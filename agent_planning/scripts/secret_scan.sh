#!/usr/bin/env bash
# Scans a path for common secret patterns before a task is marked done.
# Uses gitleaks if installed; otherwise falls back to regex checks.
#
# Usage:
#   ./scripts/secret_scan.sh <path>          # scan a directory or file
#   ./scripts/secret_scan.sh --staged        # scan git staged files only
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

scan_file() {
  local file="$1"

  # Skip binary files
  if ! file "$file" | grep -qE 'text|empty'; then
    return
  fi

  local patterns=(
    # AWS access keys
    'AKIA[0-9A-Z]{16}'
    # Generic API key / token / password assignments
    '(api[_-]?key|api[_-]?token|secret[_-]?key|access[_-]?token|auth[_-]?token|password)\s*[:=]\s*["\x27][^"\x27]{8,}'
    # PEM private key header
    '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'
    # Bearer tokens in curl/code (long base64-ish strings after Bearer)
    'Bearer [A-Za-z0-9+/=_\-]{32,}'
    # kubeconfig certificates / tokens inline
    'client-certificate-data:|client-key-data:|token: [A-Za-z0-9._\-]{32,}'
  )

  for pattern in "${patterns[@]}"; do
    if grep -qPi "$pattern" "$file" 2>/dev/null; then
      echo "[secret_scan] POTENTIAL SECRET in $file — pattern: $pattern"
      FOUND=1
    fi
  done
}

if [[ "$TARGET" == "--staged" ]]; then
  # Scan staged files via git diff
  while IFS= read -r file; do
    [[ -f "$file" ]] && scan_file "$file"
  done < <(git diff --cached --name-only 2>/dev/null || true)
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
