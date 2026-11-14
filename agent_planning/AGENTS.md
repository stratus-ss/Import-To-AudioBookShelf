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
4. **If plan produces a browser-rendered UI:** `agent_planning/addenda/web.md` — MANDATORY. Every web-related plan must include a Playwright functional-test task (R14); an operator browser checklist is not a substitute.
5. `agent_planning/deepseek/MODEL_ADDENDUM.md` or `agent_planning/minimax/MODEL_ADDENDUM.md` — model-specific tuning notes
6. **If plan produces code:** check `agent_planning/openspec/specs/` for existing behavioral specs — create the directory if it doesn't exist
7. `agent_planning/LOCAL_RULES.md` (when present) — repo-local rules that survive the framework sync and bind plan content where they apply

## Prompt Templates

`agent_planning/prompts/README.md` — copy-paste prompts for plan authoring and execution sessions.

## Plan Storage

Plans go in `./zed_plans/{descriptive_name}_{YYYY-MM-DD}.md` at the repository root (per `agent_planning/PLAN_CORE.md` §8). This is non-negotiable regardless of where implementation artifacts are placed — implementation can be nested under `./my_project/` or anywhere else, but the plan itself lives in `zed_plans/`.

## Execution Tracking

`agent_planning/EXECUTION_PROTOCOL.md` — session bootstrap, state writeback, chunked execution rules.
`agent_planning/execution/<project_name>/` — SESSION_BRIEF, HANDOFF, TASK_QUEUE, devlogs for active work.

## Before Task 1 (code-producing plans)

1. `agent_planning/scripts/plan_lint.sh [--require-full-tasks] <plan.md>` must exit 0 (fix the plan on failure). Forward-only on existing corpus (`zed_plans/*.md`) — pre-adoption Phase 1 failures are tolerated.
2. **Authoring closeout:** run the reconciliation pass (PLAN_CORE §8.6; template in `prompts/README.md`), then the authoring self-check: `agent_planning/scripts/plan_selfcheck.sh [--rerun] [--verify-paths] <plan.md>` — catches near-duplicate bullets, bare line-number coordinates, interface changes with no dependent enumeration, unbacked provenance marks, and absolute/negative acceptance checks with no baseline result (R9). `--verify-paths` additionally flags backticked path citations that no longer resolve (archived/renamed/phantom) — advisory, and it reports `moved` vs `not-found`. Run it so the deterministic layer catches mechanical defects before execution. `--rerun` re-executes whitelisted `✅ TESTED` commands (a command that cannot run at authoring time must be marked `⚠️ UNTESTED`, not `✅ TESTED`); the rerun asserts exact-count re-execution against the live output for any plan line stating `→ N lines|hits|matches|occurrences|results|files|rows|entries`, exempts `✅ VERIFIED-ABSENT` and `⚠️ UNTESTED` lines, and skips explanatory spans containing `...`. Mark a tested absence `✅ VERIFIED-ABSENT`, never `✅ TESTED`.
3. **Plan validation gate (Tier 2/3 only — R7, PLAN_CORE §8.7):** dispatch the clean-context `plan-validator` subagent. Copy `agent_planning/reviewer/plan-validator.md` to `.opencode/agents/plan-validator.md` and dispatch it with the plan path, your model id, and the `PLAN_CORE.md` path (§12 is its rubric). Do **not** pass your transcript or discovery rationale. Zero FAIL rows before bootstrap; remediate, then re-dispatch once. Record the validation line in the plan preamble. Model is pinned (`opencode/deepseek-v4.1-flash#max` — operator choice 2026-10-25; a DeepSeek-authored plan yields Row 0 `ADVISORY`, clean-context only). Tier 1 plans: skip.
4. `agent_planning/scripts/init_execution_dir.sh <project> --plan <plan.md>` — runs `plan_lint.sh` (fail-closed) and creates the execution directory. The R7 validation gate is agent-side (step 3), not a bootstrap script gate. Phase-2 lint checks (`P8d`–`P8j`) are **diagnostic only**: run `plan_lint.sh --report-phase2` directly if you want their findings; bootstrap does not enforce them.
5. After code tasks / sprint boundaries: `agent_planning/scripts/quality_gate.sh <paths>`

**Plan validation is never a self-validation.** After lint and selfcheck pass (Tier 2/3), dispatch a clean-context `plan-validator` subagent — you authored the plan, and the reasoning that produced a defect is the reasoning that failed to notice it. Copy `agent_planning/reviewer/plan-validator.md` to `.opencode/agents/plan-validator.md`; pass the plan path, your model id, and the `PLAN_CORE.md` path; never your transcript or DR rationale. Record `Plan validation: 0 FAIL, N ADVISORY — plan-validator (opencode/deepseek-v4.1-flash#max) on YYYY-MM-DD` in the plan preamble. Contract: `PLAN_CORE.md §8.7`; independence rule: `EXECUTION_PROTOCOL.md §9.0`. If no subagent dispatch is available, mark the plan `⚠️ UNTESTED (validation)` with a `[SCOPE-GAP]` — never self-validate and never mark an unvalidated plan ready.

**The Playwright pass is never self-run.** Web plans (R14) dispatch a
clean-context `playwright-tester` subagent, not an author-run test — the author
already believes the feature works and will tune the test until it agrees. Copy
`agent_planning/reviewer/playwright-tester.md` to
`.opencode/agents/playwright-tester.md`. Model is pinned
(`opencode-go/minimax-m3.1-flash#medium`, falling back to
`alibaba-token-plan/deepseek-v4.1-flash-1017#high` when the primary is unavailable **or is the
authoring model** — there is no `fallback-model` key; re-dispatch with an explicit
`model` argument). Record `TESTER:` / `DISPATCH:` / `ROW0:` / `BLOCKING:` in the
devlog. Contract: `addenda/web.md` W2.1/W2.2; rule: `EXECUTION_PROTOCOL.md §9.0`.

**Code Review is never a self-review.** When a plan's Code Review task comes up, dispatch a **clean-context subagent** — you did not write that code, and the reasoning that produced a defect is the reasoning that failed to notice it. Copy `agent_planning/reviewer/code-reviewer.md` to `.opencode/agents/code-reviewer.md` and dispatch it with the plan path, the in-scope file list, the per-category verification commands, and the binding STOP RULES — **do not** pass your transcript or rationale. Model is pinned (`alibaba-token-plan/deepseek-v4.1-flash-1017#max`, falling back to `opencode-go/minimax-m3.1-flash#medium` when the primary is unavailable **or is the authoring model** — re-dispatch with an explicit `model` argument; operator choice 2026-10-25). Record the `REVIEWER:` / `DISPATCH:` / `FINDINGS:` / `BLOCKING:` lines in the devlog. Full contract: `EXECUTION_PROTOCOL.md §9.0`; authoring rule: `code-quality.md §CQ9.2`. If no subagent dispatch is available, mark the review `⚠️ UNTESTED` with a `[SCOPE-GAP]` — never mark a self-reviewed Code Review task `done`.

**Two rounds maximum per gate — then hand back.** Code Review and Playwright each get **2 rounds** (initial dispatch + one re-review after remediation); the two budgets are separate. A re-check, a re-dispatch on another model, and a re-run "just to confirm" all count as rounds. If round 2 is still blocking: record `ROUND: 2/2 · <gate> · BLOCKING <n>` and the findings verbatim, mark the task `⚠️ BLOCKED (loop cap — <gate>, 2 rounds)`, add a `Loop cap hit` section to HANDOFF, and stop the session. No third round without an explicit operator override logged as `LOOP-CAP OVERRIDE:`. A cap stop is **not** a promotion — "ready to ship with N open findings" is a defect, and elapsed time is not a pass. Contract: `EXECUTION_PROTOCOL.md §9`, Review Loop Cap; Playwright half: `addenda/web.md` W2.4.

**Optional plan review (separate tool, not the R7 gate):** `agent_planning/scripts/plan_review.sh <plan.md> --model <provider/name> --out <out.json> --approved` runs a cross-model semantic review exactly once, at the operator's discretion. It prints a preflight cost estimate and refuses to run without `--approved`. It also **refuses to run unattended** — an agent-run shell has no TTY, so an agent cannot start a review on its own; the operator runs it from a terminal (or sets `PLAN_REVIEW_AUTORUN=1` to accept headless spend). Disable it entirely with `PLAN_REVIEW_DISABLED=1` or a sentinel file `agent_planning/execution/.no-plan-review`. It never blocks Task 1 and no `plan_review.sh` result is recorded in the plan preamble (the mandatory R7 gate is the `plan-validator` subagent dispatch above — a different mechanism).
