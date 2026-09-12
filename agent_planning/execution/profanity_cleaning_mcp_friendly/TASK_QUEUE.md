# Task Queue — profanity_cleaning_mcp_friendly

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | Fix silent-fallback in `process_audio_file` (raise `AudioCleaningError`) | done | DR-1; `audio_cleaner.py` raises now; 2 new tests pass |
| 2  | Wire `_transfer_book_file` to catch `AudioCleaningError` + track failures into `cleaning_failures[]` | done | DR-5; pipeline.py; 2 new tests pass |
| 3  | Add per-stage progress events (`stage`, `books_done`, `books_total`) to `_fire_progress` calls | done | DR-2; audio_cleaner.py; 1 new test passes; `set_book_count` added |
| 4  | Update MCP tool docstrings (`get_cleaning_progress`, `organize_books`, `ingest_books`) for new response fields + add `set_book_count` call | done | ingestion.py 3 docstrings + pipeline.py `set_book_count(len(books_to_process))` before for loop; 1 new test passes |
| 4b | Async job pattern: convert `organize_books`/`ingest_books` to async wrappers + add `get_job_result` MCP tool (DR-6) | done | ingestion.py: async wrappers + get_job_result tool; 4 new tests pass; 61/61 in-scope total |
| 5  | Empirical benchmark on 3 audio chapters (≥1 hr total) via prod MCP with test-ABS + temp-dir overrides | done | DR-3+DR-4+DR-6 validation; 580.82s wallclock for 71.4 min audio → **8.13 min/hour**; 117 progress polls (2-5ms each), DR-6 PASS |
| 6  | Functional test — happy path + ETA sanity vs prod MCP + test ABS | done | Phase 1 (3/3 moved, DR-6 PASS) + Phase 2 (ETA error 2.8%, within ±25%) — both PASS; 7.72 min/hour |
| 7  | Update 3 skill files with measured timing + new response fields + async job pattern | done | moltis / cursor / claude-code skills synced: 8.13 min/hour measured, get_job_result row, async pattern docs |
| 8  | Deploy to prod: commit + push dev + `git pull` on open-audible + `systemctl restart` + smoke test | done | Commit `9566541` deployed; PID 2231860 running on `dev` branch |
| 9  | KB writeback — update `~/git_projects/scratch_pad/knowledge/media/audiobook-pipeline.md` + append `GO_BACK_VERIFICATION.md` | done | KB updated: 2026-07-24, confidence: verified, §6 extended; commit `18fccc7` |
| 10 | OpenSpec archive — write delta scenarios to `openspec/changes/profanity-cleaning-mcp-friendly/specs/` and merge into `openspec/specs/{ingestion-mcp,pipeline}/spec.md` | done | ingestion-mcp 54→64, pipeline 16→17; commit `f0055f3`; `.gitignore` updated with `!openspec/specs/**/*.md` exception |

Statuses: `todo` / `doing` / `done` / `blocked` / `skipped`