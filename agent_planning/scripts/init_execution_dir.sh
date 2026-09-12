#!/usr/bin/env bash
# Creates the execution directory for a Tier 2/3 plan and pre-populates
# SESSION_BRIEF.md, HANDOFF.md, and TASK_QUEUE.md from the templates in
# EXECUTION_PROTOCOL.md §7. Run once at the start of the first session.
#
# Usage:
#   ./scripts/init_execution_dir.sh <project_name>
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md>
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md> --require-full-tasks
#   ./scripts/init_execution_dir.sh <project_name> --plan <plan.md> --allow-non-code
#   ./scripts/init_execution_dir.sh <project_name> --skip-plan-lint   # emergency only
#   ./scripts/init_execution_dir.sh <project_name> --skip-r7-gate     # emergency only
#
# When --plan is provided, plan_lint.sh MUST pass AND the plan preamble MUST
# carry a recorded R7 review line (no unresolved FAIL) before the directory is
# created/updated. These are the fail-closed gates before Task 1.
#
# The script is idempotent — running it again on an existing directory only
# creates missing files; it will not overwrite files that already have content.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--skip-plan-lint] [--skip-r7-gate]" >&2
  exit 1
fi

PROJECT_NAME="$1"
shift

PLAN=""
REQUIRE_FULL=0
SKIP_PLAN_LINT=0
ALLOW_NON_CODE=0
SKIP_R7_GATE=0

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
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--allow-non-code] [--skip-plan-lint] [--skip-r7-gate]" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(dirname "$SCRIPT_DIR")"
EXEC_DIR="$FRAMEWORK_DIR/execution/$PROJECT_NAME"
NOW="$(date '+%Y-%m-%d %H:%M')"
# shellcheck disable=SC2034
DATE="$(date '+%Y-%m-%d')"

# R7 review-summary defaults — defined unconditionally so the SESSION_BRIEF
# append below works even when --plan is omitted (the reviewer only runs in
# the --plan branch). Without these, `set -u` aborts the no-plan path.
REVIEW_OUT="$FRAMEWORK_DIR/execution/$PROJECT_NAME/artifacts/plan_review.json"
R7_SUMMARY_TOTAL=0
R7_SUMMARY_FAILS=0
R7_SUMMARY_GRADE="?"
R7_SUMMARY_SCORE="?"
R7_SUMMARY_MODEL=""

# ── Fail-closed plan lint (when --plan is supplied) ─────────────────────────
if [[ -n "$PLAN" ]]; then
  PLAN_LINT_RAN=0
  R7_GATE_RAN=0
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

  # ── Deterministic R7 recorded-line gate (DR-2) ─────────────────────────────
  # R7 requires the plan preamble to record the semantic-review line before
  # Task 1. The reviewer tool itself is advisory; THIS deterministic check is
  # the gate. Refuse bootstrap when the line is absent or records an unresolved
  # FAIL. Override with --skip-r7-gate (log as [SCOPE-GAP]).
  if [[ "$SKIP_R7_GATE" -eq 1 ]]; then
    echo "[init_execution_dir] WARN — skipping R7 recorded-line gate (--skip-r7-gate). Log as [SCOPE-GAP]."
  else
    r7_block="$(awk '/Recorded R7 review|R7 review line/{f=1} f && c<25 {print; c++}' "$PLAN")"
    if [[ -z "$r7_block" ]]; then
      echo "[init_execution_dir] FAIL — no recorded R7 review line in the plan preamble (R7 gate)." >&2
      echo "  Run plan_review.sh, record the line under 'Recorded R7 review + operator gate', then re-run." >&2
      exit 1
    fi
    if printf '%s\n' "$r7_block" | rg -q '[1-9][0-9]* FAIL'; then
      echo "[init_execution_dir] FAIL — recorded R7 line reports an unresolved FAIL finding (R7 gate)." >&2
      printf '%s\n' "$r7_block" | sed 's/^/  /' >&2
      exit 1
    fi
    echo "[init_execution_dir] R7 recorded-line gate: PASS"
    R7_GATE_RAN=1
  fi

  # ── Advisory semantic reviewer (DR-2 / R7) ────────────────────────────────
  # After the deterministic lint passes, run the cross-model reviewer in
  # advisory mode. Failures are logged but do not block bootstrap.
  # The recorded-line R7 gate is enforced by the agent reading the plan
  # preamble (AGENTS.md "Before Task 1" — Step 2); the reviewer tool stays
  # advisory (non-deterministic output must not hard-block).
  mkdir -p "$(dirname "$REVIEW_OUT")"
  if [[ -x "$SCRIPT_DIR/plan_review.sh" ]]; then
    echo "[init_execution_dir] Running plan_review.sh (advisory) on $PLAN"
    if timeout 200 "$SCRIPT_DIR/plan_review.sh" "$PLAN" --out "$REVIEW_OUT" >/dev/null 2>&1; then
      if [[ -f "$REVIEW_OUT" ]]; then
        # shellcheck disable=SC2016  # single-quote python: env var intentionally literal
        R7_SUMMARY=$(REVIEW_OUT="$REVIEW_OUT" python3 -c '
import json, os, sys, re
try:
    d = json.load(open(os.environ["REVIEW_OUT"]))
    # If the script fell back to the error wrapper, try to extract the
    # structured JSON from the `raw` field (model often wraps JSON in
    # markdown fences; the raw preserves the full response).
    if "error" in d and "raw" in d:
        raw = d["raw"]
        m = re.search(r"```(?:json)?\s*\n(\{.*?\})\s*\n```", raw, re.DOTALL)
        if m:
            try:
                d = json.loads(m.group(1))
            except json.JSONDecodeError:
                # Last resort: find first balanced {...} in raw
                start = raw.find("{")
                depth = 0; end = -1
                for i in range(start, len(raw)):
                    if raw[i] == "{": depth += 1
                    elif raw[i] == "}":
                        depth -= 1
                        if depth == 0:
                            end = i; break
                if end > start:
                    try:
                        d = json.loads(raw[start:end+1])
                    except json.JSONDecodeError:
                        pass
    fs = d.get("findings", [])
    fails = sum(1 for f in fs if f.get("status") == "FAIL")
    grade = d.get("grade", "?")
    score = d.get("score", "?")
    model = d.get("model", "") or ""
    print(f"{len(fs)}|{fails}|{grade}|{score}|{model}")
except Exception:
    print("0|0|?")
' 2>/dev/null || echo "0|0|?")
        R7_SUMMARY_TOTAL="${R7_SUMMARY%%|*}"; rest="${R7_SUMMARY#*|}"
        R7_SUMMARY_FAILS="${rest%%|*}"; rest2="${rest#*|}"
        R7_SUMMARY_GRADE="${rest2%%|*}"; rest3="${rest2#*|}"
        R7_SUMMARY_SCORE="${rest3%%|*}"; R7_SUMMARY_MODEL="${rest3#*|}"
        echo "[init_execution_dir] plan_review.json: ${R7_SUMMARY_TOTAL} findings (${R7_SUMMARY_FAILS} FAIL); grade=${R7_SUMMARY_GRADE} score=${R7_SUMMARY_SCORE} model=${R7_SUMMARY_MODEL:-?} (advisory; see artifacts/plan_review.json)"
        if [[ "${R7_SUMMARY_FAILS}" -gt 0 ]]; then
          echo "[init_execution_dir] REQUIRED-RESOLVE — ${R7_SUMMARY_FAILS} FAIL finding(s) in plan_review.json. Resolve or override before Task 1 (R7)."
        fi
      fi
    else
      echo "[init_execution_dir] WARN — plan_review.sh failed; bootstrap continues (advisory only)."
    fi
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

# SESSION_BRIEF.md
SESSION_BRIEF="$EXEC_DIR/SESSION_BRIEF.md"
if [[ ! -f "$SESSION_BRIEF" ]]; then
  cat > "$SESSION_BRIEF" << EOF
# Session Brief — $PROJECT_NAME

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
EOF
  echo "  created: SESSION_BRIEF.md"
  # Append the R7 review summary to the just-created SESSION_BRIEF (Task 8).
  # The recorded-line R7 gate is enforced by the agent reading the preamble;
  # the bootstrap script just surfaces the review metadata for downstream
  # sessions. Only append when --plan was supplied and the reviewer actually
  # ran (the no-plan path has no review to surface).
  if [[ -n "$PLAN" ]]; then
    cat >> "$SESSION_BRIEF" << EOF

## R7 Review Summary

- reviewer: ${R7_SUMMARY_MODEL:-minimax/MiniMax-M3 (default; artifact did not record model)}
- grade: ${R7_SUMMARY_GRADE}
- score: ${R7_SUMMARY_SCORE}
- findings: ${R7_SUMMARY_TOTAL} (FAIL=${R7_SUMMARY_FAILS})
- artifact: ${REVIEW_OUT}

> **R7 gate:** the recorded line in the plan preamble is the authority.
> The bootstrap script surfaces the review metadata here so subsequent
> sessions don't need to re-run the reviewer.
EOF
  fi
fi

# HANDOFF.md
HANDOFF="$EXEC_DIR/HANDOFF.md"
if [[ ! -f "$HANDOFF" ]]; then
  cat > "$HANDOFF" << EOF
# Handoff — $PROJECT_NAME

**Written:** $NOW

## Bootstrap
Read in order:
1. zed_plans/<plan_file>.md — OBJECTIVE + current task section only
2. agent_planning/execution/$PROJECT_NAME/SESSION_BRIEF.md
3. agent_planning/execution/$PROJECT_NAME/TASK_QUEUE.md

## Where We Are
_(Fill in: what has been done, what is not done.)_

## Next Action
_(Fill in: specific action — command, file edit, or verification step.)_

## Known Blockers / Gotchas
- _(none yet)_
EOF
  echo "  created: HANDOFF.md"
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
  if [[ "$R7_GATE_RAN" -eq 0 ]]; then
    echo "R7 recorded-line gate: SKIPPED — [--skip-r7-gate] in effect"
  fi
fi
echo "Next steps:"
echo "  1. Open the plan and copy all task names into TASK_QUEUE.md"
echo "  2. Fill in the Objective and Next Action in SESSION_BRIEF.md"
echo "  3. Mark Task 1 as 'doing' in TASK_QUEUE.md before starting work"
echo "  4. After code tasks / every 3-task sprint: agent_planning/scripts/quality_gate.sh <paths>"
