#!/usr/bin/env bash
# Creates the execution directory for a Tier 2/3 plan and pre-populates
# STATE.md and TASK_QUEUE.md from the templates in EXECUTION_PROTOCOL.md §7.
# Run once at the start of the first session.
#
# Usage:
#   ./scripts/init_execution_dir.sh <project_name>
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md>
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md> --require-full-tasks
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md> --allow-non-code
#   ./scripts/init_execution_dir.sh <project_name> --skip-plan-lint   # emergency only
#
# When --plan is provided, plan_lint.sh MUST pass before the directory is
# created/updated. That is the only fail-closed script gate before Task 1.
# Plan review via plan_review.sh is optional and operator-run, never invoked
# by bootstrap. (The R7 validation gate is the agent-side plan-validator
# subagent dispatch, PLAN_CORE.md §8.7 — not a bootstrap script gate.)
#
# --skip-r7-gate / --r7-waived are accepted for backward compatibility but are
# no-ops (the shell-based R7 gate was removed 2026-10-04; R7 was re-instated
# 2026-10-25 as the agent-side subagent dispatch above).
#
# The script is idempotent — running it again on an existing directory only
# creates missing files; it will not overwrite files that already have content.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--skip-plan-lint]" >&2
  exit 1
fi

PROJECT_NAME="$1"
shift

PLAN=""
REQUIRE_FULL=0
SKIP_PLAN_LINT=0
ALLOW_NON_CODE=0
# R7: the shell-based gate was removed 2026-10-04; R7 was re-instated
# 2026-10-25 as the agent-side plan-validator subagent dispatch
# (PLAN_CORE.md §8.7) — still not a bootstrap script gate. SKIP_R7_GATE and
# R7_WAIVED remain accepted as deprecated no-op flags so existing callers do
# not break; neither has any effect.
SKIP_R7_GATE=0
R7_WAIVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN="${2:-}"
      if [[ -z "$PLAN" ]]; then
        echo "Usage: $0 <project_name> --plan <plan.md>" >&2
        exit 1
      fi
      shift 2
      ;;
    --require-full-tasks) REQUIRE_FULL=1; shift ;;
    --allow-non-code) ALLOW_NON_CODE=1; shift ;;
    --skip-plan-lint) SKIP_PLAN_LINT=1; shift ;;
    --skip-r7-gate) SKIP_R7_GATE=1; shift ;;
    --r7-waived) R7_WAIVED=1; shift ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--allow-non-code] [--skip-plan-lint]" >&2
      exit 1
      ;;
  esac
done

# shellcheck disable=SC2034  # deprecated no-op flags retained for caller compatibility
: "$SKIP_R7_GATE" "$R7_WAIVED"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
EXEC_DIR="$FRAMEWORK_DIR/execution/$PROJECT_NAME"
NOW="$(date '+%Y-%m-%d %H:%M')"
# shellcheck disable=SC2034
DATE="$(date '+%Y-%m-%d')"

# ── Fail-closed plan lint (when --plan is supplied) ─────────────────────────
if [[ -n "$PLAN" ]]; then
  PLAN_LINT_RAN=0
  if [[ "$SKIP_PLAN_LINT" -eq 1 ]]; then
    echo "[init_execution_dir] WARN — skipping plan_lint (--skip-plan-lint). Log as [SCOPE-GAP]."
  else
    LINT_ARGS=("$SCRIPT_DIR/plan_lint.sh")
    if [[ "$REQUIRE_FULL" -eq 1 ]]; then
      LINT_ARGS+=(--require-full-tasks)
    fi
    if [[ "$ALLOW_NON_CODE" -eq 1 ]]; then
      LINT_ARGS+=(--allow-non-code)
    fi
    LINT_ARGS+=("$PLAN")
    echo "[init_execution_dir] Running plan_lint on $PLAN"
    if ! "${LINT_ARGS[@]}"; then
      echo "[init_execution_dir] REFUSING to bootstrap — fix the plan first." >&2
      exit 1
    fi
    PLAN_LINT_RAN=1
  fi

else
  echo "[init_execution_dir] WARN — no --plan provided; plan_lint not run."
  echo "  Prefer: $0 $PROJECT_NAME --plan zed_plans/<plan>.md"
fi

mkdir -p "$EXEC_DIR/devlogs"
mkdir -p "$EXEC_DIR/artifacts"

# Per-directory .gitignore for artifacts (excludes large snapshots, keeps README)
GITIGNORE="$EXEC_DIR/artifacts/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" << 'EOF'
# Exclude large/regeneratable snapshots from git
*.json
*.bin
*.img
*.tar.gz
*.zip
# Keep README and small manifests
!README.md
!*.md
EOF
  echo "  created: artifacts/.gitignore"
fi

# artifacts/README.md
ARTIFACTS_README="$EXEC_DIR/artifacts/README.md"
if [[ ! -f "$ARTIFACTS_README" ]]; then
  cat > "$ARTIFACTS_README" << EOF
# Artifacts — $PROJECT_NAME

Runtime state snapshots saved during plan execution.

| File | Description | Date added |
|------|-------------|------------|
| _(none yet)_ | | |

## Recovery

Snapshots here are for forensic diff and rollback only.
The live system is the source of truth; canonical git-tracked files are the importable source.

## Sensitive content

If any snapshot contains secrets, it is listed here but NOT git-tracked.
EOF
  echo "  created: artifacts/README.md"
fi

# STATE.md — single recovery file (replaces SESSION_BRIEF.md + HANDOFF.md).
STATE_FILE="$EXEC_DIR/STATE.md"
# Migrate legacy SESSION_BRIEF.md / HANDOFF.md into STATE.md when they exist.
if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" || -f "$EXEC_DIR/HANDOFF.md" ]]; then
  if [[ ! -f "$STATE_FILE" ]]; then
    {
      echo "# State — $PROJECT_NAME"
      echo ""
      echo "**Updated:** $NOW"
      echo ""
      echo "## Objective"
      if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        awk '/^## Objective/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/SESSION_BRIEF.md" | head -3
      else
        echo "_(Fill in: one sentence describing what the overall plan achieves.)_"
      fi
      echo ""
      echo "## Current Task"
      if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        awk '/^## Current Task/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/SESSION_BRIEF.md" | head -3
      else
        echo "_(Fill in: Task ID and name from TASK_QUEUE.md.)_"
      fi
      echo ""
      echo "## Status"
      if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        awk '/^## Status/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/SESSION_BRIEF.md" | head -10
      else
        echo "- Last completed: none"
        echo "- Active: Task 1"
        echo "- Blocked on: none"
      fi
      echo ""
      echo "## Next Action"
      if [[ -f "$EXEC_DIR/HANDOFF.md" ]]; then
        awk '/^## Next Action/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/HANDOFF.md" | head -5
      elif [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        awk '/^## Next Action/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/SESSION_BRIEF.md" | head -5
      else
        echo "_(Fill in: the specific first action — command, file edit, or verification step.)_"
      fi
      echo ""
      echo "## Files In Scope"
      if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        awk '/^## Files In Scope/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/SESSION_BRIEF.md" | head -10
      else
        echo "- _(Fill in: path/to/file — why it matters)_"
      fi
      echo ""
      echo "## Bootstrap"
      echo "Read in this order:"
      echo "1. zed_plans/<plan_file>.md — OBJECTIVE + current task section only"
      echo "2. agent_planning/execution/$PROJECT_NAME/STATE.md"
      echo "3. agent_planning/execution/$PROJECT_NAME/TASK_QUEUE.md"
      echo ""
      echo "## Where We Are"
      if [[ -f "$EXEC_DIR/HANDOFF.md" ]]; then
        awk '/^## Where We Are/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/HANDOFF.md" | head -3
      else
        echo "_(Fill in: what has been done, what is not done.)_"
      fi
      echo ""
      echo "## Known Blockers / Gotchas"
      if [[ -f "$EXEC_DIR/HANDOFF.md" ]]; then
        awk '/^## Known Blockers/{flag=1; next} /^## /{flag=0} flag' "$EXEC_DIR/HANDOFF.md" | head -10
      else
        echo "- _(none yet)_"
      fi
    } > "$STATE_FILE"
    echo "  migrated → STATE.md"
  fi
fi

if [[ ! -f "$STATE_FILE" ]]; then
  cat > "$STATE_FILE" << EOF
# State — $PROJECT_NAME

**Updated:** $NOW

## Objective
_(Fill in: one sentence describing what the overall plan achieves.)_

## Current Task
_(Fill in: Task ID and name from TASK_QUEUE.md.)_

## Status
- Last completed: none
- Active: Task 1
- Blocked on: none

## Next Action
_(Fill in: the specific first action — command, file edit, or verification step.)_

## Files In Scope
- _(Fill in: path/to/file — why it matters)_

## Bootstrap
Read in this order:
1. zed_plans/<plan_file>.md — OBJECTIVE + current task section only
2. agent_planning/execution/$PROJECT_NAME/STATE.md
3. agent_planning/execution/$PROJECT_NAME/TASK_QUEUE.md

## Where We Are
_(Fill in: what has been done, what is not done.)_

## Known Blockers / Gotchas
- _(none yet)_
EOF
  echo "  created: STATE.md"
fi

# TASK_QUEUE.md
TASK_QUEUE="$EXEC_DIR/TASK_QUEUE.md"
if [[ ! -f "$TASK_QUEUE" ]]; then
  cat > "$TASK_QUEUE" << EOF
# Task Queue — $PROJECT_NAME

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | _(Fill in task name from plan)_ | todo | |

<!-- Statuses: todo / doing / done / blocked / skipped -->
EOF
  echo "  created: TASK_QUEUE.md"
fi

echo ""
echo "Execution directory ready: $EXEC_DIR"
if [[ -n "$PLAN" ]]; then
  if [[ "$PLAN_LINT_RAN" -eq 1 ]]; then
    echo "Plan lint: PASS ($PLAN)"
  else
    echo "Plan lint: SKIPPED ($PLAN) — [--skip-plan-lint] in effect"
  fi
fi
echo "Next steps:"
echo "  1. Open the plan and copy all task names into TASK_QUEUE.md"
echo "  2. Fill in the Objective and Next Action in STATE.md"
echo "  3. Mark Task 1 as 'doing' in TASK_QUEUE.md before starting work"
echo "  4. After code tasks / every 3-task sprint: agent_planning/scripts/quality_gate.sh <paths>"

# ── Telemetry hook (Task 11) ──────────────────────────────────────────────
# Appends one JSONL line per run to agent_planning/execution/_telemetry.jsonl.
# Local-only append; no network; secrets are never recorded. See TELEMETRY.md.
emit_telemetry() {
  local deviations=$(( SKIP_PLAN_LINT ))
  local round_trips=0
  local state_writes=0
  [[ -f "$STATE_FILE" ]] && state_writes=$((state_writes + 1))
  [[ -f "$TASK_QUEUE" ]] && state_writes=$((state_writes + 1))
  local recovery_success=0
  [[ -f "$STATE_FILE" ]] && recovery_success=1
  local sink="$FRAMEWORK_DIR/execution/_telemetry.jsonl"
  python3 - "$PROJECT_NAME" "$deviations" "$round_trips" "$state_writes" "$recovery_success" "$PLAN" "$sink" <<'PYTELEMETRY' || true
import json, os, sys, datetime
project = sys.argv[1]
deviations = int(sys.argv[2])
round_trips = int(sys.argv[3])
state_writes = int(sys.argv[4])
recovery_success = bool(int(sys.argv[5]))
plan = sys.argv[6]
sink = sys.argv[7]
record = {
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "hook": "init_execution_dir",
    "project": project,
    "tier": None,
    "addendum": None,
    "model": None,
    "protocol_lines_read": None,
    "state_writes": state_writes,
    "tool_calls": 0,
    "round_trips": round_trips,
    "findings": 0,
    "defects": 0,
    "deviations": deviations,
    "rework": 0,
    "recovery_success": recovery_success,
    "counterfactual": None,
    "plan": plan,
}
os.makedirs(os.path.dirname(sink), exist_ok=True)
with open(sink, "a") as f:
    f.write(json.dumps(record) + "\n")
PYTELEMETRY
}
emit_telemetry
