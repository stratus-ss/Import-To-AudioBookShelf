# Agent Guidance

This project uses the `agent_planning/` framework for structured plan authoring and execution.

## Small / Obvious Tasks (Tier 1)

For single-file edits, bugfixes, or tasks with fewer than 5 steps and no deployment risk, use the condensed path (`agent_planning/TIER1_FASTPATH.md` contains the full eligibility criteria):

`agent_planning/TIER1_FASTPATH.md` — quick interview + minimal task template, no addendum required.

## Before Planning Any Non-Trivial Task

Read in this order:
1. `agent_planning/PLAN_CORE.md` — universal planning protocol
2. `agent_planning/addenda/INDEX.md` — select and read the matching domain addendum
3. **If plan produces code:** `agent_planning/addenda/code-quality.md` and `agent_planning/addenda/file-budget.md` — MANDATORY. Plan will be rejected if CQ or file-budget requirements are missing.

4. `agent_planning/deepseek/MODEL_ADDENDUM.md` or `agent_planning/minimax/MODEL_ADDENDUM.md` — model-specific tuning notes
5. **If plan produces code:** check `agent_planning/openspec/specs/` for existing behavioral specs — create the directory if it doesn't exist

## Prompt Templates

`agent_planning/prompts/README.md` — copy-paste prompts for plan authoring and execution sessions.

## Plan Storage

Plans go in `./zed_plans/{descriptive_name}_{YYYY-MM-DD}.md` at the repository root (per `agent_planning/PLAN_CORE.md` §8). This is non-negotiable regardless of where implementation artifacts are placed — implementation can be nested under `./my_project/` or anywhere else, but the plan itself lives in `zed_plans/`.

## Execution Tracking

`agent_planning/EXECUTION_PROTOCOL.md` — session bootstrap, state writeback, chunked execution rules.
`agent_planning/execution/<project_name>/` — SESSION_BRIEF, HANDOFF, TASK_QUEUE, devlogs for active work.

## Before Task 1 (code-producing plans)

1. `agent_planning/scripts/plan_lint.sh [--require-full-tasks] <plan.md>` must exit 0 (fix the plan on failure). Forward-only on existing corpus (`zed_plans/*.md`) — pre-adoption Phase 1 failures are tolerated.
2. **Authoring self-check (before the reviewer):** `agent_planning/scripts/plan_selfcheck.sh [--rerun] <plan.md>` — catches near-duplicate bullets, bare line-number coordinates, interface changes with no dependent enumeration, unbacked provenance marks, and absolute/negative acceptance checks with no baseline result (R9). Run it first so the R7 reviewer confirms rather than discovers mechanical defects. `--rerun` re-executes whitelisted `✅ TESTED` commands (a command that cannot run at authoring time must be marked `⚠️ UNTESTED`, not `✅ TESTED`); the rerun asserts exact-count re-execution against the live output for any plan line stating `→ N lines`, exempts `✅ VERIFIED-ABSENT` and `⚠️ UNTESTED` lines, and skips explanatory spans containing `...`. Mark a tested absence `✅ VERIFIED-ABSENT`, never `✅ TESTED`.
3. **R7 pre-execution semantic review (REQUIRED for high-risk plans; optional with audit-trail waiver for ordinary local Tier 2):** run `agent_planning/scripts/plan_review.sh <plan.md> --out <out.json>` before bootstrap and record the reviewer model, date, grade, score, and finding count in the plan preamble under "Recorded R7 review + operator gate" (see `PLAN_CORE.md` §2 R7 and §12 R7 checklist item). Resolve any `FAIL` finding before Task 1. The narrow trigger is: REQUIRED for Tier 3 plans and for Tier 2 plans that touch a remote system, a public interface, a schema/migration, secrets, or more than one repo; OPTIONAL (with `--r7-waived` recording `R7 waived (narrow trigger)`) for local, non-public, deterministically verified Tier 2 plans.
4. `agent_planning/scripts/init_execution_dir.sh <project> --plan <plan.md>` — this script runs the reviewer in advisory mode if Step 3 was skipped, but the recorded-line gate must still be met before bootstrap. Phase-2 lint checks (`P8d`–`P8j`) are **diagnostic only**: run `plan_lint.sh --report-phase2` directly if you want their findings; bootstrap does not enforce them.
5. After code tasks / sprint boundaries: `agent_planning/scripts/quality_gate.sh <paths>`
