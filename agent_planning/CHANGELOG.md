# Changelog

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
