#!/usr/bin/env bash
# Structural gate for code-producing plans. Run before execution bootstrap.
# Language-agnostic: validates CQ9 / DRY / complexity VERIFICATION presence.
#
# Usage:
#   ./scripts/plan_lint.sh <plan.md>
#   ./scripts/plan_lint.sh --require-full-tasks <plan.md>
#   ./scripts/plan_lint.sh --allow-non-code <plan.md>   # skip code gates (creative/config)
#   ./scripts/plan_lint.sh --report-phase2 <plan.md>   # emit P8d–P8j findings, do not fail
#
# Phase 2 (P8d–P8j) is diagnostic-only: the checks never increment FAILS.
# `--enforce-phase2` was removed 2026-09-12 — see the Phase 2 block below.
#
# Exit codes:
#   0 — PASS
#   1 — FAIL (non-compliant plan)

set -euo pipefail

REQUIRE_FULL=0
ALLOW_NON_CODE=0
# REPORT_PHASE2 gates the P8d–P8j diagnostic checks (added in Task 6/7).
# shellcheck disable=SC2034
REPORT_PHASE2=0
PLAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-full-tasks) REQUIRE_FULL=1; shift ;;
    --allow-non-code) ALLOW_NON_CODE=1; shift ;;
    --report-phase2) # shellcheck disable=SC2034
                      REPORT_PHASE2=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      if [[ -n "$PLAN" ]]; then
        echo "Usage: $0 [--require-full-tasks] [--allow-non-code] [--report-phase2] <plan.md>" >&2
        exit 1
      fi
      PLAN="$1"
      shift
      ;;
  esac
done

if [[ -z "$PLAN" ]]; then
  echo "Usage: $0 [--require-full-tasks] [--allow-non-code] [--report-phase2] <plan.md>" >&2
  exit 1
fi

if [[ ! -f "$PLAN" ]]; then
  echo "[plan_lint] FAIL — plan file not found: $PLAN" >&2
  exit 1
fi

FAILS=0
WARNINGS=0

pass() { echo "[plan_lint] PASS — $1"; }
fail() { echo "[plan_lint] FAIL — $1" >&2; FAILS=$((FAILS + 1)); }
warn() { echo "[plan_lint] WARN — $1" >&2; WARNINGS=$((WARNINGS + 1)); }

# ── Detect code-producing plan ──────────────────────────────────────────────
# Shell (.sh/.bash), Rust, and SQL are code languages too; they are included so
# a plan that writes a shell/Ansible-adjacent script is not silently waved past
# the code gates. (2026-09-12 fix: `.sh` was omitted, so pure-shell plans such
# as the security-scanning framework plan skipped all CQ gates.)
is_code=0
if rg -qi \
  '\.py\b|\.go\b|\.ts\b|\.tsx\b|\.js\b|\.jsx\b|\.sh\b|\.bash\b|\.rs\b|\.sql\b|python|golang|typescript|javascript|evaluator|cyclomatic|ruff|radon|gocyclo|eslint|shellcheck|quality_gate\.sh|code-quality|CQ[0-9]|tools/scripts/' \
  "$PLAN"; then
  is_code=1
fi

if [[ "$ALLOW_NON_CODE" -eq 1 ]]; then
  pass "(--allow-non-code) skipping code-quality structural gates"
  echo "[plan_lint] RESULT: PASS (non-code mode)"
  exit 0
fi

if [[ "$is_code" -eq 0 ]]; then
  warn "no code signals found — treating as non-code; use --allow-non-code to silence"
  echo "[plan_lint] RESULT: PASS (no code signals)"
  exit 0
fi

pass "detected code-producing plan"

# ── Language declaration ────────────────────────────────────────────────────
if rg -qi \
  'language\s*[:=]|languages\s*[:=]|^\s*[-*]\s*\*\*Language\*\*|PROJECT CONTEXT[\s\S]{0,800}(Python|Go|TypeScript|JavaScript|Bash|Shell)' \
  "$PLAN"; then
  pass "language declared in plan context"
else
  fail "PROJECT CONTEXT must declare language (or languages) for code-producing plans"
fi

# ── Shared Patterns / DRY audit ─────────────────────────────────────────────
if rg -qi 'Shared Patterns|DRY [Aa]udit|DRY audit' "$PLAN"; then
  pass "Shared Patterns / DRY audit present"
else
  fail "missing Shared Patterns (DRY Audit) table/section (CQ4)"
fi

# ── Collect task headings ───────────────────────────────────────────────────
# Supports: ### N) title | ### Task N | ## Task N | ### N. title
mapfile -t TASK_LINES < <(
  rg -n '^#{2,3}[[:space:]]+([0-9]+[).]|Task[[:space:]]+[0-9]+)' "$PLAN" || true
)

TASK_COUNT=${#TASK_LINES[@]}
if [[ "$TASK_COUNT" -lt 2 ]]; then
  # Fallback: numbered list under TASKS
  mapfile -t TASK_LINES < <(
    rg -n '^[[:space:]]*[0-9]+\.[[:space:]].+' "$PLAN" | head -40 || true
  )
  TASK_COUNT=${#TASK_LINES[@]}
fi

if [[ "$TASK_COUNT" -lt 2 ]]; then
  fail "could not find ≥2 numbered tasks (need implementation + Code Review at minimum)"
else
  pass "found $TASK_COUNT task-like headings/items"
fi

# ── Dedicated Code Review task + doc ordering ───────────────────────────────
# Prefer explicit "Code Review" heading; reject mashups with docs in same task title.
# (Deployment plans additionally require review BEFORE deploy — see P7 below.)
REVIEW_LINES=()
DOC_LINES=()
while IFS= read -r line; do
  REVIEW_LINES+=("$line")
done < <(rg -ni '^#{2,3}[[:space:]].*code[[:space:]-]?review' "$PLAN" || true)

while IFS= read -r line; do
  DOC_LINES+=("$line")
done < <(rg -ni '^#{2,3}[[:space:]].*(doc[[:space:]]*update|documentation|openspec.*doc)' "$PLAN" || true)

# Also catch list-style tasks
if [[ ${#REVIEW_LINES[@]} -eq 0 ]]; then
  while IFS= read -r line; do
    REVIEW_LINES+=("$line")
  done < <(rg -ni '^[[:space:]]*[0-9]+[.)][[:space:]].*code[[:space:]-]?review' "$PLAN" || true)
fi

REVIEW_MASHUP=0
if [[ ${#REVIEW_LINES[@]} -eq 0 ]]; then
  fail "missing dedicated Code Review task (CQ9.4) — REJECT"
else
  # Mashup detection: same heading contains docs + code-review
  for line in "${REVIEW_LINES[@]}"; do
    if echo "$line" | rg -qi 'doc|openspec|readme'; then
      REVIEW_MASHUP=1
    fi
  done
  if [[ "$REVIEW_MASHUP" -eq 1 ]]; then
    fail "Code Review must be its own task — do not bundle with docs/OpenSpec (CQ9.4)"
  else
    pass "dedicated Code Review task found"
  fi
fi

# Ordering heuristic: last Code Review should appear before last Doc Update when both exist
if [[ "$REVIEW_MASHUP" -eq 0 && ${#REVIEW_LINES[@]} -gt 0 && ${#DOC_LINES[@]} -gt 0 ]]; then
  last_review_line=$(echo "${REVIEW_LINES[-1]}" | cut -d: -f1)
  last_doc_line=$(echo "${DOC_LINES[-1]}" | cut -d: -f1)
  if [[ "$last_review_line" -gt "$last_doc_line" ]]; then
    fail "Code Review must be penultimate — Doc Update should be the final task (CQ9.4)"
  else
    pass "Code Review appears before Doc Update (penultimate ordering)"
  fi
elif [[ "$REVIEW_MASHUP" -eq 0 && ${#REVIEW_LINES[@]} -gt 0 && ${#DOC_LINES[@]} -eq 0 ]]; then
  # Allow explicit N/A for docs
  if rg -qi 'doc(umentation)?[[:space:]]*(update|task)?[[:space:]]*(N/A|not applicable|none required)' "$PLAN"; then
    pass "Doc Update marked N/A"
  else
    warn "no Doc Update task found — add Task N or explicit 'Doc Update: N/A'"
  fi
fi

# ── P7: pre-deployment review gate (CQ9.6 / R6) ─────────────────────────────
# Deployment plans must place the dedicated Code Review task BEFORE the first
# task that mutates live/remote state. Detection is heading-based (task titles
# only, never body prose) plus an explicit author override in the preamble.
check_deploy_review_order() {
  local deploy_re
  deploy_re='deploy|apply|provision|rollout|migrat|restart|reload|ansible-playbook|kubectl|terraform|docker[[:space:]]+push|docker[[:space:]]+compose[[:space:]]+up|scp[[:space:]]|rsync|systemctl[[:space:]]+(start|restart|enable)'

  local forced_yes=0 forced_na=0
  if rg -qi 'Deployment phase:[[:space:]]*(yes|true)' "$PLAN"; then forced_yes=1; fi
  if rg -qi 'Deployment phase:[[:space:]]*(no|n/a|none)' "$PLAN"; then forced_na=1; fi

  # A heading is a deployment task only if it is NOT an authoring/review heading.
  # This stops "Author deploy script" / "Code Review — apply checklist" from
  # being misread as deploy tasks while still catching "Build and deploy image".
  # Heading-only detection (H2/H3 task titles). Body prose and numbered body
  # lists are deliberately NOT scanned — they are not task titles and produce
  # false positives. Numbered-list task plans must declare `Deployment phase:`.
  local author_re='^#{2,3}[[:space:]]+(Task[[:space:]]+[0-9]+[[:space:]]*[).:—–-]?[[:space:]]+)?(author|write|create|draft|add|update|edit|fix|refactor|document|design|review)[[:space:]]'
  local first_deploy_line=""
  local cand_ln cand_body
  while IFS=: read -r cand_ln cand_body; do
    [[ -z "$cand_ln" ]] && continue
    if echo "$cand_body" | rg -qi "$author_re"; then continue; fi
    if echo "$cand_body" | rg -qi 'code[[:space:]-]?review'; then continue; fi
    first_deploy_line="$cand_ln"
    break
  done < <(rg -ni "^#{2,3}[[:space:]]+.*(${deploy_re})" "$PLAN" || true)

  if [[ "$forced_na" -eq 1 && "$forced_yes" -eq 0 ]]; then
    pass "P7: 'Deployment phase: N/A' declared — penultimate review rule applies"
    return
  fi

  if [[ -z "$first_deploy_line" && "$forced_yes" -eq 0 ]]; then
    pass "P7: no deployment task detected — penultimate review rule applies"
    return
  fi

  if [[ ${#REVIEW_LINES[@]} -eq 0 ]]; then
    fail "P7: deployment plan has no dedicated Code Review task before deploy (CQ9.6/R6) — REJECT"
    return
  fi

  if [[ -z "$first_deploy_line" ]]; then
    warn "P7: 'Deployment phase: yes' declared but no deploy task heading matched — verify review ordering manually"
    return
  fi

  local review_line
  review_line="$(echo "${REVIEW_LINES[-1]}" | cut -d: -f1)"
  if [[ "$review_line" -lt "$first_deploy_line" ]]; then
    pass "P7: Code Review precedes first deployment task (CQ9.6/R6)"
  else
    fail "P7: Code Review (line $review_line) must precede first deployment task (line $first_deploy_line) — CQ9.6/R6"
  fi
}
check_deploy_review_order

# ── Complexity / quality_gate in VERIFICATION ───────────────────────────────
if rg -qi \
  'quality_gate\.sh|COMPLEXITY CHECK|ruff check.*C901|radon cc|gocyclo -over|eslint.*complexity|shellcheck' \
  "$PLAN"; then
  pass "complexity / quality_gate verification language present"
else
  fail "coding tasks must reference quality_gate.sh or a language complexity command in VERIFICATION"
fi

# ── DRY scan language ───────────────────────────────────────────────────────
if rg -qi 'DRY CHECK|DRY scan|rg .*duplicate|Shared Patterns' "$PLAN"; then
  pass "DRY verification language present"
else
  fail "missing DRY CHECK / DRY scan language in plan VERIFICATION"
fi

# ── task_bodies() helper (Task 5) ────────────────────────────────────────────
# Populates the TASK_HEADINGS array with the starting line number of every
# `### Task N` heading in the plan. Per-task checks iterate TASK_HEADINGS and
# slice the body with `sed -n "${start},${end}p"`. Returns 0 with a WARN when
# no `### Task N` heading is found, so per-task checks can short-circuit.
task_bodies() {
  local -a lines
  mapfile -t lines < <(rg -n '^#{2,3}[[:space:]]+Task[[:space:]]+[0-9]+' "$PLAN" 2>/dev/null \
                          | cut -d: -f1 || true)
  TASK_HEADINGS=("${lines[@]}")
  if [[ ${#TASK_HEADINGS[@]} -lt 1 ]]; then
    return 1
  fi
  return 0
}

# ── task_body / task_title (DRY) ──────────────────────────────────────────────
# Per-task checks repeatedly need (start, end) -> body and start -> title.
# These helpers centralize the slicing so each check only carries its own
# check logic (not the sed plumbing).
task_body() {
  sed -n "${1},${2}p" "$PLAN"
}
task_title() {
  sed -n "${1}p" "$PLAN" | sed -E 's/^#+[[:space:]]+//'
}

# ── Optional full-task structure ────────────────────────────────────────────
# P8b (Task 5): the legacy `≥2-task count` threshold is replaced by per-task
# presence. Under --require-full-tasks, every task body must carry
# INTENT/STRUCTURE/CONTEXT/CONSTRAINTS/VERIFICATION/DON'T. NAMING is required
# only when a task names a NEW file or a new .sh/.py/.go path.
if [[ "$REQUIRE_FULL" -eq 1 ]]; then
  if task_bodies; then
    local_required_sections="INTENT STRUCTURE CONTEXT CONSTRAINTS VERIFICATION DON'T"
    i=
    start=
    end=
    title=
    body=
    s=
    missing_sections=()
    for i in "${!TASK_HEADINGS[@]}"; do
      start="${TASK_HEADINGS[$i]}"
      if [[ $((i+1)) -lt "${#TASK_HEADINGS[@]}" ]]; then
        end="${TASK_HEADINGS[$((i+1))]}"
      else
        end="$(wc -l < "$PLAN")"
      fi
      title="$(task_title "${start}")"
      body="$(task_body "${start}" "${end}")"
      missing_sections=()
      for s in $local_required_sections; do
        # Match `**LABEL**`, `**LABEL:**`, `**LABEL (text):**`, or `LABEL:` on
        # its own line. The bold-label canonical form is `**LABEL:**`; the
        # parenthesized form `**LABEL (extra):**` is accepted as a documented
        # variant.
        if ! echo "$body" | rg -q "\*\*${s}(:|\b)" && ! echo "$body" | rg -q "^[[:space:]]*${s}:[[:space:]]"; then
          missing_sections+=("$s")
        fi
      done
      if [[ "${#missing_sections[@]}" -gt 0 ]]; then
        fail "--require-full-tasks: task '${title}' (line ${start}) missing sections: ${missing_sections[*]}"
      else
        pass "--require-full-tasks: task '${title}' has all required sections"
      fi
    done
  else
    warn "--require-full-tasks: no '### Task N' heading found — skipping per-task section check"
  fi

  # NAMING on any task whose STRUCTURE names a new file (NEW — or new .sh/.py/.go path)
  naming_count=$(rg -c \
    "^[[:space:]]*([-*][[:space:]]*)?\*\*NAMING:?\*\*|^[[:space:]]*NAMING:[[:space:]]" \
    "$PLAN" 2>/dev/null || true)
  naming_count="${naming_count:-0}"
  new_file_count=$(rg -c 'NEW[[:space:]]+—|\.(sh|py|go|ts|tsx|js|jsx)\b' "$PLAN" 2>/dev/null || true)
  new_file_count="${new_file_count:-0}"
  if [[ "$new_file_count" -gt 0 && "$naming_count" -lt 1 ]]; then
    fail "--require-full-tasks: task names a NEW file but no NAMING section found (CQ ADDENDUM)"
  else
    pass "--require-full-tasks: NAMING present for tasks naming new files"
  fi
fi

# ── P5: destructive-op gate per task body ───────────────────────────────────
# Case-insensitive destructive-term scan (Task 5 P5 correction) — sentence-
# initial capitalized destructive verbs (e.g. "Delete the cache") previously
# escaped the gate detector because `rg -q` is case-sensitive.
check_destructive_gate() {
  if ! task_bodies; then
    warn "P5: no '### Task N' heading found — skipping destructive gate check"
    return
  fi

  local destructive_re='\b(delete|clear|purge|rm|apply|drop)\b'
  local gate_re='STOP RULE|OPERATOR CONFIRM'
  local fail_count=0

  local i start end title body
  for i in "${!TASK_HEADINGS[@]}"; do
    start="${TASK_HEADINGS[$i]}"
    if [[ $((i+1)) -lt "${#TASK_HEADINGS[@]}" ]]; then
      end="${TASK_HEADINGS[$((i+1))]}"
    else
      end="$(wc -l < "$PLAN")"
    fi
    title="$(task_title "${start}")"
    body="$(task_body "${start}" "${end}")"

    # rg -qi (Task 5 fix): case-insensitive match so sentence-initial
    # capitalized destructive verbs trigger the gate.
    if echo "$body" | rg -qi "$destructive_re"; then
      if ! echo "$body" | rg -qi "$gate_re"; then
        fail "P5: destructive term in '$title' (lines ${start}–${end}) — STOP RULE or OPERATOR CONFIRM required"
        fail_count=$((fail_count + 1))
      fi
    fi
  done

  if [[ "$fail_count" -eq 0 ]]; then
    pass "P5: every task with destructive terminology has a STOP RULE / OPERATOR CONFIRM"
  fi
}
check_destructive_gate

# ── P8a: per-task DEVLOG line (Task 5) ───────────────────────────────────────
# Every task body must contain a `DEVLOG:` line. The DEVLOG step is part of
# EXECUTION_PROTOCOL §4 state writeback; its absence means a task would not
# produce the audit trail the protocol requires.
check_devlog_per_task() {
  if ! task_bodies; then
    warn "P8a: no '### Task N' heading found — skipping per-task DEVLOG check"
    return
  fi

  local missing=0
  local i start end title body
  for i in "${!TASK_HEADINGS[@]}"; do
    start="${TASK_HEADINGS[$i]}"
    if [[ $((i+1)) -lt "${#TASK_HEADINGS[@]}" ]]; then
      end="${TASK_HEADINGS[$((i+1))]}"
    else
      end="$(wc -l < "$PLAN")"
    fi
    title="$(task_title "${start}")"
    body="$(task_body "${start}" "${end}")"

    if ! echo "$body" | rg -q '^[[:space:]]*([-*][[:space:]]+)?DEVLOG:'; then
      fail "P8a: task '$title' (lines ${start}–${end}) has no DEVLOG line — EXECUTION_PROTOCOL §4 requires per-task audit trail"
      missing=$((missing + 1))
    fi
  done

  if [[ "$missing" -eq 0 ]]; then
    pass "P8a: every task body contains a DEVLOG line"
  fi
}
check_devlog_per_task

# ── P8c: no 'latest' as a version value (Task 5) ─────────────────────────────
# Hard-fail on table cells that contain just `latest` (case-insensitive) and
# on `Version: latest` field values. The motivating failure was the
# `dnd-workflow` row that silently drifted between plan authoring and
# execution; the fix is CQ1's command-resolved version requirement.
check_versions() {
  local hits=""
  local m
  # Match `| latest |` anywhere on a table line (start, middle, or end cell).
  m=$(rg -n '\|[[:space:]]*[Ll]atest[[:space:]]*\|' "$PLAN" 2>/dev/null || true)
  [[ -n "$m" ]] && hits="$m"
  m=$(rg -n '^[Vv]ersion:[[:space:]]*[Ll]atest[[:space:]]*$' "$PLAN" 2>/dev/null || true)
  [[ -n "$m" ]] && hits="${hits}${hits:+$'\n'}$m"

  if [[ -z "$hits" ]]; then
    pass "P8c: no 'latest' values in version cells"
    return
  fi

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    fail "P8c: 'latest' is a non-compliant version value — resolve with command (CQ1) — $hit"
  done <<< "$hits"
}
check_versions

# ── Phase 2 group A (Task 6) ─────────────────────────────────────────────────
# Phase 2 checks are diagnostic-only. They are dormant by default (no flag →
# no findings) and emit `PHASE2:` lines when `--report-phase2` is set. They
# NEVER increment FAILS. `--enforce-phase2` was removed 2026-09-12 (operator
# decision, plan framework hardening) because a single global enforce switch
# was blunt and had no wiring; a per-check disposition model (fail/warn/report)
# is a follow-up. The corpus dry-run uses `--report-phase2` for the FP tally
# (DR-3).
phase2_emit() {
  # Emit a Phase-2 finding without incrementing FAILS. Phase-2 checks are
  # advisory/diagnostic until a per-check disposition model replaces them.
  echo "[plan_lint] PHASE2: $1"
}

if [[ "$REPORT_PHASE2" -eq 1 ]]; then

  # ── P8d: every DR-N block carries an Assumptions entry ──────────────────
  # The block format lives at PLAN_CORE.md:177-181. We require the literal
  # string `Assumptions:` after a `### DR-N:` heading. Missing → emit (does
  # not fail under --report-phase2).
  check_dr_assumptions() {
    local dr_blocks
    dr_blocks=$(rg -n '^### DR-[0-9]+' "$PLAN" || true)
    if [[ -z "$dr_blocks" ]]; then
      phase2_emit "P8d: no DR-N blocks found — n/a"
      return
    fi
    local missing=0
    while IFS= read -r dr_line; do
      [[ -z "$dr_line" ]] && continue
      local dr_line_no dr_id body
      dr_line_no="${dr_line%%:*}"
      dr_id="${dr_line#*DR-}"
      dr_id="DR-${dr_id%%:*}"
      # Body is from the DR heading to the next blank line + next heading
      # OR end of file. We slice up to ~25 lines below the heading (the
      # Assumptions entry lives within the first ~15 lines in practice).
      body="$(sed -n "${dr_line_no},$((dr_line_no + 30))p" "$PLAN")"
      if ! echo "$body" | rg -q '^\*\*Assumptions:\*\*|^\*\*Assumptions\*\*'; then
        phase2_emit "P8d: ${dr_id} (line ${dr_line_no}) has no Assumptions entry — DR block must include Assumptions"
        missing=$((missing + 1))
      fi
    done <<< "$dr_blocks"
    if [[ "$missing" -eq 0 ]]; then
      phase2_emit "P8d: every DR-N block carries an Assumptions entry"
    fi
  }
  check_dr_assumptions

  # ── P8e: every ✅ VERIFIED / ✅ TESTED line carries evidence ────────────
  # BOTH a date (`20[0-9]{2}-[0-9]{2}-[0-9]{2}`) AND a command token (`via`,
  # backtick, `$`, `ran `) must appear on the same line. Vocabulary lines
  # that carry two or more provenance marks (definitions, lists) and
  # angle-bracket template lines (e.g. PLAN_CORE.md §6 mark definitions)
  # are exempt to avoid flagging the rule's own definitions.
  check_claim_evidence() {
    local lines_with_marks
    lines_with_marks=$(rg -n '✅ VERIFIED|✅ TESTED' "$PLAN" || true)
    if [[ -z "$lines_with_marks" ]]; then
      phase2_emit "P8e: no ✅ VERIFIED / ✅ TESTED lines found — n/a"
      return
    fi
    local bad=0 exempt=0
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      local lineno content
      lineno="${match%%:*}"
      content="${match#*:}"
      # Exempt angle-bracket template lines (definitions in PLAN_CORE.md §6)
      if echo "$content" | rg -q '<[A-Za-z_]+>'; then
        exempt=$((exempt + 1))
        continue
      fi
      # Exempt vocabulary lines: ≥2 distinct provenance marks on the line
      local mark_count
      mark_count=$(echo "$content" | rg -o '✅ VERIFIED|✅ TESTED|📖 FROM-DOCS|⚠️ UNTESTED|❌ ASSUMED|⚠️ STALE' | wc -l)
      if [[ "$mark_count" -ge 2 ]]; then
        exempt=$((exempt + 1))
        continue
      fi
      # Required: date AND command token
      local has_date has_cmd
      has_date=0
      echo "$content" | rg -q '20[0-9]{2}-[0-9]{2}-[0-9]{2}' && has_date=1
      has_cmd=0
      echo "$content" | rg -q '`|\$|via[[:space:]]|ran[[:space:]]' && has_cmd=1
      if [[ "$has_date" -eq 0 || "$has_cmd" -eq 0 ]]; then
        # P8e is HELD per phase2_fp_report.md (STOP RULE invoked 2026-09-12
        # when the corpus dry-run showed high false-positive rate on pre-
        # adoption `✅ VERIFIED` rows in tables). Always emit, never fail.
        phase2_emit "P8e: line ${lineno} has ✅ VERIFIED/TESTED without evidence (date + command) — snippet: $(echo "$content" | sed -E 's/[[:space:]]+/ /g' | cut -c1-80)"
        bad=$((bad + 1))
      fi
    done <<< "$lines_with_marks"
    if [[ "$bad" -eq 0 ]]; then
      phase2_emit "P8e: every ✅ VERIFIED/TESTED line carries date + command token"
    fi
  }
  check_claim_evidence

  # ── P8h (WARN): multi-repo plans without Operating Model ──────────────
  # Detects plans that reference absolute paths under more than one repo by
  # counting unique /home/.../git_projects/<repo>/ roots. WARN (not FAIL)
  # per DR-5: the Operating Model requirement is author discipline, not a
  # hard gate.
  check_operating_model() {
    local repos
    repos=$(rg -n '/home/stratus/git_projects/[A-Za-z0-9_.&-]+' "$PLAN" 2>/dev/null \
           | rg -o '/home/stratus/git_projects/[A-Za-z0-9_.&-]+' \
           | sort -u || true)
    # Exclude paths under agent_planning/ in scratch_pad (the canonical repo)
    local repo_count
    repo_count=$(echo "$repos" | rg -v '^$' | wc -l || echo 0)
    if [[ "$repo_count" -le 1 ]]; then
      phase2_emit "P8h: single-repo plan detected (${repo_count} repo root) — Operating Model not required"
      return
    fi
    # Multi-repo: warn if no Operating Model section (heading, bold label, or
    # inline label — plans legitimately use any of these forms).
    if ! rg -qi 'operating[[:space:]]+model' "$PLAN"; then
      warn "P8h: plan references ${repo_count} repo roots (${repos//$'\n'/, }) — no OPERATING MODEL section found"
    else
      phase2_emit "P8h: plan references ${repo_count} repo roots — OPERATING MODEL present"
    fi
  }
  check_operating_model

  # ── P8i (WARN): source-tree references without a Token budget ──────────
  # Warns when the plan names files outside agent_planning/ (i.e., source-
  # tree references) without a `^Token budget:` line.
  check_token_budget() {
    if rg -q '^Token[[:space:]]+budget:' "$PLAN"; then
      phase2_emit "P8i: Token budget line present"
      return
    fi
    # Detect source-tree references: any path outside agent_planning/
    if rg -q '\.py\b|\.go\b|\.ts\b|\.tsx\b|\.sh\b' "$PLAN"; then
      warn "P8i: plan references source-tree files but has no 'Token budget:' line — add one (PLAN_CORE §3)"
    else
      phase2_emit "P8i: no source-tree references and no Token budget line — n/a"
    fi
  }
  check_token_budget

  # ── P8f (Task 7): DR citations on shaping tasks ──────────────────────────
  # Per PLAN_CORE.md:186, every task shaped by a DR decision must cite the
  # DR in its CONSTRAINTS section. Review / doc / closeout tasks are exempt.
  # Tasks with `DRs: none` are also exempt. For Tier 2/3 plans without a
  # DR-gating map, emit a WARN.
  check_dr_refs() {
    if ! task_bodies; then
      phase2_emit "P8f: no '### Task N' heading — n/a"
      return
    fi
    local bad=0 exempt=0
    local i start end title body dr_line
    for i in "${!TASK_HEADINGS[@]}"; do
      start="${TASK_HEADINGS[$i]}"
      if [[ $((i+1)) -lt "${#TASK_HEADINGS[@]}" ]]; then
        end="${TASK_HEADINGS[$((i+1))]}"
      else
        end="$(wc -l < "$PLAN")"
      fi
      title="$(task_title "${start}")"
      body="$(task_body "${start}" "${end}")"

      # Exempt review / doc / closeout / Code Review tasks (by title)
      if echo "$title" | rg -qi 'code[[:space:]-]?review|doc[[:space:]]*update|changelog|closeout|reconciliation'; then
        exempt=$((exempt + 1))
        continue
      fi
      # Exempt tasks that opt out via `DRs: none`
      if echo "$body" | rg -q '^[[:space:]]*DRs:[[:space:]]+none'; then
        exempt=$((exempt + 1))
        continue
      fi
      # Require at least one DR citation in CONSTRAINTS section
      if ! echo "$body" | rg -q 'DR-[0-9]+'; then
        phase2_emit "P8f: task '$title' (line ${start}) has no DR citation"
        bad=$((bad + 1))
      fi
    done
    # WARN when no DR→task gating map for Tier 2/3 (the map is in DECISION RECORDS)
    if rg -q '^## DECISION RECORDS' "$PLAN"; then
      local dr_to_task_map
      dr_to_task_map=$(rg -c '^[A-Z][A-Z]+:|DR-[0-9]+' "$PLAN" || echo 0)
      if [[ "$dr_to_task_map" -lt 3 ]]; then
        warn "P8f: DECISION RECORDS section present but gating map is sparse — verify DR→task coverage"
      else
        phase2_emit "P8f: DECISION RECORDS gating map present"
      fi
    else
      phase2_emit "P8f: no DECISION RECORDS section (Tier 1 plan or doc-only)"
    fi
    if [[ "$bad" -eq 0 ]]; then
      phase2_emit "P8f: every shaping task cites its gating DR(s) (${exempt} review/doc/closeout tasks exempt)"
    fi
  }
  check_dr_refs

  # ── P8g (Task 7): command provenance broader + Provenance Legend ────────
  # Broadens the P1 command regex from the legacy `go build|go test|go vet|
  # gofmt|gocyclo|make` set to include `gocyclo`. Also accepts a `Provenance
  # Legend` block as a blanket mark ONLY inside VERIFICATION sections.
  check_provenance_legend() {
    # Broaden the P1 regex to include gocyclo (already in P1 set; see Task 7
    # report — kept for parity). This block emits findings on lines where
    # the existing P1 check would have flagged but the line is inside a
    # VERIFICATION section with a `Provenance Legend` block. No-op when no
    # legend exists; this is the "blanket mark" path P8g adds.
    local verif_sections
    verif_sections=$(rg -n '^\*\*VERIFICATION(:|\b)' "$PLAN" || true)
    if [[ -z "$verif_sections" ]]; then
      phase2_emit "P8g: no VERIFICATION sections — n/a"
      return
    fi
    if ! rg -q '^[[:space:]]*Provenance[[:space:]]+Legend' "$PLAN"; then
      phase2_emit "P8g: no Provenance Legend block — per-line marks required (P1 unchanged)"
      return
    fi
    # Legend present — P1's per-line mark requirement is relaxed within
    # VERIFICATION sections that follow a `Provenance Legend:` header.
    phase2_emit "P8g: Provenance Legend present — per-line marks relaxed inside VERIFICATION sections (P1 blanket)"
  }
  check_provenance_legend

  # ── P8j (Task 7): per-task quality_gate / DRY / CQ content ─────────────
  # Per coding task (title matches `code[[:space:]-]?review` ⇒ exempt),
  # require the existing quality_gate.sh / complexity language and the
  # existing DRY-scan language inside the task body. CONTEXT7 line required
  # only when the task names a library; `VERIFICATION: minimal` allowed
  # for scaffold-only tasks.
  # cq_task_exempt <title> <body> -> 0 when the task is exempt from P8j.
  # Extracted so check_cq_per_task stays within the ≤15-branch budget.
  cq_task_exempt() {
    local title="$1" body="$2"
    # Review / doc / closeout tasks have a different CQ footprint (CQ9.4).
    if echo "$title" | rg -qi 'code[[:space:]-]?review|doc[[:space:]]*update|changelog|closeout|reconciliation'; then
      return 0
    fi
    # Scaffold-only tasks may declare `VERIFICATION: minimal`.
    if echo "$body" | rg -q '\*\*VERIFICATION:\*\*[[:space:]]*minimal'; then
      return 0
    fi
    return 1
  }

  # cq_task_missing <body> -> prints the space-separated missing CQ items.
  cq_task_missing() {
    local body="$1" out=""
    if ! echo "$body" | rg -q 'quality_gate\.sh|COMPLEXITY CHECK|ruff[[:space:]]+check.*C901|gocyclo[[:space:]]+-over|eslint.*complexity|shellcheck'; then
      out="quality_gate"
    fi
    if ! echo "$body" | rg -q 'DRY (CHECK|scan)|rg .*duplicate|Shared Patterns'; then
      out="${out:+$out }DRY scan"
    fi
    # CONTEXT7 required only when the task names a library.
    if echo "$body" | rg -qi '\bimport\b|\brequire\b|\buse\b|npm[[:space:]]+(install|view)|pip[[:space:]]+install|go[[:space:]]+list|context7' \
       && ! echo "$body" | rg -q 'CONTEXT7[[:space:]]+CHECK'; then
      out="${out:+$out }CONTEXT7"
    fi
    printf '%s' "$out"
  }

  check_cq_per_task() {
    if ! task_bodies; then
      phase2_emit "P8j: no '### Task N' heading — n/a"
      return
    fi
    local bad=0 exempt=0
    local i start end title body missing
    for i in "${!TASK_HEADINGS[@]}"; do
      start="${TASK_HEADINGS[$i]}"
      if [[ $((i+1)) -lt "${#TASK_HEADINGS[@]}" ]]; then
        end="${TASK_HEADINGS[$((i+1))]}"
      else
        end="$(wc -l < "$PLAN")"
      fi
      title="$(task_title "${start}")"
      body="$(task_body "${start}" "${end}")"
      if cq_task_exempt "$title" "$body"; then
        exempt=$((exempt + 1))
        continue
      fi
      missing="$(cq_task_missing "$body")"
      if [[ -n "$missing" ]]; then
        phase2_emit "P8j: task '$title' (line ${start}) missing CQ: ${missing}"
        bad=$((bad + 1))
      fi
    done
    if [[ "$bad" -eq 0 ]]; then
      phase2_emit "P8j: every shaping task carries CQ (${exempt} review/scaffold tasks exempt)"
    fi
  }
  check_cq_per_task

fi  # REPORT_PHASE2

# ── P6: CQ / A11 / A12 markers in plan body ─────────────────────────────────
check_cq_markers() {
  if rg -q 'CQ9\.2|model-switch' "$PLAN"; then
    pass "P6: CQ9.2 / model-switch pause reference present"
  else
    fail "P6: CQ9.2 pause text or 'model-switch' mention required in plan (CQ9.2 gate)"
  fi

  if rg -q 'A11' "$PLAN"; then
    pass "P6: A11 reference present"
  else
    warn "P6: A11 (production image verification) not mentioned — add explicit reference or 'A11 exemption' / 'A11 N/A'"
  fi

  if rg -q 'A12' "$PLAN"; then
    pass "P6: A12 reference present"
  else
    warn "P6: A12 (functional testing) not mentioned — add explicit reference or 'A12 exemption' / 'A12 N/A'"
  fi
}
check_cq_markers

# ── Decomposition hint for large multi-check work ───────────────────────────
if rg -qi 'aggregat|multi-check|evaluator|handler' "$PLAN"; then
  if rg -qi 'decompos|dispatch|sub-evaluat|≤15|<=15|cyclomatic|CQ10|>5 independent' "$PLAN"; then
    pass "decomposition / complexity constraints mentioned for aggregate-style work"
  else
    warn "aggregate/evaluator plan without explicit decomposition CONSTRAINTS (CQ10)"
  fi
fi

# ── P1: command provenance marks (PLAN_CORE §6) ─────────────────────────────
check_provenance() {
  local commands_regex
  commands_regex='\b(curl|ssh|sqlite3|opencode|python[0-9.]*|docker|rg|git|scp|nmap)\b|\{"type":'
  local marks_regex='✅ TESTED|📖 FROM-DOCS|⚠️ UNTESTED'
  local found_any=0
  local unmarked=0
  local prev=""
  local line_no=0

  while IFS= read -r line; do
    line_no=$((line_no + 1))
    if echo "$line" | rg -q "$commands_regex"; then
      if echo "$line" | rg -q '^[[:space:]]*\|'; then
        prev="$line"
        continue
      fi
      found_any=1
      if ! printf '%s\n%s\n' "$prev" "$line" | rg -q "$marks_regex"; then
        local snippet
        snippet="$(echo "$line" | sed -E 's/[[:space:]]+/ /g' | cut -c1-80)"
        fail "P1: provenance: line $line_no command without ✅/📖/⚠️ mark — $snippet"
        unmarked=$((unmarked + 1))
      fi
    fi
    prev="$line"
  done < "$PLAN"

  if [[ "$unmarked" -eq 0 && "$found_any" -eq 1 ]]; then
    pass "P1: provenance mark present on all command-shaped lines"
  fi
  if [[ "$found_any" -eq 0 ]]; then
    warn "P1: no command-shaped lines found — plan may be documentation-only"
  fi
}
check_provenance

# ── P2: no conditional-branch phrases in task bodies ────────────────────────
check_no_conditionals() {
  local first_task_line
  first_task_line="$(rg -n '^#{2,3}[[:space:]]+Task[[:space:]]+[0-9]+' "$PLAN" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$first_task_line" ]]; then
    warn "P2: no '### Task N' heading found — skipping conditional check"
    return
  fi

  local hits
  hits="$(rg -n '\bif\b|\belse\b|or equivalent|either|whichever|one of' "$PLAN" \
    | awk -F: -v start="$first_task_line" '$1 >= start' || true)"
  if [[ -z "$hits" ]]; then
    pass "P2: no conditional-branch phrases in task bodies"
    return
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    fail "P2: conditional phrase in task body: $hit"
  done <<< "$hits"
}
check_no_conditionals

# ── P3: no angle-bracket placeholders in task bodies ────────────────────────
check_no_placeholders() {
  local first_task_line
  first_task_line="$(rg -n '^#{2,3}[[:space:]]+Task[[:space:]]+[0-9]+' "$PLAN" | head -1 | cut -d: -f1 || true)"
  if [[ -z "$first_task_line" ]]; then
    warn "P3: no '### Task N' heading found — skipping placeholder check"
    return
  fi

  local hits
  hits="$(rg -n '<[A-Za-z_-]+>' "$PLAN" \
    | awk -F: -v start="$first_task_line" '$1 >= start' || true)"
  if [[ -z "$hits" ]]; then
    pass "P3: no angle-bracket placeholders in task bodies"
    return
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    fail "P3: angle-bracket placeholder in task body: $hit"
  done <<< "$hits"
}
check_no_placeholders

echo ""
if [[ "$FAILS" -gt 0 ]]; then
  echo "[plan_lint] RESULT: FAIL ($FAILS failure(s), $WARNINGS warning(s))" >&2
  echo "[plan_lint] Fix the plan before running init_execution_dir.sh or Task 1." >&2
  exit 1
fi

echo "[plan_lint] RESULT: PASS ($WARNINGS warning(s))"
exit 0
