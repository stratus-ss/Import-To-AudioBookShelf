# Plan Addendum — Web / Browser-Rendered UI

Applies to: ANY plan that adds or modifies a browser-rendered surface. This
addendum is cross-cutting — read it alongside the domain addendum, not instead
of it.

Read this after `PLAN_CORE.md` and your domain addendum. All rules here are ADDITIVE.

This addendum is the canonical home for the **Playwright functional-test
requirement** for web UI work (rule **R14** in `PLAN_CORE.md §2`). It closes the
gap that let a UI change ship with only module-level tests and a pending operator
browser checklist (precedent: the `dnd_soundboard_phase2` devlog's
"the agent cannot drive a browser" note). The `S5` rule in `addenda/software.md`
and the `A12` rule in `addenda/infrastructure.md` require a functional-testing
task for production-facing entrypoints; this addendum states what that task MUST
be when the entrypoint is a browser UI.

It closes a second gap: a Playwright pass the **authoring agent runs itself**.
The author already believes the feature works, and will adjust the test until it
agrees with them. The pass is therefore a **clean-context subagent dispatch on a
pinned, cross-model** (`EXECUTION_PROTOCOL.md §9.0`, W2.1/W2.2) — the same
property the Code Review task has carried since the silent-inheritance fix.

---

## W1. When this addendum applies

A plan is **web-related** when it adds or modifies anything a browser renders or
a user drives through a browser:

- Front-end source that runs in a browser context: `.html`, `.css`, `.js`, `.ts`,
  `.jsx`, `.tsx`, `.vue`, `.svelte`.
- A served SPA or static bundle: paths under `web/`, `static/`, `public/`,
  `dist/`, or an `index.html` served by the app.
- A dashboard/UI surface: a Lovelace card, a Grafana panel backed by authored UI
  code, or any UI whose behaviour is only observable through the DOM.

**Not web-related** (no Playwright task; record `Playwright: N/A — <reason>` in
the preamble): a pure API/JSON contract change with no UI delta, a
backend/build/config change, a data/content change, or a documentation-only
change. A Grafana *scrape target* or a Prometheus *alert rule* is not UI code and
is not web-related.

---

## W2. Playwright functional pass (MANDATORY)

Every web-related plan MUST include a dedicated **Playwright functional-test
task**, placed before the Code Review task (same ordering as S5/A12). An operator
browser checklist is **NOT** a substitute and does NOT satisfy this rule.

### W2.1 The pass runs in a clean-context subagent, not the author

**The authoring agent MUST NOT run its own Playwright pass.** The author already
believes the feature works; that belief is what makes a hand-run test worthless.
Running the test yourself lets you fix the test until it agrees with you. This is
the same defect §9.0 exists to close for code review, applied to the functional
pass.

Dispatch a **subagent**. The canonical tester is shipped at
`agent_planning/reviewer/playwright-tester.md`; copy it to
`.opencode/agents/playwright-tester.md` in the project root and dispatch it as
`playwright-tester`.

The dispatch prompt carries, and nothing depends on session state:

1. the plan file path and the Playwright task's section;
2. the surface under test and the user path;
3. the exact server start and teardown commands;
4. the spec file path the tester is permitted to write;
5. **the authoring model id** — the tester needs it for Row 0;
6. this addendum's path, so the tester does not rely on memory.

**Do not pass the authoring transcript or rationale.** If the tester finds it in
its prompt, that is a `FAIL` — the blind spot has been handed straight to it.

If the harness offers no subagent dispatch, log `[SCOPE-GAP]` in the devlog and
mark the task `⚠️ UNTESTED`; never mark an author-run Playwright pass `done`.

### W2.2 The tester runs on a different model

A subagent with no configured model inherits the parent's — the silent-inheritance
trap of `EXECUTION_PROTOCOL.md §9.0`. The shipped tester pins its primary model in
frontmatter. The dispatcher applies the fallback by re-dispatching with an explicit
`model` argument; there is no `fallback-model` config key, and inventing one would
pass an unknown field straight through to the provider.

| Order | Model | Use when |
|-------|-------|----------|
| primary | `opencode-go/minimax-m3.1-flash#medium` | always, unless the rule below says otherwise |
| fallback | `alibaba-token-plan/deepseek-v4.1-flash-1017#high` | primary unavailable, **or** the authoring model *is* the primary |

The second trigger matters: a tester on the author's own model is `ADVISORY`
(clean-context only), not `PASS`. When the author *is* the primary, dispatch
the fallback so the pass is genuinely cross-model. Model ids and reasoning-effort
variants are verified against the live catalog before being committed here; do not
guess a variant string.

The tester opens its report with **Row 0** — the model it is actually running
versus the authoring model — and the executing session applies the same
`PASS` / `ADVISORY` / `FAIL` table as §9.0. A tester pass recorded without a
Row 0 is `⚠️ UNTESTED`, not `done`.

### W2.3 What the task must do

The task MUST:

1. **Run the real surface.** Start the app/server locally (or point at a local
   build) and drive it — never a mock, never a fixture that bypasses the app.
2. **Drive the DOM.** Use Playwright locators and real interactions
   (`page.click` / `page.fill` / `page.keyboard` / `page.dragTo`) along the user
   path. A test that `fetch`es the underlying endpoint and never touches the DOM
   proves nothing about the UI.
3. **Assert observable behaviour** — element visible/hidden, exact text,
   class/attribute value, exact element count, or focus state. Never assert on
   module internals or private state.
4. **Cover the happy path AND at least one error/refusal path** (for example, an
   invalid target shows the refusal toast).
5. **Run headless** and exit non-zero on failure.
6. **Tear down** any server it started: no orphan processes (document a `pgrep`
   check that returns zero rows).
7. **Record the exact command + result** in the devlog (PLAN_CORE §9). For a
   deterministic runner you may paste the summary line + exit code; a functional
   assertion's evidence is the assertion result, not a 200-line log.

Runner: Playwright **1.63.0** is installed on the build host — both the Node
runner (`npx playwright --version`) and the Python package
(`python3 -c "import playwright"`). Use the runner whose language matches the
project's existing test suite.

### W2.4 Two rounds maximum

The Playwright gate carries the same **2-round cap** as Code Review
(`EXECUTION_PROTOCOL.md §9`, Review Loop Cap): round 1 is the initial dispatch,
round 2 is permitted after the round-1 blocking findings are remediated, and there
is no round 3. The two gates are budgeted separately — a web plan gets 2 Playwright
rounds **and** 2 Code Review rounds.

A re-run after applying fixes, a re-run on the fallback model, and a re-run "just
to confirm" each count as a round. When round 2 still reports blocking findings:
stop, mark the task `⚠️ BLOCKED (loop cap — Playwright, 2 rounds)`, record
`ROUND: 2/2 · Playwright · BLOCKING <n>` plus the round-2 report verbatim in the
devlog, add the `Loop cap hit` section to HANDOFF, and hand back to the operator.
Do **not** weaken, skip, or narrow the failing assertion to reach green (W2.1), and
do not convert the stop into a "ready to promote" claim. A third round requires an
explicit operator override logged as `LOOP-CAP OVERRIDE:`.

---

## W3. Waiver

If Playwright genuinely cannot run in the execution environment (no browser
binary, no network to fetch one, the target is only reachable from another host),
the plan records `Playwright: N/A — <reason>` in the preamble and marks the
functional task `⚠️ UNTESTED (playwright unavailable)`; the operator browser
checklist then becomes the fallback evidence, recorded as `⚠️ UNTESTED`. A
**silent** omission of the Playwright pass on a web-related plan is a defect
(R14). The waiver covers the *browser*, not the *dispatch* — if the harness can
dispatch a subagent, an author-run pass is still a defect even when the waiver
applies.

---

## W4. Task template

```
### Task N: Playwright functional pass — <surface>
**INTENT:** Prove <user path> works through the browser, not just at module level.
**DISPATCH:** clean-context subagent `playwright-tester` (W2.1) — the authoring
  agent does NOT run this pass. Model: `opencode-go/minimax-m3.1-flash#medium`,
  falling back to `alibaba-token-plan/deepseek-v4.1-flash-1017#high` when the
  primary is unavailable or
  is the authoring model (W2.2). Record `TESTER:` / `DISPATCH:` / `ROW0:` /
  `BLOCKING:` lines in the devlog.
**STRUCTURE:**
  - Test file: <path>/<name>.spec.ts   (or tests/<name>.py for the Python runner)
  - Server start: <exact local start command, absolute path>
  - Server stop:  <exact teardown command>
**CONTEXT:** Playwright 1.63.0 ✅ VERIFIED via `npx playwright --version` on <date>.
**CONSTRAINTS:**
  - Drive the DOM with real interactions; assert observable behaviour.
  - Headless; tear the server down; no orphan processes.
  - Do not parallelize tool calls — run each Playwright invocation sequentially (M3-1).
  - The tester may write ONLY the spec file named above; no application code.
**DON'T:**
  - Do not assert on module internals.
  - Do not leave the server or browser process running.
  - Do not replace the DOM interaction with a direct endpoint fetch.
  - Do not run this pass yourself, and do not weaken a failing test to make it
    pass — a failure is a reportable finding (W2.1).
  - Two rounds maximum (W2.4). If round 2 is still blocking, mark the task
    `⚠️ BLOCKED (loop cap — Playwright, 2 rounds)` and escalate — do not re-run.
**VERIFICATION:**
  - `<playwright run command>` exits 0; paste the summary + exit code into the devlog
  - Row 0 recorded with the tester's actual model vs the authoring model (W2.2)
  - Post-run teardown check: `<pgrep ...>` → 0 rows
  - DEVLOG: <devlog path + entry>
```

---

## W5. Web UI checklist (extends PLAN_CORE §12)

- [ ] Plan classified web-related, or `Playwright: N/A — <reason>` recorded
- [ ] A dedicated Playwright functional-test task exists and precedes Code Review
- [ ] The task names the clean-context `playwright-tester` subagent (W2.1); the
      authoring agent does not run the pass
- [ ] The dispatch pins a model and records the fallback actually used (W2.2);
      Row 0 present in the devlog
- [ ] The test drives the real user path through the DOM (no fetch-only substitute)
- [ ] Happy path AND an error/refusal path are asserted
- [ ] Headless run exits 0; server torn down with a documented zero-orphan check
- [ ] Exact command + result captured in the devlog
- [ ] Two rounds maximum (W2.4); a second blocking round ends in
      `⚠️ BLOCKED (loop cap — Playwright, 2 rounds)` + operator escalation, not a
      third run
