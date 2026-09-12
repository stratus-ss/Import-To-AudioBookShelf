#!/usr/bin/env bash
# Language-parameterized complexity gate for code-producing tasks.
# Prefer this over ad-hoc radon/eslint one-liners in VERIFICATION blocks.
#
# Usage:
#   ./scripts/quality_gate.sh <path> [path...]
#   ./scripts/quality_gate.sh --lang auto|python|go|ts|bash <path> [path...]
#   ./scripts/quality_gate.sh --info-radon <python-path...>   # radon informational only
#
# Exit codes:
#   0 — PASS
#   1 — FAIL (complexity / tool error)

set -euo pipefail

LANG_MODE="auto"
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
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "Usage: $0 [--lang auto|python|go|ts|bash] [--info-radon] <path>..." >&2
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
        if compgen -G "$path/*.py" >/dev/null; then echo python
        elif compgen -G "$path/*.go" >/dev/null; then echo go
        elif compgen -G "$path/*.{ts,tsx,js,jsx}" >/dev/null 2>&1 || compgen -G "$path/*.ts" >/dev/null; then echo ts
        elif compgen -G "$path/*.sh" >/dev/null; then echo bash
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
  if npx --yes eslint --no-eslintrc --rule 'complexity: ["error", 15]' "$target"; then
    pass "eslint complexity clean: $target"
  else
    fail "eslint complexity exceeded in $target"
  fi
}

run_bash() {
  local target="$1"
  if ! command -v shellcheck >/dev/null 2>&1; then
    fail "shellcheck not installed (required for Bash quality gate)"
    return
  fi
  echo "[quality_gate] bash: shellcheck $target"
  if shellcheck "$target"; then
    pass "shellcheck clean: $target"
  else
    fail "shellcheck reported issues in $target"
  fi
  info "Bash branch budget (≤15) remains a manual CONSTRAINTS check"
}

for path in "${PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    fail "path does not exist: $path"
    continue
  fi

  lang="$LANG_MODE"
  if [[ "$lang" == "auto" ]]; then
    lang="$(detect_lang "$path")"
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
