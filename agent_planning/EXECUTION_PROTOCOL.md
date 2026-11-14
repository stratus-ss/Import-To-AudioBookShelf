# Execution Protocol for Plan-Driven Agent Work

_Last updated: 2026-09-10_

This document governs what happens **during and between** execution sessions. It complements `agent_planning/PLAN_CORE.md` (which governs plan *authoring*) and the matching model addendum (`agent_planning/minimax/MODEL_ADDENDUM.md` or `agent_planning/deepseek/MODEL_ADDENDUM.md`) and applies to any agent or model executing a Tier 2 or Tier 3 plan.

---

## 1. Execution Directory

Every Tier 2/3 plan establishes a project execution directory at:

```
agent_planning/execution/<project_name>/
  STATE.md           -- single recovery file (objective, current task, blockers, next action, files in scope, bootstrap pointers)
  TASK_QUEUE.md      -- flattened queue with status
  devlogs/           -- audit trail (one file per session or day)
  artifacts/         -- (optional) runtime state snapshots, large outputs, recovery data
```

`project_name` is the snake_case identifier **explicitly declared in the plan's OBJECTIVE section** (required field for Tier 2/3 plans).

**Bootstrap the directory with the provided script before starting Task 1:**

```bash
agent_planning/scripts/init_execution_dir.sh <project_name> --plan zed_plans/<plan>.md
```

This runs `plan_lint.sh` on the plan (fail-closed), then creates the directory structure and pre-populates `SESSION_BRIEF.md`, `HANDOFF.md`, `TASK_QUEUE.md`, and `artifacts/` from the templates in Section 7. After running it, fill in the Objective and copy task names into `TASK_QUEUE.md` from the plan file.

### 1.5 Runtime State Backups and the `artifacts/` Convention

When a task snapshots or backs up state from an **external system** (live Node-RED
`/flows`, live API responses, remote host files, etc.), the snapshot MUST live
in the project tree, NOT in `/tmp`.

```
agent_planning/execution/<project_name>/artifacts/
  .gitignore         -- exclude large/regeneratable snapshots from git
  README.md          -- directory manifest: what's here, why, recovery procedure
  <snapshot files>   -- gitignored; on disk only
```

**Rationale:** `/tmp` is volatile — anything there is lost on reboot. A snapshot
taken before a destructive deploy is worthless if the next agent can't find it
after a reboot mid-incident. The project tree lives in the user's home directory
(or wherever the repo is checked out) and survives reboots, crashes, and
session churn.

**Rules:**
0. Before Task 1: validate this plan against software.md S7 and code-quality.md CQ8/CQ9. List each checklist item PASS/FAIL with evidence from the plan text. Do not bootstrap execution until every item is PASS.
1. **Default location:** `agent_planning/execution/<project_name>/artifacts/`.
   If the project has no artifacts dir yet, create it. Do NOT use `/tmp`,
   `~/.cache/`, or any other volatile location.
2. **Per-directory `.gitignore`:** large/regeneratable snapshots MUST be excluded
   from git (1MB+ JSON dumps, full HTTP responses, raw VM disk images). The
   `.gitignore` lives IN the artifacts dir and is itself git-tracked so the
   policy is visible (local ignores + selective un-ignores with `!`).
3. **README.md in the dir:** every artifacts dir MUST have a README documenting
   what's there, why, and how to recover from it. The README IS git-tracked.
4. **Snapshots are regeneration evidence, not source of truth.** When in doubt,
   the live system is the source of truth; the repo's canonical files
   (e.g., `HomeAssistant/flows/*.json`) are the importable source for any
   git-tracked flow. Snapshots here are for **recovery + forensic diff** only.
5. **Sensitive content warning:** if a snapshot contains secrets (SSH keys,
   passwords, API tokens), record in README.md but DO NOT git-track it. Add
   the file pattern to `.gitignore` with an explicit note.

**Anti-pattern:** Putting a 1MB Node-RED `/flows` snapshot in `/tmp` because "I
just need it for the next 30 seconds." If the next 30 seconds involves a reboot,
a crash, or a session boundary, the snapshot is gone. Use the artifacts dir.

---

## 2. Artifact Roles

| Artifact | Role | Update frequency |
|----------|------|-----------------|
| `STATE.md` | Single recovery file: current objective, active task, blockers, next action, files in scope, bootstrap pointers | After every completed or blocked task |
| `TASK_QUEUE.md` | Authoritative task status list (todo / doing / blocked / done) | After every task status change |
| `devlogs/<name>.md` | Audit trail: decisions made, evidence gathered, commands run, outcomes | Append after each session |

**The devlog is the audit trail, not the recovery mechanism.** `STATE.md` is the fast-recovery surface. Use the devlog only when `STATE.md` is insufficient to reconstruct evidence.

---

## 3. Execution Bootstrap (Every Session Start)

### 3.0 Plan Lint Gate (first session / before Task 1)

Before creating the execution directory or marking Task 1 as `doing`, code-producing plans MUST pass:

```bash
agent_planning/scripts/plan_lint.sh zed_plans/<plan>.md
# Prefer full task structure for Tier 2/3 software plans:
agent_planning/scripts/plan_lint.sh --require-full-tasks zed_plans/<plan>.md
```

Bootstrap with lint wired in:

```bash
agent_planning/scripts/init_execution_dir.sh <project_name> --plan zed_plans/<plan>.md
```

If `plan_lint.sh` exits non-zero: **do not begin coding**. Fix the plan (CQ9 Code Review task, DRY audit, complexity VERIFICATION, language declaration) and re-run. `--skip-plan-lint` is emergency-only and MUST be logged as `[SCOPE-GAP]` in the devlog and HANDOFF.

### 3.1 Session read order

Read in this order before taking any action:

1. Plan file — scan **OBJECTIVE** and the current task section only; do not re-read the full plan
2. `agent_planning/execution/<project_name>/STATE.md`
3. `agent_planning/execution/<project_name>/TASK_QUEUE.md` — current task and adjacent items only
4. Relevant devlog section **only if** `STATE.md` references a specific evidence gap

Mark the active task as `doing` in `TASK_QUEUE.md` before starting work.

---

## 4. State Writeback (After Every Task)

After completing or blocking on a task:

1. Update `TASK_QUEUE.md` — set status (`done` / `blocked`), note the blocker if applicable
2. Rewrite `STATE.md` — replace entirely with current state (see template below); this single file replaces the prior SESSION_BRIEF.md + HANDOFF.md pair
3. Append a devlog entry to `agent_planning/execution/<project_name>/devlogs/`

Do not skip writeback when a task fails or is blocked. Blocker context is the most valuable state to preserve.

### 4.1 Commit vs. Stage Policy

Version control during execution follows three rules:

1. **Runtime state is committed in-session.** `execution/<project>/` state files
   (SESSION_BRIEF, HANDOFF, TASK_QUEUE, devlogs, artifacts) may be committed as
   part of writeback so a fresh agent can resume from git. Commit them when the
   plan or AGENTS.md requires same-session commits.
2. **KB writeback is committed in-session.** Per the AGENTS.md Knowledge Base
   Writeback rule, a KB doc edited as part of an action MUST be committed in the
   same session — never deferred to closeout.
3. **Source and protocol-doc commits are staged unless the operator authorizes.**
   For code, scripts, and framework docs, `git add` and leave the change staged;
   do not `git commit` until the plan's closeout task or the operator explicitly
   authorizes it.

When these conflict (a plan says "stage only" but the KB rule says commit), the
KB rule wins for the KB doc; source commits still wait for authorization. Record
any commit made without prior authorization in the devlog as a `[PROCESS]` note
and ratify it at closeout. **Never** treat "the writeback rule made me do it" as
blanket authorization to commit source files.

---

## 5. Chunked Execution

Never run more than 3–5 tasks in a single session. Start fresh threads aggressively. The memory artifacts exist precisely to make this safe — a fresh agent reading the bootstrap sequence above should reach working context within 2 minutes.

Signs to end a session and start fresh:
- Accumulated tool output exceeds ~150K tokens
- The agent begins re-reading files it already processed
- A task fails in an unexpected way that requires re-evaluating prior decisions
- More than one blocked task in a row

### 5.1 Quality Gate at Sprint Boundary (MANDATORY for code-producing plans)

When executing 3+ code-producing tasks in sequence — regardless of user acceleration requests — the agent MUST run a quality checkpoint before continuing:

```bash
agent_planning/scripts/quality_gate.sh <modified_paths...>
# Optional Python informational CC (not merge-blocking):
agent_planning/scripts/quality_gate.sh --info-radon <python_paths...>
```

1. `quality_gate.sh` selects the language tool automatically (`ruff` / `gocyclo` / `eslint` / `shellcheck`)
2. If the gate exits non-zero: STOP. Refactor before proceeding.
3. Scan for duplicated patterns: `rg '<function_or_constant>' <touched_dirs>`
4. Log exact command output in the devlog

**This gate is non-negotiable.** User requests like "continue through the rest" do not override it. If the user explicitly asks to skip quality checks, log the override in the devlog and HANDOFF.md as a `[SCOPE-GAP]` deviation.

---

## 6. Wrapper-First Execution

For any action pattern executed more than once, create a script before the second execution. Place scripts in the project's scripts directory or `tools/`.

Requirements:
- Scripts exit with a non-zero code on failure
- Scripts print structured output (key=value lines or JSON) rather than prose
- Plans reference the script path, not the ad-hoc shell chain it replaced

This reduces the agent's action space, makes retries predictable, and keeps the devlog readable.

---

## 7. Templates

### STATE.md

```markdown
# State — <project_name>

**Updated:** YYYY-MM-DD HH:MM

## Objective
One sentence: what the overall plan achieves.

## Current Task
Task ID and name from TASK_QUEUE.md.

## Status
- Last completed: <task_id> — <outcome>
- Active: <task_id>
- Blocked on: (none | description)

## Next Action
Exactly what the next agent action should be (specific, not "continue the plan").

## Files In Scope
- path/to/file — why it matters

## Bootstrap
Read in this order:
1. zed_plans/<plan_file>.md — OBJECTIVE + current task section only
2. agent_planning/execution/<project_name>/STATE.md
3. agent_planning/execution/<project_name>/TASK_QUEUE.md

## Where We Are
<1-2 sentences: what has been done, what is not done>

## Known Blockers / Gotchas
- <any non-obvious constraint the next agent must know>
```

### TASK_QUEUE.md

```markdown
# Task Queue — <project_name>

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | <task name> | done | |
| 2  | <task name> | doing | |
| 3  | <task name> | todo | |
| 4  | <task name> | blocked | waiting on X |
```

Statuses: `todo` / `doing` / `done` / `blocked` / `skipped`

---

## 8. Deviation Review Feedback Loop

When execution reveals a planning error — wrong command syntax, incorrect API endpoint, wrong DNS record type, invalid query language, misconfigured service parameter — the executing agent MUST classify and document the deviation so the planning protocol improves over time.

### Deviation Classification

| Class | Description | Example |
|-------|-------------|---------|
| `CMD-SYNTAX` | Command or CLI invocation was syntactically wrong | `grafana-server --version` → `grafana-server -v` |
| `API-DRIFT` | API endpoint, payload, or auth method was incorrect | Pi-hole A record API → CNAME API |
| `QUERY-LANG` | Query language syntax was invalid for the target version | LogQL `{job=~"..."}` vs `{job="..."}` |
| `INFRA-FACT` | Infrastructure assumption was wrong (IP, port, path, service name) | Wrong NFS mount path, wrong VLAN ID |
| `SCOPE-GAP` | Plan omitted a required step that the executor had to add | Missing download-completion polling before scan |

### Required Actions

1. **In the devlog** — Log the deviation under "Deviations from plan" with the class tag:
   ```
   - **[CMD-SYNTAX]** Plan said `grafana-server --version`; actual command is `grafana-server -v`
   ```

2. **In HANDOFF.md** — Add a "Planning Corrections" section listing deviation classes encountered:
   ```
   ## Planning Corrections
   - [API-DRIFT] Pi-hole DNS: plan specified A record API, corrected to CNAME at runtime
   - [SCOPE-GAP] Added download-completion polling (Tasks 7-8) not in original plan
   ```

### Feedback to Planning Protocol

Accumulated deviations across projects inform planning protocol improvements. When the same deviation class appears in 3+ projects, it signals a systemic gap that should be addressed by adding a new rule or checklist item to `PLAN_CORE.md` or the relevant addendum.

A devlog entry claiming "Deviations from plan: none" is valid only if the executor re-read the task's STRUCTURE against the actual diff before writing the claim. Any deviation entry quotes the plan text it deviates from and names what was done instead. Numeric tallies in review tables (findings counts, PASS/FAIL/ADVISORY counts) are recomputed from the table's rows at write time, never recalled.

### Closeout Counterfactual

At the closeout of every plan, the executor answers one counterfactual question and records the answer in the closing devlog entry:

> "Without the framework changes in this plan, what would the plan-execution session have looked like — same shape with more round-trips, or a different shape entirely?"

The answer is the empirical signal for whether the framework change moved the needle on its claimed cost. The framework's telemetry hooks (`agent_planning/scripts/plan_review.sh`, `init_execution_dir.sh`) also append one JSONL line per run to `agent_planning/execution/_telemetry.jsonl` (see `agent_planning/TELEMETRY.md`); the counterfactual closes the loop between the telemetry and the closeout narrative.

---

## 9. Code Review Checkpoint

When a plan produces executable code (shell scripts, Docker Compose files, Ansible playbooks, configuration files that affect live services), a **clean-context reviewer** MUST perform the review before the task is marked done.

### 9.0 The reviewer is a separate context, not the author

**The authoring agent MUST NOT review its own code.** A self-review cannot report a
blind spot the author cannot see — the reasoning that produced the defect is the same
reasoning that failed to notice it. This is not a style preference; it is the reason
the review exists.

Concretely, the review MUST be performed by an agent that did not write the code and
whose context does not contain the authoring session. In OpenCode that is a **subagent
dispatch**, which runs in a fresh context by construction. The canonical reviewer is
shipped at `agent_planning/reviewer/code-reviewer.md`; copy it to
`.opencode/agents/code-reviewer.md` in the project root and dispatch it as
`code-reviewer`.

**Why a subagent rather than a fresh top-level session.** Both give clean context, but
the subagent is the cheaper mechanism: it needs no operator round-trip, it cannot
silently skip the checklist, and its findings come back into the executing session as
data. A fresh session is acceptable only when the harness offers no subagent dispatch;
if it is used, log `[SCOPE-GAP]` in the devlog.

**Background dispatch is permitted and preferred for long scopes.** A review covering
many files or a slow test suite may run as a background subagent; the executing
session must not begin remediation until it returns.

#### Model selection and the silent-inheritance trap

A subagent with no configured model **inherits the parent session's model**. An
unpinned reviewer therefore silently reviews with the same model that wrote the code —
the cross-model property is lost with no signal, which is the failure this section
exists to prevent. Two defences, both required:

1. **The reviewer ships with a pinned `model:`** in its frontmatter. Verified against
   the live catalog before committing a model id; variant strings must be checked
   against that model's `reasoning_options` effort values, not guessed.
2. **The dispatch passes the authoring model id** in the prompt, and the reviewer
   opens its report with **Row 0**, stating the model it is actually running and
   whether that matches the author. The reviewer is instructed to mark it `FAIL` if
   it cannot tell, or if the prompt contained the authoring transcript.

The executing session reads Row 0 and decides:

| Row 0 | Meaning | Action |
|-------|---------|--------|
| `PASS` | Clean context **and** a different model — full independence | proceed |
| `ADVISORY` | Clean context only; same model as the author | proceed only if the operator explicitly accepted a same-model review. Record that acceptance in the devlog. Otherwise treat as `FAIL`. |
| `FAIL` | Model indeterminate, or the prompt leaked the authoring transcript | stop; re-dispatch |

Prefer a different model. A deliberate same-model review is a reasonable cost or
capability choice — it is only a defect when nobody chose it.

**The same rule governs the Playwright functional pass** (`addenda/web.md`
W2.1/W2.2): the tester is a clean-context subagent with a pinned primary model
(`opencode-go/minimax-m3.1-flash#medium`) and a documented fallback
(`alibaba-token-plan/deepseek-v4.1-flash-1017#high`), reported in Row 0. There is no
`fallback-model` frontmatter key — the fallback is applied by re-dispatching with
an explicit `model` argument. A functional pass run by the authoring agent, or
dispatched without a model pin, is a defect regardless of what it reported.

**The same rule also governs the pre-execution plan validation** (`PLAN_CORE.md`
§8.7 / R7): the validator is a clean-context subagent pinned to
`opencode/deepseek-v4.1-flash#max` (operator choice 2026-10-25), reported in
Row 0 with the same ADVISORY-when-same-model semantics — a DeepSeek-authored
plan yields `ADVISORY` (clean-context only), an accepted trade, not a defect.
A plan validated by its authoring agent, or dispatched without a model pin, is
a defect regardless of what it reported.

**The reviewer does not edit.** The reviewer agent ships with edit permission denied.
Remediation stays in the executing session, applied against the reviewer's findings,
and every applied change is logged per §9's R11 clause. This keeps the reviewer a
measurement instrument rather than a second author, and keeps the audit trail —
"finding → justification → fix" — attributable to one session.

#### Dispatch contract

The prompt handed to the reviewer is self-contained. It carries, and nothing depends
on session state:

1. the plan file path and the Code Review task's section;
2. the review scope — the exact file list from the task's STRUCTURE;
3. the per-category verification commands from the task's STRUCTURE;
4. the STOP RULES that bind the remediation (so it can tell a real defect from an
   intentional constraint);
5. **the authoring model id** — the reviewer needs it to fill in Row 0 honestly;
6. the paths of the §9 checklist itself, so the reviewer does not rely on memory.

**Do not** pass the authoring session's transcript, its rationale, or its devlog
narrative. Those are precisely the context that produces the blind spot. The reviewer's
job is to check the artefacts against the plan, not to grade the author's reasoning.

#### Recording the dispatch

The Code Review task's devlog entry records, for every dispatch:

```markdown
REVIEWER: <agent id> · model <provider/model#variant> · author <provider/model#variant> · context: subagent (clean)
DISPATCH: <what was passed in scope>
ROW 0: <the reviewer's self-reported independence row — quote it verbatim>
FINDINGS: <total> — PASS <n>, FAIL <n>, ADVISORY <n>
BLOCKING: <the FAIL rows, or "none">
```

`ROW 0` is recorded verbatim rather than summarised so the dispatch is auditable
after the fact: a reviewer that silently inherited the authoring model would
otherwise be indistinguishable from one that was correctly pinned to a different
model.

A Code Review task with no `REVIEWER:` line in its devlog is not a completed review.
If no clean-context reviewer was available and the executing agent reviewed its own
work, the task is `⚠️ UNTESTED` with a `[SCOPE-GAP]` recording why — never `done`.

### Review Loop Cap — 2 rounds maximum per gate

Every re-dispatchable verification gate has a **hard budget of two rounds**. It
applies to the Code Review task (§9.0) and to the Playwright functional pass
(`addenda/web.md` W2); each gate has its own budget, so a web plan permits
**2 Code Review rounds and 2 Playwright rounds** — not two rounds total. The
R7 plan-validation dispatch (`PLAN_CORE.md §8.7`) already carries the same
single-remediation bound.

| Round | When it is allowed |
|-------|--------------------|
| 1 | the initial dispatch |
| 2 | only after the round-1 blocking findings are remediated |
| 3 | does not exist — there is no "one more quick pass" |

A round is counted **on dispatch**, not on merit. A re-check after applying fixes,
a re-dispatch on a different model, a re-run "just to confirm the last two fixes",
and a dispatch after partial remediation are each a round. Elapsed time is
irrelevant: three hours of work is not evidence that round 3 would have been the
last one, and the clock is not an input to the cap.

**When round 2 is still blocking, the gate stops.** Do not remediate again, do not
deploy, do not dispatch again. Record, then escalate:

1. Devlog: `ROUND: 2/2 · <gate> · BLOCKING <n>`, plus the round-2 findings table
   quoted verbatim. The operator needs the rows, not a summary of the mood.
2. Devlog: one line per round spent, stating what round *n* found that round
   *n−1* did not. That diff is the useful artefact — it is what separates "the fix
   regressed something" from "the approach is wrong".
3. Task status `⚠️ BLOCKED (loop cap — <gate>, 2 rounds)` — never `done`, never
   `⚠️ UNTESTED`, never "complete with N minor findings".
4. HANDOFF: a `Loop cap hit` section carrying the outstanding FAIL rows, the
   round history, and the one decision the operator has to make. Name which it
   looks like: an **unstated plan decision** (the plan never decided what the code
   should do here), a **wrong approach** (each fix exposes the next defect), or
   **genuinely small residue** (real but isolated defects that do not interact).
5. Stop the session and hand back. Do not start the next task to "keep making
   progress".

**A loop-cap stop is not a promotion.** Code that hit the cap does not ship, is not
marked ready, and is not described as "ready to promote". A report that says both
"the last round still found real defects" and "we are ready to ship" is a defect in
the report, whatever the findings' severity. Elapsed time, operator impatience, and
"the remaining findings are minor" are not a round-2 pass.

**Only an explicit operator override buys a third round**, recorded in the devlog as
`LOOP-CAP OVERRIDE: <verbatim operator instruction> — operator, YYYY-MM-DD`.
Continuing because the operator said "carry on with the plan" is not an override,
and an executor never self-grants one.

The cap exists because a review that keeps finding real defects is a signal about
the **plan**, not an invitation to keep fixing. Two rounds of real findings means the
code is wrong in a way remediation cannot reach — escalate that; do not grind it.

### Review Checklist

#### Security & Operations
- [ ] **Secret scan:** run `agent_planning/scripts/secret_scan.sh <path>` — must exit 0 before marking done
- [ ] No hardcoded IPs/hostnames that should come from variables or DNS
- [ ] Error handling: scripts check return codes; `set -euo pipefail` for bash
- [ ] Idempotency: running the script/playbook twice produces the same result
- [ ] File permissions: sensitive files are not world-readable
- [ ] The code is version-controlled (committed or staged) — not orphaned in `/tmp` or an untracked dir

#### Complexity (per code-quality.md §CQ2)
- [ ] Every function ≤ 15 cyclomatic complexity
- [ ] No function with >15 branches (if/elif/else/case/while/for combined)
- [ ] Complex functions split using lookup tables, named predicates, or strategy pattern — not pushed into a longer body

#### Maintainability (per code-quality.md §CQ3)
- [ ] No nested list/dict/set comprehensions
- [ ] No nested ternary expressions (`x ? y : z ? a : b` or `x if C else y if D else z`)
- [ ] Maximum 2 chained method calls before assigning to a named variable
- [ ] Spread/rest/unpacking depth ≤ 2 levels — no triple-nested destructuring
- [ ] No "clever" one-liners that require domain knowledge to parse
- [ ] Qualitative test: a developer unfamiliar with the project can state what each function does after one reading

#### DRY (per code-quality.md §CQ4)
- [ ] No duplicated logic across files (same regex, same error message format, same config parsing)
- [ ] Constants defined once and imported, not copied into each file
- [ ] Common patterns extracted to shared utilities or helper functions
- [ ] Error handling uses the project's standard error wrapper, not ad-hoc patterns

#### Fragility (per code-quality.md §CQ5)
- [ ] All external inputs validated at function boundaries before processing
- [ ] No bare `except:` or catch-all error handlers that swallow failures
- [ ] Functions that mutate inputs have names signaling mutation (set_, update_, modify_)
- [ ] Global variables absent or explicitly justified
- [ ] Resources (files, connections, subprocesses) cleaned up in finally/defer blocks
- [ ] Timeouts set on all network operations

#### Context7 (per code-quality.md §CQ1)
- [ ] Library query happens at authoring time and at the Code Review task (CQ1 re-queried there); per-task re-query is not required.
- [ ] Implemented patterns match current library documentation
- [ ] Any deviation from planned patterns logged with API-DRIFT tag

#### Web UI (per addenda/web.md, R14 — browser-rendered plans only)
- [ ] A dedicated Playwright functional-test task exists and ran before Code Review
- [ ] The pass ran in a clean-context `playwright-tester` subagent on a pinned, cross-model dispatch (web.md W2.1/W2.2) — the authoring agent did not run it, and a Row 0 recording the actual model vs the authoring model is in the devlog
- [ ] The test drove the real user path through the DOM (no fetch-only substitute) and asserted observable behaviour
- [ ] Happy path AND an error/refusal path were asserted
- [ ] The run was headless, exited 0, and the server it started was torn down (zero-orphan check documented) — or `Playwright: N/A — <reason>` is recorded with the task marked `⚠️ UNTESTED`
- [ ] No failing assertion was weakened, skipped, or narrowed to reach green — a failure is a reported finding, not something to tune away

### Enforcement

Every task that produces code MUST include in its VERIFICATION section:
```
CODE REVIEW:
  agent_planning/scripts/secret_scan.sh <path>
  PASS: exits 0
  FAIL: exits 1 — fix before marking done
  agent_planning/scripts/quality_gate.sh <modified_paths>
  PASS: exits 0
  FAIL: exits 1 — refactor before marking done
  Verify against EXECUTION_PROTOCOL.md Section 9 checklist before marking done.
    - Security & Operations: items above
    - Complexity (CQ2): quality_gate.sh clean (ruff/gocyclo/eslint/shellcheck by language)
    - Maintainability (CQ3): scan for nested comprehensions, ternaries, chain depth
    - DRY (CQ4): scan for duplicated patterns
    - Fragility (CQ5): input validation, error handling, resource cleanup
    - Context7 (CQ1): patterns match current library docs
```

### Pre-Deployment Review Gate (deployment plans)

For plans with a deployment/apply phase, the dedicated Code Review task is the
gate between authoring and deployment — not a final cleanup step. See
`addenda/code-quality.md §CQ9.6` and `PLAN_CORE.md` rule R6.

1. The Code Review task runs after all authoring/testing tasks and **before the
   first deployment task** (deploy / apply / provision / migrate / restart / push).
2. The review scope is the exact artifacts the deployment will apply — the
   scripts, playbooks, manifests, and configs, not a summary.
3. **No deployment task may start until the review passes.** If the review
   returns FAIL findings, resolve them and re-review **once** (Review Loop Cap,
   above). If round 2 is still blocking, the gate does not pass: mark the review
   `⚠️ BLOCKED (loop cap)` and escalate — do not deploy, and do not deploy on the
   grounds that the outstanding findings look minor. Each deployment task's
   CONSTRAINTS carries this gate.
4. The Model Switch Pause (CQ9.2) is opt-in at this gate exactly as it is for a
   penultimate review — proceed with the current model by default; switch only
   on operator request.
5. Non-deployment plans keep the penultimate Code Review placement (CQ9.4).

`plan_lint.sh` check **P7** fails a deployment plan whose Code Review task does
not precede its first deploy/apply task.

### Review Remediation & Guard Re-pointing (R10 / R11)

The Code Review task is the last chance to fix the code before it ships, so its
authority to edit is broader than a normal task's:

1. **STOP RULES are task-scoped.** A "do not modify X" STOP RULE in an earlier
   task binds that task, not a later Code Review task in its review scope. The
   review MAY edit any in-scope artifact from an earlier task — including that
   task's tests and guards — to remediate a finding. Log every such edit with
   its justification in the devlog (R11). Never ship a `FAIL` to honour a STOP
   RULE.
2. **Guard re-pointing.** When a gate-forced refactor (complexity/format/lint)
   moves an expression that a source-level guard pins, re-point the guard at the
   new stable identity in the same change and log the re-point. Preserving a
   guard's *text* at the cost of a gate pass, or weakening its assertion to keep
   a refactor, is a defect (R10). Behaviour or a stable identity is the anchor;
   expression text and line numbers are not.
3. **Guard co-scheduling.** When any change invalidates a guard's anchor — an
   id, key, symbol, flag, path, or storage key a test, lint rule, or document
   asserts — update the asserting artifact in the same task as the invalidating
   change, or record the plan's declared stale window. This extends the existing
   gate-forced-refactor re-pointing rule to any invalidating change.
4. **Capture at completion.** A devlog command capture must reflect the task's
   final tree. If a task edits a file after capturing output, re-run and
   re-capture before marking done (PLAN_CORE §9 Verification Integrity Rule).
5. **Run every guard that reads any file this task touched — not only the guards
   the task's VERIFICATION lists.** Co-scheduling means a guard outside the
   task's own list may still fire on an edited file; the executor runs it.

---

## 10. Model-Specific Addenda

See the following files for context-window sizing, thinking configuration, and model-specific guidance:

- DeepSeek (V4 Pro / V4.1 Flash): `agent_planning/deepseek/MODEL_ADDENDUM.md`
- MiniMax (M3): `agent_planning/minimax/MODEL_ADDENDUM.md`
