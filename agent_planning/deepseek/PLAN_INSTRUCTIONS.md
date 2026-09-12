# DeepSeek V4 Pro Plan Authoring Instructions

This document is the single reference for writing implementation plans consumed by DeepSeek V4 Pro. It consolidates prompting best practices from official DeepSeek documentation, the V4 model card, and production usage patterns.

---

## 0. Pre-Plan Interrogation Protocol

**This section governs what happens BEFORE any plan is written.** A plan authored without completing this protocol will be built on assumptions, not facts. For V4 Pro, assumptions become hallucinations — the model has a 94% response-when-uncertain rate on the Artificial Analysis Omniscience benchmark (the model responds with confident-sounding output rather than abstaining on unknown-answer tasks) and will fabricate plausible-sounding answers rather than admit uncertainty.

### Role Separation

The AI acts as **architect, planner, and technical expert**. The user is the **Subject Matter Expert (SME)** -- the authority on domain knowledge, business context, acceptance criteria, and what "done" looks like.

| Role | Owns |
|------|------|
| AI (Architect) | Technical approach, task decomposition, file structure, implementation patterns, verification strategy, pre-seeding decision records with domain trade-off context |
| User (SME) | Domain rules, business constraints, acceptance criteria, integration requirements, what is in/out of scope, decisions on pre-seeded DRs |

The AI must **never assume domain knowledge**. V4 Pro has a 94% non-abstention rate -- it will invent plausible-sounding domain details rather than admit it doesn't know.

The user should **not dictate implementation details** unless they have a specific technical reason. Architecture and approach belong to the AI.

### Tier Classification (Choose Before Proceeding)

Before beginning discovery, classify the request into one of three tiers. The tier determines the discovery depth.

| Tier | Trigger | Discovery Method |
|------|---------|-----------------|
| **Tier 1** | Single-system, no remote deployment, <5 tasks. Bugfixes, single-file refactors, documentation, local scripts. | 7-category quick interview + restatement gate |
| **Tier 2** | Remote systems, deployment, monitoring setup, multi-host operations, 5–15 tasks. | Domain-specific Decision Records (DRs) + Discovery Summary + restatement gate |
| **Tier 3** | Multi-system migrations, new service standup, multi-phase projects, >15 tasks. | Full grouped DRs + dependency graph + Architecture Summary + restatement gate |

When in doubt, choose the higher tier.

---

### Tier 1: Quick Discovery

Conduct a structured interview across these seven categories. Every category must be addressed or explicitly marked "deferred -- not in scope" before authoring begins:

| # | Category | What to Extract |
|---|----------|-----------------|
| 1 | **Scope boundaries** | What is IN this plan. What is explicitly OUT. What is deferred. |
| 2 | **User/actor definition** | Who uses the output. What are their roles and permissions. |
| 3 | **Data shape** | Inputs, outputs, formats, volumes, sources, transformations. |
| 4 | **Edge cases and failure modes** | What happens when X is missing, wrong, or unavailable. |
| 5 | **Integration points** | What existing systems, services, or files does this touch or depend on. |
| 6 | **Acceptance criteria** | How does the user know the plan succeeded. Concrete pass/fail conditions. |
| 7 | **Unstated constraints** | Deadlines, hardware limits, team conventions, regulatory requirements. |

After the interview, produce the Restatement Gate (see below). No DRs required.

---

### Tier 2: Infrastructure Discovery

**The AI pre-seeds Decision Records (DRs) with domain trade-off context. The user provides the decisions.**

This mirrors how a Red Hat architect interrogates a client before an engagement: the architect writes the Issue (explaining trade-offs and what happens if the wrong choice is made), and the client fills in the Decision. V4 Pro's fabrication tendency makes this especially critical — if the AI is not given structured decision points, it will invent them silently.

#### Decision Record Format (XML — matches V4 Pro task format)

```xml
<decision_record id="DR-N" title="[Short title]">
  <issue>
    [2-5 sentences written by the AI explaining: what this decision controls,
     what the failure mode is if the wrong choice is made, what the options are,
     and why this must be decided before task authoring begins.]
  </issue>
  <decision>[User provides]</decision>
  <assumptions>[User provides any assumptions that condition the decision]</assumptions>
  <dependencies>[DR-N, DR-M or none]</dependencies>
</decision_record>
```

#### How to Generate DRs

The AI reads the user's request and produces DRs for every decision that:
- Is **irrevocable** or **expensive to change** after execution begins
- Involves a **trade-off** the user may not be aware of
- Has **silent failure modes** if the wrong assumption is made
- Creates **dependency ordering** issues for other tasks

Each DR's Issue is written by the AI — the user only provides Decision and Assumptions.

**DR count is variable.** Generate as few or as many DRs as the project requires -- a simple deployment may need 2, a complex migration may need 10. Do not pad to a round number. If you have produced your DRs, stop. A DR that does not meet any of the four criteria above is filler and must be cut.

**Present DRs sequentially, not as a batch.** V4 Pro's tool use patterns are more reliable when decisions are processed one at a time through the conversation.

#### Discovery Summary

After all DRs are resolved, produce a Discovery Summary of 2-3 paragraphs: what the plan will do, what is explicitly out of scope, and how success is measured. This becomes the seed for OBJECTIVE and PROJECT CONTEXT.

```
## Discovery Summary

[What the plan achieves, with DR decisions folded in concretely.]

[Explicit scope boundary: IN scope / NOT in scope / deferred.]

[Success criteria: concrete pass/fail conditions.]
```

The Restatement Gate applies to this summary. Plan authoring is blocked until confirmed.

---

### Tier 3: Major Project Discovery

Tier 3 extends Tier 2 with:

**1. Grouped DRs with explicit dependency graph.** DRs are organized into domain sections. After all DRs are resolved, produce a dependency graph showing which decisions gate which tasks.

**2. Architecture Summary (mini-HLD).** After DRs are resolved, produce a 1-2 page Architecture Summary describing the end-state system, integration points, and data flows. Reviewed and confirmed before task decomposition begins.

```xml
<architecture_summary>
  <end_state>[Deployed system after all tasks complete]</end_state>
  <integration_points>[Every system the plan touches]</integration_points>
  <data_flows>[How data moves between systems, protocols, auth]</data_flows>
  <decision_dependencies>[Which DRs gate which phases]</decision_dependencies>
</architecture_summary>
```

Plan authoring is blocked until both the Architecture Summary and Restatement Gate are confirmed.

---

### The Restatement Gate (All Tiers)

Before writing any task, the AI MUST produce a restatement of the form:

> **What I understand:** [2-3 sentence summary of what the plan will achieve, what it will NOT do, and how success is measured.]
>
> **Does this match your intent?**

If the user corrects the restatement, another round of questions or DR revision follows. **Plan authoring is blocked until the restatement is confirmed.**

### Why This Matters for V4 Pro Specifically

V4 Pro's 94% non-abstention rate (Artificial Analysis Omniscience benchmark) means the model will fabricate confident-sounding answers rather than admitting uncertainty. Without interrogation, it will invent:

- Acceptance criteria that sound reasonable but miss business requirements
- Integration assumptions that conflict with existing systems
- Scope boundaries that include things the user did not want
- Domain rules derived from "common patterns" rather than actual requirements

The tiered discovery protocol is the primary defense: **DRs force V4 Pro to receive domain facts from the user rather than fabricating them.** The restatement gate is the convergence checkpoint that anchors V4 Pro to confirmed scope before the model's 94% non-abstention rate can introduce fabricated scope.

---

## 1. Plan Structure

Every plan MUST have these top-level sections in order:

### OBJECTIVE
One paragraph explaining what the plan achieves and why it matters. State the end-state, not the process. For Tier 2/3 plans, this is derived directly from the Discovery Summary produced in Section 0.

**Tier 2/3 plans MUST also declare a `project_name`** immediately after the objective paragraph:

```
project_name: <snake_case_identifier>
```

This identifier is used to locate the execution directory at `agent_planning/execution/<project_name>/`. It must be stable across sessions — do not change it after the first session has started.

### DECISION RECORDS (Tier 2/3 plans only)

Embed the resolved Decision Records from Section 0 discovery directly in the plan file. This prevents V4 Pro from re-opening decided questions during task execution (which it will otherwise do, given its tendency to re-derive answers from context).

Use XML format consistent with V4 Pro task format:

```xml
<decision_records>

<decision_record id="DR-1" title="[Title]">
  <decision>[What was decided]</decision>
  <rationale>[Key trade-offs from the Issue field — why this choice over alternatives]</rationale>
  <assumptions>[What must be true for this decision to hold]</assumptions>
  <dependencies>none</dependencies>
</decision_record>

<decision_record id="DR-2" title="[Title]">
  ...
  <dependencies>DR-1</dependencies>
</decision_record>

</decision_records>
```

**Rules:**
- Include only DRs that were resolved during Section 0 discovery. Open/deferred DRs must be marked as such and must NOT gate any task.
- Every task shaped by a DR MUST reference it in its `<constraints>` block (e.g., `Per DR-3: use grafana read-only user, not admin`).
- Do NOT re-open DR decisions during task authoring. If a task reveals a decision needs revision, surface it to the user — do not override silently.
- For Tier 1 plans: omit this section entirely.

### PROJECT CONTEXT
- Language and runtime (e.g., Python 3.12, Go 1.26)
- Key libraries and frameworks
- How the pipeline/workflow operates (1-2 sentences)
- Repository root path

### KEY FILES REFERENCE

| File | Purpose |
|------|---------|
| `path/to/file.py` | Brief description of what it does |

This table anchors every task. V4 Pro uses it to locate code without guessing. With a 1M-token context window, inline code snippets for critical functions (up to ~50 lines each) are encouraged here when they prevent the model from misreading a pattern.

### TASKS
Numbered, ordered list of tasks (see Section 2).

### Four-Block Plan Layout

Every plan fed to V4 Pro maps to four blocks. This structure drives context caching and token weighting and MUST be followed in actual plan files.

```
┌─────────────────────────────────────────────────────────────┐
│ SYSTEM BLOCK (stable -- cached across calls)                │
│   Role statement, global constraints, output format rules   │
├─────────────────────────────────────────────────────────────┤
│ REFERENCE BLOCK (mostly stable -- cached)                   │
│   KEY FILES table, schemas, few-shot examples, patterns     │
├─────────────────────────────────────────────────────────────┤
│ TASK BLOCK (per-task -- not cached)                         │
│   Current <task> XML element with all required fields       │
├─────────────────────────────────────────────────────────────┤
│ USER INPUT BLOCK (volatile -- not cached)                   │
│   File contents, error messages, command output             │
└─────────────────────────────────────────────────────────────┘
```

Blocks 1 and 2 must be **bit-identical across calls** to trigger context caching (cutting input cost from $1.74/M to $0.0145/M on V4 Pro list rates). Never interpolate timestamps, request IDs, or per-task values into blocks 1 or 2.

---

## 2. Task Sections

Every task MUST be written as an XML element in actual plan files. V4 Pro parses XML tags reliably; markdown headers are for this reference document only and MUST NOT be used as task section delimiters in plans.

### Canonical Task Format

Every plan task uses this exact template. Omit `<schema>` when not applicable. All other elements are required.

```xml
<task id="N" reasoning="think-high" temperature="0.0">

  <intent>
    WHY this task exists and what problem it solves. One paragraph.
    V4 Pro produces better output when it understands purpose, not just mechanics.
  </intent>

  <structure>
    Define exactly what to create or modify -- no open decisions left to the model:
    - File: path/to/file.go
    - Function: func FunctionName(arg ArgType) (ReturnType, error)
    - Class/struct: TypeName with fields listed
    - Output file or format if applicable
  </structure>

  <schema>
    <!-- Omit this element if the task has no data schema. -->
    <!-- List exact field names, types, and order. Never write "appropriate fields". -->
    FieldName  string    // description
    OtherField int64     // description
  </schema>

  <context>
    Specify data sources with concrete names:
    - Struct/class names and field names from source files
    - File paths where data originates
    - Computation formulas where derivation is needed
    - Pattern to follow: "follow the pattern in path/to/existing.go"

    [TASK RESTATEMENT: one-line restatement of the task goes here when
     the context block above exceeds ~500 tokens. This prevents the
     instruction from being buried at the end of a large input block.]
  </context>

  <constraints>
    - Modify only: path/to/file.go
    - Do NOT modify: path/to/other.go
    - Follow pattern in: path/to/reference.go
    - Max function length: N lines
    - No new packages
    - If field value is unknown, output "unknown" -- do not invent data
  </constraints>

  <naming>
    File: processor.go
    Function: ProcessAudio
    Variable: audioCtx
    Test: TestProcessAudio_HappyPath
  </naming>

  <examples>
    WRONG: if err != nil { log.Fatal(err) }
    RIGHT: if err != nil { return fmt.Errorf("processAudio: %w", err) }

    WRONG: client = APIClient()
    RIGHT: client = APIClient(base_url=cfg.BaseURL, token=cfg.Token, verify=cfg.VerifySSL)
  </examples>

  <dont>
    - Do not create new files or packages unless this task explicitly says to.
    - Do not invent new abstractions beyond what is specified.
    - Do not add features not listed in the `&lt;structure&gt;` element.
    - Do not modify files outside the scope listed in the `&lt;constraints&gt;` element.
    - Do not guess at unknown values -- output the sentinel "unknown" instead.
    <!-- Add a WRONG/RIGHT pair for each critical constraint -->
  </dont>

  <verification>
    Command: go build ./...
    PASS: exit code 0, no output
    FAIL: any compilation error printed to stderr
    BLOCKED: [state condition that would externally prevent verification]
  </verification>

  <output>
    <!-- Output anchor: start the response with the first tokens of the
         expected output. Reduces preamble drift. -->
    Begin your reply with: func ProcessAudio(
  </output>

</task>
```

### Reasoning mode reference

The `reasoning` attribute controls thinking mode. Specify one per task:

| Value | API parameter | When to use | Token overhead |
|-------|--------------|-------------|----------------|
| `non-think` | `extra_body={"thinking": {"type": "disabled"}}` | Formatting, simple edits, deterministic transforms | 1x |
| `think-high` | `reasoning_effort="high"` (default) | Most coding, logic, multi-step reasoning | ~2x |
| `think-max` | `reasoning_effort="max"` | Hard debugging, complex algorithms, architecture decisions | ~4x; requires total request context window >= 384K tokens (input + trace + output) |

Temperature is specified as the `temperature` attribute. Set `0.0` for code and math. Note: **temperature has no effect when thinking mode is enabled** -- tune the prompt text instead.

### Source divergence (plan-authoring time)

When the plan author's approach intentionally differs from a source document's recommendation (investigation report, prior plan, upstream documentation), the divergence MUST be flagged in the task's `<context>` element with the format:

**Divergence from [source]:** [what the source recommended] → [what this plan does instead] — [rationale].

This prevents the executor from reading the source, finding a contradiction with the plan, and either following the source (wrong) or stopping to ask (wasteful).

### No conditional branches

A task MUST NOT contain "if X then do Y, if Z then do W" decision trees. Pre-decide every outcome and state it as a directive in the task XML.

```xml
<!-- WRONG -->
<intent>
  If kvm-api is obsolete, delete it. If it's still used, extract to its own repo.
</intent>

<!-- RIGHT -->
<intent>
  Delete kvm-api/ entirely. It is superseded by kvm-mcp (confirmed with owner on 2026-05-01).
</intent>
```

### Inter-task data dependencies

When a later task depends on data discovered by an earlier task (e.g., Task 1 captures live DNS state, Task 4 uses the list of ghost entries), the plan author MUST NOT defer the values to runtime with placeholders like `<from_task_1>` or hedge with "expected but may differ." Instead:

1. **Enumerate the expected values** from the source material (investigation report, recon output, prior discovery) as concrete literals in the later task's STRUCTURE.
2. **Add a stop rule** to the later task: "If live data from Task N differs from this list, stop and report the discrepancy before proceeding."

This preserves the "no conditional branches" principle (the task has one path with concrete values) while acknowledging that live state may have changed since the source material was collected.

**Bad:**
- `WHERE na.ip IN (<ghost_IPs_from_preflight>)`
- "Add custom.list entries for unresolving hosts (expected set includes but may differ from...)"

**Good:**
- `WHERE na.ip IN ('192.168.99.195', '192.168.99.198', '192.168.99.219', '192.168.99.251', '192.168.99.252')`
- STOP RULE: "If the ghost IP set from Task 1 differs from this list, stop and report before deleting."

---

## 2.5. Mandatory Functional Testing Task

**Every plan that modifies code deployed to an external system (container, server, MCP, service) MUST include a dedicated functional testing task.** This task validates the fix against the real system -- not mock data, not unit tests alone. It must exercise the same code paths that production uses.

### Rules

1. **Separate task.** Functional testing is its own task, numbered after implementation but before deploy. It is NOT a subsection of a build or deploy task.
2. **Real data.** Must test against the live system or production-equivalent data when available. Mock data is acceptable only when live data is inaccessible.
3. **Same code path.** The test must exercise the production entry point (e.g., MCP protocol over stdio, HTTP endpoint, CLI entrypoint) -- not bypass it via direct imports.
4. **Machine-verifiable.** Exit code 0 = pass. Assertions must produce PASS/FAIL output.
5. **No deploy without it.** The deploy task must gate on functional test success.

### Template

```xml
<task id="N" reasoning="think-high" temperature="0.0">
  <intent>
  Functional end-to-end validation against the live system. Build the
  container, run it with production configuration, and assert the fix
  works correctly via the same protocol used in production.
  </intent>

  <structure>
  1. Build the production artifact (Docker image, binary, etc.).
  2. Start the service with production-equivalent configuration.
  3. Exercise the affected endpoint/tool/path using the production protocol.
  4. Assert the expected behavior (concrete pass/fail conditions).
  5. Assert no regressions (false positives, crashes, missing data).
  6. Print PASS/FAIL summary with exit code 0 on success.
  </structure>

  <constraints>
  - Do NOT deploy if this task fails.
  - Test against live/real data unless blocked (e.g., auth unavailable).
  - Produce machine-parseable output.
  </constraints>

  <verification>
  Command: run-the-functional-test
  PASS: all assertions pass, exit code 0
  FAIL: any assertion failure
  BLOCKED: cannot access live system or build artifact
  </verification>
</task>
```

### Examples of functional vs non-functional

| Functional (OK) | Not functional (insufficient) |
|-----------------|-------------------------------|
| Build container, send JSON-RPC to MCP server, assert response | `pytest` with mock API responses |
| Hit the HTTP endpoint, assert status 200 and body shape | Import function, pass mock dict, assert return value |
| `docker run` with real auth, call full pipeline, check output | Unit test with fixture data |
| Invoke the MCP tool via production protocol (stdio/HTTP), verify correct JSON output shape and content | Check tool registration via module introspection (`mcp._tool_manager._tools`) — proves plumbing, not behavior |
| Exercise the production entry point with live credentials, assert side effects (task created, comment added) | Assert the function imports without error — proves syntax, not runtime correctness |

### Exceptions

Functional testing may be skipped only when:
- The plan is purely documentation or config changes with no code.
- The code is a library with no deployable entrypoint (then integration tests suffice).
- Live system access is genuinely blocked (auth, network, credentials) -- in this case, note the BLOCKED reason in the devlog.

---

## 3. Granularity Rules

- Each task MUST have a single, focused goal. One new file, one struct change, one function.
- Tasks MUST be ordered to minimize conflicts -- new additions before modifications.
- Target ~100 lines of new/modified code per task. V4 Pro handles larger scope than smaller-context models, but tasks over 150 LOC increase the risk of silent incompletion.
- If a feature needs types + logic + output, that is 3 tasks minimum.
- Every task that adds struct fields MUST have a paired output-wiring task later.

---

## 4. Single-Layer Scoping

V4 Pro is more capable of spanning multiple pipeline layers within a single task than smaller models, but crossing layers in a single task still increases failure risk. Default to one layer per task. Two closely related layers (e.g., types + collection) may be combined when the total is under 100 LOC and the relationship is inseparable.

Common pipeline layers:
1. **Types/Models** -- data structures, schemas
2. **Collection/Input** -- API calls, file reading, data gathering
3. **Transform/Logic** -- business logic, data processing
4. **Output/Presentation** -- writers, formatters, UI
5. **Tests** -- test assertions and fixtures

Each task operates on at most ONE layer unless explicitly noted as a combined task with justification.

---

## 5. Token and Context Management

V4 Pro has a 1,000,000-token context window with up to 384,000 output tokens. This is far larger than most models, but large context is not free of risk:

- V4 Pro has a 94% non-abstention rate when uncertain (Artificial Analysis): when it does not know an answer, it provides a confident-sounding response 94% of the time rather than admitting uncertainty. More context can anchor the model, but it can also introduce irrelevant signal that the model treats as authoritative.
- Think Max mode requires the total request context window (input tokens + reasoning trace + output) to be at least 384K tokens. This is a server-side `max_model_len` / per-request window setting, not a limit on the plan's own size.
- Reasoning traces count as completion tokens and are billed accordingly (~2x for Think High, ~4x for Think Max).

**Token budget guidance:**
- Keep plan introductions concise. Front-load role and task before any large context block.
- Plans should stay under ~500K total tokens (plan + code read + expected output) to leave room for multi-turn follow-up.
- Break large plans (>12 tasks) into two sequential plans with explicit non-regression constraints.
- For Think Max tasks, size `max_tokens` to at least 8x the expected output length to accommodate the reasoning trace.

**Cache-friendly layout:**
- Put the stable system prompt, schemas, and few-shot examples at the very front of the system message and keep them bit-identical across calls.
- Never interpolate timestamps, request IDs, or per-user names into the stable prefix -- this breaks context caching and costs full input price on every call.

Monitor `prompt_cache_hit_tokens` and `prompt_cache_miss_tokens` in the `usage` response field to validate caching economics. Caching is automatic and best-effort — not guaranteed. Cache is prefix-only from token 0.

**Phased execution:**
- Window 1: Framework setup (scaffolding, config, test harness)
- Window 2: Iterate through implementation tasks

---

## 6. Consistency Rules

- Plans MUST NOT contain contradictory constraints across tasks.
- If a later task overrides an earlier constraint, state the override explicitly.
- Formatting rules (tables vs bullets, prose vs lists) must be consistent across all tasks.
- Mark approximate values as "(approximate -- verify against source)".
- Mark exact values as "(exact -- do not deviate)".
- Unmarked numbers are treated as exact.

---

## 7. Prompting Best Practices for DeepSeek V4 Pro

### The six-part prompt anatomy

Every effective V4 Pro prompt has these six parts. Skip any and quality degrades:

1. **Role** -- who the model acts as ("senior Go engineer", "database administrator with 15 years of Postgres experience")
2. **Task** -- one verb-led instruction. Not three, not five.
3. **Context** -- the code, data, or background needed
4. **Constraints** -- length, banned patterns, must-include items
5. **Output format** -- JSON schema, markdown table, function signature
6. **Examples** -- one or two Wrong/Right pairs for non-obvious formats

**Early tokens are weighted more heavily than later tokens.** Role and task must appear before the context block. This is why `<intent>` and `<structure>` come before `<context>` in the canonical task format (Section 2).

For long context (>500 tokens), add a one-line restatement of the task after the context block inside `<context>` -- the task sandwich. Without this restatement, the instruction is buried and V4 Pro will weight the context content over the directive.

### Use XML tags -- not markdown headers -- in plan tasks

DeepSeek V4 Pro parses XML tags reliably. DeepSeek's official XML is DSML for tool invocations. The plan tags (`<intent>`, `<structure>`, `<constraints>`, etc.) are a well-tested authoring convention that V4 Pro parses reliably, not an official DeepSeek prompt schema. They are the correct way to delimit task sections for this model.

Markdown headers (`### INTENT`) work as human-readable documentation in this reference file, but should not be used as section delimiters in actual plans sent to V4 Pro.

### Temperature

| Use case | Temperature | Notes |
|----------|-------------|-------|
| Code generation, mathematics | `0.0` | Lowest randomness; near-deterministic in non-thinking mode. Not guaranteed identical across calls — JSON mode may return empty content in edge cases. Temperature has no effect in thinking mode. |
| Data analysis, cleaning | `1.0` | DeepSeek's recommended default |
| General conversation, translation | `1.3` | Balanced output |
| Creative writing | `1.5` | More variation; expect reruns |

**Critical:** temperature, `top_p`, `presence_penalty`, and `frequency_penalty` have no effect in thinking mode. Do not set both `temperature` and `top_p` aggressively -- pick one knob.

**Task-level vs agent-level temperature:** The `temperature` attribute on a `<task>` element specifies what the task content requires (e.g., `0.0` for code generation). This is distinct from the temperature used by the orchestrating agent's chat loop. When V4 Pro is executing a plan as a coding agent (as in Cursor), the agent loop itself is a conversational context and should use `1.3`. Setting `0.0` on every task does not propagate to the agent's orchestration calls unless the caller explicitly passes it -- but plan authors should not assume the two are the same setting. Use the `temperature` attribute to document intent for the task; configure the agent's chat temperature separately.

### Reasoning mode selection

- **Non-think:** Use for formatting, classification, translation, and structured extraction where speed matters and the task has no multi-step logic. Pass `extra_body={"thinking": {"type": "disabled"}}`.
- **Think High:** Use for most coding and planning tasks. Default in the V4 API. Pair with `reasoning_effort="high"`.
- **Think Max:** Reserve for hard debugging, complex algorithm design, and formal proofs. Set `reasoning_effort="max"` and ensure the total request context window (input + reasoning trace + output) is >= 384K tokens.

**`reasoning_content` passback rules (official API):**
- **Non-tool-call turns:** `reasoning_content` is ignored if passed — omit it for cost savings.
- **Tool-call sub-turns:** You **must** pass the full assistant message including `reasoning_content` or the API returns 400.

V4 Pro preserves reasoning traces across user-turn boundaries in tool-using conversations (interleaved thinking). This affects context window budgeting for long multi-turn agent workflows.

### Hallucination guardrails

V4 Pro has a 94% non-abstention rate when uncertain (Artificial Analysis) -- when it does not know an answer, it provides a confident-sounding response 94% of the time rather than admitting uncertainty. Plans must compensate:

- Every task's VERIFICATION section must produce machine-checkable output. Subjective "looks fine" gates will be reported as passed.
- When referencing specific values from source code (field names, counts, enum values), instruct V4 Pro to read the source file and use the value it finds -- do NOT hardcode values in the plan without marking them "(exact -- do not deviate)" or "(approximate -- verify against source)".
- When the correct answer for a field may be unknown at runtime, instruct the model to output the literal string `"unknown"` or a sentinel value rather than inventing plausible data.
- Include "if you cannot determine X from the provided context, output `unknown` rather than guessing" in the CONSTRAINTS section of any task that touches uncertain data.

### Negative examples over bare "don't"

V4 Pro responds more reliably to concrete counterexamples than to bare prohibition:

```
WRONG: if err != nil { log.Fatal(err) }
RIGHT: if err != nil { return fmt.Errorf("processAudio: %w", err) }
```

For each DON'T item that matters, provide a Wrong/Right pair.

### Output anchors

End prompts with the first tokens of the expected output to reduce preamble drift:

- "Begin your reply with the line: `## Summary`"
- "Output only the modified function. Start with `func `."
- "Return only valid JSON. Start your response with `{`."

### JSON mode rules

JSON mode (`response_format={"type": "json_object"}`) is designed to return valid JSON, not guaranteed. Three rules prevent silent failures:

1. Include the literal word "json" in the system or user message.
2. Show a small example schema inline -- not just describe it.
3. Set `max_tokens` high enough that the JSON cannot be truncated mid-string.

Always wrap JSON parsing in a retry with try/except. V4 Pro can return empty content when it cannot satisfy the schema.

### Tool calling caveats

V4 Pro emits tool calls correctly only ~79% of the time (GitHub #1244, 19-completion production sample; DeepSeek acknowledged). 11% of calls appear as plain text in `content` instead of the `tool_calls` field. Tool calls are officially supported in thinking mode; the real risk is plain-text leakage into `content`, not thinking-mode incompatibility. Prefer `think-high` over `think-max` for tool-call-heavy workflows for cost/latency reasons, not because chains break.

V4 Pro uses **DSML** (DeepSeek Markup Language) internally for tool invocations. When calling tools via the native format (self-hosted or raw API), tool calls appear as `<｜DSML｜tool_calls>` blocks rather than standard OpenAI function-calling JSON. When using the OpenAI-compatible API surface (`https://api.deepseek.com`), tool calls are translated to/from the standard `tool_calls` field automatically -- but the 11% plain-text leakage means the raw DSML format may occasionally surface in `content`. A parser that checks both `tool_calls` and `content` for DSML-formatted invocations is more robust than one that only checks `tool_calls`.

Plans that require tool use MUST:
- Specify single-tool-call-per-turn in the system prompt
- Instruct the model to never invent tool results
- Include a parser that checks both `tool_calls` and `content` for tool invocations (including DSML format: `<｜DSML｜tool_calls>`)

**Strict tool-call mode:** Use `base_url="https://api.deepseek.com/beta"` with `"strict": true` on tool function definitions to enforce schema adherence. Especially useful given the ~11% plain-text leakage issue.

---

## 7.5. API Model Selection

- **Model ID:** `deepseek-v4-pro`
- **Legacy models:** `deepseek-chat` and `deepseek-reasoner` are deprecated, sunset **2026-07-24 15:59 UTC**
- **Default thinking mode:** Enabled with `reasoning_effort="high"`. Explicit `extra_body={"thinking": {"type": "disabled"}}` is required for `non-think` tasks.
- **Agent client overrides:** Some agent clients (e.g., Cursor, OpenCode) may auto-set `reasoning_effort="max"`. Plan authors should be aware of this when specifying per-task `reasoning` attributes.

---

## 8. Plan File Conventions

- Plans are stored as markdown files in `./zed_plans/` (relative to the repository root).
- File naming: `{descriptive_name}_{YYYY-MM-DD}.md` (e.g., `ente_alerts_cleanup_2026-06-04.md`). Always append the date in YYYY-MM-DD format to the file name.
- Each plan file is self-contained -- it includes all context needed for execution.
- Plans reference templates and existing code by path so V4 Pro can read them.
- Plans that create a new moltis skill MUST include a task to update `moltis/SKILLS_CATALOG.md` with the new skill's name and one-line description.

### Plan File Format: Markdown Wrapper, XML Task Content

A plan file is a markdown document. These two things are true simultaneously and do not conflict:

- **Top-level sections** (OBJECTIVE, PROJECT CONTEXT, KEY FILES, TASKS) use markdown headers (`##`, `###`) for human readability and navigation.
- **Individual task definitions** inside the TASKS section use XML `<task>` elements for V4 Pro to parse.

The rule in Section 2 ("markdown headers MUST NOT be used as task section delimiters") applies to the content *within* each task -- the intent, structure, context, etc. are XML elements, not markdown headers. The plan's top-level outline remains markdown.

A plan file skeleton looks like this:

```markdown
## OBJECTIVE
...

## PROJECT CONTEXT
...

## KEY FILES REFERENCE
| File | Purpose |
...

## TASKS

<task id="1" reasoning="think-high" temperature="0.0">
  <intent>...</intent>
  <structure>...</structure>
  ...
</task>

<task id="2" reasoning="non-think" temperature="0.0">
  ...
</task>
```

---

## 8.5. Stop Rules

Stop rules tell V4 Pro when to stop. Without them, the model will continue generating confident output indefinitely -- its 94% non-abstention rate means it will never self-terminate on uncertainty alone.

Stop rules belong in two places:
- **Plan-level:** As a `<stop_rules>` block in the SYSTEM BLOCK, applied globally to the whole execution
- **Task-level:** As a `<stop_rules>` child element inside individual `<task>` elements for task-specific limits

### For Plan Authoring (used by the plan author, not V4 Pro)

Stop writing tasks when the OBJECTIVE is fully covered end-to-end. Do not add tasks because they are "nice to have," "related," or "probably expected." The interrogation restatement is the scope boundary -- anything outside it requires user approval before it enters the plan.

### Paste-Ready Templates

Embed these in the SYSTEM BLOCK or inside `<task>` elements as needed:

**For research tasks:**
```xml
<stop_rules>
  <rule>Stop after 5 sources unless the topic is genuinely contested.</rule>
  <rule>Stop when 2 credible sources agree. Do not seek disconfirmation as a default.</rule>
  <rule>Stop if the answer is in the files already provided.</rule>
</stop_rules>
```

**For coding tasks:**
```xml
<stop_rules>
  <rule>Stop after fixing the requested issue. Do not refactor unrelated code.</rule>
  <rule>Stop after running tests once. Do not re-run unless they failed.</rule>
  <rule>Do not read files outside the task scope defined in &lt;constraints&gt;.</rule>
  <rule>Stop after 3 files reviewed in a code review task unless explicitly asked for more.</rule>
</stop_rules>
```

**For document review tasks:**
```xml
<stop_rules>
  <rule>Stop after identifying the issues listed in the checklist. Do not scan beyond listed items.</rule>
  <rule>One finding per checklist row, plus the file path and line number.</rule>
  <rule>Do not suggest rewrites unless explicitly asked.</rule>
</stop_rules>
```

**For classification/support tasks:**
```xml
<stop_rules>
  <rule>Stop after one clarifying question maximum. Then make your best classification and proceed.</rule>
  <rule>Do not escalate unless the escalation rule explicitly applies.</rule>
  <rule>Stop after the response is drafted. Do not preview alternatives.</rule>
</stop_rules>
```

**For multi-step agent workflows:**
```xml
<stop_rules>
  <rule>Stop after 20 turns total in this task. If incomplete, surface what remains.</rule>
  <rule>Stop if the same tool is called 3 times with no progress.</rule>
  <rule>Stop if you are reading files outside the original scope defined in &lt;constraints&gt;.</rule>
</stop_rules>
```

### V4 Pro-Specific Note

Without stop rules, V4 Pro will over-work: extra tool calls, additional "related" refactors, broader validation sweeps than requested. It does this not because it is malfunctioning but because nobody told it when done is done. The 94% non-abstention rate means it will always find something more to check rather than stopping and reporting completion.

Stop rules are the boundary. They are not restrictions -- they are precision.

---

## 8.6. Document-Order Principle

**Note:** Section 7 states that role and task should appear before context (early-token weighting). This section states that the task instruction should be at the bottom. These are complementary: at the macro level (four-block layout), stable context precedes the task. At the micro level (within `<context>`), large data comes first with a one-line task restatement at the end.

**Long context on top. The task instruction at the bottom.**

When the `<context>` block of a task exceeds ~500 tokens, the model reads the context, then arrives at the end of the block with the instruction's specifics faded from working memory. The task sandwich (already documented in Section 7) is the fix: restate the task directive as the last line of `<context>` after any large code or data block.

```xml
<context>
  [... large code block, schema, or data -- hundreds of tokens ...]

  [TASK RESTATEMENT: implement the ProcessAudio function as defined in &lt;structure&gt; above.]
</context>
```

This applies to the four-block plan layout as well: the SYSTEM and REFERENCE blocks precede the TASK block. The question (the task) is always at the bottom of the input, not the top. This is consistent with Anthropic's documented finding of up to 30% quality improvement on long-context inputs when question placement follows this order.

---

## 9. Devlog Pairing (MANDATORY)

Every plan execution MUST produce a devlog entry. This is not optional -- the devlog is the authoritative **audit trail and evidence record**. For fast session recovery (new thread, context cleared, agent restart), the primary context sources are `agent_planning/execution/<project_name>/SESSION_BRIEF.md` and `HANDOFF.md`, per `agent_planning/EXECUTION_PROTOCOL.md`. The devlog provides detailed evidence when the brief is insufficient.

Plans executed without a devlog are incomplete.

### Devlog Lifecycle

1. **CREATE the devlog as the FIRST action** of plan execution, before any task work begins. Populate the title, date, and Objective section immediately.
2. **UPDATE the devlog after EACH task is completed.** Append the task's execution details, discoveries, files changed, and verification results. Do not batch updates -- write them while details are fresh.
3. **FINALIZE the devlog after all tasks are complete.** Add the Conclusion/Next Steps section and verify all sections are populated.

### Standard Devlog Format

Every devlog MUST use this exact structure. Sections marked `(if applicable)` are omitted when the plan had no discoveries, issues, or investigation.

```
# Devlog: {Descriptive Title} — {YYYY-MM-DD}

## Objective / Problem
One paragraph stating what was done and why. State the end-state, not the process.

## Discoveries (if applicable)
- Findings during execution that were not known at plan-authoring time
- API behaviors, system constraints, tool quirks discovered
- Cite specific evidence: log lines, command output, file contents

## Execution Log
Per-task breakdown. Each completed task gets its own subsection:

### ✅ Task N: {Task Name} — COMPLETE
- **What was done:** Concrete actions taken
- **Files modified/created:** Paths and nature of changes
- **Verification:** Command output or checks confirming success
- **Deviations from plan (if any):** What differed and why

## Issues Encountered (if applicable)
- Each issue as a sub-heading with: symptom, root cause, resolution
- Cite specific error messages, timestamps, or log lines

## Files Modified / Created
| File | Purpose / Change |
|------|------------------|
| `path/to/file` | What was changed or why it was created |

## Result / Conclusion / Next Steps
- Final outcome
- Any unverified or deferred items
- Concrete next actions

---

*Execution completed — {YYYY-MM-DD} ~{HH:MM} {timezone}*
```

### Devlog Location and Naming Convention

All devlogs MUST be written to the project's execution devlogs directory: `agent_planning/execution/<project_name>/devlogs/` (where `project_name` is declared in the plan's OBJECTIVE section).

```
agent_planning/execution/<project_name>/devlogs/devlog_YYYYMMDD_{descriptive_name}.md
```

Examples:
- `agent_planning/execution/fish_tts/devlogs/devlog_20260504_fishtts_docker_deploy.md`
- `agent_planning/execution/vikunja/devlogs/devlog_20260501_vikunja_mcp.md`
- `agent_planning/execution/general/devlogs/devlog_20260427_unified_format_design.md`

### Investigation/Diagnostic Devlog Requirements

When the plan is investigative (reproduce bug, analyze logs, identify root cause), the devlog has additional requirements beyond the standard format:

1. **Required criteria checklist:** If the plan specifies items the devlog must address, list them as a checklist at the top of the Execution Log and answer each one explicitly. Never omit a required criterion.
2. **Evidence-linked conclusions:** Every conclusion or "ruled out" claim must cite specific log lines, command output, or timestamps. Do not state "X was confirmed" without showing the evidence inline.
3. **No forced classification:** If evidence is insufficient, state "Inconclusive" rather than guessing. V4 Pro's 94% non-abstention rate when uncertain makes forced classification a significant risk -- rather than saying "I don't know," it will produce a confident-sounding but invented root cause if not constrained.
4. **Sanity-check gate:** The devlog must state whether the test results matched the expected failure pattern. If they did not match, the devlog must not proceed to root cause classification.
5. **No stream-of-consciousness:** Devlogs must be professional analysis. No self-contradictions. Present conclusions supported by evidence.

---


## 9.5. Reconstruction Completeness (MANDATORY)

Every plan that deploys artifacts to external systems (servers, containers, cloud) MUST leave behind enough repo-side material for a complete rebuild without access to the deployed system. The litmus test: **if the server is destroyed, can an agent with only the repo reconstruct every deployed artifact?**

#### Required Artifacts

| Artifact | Requirement |
|----------|-------------|
| Plan file | Full task descriptions with STRUCTURE showing exact config/script content |
| Devlog | Per-task records with verification output, deviations, and discoveries |
| Notes file | Monitoring/architectural documentation section with redeployment steps |
| Scripts | Every script deployed to a server MUST have a copy saved in the repo |

#### Script Preservation Rule

Any script or config file that is created on or copied to a remote server during plan execution MUST also be saved in the repository. The agent executing the plan must either:

1. **Write the script to the repo first**, then `scp` it to the server, OR
2. **Pull the script back from the server** after deployment: `scp user@host:/path/to/script.sh ./repo/path/`

Scripts saved only in `/tmp` on the agent's local machine or solely on the remote server are NOT sufficient — they will be lost when the agent session ends or the server fails.

#### Devlog Completeness for Reconstruction

The devlog must include enough detail to recreate any file that was modified. This means:

- **For small files** (<100 lines): Include the full file content in the devlog verification output
- **For larger files**: Reference the repo path where the copy is saved
- **For config patches**: Show the exact `sed` commands or diff hunks applied, not just "added X to Y"
- **For generated values** (tokens, keys): Document the generation command so it can be re-run; never hardcode ephemeral values

#### Plan-to-Notes Traceability

When a plan creates monitoring, backup, or operational infrastructure, the project notes file (e.g., `notes.md`) MUST be updated with a dedicated section documenting:

- Architecture diagram or description
- All new ports, endpoints, credentials (or references to where they're stored)
- Alert rules and their triggers
- Redeployment steps as a copy-paste bash block
- References to all new files (both server paths and repo copies)

The combination of **plan + devlog + notes + repo scripts** must be sufficient to reconstruct the entire solution from scratch.

#### Home Lab Documentation Update (MANDATORY for infrastructure changes)

When a plan deploys a new service, modifies network configuration, adds/removes VMs, changes ports, or alters DNS records on the home lab infrastructure, the plan MUST include a task (or sub-step of the final task) that updates the relevant documentation in `~/git_projects/home-lab/`. This is the canonical source of truth for the lab's state.

**Files to update based on change type:**

| Change | File(s) to update |
|--------|-------------------|
| New service deployed | `SERVICE-MAPPING.md` (add to appropriate section: Docker services, VM table, port reference, service URLs) |
| New VM created | `SERVICE-MAPPING.md` (VM table + host section) |
| Port changes | `SERVICE-MAPPING.md` (port reference tables) |
| Network/VLAN changes | `SERVICE-MAPPING.md` (network overview, VLAN table) |
| New hardware | `HARDWARE.md` |
| Storage changes | `STORAGE.md` |
| New automation | `AUTOMATIONS.md` |

**Rules:**
- The update must reflect the ACTUAL deployed state (verified post-deployment), not the planned state
- Include: service name, IP/port, URL (if applicable), purpose, and any dependencies
- For Docker services: add to the correct host section with CNAME, internal port, HTTPS URL, and purpose columns
- For services accessible via reverse proxy: document the CNAME/vhost entry
- Commit the documentation update in the same session as the deployment (do not defer to a follow-up)
- If the plan is executed across multiple sessions, the documentation update belongs in the FINAL task's verification steps

**Litmus test:** After plan execution, could someone reading `SERVICE-MAPPING.md` discover and access the new service without consulting the devlog or plan file?

#### Knowledge Base Update (MANDATORY for any KB-covered system)

The synthesized knowledge base at `~/git_projects/scratch_pad/knowledge/` is the authoritative reference that every agent reads FIRST when asked about any home-lab file, service, VM, container, host, or network device (see `knowledge/INDEX.md`). `SERVICE-MAPPING.md` is the raw source of truth; the KB is the derived, agent-consumable layer. Both must stay current.

When a plan task — whether deployment, configuration, diagnostic, or maintenance — changes the state of any system, service, VM, container, host, network device, storage pool, automation, or pipeline that has a corresponding doc under `~/git_projects/scratch_pad/knowledge/`, the plan MUST include a task (or sub-step of the final task) that updates the relevant KB doc(s) and records the verified state in that doc's `verification-notes` or the relevant devlog.

This rule is BROADER than the home-lab rule above: it fires on any agent action that touches a KB-covered topic, not only on new deployments. Examples of triggering actions:

- Deploying, reconfiguring, or removing a service, VM, container, host, DNS record, port, VLAN, storage pool, NFS/SMB share, automation flow, ESPHome device, or pipeline component.
- Discovering that an existing KB doc is wrong, stale, or missing (e.g., wrong IP, wrong port count, false alert-file claim, reconciled inconsistency).
- Adding a new MCP server, skill, pipeline, or integration that the KB should document.
- Changing alert rules, contact points, dashboards, retention policies, or other monitored-state items referenced in `infrastructure/monitoring.md` or any service doc.

**Discovery step (mandatory first action of any KB-update task):**

```bash
# Map the change to the right KB doc(s)
rg -l '<topic-keyword>' ~/git_projects/scratch_pad/knowledge/
rg -l 'topic: <category>'  ~/git_projects/scratch_pad/knowledge/
rg '^summary:'              ~/git_projects/scratch_pad/knowledge/
```

Cross-reference the change against `knowledge/INDEX.md` to confirm the affected doc. If no doc exists yet for the topic, create one following `knowledge/.frontmatter-template.md` (or note in the devlog that a new doc is needed and add it to the relevant `related:` field on `INDEX.md`).

**Files to update based on change type:**

| Change | File(s) to update |
|--------|-------------------|
| Service / VM / container / host state change | The matching `knowledge/<category>/<doc>.md` (services/, infrastructure/, media/, home-automation/) |
| Network / VLAN / DNS / IP change | `knowledge/infrastructure/networking.md` + affected service doc(s) |
| Monitoring / alert rule / contact point change | `knowledge/infrastructure/monitoring.md` + affected service doc(s) |
| Storage / ZFS / NFS / SMB / replication change | `knowledge/infrastructure/storage.md` |
| New / removed / changed MCP server, skill, or pipeline | `knowledge/agent-guide/tool-inventory.md` + relevant service doc |
| New / removed / changed automation, flow, or ESPHome device | `knowledge/home-automation/node-red-flows.md` or `esphome-devices.md` or `overview.md` |
| New / changed entry-point or cross-reference doc | `knowledge/INDEX.md` and the `related:` field on any affected doc |
| Drift / staleness discovery on an existing doc | The affected doc + relevant devlog or plan follow-up |
| Any verified or partially-verified state above | The affected doc's `confidence`/`verification-notes` fields |

**Update rules:**

- The update must reflect the ACTUAL current state (verified post-deployment), not the planned state. Cite the verification command and its output in the doc or the devlog.
- Preserve the existing frontmatter shape (`topic:`, `tags:`, `sources:`, `related:`, `updated:`, `summary:`, `confidence:`). Bump the `updated:` date to today.
- If the change was verified against a live host or authoritative source, advance the doc's `confidence:` field from `synthesized-from-sources` to `verified` or `partially-verified` (with a note in the verification-notes block).
- Every KB update MUST record the date, verified state, and verification command in the affected KB doc's `verification-notes` or the relevant devlog.
- If the change creates a new cross-reference (e.g., a new doc, a new related link), update `related:` frontmatter on both the new doc and any doc that should point to it.
- Commit the KB update in the same session as the change (do not defer to a follow-up).
- If the plan is executed across multiple sessions, the KB update belongs in the FINAL task's verification steps — not in a hypothetical "later cleanup" task.

**Litmus test:** After plan execution, could an agent reading only the KB doc (without consulting the devlog or plan file) correctly answer questions about the current state of the system? If not, the KB was not updated.

**Anti-pattern:** Editing the KB only in the devlog or only via an in-conversation summary. The KB doc itself must change — `updated:` must be bumped, `confidence:` must advance if verified, and the verification must be recorded in the affected doc's `verification-notes` or the relevant devlog. A devlog mention is insufficient because the KB is the layer agents consult before the devlog.

## 10. Review and Validation Task Pattern

V4 Pro will report "all looks fine" on open-ended review tasks without verifying individual items. Its 94% non-abstention rate when uncertain amplifies this risk: rather than admitting it has not checked, it will generate plausible-sounding verification output. Review tasks require a different plan structure than implementation tasks.

### Use concrete checklists, not open-ended scans

Never instruct V4 Pro to "check all removed lines" or "verify every CLI flag." Instead, pre-enumerate every specific item to verify in a checklist table:

**Bad:**
```
For every line prefixed with `-`, check whether that content appears in a `+` line or supplemental doc.
```

**Good:**
```
| # | Item | Search term | Expected location |
|---|------|-------------|-------------------|
| 1 | GARMIN_USER env var | `GARMIN_USER` | README.md |
| 2 | --dry-run CLI flag | `--dry-run` | README.md |
| 3 | InfluxDB 1.x requirement | `InfluxDB` | README.md |
```

The checklist must include every env var, CLI flag, config option, command example, warning, and feature description that could be lost. Extract this list from the original file before writing the review plan.

### Require structured output with evidence

Every review task MUST specify a required output format that forces V4 Pro to show its work. Without this, V4 Pro claims "all clean" without evidence -- and does so confidently.

```
REQUIRED OUTPUT -- produce this exact table:
| # | Item | Status | Found in |
|---|------|--------|----------|
| 1 | GARMIN_USER | FOUND/LOST | README.md |
| 2 | --dry-run | FOUND/LOST | -- |
```

V4 Pro must fill in every row. An output table that is absent or incomplete is an invalid review result.

### Scope limits for review tasks

- Max 3 repos per review plan. High-risk repos (>200 removed lines) get their own plan or share with at most 1 other.
- Max ~30 checklist items per task. Longer checklists should be split across multiple tasks.
- Process repos in risk order (highest first) so the highest-risk repo gets the freshest context.

### Provide expected-location hints

Each checklist item should include where the content is expected to be found. This anchors V4 Pro's search and prevents lazy "not found" classifications:

```
| 9 | ALLOWED_DISK_PATHS env var | `ALLOWED_DISK_PATHS` | QUICKSTART.md |
```

### Use search commands, not diff parsing

Instead of asking V4 Pro to parse `git diff` output (which can be hundreds of lines), instruct it to search for each item directly:

```bash
rg "SEARCH_TERM" README.md QUICKSTART.md ARCHITECTURE.md CODEFLOW.md AGENTS.md
```

### Pre-extraction pattern for rewrite plans

Before any plan that rewrites a large file (>100 lines), create a content inventory. The rewrite plan should include a task that extracts all significant items (env vars, CLI flags, config options, warnings, feature descriptions) into a checklist. The review plan then references this checklist.

If the inventory was not created before the rewrite, the review plan author must extract it from `git diff HEAD` output and embed it directly in the review plan as a checklist table.

### DeepSeek-specific advantage: 1M context for whole-repo review

V4 Pro's 1M-token context window means a review task can ingest an entire small-to-medium repository in a single pass without chunking. For repos under ~800K tokens of source, include all relevant files in the USER INPUT block of a single `<task>` rather than splitting across multiple tasks. This eliminates the inter-task continuity risk present in smaller-context models while still requiring the concrete checklist and structured output table described above.

---

## 11. Sequential Plan Integrity (Multi-Phase Tasks)

When a project spans multiple sequential plans (e.g., scaffold → move → fix imports → verify), extra constraints apply to prevent later phases from silently undoing earlier work or leaving incomplete state.

### Cleanup tasks need explicit file inventories

Never say "remove directory X" or "directory should be empty after." Instead, enumerate what must be deleted or moved. If the exact file list is unknown at plan-authoring time, make the first step of the task an inventory command:

**Bad:**
```
After move, `language/` is empty or removed.
```

**Good:**
```
STEP 1: Run `git ls-files language/ | wc -l` -- record count.
STEP 2: For each tracked file under `language/`:
  - If it was moved to `src/`: verify rename in `git status`, then `git rm` the old path if still tracked.
  - If it is data (images, fixtures): `git mv` to `data/` root.
  - If it is build artifact (venv, __pycache__): `git rm --cached` and confirm .gitignore coverage.
STEP 3: Run `git ls-files language/ | wc -l` -- must be 0.
```

### Non-regression constraints across phases

When a later phase touches files that an earlier phase cleaned up, explicitly state what the earlier phase achieved and that it MUST NOT be reverted:

```
CONSTRAINT: Phase 5c removed all `sys.path.insert` calls from this repo.
This phase MUST NOT reintroduce `sys.path` hacks. If a module needs the
package root for path resolution, import from `paths.py` -- do NOT use
`sys.path.insert`.
```

### Verification tasks need machine-checkable pass/fail criteria

Replace subjective criteria ("actually start the app briefly") with concrete commands:

**Bad:**
```
Confirm UI binds and no crash on import.
```

**Good:**
```
VERIFICATION COMMAND:
  timeout 10 python -m ai_assisted_language_quizzer 2>&1 | head -5
PASS: output contains "Running on" (Gradio bind message)
FAIL: output contains "ImportError", "ModuleNotFoundError", or exit code != 0 within 10s
BLOCKED: if dependency install fails, log the exact error and mark BLOCKED (not PASS).
```

When a verification step might be blocked by an external constraint (missing system lib, network), provide the BLOCKED status explicitly so V4 Pro cannot classify it as PASS.

### Discovery-based scope for update tasks

When a task says "update all X references," V4 Pro will only check files it has explicitly been told to check. If the real scope is "all files containing pattern Y," instruct V4 Pro to discover the scope first:

**Bad:**
```
Update README.md, AGENTS.md, ARCHITECTURE.md, CODEFLOW.md to remove `language/` references.
```

**Good:**
```
STEP 1: Run `rg -l 'language/' .` to discover ALL files with stale references.
STEP 2: For each file found, replace `language/` paths with the new canonical paths.
STEP 3: Re-run `rg -l 'language/'` -- must return 0 results (or only explicitly-excluded files like changelogs).
```

### Verification command fidelity

V4 Pro must execute the EXACT verification commands specified in the plan. Do not substitute `grep` for `rg`, and do not use shell globs (`*.md`) where recursive ripgrep was specified (`--glob '*.md'`).

**Bad (silently changes scope):**
```
PLAN SAYS: rg -l 'pattern' . --glob '*.md'
EXECUTED:  grep -rn 'pattern' *.md   <- shell glob, top-level only
```

**Good:**
```
rg -l 'pattern' . --glob '*.md'   <- recursive, matches the plan exactly
```

If the specified command is unavailable or fails, report the failure explicitly rather than substituting an alternative with different scope.

### Explicit git baselines

When a review plan uses `git diff` to detect changes, it MUST specify the exact baseline reference -- not `HEAD`. In a multi-plan execution sequence, `HEAD` moves after each commit. Use one of:
- A tagged commit: `git diff phase5-complete..HEAD -- file`
- A branch point: `git diff main..HEAD -- file`
- A relative ref with explanation: `git diff HEAD~3 -- file` (where 3 = number of phase commits preceding this review)

If the baseline is unknown at authoring time, make the FIRST step of the review task record it:
```bash
git log --oneline -1 -- <file>
```
Run this before any modifying plans execute so the SHA is captured.

---

## 12. Diagnostic and Investigation Plans

When a plan's purpose is to reproduce a bug, collect diagnostic data, and identify root cause (rather than implement a feature), additional rules apply.

### Test Fidelity: Match Production Behavior Exactly

Diagnostic tests MUST replicate how the system operates in production. Approximations that differ from production behavior produce invalid data.

**stdio/pipe transports:** `cat input | process` closes stdin immediately after the last message. This is NOT equivalent to a client that keeps the pipe open across multiple requests. For MCP servers, gRPC services, or any protocol where the client maintains a persistent connection, use a method that keeps the connection open:

- Python `asyncio` script that sends messages and awaits responses
- Explicit sleep to prevent premature EOF: `{ cat input.txt; sleep 30; } | docker exec -i ...`
- A purpose-built test harness that manages the connection lifecycle

**API clients:** Diagnostic test scripts MUST use the same initialization path as production code. Before writing a diagnostic test script, verify it exercises the EXACT same code path that triggers the bug in production.

**Bad:**
```python
client = VikunjaClient()  # defaults to verify=True -- different from production
```

**Good:**
```python
config = Config.from_env()
client = VikunjaClient(base_url=config.base_url, token=config.api_token, verify=config.verify_ssl)
```

### Complex Shell Commands as Script Files

When a plan task includes commands with 2+ levels of quoting, provide the command as a standalone script file rather than inline shell.

**Bad (fragile across shell implementations):**
```bash
ssh host 'cat > /tmp/file << '"'"'EOF'"'"'
{"jsonrpc":"2.0",...,"project":"Steve'"'"'s TO-DOs"}
EOF'
```

**Good:**
```
STRUCTURE:
  1. Create tests/reproduce_crash.json with the JSON-RPC messages (no quoting issues)
  2. Copy to remote: scp tests/reproduce_crash.json arch-openclaw:/tmp/
  3. Execute: ssh arch-openclaw "{ cat /tmp/reproduce_crash.json; sleep 30; } | docker exec -i vikunja-mcp ..."
```

### Sanity-Check Test Results Before Analysis

After collecting diagnostic data, compare results against KNOWN BEHAVIOR before proceeding to root cause analysis. If the test output does not match the expected failure pattern, the test is invalid.

| Expected (from plan) | Actual (from test) | Action |
|----------------------|-------------------|--------|
| 2 calls succeed, 3rd crashes | 0 calls complete (no HTTP responses at all) | **INVALID.** Test methodology did not reproduce the production failure. Redesign the test. Do NOT classify a root cause. |
| 2 calls succeed, 3rd crashes | 2 calls succeed, 3rd returns error | Valid -- proceed to analysis |
| 2 calls succeed, 3rd crashes | All 3 calls succeed | Valid -- bug may be environment-specific. Note this. |

If test results are anomalous, the analysis task MUST report the anomaly rather than forcing a root cause classification. V4 Pro's 94% non-abstention rate when uncertain makes this a high risk -- rather than saying "I don't know," it will produce a confident-sounding invented root cause if not explicitly constrained to report "Inconclusive."

### Handling Inconclusive Results

"Inconclusive -- test methodology invalid" is a valid devlog conclusion. Do NOT force a classification when evidence is insufficient.

When a diagnostic test fails to reproduce the bug, the devlog MUST:
1. State that the test was inconclusive
2. Explain why the test methodology differed from production behavior
3. Recommend a specific test redesign
4. Report any partial findings that ARE valid (e.g., "the `project` parameter was correctly populated on all 3 calls -- Hypothesis A is ruled out regardless of test methodology")

### DeepSeek-specific advantage: Think High reasoning trace as evidence

When a diagnostic task uses `reasoning="think-high"`, V4 Pro returns `reasoning_content` alongside its final answer. For investigation plans, instruct V4 Pro to append the reasoning trace (or a summary of it) to the devlog as a **Reasoning Trace** subsection. This provides auditable evidence of the model's analytical path -- useful for diagnosing why a conclusion was reached and for spotting where the model inferred rather than observed.

```
VERIFICATION (diagnostic tasks):
  Append to devlog: the reasoning_content trace (or a 200-token summary) under
  "## Reasoning Trace" to make the analysis auditable.
```

### Devlog Quality for Investigation Plans

Investigation devlogs MUST be professional analysis:

- No stream-of-consciousness ("Wait -- actually...", "Let me trace through...")
- No self-contradictions
- Every "ruled out" hypothesis MUST have explicit supporting evidence stated immediately before the claim
- If the plan specifies required devlog criteria, each criterion MUST be explicitly addressed -- even if the answer is "cannot be determined from available data"
- Present conclusions supported by evidence, not the journey to reach them

### Artifact Cleanup

Every plan that creates temporary files or test data in external systems MUST include an explicit cleanup step:

```
CLEANUP:
  1. Delete test records from Vikunja API
  2. Remove temp files: rm test_vikunja.py test_http.py
  3. Verify: ls test_*.py 2>&1 | grep -q "No such file" && echo PASS
```

---

## 13. Operational Robustness

Rules for plan tasks that involve runtime environments (containers, remote hosts, file transfers).

### A. Container Filesystem vs Host Filesystem

Scripts created on the host are NOT automatically available inside a container. Any task that creates a file to be executed inside a container MUST include an explicit copy step:

```
1. Write /tmp/test_script.py on host
2. docker cp /tmp/test_script.py container_name:/tmp/test_script.py
3. docker exec container_name python3 /tmp/test_script.py
```

### B. File Modification Resilience

When a plan modifies source files, specify the exact content or diff for each modification. For critical modifications:

- Provide the FULL intended file content if the file is small (<50 lines)
- Provide a precise diff with 5+ lines of surrounding context if the file is large
- Include a verification step that checks syntax validity after modification (e.g., `python -c "import ast; ast.parse(open('file.py').read())"`)

### C. Recovery from Tool-Induced Corruption

Plans that modify source code MUST include a recovery path. If a modification produces invalid output (syntax errors, merged content, markdown injection):

1. Do NOT attempt to fix corruption with more edits to the corrupted file
2. Restore from version control: `git checkout -- <file>`
3. Re-attempt with a different strategy (e.g., write the full file instead of patching)

Include this as a DON'T in the task:

```
DON'T:
- Do not apply successive edit_file patches to fix corruption from a prior failed edit. Restore and retry from clean state.
```

### D. SSH/Remote Execution Reliability

For tasks that execute commands on remote hosts:

- Always verify SSH connectivity as the first step: `ssh -o ConnectTimeout=5 host true`
- Use explicit paths, never rely on shell aliases or `.bashrc` being sourced
- For multi-command sequences, use a single `ssh host 'cmd1 && cmd2 && cmd3'` rather than multiple SSH connections
- Capture both stdout and stderr: `ssh host 'command' 2>&1`

### E. Docker Build/Push Verification

After any `docker build` or `docker push` task, include machine-verifiable success checks:

```
VERIFICATION:
  1. docker images | grep "image_name" | grep "tag" (confirms local image exists)
  2. docker manifest inspect registry/image:tag (confirms push succeeded)
```

Do NOT rely on "command exited successfully" as the only verification -- network issues can produce partial pushes with exit code 0.

### F. Container Overlay Filesystem Limitations

When a plan modifies files inside a running container (e.g., Prometheus rules, blackbox config), the container overlay filesystem blocks writes to in-use files. Common operations that FAIL: docker cp, sed -i, cat > file.

**The only reliable method:** 1. docker stop container, 2. Write via host MergedDir path (docker inspect for GraphDriver.Data.MergedDir), 3. docker start container. Do NOT specify docker cp, sed -i, or SIGHUP-based reload for container overlay files.

### G. Configuration Reload Behavior (Prometheus, blackbox_exporter)

| Tool | SIGHUP reloads | SIGHUP does NOT reload |
|------|---------------|------------------------|
| Prometheus | Rule files, scrape intervals | __address__ relabel changes, job_name changes, new/removed scrape jobs |
| blackbox_exporter | Module definitions | Module removal (old modules persist), port changes |

When in doubt, docker restart. __address__ relabel changes require restart, not SIGHUP.

### H. Multi-Module Probe Behavior (blackbox_exporter)

When Prometheus scrape job specifies multiple modules, the FIRST module's value masks the second's for shared metric names. This is a silent masking bug. Each scrape job MUST use exactly ONE module.

### I. Pre-Deployment Access Verification (MANDATORY)

The #1 cause of deployment failures in monitoring plans is deploying an exporter for a target that is unreachable. Before any exporter/scraper deployment, STEP 1 MUST be an access gate: ping target, test port/service, test credentials. If ANY check fails: mark BLOCKED, record evidence, do NOT deploy. Distinguish reachability failure (ping fails, no ARP) from credentials failure (ping succeeds, auth error).

### J. Grafana 3-Stage Alert Rule Pattern (CRITICAL)

Two common failure modes in Grafana alert rule expressions:

1. **B step MUST be type: reduce with reducer: last.** Using type: threshold with empty params causes DatasourceError and broken template rendering.

2. **Threshold placement and $value rendering:** Put PromQL WITHOUT comparison in A step, threshold in C step evaluator.params. If A includes comparison (e.g., rate(x[5m]) > 10), $value shows 0/1 instead of the actual rate. Exception: binary metrics (up == 0, ifOperStatus == 2) can keep comparison in A.

3. **Template escaping:** Literal curly braces in annotation descriptions (e.g., Docker --format templates) MUST use Go template escaping. Unescaped braces break entire template expansion.

4. **Receiver names in Grafana 13:** notification_settings.receiver uses the contact point NAME (e.g., "Telegram HostDown"), NOT the UID. Using UIDs returns HTTP 400.

---

## 14. Quick Reference Checklist

Before submitting a plan for V4 Pro execution, verify:

**Pre-Plan Interrogation (Section 0)**
- [ ] All 7 interview question categories addressed or explicitly deferred (scope, users, data, edge cases, integrations, acceptance criteria, unstated constraints)
- [ ] Restatement confirmed by user before plan authoring began
- [ ] No tasks added beyond the confirmed restatement scope

**Stop Rules (Section 8.5)**
- [ ] Stop rules included in SYSTEM BLOCK or per-task `<stop_rules>` element where over-working risk is high
- [ ] Multi-step agent tasks have turn limit and same-tool repetition limit

- [ ] OBJECTIVE section present and clear
- [ ] PROJECT CONTEXT lists language, libraries, workflow
- [ ] KEY FILES table maps all referenced paths
- [ ] Plan follows the four-block layout: System → Reference → Task → User input
- [ ] System and Reference blocks are stable (no interpolated timestamps or per-task values)
- [ ] Each task is an XML `<task>` element with all required child elements
- [ ] Each task has: `<intent>`, `<structure>`, `<context>`, `<constraints>`, `<naming>`, `<examples>`, `<dont>`, `<verification>`, `<output>`
- [ ] `reasoning` attribute set per task (non-think / think-high / think-max)
- [ ] `temperature` attribute set per task (0.0 for code; has no effect in thinking mode)
- [ ] Each task touches only ONE pipeline layer (or two with explicit justification and <100 LOC)
- [ ] Tasks are explicitly ordered
- [ ] Naming is specified for all new files/functions/variables
- [ ] No contradictions between tasks
- [ ] Total plan stays under ~500K tokens (plan + code + expected output)
- [ ] Think Max tasks: total request context window (input + reasoning trace + output) >= 384K tokens
- [ ] Approximate vs exact values are marked
- [ ] DON'T sections use Wrong/Right example pairs, not bare negatives
- [ ] Output anchors specified for tasks where format is non-obvious
- [ ] Hallucination guardrails present: unknown fields output sentinel value, not invented data
- [ ] Verification tasks use machine-checkable PASS/FAIL (not subjective observations)
- [ ] Tool-calling tasks specify single-tool-per-turn and include parser for content-field fallback
- [ ] JSON mode tasks include the word "json", an example schema, and adequate max_tokens
- [ ] Review/validation tasks use concrete item checklists (not open-ended "check all")
- [ ] Review/validation tasks specify a required output format (classification table)
- [ ] Cleanup/deletion tasks enumerate files or use discovery commands
- [ ] Later phases include non-regression constraints referencing earlier phase outcomes
- [ ] Update tasks use `rg -l` discovery instead of hardcoded file lists
- [ ] Verification commands match the plan exactly (no `grep` substitution for `rg`)
- [ ] No conditional decision branches ("if X delete, if Y extract") -- all outcomes pre-decided
- [ ] Inter-task data dependencies use concrete expected values from source material, with a stop rule if live data differs (not placeholders or "may differ" hedges)
- [ ] When the plan intentionally diverges from a source document's recommendation, the divergence is flagged in the task's `<context>` element with rationale
- [ ] diff-based review tasks specify an explicit git baseline SHA or ref (not `HEAD`)
- [ ] For diagnostic/investigation plans: test methodology matches production behavior
- [ ] For diagnostic/investigation plans: plan includes a sanity-check step comparing test output to KNOWN BEHAVIOR before analysis proceeds
- [ ] For diagnostic/investigation plans: devlog requirements are enumerated as a checklist
- [ ] For diagnostic/investigation plans: complex shell commands (2+ quoting levels) are provided as script files
- [ ] For diagnostic/investigation plans: cleanup steps for temp files and external system test data are explicit numbered actions
- [ ] Devlog: plan specifies devlog filename and location; devlog created as first action, updated after each task (Section 9); path follows `agent_planning/execution/<project_name>/devlogs/` convention
- [ ] Reconstruction: Every script deployed to a server has a copy saved in the repo (Section 9, Reconstruction Completeness)
- [ ] Reconstruction: Devlog includes full content of small files (<100 lines) or repo references for larger files
- [ ] Reconstruction: Notes file has a dedicated section with architecture, ports, alert rules, and redeployment steps
- [ ] Reconstruction: Plan + devlog + notes + repo scripts are sufficient to rebuild the entire solution without server access
- [ ] Home lab documentation: plans deploying services/VMs/ports/DNS include a task updating `~/git_projects/home-lab/SERVICE-MAPPING.md` (or HARDWARE.md, STORAGE.md, AUTOMATIONS.md as applicable) with the actual deployed state (Section 9.5, Home Lab Documentation Update)
- [ ] Knowledge base update: any plan task that touches a KB-covered system (service/VM/host/network/storage/automation/pipeline/MCP/skill) includes a task updating the matching `knowledge/<category>/<doc>.md`, bumping `updated:`, advancing `confidence:` if verified, and recording verification evidence in the affected doc or relevant devlog — the KB update is mandatory for any agent action, not only new deployments (Section 9.6, Knowledge Base Update)
- [ ] Tool versions: every external tool the plan configures has a VERIFIED version string (not assumed, not "latest")
- [ ] Overlay FS: tasks that modify container config files use stop-MergedDir-start pattern (not docker cp or sed -i on running containers)
- [ ] Config reload: tasks specify SIGHUP vs restart based on change type
- [ ] Multi-module: scrape jobs using blackbox_exporter use exactly ONE module per job
- [ ] Pre-deployment access verification: every exporter/scraper deployment task has STEP 1 as reachability gate; unreachable = BLOCKED (Section 13.I)
- [ ] Grafana rules: B step is type: reduce, thresholds in C step not A step (Section 13.J)
- [ ] Grafana rules: receiver is contact point NAME not UID; no unescaped curly braces in annotation templates

---

## 14. Execution Addendum (V4 Pro-Specific)

For session management, external memory artifacts, state writeback, and chunked execution, follow `agent_planning/EXECUTION_PROTOCOL.md`. The following constraints are V4 Pro-specific:

**Wrapper-first mandate:** V4 Pro's tool-call emission is unreliable (~79% correct rate). Prefer wrapper scripts over inline shell chains for any action executed more than once. Scripts provide a deterministic execution path that does not depend on correct tool-call emission. See EXECUTION_PROTOCOL.md Section 6.

**Single tool call per turn:** Instruct V4 Pro explicitly in the SYSTEM BLOCK: "Emit exactly one tool call per turn. Do not batch tool calls." This prevents the parallel emission pattern that causes silent step skips.

**Context window sizing:** V4 Pro's 1M-token window means long sessions are technically possible, but context past ~500K tokens introduces irrelevant signal the model treats as authoritative. Restart sessions after 5 tasks or after ~250K tokens of accumulated tool output.

**Writeback via `non-think` mode:** The state writeback step (EXECUTION_PROTOCOL.md Section 4) should be executed with `reasoning="non-think"`. It is a structured write, not a reasoning task. Using `think-high` here wastes tokens and introduces rewrite risk.
