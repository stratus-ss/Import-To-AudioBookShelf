# Plan Addendum — Code Quality Standards

Applies to: ALL plans that produce executable code — software (Go/Python/TypeScript/Bash), pipeline stages with behavioral logic, automation plans with Node-RED function nodes, and infrastructure plans producing shell scripts or Ansible playbooks.

Read this after `PLAN_CORE.md` and your domain addendum. All rules here are ADDITIVE.

**When to use this addendum:**

| Domain addendum | Read code-quality when... |
|----------------|--------------------------|
| software | ALWAYS — all software plans produce code |
| pipeline | ALWAYS — all pipeline plans produce code with behavioral logic |
| automation | When the plan adds or modifies Node-RED function nodes |
| infrastructure | When the plan produces executable scripts, Ansible playbooks, or Dockerfiles (not for pure config-only plans) |
| creative | NEVER — narrative content is exempt |

This addendum is NOT a replacement for the domain addendum. Always read both.

---

## CQ1. Context7 Integration (MANDATORY for libraries and frameworks)

Context7 is the primary source for current API signatures and idiomatic patterns.

### Plan-Authoring Phase

Before writing tasks that involve libraries or frameworks:

1. Identify all libraries used by the plan (add a **Library Context** table in PROJECT CONTEXT).
2. Query context7 for each library:
   - version-specific APIs
   - idiomatic patterns
   - anti-patterns
3. Embed findings in each task's CONTEXT section.

When context7 is unavailable:
- mark `⚠️ UNTESTED (context7 unavailable)`
- fall back to official docs
- cite fallback source

**Version resolution (MANDATORY for library / framework rows):** every `Version` value in a Library Context table or `ACCESS` toolchain row MUST be resolved by an actual command at authoring time, not by memory or assumption. Use the package manager's resolving command — `go list -m -versions <module>`, `pip index versions <pkg>`, `npm view <pkg> version`, `cargo search <crate>`, `gem list <gem>`, or the tool's own `--version` flag for binaries — and record the result with a date mark. The string `latest` is a **non-compliant value** for any version cell: it drifts silently between plan authoring and execution, has no reproducibility, and is a hard-fail under the `P8c` lint check (see `plan_lint.sh`). Plans that need the latest behavior describe it in prose ("the current release as of <date>") and still pin a numeric version. The prohibition originates in `agent_planning/PLAN_CORE.md §12 Code Quality Gate` and is enforced here for all model addenda.

### Execution Phase

The library query happens twice in the plan lifecycle: once at authoring time (per the Plan-Authoring phase above), and once at the Code Review task (where the reviewer re-queries libraries and confirms the implementation still matches). Per-task re-query between authoring and review is not required; doc drift within a single session is negligible.

When a per-task re-query IS warranted (a long-paused plan, a task that cites a different library version than the plan's Library Context row, or an externally-pinned dependency that may have moved), the executor re-queries context7 for that task's libraries and logs `API-DRIFT` when implementation diverges from current docs.

The per-task review checklist (see `EXECUTION_PROTOCOL.md §9`) keeps the re-query at the Code Review task. The `API-DRIFT` deviation tag is preserved.


Library Context format:

```
## Library Context (context7-queried)

| Library | Version | context7 ID | Key patterns |
|---------|---------|-------------|-------------|
| gorilla/mux | v1.8.1 | /gorilla/mux | Subrouters, middleware chaining |
| cobra | v1.8.0 | /spf13/cobra | PersistentPreRun, Args validation |
```

---

## CQ2. Cyclomatic Complexity — Maximum 15 Per Function

Every function/method/closure MUST be ≤15 complexity.

### Preferred enforcement (all languages)

```
agent_planning/scripts/quality_gate.sh <modified_paths>
PASS: exits 0
```

`quality_gate.sh` auto-detects language from file extension (or `--lang`).

### Language tools (what the script runs)

| Language | Authoritative complexity gate |
|----------|-------------------------------|
| Python | `ruff check --select C901,PLR0912,PLR0915` (max complexity/branches 15, statements 50) |
| Go | `gocyclo -over 15` |
| TypeScript/JavaScript | `eslint --rule 'complexity: ["error", 15]'` |
| Bash | `shellcheck` + CONSTRAINTS branch budget ≤15 |

**Python note:** Prefer Ruff over radon for pass/fail. Radon CC may differ (e.g. compound booleans). Use `quality_gate.sh --info-radon` only for informational hotspot reports — not as a merge blocker.

Refactor when over limit:
- Extract lookup tables
- Extract loop bodies to named helpers
- Extract condition groups to named predicates
- Replace large switch branching with strategy/polymorphism when appropriate

---

## CQ3. Maintainability — Newcomer Readability

Code must be understandable to a new contributor in one pass.

### Non-negotiable rules

- No nested comprehensions
- No nested ternaries
- Maximum 2 chained method calls before assignment
- No triple-nested spread/rest/unpacking
- No obtuse one-liners

### No changelog comments

A comment that narrates a **change event** is banned. History has two
authoritative homes — `git log -S` and the execution devlog under
`agent_planning/execution/<project>/devlogs/` — and a third copy in the
source is pure cost. Write the **rule**, not the **revision**.

Banned signals: a ticket or plan slug (`my-project-feature`, `ACME-142`),
a task/phase number (`Task 6`, `Phase 2`), an ISO date, a version or cap
bump (`Bumped 1400 -> 1500`, `sentinel raised 180->260`).

```
// BAD  my-project-feature Task 6 (DR-4): the caster's summons vanish
// GOOD the caster's summons vanish with the concentration
```

Comments explaining **why** code is shaped as it is are the opposite of
slack and stay, however long they run — a comment documenting a
partial-refresh bug surface is the file earning its budget. Keep bare
requirement anchors (`DR-N`) that point at a live spec. Keep any comment
line a tool parses, such as a `file-budget:` sentinel.

Two costs make this worth enforcing rather than merely advising:

1. **Tokens.** Every comment line is re-read by every agent that opens the
   file, on every future task that touches it.
2. **Code budget.** Where a per-file line cap exists (see
   `addenda/file-budget.md`), it counts *every* line, so comment prose
   directly steals the room the next task needs to grow. Stripping them
   once is not enough; the noise returns with the next task. Enforce it
   mechanically (a grep gate in the repo's own test/script suite)
   rather than trusting review.

Two failure modes re-plant the noise; both are bound here:

- **A plan that prescribes provenance.** The plan is the executor's
  instruction surface. A task line like "update the comment above it to
  state the arithmetic: `... = 36. my-project-feature Task 7.`" teaches the
  executor to write exactly what this section bans — and it complies.
  Comment text quoted inside a plan is subject to this rule; a plan asking
  for a rationale asks for the **why**, never the **when** or the
  **which task**.
- **A gate scoped to reviewed files.** Enforcement that covers only a
  hand-curated list of already-cleaned files cannot stop writes in the
  files nobody has reviewed yet — which is exactly where in-flight work
  lands. Scan every first-party source file a task can touch; carry
  pre-existing debt in a baseline that must shrink, never grow. A curated
  allowlist is an audit trail, not the gate.

### Verification

```
MAINTAINABILITY CHECK:
  1. rg '<nested-comprehension-pattern>' <files>
  2. rg '\?.*\?' <files>                  # nested ternaries
  3. rg '(ticket-or-plan-slug|Task \d+|20\d\d-\d\d-\d\d|Bumped)' <files>
                                           # changelog comments (whole-line //)
  4. Visually inspect method chain depth (<=2)
  5. Read each modified function for newcomer clarity
PASS: no violations
```

---

## CQ4. DRY — Don't Repeat Yourself

### Plan-Authoring

Add a **Shared Patterns (DRY Audit)** table in PROJECT CONTEXT:

```
| Pattern | Defined in | Tasks that use it |
|---------|-----------|-------------------|
| Config loading | config.go:LoadConfig | Task 2, Task 3 |
| API error shape | errors.go:APIError | Task 2, Task 4 |
```

If multiple tasks need shared logic, include an explicit shared-utility task first.

### Duplicated-value agreement guard

When a value must exist in more than one artifact by architecture — config beside code, stylesheet beside script, documentation beside implementation; any duplication no build step unifies — the plan MUST include a value-anchored guard that pins the artifacts' agreement: extract the value from its canonical artifact and assert it appears in the others. Anchor the guard to the value or a stable identity, never to a line number or surrounding text. This supplements, and never replaces, CQ4's define-once rule; it is not license to duplicate freely.

### Execution

Run duplication scans before marking done:

```
DRY CHECK:
  rg '<function_name>|<constant>|<regex>' <files>
```

Reject common violations:
- same regex copied in multiple files
- repeated config/env constants
- repeated ad-hoc error wrappers

Every coding task's DON'T section must include:

```
DON'T:
  - Don't copy-paste logic from existing files
  - Don't redefine existing constants
  - Don't duplicate error-handling patterns
```

---

## CQ5. Fragility — Defensive Coding

Required constraints for all coding tasks:

- Validate external input at boundaries
- No silent error swallowing (`except:` / `catch {}`)
- Explicit error context (`raise ... from err`, `fmt.Errorf(...: %w, err)`)
- No silent mutation of shared state
- Cleanup resources (files, network, subprocesses)
- Network operations must use timeouts

Language-specific snippets:

**Bash**
```
set -euo pipefail
```

**Go**
```
All error returns checked; wrap with context
```

**Python**
```
Catch specific exceptions only; never bare except
```

**TypeScript**
```
No empty catch blocks; validate response shapes
```

---

## CQ6. Enforcement Mechanics

At plan-authoring time:
- include complexity limits in CONSTRAINTS
- include Library Context table
- include DRY audit table
- include maintainability/fragility rules in DON'T

At execution time, every coding task VERIFICATION must include:

```
VERIFICATION:
  1. BUILD
  2. TESTS
  3. COMPLEXITY CHECK — agent_planning/scripts/quality_gate.sh <paths>
  4. MAINTAINABILITY CHECK
  5. DRY CHECK
  6. CODE REVIEW (EXECUTION_PROTOCOL §9; CONTEXT7 re-query lives here per CQ1 §Execution Phase)
  7. DEVLOG update
```

Before Task 1 on a code-producing plan:

```
agent_planning/scripts/plan_lint.sh [--require-full-tasks] <plan.md>
PASS: exits 0
```

---

## CQ7. Tooling References

| Language | Complexity (authoritative) | Linting | Formatting |
|----------|---------------------------|---------|------------|
| Python | `ruff check --select C901,PLR0912,PLR0915` (via `quality_gate.sh`) | `ruff check <file>` | `ruff format --check <file>` |
| Go | `gocyclo -over 15` (via `quality_gate.sh`) | `go vet ./...` + `golangci-lint run` | `gofmt -d <file>` |
| TypeScript | `eslint` complexity 15 (via `quality_gate.sh`) | `eslint <file>` | `prettier --check <file>` |
| Bash | `shellcheck` + branch budget (via `quality_gate.sh`) | `shellcheck <file>` | — |

Wrapper: `agent_planning/scripts/quality_gate.sh [--lang auto|python|go|ts|bash] <paths…>`

---

## CQ8. Checklist (extends PLAN_CORE §12)

**Cross-cutting framework rules (R1–R14):** see `PLAN_CORE.md §2 — Cross-cutting framework rules` for the canonical rule text. Code-producing plans must additionally satisfy: **R1** confirm destructive test fixture setup with the operator before apply; **R2** drain any job-queued test/CI call with a wall-clock STOP; **R3** name the response field schema of every API the plan's tests consume (or carry `⚠️ UNTESTED`); **R9** run every absolute/negative check against the pre-change tree at authoring and cite the baseline, or scope it to the diff; **R10** anchor static/source-level guards at behaviour or a stable identity, never expression text (re-point and log when a gate-forced refactor moves it); **R13** include `quality_gate.sh --file-budget` in every coding task's VERIFICATION (caps in `addenda/file-budget.md §FB1`).

Plan authoring:
- [ ] Library Context table present
- [ ] context7 citations in library-using tasks
- [ ] Shared Patterns (DRY audit) included
- [ ] Complexity limit in coding tasks
- [ ] Maintainability/Fragility constraints in DON'T

Execution:
- [ ] CONTEXT7 query at authoring and at Code Review task (CQ1 §Execution Phase)
- [ ] COMPLEXITY CHECK present
- [ ] MAINTAINABILITY CHECK present
- [ ] DRY CHECK present
- [ ] File budget enforced — `quality_gate.sh --file-budget` in VERIFICATION (CQ11 / R13)
- [ ] CODE REVIEW step references EXECUTION_PROTOCOL §9

---

## CQ9. Mandatory Code Review Task (software and pipeline)

Every code-producing plan MUST include a dedicated review task. Its **position
depends on whether the plan has a deployment phase** (defined in CQ9.6):

- **Non-deployment plan:** `Task N-1 = Code Review`, `Task N = Doc Update` (penultimate).
- **Deployment plan:** Code Review MUST sit **after all authoring/testing tasks and
  immediately before the first deployment/apply task**. Doc Update remains the final
  task. Deployment MUST NOT begin until the review passes.

### CQ9.1 Plan-authoring requirement

Review task must be tailored and include:
- exact files to review
- libraries to re-query via context7
- language-specific complexity command
- concrete maintainability/DRY scan patterns
- for EACH applicable §9 category (Security/Ops, Complexity, Maintainability, DRY, Fragility, Context7): at least one concrete verification action in STRUCTURE — either an automated scan command OR an explicit qualitative review instruction. Delegating to §9 "by pointer" without operationalizing each category in STRUCTURE is non-compliant.
- for every absolute/negative check in STRUCTURE ("returns nothing", "no nested X", "expect 0"), the pre-change baseline command and its authoring-time result — or an explicit `⚠️ UNTESTED (baseline)` mark, or a diff-scoped rewording (R9)
- CQ9.3 output format (findings table with PASS/FAIL/ADVISORY counts) referenced in STRUCTURE as a required deliverable
- the R11 remediation clause: the review MAY modify in-scope artifacts from earlier tasks (including their guards) and logs each modification
- a reviewer-dispatch clause naming the clean-context reviewer (CQ9.2 / `EXECUTION_PROTOCOL.md §9.0`) and the `REVIEWER:` devlog line the review must record
- a re-review bound: the review task's CONSTRAINTS states the 2-round cap and the `⚠️ BLOCKED (loop cap)` escalation (`EXECUTION_PROTOCOL.md §9`, Review Loop Cap)

### CQ9.2 Reviewer Dispatch and Model Selection

Before starting the Code Review task (Task N-1 for non-deployment plans, Task R
for deployment plans), execution must:
1. Complete all authoring/implementation/testing tasks
2. Perform full state writeback
3. **Dispatch a clean-context reviewer** per `EXECUTION_PROTOCOL.md §9.0` — a subagent
   that did not author the code. The authoring agent does not perform the review.
4. Choose the reviewer model. Default: the reviewer's configured model, which is a
   *different model from the author* by construction — that cross-model property is
   the point, so do not silently pin it to the author's id. Override on operator
   request (one line), updating HANDOFF/STATE before dispatch.
5. Run in background when the scope is large; block on the result before remediating.
6. **Observe the Review Loop Cap** — `EXECUTION_PROTOCOL.md §9`. Two rounds per
   gate (initial dispatch + one re-review after remediation). If round 2 is still
   blocking: mark the task `⚠️ BLOCKED (loop cap — Code Review, 2 rounds)`, write
   the `Loop cap hit` HANDOFF section, and hand back to the operator. A third round
   requires an explicit operator override logged as `LOOP-CAP OVERRIDE:`. Never
   self-grant one, and never convert a cap stop into a promotion ("ready to ship
   with N open findings" is a defect).

**Retired:** the previous claim that "a cross-model pass already occurs because the
review wrapper's default reviewer model differs from a DeepSeek author." That held only
when the author was DeepSeek. When the author is any other model — or when no review
wrapper runs at all — the property silently did not exist, and the review degraded to
a same-model, same-context self-review without any signal that it had. The clean-context
subagent dispatch makes the property structural instead of incidental.

A Code Review task with no reviewer dispatch recorded in its devlog is `⚠️ UNTESTED`,
not `done`.

**The same dispatch discipline applies to the Playwright functional pass.** An
author-run functional test is a self-review in a different costume: the author
adjusts the test until it agrees with their belief that the feature works. Web
plans dispatch a clean-context `playwright-tester` subagent on a pinned,
cross-model dispatch and record Row 0 — see `addenda/web.md` W2.1/W2.2 and
`EXECUTION_PROTOCOL.md §9.0`.

### CQ9.3 Required review output

```
| # | File | Line | Rule | Finding | Status |
|---|------|------|------|---------|--------|
```

Summary must include total findings and PASS/FAIL/ADVISORY counts.

### CQ9.4 Placement rule

**Non-deployment plan:**

```
Task 1..X: implementation/testing
Task N-1: Code Review — Full Quality Gate
Task N:   Doc Update
```

**Deployment plan** (contains any task that applies/mutates a live or remote system):

```
Task 1..A:     author deployment artifacts (scripts, playbooks, configs, manifests)
Task A+1..A+T: implementation/testing (functional tests, dry-runs, --check)
Task R:        Code Review — Pre-Deployment Gate   ← MUST precede first deploy task
Task R+1..N-1: deployment / apply / build+push+deploy / post-deploy E2E
Task N:        Doc Update
```

The Code Review task's file scope MUST include every artifact the deployment
consumes. Every deployment task MUST gate on the review passing (see CQ9.6).

### CQ9.5 HANDOFF "Code Review Ready" section

If user chooses model switch, update HANDOFF with:
- files to review
- review tool commands
- checklist steps
- expected output format

### CQ9.6 Deployment-phase definition and ordering

A task is a **deployment task** when it mutates live or remote state — for
example: `deploy`, `apply` (`terraform apply`, `kubectl apply`),
`ansible-playbook` without `--check`, `docker build` + `push` + `restart`,
`systemctl restart`, `migrate`, `rollout`, `release`, `scp`/`rsync` to a
target, or a remote `rm`/`DROP`/`DELETE`.

**Not a deployment task:** copying repository files to another source-controlled
repo (e.g. a `sync_protocol.sh` mirror/distribution run). That mutates version
control, not a running system, and does not trigger the pre-deployment gate —
the Code Review task reviews the files before the sync distributes them. The
distinction is runtime mutation (deployment) vs. source distribution (not).

**Rules:**

1. Every deployment task MUST be ordered AFTER the Code Review task.
2. The Code Review task MUST review the exact artifacts the deployment consumes
   (scripts, playbooks, configs, manifests) — not a summary of them.
3. Each deployment task's CONSTRAINTS MUST include: "Do NOT begin this task
   unless the Code Review task has passed. If review returned FAIL findings,
   resolve them and re-review once (EXECUTION_PROTOCOL.md §9, Review Loop Cap);
   if round 2 is still blocking, mark the review `⚠️ BLOCKED (loop cap)` and
   escalate to the operator. Do NOT deploy."
4. Doc Update remains the final task in both layouts.
5. For plans with no deployment task, CQ9.4's penultimate rule applies unchanged.

**Lint enforcement:** `plan_lint.sh` (check P7) classifies task headings by
deploy keyword. If a deployment task heading is found, the Code Review heading
MUST appear before the first deployment heading. Authors may declare the branch
explicitly in the plan preamble with `Deployment phase: yes` or
`Deployment phase: N/A` when the heading heuristic would be ambiguous.

---

## CQ10. Function Size / Decomposition Heuristic

Any evaluator, handler, or aggregation function that will check more than **5 independent conditions** MUST be decomposed at plan time into:

- A **dispatch** function (thin orchestrator) that calls sub-evaluators
- **Sub-evaluator** functions each handling 1–3 related checks

Plan-authoring rules:
- Include the decomposition plan in task CONSTRAINTS when estimated new LOC in one function > 50
- Do not plan a single `_eval_*_aggregate` that absorbs an entire TSR/section checklist
- Name sub-functions after the check family they own (e.g. `_eval_etcd_health`, `_eval_mcp_status`)

Execution rule:
- If `quality_gate.sh` fails on a new aggregate function, split before marking the task done — do not disable the gate

---

## CQ11. File budget

Enforce the per-language file caps with `agent_planning/scripts/quality_gate.sh --file-budget [modified_paths]` in every coding task's VERIFICATION (additive to the `--lang` complexity invocation). The cap values, the in-file sentinel that authorizes a per-file override, and the exemption list live in `addenda/file-budget.md §FB1`–§FB4 (see also `PLAN_CORE.md §2 R13`); this section does not repeat them. An over-cap file is decomposed, or carries a sentinel whose reason names the plan or issue that justifies it. Enforcement is per-plan: only the plan's named paths are checked.
