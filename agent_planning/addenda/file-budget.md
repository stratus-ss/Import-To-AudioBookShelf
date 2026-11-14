# Plan Addendum — File Budget

Applies to: ANY plan that authors or modifies source files. This addendum is
cross-cutting — read it alongside the domain addendum, not instead of it.

Read this after `PLAN_CORE.md` and your domain addendum. All rules here are ADDITIVE.

This addendum defines the per-file line budget enforced by
`agent_planning/scripts/quality_gate.sh --file-budget`, the in-file sentinel that
authorizes a per-file override, and the exemption list. It is the canonical home
for the cap values, the sentinel syntax, and the skip patterns; the R13 rule in
`PLAN_CORE.md §2`, the `§CQ11` section in `addenda/code-quality.md`, and the gate
script all defer here.

---

## FB1. Per-language caps

| Language | Cap (lines) | Sentinel form |
|----------|------------:|---------------|
| JavaScript / TypeScript | **800** | `// file-budget: [N] — [reason]` |
| Go | **500** | `// file-budget: [N] — [reason]` |
| Python | **500** | `# file-budget: [N] — [reason]` |
| Bash | **200** | `# file-budget: [N] — [reason]` |

A single number either over-constrains small-language projects (a Bash cap of
800 would let installer-style files sprawl) or under-constrains JS/TS (a single
500-line cap would have forced the dnd-dashboard decompose plan to extract three
more modules beyond the seven it already created). Caps are therefore
language-conditional, matching the per-language pattern already used by
`code-quality.md §CQ2` and the `--lang auto` switch in `quality_gate.sh`. The
JS/TS number is set at 800 — above the decompose plan's working `battle.js ≤700`
— so the project's `battle-resolvers.js` (800 lines) is in scope on day 1 without
an override; anything above 800 declares a sentinel.

---

## FB2. In-file sentinel

A file may declare its own budget instead of the language default by placing a
sentinel comment in its **first 50 lines**:

- Go / TypeScript / JavaScript: `// file-budget: [N] — [reason]`
- Python / Bash: `# file-budget: [N] — [reason]`

`[N]` is the declared line budget (an integer). `[reason]` is free text of **at
least 30 characters** naming the plan or issue that justifies the override; a
sentinel with a shorter reason is a review finding (the reason is the audit
trail, so it must say something).

The sentinel is matched by exactly this regular expression (the em-dash is
U+2014; this is the single source of truth — the gate holds the same string as a
constant):

```
^\s*(//|#)\s*file-budget:\s*(\d+)\s*—\s*(.+)$
```

Sentinels outside the first 50 lines are ignored — the gate only reads the head
of the file, so a sentinel buried mid-file does not silence the default cap. A
sentinel is a stable string the gate greps for, satisfying the R10 rule that
guards anchor at a stable identity rather than a line number.

Example (Go / TypeScript / JavaScript):

```
// file-budget: 600 — resolver module; extraction tracked in zed_plans/<plan>.md
```

Example (Python / Bash):

```
# file-budget: 350 — framework quality gate; spec in addenda/file-budget.md
```

---

## FB3. Worked example

The rule exists because of a concrete failure. `D&D_Workflow`'s
`zed_plans/archive/dnd_battle_js_decompose_2026-10-01.md` (2026-10-01, archived
2026-10-02) began with a spec scenario that stated `battle.js` would stay at
`≤400` lines. Nothing enforced it. The file grew to **2454 lines** before the
decompose plan shipped, at which point the plan's own DR-3 recorded the missing
enforcement and added a per-project selfcheck (`scripts/battle_modules_selfcheck.mjs`)
as the local fix. The decompose brought the file down to 679 lines plus new
modules.

This addendum lifts that local fix to the framework level: the cap table
(§FB1), the sentinel (§FB2), the exemption list (§FB4), and the gate (§FB5 /
§FB7) make the constraint machine-checked for every plan, so the next
`≤400`-style claim cannot drift unenforced. The cross-link from the framework
rule is `PLAN_CORE.md §2 R13`.

---

## FB4. Skip / exemption list

The gate silently skips:

- **Tests** — `*_test.go`, `*_test.py`, `test_*.py`, `conftest.py`,
  `*.test.ts`, `*.test.tsx`, `*.test.js`, `*.test.jsx`, `*.spec.ts`,
  `*.spec.tsx`, `*.spec.js`, `*.spec.jsx`.
- **Generated** — `*.gen.go`, `*.gen.ts`, `*.gen.js`, `*_pb2.py`,
  `*_pb2_grpc.py`, `*.pb.go`, `*.pb.ts`, and anything under `dist/`, `build/`,
  `out/`, `.next/`, `target/`.
- **Vendored** — anything under `vendor/`, `node_modules/`, `third_party/`,
  `.venv/`, `venv/`, `__pycache__/`.
- **Repository metadata** — anything under `.git/` is never scanned.

Tests grow because they encode coverage; generated code is owned by its
generator; vendored code is owned by upstream; VCS metadata is not source. The
test fixtures installed under `scripts/test/fixtures/file_budget/` are
intentionally over-cap test data and are **not** exempt by pattern — the gate is
path-scoped (§FB7) and never scans them unless a plan passes them explicitly,
which the self-test does on purpose.

---

## FB5. Gate behavior

With `--file-budget`, each candidate file resolves to one effective cap:

- **Sentinel present in the first 50 lines** → the declared value is the
  effective cap. The gate reports it and fails if the file exceeds its own
  declared budget:
  - `[quality_gate] INFO — [path] sentinel [value] honored; file is [N] lines`
- **No sentinel in the first 50 lines** → the language default cap from §FB1
  applies. On exceed, the gate fails:
  - `[quality_gate] FAIL — file [path] is [N] lines (cap [M]); add a file-budget sentinel ([M] for Go/TS/JS via //, Python/Bash via #) or decompose`
- **Exempt or unmapped extension** → silent (no PASS/FAIL/INFO line).

The sentinel is therefore an *explicit per-file budget*, not a blanket
exemption: raising the number is a deliberate, reviewable act, and a file that
outgrows even its declared budget still fails. The single threshold and hard
fail are deliberate — a soft warning would not have stopped the 2454-line
`battle.js`.

---

## FB6. Checklist

For every plan that produces code:

- [ ] Every coding task's VERIFICATION includes
  `agent_planning/scripts/quality_gate.sh --file-budget [modified_paths]`
  (additive to the `--lang` complexity check).
- [ ] Every file over its language cap is decomposed, or carries a sentinel
  whose reason names the plan or issue that justifies the override.

---

## FB7. Enforcement

Invocation form:

```bash
agent_planning/scripts/quality_gate.sh --file-budget [paths]
```

- The mode is **orthogonal to `--lang`**: the language — and therefore the
  default cap — is detected per file from its extension. `--file-budget` with no
  path is a usage error.
- Directory arguments are walked **recursively**; single-file arguments are
  checked directly.
- Files whose extension does not map to a cap (per §FB1) are skipped silently.
- Enforcement is **per-plan**, not tree-wide: only the paths the plan passes are
  checked. A plan that does not touch a file never gates it. The rule trips on
  the next plan that touches an over-cap file — which is the desired behavior,
  because that is the moment a reviewer sees the size in the diff.
- Exit codes: **0** (no over-cap file) / **1** (at least one file over its
  effective cap).
