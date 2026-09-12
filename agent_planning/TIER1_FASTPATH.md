# Tier 1 Fast Path

Use this instead of the full `PLAN_CORE.md` section 0 flow **only when ALL of the following are true:**

- Single system or single file — no remote deployment, no multi-host coordination
- Fewer than 5 tasks
- No irrevocable decisions (no data-at-risk operations, no migrations, no auth changes)
- No domain-specific risk that an addendum would catch (no containers, no live services, no flows)

If any condition is not met, fall back to `PLAN_CORE.md` and classify the tier there.

---

## Step 1 — Quick Interview (7 categories)

Address each category briefly or mark it "not applicable." Do not skip any.

| # | Category | What to extract |
|---|----------|-----------------|
| 1 | **Scope** | What is IN. What is explicitly OUT. |
| 2 | **Actor** | Who uses the output and with what permissions. |
| 3 | **Data shape** | Inputs, outputs, formats. |
| 4 | **Edge cases** | What happens when input is missing, wrong, or empty. |
| 5 | **Integration points** | What existing files, services, or systems does this touch. |
| 6 | **Acceptance criteria** | Concrete pass/fail: how do you know it worked. |
| 7 | **Unstated constraints** | Conventions, style rules, things the user considers obvious. |

---

## Step 2 — Restatement Gate

Before writing any task, produce:

> **What I understand:** [2–3 sentences: what the plan achieves, what it will NOT do, how success is measured.]
>
> **Does this match your intent?**

Do not write tasks until this is confirmed.

---

## Step 3 — Minimal Task Template

Each task needs only these four sections for Tier 1:

```
### Task N: <Name>

INTENT:
Why this task exists and what problem it solves.

STRUCTURE:
- File paths
- Function/method signatures or class names
- Output file names

CONSTRAINTS:
- Which files to modify (and which NOT to)
- Patterns to follow
- No new packages unless specified

DON'T:
- Don't create files not listed in STRUCTURE
- Don't modify files outside the scope above
- Don't add features not specified

VERIFICATION:
<concrete command or check>
PASS: <expected output>
FAIL: <failure condition>
```

---

## What you skip at Tier 1

- Decision Records (DRs) — not needed for small, reversible tasks
- Domain addendum — skip unless the task touches a domain with real risk (see below)
- Model addendum — skip unless you need to tune reasoning effort or context budget
- EXECUTION_PROTOCOL.md artifacts (SESSION_BRIEF, HANDOFF, TASK_QUEUE) — only required for Tier 2/3 plans

**When to pull in the domain addendum anyway (even for Tier 1):**

| Situation | Pull in |
|-----------|---------|
| Task modifies a live Node-RED flow or HA config | `addenda/automation.md` AU1 (backup rule) |
| Task deploys anything to a remote host | `addenda/infrastructure.md` A3/A9 (access gates) |
| Task touches a codebase with existing behavioral specs | `addenda/software.md` S2 |
| Task runs a pipeline stage that produces media/data files | `addenda/pipeline.md` P2 (idempotency) |
