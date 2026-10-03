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
  echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--skip-plan-lint] [--skip-r7-gate] [--r7-waived]" >&2
  exit 1
fi

PROJECT_NAME="$1"
shift

PLAN=""
REQUIRE_FULL=0
SKIP_PLAN_LINT=0
ALLOW_NON_CODE=0
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
      echo "Usage: $0 <project_name> [--plan <plan.md>] [--require-full-tasks] [--allow-non-code] [--skip-plan-lint] [--skip-r7-gate] [--r7-waived]" >&2
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

  # ── Deterministic R7 recorded-line gate (DR-2; narrow trigger per R7) ────
  # R7 requires the plan preamble to record the semantic-review line before
  # Task 1 for Tier 3 plans and for Tier 2 plans that touch a remote system,
  # a public interface, a schema/migration, secrets, or more than one repo.
  # Local, non-public, deterministically verified Tier 2 plans may waive
  # R7 via --r7-waived (records "R7 waived (narrow trigger)" so the gate
  # stays auditable). The reviewer tool itself is advisory; THIS
  # deterministic check is the gate. Refuse bootstrap when the line is
  # absent or records an unresolved FAIL. Override with --skip-r7-gate
  # (log as [SCOPE-GAP]).
  if [[ "$SKIP_R7_GATE" -eq 1 ]]; then
    echo "[init_execution_dir] WARN — skipping R7 recorded-line gate (--skip-r7-gate). Log as [SCOPE-GAP]."
  elif [[ "$R7_WAIVED" -eq 1 ]]; then
    echo "[init_execution_dir] R7 recorded-line gate: WAIVED (--r7-waived; narrow-trigger Tier 2 plan)"
    echo "TELEMETRY r7_waived project=$PROJECT_NAME tier=2 narrow_trigger=true" >&2
    R7_GATE_RAN=0
  else
    # Capture from the marker to the next `## ` heading or EOF (not a fixed
    # window), so a long review block cannot hide the FAIL count.
    r7_block="$(awk '/Recorded R7 review|R7 review line/{f=1} f && /^## / && !/Recorded R7|R7 review line/{exit} f{print}' "$PLAN")"
    if [[ -z "$r7_block" ]]; then
      echo "[init_execution_dir] FAIL — no recorded R7 review line in the plan preamble (R7 gate)." >&2
      echo "  Run plan_review.sh, record the line under 'Recorded R7 review + operator gate', then re-run." >&2
      exit 1
    fi
    if printf '%s\n' "$r7_block" | rg -q '[1-9][0-9]* FAIL\b'; then
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
    if timeout "${PLAN_REVIEW_TIMEOUT:-1500}" "$SCRIPT_DIR/plan_review.sh" "$PLAN" --out "$REVIEW_OUT" >/dev/null 2>&1; then
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
      # Preserve any existing R7 Review Summary section if present
      if [[ -f "$EXEC_DIR/SESSION_BRIEF.md" ]]; then
        if grep -q '^## R7 Review Summary' "$EXEC_DIR/SESSION_BRIEF.md"; then
          echo ""
          awk '/^## R7 Review Summary/{flag=1; print; next} flag && /^## /{flag=0} flag{print}' "$EXEC_DIR/SESSION_BRIEF.md"
        fi
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
  # Append the R7 review summary to the just-created STATE.md.
  # The recorded-line R7 gate is enforced by the agent reading the preamble;
  # the bootstrap script just surfaces the review metadata for downstream
  # sessions. Only append when --plan was supplied and the reviewer actually
  # ran (the no-plan path has no review to surface).
  if [[ -n "$PLAN" ]]; then
    if [[ "$R7_WAIVED" -eq 1 ]]; then
      cat >> "$STATE_FILE" << EOF

## R7 Review Summary

- reviewer: (waived — narrow-trigger Tier 2 plan; --r7-waived)
- grade: n/a
- score: n/a
- findings: 0 (FAIL=0)
- artifact: (none)

> **R7 waived (narrow trigger).** Per PLAN_CORE.md R7, this plan is a local,
> non-public, deterministically verified Tier 2 plan that is exempt from the
> pre-execution semantic-review gate. The waiver is recorded here so the gate
> stays auditable.
EOF
    else
      cat >> "$STATE_FILE" << EOF

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
echo "  2. Fill in the Objective and Next Action in STATE.md"
echo "  3. Mark Task 1 as 'doing' in TASK_QUEUE.md before starting work"
echo "  4. After code tasks / every 3-task sprint: agent_planning/scripts/quality_gate.sh <paths>"

# ── Telemetry hook (Task 11) ──────────────────────────────────────────────
# Appends one JSONL line per run to agent_planning/execution/_telemetry.jsonl.
# Local-only append; no network; secrets are never recorded. See TELEMETRY.md.
emit_telemetry() {
  local r7_outcome="recorded"
  if [[ "$SKIP_R7_GATE" -eq 1 ]]; then r7_outcome="skipped"; fi
  if [[ "$R7_WAIVED" -eq 1 ]]; then r7_outcome="waived"; fi
  local deviations=$(( SKIP_PLAN_LINT + SKIP_R7_GATE ))
  local round_trips=0
  local state_writes=0
  [[ -f "$STATE_FILE" ]] && state_writes=$((state_writes + 1))
  [[ -f "$TASK_QUEUE" ]] && state_writes=$((state_writes + 1))
  local recovery_success=0
  [[ -f "$STATE_FILE" ]] && recovery_success=1
  local sink="$FRAMEWORK_DIR/execution/_telemetry.jsonl"
  python3 - "$PROJECT_NAME" "$r7_outcome" "$deviations" "$round_trips" "$state_writes" "$recovery_success" "$PLAN" "$sink" <<'PYTELEMETRY' || true
import json, os, sys, datetime
project = sys.argv[1]
r7_outcome = sys.argv[2]
deviations = int(sys.argv[3])
round_trips = int(sys.argv[4])
state_writes = int(sys.argv[5])
recovery_success = bool(int(sys.argv[6]))
plan = sys.argv[7]
sink = sys.argv[8]
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
    "r7_outcome": r7_outcome,
    "plan": plan,
}
os.makedirs(os.path.dirname(sink), exist_ok=True)
with open(sink, "a") as f:
    f.write(json.dumps(record) + "\n")
PYTELEMETRY
}
emit_telemetry
