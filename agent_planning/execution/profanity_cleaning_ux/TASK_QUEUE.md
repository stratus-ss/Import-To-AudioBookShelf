# Task Queue — profanity_cleaning_ux

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | audio_cleaner.py: systemd journal logging + book-level resume state + fail-fast backend check (1a/1b/1c) | done | imports added, _RESUME_FILE constant, _is_already_processed + _mark_resume_status helpers, dual logging to journal, fail-fast via requests.head |
| 2  | mcp_server.py + pipeline.py: duration hint + progress state + cleaning stats + `get_cleaning_progress` tool (2a/2b/2c/2d) | done | threading import, _cleaning_progress + lock + _update/_reset helpers, _progress_callback wired through Config→AudioCleaner, _fire_progress at 4 lifecycle points, cleaning key in step_organize return, new MCP tool registered |
| 3  | tests: 7 new test cases in TestProfanityCleaningUx (new class) | done | all 7 pass; full suite 124 passed (+7), 12 skipped, 1 pre-existing failure unrelated |
| 4  | skill (moltis-audiobook-pipeline.md) + KB (media/audiobook-pipeline.md) updates | done | skill committed as b792750, deployed to prod; KB troubleshooting entry replaced + frontmatter bumped 2026-06-25 → 2026-07-22 (in scratch_pad repo) |
| 5  | **Functional validation against live prod MCP server** (5a tool registration, 5b fail-fast surface, 5c happy path + resume=done, 5d resume skip on rerun, 5e journal logging) | done | 5a 5b 5c 5d PASSED on prod; 5e partial (dual-log mechanism verified, full journal capture requires SSE tool invocation); also fixed fail-fast probe bug discovered during 5b (HEAD→TCP) |
| 6  | deploy to production (open-audible.x86experts.com) | done | HEAD on prod = b792750; service active (PID 2215600), 25 tools registered incl. get_cleaning_progress, journal clean |