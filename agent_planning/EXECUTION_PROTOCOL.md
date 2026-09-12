# Execution Protocol for Plan-Driven Agent Work

_Last updated: 2026-09-10_

This document governs what happens **during and between** execution sessions. It complements the model-specific `PLAN_INSTRUCTIONS.md` files (which govern plan *authoring*) and applies to any agent or model executing a Tier 2 or Tier 3 plan.

---

## 1. Execution Directory

Every Tier 2/3 plan establishes a project execution directory at:

```
agent_planning/execution/<project_name>/
  SESSION_BRIEF.md   -- active state summary (one screen)
  HANDOFF.md         -- fresh-agent continuation note
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
| `SESSION_BRIEF.md` | Fast-recovery snapshot: current objective, active task, blockers, next action, files in scope | After every completed or blocked task |
| `HANDOFF.md` | "A fresh agent reading only this can continue the work" note | After every completed or blocked task |
| `TASK_QUEUE.md` | Authoritative task status list (todo / doing / blocked / done) | After every task status change |
| `devlogs/<name>.md` | Audit trail: decisions made, evidence gathered, commands run, outcomes | Append after each session |

**The devlog is the audit trail, not the recovery mechanism.** `SESSION_BRIEF.md` and `HANDOFF.md` are the fast-recovery surface. Use the devlog only when the brief is insufficient to reconstruct evidence.

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
2. `agent_planning/execution/<project_name>/SESSION_BRIEF.md`
3. `agent_planning/execution/<project_name>/HANDOFF.md`
4. `agent_planning/execution/<project_name>/TASK_QUEUE.md` — current task and adjacent items only
5. Relevant devlog section **only if** the brief/handoff references a specific evidence gap

Mark the active task as `doing` in `TASK_QUEUE.md` before starting work.

---

## 4. State Writeback (After Every Task)

After completing or blocking on a task:

1. Update `TASK_QUEUE.md` — set status (`done` / `blocked`), note the blocker if applicable
2. Rewrite `SESSION_BRIEF.md` — replace entirely with current state (see template below)
3. Update `HANDOFF.md` — replace the "next action" section with what a fresh agent should do first
4. Append a devlog entry to `agent_planning/execution/<project_name>/devlogs/`

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

### SESSION_BRIEF.md

```markdown
# Session Brief — <project_name>

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
```

### HANDOFF.md

```markdown
# Handoff — <project_name>

**Written:** YYYY-MM-DD HH:MM

## Bootstrap
Read in order:
1. zed_plans/<plan_file>.md — OBJECTIVE + Task <N> section only
2. agent_planning/execution/<project_name>/SESSION_BRIEF.md
3. agent_planning/execution/<project_name>/TASK_QUEUE.md

## Where We Are
<1-2 sentences: what has been done, what is not done>

## Next Action
<Specific action — command, file edit, verification step>

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

---

## 9. Code Review Checkpoint

When a plan produces executable code (shell scripts, Docker Compose files, Ansible playbooks, configuration files that affect live services), the executing agent MUST perform a self-review before marking the task as done.

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
- [ ] Executor re-queried context7 for each library before implementing
- [ ] Implemented patterns match current library documentation
- [ ] Any deviation from planned patterns logged with API-DRIFT tag

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
   returns FAIL findings, resolve them and re-review before deploying. Each
   deployment task's CONSTRAINTS carries this gate.
4. The Model Switch Pause (CQ9.2) applies at this gate exactly as it does for a
   penultimate review.
5. Non-deployment plans keep the penultimate Code Review placement (CQ9.4).

`plan_lint.sh` check **P7** fails a deployment plan whose Code Review task does
not precede its first deploy/apply task.

---

## 10. Model-Specific Addenda

See the following files for context-window sizing, thinking configuration, and model-specific guidance:

- Claude (Opus 4.6, Sonnet 4.6, Sonnet 5): `agent_planning/claude/MODEL_ADDENDUM.md`
- OpenAI (GPT 5.4, Codex): `agent_planning/openai/MODEL_ADDENDUM.md`
