# Plan Authoring — Core Protocol

_Last updated: 2026-10-25_

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

The AI acts as **architect, planner, and technical expert**. The user is the **design authority and Subject Matter Expert (SME)** — the authority on domain knowledge, business context, acceptance criteria, what "done" looks like, and the system's design intent.

| Role | Owns |
|------|------|
| AI (Architect) | The question set (finding the decisions that exist); the option space; consequences and recommendations; task decomposition, file structure, implementation mechanics, verification strategy |
| User (Design authority + SME) | Domain rules, business constraints, acceptance criteria, integration requirements, scope, and **the selection of system/design intent from the AI's option space** |

The AI must **never assume domain knowledge**. It owns the *menu* — what the decisions are, what each option costs, which one it recommends — and the user owns the *order*: which option is taken.

**Default ownership of a decision** (three cases, no gap):

| The decision… | Default owner |
|---|---|
| fixes what the system does, how it is shaped, or what it optimises for | **the user** |
| is a structural fork the reproducibility test admits — module boundary, data flow, dispatch / error / concurrency strategy, ordering, idempotency | **the user** |
| is a local mechanic fully determined by the codebase and the other decisions — a name, a file layout, a loop shape any competent implementer lands on identically | **the AI**, recorded and overridable |

The middle case is the one that matters: a fork the executor would otherwise *invent* is a design commitment, not a mechanic. The AI may propose it with a `strong` recommendation, but a design commitment is not the AI's to take unilaterally — otherwise "mechanics" becomes the label that lets the agent quietly own design. Tag every DR honestly; an AI-owned structural fork is a delegation, and delegation is visible.

### Tier Classification (Choose Before Proceeding)

Before beginning discovery, classify the request into one of three tiers. The tier determines the discovery depth.

| Tier | Trigger | Discovery Method |
|------|---------|-----------------|
| **Tier 1** | Single-system, no remote deployment, <5 tasks. Bugfixes, single-file refactors, documentation, local scripts. | 7-category quick interview + restatement gate |
| **Tier 2** | Remote systems, deployment, monitoring setup, multi-host operations (task count is a heuristic — a single-system deployment stays Tier 2 even above 15 tasks; see the disambiguation below). | Domain-specific Decision Records (DRs) + Discovery Summary + restatement gate |
| **Tier 3** | Multi-system integrations where 3+ independent systems must coordinate, multi-phase migrations with data-at-risk, or a DR graph deep or wide enough that a diagram earns its place. | Grouped DRs + **rendered** dependency graph + Architecture Summary + restatement gate |

**Tier 2 vs Tier 3:** Tier 2 already carries `Dependencies:` per DR and walks them as a frontier, so a DR that gates another DR is *not* by itself a Tier 3 signal. Tier 3 is when the graph stops being readable inline — several DR layers, cross-system edges, or enough of them that the gating map needs its own artifact. When in doubt, choose the higher tier. The cost of under-scoping discovery is tasks that silently fail on unresolved assumptions.

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

After the interview, produce the Restatement Gate (see below). No DR ledger is required.

Every interview question carries the AI's recommended answer with a one-word strength (`strong` / `weak` / `none`), so a whole round can be answered with `y`, a pick, or an override. If an answer reveals a **fork** (irreversible, expensive to change, silent failure mode, or it gates other work), promote it to a mini-DR and resolve it before authoring — Tier 1 stays cheap, but not at the cost of an unmade decision. A mini-DR is a real DR and carries the full §0 record and the `Owner` tag; the only thing Tier 1 drops is the full ledger, not the discipline.

---

### Tier 2: Domain Discovery — DR-Grilling

**The AI finds and frames the decisions; the user makes them.**

This mirrors how a Red Hat architect interrogates a client before an engagement: the architect writes the Issue (what is at stake, why it is consequential), enumerates the options, and recommends one. The client is not expected to know the right questions — the architect does. The client *is* expected to make the design choice.

#### Decision Record Format

```
DR-N: [Short title]
Owner: SME | shared | AI          -- default per the ownership rule above
Issue: [2-5 sentences written by the AI: what this decision controls, the failure
        mode of the wrong choice, and why it must be settled before authoring]
Options:
  A. <option> — <consequence / what it costs>
  B. <option> — ...
➡️ Recommendation: <option> (strong | weak | none) — <reason>
   weak → also state what would change my mind
   none → omit the recommendation line; this decision is the user's to design
Dependencies: [DR-N, DR-M — DRs that must be resolved first, or "none"]
Decision: [the user's: an option letter, an authored decision, or the literal `accept`]
Assumptions: [the user's — the conditions the decision holds under]
```

#### Which decisions earn a DR (the reproducibility test)

A decision earns a DR when it is a **fork**: two competent engineers holding only the spec could build materially different software.

- It shapes observable behaviour or acceptance → DR (and the behaviour lands in the spec).
- It supports the spec's implementation and would otherwise be *invented* by the executor — module boundary, data flow, dispatch / error / concurrency strategy, ordering, idempotency → DR.
- It is determined by the codebase, the spec, or another DR → not a DR; it is plan detail (STRUCTURE / NAMING / CONSTRAINTS).

**Ledger acceptance test:** Spec + DRs must let a competent agent rebuild the software without inventing a design.

The four criteria below remain as *detection heuristics* for finding forks — they generate candidates; the reproducibility test decides:

- Is **irrevocable** or **expensive to change** after execution begins
- Involves a **trade-off** the user may not be aware of
- Has **silent failure modes** if the wrong assumption is made
- Creates **dependency ordering** issues for other tasks

DRs are organized by domain area (storage, auth, rollback, scope, integration), not generic categories. The Issue, Options, and Recommendation are written by the AI.

**Ceiling:** if a ten-task plan is producing 40+ DRs, the ledger is doing the executor's job. Collapse the mechanical implementation forks into one "Implementation commitments" DR per task; the reproducibility test still holds.

#### Rounds: the design tree, worked by frontier

The DR set is **emergent, not fixed in advance**. Work it as a design tree in dependency layers:

- The **frontier** is every DR whose `Dependencies` are already resolved — the questions askable *now* without guessing at an unanswered one. Present the whole frontier in one message, grouped by domain area. A question whose answer depends on a DR still open in this round belongs to a *later* round.
- **New layers appearing as answers land is the process working, not scope creep.** Answering a layer uncovers the questions it implies; that is how a tree gets discovered. There is no cap on questions and no cap on rounds.
- What keeps a large round tractable is the **answer cost**, not the round size: `strong` → `y`; `weak` → pick, or `accept` a called coin-flip; `none` → the user's to author.
- **Facts are the AI's job, never the user's.** Anything lookup-able (a file, a version, an API shape, a live system state) is resolved by the AI — dispatch a subagent — and the rest of the frontier is asked without waiting on it.
- **Do not pad to a round number.** A candidate that fails the reproducibility test is filler and must be cut.

#### Resolution vocabulary

- An option letter, or an authored decision → recorded as the decision.
- `accept` → recorded verbatim as `Decision: accepted AI recommendation`. A bare `yes` on an AI-owned DR is treated as `accept`. A bare `yes` on an SME-owned DR is **also accepted, but recorded as `accepted AI recommendation`** — never laundered as an authored decision. The record must show which decisions the user actually made.
- A `strong` strength on a genuine fork is inflation; `none` used to offload a decision the AI could have reasoned about is abdication. Both are authoring defects.

#### Terminal condition

Discovery ends when the frontier is empty **and** every DR carries a resolved `Decision`. The Discovery Summary then folds the decisions in concretely, and the Restatement Gate confirms it. A layer surfacing *after* the restatement is confirmed is a scope change, not a question — surface it and amend the scope before continuing.

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

**1. Grouped DRs with a rendered dependency graph.** DRs are organized into domain sections (Storage & Deployment, Network & Access, Migration, Rollback & Operations). Tier 2 already records `Dependencies:` and walks them as a frontier; Tier 3's addition is that the graph must be **drawn** — after all DRs are resolved, the AI produces a dependency map showing which decisions gate which tasks, because at this scale the edges no longer fit inline.

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

**Plan-file embedding requirement:** The Architecture Summary (End State / Integration Points / Data Flows / Decision Dependencies) and the DR→task gating map are **required plan-file sections**, not chat output. The reviewer can confirm them only if they are present in the plan under `ARCHITECTURE SUMMARY` and `DECISION RECORDS` (with the gating map recorded in DECISION RECORDS or immediately under ARCHITECTURE SUMMARY). Plans that produce this content only in chat are non-compliant with R5 evidence-cited.

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
- **Owner:** [SME | shared | AI]
- **Options:** [A. … — consequence / B. … — consequence]
- **Recommendation:** [option — strong | weak | none]  (omit the line when `none`)
- **Decision:** [option letter | authored decision | "accepted AI recommendation"]
- **Assumptions:** [What must be true for this decision to hold]
- **Dependencies:** [none / DR-N, DR-M]
```

**Rules:**
- Include only DRs that were **resolved** during Section 0 discovery — §0's terminal condition
  (frontier empty AND every DR resolved) means no DR reaches this section still open. A DR
  deferred to a follow-up plan *is* resolved: its `Decision` names the deferral and the plan
  it lands in, and it must NOT gate any task here.
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

**Allowed fallback form:** an access-gate directive line whose text starts with the literal `If ANY check fails` prefix (for example, `If ANY check fails: mark task BLOCKED with specific evidence. Do NOT deploy.`) is exempt from this rule — it names the canonical access-gate fallback, not a pre-decideable outcome.

**Corollary (DR-backed directives).** A task that wants "if X then do Y" has one of two causes: X is determined by the code, the spec, or a resolved DR — in which case write it as a directive; or X is genuinely undecided — in which case that is an **unmade DR**, not task detail. Promote it to a DR, ask it, record the decision, then write the directive.

### Cross-cutting framework rules (R1–R14)

These rules close non-mechanical gaps that the deterministic lint (P1–P8) cannot catch. They are enforced by the addenda §checklists, the R7 plan-validation dispatch (§8.7), the Code Review task, and — optionally, operator-run — the semantic reviewer (`agent_planning/scripts/plan_review.sh`).

- **R1 Operator gate for destructive ops.** A plan with any irreversible remote or data mutation MUST include an explicit operator-confirm step between dry-run and apply, written into the plan (not into chat).
- **R2 Async / job-queued API drain.** A plan consuming an API that returns-before-complete MUST specify poll-until-drained with a wall-clock STOP rule and a per-call timeout.
- **R3 API result-schema verification.** A plan consuming a collection result MUST name the element schema (field names) or mark `⚠️ UNTESTED` with a runtime dump step.
- **R4 Referenced skills loaded at authoring.** A task naming a skill MUST transcribe that skill's exact format and constraints into the plan.
- **R5 §12 self-review non-optional, evidence-cited.** Before declaring a plan done, every checklist item in §12 must carry evidence (a `✅ VERIFIED via <command> on <YYYY-MM-DD>`, `❌ ASSUMED`, `⚠️ STALE`, or equivalent provenance mark). A single aggregate count command does not satisfy the per-item rule, and an item without evidence does not count as passed. The `plan_lint.sh` R5 §12 coverage check emits the evidence-cited line count as advisory output; the `§12 pass: <n>` preamble number is optional when the lint output is preserved in the devlog. If the plan modifies the checklist it measures (a framework plan), re-record `n` at closeout against the post-change file.
- **R6 Pre-deployment review gate.** A plan with a deployment/apply phase MUST place the dedicated Code Review task before the first task that mutates live or remote state, and every deployment task MUST gate on the review passing (code-quality.md §CQ9.6). Non-deployment plans keep the penultimate Code Review placement. A source-repo mirror/distribution sync is not a deployment (see §CQ9.6).
- **R7 — Pre-execution plan validation (re-instated 2026-10-25).** For Tier 2/3 plans, after the deterministic gates pass (lint + §8.6 reconciliation + selfcheck) and before `init_execution_dir.sh`, the author MUST dispatch the clean-context `plan-validator` subagent (§8.7; pinned `opencode/deepseek-v4.1-flash#max`) and record the validation line in the plan preamble. Zero FAIL rows opens the gate; every FAIL is remediated and re-validated once. Tier 1 plans are exempt. `plan_review.sh` remains a separate, optional, operator-run tool — it is not this gate. (R7 was retired 2026-10-04 as a `plan_review.sh`-backed shell gate after an unattended-loop incident; re-instated 2026-10-25 on the §9.0 subagent mechanism, which terminates and cannot loop.)
- **R8 Assertable acceptance.** An acceptance criterion MUST be a binary, mechanically checkable assertion — present/absent, exact count, exact string, exit code, or a named fixture. Subjective adjectives ("clean", "correct", "names only", "looks right", "unambiguous") are not criteria. When the criterion describes a rendered or serialized artifact, name the assertion that proves it (e.g. "the `title` column is absent", "the list has 3 entries", "the command exits 0"). If two readers can interpret a criterion differently, it is a defect. Applies to every DON'T, VERIFICATION, and objective success-metric line.
- **R9 Baseline-verified absolutes.** Any check that asserts an absolute or negative about the tree as-shipped ("returns nothing", "no matches", "expect 0", "is empty", "no nested X", "no duplicates", "must not contain") MUST be run against the pre-change tree at authoring time and its result cited (`✅ VERIFIED ... baseline`, or `⚠️ UNTESTED (baseline)`). If the baseline already violates the absolute, the plan MUST either scope the check to the diff ("no *new* occurrences", "none introduced by this change") or include a task that clears the baseline first. An absolute written without baseline evidence is a defect: it may be unsatisfiable before the plan starts.
- **R10 Behaviour-anchored tests and guards.** Static or source-level guards (grep/regex assertions, snapshot guards, generated-fixture checks) MUST assert observable behaviour or a stable identity (a function/selector/key/section), never incidental expression text or line numbers. A guard that constrains *how* code is written rather than *what* it does is a defect. When a gate-forced refactor (complexity, format, lint) moves a guarded expression, the guard is re-pointed at the new stable identity in the same change and the re-point is logged; the guard's assertion strength must not be weakened.
- **R11 Review-remediation authority.** STOP RULES are scoped to the task that carries them. The dedicated Code Review task (Task N-1 / Task R) MAY modify any artifact in its review scope from an earlier task — including that task's tests and guards — to remediate a finding, and MUST log each modification with its justification in the devlog. A cross-task conflict between a STOP RULE and a review finding is resolved in favour of the review: never ship a `FAIL` to satisfy a STOP RULE.
- **R12 Producer–consumer representation fidelity.** When a task moves a value from where it is produced to a consumer that may expect a different representation (a stored encoding, a serialized form, a level-keyed map, a per-renderer field), the consuming task's CONSTRAINTS MUST quote the consuming site's expected representation with provenance, name the stored-form→consumed-form transformation (or cite the consuming site that proves none is needed), and carry at least one acceptance that feeds the producer's actual output through the real consumer path. Producer-side-only assertions — counts, key names, category labels — do not satisfy this rule when the consumer receives a different shape.
- **R13 File budget enforcement.** Every coding task that modifies source files MUST include `agent_planning/scripts/quality_gate.sh --file-budget [modified_paths]` in its VERIFICATION (additive to the `--lang` complexity invocation). Caps: JS/TS 800, Go 500, Python 500, Bash 200 (spec: `addenda/file-budget.md §FB1`). An over-cap file is decomposed, or carries an in-file sentinel whose reason names the plan or issue that justifies the override. Enforcement is per-plan: only the plan's named paths are checked, so a plan that does not touch a file never gates it.
- **R14 Browser-UI acceptance (Playwright).** A plan that adds or modifies a browser-rendered UI (any browser-context front-end source, a served SPA or static bundle, or a dashboard UI surface — see `addenda/web.md §W1`) MUST include a dedicated Playwright functional-test task **before** the Code Review task. The task runs the real surface, drives the real user path through the DOM, asserts observable behaviour (not module internals), covers the happy path and an error/refusal path, runs headless, and tears its server down. An operator browser checklist alone does NOT satisfy this rule. When Playwright genuinely cannot run, record `Playwright: N/A — <reason>` in the preamble and mark the task `⚠️ UNTESTED (playwright unavailable)`. See `addenda/web.md`.

### Inter-task data dependencies
When a later task depends on data discovered by an earlier task, the plan author MUST NOT defer the values to runtime with placeholders. Instead:

1. **Enumerate the expected values** from the source material as concrete literals in the later task's STRUCTURE.
2. **Add a stop rule** to the later task: "If live data from Task N differs from this list, stop and report the discrepancy before proceeding."

**Bad:**
- `WHERE na.ip IN (<ghost_IPs_from_preflight>)`

**Good:**
- `WHERE na.ip IN ('10.0.0.101', '10.0.0.102', '10.0.0.103')`
- STOP RULE: "If the ghost IP set from Task 1 differs from this list, stop and report before deleting."

### Change-Impact Enumeration (required for change tasks)

A task that changes an interface, an ordered/structured output, or a guarded branch MUST enumerate the existing dependents of that change at authoring time and paste the evidence into the task's CONSTRAINTS. The author performs the enumeration; the plan carries the result. This one step closes four recurring authoring defects: stale coordinates, unenumerated dependents, unquoted incumbent structure, and untraced branch interaction.

| Change | Required evidence in CONSTRAINTS |
|--------|----------------------------------|
| Interface change (any callable signature or parameter meaning, including module-private / unexported functions; exported symbol, API shape, DB column, config key, event/message field, CLI flag) | The pasted dependent listing (search output with match count) plus the call sites the plan updates in the same task or a paired task |
| Ordered/structured output change (render order, serialization order, stage order, log or section order, document structure) | A verbatim quote of the incumbent order from source, with the required new order stated as equal to it or as an explicit, justified change |
| New value threaded into an existing guarded branch | A verbatim quote of the receiving guard (the condition that consumes the new value) |
| Identity asserted by a test, guard, lint rule, or document (element id, config key, symbol name, wire field, CLI flag, file path, storage key) | The pasted listing of the asserting artifacts (search output with match count) plus the same-task update, or the declared interim-stale window — which task repairs the assertion and why a red or misleading suite is permitted in the interval |
| Replaced or removed behaviour surface (user-visible control, API field, CLI flag, file format, scheduled job) | The enumerated behaviours the old surface provided — including the degenerate / empty case that exercises none of its branches — each mapped to where it lands in the new design or explicitly dropped with rationale |
| New mutable state (context field, cache, session store, lock, registration table) | The state's create / read / clear paths, plus the existing teardown, reset, and re-entry handlers that reset sibling state; the new state joins those resets in the same task, or the task states why not |

A prose catch-all ("every existing caller…", "all dependents…") is **not** enumeration. The dependent listing must be the verbatim output of a codebase-wide search command, provenance-marked ✅ TESTED so the rerun self-check can re-execute it, with the match count stated. A parameter whose **meaning** changes is a signature change even when the argument count is unchanged, and even on module-private / unexported callables — visibility has nothing to do with blast radius.

Two rules apply to every reference in a plan:

- **Cite mutable artifacts by stable identity, never by volatile coordinates.** Use the function, selector, key, or section name. Never write a line number for source the executor will edit; it drifts on the first edit and a stale coordinate silently misdirects.
- **Provenance is evidence, not memory.** A `✅ VERIFIED` / `✅ TESTED` mark requires the command output that backs it. Without it, mark `❌ ASSUMED` (§6).

Domain addenda supply only the *discovery command* for their ecosystem; the rule itself is universal.

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
  - If this is Task 1, create the devlog file first
```

After the devlog update, also perform the EXECUTION_PROTOCOL.md Section 4 writeback: update TASK_QUEUE.md and STATE.md.

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
- **Split by token budget, not by task count.** Task count is a fallback heuristic, not the sizing rule — see the plan-sizing rule below.
- **Large file reference rule:** If any single file referenced by the plan's KEY FILES REFERENCE or CONTEXT sections exceeds 500 lines, the plan MUST include an explicit token budget estimate at the top of the OBJECTIVE section. Format: `Token budget: ~XXX K tokens (plan + N files: file1 L lines, file2 M lines)`. Distinct from the per-language file caps in `addenda/file-budget.md §FB1`, which govern authored files; this rule governs plan token budgets.
- **Batch-task risk:** When a single task's STRUCTURE describes generating more than 200 lines of output, that task MUST be split into sub-tasks. The risk is attention fragmentation — the model exhausts focus on early details and silently skips later ones.

### Plan Sizing — the plan is the ticket

A plan is the unit of deliverable work: its own execution directory, its own `STATE.md`, its own terminal Code Review. The spec lives *above* it (`agent_planning/openspec/specs/` for capability plans); the task lives *below* it. That makes the plan the ticket-equivalent, and it carries the ticket constraint:

- **Size the plan to ~one smart zone (~150 K tokens) of fresh work.** Plan file + per-session context + the reading, editing, and verification the tasks demand — that is the budget. Estimate it from the reading load (files that must be read in full), the writing load, and the output the VERIFICATION commands will capture.
- **This floor is deliberate and overrides the model addenda's capacity ceiling.** Past the smart zone a model keeps *completing* while accuracy degrades — a silent failure no gate detects. The addenda's figures answer a different question: *"will it fit?"*, not *"will it still work?"*. Capacity limits a plan that would not fit at all; the smart zone limits one that fits and stops working well. Both bind; the tighter one wins.
- **A larger deliverable is two plans, not one plan with more tasks.** One deliverable end-state each. `§11 Sequential Plan Integrity` governs how they chain.
- **Small plan file.** The plan is loaded every session, so ticket-style brevity is a context-budget measure as well as a staleness one: state behaviour and acceptance criteria, cite a path only where the path *is* the interface, and leave the rest to the codebase. Provenance marks (§6) are the deliberate exception — evidence costs tokens and earns them.
- Record the estimate as a preamble line when the plan is near the budget: `Token budget: ~XXX K tokens (plan + N files: file1 L lines, …)`. Format and mandatory trigger: see the Large file reference rule above.

**The 150 K figure is provisional.** It is inherited from observation of another workflow, not measured here (the operator's own unsystematic estimate was ~250 K). Treat it as a floor to be revised once telemetry records real plan budgets — tighten or loosen it on evidence, never on the next uncited number.

**Model capacity guidance:** window sizes and hard capacity ceilings are in `deepseek/MODEL_ADDENDUM.md` §D1 or `minimax/MODEL_ADDENDUM.md` §M1. Those describe what the model *can* hold; the smart-zone floor above describes what it does *well*, and the floor governs plan sizing.

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
| `✅ VERIFIED-ABSENT` | The planner ran this exact command and confirmed it returns zero matches / exits non-zero (a tested absence). Recognized by §6 and by the P1 marks regex; deliberately never re-executed by plan_selfcheck --rerun, which treats non-zero exit as failure |
| `📖 FROM-DOCS` | Copied verbatim from official documentation (cite URL or man page) |
| `⚠️ UNTESTED` | Synthesized by the planner — executor must validate before relying on output |

**Rules:**
- Commands without a provenance mark are treated as `⚠️ UNTESTED` by default.
- `⚠️ UNTESTED` commands MUST include a verification step in the task that confirms the command works before using its output for subsequent steps.
- The planner SHOULD test commands when possible. When the planner cannot test (no access to the target host, no API credentials), mark `⚠️ UNTESTED` and add a note explaining why.
- Query languages (LogQL, PromQL) are especially prone to syntax drift between versions. Always cite the docs version when using `📖 FROM-DOCS`.
- Commands marked ✅ VERIFIED-ABSENT are exempt from rerun re-execution: a search that correctly returns zero matches exits non-zero, so re-running it would false-fail. Mark a tested absence ✅ VERIFIED-ABSENT, never ✅ TESTED. Lines marked ⚠️ UNTESTED are likewise never re-executed — an UNTESTED line states an expectation, and its ✅ TESTED token, if any, is a baseline quote. ✅ TESTED asserts the command holds against the CURRENT tree (`plan_selfcheck --rerun` re-executes it verbatim in the caller's working directory): quote pre-change state as ✅ VERIFIED, not ✅ TESTED, and give rerun-eligible commands absolute paths (relative ones resolve only from one cwd).

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

## 8.6. Authoring Closeout — Reconciliation Pass (trial 2026-10-07)

After the plan draft is complete, and before `plan_selfcheck.sh` or
`plan_lint.sh` runs, the author performs ONE reconciliation pass: bounded,
single-purpose, same agent (same session preferred). Its only objective is to
make every claim in the plan true against the working tree. It is not a review,
not a grade, and it does not change scope.

- Verify claims about existing state; declared to-be-created outputs are out of
  scope.
- Checklist — eight classes: (1) re-run every cited command or its closest safe
  equivalent; (2) re-count every stated number; (3) re-resolve every cited path
  and symbol; (4) re-run every enumeration and diff the live set against the
  plan's list (missing and phantom); (5) re-check every absolute/negative
  baseline (R9); (6) quote the consumer's expected representation for every
  cross-task value (R12); (7) resolve every provenance mark against its backing
  evidence; (8) resolve every fork in the task text — a spec line, a resolved DR,
  or the codebase. An unresolved fork is an unmade DR: promote it, ask it, record
  it before execution (§0).
- Downgrade anything unverifiable to `❌ ASSUMED` or `⚠️ UNTESTED` with a
  reason. The pass ends when the deterministic gates are green and no
  resolvable mark remains.
- Record one preamble line: `Reconciliation: 12 claims verified, 2 corrected
  (2026-10-07)` — or `Reconciliation: N/A — no repo-state claims`. Tier 1
  plans are exempt.
- Trial (adopted 2026-10-07): reviewed by the operator after 5 Tier-2/3 plans,
  against recorded per-plan pass cost and catch data; removed if it
  demonstrates no catch. The advisory `plan_lint.sh` record check mirrors this
  subsection and never blocks a plan.

---

## 8.7. Plan Validation Dispatch (R7 — Tier 2/3)

After the deterministic gates pass (`plan_lint.sh` exit 0, §8.6 reconciliation
recorded, `plan_selfcheck.sh` clean) and BEFORE `init_execution_dir.sh`
bootstraps execution, the plan MUST be validated by a **clean-context
subagent** — the same discipline §9.0 (EXECUTION_PROTOCOL.md) imposes on Code
Review. The author cannot validate their own plan: the reasoning that produced
a defect is the reasoning that failed to notice it.

- **Agent:** copy `agent_planning/reviewer/plan-validator.md` to
  `.opencode/agents/plan-validator.md` and dispatch it as `plan-validator`.
  It ships with `model: opencode/deepseek-v4.1-flash#max` pinned (operator
  choice 2026-10-25 — flash at max effort is a deliberate cost/capability
  pick; a DeepSeek-authored plan yields Row 0 `ADVISORY`, clean-context only,
  which is an accepted trade, not a defect).
- **Prompt carries:** the plan file path, the authoring model id, and the path
  of this file (its §12 checklist is the validator's rubric). **Never** the
  authoring transcript, DR rationale, or discovery narrative — that context is
  the blind spot.
- **Blocking:** the gate opens only on zero FAIL rows. Every FAIL is
  remediated in the plan by the authoring session, then re-dispatched once.
  A validation run by the authoring agent itself is a defect regardless of
  what it reported. If no subagent dispatch is available, mark the plan
  `⚠️ UNTESTED (validation)` with `[SCOPE-GAP]` and surface it to the operator.
- **Recording:** one line in the plan preamble:
  `Plan validation: 0 FAIL, N ADVISORY — plan-validator (opencode/deepseek-v4.1-flash#max) on YYYY-MM-DD`
  A remediation re-dispatch appends `; re-validated YYYY-MM-DD`. Tier 1 plans
  are exempt (TIER1_FASTPATH.md).
- **`plan_review.sh` is not this gate.** It stays optional, operator-run,
  single-pass, approval-gated, and cross-model — a separate tool, unaffected
  by R7.
- **No unattended-loop risk** (the failure mode that retired the 2026-10-04
  R7): the validator is a harness-native subagent dispatch — it terminates and
  returns its findings as data; it is not a shell tool an agent re-invokes
  from a non-TTY session. One dispatch, plus one re-dispatch per remediation.

---

## 9. Devlog Pairing (MANDATORY)

Every plan execution MUST produce a devlog entry. Plans executed without a devlog are incomplete.

### Context Recovery Principle

The devlog is the authoritative **audit trail and evidence record** — not the primary recovery mechanism. For fast session recovery, the primary context source is `agent_planning/execution/<project_name>/STATE.md`, per `agent_planning/EXECUTION_PROTOCOL.md`. `TASK_QUEUE.md` is authoritative for remaining tasks; the devlog does not carry a regenerated "Remaining Tasks" checklist.

### Devlog Lifecycle

1. **CREATE the devlog after the FIRST task completes.** Populate the title, date, Objective section, and the first task's execution details.
2. **UPDATE the devlog at the END of EACH subsequent task.** Do not batch updates — write them while details are fresh.
3. **FINALIZE the devlog after all tasks are complete.** Replace the placeholder "Remaining Tasks" section with the Result / Conclusion / Next Steps section.

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
_(Replaced at closeout with "Result / Conclusion / Next Steps". The queue is authoritative — see `TASK_QUEUE.md`.)_

## Result / Conclusion / Next Steps
(Replaces "Remaining Tasks" when all tasks are finalized.)
```

> The devlog does not carry a regenerated "Remaining Tasks" checklist. `TASK_QUEUE.md` is authoritative; the devlog points at it for remaining tasks. The closeout step replaces this section with "Result / Conclusion / Next Steps".

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

**Capture-at-completion (MANDATORY).** Captured output MUST reflect the task's *final* tree. If a task edits a file after capturing a command's output — including a complexity/lint refactor that lands at the end of the task — re-run and re-capture that command before marking the task done. A capture that no longer reproduces against the shipped file is a defect, not a historical record: correct it in the devlog and note the re-capture. This closes the failure where a task refactors a symbol after quoting a search result for it.

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
- [ ] Every DR carries `Owner`, enumerated `Options`, and a recommendation with a strength (or an explicit `none`)
- [ ] Every DR's `Decision:` is resolved — an option letter, an authored decision, or an explicit `accept`; no bracketed placeholders (`plan_lint.sh` fails them)
- [ ] Rounds were asked as the dependency frontier — no DR asked before its `Dependencies` resolve; new layers surfaced as answers landed were asked, not suppressed
- [ ] Ledger acceptance test applied: Spec + DRs let a competent agent rebuild without inventing a design
- [ ] Ownership defaults respected — design intent **and** structural forks taken by the user; only codebase-determined mechanics defaulted to the AI, recorded and overridable
- [ ] Tier 1: any revealed fork was promoted to a mini-DR and resolved, not absorbed into a task
- [ ] Tier 2/3: Discovery Summary produced and confirmed
- [ ] Tier 3 only: Architecture Summary produced and confirmed
- [ ] Restatement gate confirmed by user before plan authoring began
- [ ] No tasks added beyond the confirmed restatement scope

**Plan Structure**
- [ ] OBJECTIVE section present and clear
- [ ] Plan sized to ~one smart zone of fresh work — plan = ticket (§5 Plan Sizing); a larger deliverable is split into plans, not padded with tasks
- [ ] PROJECT CONTEXT lists language, libraries, workflow
- [ ] KEY FILES table maps all referenced paths
- [ ] Each task has: INTENT, STRUCTURE, CONTEXT, CONSTRAINTS, DON'T, VERIFICATION
- [ ] Each task touches only ONE pipeline layer
- [ ] Tasks are explicitly ordered — **execution is serial**; the frontier in §0 orders *DRs*, not tasks. A task-level `blocked_by` edge is not yet modelled (deferred with the ticket-graph work)
- [ ] Naming is specified for all new files/functions/variables
- [ ] No contradictions between tasks
- [ ] Verification claims marked with provenance (✅ VERIFIED / ❌ ASSUMED / ⚠️ STALE)
- [ ] All commands/queries/API calls marked with provenance (✅ TESTED / ✅ VERIFIED-ABSENT / 📖 FROM-DOCS / ⚠️ UNTESTED)
- [ ] Reconciliation pass recorded in the preamble (PLAN_CORE §8.6) — or an explicit N/A
- [ ] ⚠️ UNTESTED commands have a verification step before their output is used
- [ ] Change-impact: every task changing an interface, an ordered output, or a guarded branch pastes its dependent listing / incumbent-shape quote / guard quote into CONSTRAINTS, and no source reference uses a line number (§2 Change-Impact Enumeration)

**Devlog (Section 9)**
- [ ] Plan specifies devlog filename in `agent_planning/execution/<project_name>/devlogs/`
- [ ] EVERY task's VERIFICATION section ends with an explicit DEVLOG update step
- [ ] VERIFICATION sections include instruction to copy-paste exact command output
- [ ] Devlog does not carry a regenerated "Remaining Tasks" checklist; `TASK_QUEUE.md` is authoritative

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

**Cross-cutting framework rules (R1–R14)**
- [ ] R1: Destructive ops in the plan include an explicit operator-confirm step between dry-run and apply
- [ ] R2: Async / job-queued API consumers include poll-until-drained with a wall-clock STOP
- [ ] R3: Collection results have either a named element schema or a `⚠️ UNTESTED` dump step
- [ ] R4: Every skill named in a task has its format/constraints transcribed into the task body
- [ ] R5: Every §12 checklist item carries evidence (`✅ VERIFIED via <command> on <date>`, `❌ ASSUMED`, `⚠️ STALE`, or equivalent); the `§12 pass: <n>` preamble number is optional when `plan_lint.sh` R5 §12 coverage output is preserved in the devlog. Aggregate-count alone is insufficient; an item without evidence is not passed. Framework plans re-record `n` at closeout against the post-change file.
- [ ] R6: Deployment plans place the Code Review task before the first deploy/apply task; deploy tasks gate on review pass (CQ9.6)
- [ ] R7: Tier 2/3 plan validated by the clean-context `plan-validator` subagent (§8.7) after lint/selfcheck and before bootstrap; validation line recorded in the preamble; 0 FAIL rows. Tier 1 exempt
- [ ] R8: Every acceptance criterion is assertable — present/absent, exact count, exact string, exit code, or named fixture; no subjective adjective stands as a criterion
- [ ] R9: Every absolute/negative check ("returns nothing", "expect 0", "no X") was run against the pre-change tree at authoring and cites the baseline result, or is explicitly scoped to the diff, or the plan clears the baseline first
- [ ] R10: Source-level/static guards assert behaviour or a stable identity, never incidental expression text or line numbers; guard re-pointing is logged
- [ ] R11: STOP RULES are task-scoped; the Code Review task may remediate an earlier artifact (guards included) and logs each modification
- [ ] R12: every producer→consumer value move quotes the consumer's expected representation with provenance, names the stored→consumed transform (or cites the proof none is needed), and carries one acceptance through the real consumer path
- [ ] R13: every coding task that modifies source files includes `agent_planning/scripts/quality_gate.sh --file-budget [modified_paths]` in its VERIFICATION; over-cap files are decomposed or carry a sentinel whose reason names the justifying plan (caps: `addenda/file-budget.md §FB1`)
- [ ] R14: every web-related plan (browser-rendered UI — `addenda/web.md §W1`) has a dedicated Playwright functional-test task before Code Review, driving the DOM and asserting observable behaviour; OR carries `Playwright: N/A — <reason>` with the task marked `⚠️ UNTESTED (playwright unavailable)`
- [ ] Asserted-identity co-scheduling: every task changing an id/key/symbol/flag/path/storage key pastes the asserting-artifact listing and updates it same-task, or declares the stale window
- [ ] Replaced-surface enumeration: every task removing or replacing a behaviour surface enumerates the old behaviours including the degenerate case, and states where each lands or why it is dropped
- [ ] State-lifecycle declaration: every task introducing mutable state names its create/read/clear paths and the sibling-reset handlers it joins
- [ ] Repo-state provenance: every claim about binary names, target hosts/IPs/URIs, file existence, API signatures, or dependency versions carries a `✅ VERIFIED via <command> on <date>` or `❌ ASSUMED` mark (§6)

**Code Quality Gate (code-quality.md — MANDATORY for code-producing plans)**
- [ ] `code-quality.md` was read before plan authoring (not optional for code plans)
- [ ] PROJECT CONTEXT declares `language` / `languages`
- [ ] Every code task's VERIFICATION includes `agent_planning/scripts/quality_gate.sh <paths>` (or the language-specific command it wraps)
- [ ] Each code task's VERIFICATION includes `agent_planning/scripts/quality_gate.sh --file-budget [paths]` (R13)
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
