#!/usr/bin/env bash
# Semantic reviewer wrapper. Shells out to the `opencode` CLI to run the
# cross-model reviewer on a plan, captures the response, strips ANSI escapes,
# and extracts the final non-empty line as JSON. The reviewer is advisory:
# this script exits 0 regardless of the reviewer's findings; only invocation
# failures (opencode missing, plan file missing) exit non-zero.
#
# Plans larger than ~48 KB are split into task-aligned parts; ALL parts are
# attached to a SINGLE opencode invocation (multi-file attach, plan parts in
# order + the self-check output), so one reviewer session sees the whole plan
# and cross-task contracts stay reviewable. If the multi-file invocation
# fails, the wrapper falls back to sequential per-part reviews (the
# pre-2026-09-28 behavior). The split exists because opencode truncates a
# single attached file at ~50 KB with no CLI override — each PART stays under
# that per-file limit. Override the threshold with PLAN_REVIEW_MAX_BYTES.
#
# Usage:
#   ./scripts/plan_review.sh <plan.md> [--out <path>] [--model <provider/name>]
#   ./scripts/plan_review.sh --help
#
# Exit codes:
#   0 — review completed (findings may or may not exist; advisory)
#   1 — invocation failure (opencode not on PATH, plan missing, etc.)
#
# Auth: the opencode CLI reads its provider key from
# `~/.local/share/opencode/auth.json`. This script does NOT accept or store
# credentials. If you need a different model, pass `--model provider/name`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC_FILE="$SCRIPT_DIR/../prompts/plan_review_rubric.md"
DEFAULT_MODEL="minimax/MiniMax-M3"
# opencode truncates a single attached file at ~50 KB with no CLI override, so
# a larger plan is split into task-aligned parts, each under the per-file
# limit, and attached together to one reviewer invocation.
# Override the split threshold with PLAN_REVIEW_MAX_BYTES.
MAX_BYTES="${PLAN_REVIEW_MAX_BYTES:-48000}"
# Per-invocation opencode timeout. The multi-file whole-plan review gets a
# larger budget (it does the work the sequential parts used to split).
REVIEW_TIMEOUT_SINGLE=240
REVIEW_TIMEOUT_MULTI=600
REVIEW_TIMEOUT="$REVIEW_TIMEOUT_SINGLE"

# opencode CLI compatibility (V1 vs V2). V1 accepted the global `--pure` flag
# ("run without external plugins"). V2 removed it: `opencode run --pure ...`
# exits 1 with "Unrecognized flag: --pure" and prints help, which silently
# broke every review (the wrapper captured the help text as non-JSON output).
# On V2 the equivalent is the `plugins` config control list: "-*" disables
# every external plugin, injected for this invocation only via
# OPENCODE_CONFIG_CONTENT. The arrays are populated once by detect_opencode_cli.
OC_FLAGS=()
OC_ENV=()
detect_opencode_cli() {
  if opencode --help 2>&1 | grep -q -- '--pure'; then
    OC_FLAGS=( --pure )                       # V1
  else
    OC_ENV=( env OPENCODE_CONFIG_CONTENT='{"plugins":["*","-*"]}' )  # V2
  fi
}

PLAN=""
OUT=""
MODEL="$DEFAULT_MODEL"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT="${2:-}"
      if [[ -z "$OUT" ]]; then
        echo "Usage: $0 [--model <provider/name>] [--out <path>] <plan.md>" >&2
        exit 1
      fi
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      if [[ -z "$MODEL" ]]; then
        echo "Usage: $0 [--model <provider/name>] [--out <path>] <plan.md>" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      if [[ -n "$PLAN" ]]; then
        echo "Usage: $0 [--model <provider/name>] [--out <path>] <plan.md>" >&2
        exit 1
      fi
      PLAN="$1"
      shift
      ;;
  esac
done

if [[ -z "$PLAN" ]]; then
  echo "[plan_review] FAIL — plan file argument required" >&2
  echo "[plan_review] Usage: $0 <plan.md> [--out <path>] [--model <provider/name>]" >&2
  exit 1
fi

if [[ ! -f "$PLAN" ]]; then
  echo "[plan_review] FAIL — plan file not found: $PLAN" >&2
  exit 1
fi

if [[ ! -f "$RUBRIC_FILE" ]]; then
  echo "[plan_review] FAIL — rubric not found: $RUBRIC_FILE" >&2
  exit 1
fi

if [[ -z "$OUT" ]]; then
  OUT="${PLAN%.*}.review.json"
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "[plan_review] FAIL — opencode CLI not on PATH" >&2
  exit 1
fi

# Resolve the V1/V2-specific invocation flags once (see detect_opencode_cli).
detect_opencode_cli

# ── strip ANSI escape sequences from captured output ───────────────────────
strip_ansi() {
  sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g; s/\x1B[@_]//g; s/\r$//'
}

# ── extract a JSON object from captured output; emit a JSON result ──────────
# Strategy: parse the whole text; else take the FIRST balanced { ... } object;
# else each non-empty single-line object last-to-first. The balanced scan is
# required because the reviewer rubric asks for the object TWICE (a fenced
# block plus a bare echo), so a naive first-{ to last-} span contains both
# copies and fails to parse ("Extra data").
extract_json() {
  local raw="$1"
  local stripped
  stripped="$(echo "$raw" | strip_ansi)"

  if command -v python3 >/dev/null 2>&1; then
    # Use python to find the reviewer's JSON object: whole text, then the
    # first balanced object (preferring one with a "grade" key), then
    # each non-empty line last-to-first.
    local picked
    picked="$(printf '%s' "$stripped" | python3 -c '
import json, sys
text = sys.stdin.read()

def emit(obj):
    print(json.dumps(obj))
    sys.exit(0)

# 1) whole text is valid JSON (bare output)
try:
    emit(json.loads(text))
except Exception:
    pass

# 2) first balanced { ... } object (fenced output, and the rubric s
#    duplicated "fenced block + bare echo" form which defeats a naive
#    first-{ to last-} span)
def balanced_objects(s):
    i = 0
    n = len(s)
    while i < n:
        if s[i] != "{":
            i += 1
            continue
        depth = 0
        instr = False
        esc = False
        start = i
        j = i
        while j < n:
            c = s[j]
            if instr:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == "\"":
                    instr = False
            elif c == "\"":
                instr = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    yield s[start:j + 1]
                    break
            j += 1
        i = j + 1

candidates = []
for blob in balanced_objects(text):
    try:
        candidates.append(json.loads(blob))
    except Exception:
        pass

for obj in candidates:
    if isinstance(obj, dict) and "grade" in obj:
        emit(obj)
if candidates:
    emit(candidates[0])

# 3) each non-empty line, last to first (single-line JSON)
for line in reversed(text.splitlines()):
    s = line.strip()
    if s.startswith("{") and s.endswith("}"):
        try:
            emit(json.loads(s))
        except Exception:
            pass

sys.exit(1)
' 2>/dev/null || true)"
    if [[ -n "$picked" ]]; then
      printf '%s\n' "$picked"
      return
    fi
    # Build the error envelope with python so $MODEL/$PLAN are JSON-escaped.
    printf '%s' "$stripped" | python3 -c '
import json, sys
print(json.dumps({"error": "non-json-output",
                  "model": sys.argv[1],
                  "plan": sys.argv[2],
                  "raw": sys.stdin.read()[:4000]}))
' "$MODEL" "$PLAN" 2>/dev/null || printf '{"error":"non-json-output","model":"%s","plan":"%s"}\n' \
      "${MODEL//\"/\\\"}" "${PLAN//\"/\\\"}"
    return
  fi

  # No python3 — best-effort: pick the longest non-empty line that looks like JSON
  local best
  best="$(echo "$stripped" | grep -E '^\{.*\}$' | awk '{ if (length($0) > max) { max = length($0); best = $0 } } END { print best }')"
  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
  else
    printf '{"error":"no-json-line","model":"%s","plan":"%s"}\n' \
      "${MODEL//\"/\\\"}" "${PLAN//\"/\\\"}"
  fi
}

# ── one reviewer invocation over one or more attached plan files ────────────
# $1 = note appended to the rubric prompt; $2 = optional path to a
#      deterministic self-check output to also attach (attached LAST);
#      remaining args = plan file(s) to attach, in order.
# Uses the REVIEW_TIMEOUT global (single-file callers leave it at
# REVIEW_TIMEOUT_SINGLE; the multi-file caller raises it).
review_once() {
  local note="${1:-}" selfcheck="${2:-}"
  shift 2
  local attach_args=()
  local f
  for f in "$@"; do
    attach_args+=( -f "$f" )
  done
  if [[ -n "$selfcheck" && -f "$selfcheck" ]]; then
    attach_args+=( -f "$selfcheck" )
  fi
  raw="$(timeout "$REVIEW_TIMEOUT" "${OC_ENV[@]}" opencode run -m "$MODEL" "${OC_FLAGS[@]}" "$(cat "$RUBRIC_FILE")${note}" "${attach_args[@]}" 2>&1)" || {
    rc=$?
    echo "[plan_review] FAIL — opencode invocation failed (exit $rc)" >&2
    echo "$raw" >&2
    return 1
  }
  extract_json "$raw"
}

# ── split an oversize plan into <=MAX_BYTES chunks at task boundaries ───────
split_plan() {
  # $1 = output dir; prints chunk paths, one per line
  python3 - "$PLAN" "$1" "$MAX_BYTES" <<'PYSPLIT'
import sys, os, re
plan, outdir, maxb = sys.argv[1], sys.argv[2], int(sys.argv[3])
text = open(plan, encoding="utf-8", errors="replace").read()
parts = re.split(r"(?m)^(?=### )", text) or [text]
chunks, cur = [], ""
for part in parts:
    if cur and len(cur.encode()) + len(part.encode()) > maxb:
        chunks.append(cur); cur = part
    else:
        cur += part
if cur:
    chunks.append(cur)
final = []
for c in chunks:
    if len(c.encode()) <= maxb:
        final.append(c); continue
    # Single chunk still over MAX_BYTES — hard-split by lines. A single line
    # itself > MAX_BYTES will sit whole (the limit is a soft target); warn.
    line_cur = ""
    for line in c.splitlines(True):
        if line_cur and len(line_cur.encode()) + len(line.encode()) > maxb:
            final.append(line_cur); line_cur = line
        else:
            line_cur += line
    if line_cur:
        # Detect a single line that exceeded MAX_BYTES (line_cur is exactly it).
        if len(line_cur.encode()) > maxb:
            print(f"[plan_review] WARN — chunk contains a {len(line_cur.encode())}B line (> {maxb}B); line kept whole; review may be truncated by opencode", file=sys.stderr)
        final.append(line_cur)
paths = []
for i, c in enumerate(final, 1):
    p = os.path.join(outdir, "chunk_%02d.md" % i)
    open(p, "w", encoding="utf-8").write(c)
    paths.append(p)
print("\n".join(paths))
PYSPLIT
}

# ── merge per-chunk reviewer JSON into one findings object ──────────────────
merge_json() {
  # $1 = output path; rest = chunk JSON files
  python3 - "$@" <<'PYMERGE'
import json, sys
out, files = sys.argv[1], sys.argv[2:]
GRADES = ["F","D","C-","C","C+","B-","B","B+","A-","A","A+"]
grade, score, findings, summaries, chunks, models = "A+", 100, [], [], [], []
for fn in files:
    try:
        d = json.load(open(fn))
    except Exception:
        continue
    if not isinstance(d, dict) or "error" in d:
        continue
    chunks.append(fn)
    findings.extend(d.get("findings", []) or [])
    s = d.get("score")
    if isinstance(s, int):
        score = min(score, s)
    g = d.get("grade")
    if g in GRADES and GRADES.index(g) < GRADES.index(grade):
        grade = g
    if d.get("summary"):
        summaries.append(str(d["summary"]))
    if d.get("model"):
        models.append(str(d["model"]))
merged = {
    "grade": grade if chunks else "F",
    "score": score if chunks else 0,
    "findings": findings,
    "summary": (" ".join(summaries) if summaries
                else "chunked review: no parsable chunk output"),
    "chunks_reviewed": len(chunks),
    "model": models[0] if models else "",
}
print(json.dumps(merged))
PYMERGE
}

# ── run plan_selfcheck.sh once and capture output for the reviewer to read ─
run_selfcheck() {
  local selfcheck_script="$SCRIPT_DIR/plan_selfcheck.sh"
  if [[ ! -x "$selfcheck_script" ]]; then
    return 1
  fi
  local out="$1"
  bash "$selfcheck_script" "$PLAN" > "$out" 2>&1 || true
  [[ -s "$out" ]]
}

# ── main: invoke the reviewer (single call, or chunked for oversize plans) ──
main() {
  mkdir -p "$(dirname "$OUT")"
  local size review_json
  size=$(wc -c < "$PLAN")

  # Run the deterministic self-check once; attach the output to every chunk
  # so the reviewer can defer baseline/enumeration checks to a checked source.
  local selfcheck_tmp=""
  selfcheck_tmp="$(mktemp -t plan_review_selfcheck_XXXXXX.txt)"
  # shellcheck disable=SC2064
  trap "rm -f '$selfcheck_tmp'" EXIT
  if run_selfcheck "$selfcheck_tmp"; then
    echo "[plan_review] attached deterministic self-check (plan_selfcheck.sh)" >&2
  else
    selfcheck_tmp=""
    echo "[plan_review] WARN — plan_selfcheck.sh unavailable; reviewer will rely on its own runs" >&2
  fi

  if [[ "$size" -le "$MAX_BYTES" ]]; then
    local single_note
    single_note=$'\n\nReviewer session nonce: '"$(date +%s%N)-$RANDOM"
    review_json="$(review_once "$single_note" "$selfcheck_tmp" "$PLAN")" || return 1
  else
    local tmpd chunks
    tmpd="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpd' '$selfcheck_tmp'" EXIT
    echo "[plan_review] plan is ${size}B (> ${MAX_BYTES}B) — split into parts, reviewed in ONE multi-file invocation" >&2
    chunks="$(split_plan "$tmpd")" || {
      echo "[plan_review] FAIL — chunking failed" >&2
      return 1
    }
    local paths=()
    mapfile -t paths <<< "$chunks"
    local n="${#paths[@]}"
    local multi_note
    multi_note=$'\n\nThe complete plan is attached as '"$n"' files (part 1 through part '"$n"', in attachment order) followed by the deterministic self-check output as the final attachment. Together the parts ARE the whole plan, in order — review it end to end as one plan. Cross-part and cross-task contracts (producer↔consumer value flows, enumeration↔tree call-site sets) are fully visible in this session and MUST be reviewed as ordinary findings; the UNVERIFIED-CROSS-CHUNK exemption does NOT apply.\n\nDeterministic self-check output is attached as a separate file; treat it as authoritative for baseline/enumeration checks it ran. Reviewer session nonce: '"$(date +%s%N)-$RANDOM"

    REVIEW_TIMEOUT="$REVIEW_TIMEOUT_MULTI"
    local multi_json="$tmpd/review_multi.json" multi_ok=0
    if review_once "$multi_note" "$selfcheck_tmp" "${paths[@]}" > "$multi_json"; then
      if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,dict) and "grade" in d and "error" not in d else 1)' "$multi_json" 2>/dev/null; then
        multi_ok=1
      fi
    fi
    REVIEW_TIMEOUT="$REVIEW_TIMEOUT_SINGLE"
    if [[ "$multi_ok" -eq 1 ]]; then
      echo "[plan_review] multi-file whole-plan review succeeded (${n} parts)" >&2
      review_json="$(cat "$multi_json")"
    else
      echo "[plan_review] WARN — multi-file review failed or unparsable; falling back to sequential per-part reviews" >&2
      local i=0 p json_files=()
      for p in "${paths[@]}"; do
        i=$((i + 1))
        local jf="$tmpd/review_${i}.json"
        local note
        note=$'\n\nThis is chunk '"$i"' of '"$n"' of a larger plan; review only what is shown and do not penalize omissions that another chunk may cover — but DO flag cross-artifact contracts (producer↔consumer value flows, enumeration↔tree call-site sets) as findings tagged UNVERIFIED-CROSS-CHUNK with status ADVISORY. An unverified internal enumeration is a real issue, not an invented one.\n\nDeterministic self-check output is attached as a separate file; treat it as authoritative for baseline/enumeration checks it ran. Reviewer session nonce: '"$(date +%s%N)-$RANDOM"
        if review_once "$note" "$selfcheck_tmp" "$p" > "$jf"; then
          json_files+=("$jf")
        else
          echo "[plan_review] WARN — chunk ${i}/${n} review failed; continuing" >&2
        fi
      done
      if [[ "${#json_files[@]}" -eq 0 ]]; then
        echo "[plan_review] FAIL — all chunk reviews failed" >&2
        return 1
      fi
      review_json="$(merge_json "$OUT" "${json_files[@]}")"
    fi
  fi
  printf '%s\n' "$review_json" > "$OUT"
  echo "[plan_review] wrote: $OUT"
  emit_telemetry "$review_json"
  echo "$review_json"
  return 0
}

# ── Telemetry hook (Task 11) ──────────────────────────────────────────────
# Appends one JSONL line per run to agent_planning/execution/_telemetry.jsonl.
# Local-only append; no network; secrets are never recorded. See TELEMETRY.md.
emit_telemetry() {
  local review_json="$1"
  local project
  project="$(basename "$(dirname "$OUT")")"   # .../execution/<project>/...
  local hook_state_writes=1   # we wrote one OUT (review.json)
  local hook_tool_calls=1     # at minimum one opencode invocation
  local sink="$SCRIPT_DIR/../execution/_telemetry.jsonl"
  python3 - "$OUT" "$project" "$MODEL" "$hook_state_writes" "$hook_tool_calls" "$sink" <<'PYTELEMETRY' || true
import json, os, sys, datetime
out_path = sys.argv[1]
project  = sys.argv[2] if sys.argv[2] else "unknown"
model    = sys.argv[3]
state_writes = int(sys.argv[4])
tool_calls   = int(sys.argv[5])
sink = sys.argv[6]
try:
    d = json.load(open(out_path))
except Exception:
    d = {}
fs = d.get("findings", []) or []
defects = sum(1 for f in fs if f.get("status") == "FAIL")
record = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "hook": "plan_review",
    "project": project,
    "tier": None,
    "addendum": None,
    "model": model or d.get("model", ""),
    "protocol_lines_read": None,
    "state_writes": state_writes,
    "tool_calls": tool_calls,
    "round_trips": 0,
    "findings": len(fs),
    "defects": defects,
    "deviations": 0,
    "rework": 1 if "re-review" in (d.get("summary", "") or "").lower() else 0,
    "recovery_success": defects == 0,
    "counterfactual": None,
}
os.makedirs(os.path.dirname(sink), exist_ok=True)
with open(sink, "a") as f:
    f.write(json.dumps(record) + "\n")
PYTELEMETRY
}
main
exit 0

