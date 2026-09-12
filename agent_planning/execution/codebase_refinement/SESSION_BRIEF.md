# Session Brief — codebase_refinement

**Updated:** 2026-07-23

## Objective
Split 1583-line `abs-mcp/mcp_server.py` into a thin assembly + 5 modules; remove `_last_downloaded_asins` global with file-based handoff; change all 17 MCP tools to return `dict`; create `tests/mcp/` integration tests; append ~47 OpenSpec scenarios.

## Current Task
Task 3 — Extract `abs-mcp/config.py` (shared infrastructure: env loading, library registry, config construction, auth headers, metrics wiring, shared utilities).

## Status
- Last completed: Task 2 — Package `__init__.py` files created; symlink `abs_mcp -> abs-mcp` added for Python imports
- Active: Task 3
- Blocked on: (none)

## Next Action
1. Read `abs-mcp/mcp_server.py` lines 26-43, 46-101, 103-107, 187-188, 198-211, 228-290, 293-353 (per plan line references for config extraction)
2. Extract infrastructure code into `abs-mcp/config.py` per plan §STRUCTURE Task 3 Parts A-F:
   - Part A: Imports (with `import threading` added for `_CLEANING_PROGRESS_LOCK`)
   - Part B: `_load_dotenv`, `_env`, `_r`, `_log_buffer`, `_elapsed_ms`, `_abs_headers`
   - Part C: Library registry (`_load_libraries`, `_resolve_library`)
   - Part D: `_build_config` (POST-Plan-2 version using `Config.from_dict()`)
   - Part E: Metrics wiring + module-level singletons + `_record_tool_result` (dict signature)
   - Part F: Logger setup
3. Verify imports work via `sys.path.insert(0, 'abs-mcp'); from config import ...`
4. Verify `_build_config()` still works (constructs Config with all HTTP fields)
5. Verify `_load_libraries()` still returns the YAML library registry

## Files In Scope
- `abs-mcp/config.py` — new module (extracts infrastructure from mcp_server.py)
- `abs-mcp/mcp_server.py` — line counts shrink as code is extracted (extraction in this task; deletion in Task 7)
- `abs-mcp/__init__.py` + `abs-mcp/tools/__init__.py` — package markers (done)
- `abs-mcp/_mcp_bridge.py` — relative import update (Task 7)
- `abs-mcp/tools/{ingestion,discovery,podcast,metrics}.py` — extraction targets (Tasks 4-6)
- `abs-mcp/test_mcp.sh` — update for dict returns (Task 14)
- `abs-mcp/skills/moltis-audiobook-pipeline.md` — note explicit ASIN handoff (Task 14)
- `openspec/specs/ingestion-mcp/spec.md` — append ~47 scenarios (Task 10)
- `tests/mcp/{conftest,test_ingestion,test_discovery,test_error_paths,test_cache,test_asins_file}.py` — integration tests (Task 11)
- `README.md` — add package structure section (Task 14)
- `agent_planning/execution/codebase_refinement/artifacts/test_config.json` — refreshed with new RT
- `agent_planning/execution/codebase_refinement/artifacts/plan1_amendments.md` — written in Task 1
- `agent_planning/execution/codebase_refinement/artifacts/plan3_functional_test_results.json` — write in Task 12

## Critical Context for Task 3
- **Plan §STRUCTURE Task 3 §Part A** says `from tool_metrics import ToolMetricsRecorder` — direct import (relative imports come in Task 7)
- **Plan §STRUCTURE Task 3 §Part D** says `_build_config()` uses `Config.from_dict()`. Post-Plan-2 code already does this.
- **Plan §STRUCTURE Task 3 §Part E** says `_record_tool_result` signature takes `result: dict` (anticipates Task 9 change)
- `ABS_MCP_DIR = Path(__file__).resolve().parent` — when moved to `abs-mcp/config.py`, this resolves to `abs-mcp/`
- Module-level env loading MUST run at import time (lines 61-65 in current code)
- `import threading` needs to be added (used by `_CLEANING_PROGRESS_LOCK`)
