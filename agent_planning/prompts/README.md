# Plan Authoring — Standard (Agent picks model and addendum)

Use this when you are not specifying the model. The agent reads the index and selects the domain addendum.

```
I need a plan to <GOAL>.

Read @agent_planning/PLAN_CORE.md and follow it exactly.
Read @agent_planning/addenda/INDEX.md — select and read the matching domain addendum.
If the selected addendum supports OpenSpec (software or pipeline): check for project specs per its spec section before authoring tasks.
If the selected addendum produces executable code (software, pipeline, automation with function nodes, infra with scripts): also read @agent_planning/addenda/code-quality.md.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
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
Read @agent_planning/claude/MODEL_ADDENDUM.md for thinking configuration and granularity guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
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
Read @agent_planning/claude/MODEL_ADDENDUM.md

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
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
Read @agent_planning/openai/MODEL_ADDENDUM.md for reasoning effort configuration and context budget guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
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
Read @agent_planning/openai/MODEL_ADDENDUM.md

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
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
Read @agent_planning/openai/MODEL_ADDENDUM.md for Codex context limits and AGENTS.md guidance.

Start with the tiered discovery protocol (Section 0). Classify the tier,
run the appropriate DR/interview sequence, and do not write tasks until
I have confirmed the Discovery Summary restatement.

project_name for execution artifacts: <PROJECT_NAME>
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
3. Bootstrap with the plan attached:
   agent_planning/scripts/init_execution_dir.sh <PROJECT_NAME> --plan zed_plans/<PLAN_FILE>.md --require-full-tasks
4. Open agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md and populate
   it with all tasks from the plan
5. Fill in the Objective and Next Action in SESSION_BRIEF.md
6. Confirm the directory is initialized, then begin Task 1

After each task, perform the Section 4 writeback before proceeding.
Do not skip writeback when a task fails or is blocked.
After every code task (and every 3-task sprint): agent_planning/scripts/quality_gate.sh <modified_paths>

CODE REVIEW PAUSE (per code-quality.md §CQ9.2):
  When you reach the Code Review task:
  - Complete ALL authoring/implementation/testing tasks first
  - For deployment plans, the Code Review task comes BEFORE the first
    deploy/apply task — do not deploy until the review passes (§CQ9.6 / R6)
  - Perform full state writeback
  - Announce the model-switch gate and WAIT for user confirmation
  - Do NOT begin the review task until the user responds
```

# Execution — Resume Session

```
Read @agent_planning/EXECUTION_PROTOCOL.md
Read @agent_planning/execution/<PROJECT_NAME>/SESSION_BRIEF.md
Read @agent_planning/execution/<PROJECT_NAME>/HANDOFF.md
Read @agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md

Follow the bootstrap sequence in Section 3. Resume from where
HANDOFF.md says to continue. After each task, perform the
Section 4 writeback before proceeding.
```

# Execution — Resume After Blocker Resolved

```
Read @agent_planning/EXECUTION_PROTOCOL.md
Read @agent_planning/execution/<PROJECT_NAME>/SESSION_BRIEF.md
Read @agent_planning/execution/<PROJECT_NAME>/HANDOFF.md
Read @agent_planning/execution/<PROJECT_NAME>/TASK_QUEUE.md

The previously blocked task is now unblocked because: <REASON>.
Update the TASK_QUEUE.md status from blocked to doing, then
resume execution. After each task, perform the Section 4 writeback.
```
