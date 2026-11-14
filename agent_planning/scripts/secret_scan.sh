#!/usr/bin/env bash
# Scans a path for common secret patterns before a task is marked done.
# Uses gitleaks if installed; otherwise falls back to regex checks.
#
# Usage:
#   ./scripts/secret_scan.sh <path>          # scan a directory or file
#   ./scripts/secret_scan.sh --staged        # scan the git INDEX and the worktree
#
# `--staged` deliberately scans two copies of every staged file:
#   1. the index blob (`git show :<path>`) — what a commit would actually record
#   2. the worktree file — what a later `git add` would record
# Scanning only the worktree cannot see a credential left behind in the index by
# a remediation that was never re-staged, and that is the state a commit ships.
#
# Exit codes:
#   0 — no secrets found (PASS)
#   1 — secrets found or scan error (FAIL)

set -euo pipefail

TARGET="${1:-}"
FOUND=0

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <path|--staged>" >&2
  exit 1
fi

# ── gitleaks (preferred) ────────────────────────────────────────────────────
if command -v gitleaks &>/dev/null; then
  echo "[secret_scan] gitleaks found — running gitleaks detect"
  if [[ "$TARGET" == "--staged" ]]; then
    gitleaks detect --staged --no-banner
  else
    gitleaks detect --source "$TARGET" --no-banner
  fi
  echo "[secret_scan] PASS — gitleaks found no secrets"
  exit 0
fi

# ── regex fallback ──────────────────────────────────────────────────────────
echo "[secret_scan] gitleaks not found — running regex fallback"

PATTERNS=(
  # AWS access keys
  'AKIA[0-9A-Z]{16}'
  # Generic API key / token / password assignments
  '(api[_-]?key|api[_-]?token|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*["\x27][^"\x27]{8,}'
  # PEM private key header
  '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'
  # Bearer tokens in curl/code (long base64-ish strings after Bearer)
  'Bearer [A-Za-z0-9+/=_\-]{32,}'
  # kubeconfig certificates / tokens inline.
  # Split across adjacent literals so this pattern list does not match itself.
  'client-cert'"ificate-data:|client-key-da"'ta:|token: [A-Za-z0-9._\-]{32,}'
  # JWT / JWS — a bare token with no `Bearer` prefix and no assignment. This is
  # the shape HA long-lived tokens take, and it is what the first version of
  # this script could not see: `HA_TOKEN = "eyJhbGciOi..."` in a committed
  # helper script matched none of the patterns above.
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  # Truncated / concatenated JWT still bearing the standard header
  'eyJhbGciOiJ[A-Za-z0-9_-]{6,}'
)

# scan_file <file> [label]
scan_file() {
  local file="$1"
  local label="${2:-$1}"

  # Skip binary files
  if ! file "$file" | grep -qE 'text|empty'; then
    return
  fi

  local pattern
  for pattern in "${PATTERNS[@]}"; do
    if grep -qPi "$pattern" "$file" 2>/dev/null; then
      echo "[secret_scan] POTENTIAL SECRET in $label — pattern: $pattern"
      FOUND=1
    fi
  done
}

# scan_index_blob <path> — scan what `git commit` would record, not the worktree.
scan_index_blob() {
  local path="$1"
  local blob
  if ! blob="$(git show ":$path" 2>/dev/null)"; then
    return
  fi
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/secret_scan.XXXXXX")"
  printf '%s\n' "$blob" > "$tmp"
  scan_file "$tmp" "$path (git index)"
  rm -f "$tmp"
}

if [[ "$TARGET" == "--staged" ]]; then
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "[secret_scan] ERROR: --staged requires a git repository" >&2
    exit 1
  fi
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    scan_index_blob "$file"
    [[ -f "$file" ]] && scan_file "$file" "$file (worktree)"
  done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
elif [[ -f "$TARGET" ]]; then
  scan_file "$TARGET"
elif [[ -d "$TARGET" ]]; then
  while IFS= read -r file; do
    scan_file "$file"
  done < <(find "$TARGET" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/__pycache__/*' \
    ! -name '*.png' ! -name '*.jpg' ! -name '*.gif' ! -name '*.pdf')
else
  echo "[secret_scan] ERROR: $TARGET is not a file or directory" >&2
  exit 1
fi

if [[ "$FOUND" -eq 1 ]]; then
  echo "[secret_scan] FAIL — potential secrets detected. Review the files above before committing."
  exit 1
else
  echo "[secret_scan] PASS — no secret patterns detected"
  exit 0
fi
