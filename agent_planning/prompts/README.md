# Plan Authoring — Standard (Agent picks model and addendum)

Use this when you are not specifying the model. The agent reads the index and selects the domain addendum.

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/INDEX.md — select and read the matching domain addendum.
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

---

# Plan Authoring — Claude (Opus 4.6 or Sonnet 5)

Use this when running the plan with Claude Opus 4.6 (complex Tier 2/3 plans) or Claude Sonnet 5 (standard plans).

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/INDEX.md — select and read the matching domain addendum.
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.
Read @agent_planning/deepseek/MODEL_ADDENDUM.md for thinking configuration and granularity guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

# Plan Authoring — Claude (explicit addendum)

Use this when you already know which domain addendum applies and want to skip the INDEX routing.

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/<ADDENDUM>.md   ← one of: software | infrastructure | automation | pipeline
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.
Read @agent_planning/deepseek/MODEL_ADDENDUM.md

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

---

# Plan Authoring — GPT 5.4

Use this when running the plan with GPT 5.4.

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/INDEX.md — select and read the matching domain addendum.
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.
Read @agent_planning/minimax/MODEL_ADDENDUM.md for reasoning effort configuration and context budget guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

# Plan Authoring — GPT 5.4 (explicit addendum)

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/<ADDENDUM>.md   ← one of: software | infrastructure | automation | pipeline
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.
Read @agent_planning/minimax/MODEL_ADDENDUM.md

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

---

# Plan Authoring — Codex (GPT-5.3-Codex)

Use this for agentic long-horizon coding tasks executed in the Codex environment.

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/software.md
If the project has existing specs: check agent_planning/openspec/specs/ before authoring tasks.
Read @agent_planning/addenda/code-quality.md before authoring tasks.
Read @agent_planning/minimax/MODEL_ADDENDUM.md for Codex context limits and AGENTS.md guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence — Tier 2/3 is DR-grilling: work the
DR set as a dependency frontier, and carry Owner + Options + a Recommendation
(strength: strong|weak|none) on every DR. Do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
```

---

# Plan Reconciliation — same session (authoring closeout)

Run after the plan draft is complete and before `plan_selfcheck.sh` /
`plan_lint.sh` — one pass, same session (`PLAN_CORE.md` §8.6). Paste:

```
You are the RECONCILER, not the author. One objective: make every claim in
@zed_plans/YOUR_PLAN.md true against the working tree. Do not review style, do
not grade, do not change scope. Read-only checks only; no writes.

Checklist:
1. Re-run every cited command (or its closest safe equivalent); reconcile the output.
2. Re-count every stated number.
3. Re-resolve every cited path and symbol.
4. Re-run every enumeration; diff the live set against the plan's list.
5. Re-check every absolute/negative baseline (R9).
6. Quote the consumer's expected representation for every cross-task value (R12).
7. Resolve every provenance mark against its backing evidence.

Downgrade anything unverifiable to ❌ ASSUMED or ⚠️ UNTESTED with a reason.
Output: findings first (claim / expected / actual / evidence command / severity),
then the fixes. Finish by recording one preamble line:
`Reconciliation: N claims verified, M corrected (YYYY-MM-DD)` — or
`Reconciliation: N/A — no repo-state claims`.
```

---

# Execution — First Session

```
Read @agent_planning/EXECUTION_PROTOCOL.md
Read @zed_plans/<PLAN_FILE>.md

This is the first session. Before starting Task 1:
1. Determine the project_name from the plan's OBJECTIVE section
2. Run plan lint (MUST exit 0 — do not code if it fails):
   agent_planning/scripts/plan_lint.sh --require-full-tasks zed_plans/<PLAN_FILE>.md
3. Tier 2/3 only — R7 plan validation gate (PLAN_CORE.md §8.7):
   DISPATCH a clean-context plan-validator subagent — you do NOT validate
   your own plan. Copy agent_planning/reviewer/plan-validator.md to
   .opencode/agents/plan-validator.md, then pass it: the plan path, your
   model id, and the PLAN_CORE.md path (§12 is its rubric). Do NOT pass
   your transcript or discovery rationale. Zero FAIL rows before
   bootstrap; remediate, then re-dispatch once. Record in the plan
   preamble: Plan validation: 0 FAIL, N ADVISORY — plan-validator
   (opencode/deepseek-v4.1-flash#max) on YYYY-MM-DD. Tier 1: skip.
4. Bootstrap with the plan attached:
   agent_planning/scripts/init_execution_dir.sh <PROJECT_NAME> --plan zed_plans/<PLAN_FILE>.md --require-full-tasks
5. Open agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md and populate
   it with all tasks from the plan
6. Fill in the Objective and Next Action in STATE.md
7. Confirm the directory is initialized, then begin Task 1

After each task, perform the Section 4 writeback before proceeding.
Do not skip writeback when a task fails or is blocked.
After every code task (and every 3-task sprint): agent_planning/scripts/quality_gate.sh <modified_paths>

CODE REVIEW (per code-quality.md §CQ9.2 / EXECUTION_PROTOCOL.md §9.0):
  When you reach the Code Review task:
  - Complete ALL authoring/implementation/testing tasks first
  - For deployment plans, the Code Review task comes BEFORE the first
    deploy/apply task — do not deploy until the review passes (§CQ9.6 / R6)
  - Perform full state writeback
  - DISPATCH a clean-context reviewer subagent — you do NOT review your own
    code. Copy agent_planning/reviewer/code-reviewer.md to
    .opencode/agents/code-reviewer.md, then pass it: the plan path + Code
    Review task section, the exact in-scope file list, the per-category
    verification commands, the binding STOP RULES, and the path to
    EXECUTION_PROTOCOL.md §9. Do NOT pass your transcript or rationale —
    that context is the blind spot.
  - Use a different model for the reviewer than for the authoring (the
    default cross-model property; override only on operator request)
  - Block on the reviewer's findings table before applying any remediation
  - Record the dispatch in the devlog:
      REVIEWER: <agent id> · model <provider/model#variant> ·
               author <provider/model#variant> · context: subagent (clean)
      DISPATCH / ROW 0 / FINDINGS / BLOCKING
    ROW 0 is the reviewer's own independence row, quoted verbatim. An unpinned
    reviewer inherits the authoring model silently — Row 0 is how that is caught.
  - If no subagent dispatch is available, the review is ⚠️ UNTESTED with a
    [SCOPE-GAP] — never mark a self-reviewed Code Review task done
  - TWO ROUNDS MAXIMUM (EXECUTION_PROTOCOL.md §9 "Review Loop Cap"). Code Review
    and Playwright each get 2 rounds; the budgets are separate. If round 2 is
    still blocking: log `ROUND: 2/2 · <gate> · BLOCKING <n>` + the findings,
    mark the task `⚠️ BLOCKED (loop cap — <gate>, 2 rounds)`, add a `Loop cap
    hit` section to HANDOFF, and STOP. No third round without an explicit
    operator override (`LOOP-CAP OVERRIDE:` in the devlog). A cap stop is not a
    promotion — never follow it with "ready to ship/promote".
```

# Execution — Resume Session

```
Read @agent_planning/EXECUTION_PROTOCOL.md
Read @agent_planning/execution/<PROJECT_NAME>/STATE.md
Read @agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md

Follow the bootstrap sequence in Section 3. Resume from where
STATE.md "Next Action" or "Where We Are" says to continue. After each task, perform the
Section 4 writeback before proceeding.
```

# Execution — Resume After Blocker Resolved

```
Read @agent_planning/EXECUTION_PROTOCOL.md
Read @agent_planning/execution/<PROJECT_NAME>/STATE.md
Read @agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md

The previously blocked task is now unblocked because: <REASON>.
Update the TASK_QUEUE.md status from blocked to doing, then
resume execution. After each task, perform the Section 4 writeback.
```
