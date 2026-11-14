#!/usr/bin/env bash
# Language-parameterized complexity gate for code-producing tasks.
# Prefer this over ad-hoc radon/eslint one-liners in VERIFICATION blocks.
#
# Usage:
#   ./scripts/quality_gate.sh <path> [path...]
#   ./scripts/quality_gate.sh --lang auto|python|go|ts|bash <path> [path...]
#   ./scripts/quality_gate.sh --file-budget <path> [path...]
#   ./scripts/quality_gate.sh --file-budget-only <path> [path...]
#   ./scripts/quality_gate.sh --info-radon <python-path...>   # radon informational only
#
# File budget (--file-budget):
#   Enforces the per-language line caps from addenda/file-budget.md:
#   JS/TS 800, Go 500, Python 500, Bash 200. Directories are walked
#   recursively; test / generated / vendored files are skipped silently.
#   A file may declare its own budget with a sentinel comment placed in its
#   first 50 lines, written as  // file-budget: [N] — [reason]  (Go/TS/JS)
#   or  # file-budget: [N] — [reason]  (Python/Bash).
#   ADDITIVE: this also runs the language complexity gate, per CQ11. Use
#   --file-budget-only to check line caps alone.
#
# Exit codes:
#   0 — PASS
#   1 — FAIL (complexity / tool error / file over its budget)

set -euo pipefail

# file-budget: 350 — framework quality gate; four language detectors plus run_file_budget; spec in addenda/file-budget.md

LANG_MODE="auto"
FILE_BUDGET=0
FILE_BUDGET_ONLY=0
INFO_RADON=0
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)
      LANG_MODE="${2:-}"
      if [[ -z "$LANG_MODE" ]]; then
        echo "Usage: $0 --lang auto|python|go|ts|bash <path>..." >&2
        exit 1
      fi
      shift 2
      ;;
    --info-radon) INFO_RADON=1; shift ;;
    --file-budget) FILE_BUDGET=1; shift ;;
    --file-budget-only) FILE_BUDGET=1; FILE_BUDGET_ONLY=1; shift ;;
    -h|--help)
      awk 'NR==1 {next} /^#/ {sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "Usage: $0 [--lang auto|python|go|ts|bash] [--file-budget|--file-budget-only] [--info-radon] <path>..." >&2
  exit 1
fi

FAILS=0

fail() { echo "[quality_gate] FAIL — $1" >&2; FAILS=$((FAILS + 1)); }
pass() { echo "[quality_gate] PASS — $1"; }
info() { echo "[quality_gate] INFO — $1"; }

detect_lang() {
  local path="$1"
  case "$path" in
    *.py) echo python ;;
    *.go) echo go ;;
    *.ts|*.tsx|*.js|*.jsx) echo ts ;;
    *.sh|*.bash) echo bash ;;
    *)
      if [[ -d "$path" ]]; then
        if find "$path" -name '*.py' -print -quit 2>/dev/null | grep -q .; then echo python
        elif find "$path" -name '*.go' -print -quit 2>/dev/null | grep -q .; then echo go
        elif find "$path" \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print -quit 2>/dev/null | grep -q .; then echo ts
        elif find "$path" -name '*.sh' -print -quit 2>/dev/null | grep -q .; then echo bash
        else echo unknown
        fi
      else
        echo unknown
      fi
      ;;
  esac
}

run_python() {
  local target="$1"
  if ! command -v ruff >/dev/null 2>&1; then
    fail "ruff not installed (required for Python complexity gate)"
    return
  fi
  echo "[quality_gate] python: ruff check --select C901,PLR0912,PLR0915 $target"
  if ruff check --select C901,PLR0912,PLR0915 "$target"; then
    pass "ruff complexity clean: $target"
  else
    fail "ruff complexity exceeded in $target (C901/PLR0912/PLR0915; max 15 / 15 / 50)"
  fi
  if [[ "$INFO_RADON" -eq 1 ]]; then
    if command -v radon >/dev/null 2>&1; then
      info "radon (informational only — not merge-blocking):"
      radon cc "$target" -s --min C || true
    else
      info "radon not installed; skipping informational CC report"
    fi
  fi
}

run_go() {
  local target="$1"
  if ! command -v gocyclo >/dev/null 2>&1; then
    fail "gocyclo not installed (required for Go complexity gate)"
    return
  fi
  echo "[quality_gate] go: gocyclo -over 15 $target"
  local out
  out="$(gocyclo -over 15 "$target" 2>&1 || true)"
  if [[ -n "$out" ]]; then
    echo "$out" >&2
    fail "gocyclo found functions over 15 in $target"
  else
    pass "gocyclo clean: $target"
  fi
}

run_ts() {
  local target="$1"
  if ! command -v npx >/dev/null 2>&1; then
    fail "npx not available (required for TypeScript complexity gate)"
    return
  fi
  echo "[quality_gate] ts: eslint complexity≤15 on $target"
  local out rc=0
  out=$(npx --yes eslint --no-config-lookup --max-warnings 0 \
        --rule 'complexity: ["error", 15]' "$target" 2>&1) || rc=$?
  if [[ $rc -eq 0 ]]; then
    pass "eslint complexity clean: $target"
  elif grep -q 'ignored because' <<<"$out"; then
    # ESLint ignores a file with no config covering it — an absolute path
    # outside the cwd's base path, which is how every caller passes a target
    # from another repo. "Ignored" is unverified, not exceeded; failing here
    # made this arm unable to pass for ANY .ts file (2026-11-13 review, row 17).
    info "eslint has no config covering $target — complexity unverified (check by hand)"
  else
    echo "$out" >&2
    fail "eslint complexity exceeded in $target"
  fi
}

run_bash() {
  local target="$1"
  if ! command -v shellcheck >/dev/null 2>&1; then
    fail "shellcheck not installed (required for Bash quality gate)"
    return
  fi
  # The shellcheck CLI cannot take a directory: it aborts with
  #   openBinaryFile: inappropriate type (is a directory)
  # Expand a directory to the scripts underneath instead, so that
  # `--lang bash <dir>` (and `--lang auto <dir>` for a shell tree) does what
  # the caller expects. Previously that invocation always failed, which is why
  # `--lang bash` had never passed against a lab directory.
  local -a files=()
  if [[ -d "$target" ]]; then
    while IFS= read -r f; do
      files+=("$f")
    done < <(find "$target" -type f \( -name '*.sh' -o -name '*.bash' \) \
               -not -path '*/.git/*' 2>/dev/null | sort)
    if [[ ${#files[@]} -eq 0 ]]; then
      info "bash: no .sh/.bash files under $target — nothing to check"
      return
    fi
  else
    files=("$target")
  fi
  echo "[quality_gate] bash: shellcheck ${#files[@]} file(s) under $target"
  local f
  for f in "${files[@]}"; do
    if shellcheck "$f"; then
      pass "shellcheck clean: $f"
    else
      fail "shellcheck reported issues in $f"
    fi
  done
  info "Bash branch budget (≤15) remains a manual CONSTRAINTS check"
}

# --- File-budget mode (R13 / addenda/file-budget.md) -----------------------

# Skip tests, generated files, vendored trees, and VCS metadata.
# Returns 0 (skip) / 1 (do not skip).
is_skipped() {
  local path="$1"
  local base
  base="$(basename "$path")"
  case "$path" in
    */.git/*|.git/*) return 0 ;;
  esac
  case "$path" in
    */vendor/*|vendor/*|*/node_modules/*|node_modules/*) return 0 ;;
    */third_party/*|third_party/*|*/.venv/*|.venv/*) return 0 ;;
    */venv/*|venv/*|*/__pycache__/*|__pycache__/*) return 0 ;;
    */dist/*|dist/*|*/build/*|build/*|*/out/*|out/*) return 0 ;;
    */.next/*|.next/*|*/target/*|target/*) return 0 ;;
  esac
  case "$base" in
    *_test.go|*_test.py|test_*.py|conftest.py) return 0 ;;
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) return 0 ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) return 0 ;;
    *.gen.go|*.gen.ts|*.gen.js|*_pb2.py|*_pb2_grpc.py) return 0 ;;
    *.pb.go|*.pb.ts) return 0 ;;
  esac
  return 1
}

run_file_budget() {
  local path="$1"
  local SENTINEL_RE='^\s*(//|#)\s*file-budget:\s*(\d+)\s*—\s*(.+)$'
  local cap="" count="" sentinel_line="" declared=""
  if is_skipped "$path"; then
    return
  fi
  case "$path" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) cap=800 ;;
    *.go) cap=500 ;;
    *.py) cap=500 ;;
    *.sh|*.bash) cap=200 ;;
    *) return ;;
  esac
  count="$(wc -l < "$path" | tr -d '[:space:]')"
  sentinel_line="$(head -50 "$path" | rg -m 1 "$SENTINEL_RE" || true)"
  if [[ -n "$sentinel_line" ]]; then
    declared="$(printf '%s\n' "$sentinel_line" | rg -o -r '$2' "$SENTINEL_RE" || true)"
  fi
  if [[ -n "$declared" ]]; then
    cap="$declared"
    info "$path sentinel $declared honored; file is $count lines"
  fi
  if [[ "$count" -gt "$cap" ]]; then
    fail "file $path is $count lines (cap $cap); add a file-budget sentinel ($cap for Go/TS/JS via //, Python/Bash via #) or decompose"
  else
    pass "file budget ok: $path ($count/$cap lines)"
  fi
}

for path in "${PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    fail "path does not exist: $path"
    continue
  fi

  if [[ "$FILE_BUDGET" -eq 1 ]]; then
    if [[ -d "$path" ]]; then
      while IFS= read -r fp; do
        run_file_budget "$fp"
      done < <(find "$path" -type f 2>/dev/null)
    else
      run_file_budget "$path"
    fi
    # CQ11 says the file-budget check is "additive to the --lang complexity
    # invocation". This used to `continue` here, which made the two gates
    # mutually exclusive — so the command every coding task's VERIFICATION
    # names structurally could not run complexity, and did not across 68
    # devlogs. Fall through instead. `--file-budget-only` opts out.
    [[ "$FILE_BUDGET_ONLY" -eq 1 ]] && continue
    # A directory sweep already ran every file through the budget arm; the
    # complexity arm below walks paths, so return rather than re-walk.
    [[ -d "$path" ]] && continue
  fi

  lang="$LANG_MODE"
  if [[ "$lang" == "auto" ]]; then
    lang="$(detect_lang "$path")"
  fi
  # Non-code files have no complexity to measure. A data-file or docs sweep is
  # a legitimate use of --file-budget, so skip silently (the budget arm still
  # checked them) rather than failing with "could not detect language".
  if [[ "$lang" == "unknown" && "$FILE_BUDGET" -eq 1 ]]; then
    continue
  fi

  case "$lang" in
    python|py) run_python "$path" ;;
    go) run_go "$path" ;;
    ts|typescript|js|javascript) run_ts "$path" ;;
    bash|sh|shell) run_bash "$path" ;;
    unknown)
      fail "could not detect language for $path — pass --lang explicitly"
      ;;
    *)
      fail "unsupported --lang value: $lang"
      ;;
  esac
done

echo ""
if [[ "$FAILS" -gt 0 ]]; then
  echo "[quality_gate] RESULT: FAIL ($FAILS failure(s))" >&2
  exit 1
fi
echo "[quality_gate] RESULT: PASS"
exit 0
