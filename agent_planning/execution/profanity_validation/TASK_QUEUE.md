# Task Queue — profanity_validation

| ID | Task | Status | Notes |
|----|------|--------|-------|
| 1  | Set REMOTE_WHISPER_URL in .env | done | `.env` line 17 |
| 2  | Add profanity-cleaning validation to MCP server | done | 3 paths verified manually; full suite 117 passed |
| 3  | Add tests (TestProfanityCleaningValidation class, 5 methods) | done | 5 new tests pass |
| 4  | Update KB doc media/audiobook-pipeline.md troubleshooting | done | frontmatter + troubleshooting entry |
| 5  | Functional validation (deploy MCP, real stdio MCP commands, negative + positive paths) | done | partial pass: NEGATIVE PATH PASS; POSITIVE validation+invocation PASS; POSITIVE bytes-differ FAIL (test-data limitation) — see devlog + result.json |
