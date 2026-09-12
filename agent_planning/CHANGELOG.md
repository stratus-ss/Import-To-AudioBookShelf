# Changelog

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
