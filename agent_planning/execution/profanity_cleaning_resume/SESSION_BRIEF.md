# Session Brief — profanity_cleaning_resume

**Updated:** 2026-07-25 17:18

## Objective
Enable per-chunk profanity cleaning resume: when the MCP server crashes mid-book, re-invoking `organize_books` must skip already-transcribed chunks rather than start over.

## Current Task
None — all 8 tasks complete.

## Status
- Tasks 1-5 (done) — feature implemented + tested
- Task 6 (done) — functional test (partial — resume verified, backend confirmed working but slow)
- Task 7 (done) — OpenSpec deltas added (commit 5f523a9)
- Task 8 (done) — KB writeback (scratch_pad commit ba80521)

## Final State

**Commits pushed to origin/dev:**
- `3b85f53` — feat(audio_cleaner): per-chunk profanity cleaning resume
- `51d419b` — fix(audio_cleaner): move working directory to durable path
- `5f523a9` — docs(openspec): add resume-state delta to pipeline + ingestion-mcp specs

**Deployed to open-audible:**
- MCP service running new code at commit 15856c7 (parent of 5f523a9)
- Working dir at `/home/stratus/.cache/monkeyplug-cleaning/` (durable)
- Profanity cleaning enabled in .env
- Pointing at test ABS at 192.168.101.156:13378 (NOT prod)

**KB updated in scratch_pad:**
- `knowledge/media/audiobook-pipeline.md` — resume contract + durable working dir
- `knowledge/services/whisper-webui.md` — new §2a on single-worker limitation

**VM infrastructure fixes (out-of-band):**
- 32 vCPUs → 4 vCPUs (eliminated soft lockups)
- 8GB RAM → 6GB RAM
- graphical.target → multi-user.target (no GNOME boot)

## Files In Scope (final)
- `src/openaudible_to_audiobookshelf/audio_cleaner.py` — Tasks 1-3
- `src/openaudible_to_audiobookshelf/pipeline.py` — Task 4
- `tests/test_audio_cleaner_integration.py` — Task 5 (9 new tests)
- `tests/test_move_audio_book_files.py` — Task 5 (updated existing test)
- `src/openaudible_to_audiobookshelf/config.py` — Task 6 (durable default)
- `abs_mcp/config.py` — Task 6 (durable default)
- `abs_mcp/.env.example` — Task 6 (doc)
- `abs_mcp/README.md` — Task 6 (warning)
- `openspec/specs/pipeline/spec.md` — Task 7 (delta)
- `openspec/specs/ingestion-mcp/spec.md` — Task 7 (delta)
- `~/git_projects/scratch_pad/knowledge/media/audiobook-pipeline.md` — Task 8
- `~/git_projects/scratch_pad/knowledge/services/whisper-webui.md` — Task 8