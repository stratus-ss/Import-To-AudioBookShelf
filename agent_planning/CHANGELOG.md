# Changelog

## 2026-10-27 — Review Loop Cap: 2 rounds maximum per gate (LOOP-CAP)

Origin: an execution session ran 3 hours through **6 Code Review rounds and 5
Playwright rounds**, each returning real defects, was stopped by the operator —
and then reported itself "ready to promote". Nothing in the protocol bounded a
remediation loop; `CQ9.6` in fact said "resolve them and re-review before
deploying" with no terminus, and the executor read the absence of a bound as
license to keep grinding.

- **`EXECUTION_PROTOCOL.md §9` — new subsection *Review Loop Cap — 2 rounds
  maximum per gate*.** Round 1 = initial dispatch; round 2 = only after round-1
  blocking findings are remediated; round 3 does not exist. A round counts **on
  dispatch**, not on merit (a re-check, a re-dispatch on another model, a
  partial-remediation dispatch, a "just to confirm" run each count). Code Review
  and Playwright are budgeted **separately** (2 each, not 2 total). Elapsed time
  is explicitly not an input.
- **Escalation contract on a second blocking round** — devlog
  `ROUND: 2/2 · <gate> · BLOCKING <n>` + the findings quoted verbatim + a
  per-round diff ("what round *n* found that round *n−1* did not"); task marked
  `⚠️ BLOCKED (loop cap — <gate>, 2 rounds)` (never `done`, never `⚠️ UNTESTED`);
  a `Loop cap hit` HANDOFF section naming the operator's decision and classifying
  it as unstated plan decision / wrong approach / genuinely small residue; stop
  the session, don't start the next task.
- **A cap stop is not a promotion, written down as a rule.** "Ready to ship with
  N open findings" after the cap fired is a defect in the report; "the remaining
  findings are minor" and operator impatience are not a round-2 pass. Third round
  only on an explicit operator override, logged as `LOOP-CAP OVERRIDE:
  <verbatim instruction> — operator, YYYY-MM-DD`; never self-granted.
- **`addenda/code-quality.md`** — CQ9.1 now requires the review task's CONSTRAINTS
  to carry the cap; CQ9.2 gains step 6 (observe the cap, `⚠️ BLOCKED` wording, no
  self-granted third round); CQ9.6 rule 3's boilerplate reworded from open-ended
  "re-review before deploying" to "re-review **once** … do NOT deploy" on a
  second blocking round.
- **`addenda/web.md`** — new **W2.4** (2-round cap for the Playwright gate,
  separate budget, `⚠️ BLOCKED (loop cap — Playwright, 2 rounds)`); W4 task
  template CONSTRAINTS and the W5 checklist carry it.
- **`AGENTS.md`** — new "Two rounds maximum per gate — then hand back" paragraph
  directly after the Code Review paragraph (the file an executing agent reads
  first).
- **`prompts/README.md`** — execution-session prompt carries the cap, the
  `ROUND:` line, and the "a cap stop is not a promotion" clause.
- Not changed: reviewer/tester pins, Row 0, dispatch contract, R14, the R7
  single-remediation bound (already capped), and the R1–R14 numbering (the cap is
  an execution-time rule, so it is referenced as `§9` Review Loop Cap rather than
  a new R-rule; a plan-authoring R-rule would have had to restate it in every
  addendum's R-list).

## 2026-10-25 — playwright-tester model pin changed (catalog change)

Same dead-model problem as the code-reviewer pin below: `opencode/space-bunny-free`
is gone from the catalog.

- **`reviewer/playwright-tester.md`** — primary is now
  `opencode-go/minimax-m3.1-flash#medium`; fallback is now
  `alibaba-token-plan/deepseek-v4.1-flash-1017#high` (operator choice
  2026-10-25). Fallback still applied by re-dispatching with an explicit `model`
  argument — no `fallback-model` key. Same trigger as before: primary
  unavailable, **or** primary *is* the authoring model (otherwise Row 0 is
  `ADVISORY`, not `PASS`).
- Propagated to every dispatch-path reference: `addenda/web.md` (W2.2 table +
  W4 task template), `EXECUTION_PROTOCOL.md` §9.0, `AGENTS.md` (Playwright
  paragraph), and the `.opencode/agents/playwright-tester.md` dispatch copy.
- Both ids + variant strings verified against `opencode models` on 2026-10-25.
  `#medium` (m3.1-flash) and `#high` (deepseek-v4.1-flash-1017) both exist.
- Unchanged: Row 0 self-report, spec-file-only edit permissions, W2.3 task
  requirements, R14 gate.

## 2026-10-25 — code-reviewer model pin changed (catalog change)

Operator: `opencode/space-bunny-free` is gone from the catalog, so the
Code Review subagent's pin moved. The prior pin would have failed dispatch
(or, if the id were ignored, silently inherited the authoring model — the
exact §9.0 defect).

- **`reviewer/code-reviewer.md`** — `model:` now
  `alibaba-token-plan/deepseek-v4.1-flash-1017#max` (DeepSeek V4.1 Flash 1017,
  Alibaba Token Plan, max effort — operator choice 2026-10-25).
- **Fallback** documented in the same frontmatter:
  `opencode-go/minimax-m3.1-flash#medium`, applied by re-dispatching with an
  explicit `model` argument (no `fallback-model` key). Use it when the primary
  is unavailable **or is the authoring model**.
- Both ids + variant strings verified against `opencode models` on 2026-10-25;
  effort values read from each model's variant list, not guessed.
- No behavioural change: read-only, Row 0 self-report, dispatch contract, and
  the §9.0 / CQ9.2 references are untouched. `plan-validator`
  (`opencode/deepseek-v4.1-flash#max`) and `playwright-tester` are untouched
  here — playwright-tester had the same dead pin and is covered by the entry
  above; plan-validator's pin is unaffected.

## 2026-10-25 — R7 re-instated: plan validation is a clean-context subagent gate (Tier 2/3)

Operator amendment. After a Tier 2/3 plan is authored and passes the
deterministic gates (lint, §8.6 reconciliation, selfcheck), it MUST be
validated by a clean-context `plan-validator` subagent **before**
`init_execution_dir.sh` — the same §9.0 discipline as Code Review. Hard gate:
zero FAIL rows before bootstrap; every FAIL is remediated and re-validated
once. Tier 1 fastpath plans stay exempt.

Design decisions (operator, 2026-10-25): hard gate (not advisory); Tier 2/3
only; R7 revised in place rather than a new rule number; validator pinned to
`opencode/deepseek-v4.1-flash#max` — flash at max effort is a deliberate
cost/capability pick, and a DeepSeek-authored plan yields Row 0 `ADVISORY`
(same-model, clean-context only), an accepted trade per the carried-over §9.0
semantics.

Why this does not resurrect the 2026-10-04 failure: the retired gate was a
shell tool (`plan_review.sh`) that an agent re-invoked from a non-TTY session
in a 5-hour unattended loop. The re-instated gate is a harness-native subagent
dispatch — it terminates and returns findings as data; one dispatch plus one
re-dispatch per remediation. `plan_review.sh` is unchanged: still optional,
operator-run, single-pass, approval-gated.

- **`reviewer/plan-validator.md`** (new, ships via the existing `reviewer/`
  sync dir) — clean-context plan validator. Pinned
  `model: opencode/deepseek-v4.1-flash#max` so it does not silently inherit
  the authoring model. Edit and subagent permissions denied. Re-runs
  `plan_lint.sh` / `plan_selfcheck.sh` for evidence, walks the §12 checklist
  and R1–R14 against the plan file itself, hunts unmade-DR forks and missing
  task sections. Row 0 self-report; findings table + `Blocking:` line.
- **`PLAN_CORE.md`** — R7 rewritten (number retained, re-instated 2026-10-25);
  new **§8.7 Plan Validation Dispatch** (contract: agent, prompt contents,
  blocking, preamble recording line, Tier 1 exemption, no-loop rationale);
  §2 rules intro now names the R7 dispatch; §12 R7 checklist item flipped
  from "retired/informational" to the active gate; `_Last updated_` bumped.
- **`AGENTS.md`** — "Before Task 1" gains the validation dispatch as step 3
  (bootstrap becomes step 4, quality gate step 5); new "Plan validation is
  never a self-validation" paragraph with the `[SCOPE-GAP]` fallback; the
  optional `plan_review.sh` paragraph now names the R7 gate as a distinct
  mechanism.
- **`EXECUTION_PROTOCOL.md` §9.0** — the model-pinning / silent-inheritance
  rule extended to the plan-validator dispatch (pinned
  `opencode/deepseek-v4.1-flash#max`, ADVISORY-when-same-model semantics).
- **`prompts/README.md`** — Execution—First Session gains the R7 dispatch
  step ahead of bootstrap.
- **`addenda/software.md`** — §checklist R7 row updated from retired to
  active gate.
- **`addenda/ponytail.md`** — two "note R7 is retired" parentheticals
  corrected.
- **`scripts/sync_protocol.sh`** — reviewer/ manifest comment gains
  plan-validator.md (comment only; `reviewer/` already syncs as a dir).
- **`scripts/init_execution_dir.sh`** — header comments updated so they no
  longer state "R7 removed" (behavior unchanged; R7 is agent-side, not a
  bootstrap script gate; `--skip-r7-gate` / `--r7-waived` stay no-ops).
- Enforcement is agent discipline + the preamble validation line (the same
  shape as Code Review's devlog discipline); no lint gate was added, so
  forward-only toleration keeps the existing plan corpus bootstrap-able.
- Model provenance: `opencode models list` → `opencode/deepseek-v4.1-flash`
  (2026-10-25); efforts low/high/max verified against the live catalog
  2026-10-18 (see the 2026-10-18 entry).

## 2026-10-18 — The Playwright pass is a clean-context subagent on a pinned, cross-model dispatch (R14)

Closed the second self-review hole, the one that survived the clean-context-reviewer
fix: the R14 functional pass had no independence requirement at all. A web plan
could satisfy R14 by naming a Playwright task and having the **authoring agent run
it** — the same defect §9.0 forbids for code review, in costume. An author already
believes the feature works, and will adjust the test until it agrees with them.

- **`reviewer/playwright-tester.md`** (new, ships via the existing `reviewer/`
  sync dir) — clean-context functional tester. Pinned
  `model: opencode/space-bunny-free#max` in frontmatter so it does not silently
  inherit the authoring model. Edit permission is denied for `*` and allowed only
  for spec files (`*.spec.ts`, `*.spec.js`, `test_*.py`, `*_test.py`) — the tester
  writes the test, never the application. Subagent dispatch denied. Carries the
  same Row 0 self-report as the Code Review.
- **Fallback model — `opencode/deepseek-v4.1-flash#max`**, applied by
  re-dispatching with an explicit `model` argument. Two triggers: the primary is
  unavailable, **or** the authoring model *is* the primary (a same-model tester
  is `ADVISORY`, not `PASS`). Verified 2026-10-18 against the live catalog:
  `space-bunny-free` efforts = low/medium/high/xhigh/max; `deepseek-v4.1-flash`
  efforts = low/high/max.
  **No `fallback-model:` frontmatter key was added** — OpenCode passes
  unrecognised agent config keys through to the provider as model options, so such
  a key would be silently sent upstream instead of doing anything.
- **`addenda/web.md`** — new **W2.1** (clean-context dispatch, prompt contents,
  no-transcript rule, `[SCOPE-GAP]` fallback) and **W2.2** (model pin, primary/
  fallback table, Row 0) ahead of the existing requirements, now numbered W2.3.
  W3 waiver clarified: it waives the *browser*, not the *dispatch*. W4 template
  gained a `**DISPATCH:**` block and a "do not weaken a failing test" DON'T.
  W5 checklist gained two items.
- **`addenda/code-quality.md` §CQ9.2** — one paragraph binding the Playwright pass
  to the same dispatch discipline: "an author-run functional test is a self-review
  in a different costume."
- **`EXECUTION_PROTOCOL.md` §9** — Web UI checklist now requires the subagent
  dispatch and Row 0, plus a new item: no failing assertion weakened, skipped, or
  narrowed to reach green. §9.0 gained a paragraph extending the model rule to the
  tester and naming the no-`fallback-model`-key fact.
- **`AGENTS.md`** — new "The Playwright pass is never self-run" paragraph ahead of
  the Code Review paragraph, with the devlog lines `TESTER:` / `DISPATCH:` /
  `ROW0:` / `BLOCKING:`.
- **`addenda/software.md` S7** — one checklist item.
- **`scripts/plan_lint.sh` P6-R14** — when a web-related plan names Playwright it
  must also name the tester (`playwright-tester` / `clean-context tester` /
  `functional-tester`). This is a **FAIL, not a `warn`**: the existing
  "looks web-related but names neither" check was advisory by design, and an
  advisory here is the loophole — it could not catch a plan that says "Playwright"
  and means "I will click through it myself". Three pre-existing closed plans trip
  the new gate; forward-only tolerates them.
  **The waiver check is tested before the Playwright check**, and scoped to the
  plan's preamble. Both orderings were wrong in the first cut, found by running
  the gate against the real corpus:
  - *Order*: `Playwright: N/A` contains the word "Playwright". Testing for
    Playwright first pushed every legitimately waived plan into the dispatch gate
    and failed it.
  - *Scope*: a body-wide waiver scan reads a REQUIRED plan's self-check
    proof-text as a real waiver. `dnd_character_sheet_2026-10-12.md` line 1139
    greps for the literal waiver string precisely to prove it did **not** claim
    one. The waiver is a preamble declaration by definition, so the scan is cut to
    the preamble — either before the first H2, or under an explicit `## Preamble`
    H2 (both shapes occur in the corpus).
  - The waiver pattern also tolerates markdown emphasis (`**Playwright:** N/A`,
    `- **Playwright:** N/A`), which the previous bare `Playwright: *N/A` missed.
  Fixture `r14_na_prooftext_not_waiver.md` covers the proof-text trap; both
  fixtures cover positive and negative dispatch.

## 2026-10-18 — Reviewer model is pinned and self-reported (follows the entry below)

Follow-up to the clean-context-reviewer change, closing a hole in it: the shipped
`reviewer/code-reviewer.md` had no `model:` field, and OpenCode documents that
*"a subagent uses its configured model, or **inherits the parent session's model**
when none is configured."* So the first version of the fix would have let a
reviewer silently run on the authoring model — reintroducing precisely the
same-model review the change set out to remove, with no signal.

### Changed

- `reviewer/code-reviewer.md` — frontmatter pins
  `model: opencode/space-bunny-free#max`. Verified against the live model catalog
  rather than guessed: `space-bunny-free` exposes
  `reasoning_options = [{type: effort, values: [low, medium, high, xhigh, max]}]`,
  so `max` is valid. Overridable per dispatch via the subagent tool's `model`
  argument.
- `reviewer/code-reviewer.md` — new **Row 0**. The reviewer opens its findings table
  by naming the model it is actually running, comparing it against the authoring
  model id passed in the prompt, and marking the result `PASS` (clean context +
  cross-model) / `ADVISORY` (clean context only) / `FAIL` (indeterminate, or the
  prompt leaked the authoring transcript). The verdict is the reviewer's, not a rule
  the dispatching agent could quietly satisfy.
- `EXECUTION_PROTOCOL.md §9.0` — the dispatch contract now requires passing the
  authoring model id; a decision table maps Row 0 to proceed / proceed-with-recorded-
  operator-acceptance / stop-and-re-dispatch. `ADVISORY` is explicitly allowed when
  the operator chose a same-model review, so the mechanism reports honestly without
  banning a legitimate cost or capability choice.
- `prompts/README.md` — `ROW 0` recorded verbatim in the devlog block. Summarising it
  would make an inherited model indistinguishable from a deliberately pinned one.

### Why not hard-fail on a same-model reviewer

The framework wants cross-model review as the default, not as a rule that punishes a
deliberate operator choice. The failure worth catching is the **silent** one — nobody
decided, and nothing shows it. Row 0 makes the decision visible in the artefact the
gate already blocks on.

## 2026-10-18 — Code Review requires a clean-context reviewer, not the author

Origin: executing Plan R0 (`budget_dashboard`) reached its Code Review task with
five authoring tasks done in one session. Asking whether the protocol required a
sub-agent surfaced the real defect: `EXECUTION_PROTOCOL.md §9` said the **executing
agent** performs a self-review, and `CQ9.2` justified that as fine because "a
cross-model pass already occurs because the review wrapper's default reviewer model
differs from a DeepSeek author."

Both statements fail together when the author is not DeepSeek. No review wrapper
runs during execution at all — `plan_review.sh` is plan-authoring, operator-run, and
explicitly never a gate. So the cross-model property the design leaned on did not
exist, and the review silently degraded to a same-model, same-session self-review
with nothing in the devlog to say so. An agent cannot report a blind spot its own
reasoning cannot see; that is the whole reason the review task exists.

### Changed

- `EXECUTION_PROTOCOL.md §9.0` (**new**) — the review MUST be performed by an agent
  that did not author the code, whose context excludes the authoring session. In
  OpenCode that is a **subagent dispatch**, which is fresh-context by construction.
  Defines the dispatch contract (the prompt is self-contained: plan path, scope file
  list, per-category commands, binding STOP RULES, §9 checklist path), forbids passing
  the authoring transcript or rationale, and specifies the `REVIEWER:` / `DISPATCH:` /
  `FINDINGS:` / `BLOCKING:` devlog record. Background dispatch is permitted for large
  scopes; the executing session blocks on the result before remediating.
- `reviewer/code-reviewer.md` (**new**) — the canonical reviewer subagent. Read-only
  by construction (`edit` denied, `subagent` denied), so it measures rather than
  authors a second time and the finding → justification → fix trail stays attributable
  to one session. Carries the §9 categories, the CQ9.3 findings-table output format,
  and the "anchor on behaviour, not line numbers" R10 discipline.
- `addenda/code-quality.md §CQ9.2` — retitled **Reviewer Dispatch and Model
  Selection**. Dispatch is now step 3 and mandatory; model selection moved to step 4
  with the cross-model property made structural rather than incidental. Records the
  retired claim and why it was unsound.
- `plan_lint.sh` **P6** — two checks. The `CQ9.2|model-switch` probe now also accepts
  reviewer-dispatch wording; and a **new fail** fires when a plan names a Code Review
  task but names no clean-context reviewer. Forward-only, so the pre-adoption corpus
  fails — expected, and it is exactly the gap being closed.
- `AGENTS.md`, `cursor_rules/agent-planning.mdc`, `prompts/README.md` — the rule is
  stated where agents actually read it, with the self-review downgrade called out
  explicitly.

### Added

- `sync_protocol.sh` — `reviewer/` joins `CANONICAL_DIRS`, so the reviewer ships to
  every downstream repo with the rest of the framework.

### Notes

- The reviewer is read-only by design. R11's remediation authority is unchanged: it
  stays with the executing session, which now applies the reviewer's findings and logs
  each change against them.
- A review with no dispatch recorded is `⚠️ UNTESTED`, never `done`. The previous
  protocol had no vocabulary for "reviewed, but not independently" — that is the
  state this closes.

## 2026-10-18 — PLAN_CORE §0: DR-grilling (decision records worked as a design-tree frontier)

Origin: a protocol review against the skill set in `~/git_projects/skills`
(grilling, domain-modeling, to-tickets, implement-spec, code-review) surfaced
four gaps in §0: (1) DRs were presented as a closed batch with no recommendation,
so every decision cost the user authoring time and "generate N DRs" was policed
by a filler rule rather than by a test; (2) the role table assigned architecture
to the AI outright — wrong for a repo where the operator is both SME and
architect-of-record; (3) nothing reconciled the two sizing models, though a plan
is a ticket-shaped unit (own execution dir, own terminal Code Review, spec lives
above it in `openspec/`); (4) no mechanical gate stopped a plan shipping with
`Decision: [user provides]` placeholders.

### Changed

- `PLAN_CORE.md §0` — Tier 2 is now **DR-grilling**. The DR format gains
  `Owner`, enumerated `Options`, and a `Recommendation` carrying a strength
  (`strong | weak | none`; `weak` must state what would change the AI's mind;
  `none` omits the line and is the user's to design). DR-worthiness is the
  **reproducibility test** — "Spec + DRs let a competent agent rebuild the
  software without inventing a design" — with the original four criteria demoted
  to detection heuristics. DRs are worked as a dependency **frontier** in
  uncapped rounds, grouped by domain area; layers opening as answers land is the
  process, not scope creep. Resolution vocabulary distinguishes an authored
  decision from `accepted AI recommendation`. Terminal condition: frontier empty
  AND every DR resolved. A ceiling rule collapses mechanical forks when a
  ten-task plan exceeds ~40 DRs.
- `PLAN_CORE.md §0` — Role Separation gains its third partition: the user owns
  system/design intent (selected from the AI's option space); the AI owns the
  question set, the option space, and implementation mechanics. Tier 1 questions
  now carry recommendations and a promotion path for a fork.
- `PLAN_CORE.md §2` — the no-conditional-branches rule gains its corollary: an
  undecided branch is an unmade DR, not task detail.
- `PLAN_CORE.md §5` — new **Plan Sizing** subsection: a plan is sized to ~one
  smart zone (~150 K) of fresh work; a larger deliverable is two plans, not one
  plan with more tasks. Splitting is **by token budget, not task count** —
  task count survives only as a tier-classification heuristic. Plan-file
  brevity is stated as a context-budget measure as well as a staleness one.
  The smart-zone floor is recorded as deliberately tighter than the model
  addenda's capacity ceilings (they answer "will it fit?"; this answers "will
  it still work?"), and the 150 K figure is flagged **provisional** — it is
  inherited, not measured here, and is to be revised on telemetry rather than
  on the next uncited number.
- `deepseek/MODEL_ADDENDUM.md §D1`, `minimax/MODEL_ADDENDUM.md §M1` — the
  task-count plan-size rules (`>12 tasks`, `>15 tasks`) are retired in favour of
  PLAN_CORE.md §5's token budget. Their `~500 K` / `~800 K` figures are
  relabelled explicitly as **capacity** ceilings so they stop reading as
  working targets that contradict §5. Both addenda now defer to §5 for sizing.
- `PLAN_CORE.md §8.6` — reconciliation gains an eighth class: resolve every fork
  in the task text to a spec line, a resolved DR, or the codebase.
- `PLAN_CORE.md §12` — checklist items for the DR ledger, ownership defaults, the
  frontier rule, and plan sizing.
- `scripts/plan_lint.sh` — new `check_dr_ledger`: an unresolved `Decision:`
  (empty, bracketed template placeholder, or `TBD`) fails the lint; the count of
  decisions taken on AI recommendation is emitted as an advisory PASS line.
  Fenced code blocks are blanked first, so a plan quoting the DR template is not
  flagged. An **unbalanced** fence fails rather than silently blanking the DR
  section and reporting a false green. A DR block with no `Owner` tag is an
  advisory WARN (forward-only: legacy plans stay green). File-budget sentinel
  raised 1000 → 1050 for the added check.
- `PLAN_CORE.md §1` — `DECISION RECORDS` now carries the §0 field set
  (`Owner`, `Options`, `Recommendation`, `Decision`, `Assumptions`,
  `Dependencies`). It previously kept the pre-rewrite template, which mandated a
  `Rationale` field §0 had dropped and omitted every field §12 requires — so a
  plan following §1 verbatim failed the §0 gate. §1's open/deferred-DR rule is
  also reconciled: a DR deferred to a follow-up plan *is* resolved (its Decision
  names the deferral) and must not gate a task here.
- `PLAN_CORE.md §0` — the default-ownership rule becomes a **three-case table
  with no gap**. Previously it had two cases ("shape" → user, "local mechanic
  forced by the codebase" → AI), which left the structural forks the
  reproducibility test admits — module boundary, data flow, dispatch / error /
  concurrency strategy, ordering, idempotency — falling through: they are
  exactly the forks an executor would otherwise *invent*, so they are not
  "forced by the codebase". Those now default to **the user**. The middle case
  carries the reasoning, because the failure it prevents is "mechanics" being
  the label that lets the agent quietly own a design commitment.
- `PLAN_CORE.md §0` Tier 1 — "No DRs required" contradicted the mini-DR
  promotion rule on the very next line. Tier 1 now drops the *ledger*, not the
  discipline: a mini-DR carries the full §0 record including `Owner`.
  `TIER1_FASTPATH.md` §"What you skip at Tier 1" updated to match.
- `PLAN_CORE.md §0` Tier classification — a DR that gates another DR is **no
  longer a Tier 3 signal**, because Tier 2 now walks `Dependencies:` as a
  frontier. Tier 3 is re-scoped to when the graph stops being readable inline
  and needs a rendered artifact; the Tier 3 block states that Tier 2's
  contribution is the recorded edges, Tier 3's is the drawing.
- `PLAN_CORE.md §12` — "Tasks are explicitly ordered" is scoped explicitly:
  execution is serial, §0's frontier orders *DRs*, and a task-level `blocked_by`
  edge is not yet modelled. Ownership item now names structural forks.
- `prompts/README.md` — all 6 authoring templates now name the DR-grilling
  mechanic (frontier, `Owner`, `Options`, `Recommendation` + strength), which
  was previously unreachable from the prompt an operator actually pastes.
- `scripts/plan_lint.sh` — the P8d comment pointed at `PLAN_CORE.md:177-181`,
  correct at HEAD but blanked by §0's growth. It now cites the section, per §2's
  ban on volatile coordinates.

### Corrections to prior entries

- **`CHANGELOG.md` 2026-10-10 (`quality_gate --file-budget`) carried a false
  premise**: "the fix lives in `scripts/`, which is **outside** the
  `sync_protocol.sh` canonical set, so it survives a framework sync." All seven
  scripts are in `CANONICAL_FILES` (lines 32–38), including `quality_gate.sh`
  where that fix landed. It survived by being fixed canonically and synced, not
  by being outside the set. Corrected inline; the real asymmetry is
  `addenda/` (synced recursively) versus `openspec/` and `scripts/test/`
  (excluded).
- **`knowledge/` cited `§9.6` of `agent_planning/{minimax,deepseek}/
  PLAN_INSTRUCTIONS.md`** as the KB-writeback rule. Both are 5-line files whose
  first line is `# DEPRECATED`, and neither contains a §9.6 (verified:
  `cat agent_planning/deepseek/PLAN_INSTRUCTIONS.md` → 250 bytes, 5 lines).
  Repointed to `agent_planning/PLAN_CORE.md §9.6` in `INDEX.md` and in
  `local-knowledge-first.md` (frontmatter `sources:`, body, and a dated
  correction block). Per the KB writeback rule that doc's `updated:` is bumped
  to 2026-10-18 and `confidence:` advanced to `partially-verified` — verified
  against the live files. `INDEX.md` `updated:` bumped to 2026-10-18.

### Notes

- **Behaviour change for every downstream repo** — `scripts/plan_lint.sh` is in
  the synced set. A plan in flight carrying `Decision: [...]` placeholders will
  start failing at bootstrap. That is the intent: the ledger is enforced at
  authoring closeout rather than discovered mid-execution.
- Forward-only: no archived plan is re-linted; the gate applies at the next
  `init_execution_dir.sh` per plan.
- Not adopted from the skills review, deliberately: free-form grilling that drops
  the DR record (`~/git_projects/skills/.../grilling`), a per-round question cap,
  and the ticket tracker itself (`to-tickets` publishes to a tracker; the plan
  file already carries the edge list).

## 2026-10-11 — plan_lint: repo-local lint hook (agent_planning/LOCAL_LINT.sh)

Origin: D&D_Workflow's roadmap-closeout contract (its LOCAL_RULES.md §7
rules 8–9) was read at authoring time and still landed in the plan preamble +
Doc Update task only — not in each task's closeout — so execution regenerated
the roadmap once, at the end, and the operator's published page lagged every
intermediate task. The identical defect had been caught by a review on an
earlier plan and recurred within a day: the rule lives downstream, and every
gate parsed only framework-owned rules, so no deterministic surface could
reject it. Authoring diligence had already been demonstrated and was not the
missing piece.

### Fixed

- `scripts/plan_lint.sh` — when `agent_planning/LOCAL_LINT.sh` exists (it is
  never synced, so each repo owns its copy), run it with the plan path as `$1`
  and fold a non-zero exit into the lint result. `init_execution_dir.sh`
  already refuses to bootstrap on a lint failure, so a repo-local rule can now
  fail closed at authoring time. Repos without the file see no behaviour
  change.
- Downstream side of the contract (not synced): D&D_Workflow's `LOCAL_LINT.sh`
  enforces the roadmap closeout on every `Task N` section of a
  dashboard-visible plan, with fixtures
  `scripts/test/fixtures/local_roadmap_{ok,missing}.md` pinning both
  directions.

### Notes

- The hook is the mechanical seat for repo-local plan rules generally:
  `AGENTS.md` item 7 tells authors to read `LOCAL_RULES.md`, and the hook lets
  that file carry enforceable checks instead of prose alone.
- Scope ceiling: the hook runs on the standard code-producing path;
  `--allow-non-code` and the no-code-signals early exit skip it by design.

## 2026-10-11 — code-quality: bind plan authoring and gate scope against changelog comments (downstream finding, D&D_Workflow dnd_consumables_seed)

Origin: CQ3 bans changelog comments and D&D_Workflow already enforces it
with a repo-owned scanner — and provenance comments still came back inside a
single in-flight plan. Two causes, neither agent drift:

1. **The plan prescribed one.** Its Task 7 text told the executor to end a
   comment with `... = 36. dnd_consumables_seed Task 7.` The plan is the
   executor's instruction surface; the executor complied, and the same
   habit carried into the other files the plan touched.
2. **The gate covered only reviewed files.** The scanner's scope was the
   `web/static/` files a human had hand-reviewed. The Go files the plan
   worked in were outside it by construction, so nothing failed.

### Fixed

- `addenda/code-quality.md §CQ3` — added the two bindings: comment text
  quoted inside a plan is subject to the rule (a plan must never prescribe
  provenance), and enforcement scope is every first-party source file a
  task can touch, with pre-existing debt carried in a shrink-only baseline
  rather than a hand-curated allowlist.
- `AGENTS.md` — the planning read-list gains item 7, a pointer to
  `agent_planning/LOCAL_RULES.md` (when present), so repo-local rules that
  bind plan content are read at authoring time. Upstreamed from
  D&D_Workflow, where it existed only as a local edit in a synced path —
  one sync from gone.

### Notes

- No framework tooling changed. CQ3 already places the gate in the repo's
  own test/script suite; the fix is that the downstream gate now matches
  the rule's actual scope.
- The downstream repo rebuilt its scanner to cover all languages and wire
  into `make check`: a per-file `[comment-provenance]` baseline (119 files
  recorded as debt after cleanup) where a cleaned file drops its entry and
  any unlisted file fails the gate.
- The 12 files the in-flight plan had touched (11 Go, the Makefile) were
  cleaned by hand: the provenance clause was deleted in every case, never
  reworded, and the rule each clause rode in on was kept.

## 2026-10-10 — quality_gate: `--file-budget` is now additive with complexity (downstream finding, D&D_Workflow dnd_battle_summons)

Origin: the `dnd_battle_summons` plan shipped six functions over the CQ11
complexity cap — `spawnSummons` at 53, `overlaySummons` at 23, the spell
popup's `open` at 20, and three more at 17–18. All sixteen selfcheck suites
and seventeen Go test packages were green throughout; the Task 10 review
caught the complexity violations only because it ran `quality_gate.sh` with a
flag the plan had never named.

Root cause was the gate, not agent drift. `addenda/code-quality.md §CQ11`
describes the file-budget check as "additive to the `--lang` complexity
invocation", but the script did `continue` after the budget arm, making the
two **mutually exclusive**. The command every coding task's VERIFICATION step
names (`--file-budget`) therefore could not reach the complexity arm at all —
68 devlogs in one downstream repo invoke it, and 2 also name `--lang`. Nobody
forgot the flag; the tool never reached the code that would have used it.
`--lang` was never the problem either: a bare `quality_gate.sh <path>`
auto-detects per-file by extension and already runs complexity.

### Fixed

- `scripts/quality_gate.sh` — `--file-budget` now **falls through** to the
  complexity arm instead of `continue`-ing past it, matching CQ11's own
  wording. A directory sweep still returns after the budget arm rather than
  re-walking every file through complexity.
- `scripts/quality_gate.sh` — new **`--file-budget-only`** for a legitimate
  line-caps-only sweep (non-code trees, config sweeps).
- `scripts/quality_gate.sh` — the complexity arm now skips **silently** on a
  file with no detectable language *when the budget arm ran* (JSON sidecars,
  markdown), instead of failing "could not detect language". A no-flag run on
  the same file still fails loudly, so a genuinely wrong invocation is not
  silenced.

### Notes

- **Behaviour change for every downstream repo.** Any plan whose VERIFICATION
  says `--file-budget` now also gets complexity checking. That is the point,
  but repos whose recorded PASSes hid over-cap functions will start reporting
  FAIL. Worth a heads-up before the next coding task.
- `--lang` was deliberately **not** added to any plan template. Adding it
  would have addressed a non-defect and bloated every task block.
- The fix lives in `scripts/`, which is **outside** the `sync_protocol.sh`
  canonical set, so it survives a framework sync. The same wording change in
  `addenda/code-quality.md` would have been silently overwritten by the next
  downstream sync.
  > **[Corrected 2026-10-18]** The premise above is **wrong**. All seven scripts
  > are in `sync_protocol.sh` `CANONICAL_FILES` (lines 32–38), including
  > `quality_gate.sh`, which is where this fix landed. Nothing survived *by
  > being outside the set* — it survived by being fixed canonically and synced.
  > The real asymmetry is `addenda/` (synced recursively via `CANONICAL_DIRS`)
  > versus `openspec/` and `scripts/test/` (explicitly excluded).
- Verified upstream before committing: a sweep of `agent_planning/` surfaces
  **no** new complexity violations, and the pre-existing failures (three
  over-cap `test/fixtures/file_budget/*.go` that exist to be over cap, and
  `shellcheck not installed`) reproduce byte-identically on the original
  script.

## 2026-10-10 — CQ3 no-changelog-comments rule (downstream finding, D&D_Workflow battle overlay)

Origin: the operator noticed `battle.js` was ~40% comment lines. It was — 607
of 1,476, and 462 changelog-style lines across the `battle*.js` zone. Commit
`72c6be6` had already stripped the same noise on 2026-10-04 and it walked
straight back in, which is the finding that matters: a one-time strip cannot
hold, so the rule has to be mechanical. Measured costs, not aesthetic ones —
every comment line is re-read by every agent that opens the file, and
`addenda/file-budget.md`'s per-file caps count *every* line, so prose directly
steals the code room the next task needs (this is what forced the
`battle-summon-flow.js` extraction mid-plan in `dnd_battle_summons` Task 6).

### Added

- `addenda/code-quality.md §CQ3` — new subsection **No changelog comments**:
  the banned signals (plan/ticket slug, task number, ISO date, version or cap
  bump), the BAD/GOOD example, the two costs that justify enforcement, and the
  explicit carve-outs — explanatory prose however long, bare requirement
  anchors pointing at a live spec, and any comment line a tool parses such as
  a `file-budget:` sentinel.
- `addenda/code-quality.md §CQ3` — `MAINTAINABILITY CHECK` gains step 3, a
  whole-line-comment grep for the same four signals.

### Notes

- Enforcement is deliberately left to each repo: the rule lands in the shared
  framework, but the gate is a repo-local script because the carve-outs differ
  per project. D&D_Workflow's is
  `dnd-dashboard/scripts/comment_hygiene_selfcheck.mjs`, whose exclusion list
  matches this rule's carve-outs.
- The rule text is repo-agnostic on purpose. The examples cite
  `dnd_battle_summons` / `DR-4` because that is the corpus it was derived
  from; they read as samples, not as a convention other repos must match.
- `plan_lint.sh` was re-run against `zed_plans/dnd_battle_summons_2026-10-09.md`
  in D&D_Workflow after this edit: PASS, 0 warnings. The P8j advisory that
  requires a `MAINTAINABILITY CHECK` per coding task is unaffected — step 3 is
  additive inside the existing block.

## 2026-10-07 — Authoring-closeout reconciliation pass (advisory lint check + blind pilot)

Origin: a blind pilot validated the pass against two pinned historical plans
before adoption. S1 (`blackbox_expansion_wekan_decom`, pinned at `64a387d2`)
had already passed lint + selfcheck and a cross-model review at A-/88, 0 FAIL;
the pass caught its tree-verifiable ground-truth defect (job census: 13/16
claimed vs 15/18 actual) plus 6 further confirmed findings, 4 of them never
recorded during execution. S2 (`agent_security_scanning_framework`, pinned at
`e724dfa9`) caught its self-disproving skill-count claim plus 5 further
confirmed findings. Totals across both subjects: 12 confirmed,
3 temporal-unverifiable, 0 false, 0 fabricated; wall clock 6m46s / 9m09s;
~$0.07–$0.09 per blind pass (≈1–2 cents per confirmed finding); no cross-model
spend. Report: `agent_planning/execution/reconciliation_pass/artifacts/pilot/REPORT.md`.

### Added

- `PLAN_CORE.md §8.6` — Authoring Closeout — Reconciliation Pass: one bounded,
  same-session pass after the plan draft and before the deterministic gates;
  the seven-class checklist, the downgrade rule, and the preamble
  `Reconciliation:` record line.
- `PLAN_CORE.md §12` — checklist row for the preamble record.
- `prompts/README.md` — "Plan Reconciliation — same session" paste-ready prompt.
- `AGENTS.md` — "Before Task 1" step 2 now opens with the closeout ordering.
- `scripts/plan_lint.sh` — advisory `check_reconciliation_record`: a Tier 2/3
  plan with no preamble record draws a WARN; the check never calls `fail()` and
  never changes the exit code.
- `scripts/test/fixtures/reconciliation_missing.md` + `reconciliation_ok.md` —
  fixture pair pinning the WARN and the record-present pass; expected-outcome
  rows added to `scripts/test/fixtures/README.md`.
- `openspec/specs/plan-gate-reconciliation/spec.md` — living spec for the
  advisory check; `openspec/README.md` Current Specs row.

### Notes

- Advisory and forward-only: pre-adoption plans WARN by design; the check is
  visibility, not a gate.
- Trial (adopted 2026-10-07): reviewed by the operator after 5 Tier-2/3 plans,
  against recorded per-plan pass cost and catch data; removed if it
  demonstrates no catch.
- Blast radius: the sync distributes this change to all 11 mirrors
  (`scripts/sync_protocol.sh`, operator-gated); `scripts/test/` stays
  canonical-only, and the pre-existing `quality_gate.sh` parity drift is
  carried by the same sync.

## 2026-10-04 — Fold mechanical plan checks into plan_selfcheck (phantom paths, count baselines)

Origin: analysis of 38 review artifacts (55 `FAIL` findings) found ~36 were
mechanically checkable and only ~8 were genuine semantic/cross-boundary defects.
This change moves the tractable ones into deterministic tooling so the optional
semantic reviewer is reserved for what only it can catch.

### Added

- `scripts/plan_selfcheck.sh --verify-paths` — NEW advisory check: flags
  backticked repo-relative path citations that do not resolve to a real file,
  classifying each as `moved` (a file with the same basename exists elsewhere —
  archived/renamed) or `not-found`. Catches stale citations such as a plan
  archived under `zed_plans/archive/` or a directory renamed (`abs-mcp/` →
  `abs_mcp/`). Resolves against cwd, the repo root, `$GIT_PROJECTS`, and by
  path-boundary suffix (subdir-relative citations). Never changes the exit code.
  Self-test fixture added.
- `scripts/plan_selfcheck.sh --rerun` — the exact-count assertion now accepts
  `→ N lines|hits|matches|occurrences|results|files|rows|entries`, not just
  `→ N lines`.

### Notes

- The R5 §12 evidence-cited coverage count already lives in `plan_lint.sh`
  (advisory) — no change needed there.
- Broader phantom detection is deliberately opt-in and advisory: measured over
  the 65-plan corpus it surfaces ~200 citations, a mix of genuine stale
  references and legitimate to-be-created / subdir / cross-project paths, so it
  cannot gate. `moved` is the high-signal class.
- `scripts/sync_protocol.sh` — `scripts/plan_selfcheck.sh` added to
  `CANONICAL_FILES`. It was **missing from the sync manifest**, so most mirrors
  never received the authoring self-check that `AGENTS.md` instructs them to run
  (`D&D_Workflow` had a stale 219-line copy; `Whisper-WebUI` and others had
  none). Now distributed to all 11 mirrors.
- No semantic capability was removed: the optional `plan_review.sh` still exists
  (operator-run, guarded) for the ~8 cross-boundary findings that
  deterministic checks cannot produce.
- Synced to the 11 downstream mirrors via the operator-gated `sync_protocol.sh`.


## 2026-10-04 — R7 pre-execution review gate removed; review hardened against unattended loops

Origin: an agent ran repeated plan reviews **unattended** and **against an
explicit operator instruction** ("execute only, skip R7"), exhausting the 5-hour
token window while the operator was away. Telemetry in `D&D_Workflow` shows the
loop: `hook: plan_review` fires 9 times 13:00–13:25 and 7 more 14:26–14:50 on
2026-10-03, almost all on the metered provider
`openrouter/anthropic/claude-sonnet-5.5`. No review ledger was written, so those
runs bypassed the single-pass guard entirely (manual `opencode run` calls). The
root causes were (a) R7 being a mandatory pre-execution gate and (b) nothing
stopping an agent from running the reviewer on its own.

### Removed

- **R7 is retired** — there is no pre-execution semantic-review gate. `PLAN_CORE.md
  §2` R7 is marked retired (number retained to avoid renumber churn); `§12` R7
  is informational; `AGENTS.md` "Before Task 1" no longer has a review step;
  `addenda/software.md` and the review rubric drop the R7 gate check.
- `scripts/init_execution_dir.sh` — the R7 recorded-line gate, the R7 review
  summary appended to `STATE.md`, the migration-preserve of an R7 section, the
  R7 "SKIPPED" message, and the `r7_outcome` telemetry field are all removed.
  Bootstrap now gates only on `plan_lint.sh`. `--skip-r7-gate` / `--r7-waived`
  are accepted as deprecated no-ops so existing callers do not break.
- `EXECUTION_PROTOCOL.md` — the `STATE.md` template's "R7 Review Summary"
  section is gone.

### Added

- `scripts/plan_review.sh` — **unattended guard**: the tool refuses to run
  without an interactive terminal (`exit 4`); an agent-run shell has no TTY, so
  an agent cannot start a review on its own. `PLAN_REVIEW_AUTORUN=1` is the
  explicit operator opt-in for a headless run.
- `scripts/plan_review.sh` — **kill switch**: `PLAN_REVIEW_DISABLED=1` or a
  sentinel file `agent_planning/execution/.no-plan-review` refuses all runs.
- `--force` now requires the operator env `PLAN_REVIEW_FORCE_OK=1` in addition
  to the flag, so a single-pass override cannot be silently self-granted.

### Changed

- `TELEMETRY.md` — `plan_review` documented as optional/operator-run; the
  `init_execution_dir` hook no longer records an R7 outcome; `deviations` note
  updated to `--skip-plan-lint`.
- `addenda/ponytail.md` — stale `R1–R7` range corrected to `R1–R14`.
- `.gitignore` — `agent_planning/execution/.no-plan-review`.

### Notes

- Plan review remains available as an **optional** operator tool
  (`plan_review.sh` + `prompts/plan_review_rubric.md`), but it is no longer on
  the execution path and cannot be started by an agent.
- Synced to the 11 downstream mirrors via the operator-gated `sync_protocol.sh`.


## 2026-10-03 — Web UI addendum + R14 (Playwright functional pass mandatory)

Origin: web-related plans could ship with only module-level tests plus an
operator browser checklist. The `dnd_soundboard_phase2` devlog recorded "the
agent cannot drive a browser headlessly", and the `dnd_battle_downed_targeting`
plan (2026-10-03) specified only "drive the SPA in a browser (devtools console
allowed)" — the executor then improvised a ~480-line Playwright script mid-task.
Playwright 1.63.0 was in fact available on the build host, so the gap was
specification, not tooling.

### Added

- `addenda/web.md` — NEW cross-cutting addendum (§W1–§W5): when a plan is
  web-related; the MANDATORY Playwright functional-test task (drive the real
  surface, drive the DOM, assert observable behaviour, happy + error path,
  headless, tear down the server, capture the result); the `Playwright: N/A —`
  waiver; a paste-ready task template; and a Web UI checklist.
- `PLAN_CORE.md §2` — new cross-cutting rule **R14 Browser-UI acceptance
  (Playwright)**; `§12` gains the R14 checklist bullet.
- `addenda/INDEX.md` — new `web` selection-table row + "Web Addendum — When to
  Read" subsection.
- `scripts/plan_lint.sh` — new advisory check: a plan that looks web-related
  (browser-context paths / `Lovelace` / `DOM` / `browser` / `front-end` / `SPA`)
  but names neither `Playwright` nor `Playwright: N/A` emits a `P6: R14` warning.
  Advisory only (never a FAIL) to avoid false-positive hard blocks.

### Changed

- `prompts/plan_review_rubric.md` — new **R14** semantic-check bullet; the
  P-rule note documents the `P6: R14` warning; R-range `R1–R14`.
- `addenda/{software,infrastructure,code-quality,automation}.md`, `PLAN_CORE.md`,
  `prompts/plan_review_rubric.md` — R-range renamed `R1–R13` → `R1–R14`.
- `addenda/software.md §S5` and `addenda/infrastructure.md §A12` — cross-reference:
  a browser-UI functional task MUST use Playwright (no operator-checklist
  substitute).
- `AGENTS.md` — "Before Planning Any Non-Trivial Task" step 4: read
  `addenda/web.md` when the plan produces a browser-rendered UI.
- `EXECUTION_PROTOCOL.md §9` — new "Web UI (per addenda/web.md, R14)" review
  checklist subsection.

### Notes

- Rule R14 is a MUST enforced structurally at the Code Review task and by the
  §12 checklist; `plan_lint` supplies the deterministic advisory nudge. A
  borderline plan may record `Playwright: N/A — <reason>` in its preamble.
- Synced to the 11 downstream mirrors via the operator-gated
  `scripts/sync_protocol.sh` (the `addenda/` directory syncs recursively, so
  `web.md` propagates automatically).


## 2026-10-03 — Single-pass, operator-gated plan review (token-budget fix)

Origin: the planning/execution framework was consuming the MiniMax budget ~40% of the way into the time window. Root-cause analysis of the freshest run (`zed_plans/archive/agent_planning/file_budget_protocol_2026-10-02.md`) found the review path, not execution, was the dominant controllable cost:

- Every Tier 2/3 plan was reviewed **at least twice** — once by the author (R7 step 3) and again unconditionally by `init_execution_dir.sh` at bootstrap (the "advisory" invocation), plus any remediation re-review.
- The reviewer was non-deterministic and re-review did not converge: the same plan scored **A- (91, 1 FAIL)** on run 1 and **B+ (87, 2 FAIL)** on run 2 after remediation — fixing one FAIL surfaced new ones, so the loop had no termination proof.
- The findings payload was ~63% `PASS` rows the operator never reads, emitted **twice** (fenced block + bare echo), on a reviewer that also ran its own shell commands.
- Timeouts (240s/600s) were below the reviewer's documented 8+ min TTFT, so a pass timed out and was re-run at 3600s — the preamble records exactly this.
- `plan_review.sh` hard-coded `minimax/MiniMax-M3`, routing all review spend to the quota-limited provider.

### Added

- `scripts/plan_review.sh` — **operator approval gate + hard single-pass enforcement**. The wrapper prints a preflight (plan/rubric bytes, est. input tokens, model, timeout, prior-review count) and refuses to invoke a model without `--approved` / `PLAN_REVIEW_APPROVED=1` (exit 2). It hard-refuses a second review of the same plan path (exit 3) unless `--force`. Backed by a gitignored ledger `execution/_review_ledger.jsonl`.
- `scripts/plan_review.sh` — **cost telemetry**: `plan_bytes`, `raw_bytes`, `elapsed_s`, `pass`, `approved` added to the `plan_review` telemetry line and the ledger record.
- `.gitignore` — `agent_planning/execution/_review_ledger.jsonl`.

### Changed

- `scripts/plan_review.sh` — **no silent default model** (`--model` or `PLAN_REVIEW_MODEL` required); realistic timeouts (`PLAN_REVIEW_TIMEOUT_SINGLE` 1800s, `PLAN_REVIEW_TIMEOUT_MULTI` 3600s); the multi-file failure path now **fails loudly** instead of silently falling back to sequential per-part reviews (which multiplied cost by the part count).
- `prompts/plan_review_rubric.md` v1.5 — emits **only `FAIL`/`ADVISORY`** (a passing dimension is signalled by its absence); a **single** fenced JSON block (no duplicate echo); **static-only** (no shell/search tools — the attached `plan_selfcheck` output is authoritative, uncovered checks become `ADVISORY` "needs a deterministic check"); schema rule enum updated to `CQ1..CQ11 | R1..R13`.
- `scripts/init_execution_dir.sh` — **never invokes the reviewer**. Bootstrap validates the recorded R7 line and reads the existing artifact (plan-adjacent `<plan>.review.json`, else `artifacts/plan_review.json`), copying it in for the STATE.md summary. This removes the duplicate review pass that fired on every bootstrap.
- `PLAN_CORE.md` §2 R7 / §12 — R7 reworded to "narrow trigger, single pass, recorded gate": runs exactly once, operator-gated, remediation proceeds **without a re-review**; bootstrap never re-invokes. `_Last updated:_` bumped.
- `AGENTS.md` — "Before Task 1" step 3/4 rewritten for the single-pass, operator-approved, no-silent-model flow; step 4 states bootstrap never invokes the reviewer.
- `TELEMETRY.md` — `plan_review` hook documented as single-pass/operator-gated; new cost fields and the review-ledger contract added.

### Notes

- Net effect on the observed case: **one** cost-visible review per plan (down from 2–3), with ~63% less findings payload, no duplicated JSON, no reviewer shell turns, and no timeout-induced re-run.
- Synced to all 11 downstream mirrors on 2026-10-03 via the operator-gated `scripts/sync_protocol.sh` (exit 0; verification pass reports every repo "all files in sync"). The same sweep added idempotent `.gitignore` entries for `agent_planning/execution/_review_ledger.jsonl` (and the previously-missing `_telemetry.jsonl`) to each downstream repo root `.gitignore`, matching the canonical repo.
- No KB doc covers the planning framework, so this changelog entry is the audit trail for the change (per the AGENTS.md KB-writeback rule's "if no doc exists" clause the framework is not a KB-covered system).


## 2026-10-02 — File budget protocol (R13, addenda/file-budget.md)

Origin: the `D&D_Workflow` `dnd_battle_js_decompose_2026-10-01` plan's DR-3 recorded that a spec scenario stated `battle.js ≤400` but no gate enforced it — the file grew to **2454 lines** before the plan shipped a project-local `battle_modules_selfcheck.mjs`. This release lifts the per-project selfcheck to a framework rule: a per-plan, per-language file cap with an in-file sentinel override and a hard-fail gate. Plan-of-record: `zed_plans/archive/agent_planning/file_budget_protocol_2026-10-02.md` (Tasks 1–9). Propagates downstream via the operator-gated `scripts/sync_protocol.sh`, now registering all 11 framework mirrors.

### Added

- `addenda/file-budget.md` — NEW cross-cutting addendum (§FB1–§FB7): per-language caps (JS/TS 800, Go 500, Python 500, Bash 200), the in-file sentinel syntax and regex, the exemption list (tests / generated / vendored / VCS metadata), the gate behavior contract, the checklist, and the enforcement invocation.
- `PLAN_CORE.md §2` — new cross-cutting rule **R13 File budget enforcement**: every coding task that modifies source files includes `quality_gate.sh --file-budget [modified_paths]` in VERIFICATION; over-cap files are decomposed or carry a sentinel whose reason names the justifying plan. §12 checklist adds the R13 bullet and a Code Quality Gate row; §5 gains a cross-link distinguishing per-file caps from plan token budgets.
- `addenda/code-quality.md §CQ11. File budget` — short section pointing at `addenda/file-budget.md`, plus a §CQ8 checklist row.
- `scripts/quality_gate.sh --file-budget` — new mode: path-scoped, extension-mapped, sentinel-aware, skip-aware, hard-fail on cap exceed (`run_file_budget` + `is_skipped`). Orthogonal to `--lang`; directories are walked recursively; unmapped extensions are silent.
- In-file sentinel `// file-budget: [N] — [reason]` (Go/TS/JS) / `# file-budget: [N] — [reason]` (Python/Bash), read from the first 50 lines; declared budget replaces the language default and is `INFO`-reported.
- `scripts/test/file_budget_selfcheck.sh` + `scripts/test/fixtures/file_budget/` — canonical-only self-test asserting the decision matrix (over-cap FAIL, within-budget sentinel PASS+INFO, declared-budget-exceeded FAIL, late-sentinel ignored → FAIL, exempt silent).

### Changed

- `PLAN_CORE.md`, `addenda/{code-quality,software,automation,infrastructure}.md`, `prompts/plan_review_rubric.md` — R-range headers/paragraphs rename `(R1–R12)` → `(R1–R13)`; the rubric gains an R13 semantic-check bullet.
- `addenda/INDEX.md` — new `file-budget` selection-table row, a "File-Budget Addendum — When to Read" subsection, and a discovery command.
- `AGENTS.md` — the step-3 code-gate line names both `addenda/code-quality.md` and `addenda/file-budget.md`.
- `scripts/sync_protocol.sh` — `KNOWN_REPOS` extended with the four unregistered full-mirror repos (`htpc-desktop`, `garmin-influxdb`, `mtv-parser`, `pfsense-to-opnsense-api`); the legacy root `sync_protocol.sh` carries a deprecation banner.
- Mirror sync: the canonical framework is distributed to all 11 agent_planning-equipped repos via the operator-gated `scripts/sync_protocol.sh` (source distribution, not a runtime deployment).

## 2026-09-26 — Truth-gap remediation (R12, enumeration wording, absence mark, count-compare, rubric)

Origin: a human-grade review of the `dnd_battle_spell_flow` plan (D&D_Workflow) found two cross-boundary defects the gates missed — a producer/consumer representation mismatch and an incomplete call-site enumeration on module-private functions; root-cause analysis lives in the D&D_Workflow repo at `tmp/planning_protocol_spellbook_fix.md`. A parallel proposal (`tmp/battle_spell_plan_updates.md`, D&D_Workflow) harvested a seven-rule package from the same execution; four rules were folded in here, two were rejected as duplicates of `code-quality.md §CQ6` / `§CQ10` and the duplication recorded there. The fix lands in the canonical framework at `~/git_projects/scratch_pad/agent_planning/` and propagates downstream via the operator-gated `sync_protocol.sh` (R1). Plan-of-record: `zed_plans/protocol_truth_gaps_2026-09-26.md` (Tasks 1–8 + late-ingested Tasks 9–10 for the 2026-09-26 addendum `tmp/augment_protocol_truth_gaps.md`).

### Added

- `PLAN_CORE.md §2` — new cross-cutting rule **R12 Producer–consumer representation fidelity** (trimmed one-paragraph form per DR-1): consuming tasks MUST quote the consumer's expected representation with provenance, name the stored→consumed transformation (or cite the consuming site that proves none is needed), and carry at least one acceptance that feeds the producer's actual output through the real consumer path. Producer-side-only assertions (counts, key names, category labels) do not satisfy the rule when the consumer receives a different shape. §12 checklist adds the R12 bullet.
- `PLAN_CORE.md §2 Change-Impact Enumeration` — three new rows (AUG-1 addendum ingest): asserted-identity co-scheduling; replaced-surface enumeration (incl. the degenerate / empty case that exercises zero of its branches); new mutable state — create / read / clear paths plus the sibling-reset handlers the new state joins. §12 checklist gains three matching bullets.
- `PLAN_CORE.md §6` — new provenance mark **`✅ VERIFIED-ABSENT`** meaning "the planner ran this exact command and confirmed it returns zero matches / exits non-zero (a tested absence)". Recognized by §6 and by the P1 marks regex; deliberately never re-executed by `plan_selfcheck.sh --rerun`, which treats non-zero exit as failure. §12 marks line lists the new mark.
- `plan_selfcheck.sh --rerun` — exact-count re-execution: a `✅ TESTED` line stating `→ N lines` is re-executed and the live stdout line count must equal the stated count; re-executed commands' stdin is redirected from `/dev/null` so a stdin-reading command cannot swallow the queue. Skips plan lines marked `✅ VERIFIED-ABSENT` (tested absences exit non-zero by design) and `⚠️ UNTESTED` (lines state an expectation, not a tested fact). Excludes backticked spans containing `...` (the `...` guard exempts explanatory / abbreviated quotes on ✅ TESTED lines — every other backticked span is treated as a command). Commands run verbatim in the caller's cwd; rerun-eligible plan commands must use absolute paths.
- `scripts/plan_lint.sh` — the P1 marks regex widens to recognize `✅ VERIFIED` and `✅ VERIFIED-ABSENT` alongside `✅ TESTED`, `📖 FROM-DOCS`, `⚠️ UNTESTED` (vocabulary drift fix vs the P8e diagnostic regex). P8j `cq_task_missing()` gains a fourth presence item: every coding task's VERIFICATION must carry a `MAINTAINABILITY CHECK` (per `code-quality.md §CQ6`); P8j is diagnostic-only and emits a P8j advisory, never a FAIL — do not promote.
- `addenda/code-quality.md §CQ4 Plan-Authoring` — new sub-rule **`### Duplicated-value agreement guard`** (AUG-2 addendum ingest): when a value must exist in more than one artifact by architecture — config beside code, stylesheet beside script, documentation beside implementation; any duplication no build step unifies — the plan MUST include a value-anchored guard that pins the artifacts' agreement by extracting the value from its canonical artifact and asserting it appears in the others. Anchored to the value or a stable identity, never a line number. Supplements, never replaces, CQ4's define-once rule.
- `addenda/software.md` — the same enumeration wording mirrored in Change-Impact Dependent Discovery (M2 wording applied to the discovery section).
- `prompts/plan_review_rubric.md` v1.3 (2026-09-26; R8–R12) — R12 rubric line + three non-R-rule bullets under `R-rule Semantic Checks` (Asserted-identity co-scheduling / Replaced-surface enumeration / State-lifecycle declaration — AUG-3 addendum ingest). The reviewer now re-runs the plan's own enumeration searches against the working tree; unenumerated / phantom sites are FAIL.
- `scripts/plan_review.sh` — the chunked-review loop note now tags cross-artifact contracts (producer↔consumer value flows, enumeration↔tree call-site sets) as findings tagged **`UNVERIFIED-CROSS-CHUNK`** with status `ADVISORY`. An unverified internal enumeration is a real issue, not an invented one.
- `EXECUTION_PROTOCOL.md §8` — appended the **Deviation Review Feedback Loop** clause: a devlog entry claiming "Deviations from plan: none" is valid only if the executor re-read the task's STRUCTURE against the actual diff before writing the claim; any deviation entry quotes the plan text it deviates from and names what was done instead; numeric tallies in review tables are recomputed from the table's rows at write time — they are never recalled (AUG-4 addendum ingest).
- `EXECUTION_PROTOCOL.md §9 Review Remediation & Guard Re-pointing` — extended the re-pointing rule from gate-forced refactors to *any* invalidating change: **`Guard co-scheduling`** updates the asserting artifact in the same task as the invalidating change, or records the plan's declared stale window. New checklist line: **Run every guard that reads any file this task touched — not only the guards the task's VERIFICATION lists** (AUG-4 addendum ingest).
- `agent_planning/openspec/specs/plan-gate-selfcheck/spec.md` — new behavioral spec for the rerun contract: three Requirement blocks (Exact-count re-execution; Non-current claims are exempt from re-execution — covers `✅ VERIFIED-ABSENT` and `⚠️ UNTESTED` marks; Self-test coverage) and five Scenario blocks (count matches / count drifts / tested absence / expectation line with baseline quote / self-test). Authored directly as the living spec — the `/opsx` proposal machinery was not available in this session, recorded as a deviation.

### Changed

- `PLAN_CORE.md §2 Change-Impact Enumeration` — first table row broadens to: "Interface change (any callable signature or parameter meaning, including module-private / unexported functions; exported symbol, API shape, DB column, config key, event/message field, CLI flag)"; evidence cell mandates the pasted dependent listing with match count. A prose catch-all paragraph follows: "A prose catch-all … is **not** enumeration"; "visibility has nothing to do with blast radius" (M2 wording). §12 R-range header renames `(R1–R11)` → `(R1–R12)`.
- `addenda/{software,code-quality,automation,infrastructure}.md` — R1–R11 → R1–R12 rename in the Cross-cutting framework rules paragraph, with the compressed R12 clause mirrored per `code-quality.md §DR-1`. software.md's Change-Impact Dependent Discovery gains the same enumeration wording as PLAN_CORE §2.
- `scripts/plan_selfcheck.sh` — new SELF_TEST fixtures (6 total: incumbent bad/good + good_count with ellipsis-span guard + bad_count + absence-mark + untested-expectation); summary line assertions capture stdout (`rerun: N executed`) rather than relying on exit code alone.
- `openspec/README.md` — Current Specs table row appended for `plan-gate-selfcheck`.

### Rejected

- **Per-task style gate** — already `code-quality.md §CQ6` (MAINTAINABILITY CHECK per task); the prior failure (F1 nested ternary) was a compliance failure of an existing rule, not a missing rule. AUG-5 closes the only real gap (`cq_task_missing` was missing the MAINTAINABILITY presence item).
- **Budget ⇒ named decomposition** — already `code-quality.md §CQ10`; the prior failure (F2 complexity) was a compliance failure of an existing rule, not a missing rule.

## 2026-09-26 — Acceptance-validity hardening (R8–R11): assertable, baseline-checked, behaviour-anchored

Origin: a post-implementation Code Review found that a plan's stated Task-8
acceptance checks could not pass against their own pre-change baseline (a
nested-ternary check on a file that already had three), a z-index instruction
misread the DOM stacking context, and a "names only" criterion was ambiguous;
the executor also reshaped code around a brittle source-level guard. The fixes
below close those failure classes, project-agnostically.

### Added

- `PLAN_CORE.md §2` — four new cross-cutting rules:
  - **R8 Assertable acceptance** — every acceptance criterion is a binary,
    mechanically checkable assertion; no subjective adjective stands as a
    criterion; rendered/serialized criteria name the assertion that proves them.
  - **R9 Baseline-verified absolutes** — every absolute/negative check
    ("returns nothing", "finds no X", "expect 0", "is empty") is run against the
    pre-change tree at authoring and cited, or scoped to the diff, or the
    baseline is cleared by the plan. An unbaselined absolute may be unsatisfiable.
  - **R10 Behaviour-anchored tests and guards** — static/source-level guards
    assert behaviour or a stable identity, never incidental expression text or
    line numbers; gate-forced refactors re-point the guard and log it.
  - **R11 Review-remediation authority** — STOP RULES are task-scoped; the Code
    Review task may remediate an earlier artifact (guards included) and logs it.
- `PLAN_CORE.md §9` — Verification Integrity Rule gains the
  **capture-at-completion** requirement (re-capture after a task's final edit).
- `PLAN_CORE.md §12` — checklist rows for R8–R11.
- `scripts/plan_selfcheck.sh` — new static check 5: absolute/negative acceptance
  with no baseline result, no diff scope, and no `⚠️ UNTESTED (baseline)` mark.
  Forward-only on the existing `zed_plans/*.md` corpus (pre-adoption failures
  tolerated), matching the `plan_lint.sh` policy. Self-test fixtures extended.
- `prompts/plan_review_rubric.md` v1.2 — R8–R11 semantic checks; the reviewer
  must now attempt each absolute check against the working tree (R9) and flag it
  when the baseline violates it.
- `EXECUTION_PROTOCOL.md §9` — "Review Remediation & Guard Re-pointing" (R10/R11
  mechanics + capture-at-completion).
- `addenda/code-quality.md §CQ9.1` — the review task must name the pre-change
  baseline command for every absolute/negative check, and carry the R11
  remediation clause.

### Changed

- `PLAN_CORE.md §2/§12`, `addenda/{automation,infrastructure,software,code-quality}.md`,
  `prompts/plan_review_rubric.md` — R-list header and enum `R1–R7` → `R1–R11`.
- `agent_planning/AGENTS.md` — self-check bullet describes the new R9 check.

## 2026-09-12 — Framework hardening (DR-1..DR-5): R5/R7, P8a–P8j, mirror fix

Plan: `zed_plans/plan_framework_hardening_2026-09-11.md` (12 tasks; bootstrap
gated by R7 review `minimax/MiniMax-M3` A/92 with 0 FAILs; DR-1..DR-5
operator-approved before Task 1).

### Added

- `PLAN_CORE.md §2/§6/§8.5/§12` — R5 reworded to evidence-cited (every
  verification-claim item carries `command + date`); new **R7 — Pre-execution
  semantic review** (recorded review line; reviewer tool stays advisory, exit 0).
  §6 provenance rule extended to require `✅ VERIFIED via …` (with command and
  date) or `❌ ASSUMED` on every repo-state assertion. §8.5 stop-rule annotated
  with scope and a cross-reference to §6. §12 checklist adds R7, evidence-cited
  R5, repo-state-provenance, Tier-3-embedding, and Operating Model items.
- `addenda/software.md` §S1/§S4/§S7 — implementation-repo rule for spec
  existence + OpenSpec dialogue record; Go visibility rule for unexported
  tests; §S7 checklist updated.
- `addenda/infrastructure.md` §A1/§A13 — mandatory toolchain rows (compiler /
  runtime version with `✅ VERIFIED` command; complexity tool PATH status with
  invocation-prefix workaround); §A13 checklist updated.
- `addenda/code-quality.md` §CQ1/§CQ8 — version strings resolved by command at
  authoring time; `latest` is a non-compliant value; R-list updated to R1–R7.
- `scripts/plan_lint.sh` — six new deterministic checks (forward-only;
  `--report-phase2` makes the Phase-2 checks diagnostic-only without
  incrementing `FAILS`; `--enforce-phase2` was added in Task 6 then **REMOVED
  2026-09-12** per operator decision F1/F2 after the cross-model review showed
  the Phase-2 corpus had residual false positives):
  **P8a** DEVLOG step per task, **P8b** per-task full-section presence,
  **P8c** `latest` hard-fail (table cell or `Version:`), **P8d** DR
  non-empty Assumptions, **P8e** claim-evidence regex (date + command token),
  **P8f** DR citation only on non-review/non-doc/non-closeout tasks,
  **P8g** broadened P1 command regex + Provenance Legend exemption inside
  VERIFICATION sections, **P8h** multi-repo detector (WARN-only),
  **P8i** token-budget detector (WARN-only), **P8j** per-task
  complexity/DRY/CONTEXT7 language. `task_bodies()` helper extracted once
  (single definition reused by P8a/P8b/P8d/P8e/P8f/P8j). `P5` trigger regex
  made case-insensitive so sentence-initial capitalized destructive verbs
  don't escape the gate.
- `scripts/init_execution_dir.sh` — deterministic **R7 recorded-line gate**
  (refuses bootstrap when the preamble line is absent or records an unresolved
  `FAIL`); reads reviewer JSON and echoes the finding count with a
  `REQUIRED-RESOLVE` notice when any status is `FAIL`; appends reviewer
  summary to `SESSION_BRIEF.md`; honors `--skip-r7-gate` override;
  outer timeout `PLAN_REVIEW_TIMEOUT:-1500` to outlive the per-chunk review
  timeout. No-plan invocation crash fixed (`a587db0`).
- `scripts/plan_review.sh` — chunking at `### ` boundaries (default `MAX_BYTES:-48000`)
  with `split_plan`/`merge_json` that preserves the model label across chunks;
  python-based error-JSON envelope (quote-safe) with no-python3 ripgrep
  fallback; R7 line extraction (awk-extend-to-next-heading); raw-field cap
  raised so full finding JSON survives markdown-fenced wrapping.
- `scripts/sync_protocol.sh` — added `scripts/plan_review.sh` and
  `prompts/plan_review_rubric.md` to `CANONICAL_FILES`; portable `dirname`
  discover (no GNU `-printf`); dst-is-dir guard; recursive dir sync+verify;
  unknown args `exit 1`; **REAL SYNC** banner required; per-target
  verification pass.
- `prompts/plan_review_rubric.md` — schema enum `R1..R7` / `P1..P8`; R7
  semantic check + recorded review line; grading dimension 5 now covers
  review placement.
- `AGENTS.md` — "Before Task 1" adds R7 step (recorded-line gate) +
  `--report-phase2` note (Phase-2 lint checks are diagnostic-only).
- `scripts/test/fixtures/` — 12 new lint smoke fixtures (`p8a_missing_devlog`,
  `p8b_missing_section`, `p8c_latest_version`, `p8_p5_capitalized_delete`,
  `p8_clean`, `p8d_no_assumptions`, `p8e_unbacked_claim`,
  `p8f_review_task_no_dr` (must pass — review exemption),
  `p8f_impl_task_no_dr` (must fail), `p8g_unmarked_make`,
  `p8j_missing_quality_gate`). The manifest excludes `scripts/test/`
  (dev-only fixtures, recorded here).
- `EXECUTION_PROTOCOL.md §4.1` — explicit commit/stage policy: runtime state
  + KB writeback commit in-session; source/protocol-doc commits staged unless
  operator authorizes; ratify `[PROCESS]` at closeout. §10 lists the
  `deepseek/` and `minimax/` addenda references (the historical `claude/`
  +`openai/` refs were retired).
- `openspec/README.md` — replaced the "(none yet)" Current Specs row with
  the existing `health-check-*` capabilities.

### Changed

- `deepseek/PLAN_INSTRUCTIONS.md` §2/§5/§8/§14 — XML-vs-bold-label
  contradiction resolved: bold-label sections are canonical; XML elements
  are documentation only. Per-task `reasoning`/`temperature` retained as
  an optional annotation line.
- `deepseek/MODEL_ADDENDUM.md` D2/D3/D11 — same convergence.
- `prompts/README.md` (5 sites) and `cursor_rules/agent-planning.mdc` —
  stale `claude/`+`openai/` addenda refs → `deepseek/`+`minimax/`.
- `PLAN_CORE.md` Tier-2 row reworded (removed the "5–15 vs >15" contradiction
  surfaced by the cross-model review).
- `[DDW] Makefile` — removed the stale `wiki-migrate` token from the `clean`
  target (the binary was renamed to `wiki-cli`; C1 false-assertion root cause).
- `knowledge/services/dnd-workflow.md` — `sources:` block refreshed
  (`wiki-migrate` → `wiki-cli` paths; historical verification-notes
  preserved per KB append-only rule); `updated:` bumped to 2026-09-11.
- `scripts/quality_gate.sh` is now the documented complexity tool
  everywhere; the `gocyclo` off-PATH failure mode from the source review is
  cited as the ACCESS-table motivation.

### Removed

- `--enforce-phase2` flag (operator decision F1/F2 — Phase-2 promotion
  redesigned as a follow-up plan after the cross-model review showed the
  Phase-2 corpus still had residual false positives; current Phase-2
  checks remain diagnostic-only via `--report-phase2`).

### Cross-model Code Review (Task 11 — MiniMax-M3)

`prompts/plan_review_rubric.md` R1–R7 + P1–P8 across `plan_lint.sh`,
`init_execution_dir.sh`, `sync_protocol.sh`, `PLAN_CORE.md`,
`EXECUTION_PROTOCOL.md`. Grades: `plan_lint.sh` A-/87 (0 FAIL, 10 ADV);
three other scripts B+/78 (6 FAIL, 14 ADV); PLAN_CORE + EXECUTION_PROTOCOL
B-/68 (6 FAIL — mostly cross-doc false positives, 8 ADV). **9 distinct
FAIL findings resolved** (`f7113c2`). Per-check disposition table at
`agent_planning/execution/plan_framework_hardening/artifacts/t11/CQ9.3_findings.md`.

### Mirror sync (Task 10 — DR-4 Option B)

`sync_protocol.sh` wrote the manifest to all 7 `KNOWN_REPOS` targets
(`scratch_pad` self-skipped). `silverblue-desktop` carries the tracked
subset (`PLAN_CORE.md`, `EXECUTION_PROTOCOL.md`, `prompts/README.md` under
`agent_planning/`; `scripts/` gitignored by design). `openshift-sv-tools-dev`
left untracked per operator. Per-mirror commits: D&D_Workflow `b2b0904`,
silverblue-desktop `acc05eb`, infra-playbooks `8a29c3e`, monkeyplug
`28853f3`, Whisper-WebUI `1e44dcf`, OpenAudible-To-AudioBookShelf `e103f1c`.

### Policy

- Forward-only: existing plans in `zed_plans/*.md` are never re-graded;
  pre-adoption Phase-1 failures on older plans are tolerated.
- Reviewer tool stays advisory (exit 0 on findings); the recorded-line
  gate in `init_execution_dir.sh` is the only mandatory enforcement.
- `--enforce-phase2` deliberately absent — Phase-2 promotion is a
  follow-up plan gated on false-positive review.

### Ratified [PROCESS] deviations (F9 — Task 12 closeout)

Per `EXECUTION_PROTOCOL.md §4.1` commit/stage policy, the following
source/protocol-doc commits were made without explicit operator
authorization at the time. The operator's "finish the remaining steps in
the plan" directive of 2026-09-12 retroactively authorizes them. All
five commits re-verified before closeout:

- `a587db0` — `init_execution_dir.sh` no-plan crash + manifest guard
- `a506283` — `--enforce-phase2` removal (operator decision F1/F2)
- `6cb4f4f` — F4–F6 durable fixes (R5 self-attestation, deployment
  classification, code-signal detector gap)
- `92a0d34` — Task 11 in-scope defect fixes
- `5987f81` — pedantic-review matrix fixes (12/13)

## 2026-09-10 — Pre-deployment code review gate (CQ9.6 / R6 / P7)

### Changed
- `addenda/code-quality.md` §CQ9 — Code Review placement is now **phase-aware**: penultimate (`N-1`) for non-deployment plans; **immediately before the first deploy/apply task** for deployment plans. Added **§CQ9.6** defining a deployment task and the pre-deployment ordering/gating rules; §CQ9.2 gate text generalized from "Task N-1" to "the Code Review task".
- `PLAN_CORE.md` §2/§12 — new cross-cutting rule **R6** (pre-deployment review gate) + checklist item; the Code Quality Gate Code Review bullet now distinguishes penultimate vs pre-deploy placement.
- `EXECUTION_PROTOCOL.md` §9 — new **Pre-Deployment Review Gate** subsection: no deployment task may start until the review passes.
- `addenda/infrastructure.md` — new **§A14** (pre-deployment code review gate) + checklist item.
- `addenda/software.md` §S7 and `addenda/pipeline.md` §P8 — Code Review ordering checklist items updated for the two layouts.
- `scripts/plan_lint.sh` — new **P7** check: deployment plans must place the Code Review heading before the first deploy/apply heading. Detection is **task-heading only** (authoring-verb and `Code Review` headings excluded to avoid noun false positives), with `Deployment phase: yes` / `Deployment phase: N/A` preamble overrides.
- `prompts/README.md` — execution Code Review pause text now covers deployment plans.
- `prompts/plan_review_rubric.md` — grading dimension 5 now covers review placement; added **R6** semantic check and **P7** expectation.
- `deepseek/PLAN_INSTRUCTIONS.md` §2.5, `minimax/PLAN_INSTRUCTIONS.md` §13.O — ordering rule (authoring → functional test → Code Review → deploy) + checklist items.
- `scripts/test/fixtures/` — added `bad_deploy_before_review.md` (P7 FAIL) and `good_review_before_deploy.md` (P7 PASS).

### Rationale
Deployment scripts, playbooks, and configs must be reviewed **before** they
mutate a live system. The prior penultimate-only placement meant the review
happened after the artifacts had already been deployed.

### Policy
- Forward-only: existing plans are not re-graded. `plan_lint.sh` runs without
  crashing against the existing `zed_plans/` corpus (27/27, 0 crashes); P7 is
  fail-closed for new deployment plans only.

## 2026-09-09 — Planning framework enforcement: P1–P6 lint rules, R1–R5 core rules, semantic reviewer

Plan: `zed_plans/plan_framework_enforcement_2026-09-09.md`

### Added
- `scripts/plan_lint.sh` — six new deterministic checks, forward-only (fail-closed on new code-producing plans, existing `zed_plans/` never re-graded): **P1** command provenance (`✅ TESTED`/`📖 FROM-DOCS`/`⚠️ UNTESTED`), **P2** no conditional-branch phrases in task bodies, **P3** no angle-bracket placeholders, **P4** full task-section completeness + NAMING on new-file tasks (`--require-full-tasks`), **P5** destructive-op gate (STOP RULE / OPERATOR CONFIRM), **P6** CQ9.2 / A11 / A12 marker presence.
- `scripts/plan_review.sh` — one-shot cross-model semantic reviewer wrapper (DR-2). Runs `opencode run -m minimax/MiniMax-M3 --pure` with an ANSI-strip + JSON-extraction layer; advisory only (exits 0 on findings, 1 only on invocation failure).
- `prompts/plan_review_rubric.md` — versioned 10-dimension grading rubric + R1–R5 semantic checks + JSON output schema.
- `PLAN_CORE.md §2` — cross-cutting framework rules **R1–R5** (operator gate, async drain, result-schema, skill transcription, §12 self-review); mirrored in §12 checklist.
- `addenda/{software,automation,infrastructure,code-quality}.md` — §checklists now reference R1–R5.
- `scripts/test/fixtures/` — three lint smoke-test fixtures (P1, P5-fail, P5-pass).

### Changed
- `init_execution_dir.sh` — after the deterministic lint gate, invokes `plan_review.sh` in advisory mode (logs findings count, never blocks bootstrap).

### Policy
- Enforcement is forward-only: existing plans are never re-graded; `plan_lint.sh` must still run without crashing against them (corpus smoke test: 27/27 plans, 0 crashes).

## 2026-08-08 — Plan storage renamed to zed_plans; sync gaps closed

### Changed
- `PLAN_CORE.md` §8, `EXECUTION_PROTOCOL.md`, `prompts/README.md`, `scripts/init_execution_dir.sh` — plan documents are stored in `./zed_plans/` (was `./cursor_plans/`); matches `deepseek/` and `minimax/` PLAN_INSTRUCTIONS
- `scripts/sync_protocol.sh` — registered `scratch_pad` in KNOWN_REPOS; added `deepseek/MODEL_ADDENDUM.md` and `minimax/MODEL_ADDENDUM.md` to the sync list (identical across repos; PLAN_INSTRUCTIONS intentionally excluded — monkeyplug carries custom copies)

## 2026-08-01 — Fail-closed plan lint and quality gate

### Added
- `scripts/plan_lint.sh` — structural CQ gate before Task 1 (CQ9 penultimate Code Review, DRY audit, complexity VERIFICATION, language declaration); supports `--require-full-tasks` and `--allow-non-code`
- `scripts/quality_gate.sh` — language-parameterized complexity gate (`ruff` / `gocyclo` / `eslint` / `shellcheck`); `--lang auto` by extension; optional `--info-radon` for Python informational CC
- `code-quality.md` §CQ10 — decomposition heuristic for multi-check / aggregate evaluators

### Changed
- `init_execution_dir.sh` — accepts `--plan <path>` and runs `plan_lint` before bootstrap; `--skip-plan-lint` emergency-only
- `EXECUTION_PROTOCOL.md` §3.0 plan-lint gate; §5.1 and §9 Enforcement use `quality_gate.sh` (not raw radon)
- `PLAN_CORE.md` §12 — Code Quality Gate aligned to `plan_lint` / `quality_gate` / CQ9 penultimate-only rule
- `code-quality.md` CQ2/CQ7 — Python authoritative complexity tool is Ruff; radon informational
- `software.md` S7, `prompts/README.md`, `AGENTS.md`, `.cursor/rules/agent-planning.mdc` — bootstrap and gate wiring

## 2026-07-28 — Portability cleanup and capability additions

### Removed
- **Knowledge Base subsystem** — removed the `MANDATORY` KB Consultation step from `PLAN_CORE.md` Section 0 (was hard-wired to `~/git_projects/scratch_pad/knowledge/`, a path that does not exist outside the original author's environment)
- `addenda/infrastructure.md` §A5 "Home Lab Documentation Update" — removed mandatory rule requiring updates to `~/git_projects/home-lab/`
- `addenda/infrastructure.md` §A6 "Knowledge Base Update" — removed mandatory KB writeback rules
- `addenda/pipeline.md` §P7 "No KB Writeback Required" — now redundant with §A6 gone
- KB checklist bullets from `PLAN_CORE.md` §12, `addenda/software.md` §S7, `addenda/automation.md` §AU7, and `EXECUTION_PROTOCOL.md` §8
- YAML frontmatter (`repo: scratch_pad`, `topic`, `tags`, etc.) from `addenda/INDEX.md`

### Changed
- **Generic examples** — replaced identifying home-lab hostnames (`x86experts.com`), IP ranges (`192.168.99.x`), project names (`valetudo_flash_prep`), and sensor names (`sensor.total_house_power_draw`) with generic placeholders throughout all files
- `openspec/README.md` — replaced stale "Current Specs" table (consumer-project rows) with an empty template row

### Added
- `TIER1_FASTPATH.md` — condensed one-page path for single-file, <5 task, no-deployment tasks; eliminates full protocol overhead for trivial work
- `scripts/init_execution_dir.sh` — bootstraps a Tier 2/3 execution directory with pre-populated `SESSION_BRIEF.md`, `HANDOFF.md`, `TASK_QUEUE.md`, `devlogs/`, and `artifacts/` from the templates in `EXECUTION_PROTOCOL.md §7`
- `scripts/secret_scan.sh` — automated secret scanner (uses `gitleaks` if available, regex fallback otherwise); wired into `EXECUTION_PROTOCOL.md §9` Code Review Checkpoint as a required gate
- `scripts/sync_protocol.sh` — syncs canonical framework files to downstream project repos; supports `--dry-run` and `--discover` modes
- `addenda/creative.md` — new addendum for written content work (blog posts, documentation narratives, editorial rewrites); reduces ceremony, simplified 4-question interview
- `claude/MODEL_ADDENDUM.md §C6.5` — Sonnet-specific explicitness guidance (scope quantification, pattern `DIFFERENT:` callout, constraint carry-forward)
- `CHANGELOG.md` (this file)
- `Last updated:` markers on all core framework files

## 2026-09-27 — Protocol simplification (R-rule dedup, state collapse, R5 automation, opt-in round-trips, telemetry)

Origin: `zed_plans/protocol_simplification_2026-09-27.md` (Tasks 1–13). The plan took items 1–11 of the ten-item scope; item 8 (off-path PLAN_INSTRUCTIONS deprecation) and item 10 (tier-gated R7) were operator-accepted in the narrow form per DR-2/DR-3.

### Added

- `scripts/plan_lint.sh` — new `check_r5_coverage` check (Task 2): counts plan lines carrying an evidence mark + `YYYY-MM-DD` date and emits the count as advisory PASS output. The R5 §12 coverage number is now emitted by the lint instead of being hand-typed.
- `scripts/plan_review.sh` — `run_selfcheck` helper + `-f` second-attachment (Task 3): the deterministic `plan_selfcheck.sh` output is attached to the reviewer invocation. Reviewer session nonce appended to the rubric note so re-reviews reflect edited plans (no more stale-finding reuse).
- `scripts/init_execution_dir.sh` — `--r7-waived` flag (Task 10): records `R7 waived (narrow trigger)` in STATE.md and emits a `TELEMETRY r7_waived project=...` line for the new telemetry sink. STATE.md migration path (Task 7): when SESSION_BRIEF.md or HANDOFF.md exist but STATE.md does not, both legacy files are merged into STATE.md via one awk-extract pattern (no per-section copy-paste).
- `agent_planning/TELEMETRY.md` + `agent_planning/execution/_telemetry.jsonl` (Task 11): JSONL schema for `plan_review` and `init_execution_dir` hooks. Local-only append; gitignored.
- `prompts/plan_review_rubric.md` v1.3 → v1.4 (Task 3): items 5/6 defer to the attached self-check output; Bias section notes reviewer tool access.
- `scripts/test/fixtures/p2_decision_branch.md` + `p2_fallback_allowed.md` (Task 1): new fixtures for the narrowed P2 scan.

### Changed

- `scripts/plan_lint.sh` `check_no_conditionals` (Task 1): replaced the broad token ban with a decision-branch pattern (`^[Ii]f <cond>, <consequence>` plus bullet-prefix variant) plus the three standalone branch connectors (`or equivalent`, `whichever`, `one of`). Lines starting with the literal `If ANY check fails` prefix are exempt (canonical access-gate fallback form).
- `PLAN_CORE.md §2 R5` + §12 R5 row (Task 2): `§12 pass: <n>` preamble number is optional when the lint-emitted count is preserved in the devlog. The per-item evidence requirement is preserved.
- `addenda/{software,code-quality,infrastructure,automation}.md` (Task 4): R1–R12 restatements replaced with a single pointer line to `PLAN_CORE.md §2`. Each addendum retains its domain-specific trigger bullets.
- `addenda/code-quality.md §CQ9.2` (Task 5): mandatory model-switch pause → opt-in (default to current model; one-line operator request triggers the switch).
- `addenda/code-quality.md §CQ1` (Task 6): per-task re-query of context7 → query happens at authoring and at the Code Review task. Per-task re-query not required unless the task cites a different library version. `API-DRIFT` tag preserved.
- `EXECUTION_PROTOCOL.md` (Task 7): directory layout collapses SESSION_BRIEF.md + HANDOFF.md → STATE.md (single recovery file); artifact roles table, session read order, §4 writeback, §7 templates all updated.
- `EXECUTION_PROTOCOL.md §8` (Task 11): new "Closeout Counterfactual" subsection names the counterfactual prompt and points at the telemetry sink.
- `EXECUTION_PROTOCOL.md §9` (Task 5): pre-deployment gate cross-ref to CQ9.2 → opt-in form.
- `PLAN_CORE.md §9` + §12 (Task 8): devlog placeholder "Remaining Tasks" reduced to a one-line pointer at TASK_QUEUE.md; the regeneration rule is removed. The devlog is no longer required to maintain a separate "Remaining Tasks" checklist.
- `PLAN_CORE.md §2 R7` + §12 R7 row (Task 10): narrow trigger — REQUIRED for Tier 3 plans and for Tier 2 plans touching a remote system, public interface, schema/migration, secrets, or more than one repo; OPTIONAL (with `R7 waived (narrow trigger)` audit record) for local, non-public, deterministically verified Tier 2 plans.
- `PLAN_CORE.md §2 "No conditional branches"` (Task 1): one sentence naming the allowed fallback directive form (`If ANY check fails:` prefix).
- `prompts/README.md` (Task 5, Task 7): CODE REVIEW pause → opt-in form; resume prompts read STATE.md instead of SESSION_BRIEF.md + HANDOFF.md.
- `sync_protocol.sh` (Task 9): removed `deepseek/PLAN_INSTRUCTIONS.md` and `minimax/PLAN_INSTRUCTIONS.md` from the canonical sync list (the legacy top-level `agent_planning/sync_protocol.sh` — same edit). The newer `scripts/sync_protocol.sh` already excluded them with a documented comment.
- `AGENTS.md` (Task 9, repo root): KB-writeback citations repointed from `agent_planning/{minimax,deepseek}/PLAN_INSTRUCTIONS.md` to `PLAN_CORE.md §9.6` and the matching model addendum. "PLAN_INSTRUCTIONS task description" anti-pattern phrase removed.

### Deprecated

- `agent_planning/minimax/PLAN_INSTRUCTIONS.md` (Task 9): replaced with a 5-line redirect stub pointing at `PLAN_CORE.md` and `minimax/MODEL_ADDENDUM.md`.
- `agent_planning/deepseek/PLAN_INSTRUCTIONS.md` (Task 9): same, pointing at `deepseek/MODEL_ADDENDUM.md`.

### Held (not taken)

- Original item 8 (full PLAN_INSTRUCTIONS deprecation): taken in narrow form per DR-3 — the operator-gated mirror sync is the only other disposal needed and lives in DR-5.
- Original item 10 (broad tier-gated R7 waiver): taken in narrow form per DR-2 — see R7 above.

### Verification

- `bash agent_planning/scripts/quality_gate.sh agent_planning/scripts/*.sh` → PASS — shellcheck clean on all 6 shell scripts.
- `bash agent_planning/scripts/plan_lint.sh --require-full-tasks zed_plans/protocol_simplification_2026-09-27.md` → PASS — R5 §12 coverage: 10 evidence-cited lines (advisory).
- `bash agent_planning/scripts/plan_selfcheck.sh zed_plans/protocol_simplification_2026-09-27.md` → PASS — static checks clean.
- CQ9.3 review: 26 PASS, 1 ADVISORY, 0 FAIL. The single ADVISORY is the pre-existing false-positive in `scripts/secret_scan.sh` (the script's own regex pattern matches itself). Not introduced by this plan.

### R5 post-change count

Plan preamble recorded: `§12 pass: 10 items` (re-recorded at closeout against the post-change `PLAN_CORE.md §12` checklist, via the `plan_lint.sh` R5 §12 coverage check; see the lint PASS line above).

## 2026-09-28 — Whole-plan multi-file review (plan_review.sh)

Origin: three chunked machine review runs (B− 68 → B+ 85 → A− 88) graded the `caster_slot_editor` plan clean while it contained three feature-breaking cross-task contracts; the full-matrix manual review (`tmp/caster_slot_editor_review4_findings.md`) and the size analysis (`tmp/plan_size_report_2026-09-28.md`) traced the miss to chunk-blindness — each chunk reviewer could not see the other chunks' task bodies.

### Changed

- `scripts/plan_review.sh`: oversize plans are still split at task boundaries (each part stays under opencode's ~50 KB per-file attachment limit) but ALL parts + the deterministic self-check output are now attached to a SINGLE reviewer invocation, so one reviewer session sees the whole plan and cross-task producer↔consumer contracts are reviewable as ordinary findings (the `UNVERIFIED-CROSS-CHUNK` exemption is explicitly withdrawn in the multi-file note). The whole-plan run gets a 600 s timeout (240 s stays for single-file). On invocation failure or unparsable output, the wrapper falls back to the previous sequential per-part reviews — behavior is never worse than before. First live run (caster_slot_editor, 67 KB, 2 parts) caught a real cross-chunk defect — a §12 count drift between the preamble and §12 REVIEW NOTES — that three chunked runs had passed.
- `.gitignore`: `agent_planning/execution/_telemetry.jsonl` is now actually ignored (the 2026-09-27 entry documented it as gitignored; it was not).

## 2026-09-30 — opencode V2 CLI compatibility (plan_review.sh `--pure` removed)

Origin: opencode upgraded to V2 (`opencode v2.0.19`). V2 removed the V1 global
`--pure` flag ("run without external plugins"); `opencode run --pure …` now
exits 1 with `Unrecognized flag: --pure` and prints help instead of reviewing.
The wrapper treated the captured help text as non-JSON output, so every R7
review silently degraded to a `{"error":"non-json-output"}` envelope (first
noticed in the `blackbox_expansion_wekan_decom` session, which worked around it
with a manual reviewer invocation).

### Changed

- `scripts/plan_review.sh` — `detect_opencode_cli()` probes the CLI once and
  builds the invocation for the detected major version: on V1 it keeps
  `--pure`; on V2 (no such flag) it preserves the "no external plugins" intent
  with the documented `plugins` control list (`OPENCODE_CONFIG_CONTENT='{"plugins":["*","-*"]}'`),
  applied to the reviewer invocation only. This also neutralizes any V1-API
  global plugin that V2 refuses to load (e.g. the configured
  `@dietrichgebert/ponytail`, which logs a non-fatal load error under V2).

### Verified

- `bash -n scripts/plan_review.sh` → syntax OK; `quality_gate.sh scripts/plan_review.sh` → PASS (shellcheck clean).
- Live single-file review of `zed_plans/spook_orphan_statistics_purge_2026-09-09.md` → exit 0, grade B / score 78 / 38 findings (real rubric output, not an error envelope).
- V2 `-f` attachment confirmed to deliver verbatim file contents, including multiple `-f` files in order (exercised by the chunked multi-file path).
- `scripts/plan_lint.sh` reviewed and confirmed unaffected — it never invokes `opencode`; PASS on `plan_framework_hardening_2026-09-11.md` (phase 1 and `--report-phase2`).
