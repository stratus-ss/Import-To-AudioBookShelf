# MiniMax M3 Plan Authoring Instructions

This document is the single reference for writing implementation plans consumed by MiniMax M3. It consolidates patterns from internal `.mdc` rules, `AGENTS.md` conventions, and MiniMax's official best practices.

---

## 0. Pre-Plan Interrogation Protocol

**This section governs what happens BEFORE any plan is written.** A plan authored without completing this protocol will be built on assumptions. For M3, assumptions become creative drift and reasoning spirals -- the model will invent plausible-looking features it was never asked for, and once it starts refining them it may loop without converging.

### Role Separation

The AI acts as **architect, planner, and technical expert**. The user is the **Subject Matter Expert (SME)** -- the authority on domain knowledge, business context, acceptance criteria, and what "done" looks like.

| Role | Owns |
|------|------|
| AI (Architect) | Technical approach, task decomposition, file structure, implementation patterns, verification strategy, pre-seeding decision records with domain trade-off context |
| User (SME) | Domain rules, business constraints, acceptance criteria, integration requirements, what is in/out of scope, decisions on pre-seeded DRs |

The AI must **never assume domain knowledge**. M3 generalizes well from examples -- which means it will confidently generalize FROM THE WRONG EXAMPLES if domain knowledge is not provided explicitly.

The user should **not dictate implementation details** unless they have a specific technical reason. Architecture and approach belong to the AI.

### Tier Classification (Choose Before Proceeding)

Before beginning discovery, classify the request into one of three tiers. The tier determines the discovery depth.

| Tier | Trigger | Discovery Method |
|------|---------|-----------------|
| **Tier 1** | Single-system, no remote deployment, <5 tasks. Bugfixes, single-file refactors, documentation, local scripts. | 7-category quick interview + restatement gate |
| **Tier 2** | Remote systems, deployment, monitoring setup, multi-host operations, 5–15 tasks. | Domain-specific Decision Records (DRs) + Discovery Summary + restatement gate |
| **Tier 3** | Multi-system integrations where 3+ independent systems must coordinate, multi-phase migrations with data-at-risk, or projects where a dependency graph between DRs is non-trivial (DRs gate other DRs). | Full grouped DRs + dependency graph + Architecture Summary + restatement gate |

When in doubt, choose the higher tier. The cost of under-scoping discovery is tasks that silently fail on unresolved assumptions.

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
| 7 | **Unstated constraints** | Deadlines, hardware limits, team conventions, regulatory requirements, things the user considers obvious. |

After the interview, produce the Restatement Gate (see below). No DRs required.

---

### Tier 2: Infrastructure Discovery

**The AI pre-seeds Decision Records (DRs) with domain trade-off context. The user provides the decisions.**

This mirrors how a Red Hat architect interrogates a client before an engagement: the architect writes the Issue (explaining what is at stake and why the decision is irrevocable or consequential), and the client fills in the Decision. The client is not expected to know the right questions -- the architect does.

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

DRs are organized by domain area (storage, auth, rollback, scope, integration), not generic categories. Each DR's Issue is written by the AI -- the user only provides Decision and Assumptions.

**DR count is variable.** Generate as few or as many DRs as the project requires -- a simple deployment may need 2, a complex migration may need 10. Do not pad to a round number. If you have produced your DRs, stop. A DR that does not meet any of the four criteria above is filler and must be cut.

**DR processing rules depend on context:**
- **When presenting DRs to the user for decisions:** Present all DRs in a single message with clear numbered IDs (DR-1, DR-2, etc.). Ask the user to respond with decisions keyed to each ID. Humans read sequentially and can handle a batch; multiple round-trips waste time.
- **When M3 processes DR responses via tool calls during execution:** Process one DR at a time. M3 has a confirmed failure mode (GitHub MiniMax-M3 #1) where it swaps results across parallel tool calls by arrival order rather than ID. Sequential processing prevents misattribution.

#### DR Example (InfluxDB Migration)

```
DR-1: Storage Backend
Issue: InfluxDB 1.x uses mmap() for TSM files. The storage backend choice
(local bind mount vs NFS vs named Docker volume) is irrevocable after the
first data write -- migrating to a different backend requires a full
export/import cycle. NFS + mmap causes silent data corruption on network
disconnect, query latency spikes, and TSM file lock contention. The
containers VM has 117 GB free on /var, confirmed sufficient for 5-year
growth. Local bind mount is the only safe choice for this workload.
Decision: [User provides]
Assumptions: [User provides]
Dependencies: none

DR-2: Unknown Database Writers
Issue: Three databases (solar, prometheus, zfs) have unknown writers.
Migrating data without redirecting writers creates split-brain state:
historical data lands on the new instance while new data continues flowing
to the old one. This is silent -- dashboards will appear to work on the
new instance for historical queries but go stale going forward. Options:
(a) discover all writers before migration begins, blocking the plan on
discovery; (b) migrate data and accept those databases as historical-only
until writers are found post-migration; (c) exclude those databases from
this migration entirely and handle them in a follow-up plan.
Decision: [User provides]
Assumptions: [User provides]
Dependencies: DR-1

DR-3: Authentication and Least-Privilege Access
Issue: The new InfluxDB instance will require auth (unlike some HA InfluxDB
configurations). If Grafana datasources use the admin user for queries, any
dashboard query can accidentally write or drop data. A read-only grafana
user must be created before datasources are configured -- this decision
controls Task 5 (Grafana update) and must be made before that task is
authored. Decide: admin-only (simpler, higher risk) or admin-for-writers +
read-only-grafana-user (recommended, requires an extra task).
Decision: [User provides]
Assumptions: [User provides]
Dependencies: DR-1

DR-4: Rollback Window
Issue: The final cleanup step (dropping migrated databases from HA InfluxDB)
is destructive and irreversible. If the migration introduced data gaps,
writer misconfiguration, or corruption that only surfaces days later, there
is no rollback path once the source databases are dropped. Options:
(a) keep source databases indefinitely (safest, wastes HA disk space);
(b) keep for N days post-verification before dropping (balance of safety
and cleanup); (c) drop immediately after verification passes (fastest,
highest risk). The drop task must be explicitly gated on verification passing.
Decision: [User provides]
Assumptions: [User provides]
Dependencies: DR-2, DR-3
```

#### Discovery Summary

After all DRs are resolved, the AI produces a Discovery Summary of 2-3 paragraphs covering: what the plan will do, what is explicitly out of scope, and how success is measured. This becomes the seed for the plan's OBJECTIVE and PROJECT CONTEXT sections.

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

**2. Architecture Summary (mini-HLD).** After DRs are resolved, the AI produces a 1-2 page Architecture Summary describing the end-state system, integration points, and data flows. This is reviewed and confirmed before any task decomposition begins. The Architecture Summary becomes the authoritative reference for PROJECT CONTEXT and the ACCESS & CREDENTIAL PREREQUISITES table.

Format:

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

**Tier 2 vs Tier 3 disambiguation:** A single-system deployment with a local orchestrator script is Tier 2 even if it has >15 tasks -- the complexity is in task count, not system integration. Tier 3 is reserved for cases where decisions in one system constrain decisions in another (e.g., DRs that have inter-DR dependencies, data migrations where source and target must coordinate, or multi-host deployments where ordering matters for correctness).

---

### The Restatement Gate (All Tiers)

Before writing any task, the AI MUST produce a restatement of the form:

> **What I understand:** [2-3 sentence summary of what the plan will achieve, what it will NOT do, and how success is measured.]
>
> **Does this match your intent?**

If the user corrects the restatement, another round of questions or DR revision follows. **Plan authoring is blocked until the restatement is confirmed.**

### Why This Matters for M3 Specifically

M3 has two primary failure modes that the discovery protocol directly mitigates:

- **Creative drift:** M3 invents features, patterns, and abstractions not requested. The restatement gate anchors M3 to what was confirmed. Anything outside the confirmed restatement requires explicit user approval before entering the plan.

- **Reasoning spiral (inference collapse):** M3 can enter infinite revision loops -- it recognizes a solution is suboptimal, generates a revised solution with a different flaw, recognizes that flaw, and repeats without converging. It will never self-report being stuck. The Discovery Summary and restatement gate are explicit convergence checkpoints that prevent this from occurring during the discovery phase and give the executing agent a clear "done" signal.

The tiered approach also prevents two common plan-authoring failures: under-scoped discovery (where Tier 1 is applied to a Tier 2 problem and assumptions become task-level surprises) and over-scoped discovery (where full ADR ceremony is applied to a 2-task bugfix and the protocol itself becomes the bottleneck).

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

Embed the resolved Decision Records from Section 0 discovery directly in the plan file. This gives the executing agent immediate access to the reasoning behind every architectural choice without requiring it to reconstruct the pre-plan conversation.

Format each DR as a collapsed block immediately after OBJECTIVE:

```
## DECISION RECORDS

### DR-1: [Title]
- **Decision:** [What was decided]
- **Rationale:** [Why -- key trade-offs from the Issue field]
- **Assumptions:** [What must be true for this decision to hold]
- **Dependencies:** [none / DR-N, DR-M]

### DR-2: [Title]
...
```

**Rules:**
- Include only DRs that were resolved during Section 0 discovery. Open/deferred DRs must be marked as such and must NOT gate any task.
- Every task that was shaped by a DR decision MUST reference the DR in its CONSTRAINTS section (e.g., "Per DR-3: use `grafana` read-only user, not admin").
- Do NOT re-open DR decisions during task authoring. If a task reveals the decision needs revision, surface it to the user before continuing.
- For Tier 1 plans: omit this section entirely.

### ACCESS & CREDENTIAL PREREQUISITES (MANDATORY for plans touching remote systems)

When the plan interacts with remote hosts, APIs, network devices, or authenticated services, this section MUST enumerate every access path the plan depends on:

| Target | Type | Credential/Path | Verified? | Verification command |
|--------|------|-----------------|-----------|---------------------|
| containers.x86experts.com | SSH | root key-based | ✅ | `ssh -o ConnectTimeout=5 root@containers.x86experts.com true` |
| grafana.x86experts.com | API | glsa_... token | ✅ | `curl -sk -o /dev/null -w "%{http_code}" https://grafana.x86experts.com/api/health` |
| 192.168.99.10 | SNMPv3 | user snmp, noAuthNoPriv | ❌ ASSUMED | `snmpwalk -v3 -u snmp -l noAuthNoPriv -t 5 192.168.99.10 1.3.6.1.2.1.1.5.0` — TIMEOUT |
| 192.168.99.10 | ICMP | — | ❌ ASSUMED | `ping -c 2 -W 2 192.168.99.10` — 100% loss |

**Rules:**
- Every target the plan deploys an exporter/scraper/agent against MUST appear in this table
- Claims MUST be marked `✅ VERIFIED` (with the exact command and its output) or `❌ ASSUMED` (untested)
- **No task that depends on an ASSUMED access path may proceed without first verifying it.** Tasks that depend on ASSUMED paths MUST include a STEP 0 that tests reachability before any deployment
- If a verification command returns unexpected results (timeout, unreachable, auth failure), the claim mark MUST be updated to `❌ BLOCKED` and the task must halt
- The litmus test: if you cannot run the verification command right now and get the expected output, the claim is ASSUMED, not VERIFIED

### PROJECT CONTEXT
- Language and runtime (e.g., Python 3.12, Go 1.26)
- Key libraries and frameworks
- How the pipeline/workflow operates (1-2 sentences)
- Repository root path
- **Tool versions for EVERY external tool the plan interacts with** - the exact version string, verified from the target host. This includes Prometheus, Grafana, blackbox_exporter, node_exporter, MinIO, Docker, nginx, and any other tool the plan configures or queries. Format: `Prometheus 2.45.0 (verified via prometheus --version on containers.x86experts.com)`. Do NOT write "v0.24+" or "latest" - cite the specific running version.
  - **Why:** v0.24.0 of blackbox_exporter uses `fail_if_body_not_matches_regexp` for body matching; v0.25+ uses a `body:` sub-map. node_exporter v1.8.1 exports `node_systemd_unit_state` but not `namedprocess_namegroup_num_procs`. Grafana rule patterns (2-stage vs 3-stage) vary by instance. Plans that assume tool behavior without verifying the actual version produce tasks that silently fail.
- **Existing infrastructure on ALL hosts the plan touches** — not just the target system. When a plan interacts with monitoring stacks, reverse proxies, databases, container hosts, or any shared infrastructure, document what already runs there (ports, versions, config paths). Cite the source of this information (e.g., "verified in infrastructure audit 2026-06-02", "confirmed via ssh recon on YYYY-MM-DD").
  - **Why:** M3 excels at recon of the system directly named in the objective but frequently omits dependency-side verification. Plans that say "deploy a blackbox_exporter" without checking whether one already exists on the monitoring host will produce port conflicts and deployment failures.
  - **Litmus test:** If the plan proposes creating or modifying a component on host B to monitor host A, the PROJECT CONTEXT must describe what is already running on host B that is relevant to the plan.
- **Behavioral assumptions must be verified-by-example** — for each tool the plan configures, cite an existing working instance of the same configuration pattern on the SAME host. E.g., "The existing `blackbox_ssl` job uses `replacement: containers.x86experts.com:9115` for the `__address__` relabel — this confirms the FQDN (not Docker DNS name) resolves in the prometheus container's network namespace." Do NOT assume patterns work without citing an existing example.
  - **Why:** The jellyfin plan assumed `replacement: blackbox-exporter:9115` would work based on Docker DNS conventions, but the prometheus container's network namespace had no such alias. The existing `blackbox_ssl` job already used the FQDN — the plan author could have verified the pattern by reading the existing config but didn't. Requiring an explicit existing-example citation forces the plan author to check.

### KEY FILES REFERENCE

| File | Purpose |
|------|---------|
| `path/to/file.py` | Brief description of what it does |

This table anchors every task. M3 uses it to locate code without guessing.

### TASKS
Numbered, ordered list of tasks (see Section 2).

---

## 2. Task Sections

Every task MUST include these sections. Omitting any causes M3 to fill the gap with creative drift.

### INTENT
Explain WHY the task exists and what problem it solves. M3 produces better output when it understands purpose, not just mechanics.

### STRUCTURE
Define exactly what to create or modify:
- File paths
- Function/method signatures
- Class names
- Output file names or formats

Do not leave architectural decisions to the model.

### SCHEMA (when applicable)
List exact field names, types, and order. Never say "appropriate columns" -- enumerate them.

### CONTEXT
Specify data sources with concrete names:
- Struct/class names and field names
- File paths where data originates
- Computation formulas where derivation is needed
- Reference existing patterns by name and path (e.g., "follow the pattern in `garmin_to_influxdb.py`")

When the plan's approach intentionally differs from a source document's recommendation (investigation report, prior plan, upstream documentation), flag it in the CONTEXT section with the format:

**Divergence from [source]:** [what the source recommended] → [what this plan does instead] — [rationale].

This prevents the executor from reading the source, finding a contradiction with the plan, and either following the source (wrong) or stopping to ask (wasteful).

### CONSTRAINTS
- Which files to modify (and which NOT to)
- Patterns to follow
- Limits: function length, complexity, no new packages, etc.
- Style requirements not covered elsewhere

### ACCESS PREREQUISITES (for deployment/monitoring tasks)
When a task deploys an exporter, scraper, agent, or configuration that targets a remote system, this subsection lists what must be reachable before proceeding:

- **Network reachability:** `ping -c 2 -W 2 <target>` must succeed (0% loss) OR document why ICMP may be blocked
- **Port accessibility:** `nc -z -w 3 <target> <port>` must show open OR explain alternative verification
- **Credential validity:** For authenticated services, the exact test command that confirms credentials work
- **Fallback instruction:** "If any prerequisite fails, mark the task BLOCKED with the specific failure evidence and continue to the next task. Do NOT deploy a scraper/exporter that will permanently show DOWN."

### NAMING
Define file names, function names, variable conventions, and component names. Without explicit naming, M3 produces generic names like `Component1`, `process_data`.

### EXAMPLES (optional)
Show concrete good/bad examples where demonstrating a pattern is clearer than describing it. M3 generalizes well from examples.

### No conditional branches

A task MUST NOT contain "if X then do Y, if Z then do W" decision trees. The plan author has product context that the executor does not. Pre-decide every outcome and state it as a directive.

**Bad:**
- "If kvm-api is obsolete, delete it. If it's still used, extract to its own repo."

**Good:**
- "Delete kvm-api/ entirely -- it is superseded by kvm-mcp (confirmed with owner)."

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

### DON'T
Explicitly list what NOT to do. M3 may drift without negative constraints. Always include:
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

**For containerized projects — final task only:** The last task's VERIFICATION MUST include the production image verification sequence from Section 13.N (build → push → deploy → E2E → healthcheck). Pytest alone is not sufficient as the final verification for a containerized project, even if no production code changed. See Section 13.N for the required steps and example structure.

Every task's VERIFICATION section MUST end with a **DEVLOG** step that updates the running devlog before proceeding to the next task. This is not optional -- it is part of the task's completion criteria. A task is NOT complete until the devlog has been updated. Format:

```
DEVLOG: Update agent_planning/execution/<project_name>/devlogs/{name}_{date}.md
  - Add this task's entry to the Execution Log section
  - Update the Remaining Tasks checklist
  - If this is Task 1, create the devlog file first
```

After the devlog update, also perform the EXECUTION_PROTOCOL.md Section 4 writeback: update TASK_QUEUE.md, SESSION_BRIEF.md, and HANDOFF.md in `agent_planning/execution/<project_name>/`.

The devlog update must be the LAST action in every task -- after verification passes but before starting the next task. Plan authors MUST include this step in every task. The executing agent MUST NOT skip it or batch devlog updates.

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
- Tasks MUST be ordered to minimize conflicts -- new additions before modifications.
- Target ~50 lines of new/modified code per task. Larger scope risks silent incompletion.
- For M3, the ~50 line target may be relaxed to ~100 lines for well-scoped tasks where structure and context are fully specified. The limit still applies to tasks involving complex cross-file logic, new abstractions, or schema changes -- those remain single-focused at ~50 lines.
- M3 completes longer task scopes more reliably than M2.7, but silent incompletion still occurs when a task spans multiple pipeline layers. Single-layer scoping (Section 4) remains MANDATORY.
- If a feature needs types + logic + output, that is 3 tasks minimum.
- Every task that adds struct fields MUST have a paired output-wiring task later.

---

## 4. Single-Layer Scoping

M3 executes tasks best when they touch ONE concern layer. Tasks that cross layers risk exhausting attention on early layers and silently skipping later ones. This risk is reduced vs M2.7 but still present for complex cross-layer work.

Identify the layers relevant to your project. Common patterns:

- **Application code:** Types/Models, Collection/Input, Transform/Logic, Output/Presentation, Tests
- **Infrastructure/deployment:** Configuration files, Provisioning scripts, Service definitions, Verification/healthchecks
- **Data pipelines:** Schema, Ingestion, Transformation, Output, Validation

Each task operates on at most ONE layer. If a feature spans layers (e.g., a new config value that requires a provisioning change AND a service restart AND a healthcheck update), split into separate tasks per layer.

---

## 5. Token and Context Management

M3 has a 1,000,000 token context window (512K guaranteed minimum) via MiniMax Sparse Attention (MSA). Standard billing applies up to 512K tokens; long-context billing (higher rate) applies above 512K on pay-as-you-go.

- Keep plan introductions concise -- every token counts even with large windows.
- The phased window approach from M2.7 is NO LONGER REQUIRED for plans <=15 tasks. M3 can hold the full plan, codebase, and skill docs in one session without goal drift.
- For very large plans (>15 tasks, or plans referencing >300K tokens of repo context), still consider splitting into phases -- not for context capacity, but to keep per-session cost predictable.
- Remove the 200K system prompt workaround -- M3 does not require it.
- The ">8 tasks -> split into two plans" rule is relaxed to ">15 tasks" for M3.
- **Large file reference rule:** If any single file referenced by the plan's KEY FILES REFERENCE or CONTEXT sections exceeds 500 lines, the plan MUST include an explicit token budget estimate at the top of the OBJECTIVE section. Format: `Token budget: ~XXX K tokens (plan + N files: file1 L lines, file2 M lines)`. This prevents the executing agent from pulling a large file into context without realizing the cumulative token cost.
- **Batch-task risk:** When a single task's STRUCTURE describes generating more than 200 lines of output (e.g., a complex JSON config, a large dashboard, a multi-query script), that task MUST be split into sub-tasks even if it stays under 15 total tasks. The risk is not just context overflow but attention fragmentation — the model exhausts focus on early details and silently skips later ones.

---

## 6. Consistency Rules

- Plans MUST NOT contain contradictory constraints across tasks.
- If a later task overrides an earlier constraint, state the override explicitly.
- Formatting rules (tables vs bullets, prose vs lists) must be consistent across all tasks.
- Mark approximate values as "(approximate -- verify against source)".
- Mark exact values as "(exact -- do not deviate)".
- Unmarked numbers are treated as exact.
- **Verification claims MUST be marked with provenance:** `✅ VERIFIED via <command> on <YYYY-MM-DD>` or `❌ ASSUMED (not tested)` or `⚠️ STALE (last verified <date>, may have changed)`. A claim without provenance markup is ASSUMED by default and MUST be independently tested before acting on it.
- **Credentials and access URIs:** Bot tokens, API keys, chat IDs, and target IPs that were verified in a prior devlog must cite that devlog by path. If no devlog citation exists, the credential is ASSUMED and the executing agent must test it.

---

## 7. Prompting Best Practices (from MiniMax official docs)

### Be specific
Instead of "Create a config parser", say "Create a YAML config parser that reads `config.yaml`, validates required keys `host`, `port`, `database`, and returns a `Config` dataclass with those fields."

### Explain intent
Instead of "Don't use print statements", say "This code runs as a library imported by other modules, so use `logging.getLogger(__name__)` instead of print statements for observability."

### Use examples
Show a concrete good example and a concrete bad example. M3 generalizes from examples better than from abstract descriptions.

### Negative constraints matter
M3 may drift creatively without explicit "don't" lists. Always include what NOT to do.

### M3 Tool Use Notes

Early user reports indicate M3 follows structured plans more reliably than M2.7 — reduced drift and better long-session stability are widely noted. However, reports also confirm that M3 still skips details, hallucinates findings in unread files, and misunderstands instructions when plans are ambiguous:

- **Explicit DON'T sections remain MANDATORY.** M3 is better at following constraints than M2.7, but user reports show it still skips files it "didn't bother to look into" and produces confident-but-wrong analysis when scope is open-ended.
- **Inline constraint restating per step is now recommended but not mandatory** (was mandatory for M2.7). For complex skill-constrained tools, still restate inline. For standard file/code operations, a single CONSTRAINTS section is usually sufficient.
- M3 handles long sessions better than M2.7 — multiple users report reduced monitoring burden and fewer drift events. However, one user noted detail-skipping emerged after ~10 hours of heavy use, so verification checkpoints remain important.
- **The core thesis of this document stands:** M3 works best with strict, detailed plans. It is not a model for open-ended exploration.

**Five confirmed M3 failure modes (June 2026) that plan tasks must explicitly defend against:**

| # | Failure Mode | Symptom | Plan Defense |
|---|-------------|---------|-------------|
| M3-1 | Parallel tool call misattribution | Silent result swap across parallel calls | Sequence tool calls; never parallelize dependent operations |
| M3-2 | Reasoning spiral (inference collapse) | Infinite self-revision loop, never converges | Explicit convergence stop rule per task; restatement gate as checkpoint |
| M3-3 | High latency | 8+ min TTFT on complex tasks, agent timeouts | Set loop timeouts to 15+ min for Tier 2/3; document expected latency |
| M3-4 | Tool call payload corruption | Silently dropped args, no-op tool calls | Machine-verifiable verification step on every tool-executed step |
| M3-5 | Interleaved thinking state loss | Performance degrades across turns if thinking stripped | Preserve full `response_message` in API history; `reasoning_split=True` |

See **Section 13.M** for full detail and per-failure-mode plan defense patterns.

---

## 8. Plan File Conventions

- **Plan documents** (the meta-file describing what to build) are stored in `./zed_plans/` (relative to the repository root). This is non-negotiable regardless of where implementation artifacts are placed.
- **Implementation artifacts** (scripts, configs, playbooks, code files created by executing the plan) go wherever the user specifies. If the user says "nest files in ./FishTTS/", the plan goes to `./zed_plans/` and the scripts go to `./FishTTS/`.
- File naming: `{descriptive_name}_{YYYY-MM-DD}.md` (e.g., `ente_alerts_cleanup_2026-06-04.md`). Always append the date in YYYY-MM-DD format to the file name.
- Each plan file is self-contained -- it includes all context needed for execution.
- Plans reference templates and existing code by path so M3 can read them.

---

## 8.5. Stop Rules

Stop rules tell M3 when to stop. Without them, M3 will over-work tasks: adding features that "seemed reasonable," refactoring code outside the task scope, or running extra verification passes not requested.

Stop rules belong in two places:
- **Plan-level:** As a STOP RULES section in the plan preamble, applied globally to the whole execution
- **Task-level:** Inside individual task CONSTRAINTS sections for task-specific limits

### For Plan Authoring (used by the plan author, not M3)

Stop writing tasks when the OBJECTIVE is fully covered end-to-end. Do not add tasks because they are "nice to have," "related," or "probably expected." The interrogation restatement (Section 0) is the scope boundary -- anything outside it requires user approval before it enters the plan.

### Paste-Ready Templates

Add these to task CONSTRAINTS sections or the plan preamble as needed:

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

**For document review tasks:**
```
STOP RULES:
- Stop after identifying the issues listed in the checklist. Do not scan beyond listed items.
- One finding per checklist row, plus the file path and line number.
- Do not suggest rewrites unless explicitly asked.
```

**For classification/support tasks:**
```
STOP RULES:
- Stop after one clarifying question maximum. Then make your best classification and proceed.
- Do not escalate unless the escalation rule explicitly applies.
- Stop after the response is drafted. Do not preview alternatives.
```

**For multi-step agent workflows:**
```
STOP RULES:
- Stop after 20 turns total in this task. If incomplete, surface what remains.
- Stop if the same tool is called 3 times with no progress.
- Stop if you are reading files outside the original scope in CONSTRAINTS.
```

### M3-Specific Note

M3's creative generalization is its strength and its failure mode. It is good at inferring what "should" exist and producing it -- which means it will add abstractions, refactor patterns, and extend scope whenever the boundary is implicit rather than explicit. Stop rules make the boundary explicit.

M3 also handles long sessions well, but user reports confirm detail-skipping can emerge after heavy use. Explicit stop rules reduce the attention budget M3 spends on out-of-scope work, leaving more for the actual task.

---

## 9. Devlog Pairing (MANDATORY)

Every plan execution MUST produce a devlog entry. This is not optional — the devlog is the authoritative record of what was done, what was discovered, and what state was left behind. Plans executed without a devlog are incomplete.

### Context Recovery Principle

The devlog is the authoritative **audit trail and evidence record** — not the primary recovery mechanism. For fast session recovery (new thread, context cleared, agent restart), the primary context sources are `agent_planning/execution/<project_name>/SESSION_BRIEF.md` and `HANDOFF.md`, per `agent_planning/EXECUTION_PROTOCOL.md`.

The devlog MUST be self-contained as an audit record: an agent consulting it must be able to determine what was decided, what was discovered, and what state was left behind. The devlog provides detailed evidence when the SESSION_BRIEF is insufficient. This means:

- Every task entry must record enough detail that re-execution or continuation requires zero prior context
- The "Remaining Tasks" section (see format below) must be updated after every task so the next agent knows exactly what to do next
- The devlog replaces conversation memory — if the context window is cleared mid-execution, the devlog is the only source of truth

### Devlog Lifecycle

1. **CREATE the devlog after the FIRST task completes.** Populate the title, date, Objective section, the first task's execution details, and the Remaining Tasks section immediately.
2. **UPDATE the devlog at the END of EACH subsequent task.** Append the task's execution details, discoveries, files changed, and verification results. Update the Remaining Tasks section to reflect current progress. Do not batch updates — write them while details are fresh.
3. **FINALIZE the devlog after all tasks are complete.** Replace the Remaining Tasks section with the Result / Conclusion / Next Steps section and verify all sections are populated.

**Enforcement:** To prevent agents from deferring devlog writes to the end, every task in the plan MUST include an explicit DEVLOG step in its VERIFICATION section (see Section 2, VERIFICATION). A task whose devlog step has not been executed is NOT complete, regardless of whether the functional work succeeded. Plan authors are responsible for including this step in every task.

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

## Remaining Tasks
(Present from first task onward. Updated after EVERY task completion.
Replaced by "Result / Conclusion / Next Steps" when finalized.)

- [ ] Task N+1: {Name} — {any notes from completed tasks that affect this one}
- [ ] Task N+2: {Name}

This section is the handoff point for context recovery. A new agent with only
the plan file and this devlog reads the Execution Log to understand what was
done, and this section to understand what remains. Include any discoveries or
state changes from completed tasks that affect remaining work.

## Result / Conclusion / Next Steps
(Replaces "Remaining Tasks" when all tasks are finalized.)
- Final outcome
- Any unverified or deferred items
- Concrete next actions

---

*Execution completed — {YYYY-MM-DD} ~{HH:MM} {timezone}*
```

### Devlog Location and Naming Convention

All devlogs MUST be written to the project's execution devlogs directory: `agent_planning/execution/<project_name>/devlogs/` (where `project_name` is declared in the plan's OBJECTIVE section).

```
agent_planning/execution/<project_name>/devlogs/{descriptive_name}_{YYYY-MM-DD}.md
```

Examples:
- `agent_planning/execution/fish_tts/devlogs/fish_tts_thunder_bootstrap_2026-06-17.md`
- `agent_planning/execution/vikunja/devlogs/vikunja_mcp_2026-05-01.md`
- `agent_planning/execution/general/devlogs/unified_format_design_2026-04-27.md`

The descriptive name should match the plan's descriptive name. Use hyphens in the date (YYYY-MM-DD) and underscores between words in the description.

### Investigation/Diagnostic Devlog Requirements

When the plan is investigative (reproduce bug, analyze logs, identify root cause), the devlog has additional requirements beyond the standard format:

1. **Required criteria checklist:** If the plan specifies items the devlog must address, list them as a checklist at the top of the Execution Log and answer each one explicitly. Never omit a required criterion.
2. **Evidence-linked conclusions:** Every conclusion or "ruled out" claim must cite specific log lines, command output, or timestamps. Do not state "X was confirmed" without showing the evidence inline.
3. **No forced classification:** If evidence is insufficient, state "Inconclusive" rather than guessing. See Section 12 for full rules.
4. **Sanity-check gate:** The devlog must state whether the test results matched the expected failure pattern. If they did not match, the devlog must not proceed to root cause classification.
5. **No stream-of-consciousness:** Devlogs must be professional analysis, not debugging journals. No "Wait -- actually..." or self-contradictions. Present conclusions supported by evidence, not the journey to reach them.

### Deviation Propagation to Repo Artifacts (MANDATORY)

When plan execution discovers deviations from the plan (wrong tool version, missing metric, different config pattern, behavioral difference), the deviation MUST be documented in TWO places:

1. **The devlog** (in the per-task "Deviations from plan" section and the "Issues Encountered" section)
2. **The project's README or notes file** (as a dedicated "Adaptation Notes" table showing what the plan said vs what was actually done)

A deviation documented only in the devlog is insufficient. Future operators or agents reading the repo's README must see the adaptation notes so they understand why the deployed config differs from what a naive reading of the plan would produce. Without this, a redeployment from the original instructions would reintroduce the same bugs.

**Format for the repo-side Adaptation Notes table:**

```markdown
## Adaptation Notes (differences from the original plan)

| Plan said | Actually did | Why |
|-----------|--------------|-----|
| `body: { expression: "..." }` | `fail_if_body_not_matches_regexp: ["..."]` | v0.24.0 doesn't support `body:` sub-map |
| `namedprocess_namegroup_num_procs` | `node_systemd_unit_state` | Metric not exported by node_exporter v1.8.1 |
```

Every plan task that includes a VERIFICATION step must, if a deviation was discovered, include a sub-step to propagate that deviation to the project README.

### Verification Integrity Rule (CRITICAL)

**Never use `...` to abbreviate verification commands or their output in the devlog.** The devlog is the authoritative record for context recovery (see Context Recovery Principle above). A verification entry that says:

```
$ curl -sk ... "https://grafana.../api/search?type=dash-db"
  ... 8 hits, all in their target folders ...
```

...is NOT a verification — it's a paraphrase. The executing agent may have:
1. Never actually run the command (hallucinated the output)
2. Run it but misinterpreted the results (94% non-abstention risk)
3. Run it against stale state before a bug manifested

**Rule:** Every verification command in the devlog MUST show:
- The exact, complete command (no `...` in URLs, headers, or payloads)
- The actual output, copy-pasted from the terminal (at minimum the key lines)
- For tabular output: the table must be pasted, not summarized

**Enforcement:** If the executing agent writes `...` in a verification output in the devlog, the task is NOT complete. The VERIFICATION section in every plan task MUST include: `Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with '...'.`

---

## 10. Review and Validation Task Pattern


### Reconstruction Completeness (MANDATORY)

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

M3 reliably creates and modifies code but still struggles with open-ended verification tasks. When told to "check all removed lines" in a 500-line diff, it may shortcut to "all looks fine" without verifying individual items. Review tasks require a different plan structure than implementation tasks.

### Use concrete checklists, not open-ended scans

Never instruct M3 to "check all removed lines" or "verify every CLI flag." Instead, pre-enumerate every specific item to verify in a checklist table:

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

### Require structured output

Every review task MUST specify a required output format that forces M3 to show its work. Without this, M3 may claim "all clean" without evidence.

```
REQUIRED OUTPUT -- produce this exact table:
| # | Item | Status | Found in |
|---|------|--------|----------|
| 1 | GARMIN_USER | FOUND/LOST | README.md |
| 2 | --dry-run | FOUND/LOST | -- |
```

M3 must fill in every row. If the output table is absent or incomplete, the review result is invalid.

### Scope limits for review tasks

- Max 3 repos per review plan. High-risk repos (>200 removed lines) get their own plan or share with at most 1 other repo.
- Max ~30 checklist items per task. Longer checklists should be split across multiple tasks within the plan.
- Process repos in risk order (highest first) so the highest-risk repo gets the freshest context window.

### Provide expected-location hints

Each checklist item should include where the content is expected to be found. This anchors M3's search and prevents lazy "not found" classifications:

```
| 9 | ALLOWED_DISK_PATHS env var | `ALLOWED_DISK_PATHS` | QUICKSTART.md |
```

### Use search commands, not diff parsing

Instead of asking M3 to parse `git diff` output (which can be hundreds of lines), instruct it to search for each item directly:

```bash
rg "SEARCH_TERM" README.md QUICKSTART.md ARCHITECTURE.md CODEFLOW.md AGENTS.md
```

This is more reliable than asking M3 to mentally classify 200 removed lines.

### Pre-extraction pattern for rewrite plans

Before any plan that rewrites a large file (>100 lines), create a content inventory. The rewrite plan should include a task that extracts all significant items (env vars, CLI flags, config options, warnings, feature descriptions) into a checklist. The review plan then references this checklist instead of re-deriving it from the diff.

If the inventory was not created before the rewrite, the review plan author must extract it from the `git diff HEAD` output and embed it directly in the review plan as a checklist table.

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

When a later phase (e.g., fix_data_paths) touches files that an earlier phase (e.g., fix_imports) cleaned up, explicitly state what the earlier phase achieved and that it MUST NOT be reverted:

```
CONSTRAINT: Phase 5c removed all `sys.path.insert` calls from this repo.
This phase MUST NOT reintroduce `sys.path` hacks. If a module needs the
package root for path resolution, import from `paths.py` -- do NOT use
`sys.path.insert`.
```

Without this, M3 will take the path of least resistance and reintroduce the hack it just removed.

### Verification tasks need machine-checkable pass/fail criteria

Replace subjective criteria ("actually start the app briefly") with concrete commands that produce unambiguous pass/fail:

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

When a verification step might be blocked by an external constraint (missing system lib, network), provide the BLOCKED status explicitly so M3 cannot classify it as PASS.

### Discovery-based scope for update tasks

When a task says "update all X references," M3 will only check the files explicitly listed. If the real scope is "all files containing pattern Y," instruct M3 to discover the scope first:

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

This prevents M3 from updating only the 4 listed files while 3 sub-module READMEs retain stale paths.

### Verification command fidelity

M3 must execute the EXACT verification commands specified in the plan. Do not substitute `grep` for `rg`, and do not use shell globs (`*.md`) where recursive ripgrep was specified (`--glob '*.md'`). A shell glob like `grep -rn 'pattern' *.md` only matches files in the current directory, while `rg -l 'pattern' . --glob '*.md'` searches all subdirectories. These are not equivalent.

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

When a plan's purpose is to reproduce a bug, collect diagnostic data, and identify root cause (rather than implement a feature), additional rules apply. Investigation plans interact with remote hosts, containers, external APIs, and live environments where shell quoting, test methodology, and cleanup matter more than in pure code-generation tasks.

### Test Fidelity: Match Production Behavior Exactly

Diagnostic tests MUST replicate how the system operates in production. Approximations that differ from production behavior produce invalid data.

**stdio/pipe transports:** `cat input | process` closes stdin immediately after the last message. This is NOT equivalent to a client that keeps the pipe open across multiple requests. For MCP servers, gRPC services, or any protocol where the client maintains a persistent connection, use a method that keeps the connection open:

- Python `asyncio` script that sends messages and awaits responses
- Explicit sleep to prevent premature EOF: `{ cat input.txt; sleep 30; } | docker exec -i ...`
- A purpose-built test harness that manages the connection lifecycle

**API clients:** Diagnostic test scripts MUST use the same initialization path as production code. If production uses `_get_client()` which reads config from environment and passes `verify=False`, the test script must NOT instantiate the client directly with different defaults. Before writing a diagnostic test script, verify it exercises the EXACT same code path that triggers the bug in production.

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

When a plan task includes commands with 2+ levels of quoting (SSH wrapping heredoc wrapping JSON with special characters), provide the command as a standalone script file that gets `scp`'d or `docker cp`'d to the target -- not as inline shell.

**Bad (fragile across shell implementations):**
```bash
ssh host 'cat > /tmp/file << '"'"'EOF'"'"'
{"jsonrpc":"2.0",...,"project":"Steve'"'"'s TO-DOs"}
EOF'
```

**Good:**
```
STRUCTURE:
  1. Create tests/reproduce_crash.json with the 5 JSON-RPC messages (no quoting issues in a flat file)
  2. Copy to remote: scp tests/reproduce_crash.json arch-openclaw:/tmp/
  3. Execute: ssh arch-openclaw "{ cat /tmp/reproduce_crash.json; sleep 30; } | docker exec -i vikunja-mcp ..."
```

### Sanity-Check Test Results Before Analysis

After collecting diagnostic data, compare results against KNOWN BEHAVIOR before proceeding to root cause analysis. If the test output does not match the expected failure pattern, the test is invalid -- do not draw conclusions from it.

| Expected (from plan) | Actual (from test) | Action |
|----------------------|-------------------|--------|
| 2 calls succeed, 3rd crashes | 0 calls complete (no HTTP responses at all) | **INVALID.** Test methodology did not reproduce the production failure. Redesign the test. Do NOT classify a root cause. |
| 2 calls succeed, 3rd crashes | 2 calls succeed, 3rd returns error | Valid -- proceed to analysis |
| 2 calls succeed, 3rd crashes | All 3 calls succeed | Valid -- bug may be environment-specific. Note this. |

If test results are anomalous, the analysis task MUST report the anomaly rather than forcing a root cause classification. State explicitly: *"The test did not reproduce the original crash pattern. Diagnostic data is inconclusive for root cause classification."*

### Handling Inconclusive Results

"Inconclusive -- test methodology invalid" is a valid devlog conclusion. Do NOT force a classification when evidence is insufficient.

When a diagnostic test fails to reproduce the bug, the devlog MUST:
1. State that the test was inconclusive
2. Explain why the test methodology differed from production behavior
3. Recommend a specific test redesign
4. Report any partial findings that ARE valid (e.g., "the `project` parameter was correctly populated on all 3 calls -- Hypothesis A is ruled out regardless of test methodology")

### Devlog Quality for Investigation Plans

Investigation devlogs MUST be professional analysis, not debugging journals:

- No stream-of-consciousness ("Wait -- actually...", "Let me trace through...")
- No self-contradictions (e.g., claiming "0 HTTP responses" and "all responses returned successfully" in the same document)
- Every "ruled out" hypothesis MUST have explicit supporting evidence stated immediately before the claim
- If the plan specifies required devlog criteria (e.g., "state whether error handling prevented crash"), each criterion MUST be explicitly addressed -- even if the answer is "cannot be determined from available data"
- Present conclusions supported by evidence, not the journey to reach them

### Artifact Cleanup

Every plan that creates temporary files (test scripts, helper scripts, data files) or test data in external systems (API records, database rows) MUST include an explicit cleanup step as a separate numbered action with verification:

```
CLEANUP:
  1. Delete test records from Vikunja API
  2. Remove temp files: rm test_vikunja.py test_http.py
  3. Verify: ls test_*.py 2>&1 | grep -q "No such file" && echo PASS
```

---

## 13. Operational Robustness

Rules for plan tasks that involve runtime environments (containers, remote hosts, file transfers) where common failure modes are predictable and avoidable.

### A. Container Filesystem vs Host Filesystem

Scripts created on the host are NOT automatically available inside a container. Any task that creates a file to be executed inside a container MUST include an explicit copy step:

```
1. Write /tmp/test_script.py on host
2. docker cp /tmp/test_script.py container_name:/tmp/test_script.py
3. docker exec container_name python3 /tmp/test_script.py
```

Do NOT write steps that assume host paths are visible inside containers.

### B. File Modification Resilience

When a plan modifies source files, specify the exact content or diff for each modification. Do NOT rely on partial-file edits that require the tool to locate insertion points in files it may not fully understand. For critical modifications:

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

When a plan modifies files inside a running container (e.g., Prometheus rules, blackbox config, museum.yaml), the container's overlay filesystem blocks writes to in-use files. Common operations that FAIL silently or with "Device or resource busy":

- `docker cp` into a running container (overlay file is locked by the process)
- `sed -i` inside a running container (creates temp file + rename, blocked by overlay)
- `cat > file` inside a running container (truncate + write blocked)

**The only reliable method** to update an in-use file inside a container is:
1. `docker stop` the container
2. Write to the file via the host's MergedDir overlay path: `docker inspect -f '{{.GraphDriver.Data.MergedDir}}' container_name`
3. `docker start` the container

Tasks that modify container config files MUST include these steps explicitly. Do NOT specify `docker cp`, `sed -i`, or SIGHUP-based reload as the modification path for container overlay files.

### G. Configuration Reload Behavior (Prometheus, nginx, blackbox_exporter)

Different tools handle runtime config reloads differently. Do NOT assume SIGHUP works for all config changes:

| Tool | SIGHUP reloads | SIGHUP does NOT reload |
|------|---------------|------------------------|
| Prometheus | Rule files, scrape interval changes | `__address__` relabel changes, `job_name` changes, new/removed scrape jobs |
| blackbox_exporter | Module definitions | Module removal (old modules persist), port changes |
| nginx | Full config (nginx -s reload) | — |

When in doubt, specify a full container restart. For Prometheus specifically: if the plan changes `relabel_configs`, `__address__`, or adds/removes scrape jobs, use `docker restart` (not SIGHUP). If only changing rule files or scrape intervals, SIGHUP is sufficient.

### H. Multi-Module Probe Behavior (blackbox_exporter)

When a Prometheus scrape job specifies multiple modules in `params: module: [A, B]`, blackbox_exporter runs BOTH modules sequentially against the target but returns AGGREGATED metrics. For shared metric names (e.g., `probe_success`, `probe_failed_due_to_regex`), the FIRST module's value masks the second's.

**This is a silent masking bug.** A body-match failure in module B will NOT appear in `probe_failed_due_to_regex` if module A (which has no body check) runs first.

**Rule:** Each scrape job MUST use exactly ONE module. If the plan needs both an HTTP 2xx check AND a body-match check on the same target, create TWO separate scrape jobs — one per module. Do NOT combine modules in `params`.

### I. Pre-Deployment Access Verification (MANDATORY for monitoring plans)

**The #1 cause of deployment failures in monitoring plans is deploying an exporter for a target that is unreachable.** Before any task that deploys an exporter, scraper, or agent for a remote target, the FIRST numbered step MUST be an access verification gate:

```
STEP 1 (ACCESS GATE):
  a. ping -c 2 -W 2 <target> — must return 0% loss (or document why ICMP blocked)
  b. For SNMP: snmpwalk -v3 -u <user> -l noAuthNoPriv -t 5 <target> 1.3.6.1.2.1.1.5.0 — must return sysName
  c. For HTTP exporters: curl -sk -o /dev/null -w "%{http_code}" <target_url> — must return non-000
  d. If ANY check fails: mark task BLOCKED with specific evidence. Record in devlog.
     Continue to next task. Do NOT deploy a scraper that will permanently show DOWN.
  e. If ALL checks pass: record evidence in devlog and proceed with deployment.
```

This gate is NOT optional. Tasks that deploy exporters without this gate are incomplete by definition. The executing agent MUST insert this gate even if the plan omits it — but plan authors MUST include it so the agent doesn't have to guess.

**Credentials vs reachability:** When an access check fails, the agent MUST distinguish between:
- **Reachability failure:** ping fails, no ARP entry, TCP connection refused — the target is offline or on a different network. This is NOT a credentials issue.
- **Authentication failure:** ping succeeds, TCP connects, but SNMP/API returns auth error — wrong credentials. Raise to user with the specific auth error.
- **Both:** ping succeeds but SNMP times out — could be SNMP service not running, wrong port, or firewall. Test port with `nc -z` before concluding credentials.

### J. Grafana 3-Stage Alert Rule Pattern (CRITICAL)

Grafana-managed alert rules with Prometheus datasources use a 3-stage expression pattern (A → B → C). This pattern has two common failure modes that produce `DatasourceError` alerts with broken template rendering:

**Failure mode 1: B step type**

The B step MUST be `type: "reduce"` with `reducer: "last"`, NOT `type: "threshold"` with empty params. Using `type: threshold` with empty evaluator params causes Grafana to reject the expression with `invalid condition: incorrect number of arguments for threshold function`. This happened in the 2026-06-04 execution (Task 3) and required a fix pass.

**Correct B step:**
```json
{
  "refId": "B",
  "datasourceUid": "__expr__",
  "model": {
    "expression": "A",
    "refId": "B",
    "type": "reduce",
    "reducer": "last",
    "datasource": {"type": "__expr__", "uid": "__expr__"}
  }
}
```

**Failure mode 2: Threshold placement and `$value` template rendering**

When the A step includes a PromQL comparison (e.g., `rate(metric[5m]) > 10`), the value returned is the COMPARISON RESULT (0 or 1), NOT the actual metric value. If the annotation template uses `{{ $value }}`, it shows "1" instead of the actual metric value. This happened twice: 2026-06-04 Task 3 and 2026-06-05 SwitchInterfaceErrors.

**Rule:** Put the PromQL expression WITHOUT a comparison in the A step, and put the threshold in the C step's `evaluator.params`:

**Good (shows actual metric value as `$value`):**
```
A: rate(ifInErrors{job="snmp_unifi"}[5m])    ← no comparison, returns actual rate
B: type: reduce, reducer: last, expression: "A"
C: type: threshold, expression: "B", conditions[0].evaluator.params: [10], type: gt
```

**Bad (`$value` shows 0 or 1):**
```
A: rate(ifInErrors{job="snmp_unifi"}[5m]) > 10  ← comparison returns 0/1, not the rate
B: type: reduce, reducer: last
C: type: threshold, conditions[0].evaluator.params: [0], type: gt
```

**Exception:** When the metric itself is binary (e.g., `up{...} == 0`, `ifOperStatus == 2`), it's correct to keep the comparison in A — `$value` will naturally be 0 or 1 regardless. The threshold placement rule only matters when you want `$value` to display a non-binary measurement.

**Template escaping:** Annotation `description` fields that contain literal curly braces for Docker/shell formatting (e.g., `docker stats --format "table {{.Name}}\t{{.MemPerc}}"`) MUST escape them using Go template syntax: `{{"{"}}` produces literal `{`. Unescaped `{{.Name}}` directives break the ENTIRE template expansion, including `$value` and `$labels.*`.

**Receiver names in Grafana 13:** The `notification_settings.receiver` field uses the contact point NAME (e.g., `"Telegram HostDown"`), NOT the UID (e.g., `"ffnxjmcpvx2wwe"`). Using UIDs returns HTTP 400 `"receiver <uid> does not exist"`.

### K. Grafana Dashboard API — `folderUid` Placement (CRITICAL)

When creating or updating dashboards via `POST /api/dashboards/db`, the `folderUid` field MUST be placed at the **top level** of the request payload, NOT inside the `dashboard` object. Grafana silently ignores `folderUid` inside `dashboard` and places the dashboard in the General folder.

**Correct (top-level folderUid):**

```json
{
  "dashboard": {"title": "My Dashboard", "panels": [...]},
  "folderUid": "target-folder",
  "overwrite": true
}
```

**Wrong (inside dashboard — silently ignored):**

```json
{
  "dashboard": {"title": "My Dashboard", "folderUid": "target-folder", "panels": [...]},
  "overwrite": true
}
```

**Rule:** Any plan task that creates or updates a Grafana dashboard MUST show the payload structure with `folderUid` at the top level in its SCHEMA or CONTEXT section. Verification MUST confirm the dashboard is in the target folder, not just that it exists.

**Additional Grafana API quirks:**
- UID length limit: 40 characters. Prefix-based naming can exceed this — validate before posting.
- Self-signed certs: All curl commands MUST use `-k`; Python scripts must use `ssl.CERT_NONE`.
- Dashboard `id` response field is NOT the UID — always use the UID form `/d/{uid}/{slug}` for links.

### L. Data Source Schema Verification (CRITICAL for monitoring/dashboard plans)

When a plan constructs queries against a database (InfluxDB, Prometheus, SQL, etc.), every measurement name, field key, tag name, metric name, and label referenced in the plan MUST be extracted from a **working, verifiable artifact** — never fabricated from assumptions or naming conventions.

**Why:** The Grafana dashboard redesign plan fabricated InfluxDB measurement names (`"WAN_in"`, `"cpu"`, `"heart_rate"`) based on what "made sense" rather than extracting the actual names from the archived working dashboards. It also used `job="zfs"` in Prometheus filesystem queries, not realizing `node_filesystem_*` metrics come from job `nodes`. Result: 5 of 8 dashboards showed "No data" on every panel. The plan author could have prevented this by extracting query patterns from existing artifacts.

**Rules:**

1. **Every query in a plan MUST cite its source.** For each distinct query pattern the plan uses, include a "Source:" annotation pointing to the existing artifact (file path + line or panel name) that proves the query works. Example:

   ```
   -- Blood Pressure (InfluxQL)
   SELECT last("value") FROM "mmHg" WHERE ("entity_id"::tag = 'switchbot_bluetooth_proxy_ua_651ble_systolic') AND $timeFilter
   -- Source: UA-651BLE_Blood_Pressure.json, panel "Heart Tracking", target A
   ```

2. **Measurement/metric names must be extractable from the cited source.** The plan reviewer must be able to open the cited file and find the exact same name. If the cited source uses a different name, the plan is WRONG.

3. **For Prometheus metrics, verify the metric EXISTS before using it.** Run a query against the live Prometheus and include the result count. Example:

   ```
   ## Verified metrics (2026-06-05 via curl to 192.168.99.33:9191)
   node_zfs_zpool_state  → 77 results  ✅
   node_zfs_zpool_fragmentation  → 0 results  ❌ DOES NOT EXIST — must use alternative
   node_filesystem_size_bytes{fstype="zfs"}  → returns data under job="nodes" (NOT job="zfs")
   ```

4. **For InfluxDB measurements, verify they exist in the target database.** If direct database access is unavailable, extract measurement names from a working Grafana dashboard's panel targets. The archived dashboard JSON is the authoritative source — not guesses, not conventions, not "it probably uses this name."

5. **Label / tag / field name assumptions are the most common source of silent failures.** A PromQL query with a wrong label filter returns empty results with no error. An InfluxQL query against a nonexistent measurement returns empty rows. Plans MUST tag every label, tag, and field filter with its source.

**Litmus test:** Can you point to a concrete line in an existing artifact (dashboard JSON, source code, database schema dump) that proves the query will work? If not, the query is ASSUMED — and dashboards built on assumed queries will show "No data."

### M. M3-Specific Failure Modes (Plan Authors Must Defend Against These)

The following are confirmed for MiniMax M3 (documented post-release, June 2026). Plan tasks must explicitly defend against them.

**M3-1: Parallel Tool Call Misattribution** (GitHub MiniMax-M3 issue #1)

M3 swaps results across parallel tool calls by positional/arrival order rather than `tool_call_id`. The failure is silent — M3 produces internally consistent but factually wrong output. Affects any flow where M3 dispatches multiple tool calls in one turn.

*Plan defense:* Never design tasks requiring M3 to dispatch parallel tool calls and reason about their combined results. Sequence dependent operations explicitly (Step 1, Step 2...). Add to CONSTRAINTS: "Do not parallelize tool calls — process each target sequentially."

**M3-2: Reasoning Spiral (Inference Collapse)**

M3 can enter an infinite self-revision loop: it recognizes a solution as suboptimal, revises it, finds a different flaw in the revision, revises again, and repeats without converging. It will NOT self-report being stuck. Distinct from creative drift (adding unrequested features) — this is failing to finish improving a solution.

*Plan defense:* Every multi-step task needs an explicit convergence checkpoint. Use: "Stop after the first working solution. Do not optimize further. Surface what you produced." For Tier 2/3 discovery, the restatement gate is the convergence checkpoint — M3 produces the Discovery Summary and stops.

**M3-3: High Latency / Timeout Sensitivity**

Time-to-first-token can reach 8+ minutes for complex tasks. Agent loops with short timeouts cancel M3 mid-reasoning with no output.

*Plan defense:* Do not specify short timeouts for complex reasoning tasks. Set agent loop timeouts to 15+ minutes for Tier 2/3 tasks. Document expected latency for long-running tasks.

**M3-4: Tool Call Payload Corruption**

Approximately 1 in 3 tool calls may fail in some environments with malformed hash prefixes, dropped arguments, or silent no-ops where M3 acts as if a tool succeeded when it did not.

*Plan defense:* Verification steps are NOT optional. Every tool-executed step MUST have a machine-verifiable outcome (file exists, service responds, row count matches). "Command exited 0" alone is insufficient. Add: "Verify the output of this step before proceeding — do not assume tool success from exit code alone."

**M3-5: Interleaved Thinking State Loss**

M3's chain-of-thought must be preserved in conversation history across turns (`reasoning_split=True`, full `response_message` appended). If the calling agent strips thinking content, M3 loses reasoning context and performance degrades on subsequent turns.

*Plan defense:* When using M3 via API in a multi-turn agent loop, ensure `reasoning_split=True` and the full `response_message` (including thinking content) is preserved in history. Do NOT strip thinking tokens from conversation context. Cursor-based execution handles this automatically; external orchestration must account for it explicitly.

---

## 13.N. Production Image Verification (MANDATORY for containerized projects)

**Principle:** A plan's deliverable is not "tests pass locally." It is "the deployment target runs correctly after this commit." Test-only diffs still enter the commit history and are the basis for the next image build. If the next build would fail or misbehave, that is a regression — regardless of whether `src/` changed.

**Rule:** Every plan for a project that has a `Dockerfile` or deployment target (container registry, systemd unit, remote service) MUST include a final task — or an explicit final sub-task of the last task — that:

1. Builds the container image from the current working tree
2. Pushes to the registry with the next version tag
3. Deploys to the target host (pull + restart)
4. Runs the project's canonical E2E verification against the deployed container (e.g., `docker exec container python3 scripts/verify_bogo.py`)
5. Confirms the container healthcheck passes post-deploy

**Version tagging:** Every commit that changes the repo — including test-only changes — gets a version bump. The version tag tracks the commit state, not the nature of the change. `v0.12` → `v0.13` (or `v0.12.1` for minor bumps) is correct even when `src/` is byte-identical.

**Banned constraint:** The phrase "test changes only, no redeploy" MUST NOT appear in a plan's OUT OF SCOPE section for containerized projects. The correct framing is: *"Production code unchanged; image rebuilt to verify integration and bump the registry to this commit."*

**Why this matters:** The deployment consumer (e.g., moltis, docker-compose on the target host) picks up whatever image is current. A plan that completes without rebuilding and verifying the image leaves an unvalidated gap between the repo state and the deployment state. Even if tests pass locally, the image on the registry is stale relative to the commit — and the next agent or operator to rebuild will get a different image than the one tests were run against.

**Exemptions (plan must state explicitly if claiming one):**

- The project has no `Dockerfile` and is not deployed as a container or service (e.g., pure library, scripts run locally).
- The plan is a documentation-only change with no code, config, or test modifications.

If neither exemption applies, the production image verification task is mandatory. Plan authors MUST include it. Executing agents MUST NOT skip it even if the plan omits it — surface the gap to the user and add the task before declaring the plan complete.

**Example final task structure for a containerized project:**

```
### TASK N: Build, deploy, and verify v0.13

INTENT: Prove the repo state after this plan's changes produces a working container on the deployment target.

STRUCTURE:
  1. docker build --platform linux/amd64 -t <registry>/image:0.13 .
  2. docker tag <registry>/image:0.13 <registry>/image:latest
  3. docker push <registry>/image:0.13 && docker push <registry>/image:latest
  4. ssh <host> "cd <compose_dir> && docker compose pull && docker compose up -d"
  5. ssh <host> "docker exec <container> python3 scripts/verify_bogo.py"
  6. ssh <host> "docker inspect --format='{{.State.Health.Status}}' <container>" → must return "healthy"

VERIFICATION:
  - docker images shows 0.13 locally
  - docker manifest inspect <registry>/image:0.13 confirms push succeeded
  - verify_bogo.py exits 0 against the deployed container
  - healthcheck returns "healthy"
  - Devlog entry updated with verbatim output of steps 5 and 6

ACCESS PREREQUISITES:
  - ssh <host> reachable
  - registry push credentials valid
  - <compose_dir>/docker-compose.yml references the correct image tag
```

---

## 13.O. Mandatory Functional Testing Task (MCP tools, APIs, services)

**Every plan that adds or modifies an MCP tool, API endpoint, CLI subcommand, or any other production-facing entrypoint MUST include a dedicated functional testing task that exercises the production entrypoint against a live or production-equivalent system.** Registration checks, import tests, and unit tests prove plumbing — they do not prove the feature works.

### Rules

1. **Separate task.** Functional testing is its own task (or a numbered sub-step of the deploy task). It is NOT a throwaway subsection of a build or implementation task.
2. **Same code path.** The test MUST exercise the production entrypoint using the same protocol and initialization path as production:
   - MCP tool → send JSON-RPC over stdio or HTTP, parse response
   - CLI subcommand → run via `docker exec` or shell, parse stdout
   - API endpoint → send HTTP request, assert status + body
   - Direct `asyncio.run(tool_func())` is acceptable if the production tool is an async function, but the validator must understand that only the JSON-RPC framing is skipped (the function body is identical).
3. **Never verify by module introspection alone.** Checking `mcp._tool_manager._tools` or `import` success proves the tool is registered. It does NOT prove:
   - The tool's function body returns correct data against live state
   - The tool handles missing resources (project, task) gracefully
   - The tool's error path (try/except, JSON error response) works correctly
4. **Live data preferred.** Test against the live system when accessible. Mock data is acceptable only when live access is genuinely blocked (auth, network, credentials).
5. **Machine-verifiable.** Every assertion must produce unambiguous PASS/FAIL output with exit code 0 on success. Do not use subjective criteria ("looks correct").
6. **Test both happy path and error path.** If the tool returns a JSON error for a missing resource, verify that path too. One test is not enough.

### Anti-patterns (do not accept in a plan)

| Anti-pattern | Why it fails |
|--------------|-------------|
| `python -c "from server import mcp; assert 'my_tool' in [t.name for t in mcp._tool_manager._tools.values()]"` | Proves the function is decorated with `@mcp.tool()`. Does not execute the function. Does not prove it works against live data. |
| `python -c "import my_module; print('OK')"` | Proves no import-time crash. Says nothing about runtime behavior. |
| Marking a tool "verified" after only checking its source code compiles (e.g., `python -c "import ast; ast.parse(...)"`) | Syntax trees have no relationship to runtime correctness. |
| `echo "all tests passed"` without machine-assertable checks | Prose is not verification. M3-4 (tool call payload corruption) makes this particularly dangerous — a no-op tool call with fake "all tests passed" output is a known failure mode. |

### Template

```
### TASK N: Functional test the <tool_name> tool

INTENT: Prove the <tool_name> MCP tool returns correct output when
invoked against the live Vikunja/API system. Both happy path and
error path are tested.

STRUCTURE:
  1. Ensure the container/process is running with production config.
  2. Create a test resource (e.g., add a task with known attributes).
  3. Invoke the tool via production protocol (or direct async call
     if JSON-RPC framing is not possible).
  4. Assert the output JSON has the expected structure and values.
  5. Test the error path: invoke with a missing resource, assert
     the JSON error response.
  6. Clean up the test resource.
  7. Print PASS/FAIL with exit code.

VERIFICATION:
  Command: python -c "import asyncio; ... asyncio.run(invoke_tool())"
  PASS: all assertions pass, exit code 0
  FAIL: any assertion fails
  BLOCKED: live system unreachable

Devlog entry appended with verbatim verification output.
```

### Litmus test

If someone asks "does the plan prove the tool actually works against the real system?" and the answer is "it checks that the tool is in the registry" — the functional testing task is insufficient. The answer must be "it invoked the tool and asserted the output."

---

## 14. Quick Reference Checklist

Before submitting a plan for M3 execution, verify:

**Pre-Plan Interrogation (Section 0)**
- [ ] Tier classified (Tier 1 / Tier 2 / Tier 3) before discovery began
- [ ] **Tier 1:** All 7 interview question categories addressed or explicitly deferred (scope, users, data, edge cases, integrations, acceptance criteria, unstated constraints)
- [ ] **Tier 2/3:** Domain-specific Decision Records generated by AI (Issue pre-seeded with trade-offs, not generic categories)
- [ ] **Tier 2/3:** Every DR has a resolved Decision and explicit Assumptions; no open DRs gate any task
- [ ] **Tier 2/3:** Discovery Summary (2-3 paragraphs: what/scope/success criteria) produced and confirmed
- [ ] **Tier 3 only:** Architecture Summary (end state, integration points, data flows, DR dependency graph) produced and confirmed before task authoring
- [ ] Restatement gate confirmed by user before plan authoring began
- [ ] No tasks added beyond the confirmed restatement scope
- [ ] **Tier 2/3:** DECISION RECORDS section present in plan file with all resolved DRs
- [ ] **Tier 2/3:** Each task shaped by a DR references it explicitly in CONSTRAINTS (e.g., "Per DR-3: use grafana read-only user")

**Stop Rules (Section 8.5)**
- [ ] Stop rules included in plan preamble or per-task CONSTRAINTS where over-working or scope creep risk is high
- [ ] Multi-step agent tasks have a turn limit and same-tool repetition limit

- [ ] OBJECTIVE section present and clear
- [ ] ACCESS & CREDENTIAL PREREQUISITES table present (if plan touches remote systems); every target marked ✅ VERIFIED (with command+output) or ❌ ASSUMED
- [ ] PROJECT CONTEXT lists language, libraries, workflow
- [ ] KEY FILES table maps all referenced paths
- [ ] Each task has: INTENT, STRUCTURE, CONTEXT, CONSTRAINTS, DON'T, VERIFICATION
- [ ] Deployment tasks have ACCESS PREREQUISITES subsection with reachability gate as STEP 1
- [ ] Each task touches only ONE pipeline layer
- [ ] Tasks are explicitly ordered
- [ ] Naming is specified for all new files/functions/variables
- [ ] No contradictions between tasks
- [ ] Total plan fits within ~200K tokens (leaving room for code reading + output; relaxed from 100K for M3's 1M window)
- [ ] Approximate vs exact values are marked; verification claims marked with provenance (✅ VERIFIED / ❌ ASSUMED / ⚠️ STALE)
- [ ] Credentials cite source devlog; ASSUMED credentials flagged for agent testing
- [ ] Review/validation tasks use concrete item checklists (not open-ended "check all")
- [ ] Review/validation tasks specify a required output format (classification table)
- [ ] Cleanup/deletion tasks enumerate files or use discovery commands (not "directory should be empty")
- [ ] Later phases include non-regression constraints referencing earlier phase outcomes
- [ ] Verification tasks define PASS/FAIL/BLOCKED with concrete commands (not subjective observations)
- [ ] If plan creates a new moltis skill: includes task to update moltis/SKILLS_CATALOG.md with new skill name + one-line description
- [ ] Update tasks use `rg -l` discovery instead of hardcoded file lists
- [ ] Verification commands match the plan exactly (no `grep` substitution for `rg`, no shell glob instead of `--glob`)
- [ ] Every database query in the plan cites its source (archived dashboard panel, live Prometheus query result, schema dump) — per Section 13.L
- [ ] Measurement/metric names in queries are extracted from working artifacts, not fabricated — per Section 13.L
- [ ] No conditional decision branches ("if X delete, if Y extract") -- all outcomes pre-decided by the plan author
- [ ] Inter-task data dependencies use concrete expected values from source material, with a stop rule if live data differs (not placeholders or "may differ" hedges)
- [ ] When the plan intentionally diverges from a source document's recommendation, the divergence is flagged in the task's CONTEXT section with rationale
- [ ] diff-based review tasks specify an explicit git baseline SHA or ref (not `HEAD`)
- [ ] For diagnostic/investigation plans: test methodology matches production behavior (persistent connections, same client init paths, same transport lifecycle)
- [ ] For diagnostic/investigation plans: plan includes a sanity-check step comparing test output to KNOWN BEHAVIOR before analysis proceeds
- [ ] For diagnostic/investigation plans: devlog requirements are enumerated as a checklist so the agent can verify each item
- [ ] For diagnostic/investigation plans: complex shell commands (2+ quoting levels) are provided as script files, not inline shell
- [ ] For diagnostic/investigation plans: cleanup steps for temp files and external system test data are explicit numbered actions
- [ ] Devlog: plan specifies devlog filename; devlog written to `agent_planning/execution/<project_name>/devlogs/` with `{descriptive_name}_{YYYY-MM-DD}.md` naming; created after first task, updated after each subsequent task (Section 9)
- [ ] Devlog: EVERY task's VERIFICATION section ends with an explicit DEVLOG update step (not just a global instruction at the bottom of the plan)
- [ ] Devlog verification integrity: VERIFICATION sections include instruction to copy-paste exact command output (no `...` abbreviation) (Section 9, Verification Integrity Rule)
- [ ] Context window: plan is sized for M3's 1M window; phased splitting is only required if total session tokens would exceed ~800K (not default for most plans)
- [ ] Batch-task safety: no single task generates >200 lines of output; tasks generating large JSON/configs are split into sub-tasks (Section 5, Batch-task risk)
- [ ] Multimodal: if visual references would reduce ambiguity in CONTEXT sections, image paths are included with descriptive labels (Section 15)
- [ ] Reconstruction: Every script deployed to a server has a copy saved in the repo (Section 9, Reconstruction Completeness)
- [ ] Reconstruction: Devlog includes full content of small files (<100 lines) or repo references for larger files
- [ ] Reconstruction: Notes file has a dedicated section with architecture, ports, alert rules, and redeployment steps
- [ ] Reconstruction: Plan + devlog + notes + repo scripts are sufficient to rebuild the entire solution without server access
- [ ] Dependency verification: existing infrastructure on ALL hosts touched by the plan is documented in PROJECT CONTEXT with source citations (not just the target system)
- [ ] Tool versions: every external tool the plan configures has a VERIFIED version string in PROJECT CONTEXT (not assumed, not "latest")
- [ ] Behavioral verification: for each tool configuration pattern, an existing working example is cited from the same host in PROJECT CONTEXT
- [ ] Overlay FS: tasks that modify container config files use stop-MergedDir-start pattern (not `docker cp` or `sed -i` on running containers)
- [ ] Config reload: tasks specify SIGHUP vs restart based on change type (`__address__` relabel = restart; rule files = SIGHUP)
- [ ] Multi-module: scrape jobs using blackbox_exporter use exactly ONE module per job; never combine modules in `params`
- [ ] Pre-deployment access verification: every exporter/scraper deployment task has STEP 1 as ping+port+credential test; unreachable = BLOCKED (Section 13.I)
- [ ] Grafana API: all dashboard create/update tasks show `folderUid` at payload top level (not inside `dashboard`); verification confirms target folder, not just existence (Section 13.K)
- [ ] Deviation propagation: deployment plans include a task or sub-step to write Adaptation Notes table to the project README
- [ ] Home lab documentation: plans deploying services/VMs/ports/DNS include a task updating `~/git_projects/home-lab/SERVICE-MAPPING.md` (or HARDWARE.md, STORAGE.md, AUTOMATIONS.md as applicable) with the actual deployed state (Section 9.5, Home Lab Documentation Update)
- [ ] Knowledge base update: any plan task that touches a KB-covered system (service/VM/host/network/storage/automation/pipeline/MCP/skill) includes a task updating the matching `knowledge/<category>/<doc>.md`, bumping `updated:`, advancing `confidence:` if verified, and recording verification evidence in the affected doc or relevant devlog — the KB update is mandatory for any agent action, not only new deployments (Section 9.6, Knowledge Base Update)
- [ ] Production image verification: plan includes a final task that builds, pushes, deploys, and runs E2E against the deployment target — even for test-only plans with no `src/` changes (Section 13.N)
- [ ] No plan for a containerized project uses "test changes only, no redeploy" as a scope constraint; if production code is unchanged, reframe as "image rebuilt to verify integration" (Section 13.N)
- [ ] If claiming an exemption from Section 13.N (no Dockerfile, or documentation-only change), the plan's SCOPE BOUNDARIES section states the exemption explicitly
- [ ] Functional testing (Section 13.O): If the plan adds or modifies an MCP tool, API endpoint, CLI subcommand, or production-facing entrypoint, it includes a dedicated functional testing task that invokes the entrypoint and asserts its output — not just checks registration or imports
- [ ] Functional testing (Section 13.O): The plan's verification for any new tool/endpoint/command tests the error path (missing resource, auth failure) as well as the happy path
- [ ] Functional testing (Section 13.O): The plan's verification does NOT use module introspection (`_tool_manager._tools`), `import` success, or syntax parsing as the sole proof that a tool works — it invokes the production code path and asserts the output

---

## 15. Multimodal Context (M3 Only)

M3 natively accepts image and video inputs. Plans may reference visual artifacts as context where it reduces ambiguity:

- **UI/design references:** Instead of describing a target layout in prose, include the image path in the CONTEXT section. M3 will read the image directly rather than relying on text description.
- **Schema diagrams:** ER diagrams or architecture diagrams can be passed as context instead of or alongside prose descriptions.
- **Format:** Reference image paths in CONTEXT as:
  `[IMAGE: ./docs/design/target_layout.png -- reference for component structure in Task 3]`
- **Constraint:** Image context does not replace explicit STRUCTURE and SCHEMA sections -- still enumerate all field names, types, and file paths in text. Images are supplementary context, not a substitute for precise specification.

---

## 16. Execution Addendum (M3-Specific)

For session management, external memory artifacts, state writeback, and chunked execution, follow `agent_planning/EXECUTION_PROTOCOL.md`. The following constraints are M3-specific:

**Context window sizing:** M3's 512K guaranteed minimum context window means 3–5 tasks per session are safe without window pressure. Restart sessions after 5 tasks or after ~200K tokens of accumulated tool output, whichever comes first.

**Stop-and-write rule:** M3 will continue executing if not explicitly told to stop. Every plan task MUST end with a writeback step (see EXECUTION_PROTOCOL.md Section 4). After writeback, the agent MUST stop and report completion of that task before proceeding to the next one.

**Parallel tool call guard:** M3 emits parallel tool calls for sequential operations. Any task that reads a file, then edits it based on the read, MUST explicitly state: "Read first, await result, then edit. Do not parallelize read and edit." This must appear in the task's CONSTRAINTS section.
