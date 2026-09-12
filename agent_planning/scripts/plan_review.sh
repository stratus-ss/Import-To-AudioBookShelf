#!/usr/bin/env bash
# Semantic reviewer wrapper. Shells out to the `opencode` CLI to run the
# cross-model reviewer on a plan, captures the response, strips ANSI escapes,
# and extracts the final non-empty line as JSON. The reviewer is advisory:
# this script exits 0 regardless of the reviewer's findings; only invocation
# failures (opencode missing, plan file missing) exit non-zero.
#
# Plans larger than ~48 KB are split into task-aligned chunks and the chunk
# findings merged, because opencode truncates a single attached file at ~50 KB.
# Override the threshold with PLAN_REVIEW_MAX_BYTES.
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
# a larger plan is reviewed in task-aligned chunks and the chunk findings are
# merged. Override with PLAN_REVIEW_MAX_BYTES.
MAX_BYTES="${PLAN_REVIEW_MAX_BYTES:-48000}"

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

# ── strip ANSI escape sequences from captured output ───────────────────────
strip_ansi() {
  sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g; s/\x1B[@_]//g; s/\r$//'
}

# ── extract a JSON object from captured output; emit a JSON result ──────────
# Strategy: scan the stripped output for the LAST line that starts with '{'
# and ends with '}' AND parses as JSON. If none found, emit an error object.
extract_json() {
  local raw="$1"
  local stripped
  stripped="$(echo "$raw" | strip_ansi)"

  if command -v python3 >/dev/null 2>&1; then
    # Use python to find the JSON object in the output: try the whole text,
    # then the first-{ to last-} span, then each non-empty line last-to-first.
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

# 2) first { ... last } span (fenced or prose-wrapped output)
start = text.find("{")
end = text.rfind("}")
if start != -1 and end > start:
    try:
        emit(json.loads(text[start:end + 1]))
    except Exception:
        pass

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
    local escaped_raw
    escaped_raw="$(printf '%s' "$stripped" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()[:4000]))' 2>/dev/null || echo '"unparseable"')"
    echo '{"error":"non-json-output","model":"'"$MODEL"'","plan":"'"$PLAN"'","raw":'"$escaped_raw"'}'
    return
  fi

  # No python3 — best-effort: pick the longest non-empty line that looks like JSON
  local best
  best="$(echo "$stripped" | grep -E '^\{.*\}$' | awk '{ if (length($0) > max) { max = length($0); best = $0 } } END { print best }')"
  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
  else
    echo '{"error":"no-json-line","model":"'"$MODEL"'","plan":"'"$PLAN"'"}'
  fi
}

# ── single reviewer invocation over one attached file ───────────────────────
review_once() {
  # $1 = file to attach; $2 = optional note appended to the rubric prompt
  local file="$1" note="${2:-}" raw rc
  raw="$(timeout 240 opencode run -m "$MODEL" --pure "$(cat "$RUBRIC_FILE")${note}" -f "$file" 2>&1)" || {
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

# ── main: invoke the reviewer (single call, or chunked for oversize plans) ──
main() {
  mkdir -p "$(dirname "$OUT")"
  local size review_json
  size=$(wc -c < "$PLAN")
  if [[ "$size" -le "$MAX_BYTES" ]]; then
    review_json="$(review_once "$PLAN" "")" || return 1
  else
    local tmpd chunks i n p
    tmpd="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpd'" EXIT
    echo "[plan_review] plan is ${size}B (> ${MAX_BYTES}B) — chunked review" >&2
    chunks="$(split_plan "$tmpd")" || {
      echo "[plan_review] FAIL — chunking failed" >&2
      return 1
    }
    local paths=()
    mapfile -t paths <<< "$chunks"
    n="${#paths[@]}"; i=0
    local json_files=()
    for p in "${paths[@]}"; do
      i=$((i + 1))
      local jf="$tmpd/review_${i}.json"
      local note=$'\n\nThis is chunk '"$i"' of '"$n"' of a larger plan; review only what is shown and do not penalize omissions that another chunk may cover.'
      if review_once "$p" "$note" > "$jf"; then
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
  printf '%s\n' "$review_json" > "$OUT"
  echo "[plan_review] wrote: $OUT"
  echo "$review_json"
  return 0
}
main
exit 0

