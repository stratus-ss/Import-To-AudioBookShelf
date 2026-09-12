# Plan Authoring — Core Protocol

_Last updated: 2026-09-10_

This document contains the universal planning discipline that applies to ALL plan types, regardless of domain or model. It is used together with one domain addendum and optionally a model addendum.

**Read in this order:**
1. This file (`PLAN_CORE.md`)
2. `addenda/INDEX.md` → select and read the matching addendum
3. (Optional) the model addendum for your model: `deepseek/MODEL_ADDENDUM.md` or `minimax/MODEL_ADDENDUM.md`

---

## 0. Pre-Plan Interrogation Protocol

> **Tier 1 shortcut:** For single-system, <5 task, no-deployment tasks, `TIER1_FASTPATH.md` may be used instead of this full section.

**This section governs what happens BEFORE any plan is written.** A plan authored without completing this protocol is built on assumptions. Assumptions become silent task failures.

### Role Separation

The AI acts as **architect, planner, and technical expert**. The user is the **Subject Matter Expert (SME)** — the authority on domain knowledge, business context, acceptance criteria, and what "done" looks like.

| Role | Owns |
|------|------|
| AI (Architect) | Technical approach, task decomposition, file structure, implementation patterns, verification strategy, pre-seeding decision records with domain trade-off context |
| User (SME) | Domain rules, business constraints, acceptance criteria, integration requirements, what is in/out of scope, decisions on pre-seeded DRs |

The AI must **never assume domain knowledge**. The user should **not dictate implementation details** unless they have a specific technical reason. Architecture and approach belong to the AI.

### Tier Classification (Choose Before Proceeding)

Before beginning discovery, classify the request into one of three tiers. The tier determines the discovery depth.

| Tier | Trigger | Discovery Method |
|------|---------|-----------------|
| **Tier 1** | Single-system, no remote deployment, <5 tasks. Bugfixes, single-file refactors, documentation, local scripts. | 7-category quick interview + restatement gate |
| **Tier 2** | Remote systems, deployment, monitoring setup, multi-host operations (task count is a heuristic — a single-system deployment stays Tier 2 even above 15 tasks; see the disambiguation below). | Domain-specific Decision Records (DRs) + Discovery Summary + restatement gate |
| **Tier 3** | Multi-system integrations where 3+ independent systems must coordinate, multi-phase migrations with data-at-risk, or projects where a dependency graph between DRs is non-trivial (DRs gate other DRs). | Full grouped DRs + dependency graph + Architecture Summary + restatement gate |

When in doubt, choose the higher tier. The cost of under-scoping discovery is tasks that silently fail on unresolved assumptions.

---

### Tier 1: Quick Discovery

Conduct a structured interview across these seven categories. Every category must be addressed or explicitly marked "deferred — not in scope" before authoring begins:

| # | Category | What to Extract |
|---|----------|-----------------|
| 1 | **Scope boundaries** | What is IN this plan. What is explicitly OUT. What is deferred. |
| 2 | **User/actor definition** | Who uses the output. What are their roles and permissions. |
| 3 | **Data shape** | Inputs, outputs, formats, volumes, sources, transformations. |
| 4 | **Edge cases and failure modes** | What happens when X is missing, wrong, or unavailable. |
| 5 | **Integration points** | What existing systems, services, or files does this touch or depend on. |
| 6 | **Acceptance criteria** | How does the user know the plan succeeded. Concrete pass/fail conditions. |
| 7 | **Unstated constraints** | Deadlines, hardware limits, team conventions, regulatory requirements, things the user considers obvious. |

After the interview, produce the Restatement Gate (see below). No DRs required.

---

### Tier 2: Domain Discovery

**The AI pre-seeds Decision Records (DRs) with domain trade-off context. The user provides the decisions.**

This mirrors how a Red Hat architect interrogates a client before an engagement: the architect writes the Issue (explaining what is at stake and why the decision is irrevocable or consequential), and the client fills in the Decision. The client is not expected to know the right questions — the architect does.

#### Decision Record Format

```
DR-N: [Short title]
Issue: [2-5 sentences written by the AI explaining: what this decision controls,
        what the failure mode is if the wrong choice is made, what the options are,
        and why this must be decided before task authoring begins.]
Decision: [User provides]
Assumptions: [User provides any assumptions that condition the decision]
Dependencies: [DR-N, DR-M -- other DRs this one depends on, or "none"]
```

#### How to Generate DRs

The AI reads the user's request and produces DRs for every decision that:
- Is **irrevocable** or **expensive to change** after execution begins
- Involves a **trade-off** the user may not be aware of
- Has **silent failure modes** if the wrong assumption is made
- Creates **dependency ordering** issues for other tasks

DRs are organized by domain area (storage, auth, rollback, scope, integration), not generic categories. Each DR's Issue is written by the AI — the user only provides Decision and Assumptions.

**DR count is variable.** Generate as few or as many DRs as the project requires. Do not pad to a round number. A DR that does not meet any of the four criteria above is filler and must be cut.

**Present all DRs in a single message** with clear numbered IDs. Ask the user to respond with decisions keyed to each ID. Humans read sequentially and can handle a batch; multiple round-trips waste time.

#### Discovery Summary

After all DRs are resolved, produce a Discovery Summary of 2-3 paragraphs covering: what the plan will do, what is explicitly out of scope, and how success is measured. This becomes the seed for the plan's OBJECTIVE and PROJECT CONTEXT sections.

```
## Discovery Summary

[What the plan achieves, with DR decisions folded in concretely.]

[Explicit scope boundary: IN scope / NOT in scope / deferred.]

[Success criteria: concrete pass/fail conditions.]
```

The Restatement Gate (below) applies to the Discovery Summary. Plan authoring is blocked until the summary is confirmed.

---

### Tier 3: Major Project Discovery

Tier 3 extends Tier 2 with two additions:

**1. Grouped DRs with explicit dependency graph.** DRs are organized into domain sections (Storage & Deployment, Network & Access, Migration, Rollback & Operations). After all DRs are resolved, the AI produces a dependency graph showing which decisions gate which tasks.

**2. Architecture Summary (mini-HLD).** After DRs are resolved, the AI produces a 1-2 page Architecture Summary describing the end-state system, integration points, and data flows. This is reviewed and confirmed before any task decomposition begins.

```
## Architecture Summary

### End State
[Description of the deployed system after all tasks complete.]

### Integration Points
[Every system the plan touches, with direction of dependency.]

### Data Flows
[How data moves between systems, with protocols and auth model.]

### Decision Dependencies
[Which DRs gate which phases of task execution.]
```

Plan authoring is blocked until both the Architecture Summary and Restatement Gate are confirmed.

**Tier 2 vs Tier 3 disambiguation:** A single-system deployment with a local orchestrator script is Tier 2 even if it has >15 tasks. Tier 3 is reserved for cases where decisions in one system constrain decisions in another.

**Plan-file embedding requirement:** The Architecture Summary (End State / Integration Points / Data Flows / Decision Dependencies) and the DR→task gating map are **required plan-file sections**, not chat output. The reviewer can confirm them only if they are present in the plan under `ARCHITECTURE SUMMARY` and `DECISION RECORDS` (with the gating map recorded in DECISION RECORDS or immediately under ARCHITECTURE SUMMARY). Plans that produce this content only in chat are non-compliant with R5 evidence-cited and R7 reviewer gate.

---

### The Restatement Gate (All Tiers)

Before writing any task, the AI MUST produce a restatement of the form:

> **What I understand:** [2-3 sentence summary of what the plan will achieve, what it will NOT do, and how success is measured.]
>
> **Does this match your intent?**

If the user corrects the restatement, another round of questions or DR revision follows. **Plan authoring is blocked until the restatement is confirmed.**

---

## 1. Plan Structure

Every plan MUST have these top-level sections in order:

### OBJECTIVE
One paragraph explaining what the plan achieves and why it matters. State the end-state, not the process. For Tier 2/3 plans, this is derived directly from the Discovery Summary produced in Section 0.

**Tier 2/3 plans MUST also declare a `project_name`** immediately after the objective paragraph:

```
project_name: <snake_case_identifier>
```

This identifier is used to locate the execution directory at `agent_planning/execution/<project_name>/`. It must be stable across sessions.

### DECISION RECORDS (Tier 2/3 plans only)

Embed the resolved Decision Records from Section 0 discovery directly in the plan file.

```
## DECISION RECORDS

### DR-1: [Title]
- **Decision:** [What was decided]
- **Rationale:** [Why -- key trade-offs from the Issue field]
- **Assumptions:** [What must be true for this decision to hold]
- **Dependencies:** [none / DR-N, DR-M]
```

**Rules:**
- Include only DRs that were resolved during Section 0 discovery. Open/deferred DRs must be marked as such and must NOT gate any task.
- Every task that was shaped by a DR decision MUST reference the DR in its CONSTRAINTS section.
- Do NOT re-open DR decisions during task authoring. If a task reveals the decision needs revision, surface it to the user before continuing.
- For Tier 1 plans: omit this section entirely.

### ACCESS & CREDENTIAL PREREQUISITES

**Required when the infrastructure addendum is selected.** See `addenda/infrastructure.md` for the full format, rules, and VERIFIED/ASSUMED marking conventions.

### PROJECT CONTEXT
- Language and runtime (e.g., Python 3.12, Go 1.26)
- Key libraries and frameworks
- How the pipeline/workflow operates (1-2 sentences)
- Repository root path
- Key version strings for external tools the plan configures (see addendum for requirements)
- Existing infrastructure on all hosts touched (see addendum for requirements)

### KEY FILES REFERENCE

| File | Purpose |
|------|---------|
| `path/to/file.py` | Brief description of what it does |

This table anchors every task.

### OPERATING MODEL (multi-repo plans — REQUIRED when the plan spans more than one repo)

A plan that edits code in, syncs to, or invokes operations against **more than one git repository** MUST include an Operating Model subsection in PROJECT CONTEXT that states, concretely and without ambiguity:

- **Repo table:** one row per repo with `Repo` (name), `Role` (canonical / downstream mirror / KB doc / external target), and `Absolute path`.
- **Per-command cwd prefix convention:** what unprefixed paths resolve to (default: the repo where `init_execution_dir.sh` runs), and any short prefix that switches cwd (for example `[DDW]` = the second repo).
- **Path-qualification rule for STRUCTURE paths:** every path the executor must open, edit, or run lives in exactly one repo; STRUCTURE paths that cross a repo boundary MUST be qualified with their cwd prefix or absolute path.
- **Mirror prohibition:** never edit a downstream mirror as a source; the canonical framework lives in one repo and reaches downstream only via the sync script.
- **`init_execution_dir.sh` home repo:** which repo's working tree is used for bootstrap and the per-session state files.
- **Downstream blast radius of any sync step:** name every repo the sync script writes to. The sync operator-gate covers the full blast radius, not only the most prominent repo.

Plans that meet any of these conditions are non-compliant without an Operating Model section:
1. The plan's STRUCTURE references absolute paths under more than one repo.
2. The plan includes a `sync_protocol.sh` (or equivalent) invocation.
3. The plan edits a KB doc that lives outside the implementation repo (see AGENTS.md KB writeback rule).

### TASKS
Numbered, ordered list of tasks (see Section 2).

---

## 2. Task Sections

Every task MUST include these sections.

### INTENT
Explain WHY the task exists and what problem it solves.

### STRUCTURE
Define exactly what to create or modify:
- File paths
- Function/method signatures
- Class names
- Output file names or formats

Do not leave architectural decisions to the model.

### SCHEMA (when applicable)
List exact field names, types, and order. Never say "appropriate columns" — enumerate them.

### CONTEXT
Specify data sources with concrete names:
- Struct/class names and field names
- File paths where data originates
- Computation formulas where derivation is needed
- Reference existing patterns by name and path

When the plan's approach intentionally differs from a source document's recommendation, flag it:

**Divergence from [source]:** [what the source recommended] → [what this plan does instead] — [rationale].

### CONSTRAINTS
- Which files to modify (and which NOT to)
- Patterns to follow
- Limits: function length, complexity, no new packages, etc.
- Style requirements not covered elsewhere

### ACCESS PREREQUISITES (infrastructure addendum only)
When a task deploys to a remote system, list reachability requirements before proceeding. See `addenda/infrastructure.md` for full rules.

### NAMING
Define file names, function names, variable conventions, and component names. Without explicit naming, models produce generic names.

### EXAMPLES (optional)
Show concrete good/bad examples where demonstrating a pattern is clearer than describing it.

### No conditional branches

A task MUST NOT contain "if X then do Y, if Z then do W" decision trees. The plan author has product context that the executor does not. Pre-decide every outcome and state it as a directive.

**Bad:**
- "If kvm-api is obsolete, delete it. If it's still used, extract to its own repo."

**Good:**
- "Delete kvm-api/ entirely — it is superseded by kvm-mcp (confirmed with owner)."

### Cross-cutting framework rules (R1–R7)

These rules close non-mechanical gaps that the deterministic lint (P1–P8) cannot catch. They are enforced by the semantic reviewer (R7, DR-2) and by the addenda §checklists.

- **R1 Operator gate for destructive ops.** A plan with any irreversible remote or data mutation MUST include an explicit operator-confirm step between dry-run and apply, written into the plan (not into chat).
- **R2 Async / job-queued API drain.** A plan consuming an API that returns-before-complete MUST specify poll-until-drained with a wall-clock STOP rule and a per-call timeout.
- **R3 API result-schema verification.** A plan consuming a collection result MUST name the element schema (field names) or mark `⚠️ UNTESTED` with a runtime dump step.
- **R4 Referenced skills loaded at authoring.** A task naming a skill MUST transcribe that skill's exact format and constraints into the plan.
- **R5 §12 self-review non-optional, evidence-cited.** Before declaring a plan done, the author records `§12 pass: <n items>` in the plan preamble, where `n` counts only items whose verification claim carries evidence (`✅ VERIFIED via <command> on <YYYY-MM-DD>`, `❌ ASSUMED`, or `⚠️ STALE`). A single aggregate count command does not satisfy the per-item rule, and an item without evidence does not count as passed. If the plan modifies the checklist it measures (a framework plan), re-record `n` at closeout against the post-change file.
- **R6 Pre-deployment review gate.** A plan with a deployment/apply phase MUST place the dedicated Code Review task before the first task that mutates live or remote state, and every deployment task MUST gate on the review passing (code-quality.md §CQ9.6). Non-deployment plans keep the penultimate Code Review placement. A source-repo mirror/distribution sync is not a deployment (see §CQ9.6).
- **R7 Pre-execution semantic review (required, recorded gate).** Before `init_execution_dir.sh` bootstraps (or before Task 1 when bootstrap is skipped), the semantic reviewer runs against the plan and the preamble records a review line naming the reviewer model, date, grade, and finding count. Task 1 is blocked while any finding carries status `FAIL`. The reviewer tool itself stays advisory (non-deterministic output must not hard-block); the recorded-line gate is what makes review required.

### Inter-task data dependencies
When a later task depends on data discovered by an earlier task, the plan author MUST NOT defer the values to runtime with placeholders. Instead:

1. **Enumerate the expected values** from the source material as concrete literals in the later task's STRUCTURE.
2. **Add a stop rule** to the later task: "If live data from Task N differs from this list, stop and report the discrepancy before proceeding."

**Bad:**
- `WHERE na.ip IN (<ghost_IPs_from_preflight>)`

**Good:**
- `WHERE na.ip IN ('10.0.0.101', '10.0.0.102', '10.0.0.103')`
- STOP RULE: "If the ghost IP set from Task 1 differs from this list, stop and report before deleting."

### DON'T
Explicitly list what NOT to do. Always include:
- Don't create new files/packages unless the task says to
- Don't invent new abstractions
- Don't add features not specified
- Don't modify files outside the task scope

### VERIFICATION
Concrete command(s) to confirm the task succeeded:
- `python -m pytest tests/`
- `go build ./...`
- `make lint`
- "Confirm file X exists and contains Y"

Every task's VERIFICATION section MUST end with a **DEVLOG** step that updates the running devlog before proceeding to the next task. This is not optional — it is part of the task's completion criteria. Format:

```
DEVLOG: Update agent_planning/execution/<project_name>/devlogs/{name}_{date}.md
  - Add this task's entry to the Execution Log section
  - Update the Remaining Tasks checklist
  - If this is Task 1, create the devlog file first
```

After the devlog update, also perform the EXECUTION_PROTOCOL.md Section 4 writeback: update TASK_QUEUE.md, SESSION_BRIEF.md, and HANDOFF.md.

### DOC UPDATE (plan-level, MANDATORY)

Every plan that adds or modifies CLI flags, config fields, public interfaces, command behavior, or pipeline steps MUST include at least one task (or a sub-step of the final task) that updates **all stale project documentation**. This is a plan-authoring requirement — the plan author must include it before execution begins.

**Discovery step (run during plan authoring):**
```bash
rg -l '<binary-name>\|<changed-flag>\|<changed-config-field>' README.md AGENTS.md docs/ 2>/dev/null
```

**Trigger:** Any task that changes user-facing behavior — new flags, changed defaults, new config keys, modified interfaces, new subcommands, removed features.

**Files to check and update:**

| Change type | Files to update |
|-------------|-----------------|
| CLI flag added/changed | `README.md` (usage section), `AGENTS.md` (commands section) |
| Config field added/changed | `README.md` (configuration section), `AGENTS.md` (configuration table) |
| Public interface changed | `AGENTS.md` (file structure / interface descriptions) |
| New subcommand or step | `README.md`, `AGENTS.md`, any architecture docs |

**Rules:**
- The doc update task MUST appear in the plan's TASKS list — it is not an afterthought or post-execution cleanup.
- If no project docs exist yet, this rule does not apply.
- The plan-level STOP RULES must NOT prevent the doc update task from executing (e.g., "stop after all 5 tasks" must account for the doc task count).

### OUTPUT (optional but recommended)
Explicit format specification for what the task produces:

```
OUTPUT:
- File: src/parser.py
- Function: def parse_config(path: str) -> Config
- Tests: tests/test_parser.py with test_parse_valid and test_parse_missing
```

---

## 3. Granularity Rules

- Each task MUST have a single, focused goal. One new file, one struct change, one function.
- Tasks MUST be ordered to minimize conflicts — new additions before modifications.
- Target ~50 lines of new/modified code per task. Larger scope risks silent incompletion.
- If a feature needs types + logic + output, that is 3 tasks minimum.
- Every task that adds struct fields MUST have a paired output-wiring task later.

**Model-specific line target relaxation:** See the model addendum for your model (`deepseek/MODEL_ADDENDUM.md` or `minimax/MODEL_ADDENDUM.md`) for whether the 50-line target is relaxed.

---

## 4. Single-Layer Scoping

Tasks execute best when they touch ONE concern layer. Tasks that cross layers risk exhausting attention on early layers and silently skipping later ones.

Identify the layers relevant to your project. Common patterns:

- **Application code:** Types/Models, Collection/Input, Transform/Logic, Output/Presentation, Tests
- **Infrastructure/deployment:** Configuration files, Provisioning scripts, Service definitions, Verification/healthchecks
- **Data pipelines:** Schema, Ingestion, Transformation, Output, Validation

Each task operates on at most ONE layer. If a feature spans layers, split into separate tasks per layer.

---

## 5. Token and Context Management

- Keep plan introductions concise — every token counts.
- Plans should stay within the model's practical planning window.
- For very large plans (>15 tasks, or plans referencing large files), consider splitting into phases for cost predictability.
- **Large file reference rule:** If any single file referenced by the plan's KEY FILES REFERENCE or CONTEXT sections exceeds 500 lines, the plan MUST include an explicit token budget estimate at the top of the OBJECTIVE section. Format: `Token budget: ~XXX K tokens (plan + N files: file1 L lines, file2 M lines)`.
- **Batch-task risk:** When a single task's STRUCTURE describes generating more than 200 lines of output, that task MUST be split into sub-tasks. The risk is attention fragmentation — the model exhausts focus on early details and silently skips later ones.

**Model-specific context window sizes and phasing guidance:** See `deepseek/MODEL_ADDENDUM.md` §D1 or `minimax/MODEL_ADDENDUM.md` §M1.

---

## 6. Consistency Rules

- Plans MUST NOT contain contradictory constraints across tasks.
- If a later task overrides an earlier constraint, state the override explicitly.
- Formatting rules (tables vs bullets, prose vs lists) must be consistent across all tasks.
- Mark approximate values as "(approximate — verify against source)".
- Mark exact values as "(exact — do not deviate)".
- Unmarked numbers are treated as exact.
- **Verification claims MUST be marked with provenance:** `✅ VERIFIED via <command> on <YYYY-MM-DD>` or `❌ ASSUMED (not tested)` or `⚠️ STALE (last verified <date>, may have changed)`. A claim without provenance markup is ASSUMED by default.
- **Repo-state assertions require provenance:** every claim about binary names, target hosts/IPs/URIs, file existence, API signatures, dependency versions, or any other externally observable fact MUST carry `✅ VERIFIED via <command> on <date>` or `❌ ASSUMED`. The plain prose "this binary exists" or "this library is at version X" without provenance is non-compliant and triggers R5 evidence-cited review. The motivating failure is the `wiki-migrate` Makefile claim from the 2026-09-11 soundboard plan — a `grep` would have caught it.
- **Credentials and access URIs:** Bot tokens, API keys, chat IDs, and target IPs that were verified in a prior devlog must cite that devlog by path.

### Command Fidelity (MANDATORY)

Every shell command, API call, query (LogQL, PromQL, SQL), CLI invocation, or configuration snippet embedded in a plan task MUST be provenance-marked:

| Mark | Meaning |
|------|---------|
| `✅ TESTED` | The planner ran this exact command and confirmed it works |
| `📖 FROM-DOCS` | Copied verbatim from official documentation (cite URL or man page) |
| `⚠️ UNTESTED` | Synthesized by the planner — executor must validate before relying on output |

**Rules:**
- Commands without a provenance mark are treated as `⚠️ UNTESTED` by default.
- `⚠️ UNTESTED` commands MUST include a verification step in the task that confirms the command works before using its output for subsequent steps.
- The planner SHOULD test commands when possible. When the planner cannot test (no access to the target host, no API credentials), mark `⚠️ UNTESTED` and add a note explaining why.
- Query languages (LogQL, PromQL) are especially prone to syntax drift between versions. Always cite the docs version when using `📖 FROM-DOCS`.

**What this prevents:** Plans with plausible-looking but broken commands (wrong `grafana-server --version` syntax, invalid LogQL label matchers, wrong Pi-hole API endpoints) that the executor discovers only at runtime.

---

## 7. Prompting Best Practices

### Be specific
Instead of "Create a config parser", say "Create a YAML config parser that reads `config.yaml`, validates required keys `host`, `port`, `database`, and returns a `Config` dataclass with those fields."

### Explain intent
Instead of "Don't use print statements", say "This code runs as a library imported by other modules, so use `logging.getLogger(__name__)` instead of print statements for observability."

### Use examples
Show a concrete good example and a concrete bad example. Models generalize from examples better than from abstract descriptions.

### Negative constraints matter
Models may drift without explicit "don't" lists. Always include what NOT to do.

**Model-specific prompting conventions (thinking/effort modes, reasoning configuration):** See `deepseek/MODEL_ADDENDUM.md` §D2/D6 or `minimax/MODEL_ADDENDUM.md` §M4.

---

## 8. Plan File Conventions

- **Plan documents** are stored in `./zed_plans/` (relative to the repository root). This is non-negotiable regardless of where implementation artifacts are placed.
- **Implementation artifacts** go wherever the user specifies. If the user says "nest files in ./my_project/", the plan goes to `./zed_plans/` and the scripts go to `./my_project/`.
- File naming: `{descriptive_name}_{YYYY-MM-DD}.md` (e.g., `ente_alerts_cleanup_2026-06-04.md`). Always append the date in YYYY-MM-DD format.
- Each plan file is self-contained — it includes all context needed for execution.
- Plans reference templates and existing code by path.

---

## 8.5. Stop Rules

Stop rules tell the executing model when to stop. Without them, models will over-work tasks: adding features that "seemed reasonable," refactoring code outside the task scope, or running extra verification passes not requested.

Stop rules belong in two places:
- **Plan-level:** As a STOP RULES section in the plan preamble, applied globally to the whole execution
- **Task-level:** Inside individual task CONSTRAINTS sections for task-specific limits

### For Plan Authoring (used by the plan author, not the model)

Stop writing tasks when the OBJECTIVE is fully covered end-to-end. Do not add tasks because they are "nice to have," "related," or "probably expected." The interrogation restatement (Section 0) is the scope boundary.

### Paste-Ready Templates

**For research tasks:**
```
STOP RULES:
- Stop after 5 sources unless the topic is genuinely contested.
- Stop when 2 credible sources agree. Do not seek disconfirmation as a default.
- Stop if the answer is already in the files provided.
```

**For coding tasks:**
```
STOP RULES:
- Stop after fixing the requested issue. Do not refactor unrelated code.
- Stop after running tests once. Do not re-run unless they failed.
- Do not read files outside the task scope listed in CONSTRAINTS.
- Stop after 3 files reviewed in a code review task unless explicitly asked for more.
```

The 3-file rule above is **scope guidance for small review tasks, not a global cap.** A task's CONSTRAINTS-defined review scope (for example: "review the four modified scripts in PLAN_CORE plus the three addenda") overrides this default; the executor reads CONSTRAINTS first and treats its scope as authoritative. The no-contradiction rule from §6 applies across all stop-rule statements: STOP RULES in a task MUST NOT contradict CONSTRAINTS in the same task.

**For document review tasks:**
```
STOP RULES:
- Stop after identifying the issues listed in the checklist. Do not scan beyond listed items.
- One finding per checklist row, plus the file path and line number.
- Do not suggest rewrites unless explicitly asked.
```

**For multi-step agent workflows:**
```
STOP RULES:
- Stop after 20 turns total in this task. If incomplete, surface what remains.
- Stop if the same tool is called 3 times with no progress.
- Stop if you are reading files outside the original scope in CONSTRAINTS.
```

---

## 9. Devlog Pairing (MANDATORY)

Every plan execution MUST produce a devlog entry. Plans executed without a devlog are incomplete.

### Context Recovery Principle

The devlog is the authoritative **audit trail and evidence record** — not the primary recovery mechanism. For fast session recovery, the primary context sources are `agent_planning/execution/<project_name>/SESSION_BRIEF.md` and `HANDOFF.md`, per `agent_planning/EXECUTION_PROTOCOL.md`.

### Devlog Lifecycle

1. **CREATE the devlog after the FIRST task completes.** Populate the title, date, Objective section, the first task's execution details, and the Remaining Tasks section immediately.
2. **UPDATE the devlog at the END of EACH subsequent task.** Do not batch updates — write them while details are fresh.
3. **FINALIZE the devlog after all tasks are complete.** Replace the Remaining Tasks section with the Result / Conclusion / Next Steps section.

**Enforcement:** Every task in the plan MUST include an explicit DEVLOG step in its VERIFICATION section. A task whose devlog step has not been executed is NOT complete.

### Standard Devlog Format

```
# Devlog: {Descriptive Title} — {YYYY-MM-DD}

## Objective / Problem
One paragraph stating what was done and why.

## Discoveries (if applicable)
- Findings during execution that were not known at plan-authoring time
- Cite specific evidence: log lines, command output, file contents

## Execution Log

### ✅ Task N: {Task Name} — COMPLETE
- **What was done:** Concrete actions taken
- **Files modified/created:** Paths and nature of changes
- **Verification:** Command output or checks confirming success
- **Deviations from plan (if any):** What differed and why

## Issues Encountered (if applicable)
- Each issue as a sub-heading with: symptom, root cause, resolution

## Files Modified / Created
| File | Purpose / Change |
|------|------------------|
| `path/to/file` | What was changed or why it was created |

## Remaining Tasks
- [ ] Task N+1: {Name}
- [ ] Task N+2: {Name}

## Result / Conclusion / Next Steps
(Replaces "Remaining Tasks" when all tasks are finalized.)
```

### Remaining Tasks Consistency Rule

The devlog's "Remaining Tasks" checklist MUST be regenerated from `TASK_QUEUE.md` at every update — not manually edited. This prevents drift between the two artifacts.

**Process:**
1. After updating `TASK_QUEUE.md` (per EXECUTION_PROTOCOL.md Section 4), read it back
2. Regenerate the devlog's "Remaining Tasks" section from all tasks with status `todo` or `blocked`
3. When all tasks are `done`/`skipped`, replace the section with "Result / Conclusion / Next Steps"

**Anti-pattern:** Manually maintaining a separate task list in the devlog that diverges from `TASK_QUEUE.md`. The queue is authoritative; the devlog reflects it.

### Devlog Location and Naming

```
agent_planning/execution/<project_name>/devlogs/{descriptive_name}_{YYYY-MM-DD}.md
```

### Verification Integrity Rule (CRITICAL)

**Never use `...` to abbreviate verification commands or their output in the devlog.** Every verification command in the devlog MUST show:
- The exact, complete command (no `...` in URLs, headers, or payloads)
- The actual output, copy-pasted from the terminal (at minimum the key lines)
- For tabular output: the table must be pasted, not summarized

**Enforcement:** The VERIFICATION section in every plan task MUST include: `Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with '...'.`

### Deviation Propagation to Repo Artifacts (MANDATORY)

When plan execution discovers deviations from the plan, the deviation MUST be documented in TWO places:
1. **The devlog** (per-task "Deviations from plan" and "Issues Encountered" sections)
2. **The project's README or notes file** (as a dedicated "Adaptation Notes" table)

**Format:**
```markdown
## Adaptation Notes (differences from the original plan)

| Plan said | Actually did | Why |
|-----------|--------------|-----|
| `body: { expression: "..." }` | `fail_if_body_not_matches_regexp: ["..."]` | v0.24.0 doesn't support `body:` sub-map |
```

---

## 10. Review and Validation Task Pattern

When a plan includes review or validation tasks:

### Use concrete checklists, not open-ended scans

Pre-enumerate every specific item to verify in a checklist table:

```
| # | Item | Search term | Expected location |
|---|------|-------------|-------------------|
| 1 | GARMIN_USER env var | `GARMIN_USER` | README.md |
| 2 | --dry-run CLI flag | `--dry-run` | README.md |
```

### Require structured output

```
REQUIRED OUTPUT -- produce this exact table:
| # | Item | Status | Found in |
|---|------|--------|----------|
| 1 | GARMIN_USER | FOUND/LOST | README.md |
```

### Scope limits for review tasks

- Max 3 repos per review plan.
- Max ~30 checklist items per task.
- Process repos in risk order (highest first).

---

## 11. Sequential Plan Integrity (Multi-Phase Tasks)

When a project spans multiple sequential plans, extra constraints apply.

### Cleanup tasks need explicit file inventories

Never say "remove directory X." Instead, enumerate what must be deleted or use a discovery command first.

### Non-regression constraints across phases

When a later phase touches files that an earlier phase cleaned up, explicitly state what the earlier phase achieved and that it MUST NOT be reverted.

### Verification tasks need machine-checkable pass/fail criteria

```
VERIFICATION COMMAND:
  timeout 10 python -m ai_assisted_language_quizzer 2>&1 | head -5
PASS: output contains "Running on"
FAIL: output contains "ImportError" or exit code != 0 within 10s
BLOCKED: if dependency install fails, log exact error and mark BLOCKED (not PASS).
```

### Use search commands, not diff parsing

```bash
rg -l 'pattern' . --glob '*.md'
```

### Explicit git baselines

When a review plan uses `git diff`, specify the exact baseline reference — not `HEAD`.

---

## 12. Universal Quick Reference Checklist

Before submitting any plan, verify:

**Pre-Plan Interrogation (Section 0)**
- [ ] Tier classified before discovery began
- [ ] Tier 1: All 7 interview categories addressed or deferred
- [ ] Tier 2/3: Domain-specific Decision Records generated by AI
- [ ] Tier 2/3: Every DR has a resolved Decision and explicit Assumptions
- [ ] Tier 2/3: Discovery Summary produced and confirmed
- [ ] Tier 3 only: Architecture Summary produced and confirmed
- [ ] Restatement gate confirmed by user before plan authoring began
- [ ] No tasks added beyond the confirmed restatement scope

**Plan Structure**
- [ ] OBJECTIVE section present and clear
- [ ] PROJECT CONTEXT lists language, libraries, workflow
- [ ] KEY FILES table maps all referenced paths
- [ ] Each task has: INTENT, STRUCTURE, CONTEXT, CONSTRAINTS, DON'T, VERIFICATION
- [ ] Each task touches only ONE pipeline layer
- [ ] Tasks are explicitly ordered
- [ ] Naming is specified for all new files/functions/variables
- [ ] No contradictions between tasks
- [ ] Verification claims marked with provenance (✅ VERIFIED / ❌ ASSUMED / ⚠️ STALE)
- [ ] All commands/queries/API calls marked with provenance (✅ TESTED / 📖 FROM-DOCS / ⚠️ UNTESTED)
- [ ] ⚠️ UNTESTED commands have a verification step before their output is used

**Devlog (Section 9)**
- [ ] Plan specifies devlog filename in `agent_planning/execution/<project_name>/devlogs/`
- [ ] EVERY task's VERIFICATION section ends with an explicit DEVLOG update step
- [ ] VERIFICATION sections include instruction to copy-paste exact command output
- [ ] Devlog "Remaining Tasks" regenerated from TASK_QUEUE.md (not manually maintained)

**Tier 3 embedding (mandatory for Tier 3 plans)**
- [ ] `ARCHITECTURE SUMMARY` (End State / Integration Points / Data Flows / Decision Dependencies) embedded as a plan-file section, not chat output
- [ ] DR→task gating map embedded in `DECISION RECORDS` or in `ARCHITECTURE SUMMARY` — every task that is shaped by a DR is reachable from the map

**Operating Model (mandatory for multi-repo plans)**
- [ ] Repo table (Repo / Role / Absolute path) present in PROJECT CONTEXT
- [ ] cwd prefix convention stated (unprefixed = which repo; short prefix for any non-default cwd)
- [ ] Path-qualification rule stated (every STRUCTURE path lives in exactly one repo)
- [ ] Mirror prohibition stated (never edit downstream mirrors as source)
- [ ] `init_execution_dir.sh` home repo named
- [ ] Downstream blast radius of any sync step named (every repo the sync writes to)

**Cross-cutting framework rules (R1–R7)**
- [ ] R1: Destructive ops in the plan include an explicit operator-confirm step between dry-run and apply
- [ ] R2: Async / job-queued API consumers include poll-until-drained with a wall-clock STOP
- [ ] R3: Collection results have either a named element schema or a `⚠️ UNTESTED` dump step
- [ ] R4: Every skill named in a task has its format/constraints transcribed into the task body
- [ ] R5: Plan preamble contains `§12 pass: <n items>` counting only evidence-cited items (`✅ VERIFIED via <command> on <date>` or `❌ ASSUMED` or `⚠️ STALE`); an aggregate count alone is insufficient, and an item without evidence is not passed; framework plans re-record `n` against the post-change file at closeout
- [ ] R6: Deployment plans place the Code Review task before the first deploy/apply task; deploy tasks gate on review pass (CQ9.6)
- [ ] R7: Pre-execution semantic reviewer ran before bootstrap; preamble carries the review line (reviewer model, date, grade, finding count); no `FAIL` finding remains unresolved
- [ ] Repo-state provenance: every claim about binary names, target hosts/IPs/URIs, file existence, API signatures, or dependency versions carries a `✅ VERIFIED via <command> on <date>` or `❌ ASSUMED` mark (§6)

**Code Quality Gate (code-quality.md — MANDATORY for code-producing plans)**
- [ ] `code-quality.md` was read before plan authoring (not optional for code plans)
- [ ] PROJECT CONTEXT declares `language` / `languages`
- [ ] Every code task's VERIFICATION includes `agent_planning/scripts/quality_gate.sh <paths>` (or the language-specific command it wraps)
- [ ] Every code task's VERIFICATION includes a DRY scan (`rg '<pattern>' <files>`)
- [ ] A **Shared Patterns (DRY Audit)** table exists in PROJECT CONTEXT
- [ ] A dedicated **Code Review** task exists (CQ9.4) — **penultimate** for non-deployment plans, **immediately before the first deploy/apply task** for deployment plans (CQ9.6) — not bundled with docs/OpenSpec — REJECT plan if missing
- [ ] Final task is Doc Update, or the plan explicitly states `Doc Update: N/A`
- [ ] Code tasks with >5 independent conditions specify decomposition strategy in CONSTRAINTS (CQ10)
- [ ] Each code task's DON'T section includes: "Don't produce functions exceeding 15 cyclomatic complexity"
- [ ] Scripts use `set -euo pipefail`; no hardcoded secrets or orphaned files
- [ ] Before Task 1: `agent_planning/scripts/plan_lint.sh [--require-full-tasks] <plan.md>` exits 0

**PLAN REJECTION RULE:** If the plan produces executable code and any of the above Code Quality Gate items are absent, the plan is NON-COMPLIANT. Do not begin execution. Fix the plan first. Run `plan_lint.sh` — do not rely on checklist memory alone.

**Doc Update (Section 2 — DOC UPDATE)**
- [ ] If any task changes CLI flags, config fields, interfaces, or command behavior: plan includes a doc update task
- [ ] Doc update task lists specific files to update (README.md, AGENTS.md)
- [ ] Plan-level STOP RULES account for the doc update task in the task count

**Stop Rules (Section 8.5)**
- [ ] Stop rules included where over-working or scope creep risk is high

**Review/Validation tasks**
- [ ] Concrete item checklists (not open-ended "check all")
- [ ] Required output format specified (classification table)
- [ ] Cleanup/deletion tasks enumerate files or use discovery commands
- [ ] Verification tasks define PASS/FAIL/BLOCKED with concrete commands
- [ ] diff-based review tasks specify an explicit git baseline ref

**Multi-phase plans**
- [ ] Later phases include non-regression constraints referencing earlier phase outcomes
- [ ] Update tasks use `rg -l` discovery instead of hardcoded file lists
- [ ] Verification commands match the plan exactly (no `grep` substitution for `rg`)

**Deviation Feedback (EXECUTION_PROTOCOL.md Section 8)**
- [ ] HANDOFF.md includes "Planning Corrections" section if any deviations occurred
- [ ] Deviations classified with tags (CMD-SYNTAX, API-DRIFT, QUERY-LANG, INFRA-FACT, SCOPE-GAP)

**Addendum-specific checklist items:** See the selected domain addendum.
