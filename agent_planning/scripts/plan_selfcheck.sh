#!/usr/bin/env bash
# plan_selfcheck.sh — pre-review authoring self-check for plans.
#
# Run this BEFORE plan_review.sh so the semantic reviewer confirms rather than
# discovers the mechanical defects. Domain-neutral: it hard-codes no language,
# toolchain, or HTML/web concept.
#
# Static checks (always):
#   1. Near-duplicate bullet lines inside one task body (a copy-paste defect).
#   2. Bare line-number coordinates for source references ("line 597") — use a
#      stable identity instead (function/selector/key/section).
#   3. An interface-change task with no dependent enumeration.
#   4. Provenance marks (✅ TESTED / ✅ VERIFIED) with no backing evidence.
#   5. An absolute/negative acceptance check ("returns nothing", "finds no
#      nested X", "returns no matches", "is empty") with no baseline result,
#      no diff scope, and no ⚠️ UNTESTED (baseline) mark (PLAN_CORE R9).
#      Forward-only on the existing zed_plans/*.md corpus — pre-adoption
#      failures are tolerated, matching the plan_lint.sh forward-only policy.
#
# Optional:
#   --rerun       re-execute the safe-whitelisted ✅ TESTED commands; a line
#                  stating an exact count as `→ N lines|hits|matches|occurrences|
#                  results|files|rows|entries` is asserted against the live
#                  output (`wc -l`). Lines marked
#                  ✅ VERIFIED-ABSENT or ⚠️ UNTESTED are exempt from rerun
#                  re-execution (a tested absence exits non-zero; an UNTESTED
#                  line states an expectation, not a tested fact). Commands
#                  run verbatim in the caller's cwd — rerun-eligible plan
#                  commands must use absolute paths.
#   --verify-paths advisory: flag backticked repo-relative path citations that do
#                  not resolve to a real file (archived/renamed/phantom). Never
#                  affects the exit code. Catches stale citations such as a plan
#                  that moved to zed_plans/archive/ or a renamed directory.
#   --self-test   run embedded fixtures and assert the checks fire.
#
# Usage: plan_selfcheck.sh [--rerun] [--verify-paths] <plan.md>
#        plan_selfcheck.sh --self-test
# Exit: 0 = pass, 1 = findings, 2 = usage/IO.

set -euo pipefail

CHECK() {
  # $1 = plan path; prints findings, returns 1 when any exist.
  python3 - "$1" <<'PY'
import re, sys

path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
except OSError as err:
    print(f"[plan_selfcheck] FAIL — cannot read {path}: {err}", file=sys.stderr)
    sys.exit(2)

task_starts = [i for i, l in enumerate(lines) if re.match(r"^#{2,3}\s+Task\s+\d+", l)]

def tasks():
    for k, s in enumerate(task_starts):
        e = task_starts[k + 1] if k + 1 < len(task_starts) else len(lines)
        yield lines[s], lines[s:e]

def label(title):
    return title.split(":", 1)[-1].strip()

def norm(l):
    l = re.sub(r"^\s*([-*]|\d+[.)])\s+", "", l).strip().lower()
    return re.sub(r"\s+", " ", l)

findings = []

# 1) near-duplicate bullets within one task body.
# ponytail: prefix-60 comparison, enough to catch copy-paste; fuzzy near-dup is
# the semantic reviewer's job.
for title, body in tasks():
    seen = {}
    for l in body:
        n = norm(l)
        if len(n) < 60:
            continue
        key = n[:60]
        if key in seen and seen[key] != n:
            findings.append(f"{label(title)}: near-duplicate bullet — '{n[:70]}...'")
        seen.setdefault(key, n)

# 2) bare line-number coordinates in task bodies.
for title, body in tasks():
    for l in body:
        if re.search(r"\bat line \d+|\blines? \d+(-\d+)?\b", l):
            findings.append(f"{label(title)}: bare line-number coordinate — '{l.strip()[:70]}'")

# 3) interface change without a dependent enumeration.
for title, body in tasks():
    t = " ".join(body).lower()
    changed = re.search(r"signature|new parameter|changed signature|renamed (function|export)", t)
    enumerated = re.search(r"caller|dependen|consumer|impact", t)
    if changed and not enumerated:
        findings.append(f"{label(title)}: interface change without a dependent enumeration")

# 4) provenance mark without backing evidence (a date or a command).
for l in lines:
    if re.match(r"^\s*[-*]?\s*✅ (TESTED|VERIFIED)\s*—", l):
        continue  # provenance-legend definition, not a claim
    if ("✅ TESTED" in l or "✅ VERIFIED" in l) and not re.search(r"20\d\d|`", l):
        findings.append(f"provenance without evidence — '{l.strip()[:70]}'")

# 5) absolute/negative acceptance without a baseline result or a diff scope.
# Domain-neutral: the pattern list is natural-language; it hard-codes no
# language or toolchain. It targets explicit absence assertions ("returns
# nothing", "finds no X", "no matches", "is empty") rather than a bare policy
# noun-phrase ("no nested ternaries"), which is usually a rule not a check.
# Diff-scoped phrasing (introduced/added by/…) and an explicit
# ⚠️ UNTESTED (baseline) mark are both treated as compliant.
ABS = re.compile(
    r"\b(?:returns? nothing|returns? no\b|finds? no\b|no matches|"
    r"(?:is|are)\s+empty|must not contain|does not contain)\b",
    re.I,
)
SCOPED = re.compile(
    r"\b(?:introduced|added by|newly|during this|baseline|pre-change|"
    r"against HEAD|scoped to (?:the )?diff|diff-scoped|existing|"
    r"current tree|before this plan)\b",
    re.I,
)
BASELINE_MARK = re.compile(r"⚠️\s*UNTESTED\s*\(baseline\)", re.I)
for title, body in tasks():
    for l in body:
        if ABS.search(l) and not SCOPED.search(l) and not BASELINE_MARK.search(l):
            findings.append(
                f"{label(title)}: absolute acceptance without baseline — "
                f"run it against the pre-change tree, scope it to the diff, or "
                f"mark '⚠️ UNTESTED (baseline)' — '{l.strip()[:70]}'"
            )

for f in findings:
    print(f"[plan_selfcheck] FAIL — {f}")
if findings:
    sys.exit(1)
print("[plan_selfcheck] PASS — static checks clean")
PY
}

RERUN() {
  # Re-execute only commands whose first token is on the safe whitelist. A
  # plan line carrying the `✅ VERIFIED-ABSENT` or `⚠️ UNTESTED` mark is
  # intentionally NEVER re-executed (a tested absence exits non-zero; an
  # untested line states an expectation — rerunning either would false-fail
  # — see PLAN_CORE §6 rerun-exemption semantics). When the plan line
  # states an exact stdout line count as `→ N lines`, N is asserted against
  # the live output (`wc -l`). Commands' stdin is redirected from /dev/null
  # so a stdin-reading command cannot swallow the loop's inherited queue.
  local plan="$1" ran=0 failed=0 snippet expected out rc live
  while IFS=$'\t' read -r snippet expected; do
    [[ -z "$snippet" ]] && continue
    case "$snippet" in
      node\ *|rg\ *|go\ build*|go\ test*|go\ vet*|make\ *|bash\ -n*|shellcheck\ *|eslint\ *|ruff\ *|gocyclo\ *|agent_planning/scripts/quality_gate.sh*|agent_planning/scripts/plan_lint.sh*)
        ran=$((ran + 1))
        out="$(bash -c "$snippet" </dev/null 2>/dev/null)" && rc=0 || rc=$?
        if [[ "$rc" -ne 0 ]]; then
          echo "[plan_selfcheck] FAIL — ✅ TESTED command failed: $snippet" >&2
          failed=$((failed + 1))
        fi
        if [[ -n "$expected" ]]; then
          live=0
          [[ -n "$out" ]] && live="$(printf '%s\n' "$out" | wc -l)"
          if [[ "$live" -ne "$expected" ]]; then
            echo "[plan_selfcheck] FAIL — rerun count mismatch: $snippet stated $expected, got $live" >&2
            failed=$((failed + 1))
          fi
        fi
        ;;
      *)
        echo "[plan_selfcheck] skip — non-whitelisted ✅ TESTED command: $snippet" >&2
        ;;
    esac
  done < <(python3 - "$plan" <<'PY'
import re, sys
# Only command-like backticked spans are candidates; a bare filename or
# symbol on a ✅ TESTED line is not a command. Lines whose source carries
# the `✅ VERIFIED-ABSENT` mark are skipped — a tested absence must not be
# re-executed; rerunning it would false-fail on non-zero exit. When the
# plan line states an exact stdout line count as `→ N lines`, N is emitted
# as a second tab-separated field for the bash loop.
safe = re.compile(r"^(node|rg|go|make|bash|shellcheck|eslint|ruff|gocyclo|agent_planning/scripts/)")
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if "✅ TESTED" not in l:
        continue
    if "✅ VERIFIED-ABSENT" in l:
        continue
    # A line whose own mark is ⚠️ UNTESTED states an expectation, not a
    # tested fact — its ✅ TESTED token, if present, is a baseline quote in
    # a parenthetical. Re-executing it would false-fail the stated non-zero
    # exit. Skip the whole line (see PLAN_CORE §6 rerun-exemption rules).
    if "⚠️ UNTESTED" in l:
        continue
    m_count = re.search(r"→\s*(\d+)\s+(?:lines|hits|matches|occurrences|results|files|rows|entries)\b", l)
    expected = m_count.group(1) if m_count else ""
    for m in re.findall(r"`([^`]+)`", l):
        s = m.strip()
        # Every backticked span on an eligible line is executed verbatim —
        # so an explanatory or abbreviated quote (containing `...`) is NOT a
        # command. Skip it (conservative: skipping is never a false failure).
        if "..." in s:
            continue
        if safe.match(s):
            print(f"{s}\t{expected}")
PY
)
  echo "[plan_selfcheck] rerun: ${ran} executed, ${failed} failed"
  [[ "$failed" -eq 0 ]]
}

PATHS() {
  # Opt-in citation check (--verify-paths). Flags backticked repo-relative path
  # citations that do not resolve to a real file — archived plans, renamed
  # directories, phantom references. ADVISORY: prints WARN lines and never
  # affects the exit code. Precision is imperfect (to-be-created files,
  # subdir-relative paths, and cross-project paths can be legitimate), so a
  # cited path whose basename exists elsewhere is reported as `moved`.
  local plan="$1"
  python3 - "$plan" <<'PYPATHS'
import os, re, subprocess, sys
plan = sys.argv[1]
root = os.getcwd()
gp = os.environ.get("GIT_PROJECTS_ROOT") or os.path.join(os.path.expanduser("~"), "git_projects")


def index(r):
    try:
        out = subprocess.run(["rg", "--files", "--hidden", "-g", "!.git"], cwd=r,
                             capture_output=True, text=True, timeout=30)
        if out.returncode == 0:
            return [os.path.normpath(p) for p in out.stdout.splitlines()]
    except Exception:
        pass
    return []


files = index(root)
if os.path.isdir(gp) and os.path.realpath(gp) != os.path.realpath(root):
    files += index(gp)
fset = set(files)
base = set(os.path.basename(p) for p in files)

EXT = re.compile(r"\.(md|markdown|js|mjs|cjs|ts|tsx|jsx|go|py|sh|bash|json|json5|ya?ml|toml|txt|html|css|vue|svelte|cfg|conf|ini|env|rs|java|rb|sql|mdc)$", re.I)
SKIP = re.compile(r"[*?\[\]{}<>$|`]|\.\.\.|^~|\s|https?://|@")
CREATE = re.compile(r"\b(create|creates|created|new file|add|adds|adding|mkdir|touch|write|writes|written|output|produces|produced|generated|generate|emit|emits)\b", re.I)
RUNTIME = re.compile(r"(^|/)agent_planning/execution/")

found = []
for n, l in enumerate(open(plan, encoding="utf-8", errors="replace").read().splitlines(), 1):
    if CREATE.search(l):
        continue
    for m in re.findall(r"`([^`]+)`", l):
        s = m.strip()
        if "/" not in s or s.startswith("./") or SKIP.search(s) or not EXT.search(s):
            continue
        if RUNTIME.search(s):
            continue
        if os.path.isabs(s):
            if not (s.startswith(root) or s.startswith(gp)):
                continue  # remote/runtime absolute path
            ok = os.path.exists(s)
            b = os.path.basename(s)
        else:
            norm = os.path.normpath(s)
            ok = (os.path.exists(os.path.join(root, norm))
                  or os.path.exists(os.path.join(gp, norm))
                  or any(p.endswith("/" + norm) for p in fset))
            b = os.path.basename(norm)
        if not ok:
            found.append((n, "moved" if b in base else "not-found", s))

if not found:
    print("[plan_selfcheck] paths: all cited paths resolve")
for n, cat, s in found:
    print(f"[plan_selfcheck] WARN — cited path {cat} (line {n}): {s}")
print(f"[plan_selfcheck] paths: {len(found)} unresolved citation(s) — operator review (advisory)")
PYPATHS
}

SELF_TEST() {
  local dir rc
  dir="$(mktemp -d)"
  trap 'rm -rf "$dir"' RETURN
  # fix.txt: two lines that each contain `foo`, so an `rg foo` against this
  # path returns exactly 2 matches — the count-compare fixtures assert this.
  printf 'foo one\nfoo two\n' > "$dir/fix.txt"
  cat > "$dir/bad.md" <<'MD'
# t
### Task 1: change
**STRUCTURE:**
  - `pickSlot(spell)` returns `state.slot` when `slot >= spell.level`, else `spell.level` for every caller.
  - `pickSlot(spell)` returns `state.slot` when `slot >= spell.level`, else `spell.level` for every caller now.
**CONTEXT:** see line 597 of spells.js
**CONSTRAINTS:** interface change: signature updated, every caller enumerated.
**VERIFICATION:** `rg -n 'nested' src/` finds no nested ternary. ✅ TESTED
**NOTES:** ✅ VERIFIED by inspection.
**DEVLOG:** x
MD
  cat > "$dir/good.md" <<'MD'
# t
### Task 1: change
**STRUCTURE:**
  - `pickSlot(spell, slot)` returns the chosen slot at or above base.
**CONTEXT:** `buildStrip` carries the incumbent order, quoted below.
**CONSTRAINTS:** callers enumerated: `buildCardControls`, `slotSelect`, `rollSpell`.
**VERIFICATION:** `node scripts/battle_roster_selfcheck.mjs` ✅ TESTED on 2026-09-25.
  - baseline (pre-change) run: `rg -n 'nested' src/` → 2 pre-existing matches; check scoped to diff.
**DEVLOG:** x
MD
  # Task 5 fixtures (count-compare + absence-mark). Each carries a
  # `### Task 1:` heading and a DEVLOG line so CHECK()'s static surface passes.
  # The count-compare fixtures are written via unquoted heredocs (`<<EOF`) so
  # `$dir` expands for the `rg` path; backticks are escaped as `\`` so they
  # survive as literals.
  cat > "$dir/good_count.md" <<EOF
# t
### Task 1: count-check
**STRUCTURE:**
  - rg against the fixture file.
**CONTEXT:** two lines containing foo (verified at fixture creation).
**CONSTRAINTS:** none.
**VERIFICATION:** \`rg 'foo' $dir/fix.txt\` → 2 lines ✅ TESTED 2026-09-26 (also written as \`agent_planning/scripts/plan_lint.sh ...\` — an explanatory span the guard must skip).
**DEVLOG:** x
EOF
  cat > "$dir/bad_count.md" <<EOF
# t
### Task 1: count-check
**STRUCTURE:**
  - rg against the fixture file.
**CONTEXT:** two lines containing foo (verified at fixture creation).
**CONSTRAINTS:** none.
**VERIFICATION:** \`rg 'foo' $dir/fix.txt\` → 3 lines ✅ TESTED 2026-09-26.
**DEVLOG:** x
EOF
  # absence fixture: the backticked command sits on a ✅ VERIFIED-ABSENT line;
  # the extractor skips the line by mark, so 0 executed / 0 failed (the
  # backticks make this a true regression test of the mark-skip, not merely
  # of the "no command found" path).
  cat > "$dir/absence.md" <<'MD'
# t
### Task 1: absence-check
**STRUCTURE:**
  - search command marked as a tested absence.
**CONTEXT:** the planner ran this exact command; it returns zero matches.
**CONSTRAINTS:** none.
**VERIFICATION:** `rg 'no-such-token' src` exits non-zero with zero matches. ✅ VERIFIED-ABSENT 2026-09-26.
**DEVLOG:** x
MD
  # untested fixture: an expectation line (⚠️ UNTESTED) whose parenthetical
  # quotes a baseline ✅ TESTED. The extractor must skip the whole line —
  # re-executing the zero-match rg would false-fail on its non-zero exit.
  cat > "$dir/untested.md" <<EOF
# t
### Task 1: expectation
**STRUCTURE:**
  - rg against the fixture file, post-change expectation.
**CONTEXT:** a hypothetical change removes all foo matches.
**CONSTRAINTS:** none.
**VERIFICATION:** \`rg -c 'zzz-nope' $dir/fix.txt\` → 0 lines, exit 1 ⚠️ UNTESTED (baseline: \`rg 'foo' $dir/fix.txt\` → 2 lines ✅ TESTED on 2026-09-26).
**DEVLOG:** x
EOF
  rc=0
  local out
  # Incumbent static checks
  if CHECK "$dir/bad.md" >/dev/null 2>&1; then
    echo "[plan_selfcheck] SELF-TEST FAIL — bad fixture passed" >&2; rc=1
  elif ! CHECK "$dir/good.md" >/dev/null 2>&1; then
    echo "[plan_selfcheck] SELF-TEST FAIL — good fixture failed" >&2; rc=1
  fi
  # Task 5 fixtures: rerun count-compare + exemption behaviors. The skips are
  # asserted against the summary line (a silent 0-executed is not the same as
  # an executed-and-luckily-passing command).
  if ! out="$(RERUN "$dir/good_count.md" 2>/dev/null)" || [[ "$out" != *"rerun: 1 executed, 0 failed"* ]]; then
    echo "[plan_selfcheck] SELF-TEST FAIL — good_count RERUN should report 1 executed, 0 failed" >&2; rc=1
  fi
  if RERUN "$dir/bad_count.md" >/dev/null 2>&1; then
    echo "[plan_selfcheck] SELF-TEST FAIL — bad_count RERUN should fail (count mismatch)" >&2; rc=1
  fi
  if ! out="$(RERUN "$dir/absence.md" 2>/dev/null)" || [[ "$out" != *"rerun: 0 executed, 0 failed"* ]]; then
    echo "[plan_selfcheck] SELF-TEST FAIL — absence RERUN should report 0 executed, 0 failed" >&2; rc=1
  fi
  if ! out="$(RERUN "$dir/untested.md" 2>/dev/null)" || [[ "$out" != *"rerun: 0 executed, 0 failed"* ]]; then
    echo "[plan_selfcheck] SELF-TEST FAIL — untested RERUN should report 0 executed, 0 failed" >&2; rc=1
  fi
  # PATHS fixture: a clearly-phantom citation is reported (advisory; exit 0).
  cat > "$dir/phantom.md" <<'MD'
# t
### Task 1: phantom
**STRUCTURE:** see `no/such/path/gone_2026-01-01.md`.
**VERIFICATION:** DEVLOG: x
MD
  if ! out="$(PATHS "$dir/phantom.md" 2>/dev/null)" || [[ "$out" != *"cited path not-found"* ]]; then
    echo "[plan_selfcheck] SELF-TEST FAIL — PATHS should flag a phantom citation" >&2; rc=1
  fi
  if [[ "$rc" -eq 0 ]]; then
    echo "[plan_selfcheck] SELF-TEST PASS"
  fi
  return "$rc"
}

PLAN=""; DO_RERUN=0; DO_PATHS=0
for arg in "$@"; do
  case "$arg" in
    --self-test) SELF_TEST; exit $? ;;
    --rerun) DO_RERUN=1 ;;
    --verify-paths) DO_PATHS=1 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) PLAN="$arg" ;;
  esac
done

if [[ -z "$PLAN" || ! -f "$PLAN" ]]; then
  echo "Usage: plan_selfcheck.sh [--rerun] [--verify-paths] <plan.md> | --self-test" >&2
  exit 2
fi

rc=0
CHECK "$PLAN" || rc=1
if [[ "$DO_RERUN" -eq 1 ]]; then
  RERUN "$PLAN" || rc=1
fi
if [[ "$DO_PATHS" -eq 1 ]]; then
  PATHS "$PLAN"   # advisory: never changes rc
fi
exit "$rc"
