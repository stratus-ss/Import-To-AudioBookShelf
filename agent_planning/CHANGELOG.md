# Changelog

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
