# Handoff — profanity_cleaning_resume

**Written:** 2026-07-25 17:18

## Bootstrap
This project is COMPLETE. All 8 tasks done. Read in order if resuming:
1. `zed_plans/profanity_cleaning_resume_2026-07-25.md` — full plan
2. `agent_planning/execution/profanity_cleaning_resume/SESSION_BRIEF.md` — final state
3. `agent_planning/execution/profanity_cleaning_resume/devlogs/profanity_cleaning_resume_2026-07-25.md` — execution log

## Where We Are
DONE. See SESSION_BRIEF.md for final state, commits, and deployment status.

## Next Action
None — project complete. If you need to verify the deployed state:
1. SSH to open-audible.x86experts.com
2. `git -C /home/stratus/OpenAudible-To-AudioBookShelf log --oneline -3` (should show 5f523a9 + merges)
3. `cat /home/stratus/OpenAudible-To-AudioBookShelf/abs_mcp/.env | grep WORKING_DIRECTORY` (should be `/home/stratus/.cache/monkeyplug-cleaning`)
4. `systemctl status audiobook-ingestion-mcp` (active)

## Known Blockers / Gotchas (for future work)
- Working dir was previously `/tmp/monkeyplug-cleaning` — wiped on reboot. Fixed in 51d419b (default `~/.cache/monkeyplug-cleaning`). Override via `WORKING_DIRECTORY` env var.
- Whisper backend at containers-gpu.x86experts.com runs single uvicorn worker — long transcriptions block ALL other endpoints including `/docs`. Documented in `whisper-webui.md` §2a. Mitigation: chunked uploads (≤150MB via monkeyplug) + per-chunk resume. Real fix would need Celery/RQ or async background tasks.
- VM soft lockup root cause was 32 vCPUs + 8GB RAM. Fixed by reducing to 4 vCPUs + 6GB RAM + multi-user.target. Documented but not in plan — was diagnosed live during execution.
- 8 MCP tests in `tests/mcp/test_*.py` fail with HTTP 401 — pre-existing ABS auth issue, NOT caused by this work. Verified by stashing changes.

## Planning Corrections (lessons learned)
- Task 5 added an extra test (test_mark_resume_status_in_progress_requires_working_dir) beyond the 8 in the plan — required for schema integrity.
- Task 5 also updated existing test_resume_state_written_on_failure in test_move_audio_book_files.py to match new DR-2 schema — required since test would otherwise fail.
- Task 6 uncovered a critical bug: working dir default was /tmp (volatile). Plan had assumed the dir would persist; reality was different. Bug fixed in 51d419b.
- VM infrastructure (vCPUs, RAM, target) was not in the plan but discovered during execution. Future plans for this project should include an infra check step.

## Final commit history (all pushed to origin/dev + origin/feature/resume-cleaning)
```
3b85f53 feat(audio_cleaner): per-chunk profanity cleaning resume
51d419b fix(audio_cleaner): move working directory to durable path
5f523a9 docs(openspec): add resume-state delta to pipeline + ingestion-mcp specs
e95fed8 docs(skills): document profanity-cleaning resume feature
00db85e build: add sync-skills and sync-skills-check Makefile targets
```

## Post-completion: revert to production (2026-07-25 18:33)
The deployed `.env` and `libraries.yaml` on open-audible were modified for the test/proof-of-concept to point at the test ABS (`192.168.101.156:13378`). User asked to revert to production for end-user access via Moltis.

Reverted by scp'ing the committed production `.env` and `libraries.yaml` from this repo back to open-audible and restarting the MCP service.

Verified post-revert config via `_build_config()`:
- `abs_url`: `http://kids-audio-books.x86experts.com` (production)
- `abs_lib_id`: `1cc175ca-...` (adult)
- `dest`: `/home/stratus/Adult_Books` (production)
- `working_dir`: `/home/stratus/.cache/monkeyplug-cleaning` (durable default from commit 51d419b)

The custom WORKING_DIRECTORY line we added to .env was removed because the production .env doesn't have it and the default now lives in `config.py` (more durable). The default will still resolve to `~/.cache/monkeyplug-cleaning` on any host.

## Post-completion: fix /sse → /mcp path mismatch (2026-07-25 18:56)
MCP server restart + moltis agent reconnects revealed a path mismatch:
- Deployed MCP server mounts streamable-http at `/mcp` (per FastMCP default + `MCP_STREAMABLE_PATH=/mcp` in .env)
- Client proxy on arch-openclaw hardcoded `8765/sse` (legacy SSE path)
- Result: 404 on every reconnect, agent sees "MCP not ready", repeatedly retries

Fixed by updating 2 client config files on arch-openclaw:
- `/home/stratus/.local/bin/audiobook-mcp-proxy.sh` — `8765/sse` → `8765/mcp`
- `/home/stratus/.config/moltis/moltis.toml` — same

Then `sudo systemctl restart moltis` on arch-openclaw. Verified `moltis_mcp::manager: MCP server started with tools server=audiobook-ingestion`. Subsequent traffic to open-audible shows `POST /mcp 200 OK` (vs prior `POST /sse 404`).

## Skills updated
All 3 skills (moltis, claude-code, cursor) document:
- New `resuming` stage in `get_cleaning_progress` output
- Resume state path (`~/.cache/monkeyplug-cleaning/`, NOT `/tmp`)
- Both legacy string and new object JSON formats
- Action: re-invoke `organize_books` after MCP crash/restart

## KB writeback
scratch_pad commit ba80521:
- `knowledge/media/audiobook-pipeline.md` — durable working dir + per-chunk resume contract
- `knowledge/services/whisper-webui.md` — new §2a single-worker limitation