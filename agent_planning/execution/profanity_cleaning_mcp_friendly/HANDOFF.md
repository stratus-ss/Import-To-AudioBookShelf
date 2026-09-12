# Handoff — profanity_cleaning_mcp_friendly

**Written:** 2026-07-24

## Bootstrap
Read in order:
1. `zed_plans/profanity_cleaning_mcp_friendly_2026-07-24.md` — OBJECTIVE + Tasks 4b + 5 sections + DR-6 (lines 51-60)
2. `agent_planning/execution/profanity_cleaning_mcp_friendly/SESSION_BRIEF.md`
3. `agent_planning/execution/profanity_cleaning_mcp_friendly/TASK_QUEUE.md`

## Where We Are
Tasks 1-4 done:
- **Task 1 (DR-1):** `process_audio_file` raises `AudioCleaningError`
- **Task 2 (DR-5):** `_transfer_book_file` catches + records into `cleaning_failures[]` (capped 50 + "+N more")
- **Task 3 (DR-2):** Per-stage progress events: `staging → uploading → transcribing → done` with `books_done`/`books_total`; `set_book_count()` added
- **Task 4 (DR-2 docs):** 3 docstrings updated (`get_cleaning_progress` schema, `organize_books` + `ingest_books` cleaning_failures[] docs); `set_book_count(len(books_to_process))` called in `move_audio_book_files` before loop

In-scope test suite: 57/57 pass (49 package + 8 test_profanity_cleaning.py). 10 unrelated MCP skips.

**Plan was restructured mid-session** — added DR-6 (async job pattern) + Task 4b (its implementation). Task 4b is now the next task. Task 5 benchmark is the live DR-6 validation gate.

## Next Action
Task 4b = async job pattern (DR-6). Read plan Task 4b spec carefully (lines 606-811). The pattern:

```python
@mcp.tool()
async def organize_books(...) -> dict:
    global _active_job
    if _active_job and not _active_job["task"].done():
        return {"error": "...", "active_job_id": _active_job["id"]}
    job_id = uuid4().hex[:12]
    async def _run():
        result = await asyncio.to_thread(_sync_organize_books, ...)
        _active_job["result"] = result
    task = asyncio.create_task(_run())
    _active_job = {"id": job_id, "task": task, "result": None}
    return {"job_id": job_id, "status": "started"}

@mcp.tool()
def get_job_result(job_id: str) -> dict:
    if not _active_job or _active_job["id"] != job_id:
        return {"error": "Unknown job", "job_id": job_id}
    if not _active_job["task"].done():
        return {"status": "running", "job_id": job_id}
    exc = _active_job["task"].exception()
    if exc:
        return {"status": "failed", "job_id": job_id, "error": str(exc)}
    return {"status": "completed", "job_id": job_id, "result": _active_job["result"]}
```

CRITICAL:
- `asyncio.create_task` runs the background work on the event loop — survives the `return` statement that releases the SSE response stream.
- `_cleaning_progress` dict + lock (config.py:31-39) is already thread-safe — `to_thread` worker writes, event-loop `get_cleaning_progress` reads.
- `_active_job` is accessed only from event-loop threads — no lock needed.
- `get_job_result` is sync `def` — FastMCP dispatches via `to_thread` but it's microseconds.
- Do NOT add `asyncio` imports anywhere except `ingestion.py`.

After Task 4b: Task 5 = benchmark, validates DR-6 (poll `get_cleaning_progress` every 5s during job, all polls must succeed; record `dr6_validation: PASS` in `benchmark_result.json`).

## Known Blockers / Gotchas
- Production MCP server running on port 8765 on open-audible.x86experts.com.
- Local `~/git_projects/monkeyplug/` is at v2.1.8 (hatchling) — OUT OF DATE. Production uses `/home/stratus/python_testing/monkeyplug/` at v2.1.6 (setuptools). Do NOT modify local clone.
- Test runner: `PYTHONPATH=src venv/bin/python -m pytest tests/<file> -v` (use venv, NOT system python).
- MCP server import `library_parser` fails in local venv — tests skip on `abs-mcp/config.py:21` `ModuleNotFoundError`. Pre-existing, not a regression.
- `_initialize_monkeyplug` (audio_cleaner.py:370) still wraps `Exception` in `AudioCleaningError` without `from e` — out of scope for this plan.
- **Task 4b-specific gotcha:** `get_job_result` is sync. In FastMCP, sync tools go through `anyio.to_thread.run_sync` which uses the thread pool. Since the background `_run` coroutine writes `_active_job["result"]` from the event loop (after `await to_thread` resumes), and `get_job_result` reads it from a thread pool worker — Python dict access from different threads is atomic for individual attribute reads/writes, so this is safe.
- **Task 4b-specific gotcha:** `task.exception()` re-raises if task failed AND is uncaught — only call after `task.done()` returns True (already guarded in code).
- **Task 4b-specific gotcha:** `asyncio.create_task` requires an active event loop. FastMCP async tools run on the event loop, so the task is created in the right context. Tests using `asyncio.run()` create their own event loop.

## Planning Corrections (from prior sessions)
- **[SCOPE-GAP from Task 1]** `_initialize_monkeyplug` wraps without `from e` — chain test mocks that method directly.
- **[TEST-CONTRACT-DRIFT from Task 1]** Two prior-plan tests asserted OLD silent-fallback contract.
- **[TEST-RUNNER-FIX from Task 2]** Use venv python, not system python.
- **[TEST-SETUP-FIX from Task 2]** `cfg.enable_profanity_cleaning = True` required in tests.
- **[STRAGGLER from Task 2]** `cleaning_failures` capped at 50 entries.
- **[TASK 4 DOCSTRING COLLISION]** The `Note:` block in `organize_books` and `ingest_books` docstrings is identical — disambiguate with surrounding Args block.
- **[PLAN RESTRUCTURE mid-session]** Discovered MCP streamable-http serializes requests per session — `get_cleaning_progress` times out during long-running `organize_books`. Added DR-6 + Task 4b to fix. Without 4b, DR-2 progress events are unreachable in practice.
- **[BENCHMARK ATTEMPT 1]** Killed client at 18:01:56 UTC — server-side kept processing (client disconnect ≠ server cancel).
- **[BENCHMARK ATTEMPT 2]** Timed out on `initialize` at 60s — server busy from prior job. Need to wait for server to release worker thread.