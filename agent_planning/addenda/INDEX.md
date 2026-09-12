# Plan Addenda Index

_Last updated: 2026-07-28_

After reading `PLAN_CORE.md`, select ONE addendum based on your project's primary domain. Read it in full before authoring any tasks.

**Rule:** If the project spans two domains, pick the one that carries **higher risk**. If the prompt explicitly names an addendum, use that override.

**Default fallback:** `infrastructure` (highest ceremony = safest fallback when uncertain).

---

## Addendum Selection Table

| Addendum | File | Trigger signals | Use when... |
|----------|------|-----------------|-------------|
| **software** | `addenda/software.md` | Go, Python, TypeScript code; MCP servers; CLI tools; tests; refactors; libraries | The primary artifact is application code with behavioral logic — functions, types, interfaces, test suites |
| **infrastructure** | `addenda/infrastructure.md` | SSH, deploy, docker, compose, Ansible, containers, monitoring, DNS, storage, ZFS, VMs, Prometheus, Grafana | The primary artifact is a deployed config or service running on a remote host |
| **automation** | `addenda/automation.md` | Node-RED, Home Assistant, ESPHome, Lovelace, MQTT, flows, HA entities, Node-RED function nodes | The primary artifact is an HA/Node-RED flow, entity config, or automation logic |
| **pipeline** | `addenda/pipeline.md` | EPUB, TTS, Whisper, transcription, audio, media batch, scraping, ETL, data export | The primary artifact is transformed content flowing through processing stages |
| **creative** | `addenda/creative.md` | Blog posts, technical articles, documentation narratives, editorial rewrites, README prose, release notes, presentation scripts | The primary artifact is written content — reduced ceremony, simplified interview |
| **code-quality** | `addenda/code-quality.md` | (cross-cutting — read alongside domain addendum) | ANY plan that produces executable code. Required for software/pipeline (always), automation (function nodes), infrastructure (scripts/playbooks). Exempt: creative, pure config-only infra. |

---

### Code-Quality Addendum — When to Read

The `code-quality` addendum is cross-cutting — it applies alongside the domain addendum, not instead of it. Read it when:

| Domain addendum | Read code-quality? | Condition |
|-----------------|-------------------|-----------|
| software | ALWAYS | All software plans produce code |
| pipeline | ALWAYS | All pipeline plans produce code with behavioral logic |
| automation | Conditional | Only when the plan adds/modifies Node-RED function nodes (JavaScript) |
| infrastructure | Conditional | Only when the plan produces executable scripts, Ansible playbooks, or Dockerfiles. Pure config-only plans (adding a scrape target, changing a dashboard) are exempt. |
| creative | NEVER | Narrative content is exempt |

**Rule:** When in doubt, read it. The cost of reading an addendum you don't need is lower than discovering at code review that you should have.

---

## Disambiguation Guidance

**Borderline cases:**

| Scenario | Pick |
|----------|------|
| Python script that deploys a container | infrastructure (deployment is the primary risk) |
| Go CLI tool with `docker build` in its task list | software (application code is the artifact; container build is a verification step) |
| MCP server that calls remote APIs | software (behavioral contracts and interface testing matter most) |
| Ansible playbook that configures a service | infrastructure |
| Python `pihole-reconciler.py` script | software (the script has behavioral logic: reconciliation rules, idempotency) |
| Node-RED flow with a Python diagnostic script | automation (the flow is the primary artifact) |
| EPUB → TTS pipeline with a Go CLI wrapper | pipeline (content transformation is the primary concern) |
| Writing a technical blog post or README | creative (written content, not data transformation) |
| Rewriting product documentation with style constraints | creative (voice/tone preservation is the primary concern) |

**When a software project also deploys a container** (e.g., an MCP server that ships as a Docker image), use the **software** addendum AND include the production image verification task defined in `addenda/infrastructure.md §13.N`. You do not need to read the full infrastructure addendum — copy the 13.N task template only.

---

## OpenSpec Support

OpenSpec (`agent_planning/openspec/` inside the agent_planning directory) provides living behavioral specs that
accumulate across plans. Each addendum defines its own integration:

| Addendum | Supports OpenSpec | Instructions |
|----------|-------------------|--------------|
| software | Yes | `addenda/software.md §S1` — lifecycle + auto-generation on missing specs |
| pipeline | Yes | `addenda/pipeline.md §P9` — lifecycle + auto-generation on missing specs |
| infrastructure | No | Specs do not apply to procedural playbook concerns |
| automation | No | Specs do not apply to flow/entity DSL concerns |

When the selected addendum supports OpenSpec, the planner MUST check for specs
as part of the pre-DR discovery phase — see the addendum's spec section for the
exact procedure.

---

## Discovery Commands

```bash
# Confirm the right addendum exists
ls agent_planning/addenda/

# Check if specs already exist for your codebase (software and pipeline only)
ls agent_planning/openspec/specs/ 2>/dev/null || echo "No specs yet"
```

---

## Updating This Index

If a new addendum is added, append a row to the selection table and add a disambiguation example.
