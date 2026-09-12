# Plan Addendum — Media & Content Pipelines

_Last updated: 2026-09-10_

Applies to: EPUB→TTS pipelines, Whisper transcription, Fish.Audio/FishTTS production, audio normalization, media batch processing, scraping pipelines, ETL workflows, data export/import.

Read this after `PLAN_CORE.md`. All rules here are ADDITIVE.

**Code quality:** All pipeline plans produce code with behavioral logic. Read `addenda/code-quality.md` alongside this addendum.

---

## P1. Stage Sequencing

Pipelines decompose into discrete, ordered stages. Each stage is one task. Stages MUST NOT be combined.

**Canonical stage order for content pipelines:**
```
Ingest → Validate → Transform → Enrich → Output → Verify
```

**Examples:**
- EPUB → TTS: `extract_epub → clean_text → translate → format_tts_script → generate_audio → verify_audio`
- Whisper transcription: `download_audio → split_chunks → transcribe → merge_output → post_correct → export`
- Audible ingest: `scan_library → download_decrypt → organize → scan_abs → match_metadata`

Each task's STRUCTURE MUST name:
- Input: source file(s) or directory with expected format
- Output: destination file(s) or directory with expected format
- Transform: what changes between input and output

---

## P2. Idempotency Requirement

Every pipeline stage MUST be idempotent: re-running a stage that has already completed produces the same output without side effects.

**Rules:**
- Check for existing output before processing: `if output_file.exists(): skip and log`
- For batch stages: process only files not yet present in the output directory
- For API stages (e.g., Whisper, Fish.Audio): check if output already exists before making the API call
- Re-runs must NOT append duplicate data to output files

**STRUCTURE sections for pipeline tasks MUST include:**
```
IDEMPOTENCY: If output/<file> already exists, skip this file and log "skipping <file>: already processed"
```

---

## P3. Disk Space Awareness

Before any stage that generates large output (audio files, transcription dumps, organized book libraries), the plan MUST include a disk space check:

```
STEP 0 (DISK CHECK):
  df -h <output_directory>
  BLOCKED: if available space < 2x estimated output size, report and halt.
           Do not proceed with generation that will fill the disk.
```

Estimates to include in PROJECT CONTEXT:
- Expected output size per file (e.g., "~50MB per audiobook hour at 128kbps")
- Total expected output size for the full stage

---

## P4. Checkpoint/Resume Patterns

For long-running pipeline stages (>10 minutes of processing), the plan MUST include checkpoint/resume support:

**Implementation pattern:**
```python
# Write a checkpoint file after each item
checkpoint_file = output_dir / ".checkpoint"
processed = set(checkpoint_file.read_text().splitlines()) if checkpoint_file.exists() else set()

for item in items:
    if item.name in processed:
        continue
    process(item)
    with checkpoint_file.open("a") as f:
        f.write(item.name + "\n")
```

**VERIFICATION for long-running stages:**
```
VERIFICATION:
  1. Run the stage on a small subset first (first 3 items)
  2. Verify output quality before running the full batch
  3. Check checkpoint file exists after the subset run
  4. Interrupt and resume to verify checkpoint is honored
```

---

## P5. Asset Management

When a pipeline produces media assets (MP3, WAV, SRT, EPUB, PDF):

- **Naming convention:** MUST be explicit in STRUCTURE. Never "appropriate filenames."
  - Bad: "output files named after the source"
  - Good: `output/{book_title}_{chapter_num:02d}_{voice_id}.mp3`
- **Directory structure:** MUST be defined before the pipeline runs. Do not rely on the tool to choose its own layout.
- **Source preservation:** NEVER delete or overwrite source files. Always produce new output files.
- **Extension verification:** After generation, verify file extensions match expected format and files are non-zero bytes.

---

## P6. External API Pipeline Rules (Fish.Audio, Whisper, Audible)

When a pipeline stage calls an external API:

- **Rate limiting:** Include explicit sleep/backoff between API calls. Never batch-fire without throttling.
- **Retry on transient failure:** 3 retries with exponential backoff for 5xx/timeout errors
- **Hard stop on auth failure:** 4xx auth errors are NOT transient. Stop the pipeline, report credentials failure.
- **Output validation:** After each API call, validate the response before writing to disk:
  - For audio: check non-zero file size and valid file header
  - For text: check non-empty response and absence of error markers
  - For transcription: check output length is proportional to input length

```
VERIFICATION for API stages:
  wc -c <output_file>   → must be > 1000 bytes for audio (not a stub/error file)
  file <output_file>    → must match expected format (MP3: "MPEG ADTS")
```

---

## P8. Pipeline Checklist (extends PLAN_CORE §12 and code-quality.md §CQ8)

In addition to the universal checklist, verify:

- [ ] Each stage is a separate task (no combined ingest+transform in one task)
- [ ] Input and output formats are explicit in each task's STRUCTURE (not "appropriate format")
- [ ] Idempotency behavior is defined: skip-if-exists or overwrite-if-newer, stated explicitly
- [ ] Disk space check included before large output stages
- [ ] Long-running stages (>10 min) have checkpoint/resume support
- [ ] Naming convention for output assets is explicit (no "appropriate names")
- [ ] Source files are never deleted or overwritten (always produce new output)
- [ ] API stages include rate limiting, retry policy, and hard stop on auth failure
- [ ] VERIFICATION includes file size check and format validation (not just "command exited 0")
- [ ] Full-batch run is preceded by a small-subset verification run
- [ ] Every coding task's VERIFICATION includes: CONTEXT7 CHECK, COMPLEXITY CHECK, MAINTAINABILITY CHECK, DRY CHECK, CODE REVIEW
- [ ] Plan includes a dedicated Code Review task (per code-quality.md §CQ9) — penultimate for non-deployment plans, immediately before the first deploy/apply task for deployment plans (§CQ9.6 / R6) — tailored to the plan's specific files
- [ ] Task ordering: non-deployment → implementation → Code Review (N-1) → Doc Update (N); deployment → authoring/testing → Code Review → deploy → Doc Update

---

## P9. OpenSpec Integration

OpenSpec is the spec persistence layer for pipeline projects. Specs accumulate
across plans, giving the executing agent behavioral context before it touches
pipeline code. See `agent_planning/openspec/README.md` for full details.

### When Pipeline Specs Make Sense

Pipeline specs capture behavioral contracts that plans must not break:

- Stage ordering invariants ("step X MUST run before step Y")
- Input/output format contracts ("ingest produces `transcript_<date>.srt.txt`")
- Idempotency invariants ("re-running a completed stage skips, not duplicates")
- Error handling contracts ("missing input file raises error before any stage runs")

### OpenSpec Lifecycle Per Plan

```
Planning phase:
  1. Check if agent_planning/openspec/specs/<capability>/ exists
  2. If specs exist: read as additional PROJECT CONTEXT before writing tasks
  3. If specs do NOT exist: follow the No OpenSpec Found dialogue below

Execution phase:
  4. Agent follows plan tasks
  5. Agent reads agent_planning/openspec/changes/<change-id>/tasks.md alongside plan tasks

Completion:
  6. Final task: merge delta specs from agent_planning/openspec/changes/<change-id>/specs/
     into agent_planning/openspec/specs/<capability>/spec.md
  7. Delete or archive agent_planning/openspec/changes/<change-id>/
```

### No OpenSpec Found (Discovery Dialogue)

If `agent_planning/openspec/specs/` does not exist or is empty, the planner MUST flag this to
the user before proceeding with DR generation:

> **No OpenSpec behavioral specs found for this pipeline project.**
> Would you like to:
> (a) Proceed without specs — fastest, but no behavioral guardrails
> (b) Auto-generate a baseline spec — I will traverse the pipeline code
>     for stage contracts, input/output format invariants, step ordering,
>     and existing test scenarios
> (c) Pause for manual spec creation

#### Auto-Generation Procedure (Pipeline)

Traverse the pipeline codebase and write `agent_planning/openspec/specs/<capability>/spec.md`
for each discoverable capability. Present each spec file for user review before
writing the next. Do NOT modify any source code — specs are read-only snapshots.

1. **Pipeline stage definitions** — Read the pipeline runner code. For each
   stage (ingest, validate, transform, enrich, output, verify), write a
   requirement covering input format, output format, and idempotency contract.
2. **Config structs** — Read all config type definitions. Write a requirement
   for each config field group covering defaults and validation rules.
3. **Step ordering invariants** — If the pipeline has explicit step ordering or
   stage dependencies, write a requirement for each ordering constraint.
4. **File naming conventions** — Write a requirement for each output filename
   pattern that downstream stages depend on.
5. **Existing tests** — Scan test files for behavioral expectations. These
   encode spec scenarios that must continue to pass.

**Confirmation gate:** Wait for explicit user confirmation before accepting
generated specs. After confirmation, proceed with the planning flow — the specs
are now available as PROJECT CONTEXT.

### Spec Content Format

Same as `addenda/software.md §S1`: GIVEN/WHEN/THEN behavioral scenarios.

```
# <capability> Specification

## Purpose
[One paragraph: what this capability does and why it exists.]

## Requirements

### Requirement: <name>
The system SHALL <behavior>.

#### Scenario: <description>
- GIVEN <precondition>
- WHEN <action>
- THEN <expected outcome>
- AND <additional assertion>
```

### OpenSpec Checklist (extends §P8)

- [ ] If pipeline project has `agent_planning/openspec/`: PROJECT CONTEXT references existing
      specs; final task includes archive step
- [ ] Stage input/output formats are captured as spec scenarios
- [ ] Idempotency invariants are captured as spec scenarios
- [ ] Step ordering invariants are captured as spec scenarios
