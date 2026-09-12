# MCP Server Decomposition — Devlog — 2026-07-25

Plan: `zed_plans/mcp_server_decomposition_2026-07-25.md`

## Pre-Task 1: WIP divergence audit (unplanned, discovered during Task 1 prep)

Before wiring `tools/*.py` into the assembly point, read each WIP module and
diffed behavior against the monolith. Found DR-2's premise ("extensively
tested, 151/163 pass") did not hold — ran `tests/mcp/` for real: **14
failed, 5 passed**, not 151/163.

Confirmed code bugs (fixed, see below):
1. `config.py._build_config` — missing `_validate_profanity_config` fail-loud
   safety check present in monolith (`mcp_server.py:544-580`). Silent
   regression: misconfigured profanity cleaning would no longer fail fast.
2. `podcast_tools.py` — imported nonexistent `sanitize_filename` from
   `openaudible_to_audiobookshelf.utils` (real function: `sanitize_name`,
   which has different/incompatible semantics — alnum-only stripping vs.
   filesystem-unsafe-chars-only). Hard `ImportError`, blocked `tools/podcast.py`.
3. `abs_mcp/tools/podcast.py` — imported nonexistent `ABSClient` class from
   `audio_bookshelf.py` (never existed in `src/`, confirmed via
   `git log --all -S 'class ABSClient'`). Hard `ImportError`.
4. `abs_mcp/tools/ingestion.py` — most tools (`scan_audible`,
   `set_book_status`, `download_books`, `export_library`, `organize_books`'s
   sync helper, `scan_audiobookshelf`, `match_audiobookshelf`,
   `ingest_books`'s sync helper, `get_cleaning_progress`) still called
   `json.dumps()` and returned raw strings instead of dicts, contradicting
   the dict convention already used in `discovery.py`/`podcast.py`/
   `metrics.py` and asserted by `tests/mcp/test_ingestion.py`. Confirmed live:
   `get_cleaning_progress()` returned `str '{}'`, not `{}`.
5. `tests/mcp/test_asins_file.py` expected `_read_downloaded_asins`/
   `_write_downloaded_asins` helpers in `ingestion.py` (file-based ASIN
   handoff) that were never implemented — deferred from a prior plan's
   "Task 8" that never happened.

User decision (AskQuestion): fix all 4 issues now as bounded, mechanical
fixes before Task 1.

### Fixes applied
- `abs_mcp/podcast_tools.py`: removed broken import; added local
  `sanitize_filename()` copied verbatim from the monolith's
  `_sanitize_filename` (kept local, not in `utils.py`, since it must match
  monolith regex behavior exactly, not `sanitize_name`'s different
  semantics — also avoids touching `src/` per plan's STOP RULE).
- `abs_mcp/tools/podcast.py`: replaced `ABSClient(url, token).scan_library(lib_id)`
  with `scan_library_for_books(url, lib_id, token)`, matching monolith exactly.
- `abs_mcp/tools/ingestion.py`: changed 9 call sites from
  `_record_tool_result(name, start, json.dumps(x))` to
  `_record_tool_result(name, start, x)` (pass dict directly); fixed
  `get_cleaning_progress` to return dict via
  `json.loads(json.dumps(snapshot, default=str))` (preserves the
  non-JSON-safe-value guard while returning a dict); fixed 6 return-type
  annotations from `-> str` to `-> dict` to match; added
  `_read_downloaded_asins`/`_write_downloaded_asins` as pure filesystem
  helpers (not wired into `download_books`/`organize_books` — the
  in-memory `_last_downloaded_asins` handoff still matches monolith
  behavior; wiring in file-based persistence would be new functionality
  out of scope for a structural-only refactor).
- `abs_mcp/config.py`: ported `_validate_profanity_config` verbatim from
  monolith; call it at the end of `_build_config()` before `return cfg`.

### Verification
```
$ venv/bin/python -c "from abs_mcp.tools import podcast; print('podcast OK')"
podcast OK

$ PYTHONPATH=src venv/bin/python -m pytest tests/mcp/ -q --no-cov
8 failed, 11 passed in 21.63s
```
Remaining 8 failures categorized (none are WIP-vs-monolith divergences):
- `test_cache.py` (3), `test_discovery.py` (2),
  `test_ingestion.py::test_scan_audiobookshelf_happy_path` (1): stale/expired
  ABS test credentials (HTTP 401/404 against real test ABS server) —
  environment issue, not code.
- `test_error_paths.py::test_unreachable_abs_returns_error_dict`: uncaught
  `ConnectionError` from `pipeline.step_scan_abs` on unreachable host — gap
  in shared `pipeline.py`, identical in monolith, pre-existing, out of scope.
- `test_ingestion.py::test_organize_books_with_empty_source_returns_zero`:
  written before the DR-6 async job pattern was retrofitted; `organize_books`
  is intentionally `async` now (returns `{job_id, status}`, not a result
  dict directly) in both monolith and WIP. Stale test, not a divergence.

## Task 1: Replace mcp_server.py monolith with thin assembly point

Rewrote `abs_mcp/mcp_server.py` as an assembly point: creates `FastMCP`
server + `InMemoryEventStore` (copied verbatim), imports the four
`tools/*` submodules, transfers their tools via
`mcp.add_tool(_tool.fn, name=_tool.name, description=_tool.description)`
iterating each submodule's own `_tool_manager._tools`, keeps the
`__main__` block using `_env`/`LOGGER` from `config.py`.

### Verification
```
$ wc -l abs_mcp/mcp_server.py
117 abs_mcp/mcp_server.py

$ venv/bin/python -c "
from abs_mcp.mcp_server import mcp
import asyncio
tools = asyncio.run(mcp.list_tools())
names = sorted(t.name for t in tools)
print(f'{len(names)} tools registered')
assert len(names) == 26
print('PASS')
"
26 tools registered
PASS
```
26/26 tools registered, no duplicates, no missing tools. 117 lines (< 150 target).

## Task 1.5: Port missing _validate_profanity_config into config.py

Done as part of the pre-Task-1 divergence audit above (folded in since the
fix targets `config.py`, which Task 1's constraints originally said not to
touch — user approved treating this as its own task ahead of Task 1).

### Verification
```
$ venv/bin/python -c "
from abs_mcp.config import _build_config
import os
os.environ['ENABLE_PROFANITY_CLEANING'] = 'true'
os.environ.pop('REMOTE_WHISPER_URL', None)
try:
    _build_config(enable_profanity_cleaning=True)
    print('FAIL: no exception raised')
except ValueError as e:
    print(f'PASS: {e}')
"
```
Output: `PASS: Profanity cleaning is enabled but REMOTE_WHISPER_URL is not set. ...`

Also fixed a stale local `abs_mcp/.env` (gitignored, not committed):
`LIBRARIES_CONFIG=abs-mcp/libraries.yaml` (hyphenated, nonexistent path) →
`abs_mcp/libraries.yaml`. Discovered via a "Libraries config not found"
warning during verification; would have caused `list_libraries` to return
empty locally regardless of code correctness.

## Task 2: Update _mcp_bridge.py for package imports

Removed `sys.path.insert` + bare `from mcp_server import mcp`, replaced with
`from .mcp_server import mcp`. Also dropped now-unused `os`/`sys` imports
used only by the removed hack.

```
$ venv/bin/python -c "from abs_mcp._mcp_bridge import main; print('PASS: _mcp_bridge importable')"
PASS: _mcp_bridge importable
```

## Task 3: Update systemd service file

Changed `abs_mcp/audiobook-ingestion-mcp.service` ExecStart from
`python abs_mcp/mcp_server.py` to `python -m abs_mcp.mcp_server`. No other
lines touched.

```
$ grep 'ExecStart' abs_mcp/audiobook-ingestion-mcp.service
ExecStart=/home/stratus/OpenAudible-To-AudioBookShelf/venv/bin/python -m abs_mcp.mcp_server
```

## Task 4: Fix Dockerfile and docker-compose for correctness

- `docker/Dockerfile`: replaced 7 individual `COPY abs_mcp/*.py` lines with
  `COPY abs_mcp/ /app/abs_mcp/` in both builder and runtime stages; changed
  `CMD` to `["python3", "-m", "abs_mcp.mcp_server"]`.
- `docker/.dockerignore`: added `abs_mcp/data/` (holds `tool-metrics.jsonl`,
  confirmed 172KB present locally — would have been baked into the image
  without this).
- Staged the pending `abs-mcp` → `abs_mcp` rename diffs already in the
  working tree for `docker-compose.yml`, `docker-compose.override.example.yml`,
  `.dockerignore` — confirmed pure renames via `git diff`, no other changes.

```
$ grep -c 'COPY abs_mcp/' docker/Dockerfile
2
$ grep 'CMD' docker/Dockerfile
CMD ["python3", "-m", "abs_mcp.mcp_server"]
```
Not built or pushed, per DR-4.

## Task 5: Run tests and verify tool registration

```
$ venv/bin/python -c "... asyncio.run(mcp.list_tools()) ..."
26 tools: [add_podcast, delete_library_items, download_books, ...]
```
26/26, matches monolith tool count exactly, no duplicates.

```
$ PYTHONPATH=src venv/bin/python -m pytest tests/mcp/ -v --no-cov
8 failed, 11 passed in 20.43s
```
Same 8 known failures as the pre-Task-1 audit (stale ABS test credentials /
pre-existing pipeline.py gap / stale pre-DR-6 test) — no new failures from
Task 1's wiring.

```
$ PYTHONPATH=src venv/bin/python -m pytest tests/test_profanity_cleaning_mcp_friendly.py -v --no-cov
```
Initial run: 1 collection ERROR. `_load_mcp_server_module()` used
`importlib.util.spec_from_file_location` to script-load `mcp_server.py`
without package context — worked against the old monolith (bare imports)
but breaks now that `mcp_server.py` uses proper package-relative imports
(`from .config import ...`), per DR-1's intent of removing the sys.path
hack. Fixed: replaced the loader with a normal `from abs_mcp.tools import
ingestion` import — all names these tests monkeypatch (`_build_config`,
`_detect_audio_extension`, `step_organize`, `_record_tool_result`,
`_active_job`, `_last_downloaded_asins`) are already present as module-level
names on `tools/ingestion.py` (imported there via `from ..config import
(...)`), so no further changes needed.

After the loader fix: 7 passed, 1 failed
(`test_get_cleaning_progress_callable_during_job` asserted
`isinstance(progress, str)`) — this assertion directly contradicted
`tests/mcp/test_ingestion.py::test_get_cleaning_progress_returns_dict`'s
`isinstance(result, dict)` for the *same function*, left over from before
the dict-return fix applied during the pre-Task-1 audit. Updated the
assertion to `isinstance(progress, dict)` to match the now-consistent
convention.

```
$ PYTHONPATH=src venv/bin/python -m pytest tests/test_profanity_cleaning_mcp_friendly.py -v --no-cov
8 passed in 3.09s
```

```
$ PYTHONPATH=src venv/bin/python -m pytest tests/ --ignore=tests/mcp -q --no-cov
80 passed, 12 skipped in 3.39s
```
0 failures. Plan's expected "≥125 pass" baseline was stale — confirmed via
`--collect-only` that only 92 tests exist in the suite total (80+12). Not a
regression, just an inaccurate prior estimate.

## Task 6: Functional testing over production protocol

Started a local `MCP_TRANSPORT=streamable-http` server on port 8765,
confirmed `initialize` returns `serverInfo.name == "Audiobook Ingestion"`,
confirmed `tools/call` for `list_libraries` and `get_status` succeed, killed
the local server. (Note: this local-server portion ran in an earlier turn of
this session, prior to a context summarization event — the exact terminal
transcript for that sub-step was not preserved verbatim; the pass/fail
outcome above is carried forward from that turn's recorded state, not
re-derived here.)

Three sub-steps were deferred to after Task 7 (deploy) at the user's
direction, so they could run against `open-audible`'s live deployment with
the test ABS VM (`192.168.101.156`) as the target instead of a throwaway
local server: bridge protocol test, error-path test, and the
mutating/write-tool + async-job-pattern tests. Exact output below.

### Bridge protocol test (ran on `open-audible`, using deployed code + `.env`)
```
$ ssh stratus@open-audible "cd ~/OpenAudible-To-AudioBookShelf && echo -e 'TOOLS\nQUIT' | venv/bin/python -m abs_mcp._mcp_bridge"
READY
{"tools": ["add_podcast", "delete_library_items", "download_books", "download_podcast_episodes", "download_podcast_files", "export_library", "fetch_podcast_feed", "get_cleaning_progress", "get_job_result", "get_podcast_episodes", "get_source_status", "get_status", "get_tool_metrics", "ingest_books", "list_abs_library", "list_libraries", "list_library", "list_podcasts", "match_audiobookshelf", "organize_books", "query_tool_metrics_history", "scan_audible", "scan_audiobookshelf", "search_abs_library", "search_podcasts", "set_book_status"]}
```
26 tools, matches expected set exactly. PASS.

### Error-path test (live protocol, invalid library name)
```
$ curl -sS -X POST http://open-audible.x86experts.com:8765/sse \
  -H "mcp-session-id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"get_status","arguments":{"library":"nonexistent_library_xyz"}}}'

data: {"jsonrpc":"2.0","id":10,"result":{"content":[{"type":"text","text":"{\n  \"library\": \"nonexistent_library_xyz\",\n  \"media_type\": \"book\",\n  \"source_dir\": \"/home/stratus/Libation/Books\",\n  \"destination_dir\": \"(not set)\",\n  \"abs_server\": \"http://192.168.101.156:13378\",\n  \"abs_library_id\": \"(not set)\",\n  \"download_engine\": \"Libation\",\n  \"abs_status\": {...}\n}"}],"isError":false}}
```
No crash/hang; unknown library falls back gracefully to `"(not set)"` for
library-specific fields while global config (test-VM `abs_server`) still
resolves. PASS (graceful degradation, not a hard error — acceptable per
plan's "server returns an error response (not a crash/timeout)" bar).

### Async job pattern (`organize_books` + `get_job_result`) — mutating tool test
Source dir on `open-audible` (`/home/stratus/Libation/Books`) had 3 real
downloaded books. `COPY_INSTEAD_OF_MOVE=true` and
`LIBATION_FOLDER_CLEANUP=false` in the deployed `.env`, so this exercises
the write path non-destructively (copy, not move; source untouched).
```
$ curl ... -d '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"organize_books","arguments":{"purchased_how_long_ago":9999}}}'
data: {"jsonrpc":"2.0","id":11,"result":{"content":[{"type":"text","text":"{\n  \"job_id\": \"e4e2d241a949\",\n  \"status\": \"started\"\n}"}],"isError":false}}

$ sleep 5 && curl ... -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"get_job_result","arguments":{"job_id":"e4e2d241a949"}}}'
{"status": "completed", "job_id": "e4e2d241a949", "result": {
  "step": "organize", "success": true, "processed_count": 3,
  "moved": ["The Unbeatable Squirrel Girl Squirrel Meets World", "Heretical Fishing: ...", "US History for Teens: ..."],
  "total_in_source": 1782, "applied_asins": ["B01N0NKMIG", "B0CVCYB19Y", "B0CY8WT5DK"],
  "destination_dir": "/home/stratus/abs_mcp_test_deploy_dest", "cleaning": {}, "cleaning_failures": [],
  "audio_file_extension": ".m4b"
}}
```
Verified on disk: files landed in `Author/Title` tree under
`/home/stratus/abs_mcp_test_deploy_dest/`, source directory unchanged (copy
confirmed via `find` + `ls`). PASS — job-start → poll → completed lifecycle
works end-to-end over the wire.

### ABS-mutating tools against the test VM
```
$ curl ... -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"scan_audiobookshelf","arguments":{}}}'
data: {"jsonrpc":"2.0","id":13,"result":{"content":[{"type":"text","text":"{\n  \"step\": \"scan-abs\",\n  \"success\": true,\n  \"status_code\": 200,\n  \"wait_seconds\": 15\n}"}],"isError":false}}

$ curl ... -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"match_audiobookshelf","arguments":{}}}'
data: {"jsonrpc":"2.0","id":14,"result":{"content":[{"type":"text","text":"{\n  \"step\": \"match\",\n  \"success\": true,\n  \"matched_count\": 0,\n  \"log\": \"...\"\n}"}],"isError":false}}

$ curl ... -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"list_abs_library","arguments":{"limit":10}}}'
{"library": "adult", "total_in_library": 0, ..., "items": []}

$ curl ... -d '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"delete_library_items","arguments":{"delete_all":true,"library":"adult"}}}'
data: {"jsonrpc":"2.0","id":16,"result":{"content":[{"type":"text","text":"{\n  \"deleted\": 0,\n  \"results\": []\n}"}],"isError":false}}
```
All three succeed against the test VM (empty library, so `delete_all` and
`match` are no-op-safe). PASS, no crashes.

**Intentionally not exercised:** `download_books`, `ingest_books` (real
Audible downloads — out of scope for a structural refactor, unrelated to the
ABS-target concern), `add_podcast`/`download_podcast_episodes`/
`download_podcast_files` (real external network fetches — same reasoning).

## Task 7: Deploy to open-audible

Committed `abs_mcp/`, `docker/`, `tests/mcp/`,
`tests/test_profanity_cleaning_mcp_friendly.py` changes; pushed; pulled on
`open-audible`; copied the updated systemd unit; `daemon-reload` +
`restart`. Hit two infra issues along the way, both environmental, not
code:

1. `sudo systemctl daemon-reload` / other `sudo` commands hung indefinitely.
   Initially suspected NFS outage for `arch-test-openaudible`
   (192.168.101.58, unreachable). User confirmed NFS was fine and rebooted
   `open-audible`, which resolved the hang.
2. Post-reboot, service crash-looped: `ImportError: cannot import name
   'resolve_books_json_path' from 'openaudible_to_audiobookshelf.utils'`.
   `abs_mcp/config.py` depends on a function added to local
   `src/openaudible_to_audiobookshelf/{utils,pipeline}.py` in earlier,
   unrelated work that hadn't been synced to the remote yet. Fixed by
   rsyncing those two `src/` files to `open-audible` per user instruction,
   then restarting — service came up clean.

Post-deploy smoke test (tool count against the live server):
```
$ curl -sS -m 10 -X POST http://open-audible.x86experts.com:8765/sse \
  -H "mcp-session-id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list"}' | grep -o '"name":"[a-z_]*"' | sort -u | wc -l
26
```
26/26 tools live on the production deployment, pointed at the test ABS VM
per `abs_mcp/.env`'s `ABS_SERVER_URL=http://192.168.101.156:13378`
(deliberately not production ABS, per explicit user instruction). The
`initialize` and `systemctl status` exact transcripts for this task also
predate the session's context-summarization event and are not reproduced
verbatim here; the "active (running)" / healthy outcome is carried forward
from that turn.

## Task 8: Update documentation (KB + OpenSpec)

**OpenSpec** — `openspec/specs/ingestion-mcp/spec.md` had one pending
uncommitted diff (`abs-mcp/` → `abs_mcp/` rename in the Purpose section,
predating this plan). Verified scenario count unchanged and no remaining
hyphenated refs:
```
$ rg -c 'Scenario:' openspec/specs/ingestion-mcp/spec.md
64
$ rg 'abs-mcp' openspec/specs/ingestion-mcp/spec.md | wc -l
0
```
64/64 unchanged — confirms structural-only refactor, no behavioral-contract
changes. No archive needed.

**KB** — `~/git_projects/scratch_pad/knowledge/media/audiobook-pipeline.md`:
- §2 "Code layout" replaced with the new `abs_mcp/` module tree
  (`mcp_server.py` assembly point, `config.py`, `tools/{ingestion,discovery,
  podcast,metrics}.py`, `abs_cache.py`, `cleanup.py`, `podcast_tools.py`,
  `library_parser.py`, `tool_metrics.py`, `_mcp_bridge.py`), plus a note on
  module invocation (`python -m abs_mcp.mcp_server`).
- §2 "Two deployment paths" table removed; replaced with a sentence noting
  systemd+venv is the actual production deployment on `open-audible`, with
  the container image available but not deployed.
- Tool count references corrected from "20+" to "26" (2 spots).
- All remaining `abs-mcp/` → `abs_mcp/` fixed (front-matter source path,
  key-config table paths, prose references) — verified 0 matches remain.
- `updated:` bumped to `2026-07-25`; `confidence: verified` unchanged.
```
$ rg 'abs-mcp/' ~/git_projects/scratch_pad/knowledge/media/audiobook-pipeline.md
(no output, exit 1)
```
Committed to the `scratch_pad` repo:
```
$ git commit -m "kb: audiobook pipeline — mcp_decomposition module layout + abs_mcp rename"
[main 1790962] kb: audiobook pipeline — mcp_decomposition module layout + abs_mcp rename
 1 file changed, 30 insertions(+), 26 deletions(-)
```

## Result

All 8 tasks (incl. 1.5) complete. The 2,426-line monolith is now a 117-line
assembly point plus `config.py` + 4 `tools/*.py` modules (already-extracted
WIP, salvaged and bug-fixed per the pre-Task-1 audit). 26/26 tools verified
registered at every checkpoint: module introspection (Task 1/5), bridge
protocol (Task 6), and the live production deployment (Task 7). Deployed to
`open-audible` via systemd+venv, module invocation
(`python -m abs_mcp.mcp_server`), pointed at the test ABS VM
(`192.168.101.156`) rather than production ABS throughout all functional
testing. Full functional test matrix passed over the actual streamable-http
protocol: happy path, error path, bridge protocol, and — as a deliberate
extension beyond the original Task 6 scope — the async job pattern and
ABS-mutating tools (`organize_books`, `scan_audiobookshelf`,
`match_audiobookshelf`, `delete_library_items`) exercised live against the
test VM with verified non-destructive side effects (copy-not-move
confirmed on disk).

One pre-existing, non-blocking divergence was found (not fixed, per user
decision): `add_podcast`'s folder-name sanitization uses the shared
`sanitize_filename()` helper in the WIP, which is marginally stricter
(strips control chars + trailing dots/spaces) than the monolith's narrower
inline regex for that one call site. User decided to leave it — standardize
on the shared sanitizer rather than revert to the narrower monolith
behavior.

Eight failing tests in `tests/mcp/` remain unfixed, all categorized as
environmental (stale ABS test credentials) or pre-existing/out-of-scope
(pipeline.py `ConnectionError` gap; one stale pre-DR-6 test) — none are
WIP-vs-monolith code divergences introduced by this refactor.

## Next Steps (optional, not part of this plan)

- Refresh the stale ABS test credentials referenced by `tests/mcp/`'s 3
  remaining credential-related failures.
- Consider fixing the pipeline.py `ConnectionError`-on-unreachable-ABS gap
  (pre-existing, affects both monolith and decomposed code equally).
- Consider exercising `download_books`/`ingest_books`/podcast-download tools
  functionally if/when a safe sandboxed Audible/podcast fixture is
  available — currently untested over the wire (unchanged from the
  monolith, so low risk, but still a gap).
- Container cutover remains deferred (DR-1/DR-4) — no action needed unless
  NFS-mount complexity is later deemed worth solving.
