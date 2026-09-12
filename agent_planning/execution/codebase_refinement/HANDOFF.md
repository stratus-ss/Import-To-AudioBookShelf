# Handoff — codebase_refinement

**Written:** 2026-07-23 (Plan 3 — MCP Restructure starting)

## Bootstrap
Read in order:
1. `zed_plans/codebase_refinement_plan3_2026-07-22.md` — OBJECTIVE + Task 1 section only
2. `agent_planning/execution/codebase_refinement/SESSION_BRIEF.md`
3. `agent_planning/execution/codebase_refinement/TASK_QUEUE.md`

## Where We Are
Plans 1 and 2 complete. Plan 3 — MCP Restructure started. **Tasks 1-8 done** (file-based ASIN handoff replaces global). Task 9 next (str → dict return types).

## Next Action
Execute Task 9: change all `_record_tool_result` calls from `json.dumps(result)` to native `dict` (25 tools across 4 modules). Update `_record_tool_result` signature to fully pass dict through (not double-serialize for metrics). Verify FastMCP structuredContent works.

## Known Blockers / Gotchas
- **CRITICAL — Plan 3 Task 1 infrastructure fix:** ABS data was originally on `/tmp/abs-test/` which is **tmpfs** (RAM-backed) — VM reboot wipes everything. Fixed in Task 1 by migrating to `/var/lib/abs-test/` (persistent xfs). Snapshot `abs-clean-base` captures this state. If VM is rebooted without --restart=always on the container, must `docker start abs-test` manually after boot.
- **Auth endpoint layout (Task 1 discovery):** `/login` for username/password (NOT `/api/login`). `/auth/refresh` for token refresh (NOT `/api/auth/refresh`). `/api/*` requires Bearer JWT. Access tokens expire 10 min; refresh tokens last 30 days.
- **VM/container naming is exact:** VM `abs-test-refinement` (id=76) on dl380, IP 192.168.101.156; ABS port 13378; creds `admin`/`adminpass123`; library `9b922ea1-106c-419f-a8bc-8c0e06fd5193`
- **kvm-mcp `guest_exec` allowlist does NOT include docker** — use SSH to manipulate ABS container if needed during functional tests
- **Snapshot MUST be taken while VM stopped** — libvirt requires it; kvm-mcp will reject if running
- **KB doc** at `~/git_projects/scratch_pad/knowledge/media/audiobook-pipeline.md` was SKIPPED in Plans 1/2 per user feedback (out-of-repo); confirm if Plan 3 user applies same constraint — if so, KB doc update is skipped, in-repo docs are the source of truth
- **Vikunja task #108** stayed in "doing" through Plans 1/2; Plan 3 is the last plan (per its final TASK); user decides when to close it (Plan 3 Task 13 only adds comments, does NOT close)
- **STOP RULE from plan:** Stop after all 15 tasks complete. Do NOT add new tasks. Do NOT destroy VM.
- **Existing helper modules stay standalone:** `podcast_tools.py`, `abs_cache.py`, `cleanup.py`, `library_parser.py`, `tool_metrics.py` are NOT merged into tool modules; they remain separate and are imported by tool modules
- **17 MCP tools** distributed: ingestion(8) + discovery(7) + podcast(7) + metrics(2). Verification step 4 expects `len(tools) >= 16` (some tools may have variants)

## KNOWN BUGS (Plan 3 follow-up)

### Production Whisper `/swear-removal/` endpoint broken (2026-07-23)

**Container:** `backend-app-1` on `containers-gpu.x86experts.com:8001`
**Image:** `quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5`
**Symptom:** Task queues successfully, then immediately fails with `"name '_get_or_create_transcript' is not defined"`
**Root cause:** Missing function in production container code path
**Workaround:** Use `/transcription/` directly (works), then post-process transcript for swears
**Production fix needed:** Either restore `_get_or_create_transcript` definition in container code, or have AudioCleaner bypass `/swear-removal/` and call `/transcription/` directly

### ABS restart breaks VM-internal data (recurring Plan 1 issue)

- `/tmp/abs-test/` was tmpfs (Plan 1) — lost on VM reboot
- Migrated to `/var/lib/abs-test/` (persistent xfs)
- libvirt internal qcow2 snapshot STILL doesn't capture this state (discovered Plan 3 Task 12)
- Resolution: recreate ABS container on dl380 host (VM retained as required by plan)

## ACTIVE LONG-RUNNING PROCESSES

- PID 665629: Real Whisper stress test (started 2026-07-23 12:21:18)
  - 7 LibriVox chapters × ~30 min = 3.5h audio
  - Production Whisper at containers-gpu.x86experts.com:8001
  - MCP server behavior test during real cleaning
  - Logs: /tmp/real_audiobook/logs/stress.log

## NEXT STEPS

- Plan 3 Tasks 13-15: Vikunja update, docs, archive
- Production Whisper bug: file issue / coordinate with sovens team
- Stress test result: review after completion (~4 hours from 12:21)

## KNOWN BUGS (updated 2026-07-23)

### BUG: Production Whisper `/transcription/` KeyError on `lang=en` (2026-07-23)

**Symptom:** POST `/transcription/?model_size=tiny&lang=en` returns `201 Created` with task id, then `GET /task/{id}` reports `status: in_progress, progress: 0.0%` forever. GPU usage may show ~23% from other processes, but the task never actually processes.

**Real cause (in container):** `/Whisper-WebUI-Swear-Removal/modules/whisper/base_transcription_pipeline.py:580`:
```python
language_code_dict = {value: key for key, value in whisper.tokenizer.LANGUAGES.items()}
params.whisper.lang = language_code_dict[params.whisper.lang]
```

`LANGUAGES` is `{"en": "english", "zh": "chinese", ...}` (key=code, value=full_name).
The dict comprehension creates `{"english": "en", "chinese": "zh", ...}` (BACKWARDS).
Looking up `params.whisper.lang="en"` then raises `KeyError: 'en'`.

**Error propagation bug:** The exception happens in a background thread but doesn't update the task status to `failed`. Tasks stay at `in_progress, progress=0.0%` indefinitely.

**Workarounds:**
1. Don't pass `lang` parameter — auto-detection works fine
2. Pass `lang=english` (full name) — works because dict key is the full name
3. Production fix: change `{value: key for key, value in items()}` to just `dict(LANGUAGES)` or `{key: value for key, value in items()}`
