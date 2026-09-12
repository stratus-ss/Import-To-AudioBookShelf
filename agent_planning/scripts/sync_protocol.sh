#!/usr/bin/env bash
# Syncs canonical agent_planning framework files from this source directory to
# all downstream project repos that have an agent_planning/ directory.
#
# Usage:
#   ./scripts/sync_protocol.sh                # sync all known repos
#   ./scripts/sync_protocol.sh --dry-run      # show what would be copied
#   ./scripts/sync_protocol.sh --discover     # find repos with agent_planning/ under GIT_PROJECTS_ROOT
#
# Configuration:
#   Set GIT_PROJECTS_ROOT (default: ~/git_projects) to the parent directory of your repos.
#   Add repo names to KNOWN_REPOS below.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$(dirname "$SCRIPT_DIR")"   # agent_planning/ root
GIT_PROJECTS="${GIT_PROJECTS_ROOT:-$HOME/git_projects}"

# ── Files synced from canonical to each downstream repo ─────────────────────
CANONICAL_FILES=(
  "AGENTS.md"
  "PLAN_CORE.md"
  "EXECUTION_PROTOCOL.md"
  "TIER1_FASTPATH.md"
  "CHANGELOG.md"
  "prompts/README.md"
  "prompts/plan_review_rubric.md"
  "scripts/init_execution_dir.sh"
  "scripts/plan_lint.sh"
  "scripts/plan_review.sh"
  "scripts/quality_gate.sh"
  "scripts/secret_scan.sh"
  "scripts/sync_protocol.sh"
  # Model addenda are synced only where identical across repos.
  # deepseek/PLAN_INSTRUCTIONS.md and minimax/PLAN_INSTRUCTIONS.md are
  # INTENTIONALLY excluded — monkeyplug carries its own customized copies.
  "deepseek/MODEL_ADDENDUM.md"
  "minimax/MODEL_ADDENDUM.md"
)

# Deliberately NOT in CANONICAL_FILES:
#   - openspec/README.md        — per-repo spec tables; clobbering would
#                                  destroy downstream customizations.
#   - scripts/test/             — dev-only fixtures; not part of the
#                                  framework runtime surface.

CANONICAL_DIRS=(
  "addenda"
)

# ── Add your downstream repo names here ─────────────────────────────────────
# Each entry is a directory name under GIT_PROJECTS_ROOT that contains
# an agent_planning/ subdirectory.
KNOWN_REPOS=(
  "D&D_Workflow"
  "infra-playbooks"
  "monkeyplug"
  "OpenAudible-To-AudioBookShelf"
  "openshift-sv-tools-dev"
  "scratch_pad"
  "silverblue-desktop"
  "Whisper-WebUI"
)

# ── Flags ────────────────────────────────────────────────────────────────────
DRY_RUN=false
DISCOVER=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --discover) DISCOVER=true ;;
    *) # Unknown args must abort: a typo like `--dryrun` would otherwise fall
       # through to a REAL sync that overwrites every downstream repo.
       echo "[sync_protocol] ERROR — unknown argument: $arg" >&2
       echo "  Usage: sync_protocol.sh [--dry-run | --discover]  (no args = real sync)" >&2
       exit 1 ;;
  esac
done

# ── Discover mode ─────────────────────────────────────────────────────────────
if $DISCOVER; then
  echo "Repos with agent_planning/ under $GIT_PROJECTS:"
  find "$GIT_PROJECTS" -maxdepth 2 -type d -name "agent_planning" \
    ! -path "*/$(basename "$CANONICAL")/*" -printf "  %h\n" 2>/dev/null | sort
  echo ""
  echo "To register a repo, add its directory name to KNOWN_REPOS in this script."
  exit 0
fi

# ── Sync helpers ──────────────────────────────────────────────────────────────
sync_file() {
  local src="$1" dst="$2"
  if $DRY_RUN; then
    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "  [skip]  $dst (identical)"
    else
      echo "  [copy]  $src -> $dst"
    fi
  else
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
  fi
}

if [[ ${#KNOWN_REPOS[@]} -eq 0 ]]; then
  echo "No repos configured in KNOWN_REPOS."
  echo "Run with --discover to find repos that have agent_planning/, then add them to this script."
  exit 0
fi

# ── Real-sync banner (writes are destructive; make them impossible to miss) ─────
if ! $DRY_RUN; then
  echo ""
  echo "################################################################"
  echo "## REAL SYNC — writing canonical framework files downstream."
  echo "## Targets: ${#KNOWN_REPOS[@]} KNOWN_REPOS (canonical repo self-skipped)."
  echo "## Dry-run first if you have not reviewed the file list: --dry-run"
  echo "################################################################"
  echo ""
fi

# ── Sync loop ─────────────────────────────────────────────────────────────────
errors=0
for repo in "${KNOWN_REPOS[@]}"; do
  target="$GIT_PROJECTS/$repo/agent_planning"
  if [[ ! -d "$target" ]]; then
    echo "WARNING: $target does not exist — skipping (run init.sh in that repo first)"
    continue
  fi
  # Skip the canonical repo itself (target == source would abort cp).
  if [[ "$target" == "$CANONICAL" ]]; then
    continue
  fi

  echo "=== $repo ==="

  for f in "${CANONICAL_FILES[@]}"; do
    if [[ ! -f "$CANONICAL/$f" ]]; then
      echo "  ERROR: canonical file missing: $CANONICAL/$f"
      errors=$((errors + 1))
      continue
    fi
    sync_file "$CANONICAL/$f" "$target/$f"
  done

  for d in "${CANONICAL_DIRS[@]}"; do
    if [[ ! -d "$CANONICAL/$d" ]]; then
      echo "  ERROR: canonical dir missing: $CANONICAL/$d"
      errors=$((errors + 1))
      continue
    fi
    for f in "$CANONICAL/$d"/*.md; do
      [[ -f "$f" ]] || continue
      rel="${f#"$CANONICAL"/}"
      sync_file "$f" "$target/$rel"
    done
  done
done

# ── Verification pass ─────────────────────────────────────────────────────────
if ! $DRY_RUN; then
  echo ""
  echo "=== Verification ==="
  for repo in "${KNOWN_REPOS[@]}"; do
    target="$GIT_PROJECTS/$repo/agent_planning"
    [[ -d "$target" ]] || continue
    mismatches=0
    for f in "${CANONICAL_FILES[@]}"; do
      [[ -f "$CANONICAL/$f" ]] || continue
      if ! diff -q "$CANONICAL/$f" "$target/$f" >/dev/null 2>&1; then
        echo "  MISMATCH: $repo/agent_planning/$f"
        mismatches=$((mismatches + 1))
      fi
    done
    for d in "${CANONICAL_DIRS[@]}"; do
      [[ -d "$CANONICAL/$d" ]] || continue
      for f in "$CANONICAL/$d"/*.md; do
        [[ -f "$f" ]] || continue
        rel="${f#"$CANONICAL"/}"
        if ! diff -q "$f" "$target/$rel" >/dev/null 2>&1; then
          echo "  MISMATCH: $repo/agent_planning/$rel"
          mismatches=$((mismatches + 1))
        fi
      done
    done
    if [[ "$mismatches" -eq 0 ]]; then
      echo "  $repo: all files in sync"
    fi
  done
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Completed with $errors error(s)"
  exit 1
fi
