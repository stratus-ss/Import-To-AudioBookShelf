#!/usr/bin/env bash
# Semantic reviewer wrapper — SINGLE PASS, operator-gated.
#
# Shells out to the `opencode` CLI to run the cross-model reviewer on a plan,
# captures the response, strips ANSI escapes, and extracts the review JSON.
# The reviewer is advisory: this script exits 0 when a review completes,
# regardless of the findings; only invocation/gate failures exit non-zero.
#
# Single-pass policy (framework default): the reviewer runs EXACTLY ONCE per
# plan. Two gates protect the model budget:
#   1. Operator approval — the script refuses to invoke the model unless the
#      operator passes --approved (or sets PLAN_REVIEW_APPROVED=1). Without it
#      a preflight cost estimate is printed and the script exits 2.
#   2. Hard single-pass — a plan already recorded in the review ledger is
#      hard-refused (exit 3) unless --force is given. Fix the FAIL findings and
#      move on; do NOT re-review.
# The review ledger lives at agent_planning/execution/_review_ledger.jsonl
# (gitignored, local-only; override with PLAN_REVIEW_LEDGER). A refused or
# planning-only invocation consumes no ledger entry.
#
# Model is REQUIRED: pass --model provider/name or set PLAN_REVIEW_MODEL.
# There is no silent default, so review spend never lands on a model the
# operator did not choose.
#
# Plans larger than ~48 KB are split into task-aligned parts attached to a
# SINGLE opencode invocation (plan parts in order + the self-check output).
# opencode truncates a single attached file at ~50 KB with no CLI override, so
# each PART stays under that per-file limit (override with
# PLAN_REVIEW_MAX_BYTES). If the multi-file invocation fails, the script FAILS
# LOUDLY — it does NOT fall back to sequential per-part reviews (that silently
# multiplied the cost by the part count).
#
# Usage:
#   ./scripts/plan_review.sh <plan.md> --model <provider/name> [--out <path>] --approved [--force]
#   ./scripts/plan_review.sh --help
#
# Exit codes:
#   0 — review completed (findings may or may not exist; advisory)
#   1 — invocation failure (opencode not on PATH, plan missing, no model, etc.)
#   2 — operator approval required (preflight printed; nothing was spent)
#   3 — refused: plan already reviewed once (single-pass policy; --force overrides)
#   4 — refused: review disabled, or run without an interactive terminal
#       (an agent must not run this; see the unattended guard below)
#
# Unattended guard (added 2026-10-04): after an agent ran repeated reviews
# unattended against an explicit operator "skip it" instruction, this tool
# refuses to run unless it has an interactive terminal, or the operator sets
# PLAN_REVIEW_AUTORUN=1. It also honours a kill switch: PLAN_REVIEW_DISABLED=1
# or a sentinel file at agent_planning/execution/.no-plan-review.
#
# Auth: the opencode CLI reads its provider key from
# `~/.local/share/opencode/auth.json`. This script does NOT accept or store
# credentials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBRIC_FILE="$SCRIPT_DIR/../prompts/plan_review_rubric.md"
# No silent default model — require --model or PLAN_REVIEW_MODEL (see header).
# Realistic per-invocation budget: MiniMax-class reviewer models report 8+ min
# TTFT on complex plans, so a short timeout burns a pass and forces a retry —
# the exact cost this wrapper exists to prevent. Override per environment.
REVIEW_TIMEOUT_SINGLE="${PLAN_REVIEW_TIMEOUT_SINGLE:-1800}"
REVIEW_TIMEOUT_MULTI="${PLAN_REVIEW_TIMEOUT_MULTI:-3600}"
REVIEW_TIMEOUT="$REVIEW_TIMEOUT_SINGLE"
# opencode truncates a single attached file at ~50 KB with no CLI override, so
# a larger plan is split into task-aligned parts, each under the per-file
# limit, and attached together to one reviewer invocation.
# Override the split threshold with PLAN_REVIEW_MAX_BYTES.
MAX_BYTES="${PLAN_REVIEW_MAX_BYTES:-48000}"
# Review ledger (single-pass enforcement) and operator-approval state.
LEDGER="${PLAN_REVIEW_LEDGER:-$(cd "$SCRIPT_DIR/.." && pwd)/execution/_review_ledger.jsonl}"
APPROVED=0
FORCE=0
FORCE_OK=0
LAST_RAW_BYTES=0
if [[ "${PLAN_REVIEW_APPROVED:-0}" == "1" ]]; then APPROVED=1; fi
if [[ "${PLAN_REVIEW_FORCE_OK:-0}" == "1" ]]; then FORCE_OK=1; fi

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
MODEL="${PLAN_REVIEW_MODEL:-}"

usage() {
  echo "Usage: $0 <plan.md> --model <provider/name> [--out <path>] [--approved] [--force]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT="${2:-}"
      if [[ -z "$OUT" ]]; then usage; exit 1; fi
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      if [[ -z "$MODEL" ]]; then usage; exit 1; fi
      shift 2
      ;;
    --approved) APPROVED=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help)
      sed -n '2,45p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      if [[ -n "$PLAN" ]]; then usage; exit 1; fi
      PLAN="$1"
      shift
      ;;
  esac
done

if [[ -z "$PLAN" ]]; then
  echo "[plan_review] FAIL — plan file argument required" >&2
  usage
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

# ── Kill switch + unattended guard ─────────────────────────────────────────
# Two hard stops that exist because an agent once ran repeated reviews
# unattended against an explicit operator "skip it" instruction:
#   1. Kill switch — PLAN_REVIEW_DISABLED=1, or a sentinel file, refuses all runs.
#   2. Unattended refusal — this tool only runs from an interactive terminal.
#      An agent-run shell has no TTY, so it cannot start a review on its own.
#      PLAN_REVIEW_AUTORUN=1 is the explicit operator opt-in for a headless run.
SENTINEL="$SCRIPT_DIR/../execution/.no-plan-review"
if [[ "${PLAN_REVIEW_DISABLED:-0}" == "1" || -f "$SENTINEL" ]]; then
  echo "[plan_review] REFUSED — plan review is disabled (PLAN_REVIEW_DISABLED=1 or $SENTINEL)." >&2
  exit 4
fi
if [[ ! -t 0 && "${PLAN_REVIEW_AUTORUN:-0}" != "1" ]]; then
  echo "[plan_review] REFUSED — no interactive terminal. Plan review must be operator-run (this tool is not the R7 gate)." >&2
  echo "[plan_review]   An agent must NOT run this. For a deliberate headless run the operator sets PLAN_REVIEW_AUTORUN=1." >&2
  echo "[plan_review]   To disable review entirely: PLAN_REVIEW_DISABLED=1 or create $SENTINEL" >&2
  exit 4
fi

# ── Model requirement (no silent default) ──────────────────────────────────
if [[ -z "$MODEL" ]]; then
  echo "[plan_review] FAIL — no reviewer model. Pass --model <provider/name> or set PLAN_REVIEW_MODEL." >&2
  exit 1
fi

# ── Operator approval + hard single-pass gate ──────────────────────────────
# This is the anti-loop gate. It refuses to spend model tokens unless the
# operator approved the run, and hard-refuses a second run of the same plan.
PLAN_ABS="$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")"

ledger_prior() {
  [[ -f "$LEDGER" ]] || { echo 0; return 0; }
  python3 - "$LEDGER" "$PLAN_ABS" <<'PYLEDGER' 2>/dev/null || echo 0
import json, sys
n = 0
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if isinstance(d, dict) and d.get("plan") == sys.argv[2]:
            n += 1
except OSError:
    pass
print(n)
PYLEDGER
}

preflight() {
  local bytes rubric_bytes prior est timeout_used
  bytes=$(wc -c < "$PLAN")
  rubric_bytes=$(wc -c < "$RUBRIC_FILE")
  prior="$(ledger_prior)"
  est=$(( (bytes + rubric_bytes) / 4 ))
  timeout_used="$REVIEW_TIMEOUT_SINGLE"
  if [[ "$bytes" -gt "$MAX_BYTES" ]]; then timeout_used="$REVIEW_TIMEOUT_MULTI"; fi
  echo "[plan_review] preflight:"
  echo "[plan_review]   plan:            $PLAN_ABS (${bytes} B)"
  echo "[plan_review]   rubric:          $(basename "$RUBRIC_FILE") (${rubric_bytes} B)"
  echo "[plan_review]   reviewer model:  $MODEL"
  echo "[plan_review]   prior reviews:   ${prior}"
  echo "[plan_review]   est input cost:  ~${est} tokens (plan + rubric; excludes reviewer output/tool turns)"
  echo "[plan_review]   timeout:         ${timeout_used}s"
}

prior="$(ledger_prior)"
if [[ "$prior" -gt 0 && ( "$FORCE" -eq 0 || "$FORCE_OK" -eq 0 ) ]]; then
  echo "[plan_review] REFUSED — single-pass policy: this plan was already reviewed ${prior} time(s)." >&2
  echo "[plan_review]   Fix the recorded FAIL findings and move on." >&2
  echo "[plan_review]   Re-review requires --force AND the operator env PLAN_REVIEW_FORCE_OK=1." >&2
  echo "[plan_review]   ledger: $LEDGER" >&2
  exit 3
fi

if [[ "$APPROVED" -eq 0 ]]; then
  preflight
  echo "[plan_review] NOT RUN — operator approval required. Re-run with --approved (or PLAN_REVIEW_APPROVED=1) to spend the estimate above." >&2
  exit 2
fi

echo "[plan_review] approved: model=$MODEL prior=$prior plan=$PLAN_ABS" >&2

# ── strip ANSI escape sequences from captured output ───────────────────────
strip_ansi() {
  sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g; s/\x1B[@_]//g; s/\r$//'
}

# ── extract a JSON object from captured output; emit a JSON result ──────────
# Strategy: parse the whole text; else take the FIRST balanced { ... } object
# (preferring one carrying a "grade" key); else each non-empty single-line
# object last-to-first. The balanced scan tolerates a fenced block plus
# surrounding reasoning text, and still parses legacy replies that echoed the
# object twice (rubric <= v1.4).
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
  LAST_RAW_BYTES=$(printf '%s' "$raw" | wc -c)
  if [[ -n "${RAWSIZE_FILE:-}" ]]; then printf '%s' "$LAST_RAW_BYTES" > "$RAWSIZE_FILE"; fi
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
  local size review_json MAIN_START
  MAIN_START=$(date +%s)
  size=$(wc -c < "$PLAN")

  # Run the deterministic self-check once; attach the output to every chunk
  # so the reviewer can defer baseline/enumeration checks to a checked source.
  local selfcheck_tmp="" rawsize_file
  rawsize_file="$(mktemp -t plan_review_rawsize_XXXXXX)"
  RAWSIZE_FILE="$rawsize_file"
  selfcheck_tmp="$(mktemp -t plan_review_selfcheck_XXXXXX.txt)"
  # shellcheck disable=SC2064
  trap "rm -f '$selfcheck_tmp' '$rawsize_file'" EXIT
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
    trap "rm -rf '$tmpd' '$selfcheck_tmp' '$rawsize_file'" EXIT
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
      echo "[plan_review] FAIL — multi-file review failed or unparsable. NOT falling back to sequential per-part reviews (single-pass cost policy)." >&2
      echo "[plan_review]   Split the plan so each part attaches cleanly, or re-run with --force only if the operator accepts the extra spend." >&2
      return 1
    fi
  fi
  LAST_RAW_BYTES="$(cat "$rawsize_file" 2>/dev/null || echo 0)"
  if ! [[ "$LAST_RAW_BYTES" =~ ^[0-9]+$ ]]; then LAST_RAW_BYTES=0; fi
  printf '%s\n' "$review_json" > "$OUT"
  echo "[plan_review] wrote: $OUT"
  EMIT_ELAPSED=$(( $(date +%s) - MAIN_START ))
  EMIT_PASS=$(( prior + 1 ))
  EMIT_PLAN_BYTES=$(wc -c < "$PLAN")
  emit_telemetry "$review_json"
  append_ledger
  echo "[plan_review] done: pass=$EMIT_PASS elapsed=${EMIT_ELAPSED}s raw=${LAST_RAW_BYTES}B" >&2
  echo "$review_json"
  return 0
}

# ── Review ledger (single-pass enforcement) ────────────────────────────────
# Appends one JSONL line per completed review. ledger_prior() reads it to
# hard-refuse a second review of the same plan. Local-only; no network; no
# secrets. Override the path with PLAN_REVIEW_LEDGER.
append_ledger() {
  python3 - "$LEDGER" "$PLAN_ABS" "$MODEL" "$EMIT_PASS" "$EMIT_PLAN_BYTES" "$LAST_RAW_BYTES" "$EMIT_ELAPSED" "$OUT" <<'PYLEDGER' || true
import json, os, sys, datetime
ledger, plan, model, p, plan_bytes, raw_bytes, elapsed, out = sys.argv[1:9]
try:
    d = json.load(open(out))
except Exception:
    d = {}
fs = d.get("findings", []) or []
rec = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "plan": plan,
    "model": model,
    "pass": int(p),
    "grade": d.get("grade", "?"),
    "score": d.get("score", "?"),
    "findings": len(fs),
    "defects": sum(1 for f in fs if f.get("status") == "FAIL"),
    "plan_bytes": int(plan_bytes),
    "raw_bytes": int(raw_bytes),
    "elapsed_s": int(elapsed),
    "approved": True,
}
os.makedirs(os.path.dirname(ledger), exist_ok=True)
with open(ledger, "a") as f:
    f.write(json.dumps(rec) + "\n")
PYLEDGER
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
  python3 - "$OUT" "$project" "$MODEL" "$hook_state_writes" "$hook_tool_calls" "$sink" \
    "${EMIT_PLAN_BYTES:-0}" "${LAST_RAW_BYTES:-0}" "${EMIT_ELAPSED:-0}" "${EMIT_PASS:-1}" <<'PYTELEMETRY' || true
import json, os, sys, datetime
out_path = sys.argv[1]
project  = sys.argv[2] if sys.argv[2] else "unknown"
model    = sys.argv[3]
state_writes = int(sys.argv[4])
tool_calls   = int(sys.argv[5])
sink = sys.argv[6]
plan_bytes = int(sys.argv[7])
raw_bytes  = int(sys.argv[8])
elapsed_s  = int(sys.argv[9])
review_pass = int(sys.argv[10])
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
    "rework": 0,
    "recovery_success": defects == 0,
    "plan_bytes": plan_bytes,
    "raw_bytes": raw_bytes,
    "elapsed_s": elapsed_s,
    "pass": review_pass,
    "approved": True,
    "counterfactual": None,
}
os.makedirs(os.path.dirname(sink), exist_ok=True)
with open(sink, "a") as f:
    f.write(json.dumps(record) + "\n")
PYTELEMETRY
}
main
exit 0

