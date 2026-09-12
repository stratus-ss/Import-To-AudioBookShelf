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

**Version resolution (MANDATORY for library / framework rows):** every `Version` value in a Library Context table or `ACCESS` toolchain row MUST be resolved by an actual command at authoring time, not by memory or assumption. Use the package manager's resolving command — `go list -m -versions <module>`, `pip index versions <pkg>`, `npm view <pkg> version`, `cargo search <crate>`, `gem list <gem>`, or the tool's own `--version` flag for binaries — and record the result with a date mark. The string `latest` is a **non-compliant value** for any version cell: it drifts silently between plan authoring and execution, has no reproducibility, and is a hard-fail under the `P8c` lint check (see `plan_lint.sh`). Plans that need the latest behavior describe it in prose ("the current release as of <date>") and still pin a numeric version. The prohibition originates in `deepseek/PLAN_INSTRUCTIONS.md:1389` and is enforced here for all model addenda.

### Execution Phase

Before implementing each task:

1. Re-query context7 for task libraries.
2. Confirm planned usage still matches docs.
3. Log `API-DRIFT` when implementation diverges from current docs.

Required verification step:

```
CONTEXT7 CHECK:
  Resolved library IDs and queried for: <libraries>
  Patterns confirmed match plan: YES / NO (deviation logged if NO)
```

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

### Verification

```
MAINTAINABILITY CHECK:
  1. rg '<nested-comprehension-pattern>' <files>
  2. rg '\?.*\?' <files>                  # nested ternaries
  3. Visually inspect method chain depth (<=2)
  4. Read each modified function for newcomer clarity
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
  1. CONTEXT7 CHECK
  2. BUILD
  3. TESTS
  4. COMPLEXITY CHECK — agent_planning/scripts/quality_gate.sh <paths>
  5. MAINTAINABILITY CHECK
  6. DRY CHECK
  7. CODE REVIEW (EXECUTION_PROTOCOL §9)
  8. DEVLOG update
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

**Cross-cutting framework rules (R1–R7):** see `PLAN_CORE.md §2 — Cross-cutting framework rules`. Code-producing plans must additionally: R1 confirm any destructive test fixture setup with the operator before apply; R2 drain any job-queued test/CI call with a wall-clock STOP; R3 name the response field schema of every API the plan's tests consume (or carry `⚠️ UNTESTED`); R4 transcribe any testing-skill or framework-skill format/constraints into the plan; R5 record `§12 pass: <n items>` in the plan preamble with every verification-claim item evidence-cited (`✅ VERIFIED via <command> on <date>` or `❌ ASSUMED`) — an item without evidence is not passed; R6 place the Code Review task before the first deploy/apply task for deployment plans (see §CQ9.6); **R7** carry the recorded pre-execution semantic-review line in the plan preamble and resolve any `FAIL` finding before Task 1.

Plan authoring:
- [ ] Library Context table present
- [ ] context7 citations in library-using tasks
- [ ] Shared Patterns (DRY audit) included
- [ ] Complexity limit in coding tasks
- [ ] Maintainability/Fragility constraints in DON'T

Execution:
- [ ] CONTEXT7 CHECK present
- [ ] COMPLEXITY CHECK present
- [ ] MAINTAINABILITY CHECK present
- [ ] DRY CHECK present
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
- CQ9.3 output format (findings table with PASS/FAIL/ADVISORY counts) referenced in STRUCTURE as a required deliverable

### CQ9.2 Model Switch Pause Rule (mandatory gate)

Before starting the Code Review task (Task N-1 for non-deployment plans, Task R
for deployment plans), execution must:
1. Complete all authoring/implementation/testing tasks
2. Perform full state writeback
3. Ask user whether to switch models for review
4. Wait for explicit response before running review

Required gate text:

```
All implementation tasks complete. Ready for the Code Review task.

Would you like to switch models for the code review?
  (a) Proceed with current model
  (b) Switch models — update HANDOFF.md and stop
```

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
   stop and resolve them, then re-review before deploying."
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
