# Session Brief — profanity_cleaning_mcp_friendly

**Updated:** 2026-07-24

## Objective
Fix silent-fallback bug in `audio_cleaner.process_audio_file` (DR-1), add per-book + per-stage progress visibility with ETA hint via `get_cleaning_progress` (DR-2), convert `organize_books`/`ingest_books` to async job pattern so `get_cleaning_progress` is callable concurrently (DR-6), bake empirically-measured per-hour timing into the skill (DR-3), and run thorough functional tests on real audio against test ABS + prod Whisper (DR-4).

## Current Task
Task 4b — Async job pattern for `organize_books`/`ingest_books` (DR-6). Convert MCP wrappers to `async def` returning `{"job_id": str, "status": "started"}` immediately via `asyncio.create_task(asyncio.to_thread(_sync_organize_books, ...))`. Add `get_job_result(job_id)` MCP tool. Single-slot `_active_job` guard.

## Status
- Last completed: Task 4 — 3 docstrings updated + `set_book_count(len(books_to_process))` call added; 57/57 in-scope tests pass; 10 unrelated MCP skips
- Active: Task 4b (was Task 5 before plan restructure)
- Blocked on: (none)

## Next Action
Task 4b is implementation of DR-6 (Plan §Decision Records lines 51-60; Task spec lines 606-811). Steps:
1. Read `abs-mcp/tools/ingestion.py` lines 1-30 (imports) + 100-280 (organize_books) + 348-420 (ingest_books) to understand current structure
2. Part A: add `import asyncio` + `from uuid import uuid4` to ingestion.py imports
3. Part B: add `_active_job: dict | None = None` module-level dict
4. Part C: extract sync body of `organize_books` (lines ~208-282) into `_sync_organize_books(...)` returning dict
5. Part D: rewrite `organize_books` as `async def` wrapper with single-slot guard + `asyncio.create_task` + immediate `{"job_id": ..., "status": "started"}` return; updated docstring covering async job pattern + cleaning_failures[]
6. Part E: add `@mcp.tool()` `get_job_result(job_id: str) -> dict` with 4 return paths (running/completed/failed/unknown)
7. Part F: apply same pattern to `ingest_books` (extract `_sync_ingest_books`, async wrapper reusing `_active_job` slot)
8. Part G: verify Task 4's docstring additions (cleaning_failures[] + cleaning aggregate) are folded into the new async wrapper docstring
9. Write 4 new tests per Task 4b §verification (lines 780-799):
   - `test_organize_books_returns_job_id`
   - `test_organize_books_rejects_concurrent_job`
   - `test_get_job_result_unknown_job`
   - `test_get_cleaning_progress_callable_during_job`
10. Run `PYTHONPATH=src venv/bin/python -m pytest tests/ -x -v` — expect 61 passed (was 57)

After Task 4b completes: Task 5 (benchmark) can validate DR-6 with concurrent `get_cleaning_progress` polling.

## Files In Scope
- `abs-mcp/tools/ingestion.py` — Task 4b modifies (Parts A-G)
- `tests/mcp/test_profanity_cleaning.py` — Task 4b adds 4 new tests