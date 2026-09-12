# Plan Addendum — Software Development

_Last updated: 2026-09-10_

Applies to: Go/Python/TypeScript/Bash application code, MCP servers, CLI tools, libraries, scripts with behavioral logic, test suites, API clients, refactors.

Read this after `PLAN_CORE.md`. All rules here are ADDITIVE.

---

## S1. OpenSpec Integration

OpenSpec is the spec persistence layer for software projects. Specs accumulate across plans, giving the executing agent behavioral context before it touches code.

### When to Create Specs

Create a spec for a codebase when **any** of these conditions hold:
- This is the 2nd or later plan touching the same codebase
- The codebase exposes a public interface (MCP tools, CLI subcommands, API endpoints)
- The codebase has behavioral invariants that future plans must not break

Skip spec creation for: one-off scripts, purely additive changes with no behavioral contract, infrastructure-only plans using the software addendum for the `pihole-reconciler` pattern.

### OpenSpec Lifecycle Per Plan

```
Planning phase:
  1. Check if agent_planning/openspec/specs/<capability>/ already exists
  2. If specs exist: read them as additional PROJECT CONTEXT before writing tasks
  3. Propose a change: /opsx:propose <description>

Execution phase:
  4. The agent follows tasks (per PLAN_CORE.md protocol)
  5. Agent reads agent_planning/openspec/changes/<change-id>/tasks.md alongside the plan tasks

Completion:
  6. Final task: /opsx:archive
     → merges delta specs from agent_planning/openspec/changes/<change-id>/specs/
     → into agent_planning/openspec/specs/<capability>/spec.md
```

### Spec Location

The implementation repo is the **authoritative reference** for spec-existence: an OpenSpec tree declared by the implementation repo's own `openspec/README.md` overrides the addendum default location shown below. When the implementation repo names a different spec tree, the plan MUST record the divergence as a §2 divergence note and follow the implementation repo's spec tree.

```
agent_planning/openspec/
├── specs/                    ← current behavioral truth (accretes over time)
│   └── <capability>/spec.md
└── changes/                  ← active proposals (ephemeral per plan)
    └── <change-id>/
        ├── proposal.md
        ├── design.md
        ├── tasks.md
        └── specs/            ← delta specs (ADDED/MODIFIED/REMOVED)
```

The "No OpenSpec Found" dialogue outcome `(a) / (b) / (c)` chosen at plan-authoring time MUST be recorded in the plan's PROJECT CONTEXT (per the implementation-repo discovery in `PLAN_CORE.md` §0). Plans that omit the recorded outcome are non-compliant with the §S1 spec-repo check.

```
agent_planning/openspec/
├── specs/                    ← current behavioral truth (accretes over time)
│   └── <capability>/spec.md
└── changes/                  ← active proposals (ephemeral per plan)
    └── <change-id>/
        ├── proposal.md
        ├── design.md
        ├── tasks.md
        └── specs/            ← delta specs (ADDED/MODIFIED/REMOVED)
```

### Spec Content Format

Specs use GIVEN/WHEN/THEN behavioral scenarios:

```markdown
# <capability> Specification

## Purpose
[One paragraph: what this capability does and why it exists.]

## Requirements

### Requirement: <name>
The system SHALL <behavior>.

#### Scenario: <description>
- GIVEN <precondition>
- WHEN <action>
- THEN <expected outcome>
- AND <additional assertion>
```

### Archive Step (MANDATORY final task for software plans with specs)

Every software plan that touches a spec-covered codebase MUST include a final task:

```
### TASK N: Archive spec deltas

INTENT: Persist behavioral contracts from this plan's changes into the living spec.

STRUCTURE:
  1. Confirm all implementation tasks are complete and tests pass
  2. Run: /opsx:archive
  3. Verify: agent_planning/openspec/specs/<capability>/spec.md is updated with the new scenarios
  4. Commit the updated spec alongside the code changes

VERIFICATION:
  rg 'GIVEN' agent_planning/openspec/specs/<capability>/spec.md | wc -l
  → must be >= previous count (scenarios never removed unless behavior is removed)

DEVLOG: Record which scenarios were added/modified in the devlog.
```

### No OpenSpec Found (Discovery Dialogue)

If `agent_planning/openspec/specs/` does not exist or is empty, the planner MUST flag this to the user before proceeding with DR generation:

> **No OpenSpec behavioral specs found for this project.**
> Would you like to:
> (a) Proceed without specs — fastest, but no behavioral guardrails for
>     future plans
> (b) Auto-generate a baseline spec — I will traverse the codebase for
>     MCP tools, CLI subcommands, config structs, exported interfaces,
>     data models, and existing tests, and produce GIVEN/WHEN/THEN scenarios
> (c) Pause for manual spec creation

If the user picks (b), the agent follows the Auto-Generation Procedure below.
If the user picks (a), note in the plan's PROJECT CONTEXT that no behavioral
specs exist and that future plans should consider creating them.

#### Auto-Generation Procedure

Traverse the codebase and write `agent_planning/openspec/specs/<capability>/spec.md` for each
discoverable capability. Present each spec file for user review before writing
the next. Do NOT modify any source code — specs are read-only snapshots of the
current behavioral surface.

1. **MCP tool schemas** — Read all tool registrations. For each tool, write a
   requirement with GIVEN/WHEN/THEN covering happy path, validation, and error
   behavior.
2. **CLI subcommands and flags** — Read `main.go` (or equivalent entry point).
   For each subcommand, write a requirement covering flags, exit codes, and
   stdout/stderr output format.
3. **Config structs** — Read all config type definitions. Write a requirement
   covering the full field set, default values, and validation rules.
4. **Exported interfaces** — Read all `interface` definitions. Write a
   requirement for each method contract.
5. **Data models** — Read all struct/class definitions that cross module
   boundaries (API request/response types, database models, event payloads).
6. **Existing tests** — Scan test files for patterns that encode behavioral
   expectations. These become spec scenarios verbatim.

**Confirmation gate:** Wait for explicit user confirmation before accepting
generated specs. After confirmation, proceed with the planning flow — the specs
are now available as PROJECT CONTEXT.

---

## S2. Behavioral Spec Requirements in Plans

When a plan modifies code that has behavioral contracts:

- **PROJECT CONTEXT must reference the existing spec** (if one exists):
  `Read agent_planning/openspec/specs/<capability>/spec.md for current behavioral contracts before authoring tasks.`
- **CONSTRAINTS must state which scenarios must continue to pass** after the change
- **VERIFICATION must include test suite execution** — not just `go build` or `python -c "import"`

---

## S3. Interface Contracts

When a plan adds or modifies a public interface (MCP tool, CLI subcommand, API endpoint, exported function), the STRUCTURE section MUST document the interface contract:

**For MCP tools:**
```
STRUCTURE:
  Tool name: get_effort_summary
  Input schema:
    - project_id: string (required) — Vikunja project ID
    - days: int (optional, default 7) — lookback window in days
  Output schema:
    - total_minutes: int
    - tasks: list[{id, title, minutes}]
  Error behavior: returns JSON error with code -32001 if project not found
```

**For CLI subcommands:**
```
STRUCTURE:
  Command: wiki-migrate carry-forward
  Flags:
    --session-id string (required) — source session wiki page ID
    --target-id string (required) — destination page ID
    --dry-run bool (optional, default false)
  Exit codes: 0=success, 1=error, 2=page-not-found
  Stdout: JSON summary of threads carried forward
```

---

## S4. Test-Driven Verification

For software plans, VERIFICATION sections are stronger than "build passes":

**Minimum for any code change:**
```
VERIFICATION:
  go build ./...          ← build passes
  go test ./...           ← all tests pass
  go vet ./...            ← no vet errors
```

**Test package and visibility (Go-specific):** tests for unexported identifiers (lowercase names: `processAudio`, `validateConfig`, `internalHandler`) MUST live in the same directory as the code under test and declare the test file as in-package (`package X`). An external test package (`package X_test` in the same directory, the Go convention for black-box tests) cannot reference X's unexported identifiers — the compiler will reject `X.internalHandler` from `X_test`. Plans naming test files in Go MUST state the test package (`package X` vs `package X_test`) and verify visibility at authoring time, before claiming the test covers the unexported identifier.

**For MCP tools and API endpoints:**
```
VERIFICATION:
  1. Unit tests: go test ./... (or python -m pytest)
  2. Functional test (see below): invoke the tool against live/staging system
  3. Error path test: invoke with missing/invalid input, assert error response
  PASS: all assertions pass, exit code 0
  FAIL: any assertion fails
```

**For containerized projects:** Include the production image verification sequence (see `addenda/infrastructure.md §A11`). Even test-only plans must rebuild and verify the container. Copy the §A11 final task template.

---

## S5. Functional Testing (MCP Tools, APIs, CLI Commands)

This is the same rule as `addenda/infrastructure.md §A12` but stated here for completeness.

Every plan that adds or modifies a production-facing entrypoint MUST include a dedicated functional testing task:
- Exercise the production entrypoint via the production protocol (JSON-RPC over stdio, HTTP, shell)
- Test both happy path AND error path
- Never verify by module introspection alone — invoke the function and assert output

---

## S6. Code Quality Standards (MANDATORY)

All software plans MUST also read `addenda/code-quality.md`. This addendum covers:

- **Context7 integration** — query library documentation before authoring and before implementing
- **Cyclomatic complexity** — maximum 15 per function, enforced with `agent_planning/scripts/quality_gate.sh` (Ruff/gocyclo/eslint/shellcheck by language)
- **Maintainability** — no nested comprehensions, no ternary-in-ternary, max 2 chained method calls, code must be understandable to a newcomer
- **DRY** — shared patterns identified at plan-authoring time, duplication checked at code review
- **Fragility** — input validation at boundaries, explicit error handling, resource cleanup, no silent mutation

The rules below are the software-specific additions. For the full set, including context7 integration procedures, enforcement commands, and code review checklist, read `addenda/code-quality.md` in full before authoring tasks.

### Plan-Authoring Rules (in addition to code-quality.md)

- **No conditional branches in tasks** — pre-decide all outcomes (per PLAN_CORE §2)
- **Single-layer scoping** — do not cross Types + Logic + Tests in a single task (per PLAN_CORE §4)
- **Naming is explicit** — specify function names, type names, variable names; do not leave "appropriate names" to the model
- **No new dependencies without explicit approval** — state in CONSTRAINTS: "Do not add new imports beyond those listed"
- **Wrapper-first for repeated operations** — if the same shell sequence runs more than once, create a script (per EXECUTION_PROTOCOL §6)

### Context7 Integration (summarized from code-quality.md CQ1)

Before authoring any task that uses a library or framework:

1. **Query context7** for each library's current API, idiomatic patterns, and anti-patterns
2. **Embed findings** in the task's CONTEXT section as a Library Context citation
3. **Include context7 check** in each task's VERIFICATION section

The plan's PROJECT CONTEXT MUST include a Library Context table (see `code-quality.md §CQ1` for format). If context7 is unavailable, mark it `⚠️ UNTESTED (context7 unavailable)` and fall back to official docs.

---

## S7. Software Checklist (extends PLAN_CORE §12 and code-quality.md §CQ8)

In addition to the universal checklist, verify:

**Cross-cutting framework rules (R1–R7):** see `PLAN_CORE.md §2 — Cross-cutting framework rules`. The deterministic P-rules in `agent_planning/scripts/plan_lint.sh` enforce the structural surface; the R-rules close the non-mechanical gaps (operator gate, async drain, schema verify, skill transcription, §12 self-review, pre-deployment review gate, **R7 pre-execution semantic-review gate**) that lint cannot catch. Author must satisfy both layers.

**Plan-Authoring:**
- [ ] `addenda/code-quality.md` has been read in full before authoring tasks
- [ ] Library Context table present in PROJECT CONTEXT (per code-quality.md §CQ1)
- [ ] Every library-using task cites context7 source in CONTEXT section
- [ ] If touching a spec-covered codebase: PROJECT CONTEXT references existing spec; final task includes `/opsx:archive`
- [ ] §S1 spec-repo check: the implementation repo's spec tree is the authoritative reference (any divergence recorded as a §2 divergence note)
- [ ] §S1 OpenSpec dialogue outcome `(a) / (b) / (c)` recorded in PROJECT CONTEXT
- [ ] §S4 Go test visibility: test files state `package X` (in-package, for unexported identifiers) vs `package X_test` (external, for black-box); visibility verified at authoring time
- [ ] If creating new behavioral contracts: spec scenarios written in GIVEN/WHEN/THEN format
- [ ] Public interfaces (MCP tools, CLI subcommands, API endpoints) have explicit interface contracts in STRUCTURE
- [ ] Complexity limit (≤15) stated in every coding task's CONSTRAINTS
- [ ] Maintainability rules (no nested comprehensions, chain limits) in every coding task's DON'T
- [ ] DRY shared-patterns audit in PROJECT CONTEXT (per code-quality.md §CQ4.1)
- [ ] DRY anti-patterns in every coding task's DON'T
- [ ] Fragility rules (input validation, error handling) in every coding task's DON'T
- [ ] CQ10 decomposition CONSTRAINTS present for multi-check / aggregate evaluators
- [ ] `plan_lint.sh [--require-full-tasks] <plan.md>` passes before Task 1
- [ ] R7 pre-execution semantic-review gate: preamble carries the recorded review line (reviewer model, date, grade, finding count); no `FAIL` finding unresolved before Task 1

**Execution VERIFICATION:**
- [ ] VERIFICATION includes test suite execution (`go test ./...` or `pytest`), not just build/import checks
- [ ] Plans adding/modifying production-facing entrypoints (MCP tools, CLI commands, APIs) include dedicated functional testing task (production protocol, happy + error path)
- [ ] No new packages/imports added without explicit CONSTRAINTS entry
- [ ] If containerized: final task includes production image verification (or states explicit exemption)
- [ ] Every coding task's VERIFICATION includes: CONTEXT7 CHECK, `quality_gate.sh` COMPLEXITY CHECK, MAINTAINABILITY CHECK, DRY CHECK, CODE REVIEW
- [ ] Plan includes a dedicated Code Review task (per code-quality.md §CQ9) — penultimate for non-deployment plans, immediately before the first deploy/apply task for deployment plans (§CQ9.6 / R6)
- [ ] Code Review task is tailored to the plan's specific files and libraries (not a copy-paste template)
- [ ] Code Review task includes the Model Switch Pause rule (CQ9.2) in its STOP RULES
- [ ] Task ordering: non-deployment → implementation → Code Review (N-1) → Doc Update (N); deployment → authoring/testing → Code Review → deploy → Doc Update
