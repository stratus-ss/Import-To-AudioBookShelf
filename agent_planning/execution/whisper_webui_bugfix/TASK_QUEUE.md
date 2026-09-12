# Task Queue — whisper_webui_bugfix

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | Fix Bug #2 — Inverted dict comprehension (base_transcription_pipeline.py:580) | done | Original 1-line fix from bug report — INCOMPLETE (downstream rejects full_name) |
| 1b | CORRECT Bug #2 fix — Remove broken transformation entirely | done | Pass lang through unchanged; verified with live test |
| 2  | Fix Bug #1 — Wrong function name + args in swear_removal router | done | `_run_transcription` helper + correct service call |
| 2b | Fix cascading bug: `_get_output_filename` undefined | done | Routed to `swear_service.get_output_filename()` |
| 2c | Fix cascading bug: `_save_statistics_files` undefined | done | Routed to `swear_service.save_statistics_files()` |
| 2d | Fix cascading bug: `swear_service` undefined in `_create_result` | done | Added `SwearRemovalService()` inside `_create_result` |
| 3  | Fix Bug #3 — Background task failure propagation in transcription router | done | `import logging` + try/except + FAILED status update |
| 4  | Build and push container image to quay.io | done | Tag: `swear0.3.6` (preserves `swear0.3.5` for rollback). 5 build cycles due to cascading bugs. Final digest: `sha256:4f0d650b7a56...` |
| 5  | Deploy on containers-gpu (pull + restart) | done | Compose file updated to `swear0.3.6`; 4 deploy cycles; service returning 200 on /docs |
| 6  | Functional test against live endpoint | done | All 3 tests PASS. Test 1: lang=en completes. Test 2: /swear-removal/ completes. Test 3: invalid model returns failed status. |
| 7  | Writeback — KB update + execution protocol artifacts | done | KB doc updated; GO_BACK_VERIFICATION.md created; deviation log included |

**ALL TASKS COMPLETE** — plan finished 2026-07-23. Container deployed, all 3 functional tests pass. See devlog for full execution log.

Statuses: `todo` / `doing` / `done` / `blocked` / `skipped`