# Plan Addendum — Ponytail (Agent Minimalism Plugin)

_Last updated: 2026-09-12_

Applies to: every plan authored or executed in an environment where the OpenCode
`@dietrichgebert/ponytail` plugin is active (installed via
`~/.config/opencode/opencode.json` → `"plugin": ["@dietrichgebert/ponytail"]`).

Read this after `PLAN_CORE.md`. All rules here are **ADDITIVE** and, where they
intersect, **override** Ponytail's YAGNI ruleset. This addendum is cross-cutting
like `addenda/code-quality.md`: read it alongside the domain addendum, not
instead of it.

---

## PT1. What Ponytail Is (and what it is not)

Ponytail injects a "laziest senior dev" YAGNI ruleset into the system prompt of
every OpenCode chat — including every subagent — via the plugin hook
`experimental.chat.system.transform` (source:
`.opencode/plugins/ponytail.mjs` upstream). Its decision ladder is:

```
1. Does this need to exist?   → no: skip it (YAGNI)
2. Already in this codebase?  → reuse it, don't rewrite
3. Stdlib does it?            → use it
4. Native platform feature?   → use it
5. Installed dependency?      → use it
6. One line?                  → one line
7. Only then: the minimum that works
```

Active level is set with `/ponytail [lite|full|ultra|off]`. Default is `full`.
Level persists to `~/.config/opencode/.ponytail-active` (or
`$XDG_CONFIG_HOME/opencode/.ponytail-active`).

**Ponytail is an accelerator, not the source of truth. This framework is the
source of truth.** Ponytail MUST NOT be treated as a required dependency of the
planning protocol: it is a third-party npm package, its ruleset text can change
between versions, and a plan must remain executable and correct with the plugin
absent. Do not encode plan steps that assume Ponytail is installed.

**Where it genuinely complements this framework:** rung 2 ("reuse, don't
rewrite") reinforces KB consultation and the DON'T rule against new
abstractions; rung 7 reduces bloat in plan STRUCTURE/EXAMPLES sections and in
`execution/<project>/artifacts/` code. At `lite`/`full` those are wins. The
conflict is at `ultra` and when rung 1 is applied to protocol-mandated work.

---

## PT2. Rung 0 — Protocol MUSTs Outrank YAGNI (MANDATORY)

When Ponytail's ladder and a framework `MUST` disagree, **the framework's MUST
wins.** The following are **rung 0** and are never subject to "does this need to
exist? → skip it":

- Plan structure sections required by `PLAN_CORE.md §1` — OBJECTIVE,
  `project_name`, DECISION RECORDS, ACCESS & CREDENTIAL PREREQUISITES,
  PROJECT CONTEXT, KEY FILES REFERENCE, OPERATING MODEL (multi-repo), TASKS.
- Per-task sections required by `PLAN_CORE.md §2` — INTENT, STRUCTURE, CONTEXT,
  CONSTRAINTS, DON'T, VERIFICATION, DEVLOG.
- The **Restatement Gate** (`PLAN_CORE.md §0`), tier classification, and the
  no-conditional-branches rule.
- Cross-cutting rules **R1–R14** (`PLAN_CORE.md §2`; R7 is the Tier 2/3 plan-validation dispatch, §8.7).
- **KB writeback** (`AGENTS.md` — commit in the same session), and the
  `EXECUTION_PROTOCOL.md §1.5` persistence rule (artifacts in the project tree,
  never `/tmp`).
- `EXECUTION_PROTOCOL.md` writeback (TASK_QUEUE / SESSION_BRIEF / HANDOFF /
  devlog) after every task, the §5.1 quality gate, the §8 deviation log, and the
  §9 code-review gate.
- Security-scanning protocol gates (`agent_security_scanning/AGENTS.md`,
  scope register, operator-in-the-loop).
- `DOC UPDATE` tasks (`PLAN_CORE.md §2`) and provenance marking of every command
  (`# Command Fidelity`, `PLAN_CORE.md §6`).

**Rationale:** rung 1 answers "does the *code* need to exist?" The items above
are not code — they are the audit trail, safety gates, and recovery surface that
make plan-driven work resumable and correct. An agent that skips a devlog or a
backup because "it's extra" has silently broken the recovery contract that
`EXECUTION_PROTOCOL.md` exists to uphold.

**Executor duty:** if you find yourself about to omit a rung-0 item because
Ponytail's ruleset argues it is unnecessary, that is a **`[SCOPE-GAP]`
deviation** — log it in the devlog and HANDOFF, and perform the rung-0 item
anyway. Do not resolve the conflict by dropping the framework requirement.

---

## PT3. Mode Discipline for Planning and Execution

Recommended environment settings for framework work:

| Setting | Value | Why |
|---------|-------|-----|
| `PONYTAIL_DEFAULT_MODE` | `full` | Minimalism without stripping safety prose; `lite` is acceptable for pure-authoring sessions |
| `/ponytail ultra` | **forbidden during planning and plan execution** | `ultra` is tuned for narrow, single-artifact implementation and will aggressively argue against protocol ceremony |
| `PONYTAIL_SUBAGENT_MATCHER` | **unset** (default) | Planning/review subagents (`explore`, `general`) should also receive the minimalism ruleset, subject to PT2 |

**Rule:** a planning session (Tier 2/3 authoring) and an execution session
(Tier 1 fastpath excepted) MUST run at `full` or `lite`. If the operator has set
`ultra`, the agent should note it in the session's first devlog entry and still
apply PT2 rung 0. `ultra` remains appropriate for standalone implementation
tasks that touch a single artifact outside a plan.

**Do not** set the environment globally to `off` as a workaround — that discards
the legitimate rung 2 / rung 7 wins. Carve out rung 0 instead.

---

## PT4. Verifying Plugin State Before Assuming Behavior

An executor may consult the active level before deciding how much minimalism
leaning to expect:

```bash
# opencode plugin state (mode persists here)
cat "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/.ponytail-active" 2>/dev/null \
  || echo "unset (plugin default: full)"

# plugin registration
jq -r '.plugin[]?' "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" 2>/dev/null
```

A missing state file means the plugin default (`full`) is in effect when the
plugin is registered. **Absence of the plugin entirely is a supported state** —
proceed with the normal framework and do not add Ponytail-specific steps.

---

## PT5. Ponytail Checklist (extends PLAN_CORE §12)

In addition to the universal checklist and the **R1–R14** expectations
(`PLAN_CORE.md §2`; R7 is the Tier 2/3 plan-validation dispatch, §8.7), verify:

- [ ] No plan task instructs the executor to omit a rung-0 item (PT2) on the
      grounds that it is unnecessary — plan structure, devlog, persistence,
      KB writeback, quality gate, or security gates
- [ ] Plan does not assume the Ponytail plugin is installed or required
- [ ] Execution guidance (if present) states `full`/`lite` mode and forbids
      `ultra` for planning/execution sessions
- [ ] Any observed conflict between the Ponytail ruleset and a framework MUST is
      recorded as a `[SCOPE-GAP]` deviation per `EXECUTION_PROTOCOL.md §8`

---

## PT6. Installation Reference (operator action — not a plan task)

The plugin is an operator-owned OpenCode setting, not a plan deliverable:

```json
{
  "plugin": ["@dietrichgebert/ponytail"]
}
```

in `~/.config/opencode/opencode.json`. Slash commands registered by the plugin:
`/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`,
`/ponytail-gain`, `/ponytail-help`. Plans MUST NOT add tasks that install,
upgrade, or configure this plugin unless the plan's explicit objective is
managing the operator's OpenCode environment.
