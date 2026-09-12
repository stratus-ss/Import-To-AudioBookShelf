# Plan: Fix 3 Whisper-WebUI Backend Bugs + Rebuild & Deploy Container

**Date:** 2026-07-23
**Tier:** 1 (bugfix, single-system; deployment is verification, not primary artifact)
**Domain addendum:** software (+ container verification per infrastructure.md §A11)
**Model addendum:** minimax/MODEL_ADDENDUM.md
**project_name:** whisper_webui_bugfix

**Discovery source:** `agent_planning/execution/codebase_refinement/artifacts/whisper_bug_report.md` — 3 production bugs discovered during Plan 3 integration testing of the `Import-To-AudioBookShelf` pipeline on 2026-07-23.

---

## OBJECTIVE

**What I understand:** Fix three production bugs in the Whisper-WebUI backend container: Bug #1 (`/swear-removal/` crashes with `NameError: _get_or_create_transcript`), Bug #2 (`/transcription/?lang=en` returns `KeyError: 'en'`), and Bug #3 (background task exceptions leave status stuck at `IN_PROGRESS`). Apply one-line or minimal fixes to each file, rebuild the container image, push to quay.io, deploy on containers-gpu, and run functional curl tests proving all three bugs are resolved. **Out of scope:** any refactoring, new features, or changes to the Gradio frontend. **Success measured by:** all 3 functional tests passing against the live deployed endpoint.

**Restatement confirmed by:** bug report with reproduction steps, root-cause analysis, and suggested fixes (authored 2026-07-23 by the same team during codebase refinement).

Token budget: ~25K tokens (plan + 3 source files: router.py 457L, base_transcription_pipeline.py 641L, transcription/router.py 140L).

---

## ACCESS & CREDENTIAL PREREQUISITES

| Target | Type | Credential/Path | Verified? | Verification command |
|--------|------|-----------------|-----------|---------------------|
| `containers-gpu.x86experts.com` | SSH | root key-based | ✅ VERIFIED 2026-07-22 | `ssh -o ConnectTimeout=5 root@containers-gpu.x86experts.com true` |
| `quay.io` | Docker registry | `~/.docker/config.json` or interactive login | ❌ ASSUMED | `docker login quay.io` — must succeed before Task 4 |
| `containers-gpu.x86experts.com:8001` | HTTP (Whisper backend) | No auth (internal LAN) | ✅ VERIFIED 2026-07-22 | `curl -s -o /dev/null -w '%{http_code}' http://containers-gpu.x86experts.com:8001/docs` → 200 |

**Note:** Task 4 will execute `docker login quay.io` interactively or via `~/.docker/config.json`. If quay credentials are stored elsewhere, the executor should locate them before Task 4. If the backend endpoint returns non-200 at any point, the container may have crashed — check `docker logs` on containers-gpu before proceeding.

---

## PROJECT CONTEXT

- **Language:** Python 3.11 (container base `python:3.11-slim`)
- **Runtime:** FastAPI (uvicorn), NVIDIA CUDA (cu128 for Blackwell sm_120)
- **Repo root:** `/home/stratus/git_projects/Whisper-WebUI/`
- **Docker:** 29.6.2, buildx with NVIDIA runtime (verified on local build host `stratus-desktop`)
- **GPU (local build host):** NVIDIA GeForce RTX 5070 Ti (sm_120, driver 610.43.03) — used for `docker build`
- **GPU (deploy target, containers-gpu):** NVIDIA GeForce RTX 5060 Ti (sm_120) — both GPUs support cu128; the same image works on both
- **Container image:** `quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5` (9.4GB, exists locally as c4e033d31971)
- **Compose file (deploy):** `/AIStuff/Whisper-WebUI/backend/docker-compose.yaml` on containers-gpu
- **Compose service name:** `app` (port mapping 8001:8000)
- **KB doc:** `services/whisper-webui.md` (verified 2026-07-13, source for compose path and GPU facts)
- **OpenSpec:** No behavioral specs exist for this forked codebase — bugfix-only plan, no new interfaces

---

## KEY FILES REFERENCE

| File | Purpose |
|------|---------|
| `/home/stratus/git_projects/Whisper-WebUI/backend/routers/swear_removal/router.py` | Bug #1 — broken `_get_or_create_transcript` call |
| `/home/stratus/git_projects/Whisper-WebUI/modules/whisper/base_transcription_pipeline.py` | Bug #2 — inverted dict comprehension at line 580 |
| `/home/stratus/git_projects/Whisper-WebUI/backend/routers/transcription/router.py` | Bug #3 — background task failures not persisted to DB |
| `/home/stratus/git_projects/Whisper-WebUI/backend/Dockerfile` | Container build definition (multi-stage) |

---

## STOP RULES

- Stop after all 7 tasks complete. Do not add "nice-to-have" improvements.
- Stop after functional test passes for all 3 bugs. Do not refactor unrelated code.
- Do not modify files outside the 3 listed in KEY FILES REFERENCE.
- Stop after the first working solution per task. Do not optimize further. If you have revised the same code section 3 times without convergence, stop and report.
- Do not parallelize tool calls — process file edits, builds, and deployments sequentially.

---

## TASKS

---

### TASK 1: Fix Bug #2 — Inverted dict comprehension in language lookup

**INTENT:** The `validate_gradio_values` method at line 580 of `base_transcription_pipeline.py` inverts `whisper.tokenizer.LANGUAGES` incorrectly, causing `KeyError: 'en'` when any `lang` parameter is passed to `/transcription/`.

**STRUCTURE:**
In `modules/whisper/base_transcription_pipeline.py`, line 579-580, replace:

```python
language_code_dict = {value: key for key, value in whisper.tokenizer.LANGUAGES.items()}
params.whisper.lang = language_code_dict[params.whisper.lang]
```

with:

```python
language_code_dict = dict(whisper.tokenizer.LANGUAGES)
params.whisper.lang = language_code_dict[params.whisper.lang]
```

**CONTEXT:**
- `whisper.tokenizer.LANGUAGES` is `{"en": "english", "zh": "chinese", ...}` (code → full_name)
- The original comprehension `{value: key for key, value in ...}` produces `{"english": "en", ...}` (full_name → code), so `language_code_dict["en"]` raises KeyError
- `dict(whisper.tokenizer.LANGUAGES)` preserves the original mapping (code → full_name)

**CONSTRAINTS:**
- Change exactly one line. Do not touch anything else in this file.
- Target file: `/home/stratus/git_projects/Whisper-WebUI/modules/whisper/base_transcription_pipeline.py`
- No new imports. No new functions.

**DON'T:**
- Don't add comments
- Don't refactor the surrounding validation logic
- Don't add error handling — the code path already handles `None` and `AUTOMATIC_DETECTION` before reaching line 579

**VERIFICATION:**
⚠️ UNTESTED — synthesized assertion; requires Whisper venv on host
```bash
cd /home/stratus/git_projects/Whisper-WebUI
python3 -c "
import whisper
language_code_dict = dict(whisper.tokenizer.LANGUAGES)
# Spot-check known codes
assert language_code_dict['en'] == 'english', f'{language_code_dict[\"en\"]}'
assert language_code_dict['zh'] == 'chinese'
assert language_code_dict['es'] == 'spanish'
print('PASS: /transcription/?lang=en will now work')
"
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

CODE REVIEW: Verify against EXECUTION_PROTOCOL.md Section 9 checklist before marking done.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 1 entry to Execution Log section
  - Update Remaining Tasks checklist from TASK_QUEUE.md
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
  - If this is Task 1, create the devlog file first
```

---

### TASK 2: Fix Bug #1 — Wrong function name and argument signature in swear_removal router

**INTENT:** The `/swear-removal/` endpoint calls `_get_or_create_transcript()` which does not exist. The correct method is `SwearRemovalService.get_or_create_transcript()` with a different argument signature.

**STRUCTURE:**

In `backend/routers/swear_removal/router.py`:

**Step 1 — Declare a single timestamp variable** immediately after `timestamp = datetime.now().strftime(...)` at line 115. Replace the existing line 115 assignment with:

```python
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
transcript_audio_path = _save_temp_audio(audio, base_name, timestamp, params.sample_rate)
```

**Step 2 — Replace lines 117-119** (the broken call):

```python
# Get or create transcript
word_list, transcript_reused = _get_or_create_transcript(
    audio, base_name, params.reuse_transcript, identifier
)
```

with:

```python
# Get or create transcript via service
swear_service = SwearRemovalService()
word_list, transcript_reused = swear_service.get_or_create_transcript(
    audio_path=transcript_audio_path,
    base_name=base_name,
    transcribe_fn=lambda: _run_transcription(transcript_audio_path, identifier),
    reuse=params.reuse_transcript
)
```

**Step 3 — Update the `_save_temp_audio` call at line 128** to reuse `transcript_audio_path` instead of re-saving:

Replace:
```python
temp_input_path = _save_temp_audio(audio, base_name, timestamp, params.sample_rate)
```
with:
```python
temp_input_path = transcript_audio_path
```

**Step 4 — Add the `_run_transcription` helper** before the existing `run_swear_removal` function (before line 91):

```python
def _run_transcription(audio_path: str, task_identifier: str) -> List[Dict]:
    """Run Whisper transcription and return word-level list."""
    _update_task_progress(task_identifier, 0.55)
    pipeline = get_pipeline()
    segments, _ = pipeline.run(audio_path)
    _update_task_progress(task_identifier, 0.6)
    return [
        {"word": w.word, "start": w.start, "end": w.end, "probability": w.probability}
        for seg in segments for w in seg.words
    ] if segments else []
```

**CONTEXT:**
- `SwearRemovalService` is already imported at line 21: `from modules.swear_removal.swear_service import SwearRemovalService`
- `get_pipeline` is already imported at line 17: `from backend.routers.transcription.router import get_pipeline`
- The `SwearRemovalService.get_or_create_transcript` method signature is: `def get_or_create_transcript(self, audio_path, base_name, transcribe_fn, reuse=True)`
- `_save_temp_audio` already exists at line 73 — it saves a numpy array to a temp WAV file and returns the path
- `datetime` is already imported at line 9
- `transcript_audio_path` is stored once and reused — this avoids the original plan's bug where two `datetime.now()` calls produced different timestamps and therefore different temp file paths for the transcript vs. the cleaner

**CONSTRAINTS:**
- Target file: `/home/stratus/git_projects/Whisper-WebUI/backend/routers/swear_removal/router.py`
- No new imports required — `SwearRemovalService`, `get_pipeline`, `datetime`, `List`, `Dict` are all already imported
- Lines 115 and 128 both reference `transcript_audio_path` — same temp file, one save

**DON'T:**
- Don't modify imports or add new ones
- Don't touch any other function or endpoint in this file
- Don't change the existing try/except in `run_swear_removal` (the existing exception handler at lines 177-190 will propagate failures correctly once the NameError is resolved)

**VERIFICATION:**
⚠️ UNTESTED — synthesized assertion; requires Whisper-WebUI venv with all backend deps
```bash
cd /home/stratus/git_projects/Whisper-WebUI
python3 -c "
from backend.routers.swear_removal.router import run_swear_removal, _run_transcription
from modules.swear_removal.swear_service import SwearRemovalService
import inspect
# Verify _run_transcription exists and is callable
assert callable(_run_transcription), '_run_transcription helper not found'
sig = inspect.signature(_run_transcription)
assert 'audio_path' in sig.parameters, '_run_transcription missing audio_path param'
assert 'task_identifier' in sig.parameters, '_run_transcription missing task_identifier param'
# Verify SwearRemovalService has get_or_create_transcript
assert hasattr(SwearRemovalService, 'get_or_create_transcript'), 'get_or_create_transcript not found'
print('PASS: Function signatures verified')
"
```
Note: This import test requires the full Whisper-WebUI venv. If the venv is not activated, verify the file content directly instead:

⚠️ UNTESTED — fallback grep check
```bash
grep -n 'def _run_transcription' backend/routers/swear_removal/router.py
# Expected: line with 'def _run_transcription(audio_path: str, task_identifier: str)'
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

CODE REVIEW: Verify against EXECUTION_PROTOCOL.md Section 9 checklist before marking done.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 2 entry to Execution Log section
  - Update Remaining Tasks checklist from TASK_QUEUE.md
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
```

---

### TASK 3: Fix Bug #3 — Background task failures not persisted in transcription router

**INTENT:** When `run_transcription` in the transcription router fails (e.g., from Bug #2's KeyError), the exception is uncaught and the task status remains `IN_PROGRESS` indefinitely. The client polls forever and never sees a `FAILED` status.

**STRUCTURE:**

In `backend/routers/transcription/router.py`, wrap the body of `run_transcription` (lines 61-91) in a try/except:

```python
def run_transcription(
    audio: np.ndarray,
    params: TranscriptionPipelineParams,
    identifier: str,
) -> List[Segment]:
    try:
        update_task_status_in_db(
            identifier=identifier,
            update_data={
                "uuid": identifier,
                "status": TaskStatus.IN_PROGRESS,
                "updated_at": datetime.utcnow()
            },
        )

        progress_callback = create_progress_callback(identifier)
        segments, elapsed_time = get_pipeline().run(
            audio,
            gr.Progress(),
            "SRT",
            False,
            progress_callback,
            *params.to_list()
        )
        segments = [seg.model_dump() for seg in segments]

        update_task_status_in_db(
            identifier=identifier,
            update_data={
                "uuid": identifier,
                "status": TaskStatus.COMPLETED,
                "result": segments,
                "updated_at": datetime.utcnow(),
                "duration": elapsed_time,
                "progress": 1.0,
            },
        )
        return segments
    except Exception as e:
        logging.exception(f"Transcription task {identifier} failed: {e}")
        update_task_status_in_db(
            identifier=identifier,
            update_data={
                "uuid": identifier,
                "status": TaskStatus.FAILED,
                "error": str(e),
                "updated_at": datetime.utcnow()
            },
        )
        raise
```

Two changes to the file:
1. Add `import logging` after the existing imports on line 3 (`import numpy as np` → `import numpy as np; import logging`)
2. Wrap lines 61-92 in `try:`/`except` as shown above (indent the existing body one level, add the except block)

**CONSTRAINTS:**
- Target file: `/home/stratus/git_projects/Whisper-WebUI/backend/routers/transcription/router.py`
- Add exactly one new import: `import logging`
- Uses `logging.exception()` (stdlib, no dependency on `modules.utils.logger`) which always logs at ERROR level inside an exception handler
- Do not modify function signature or return type
- Do not change the swear_removal router — it already has correct error handling

**DON'T:**
- Don't refactor function body beyond adding try/except
- Don't add any new dependency on `modules.utils.logger`
- Don't modify endpoint definition or response model

**VERIFICATION:**
⚠️ UNTESTED — synthesized AST introspection; no external deps (stdlib only)
```bash
cd /home/stratus/git_projects/Whisper-WebUI
python3 -c "
import ast, sys
with open('backend/routers/transcription/router.py') as f:
    tree = ast.parse(f.read())
for node in ast.walk(tree):
    if isinstance(node, ast.FunctionDef) and node.name == 'run_transcription':
        has_try = any(isinstance(n, ast.Try) for n in node.body)
        assert has_try, 'run_transcription missing try/except'
        for n in node.body:
            if isinstance(n, ast.Try):
                has_failed = any(
                    ast.dump(h).find('FAILED') != -1
                    for handler in n.handlers
                    for h in ast.walk(handler)
                )
                assert has_failed, 'except block missing FAILED status update'
        print('PASS: run_transcription has try/except with FAILED handling')
        break
"
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

CODE REVIEW: Verify against EXECUTION_PROTOCOL.md Section 9 checklist before marking done.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 3 entry to Execution Log section
  - Update Remaining Tasks checklist from TASK_QUEUE.md
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
```

---

### TASK 4: Build and push container image to quay.io

**INTENT:** Rebuild the backend container image with the three bug fixes applied, then push to the quay.io registry so it can be pulled on containers-gpu.

**STRUCTURE:**

**Step 1 — Log in to quay.io** (if not already logged in):
📖 FROM-DOCS — `docker login` (docker.com/reference/cli/docker/login)
```bash
docker login quay.io
```

**Step 2 — Build the image:**
⚠️ UNTESTED — synthesized from existing image tag and Dockerfile path; cannot test until code fixes applied
```bash
cd /home/stratus/git_projects/Whisper-WebUI
docker build \
  -t quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5 \
  -f backend/Dockerfile \
  .
```

**Step 3 — Push to quay.io:**
⚠️ UNTESTED — requires successful build and quay.io auth
```bash
docker push quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5
```

**CONTEXT:**
- Build context is the Whisper-WebUI repo root (`.`) — the Dockerfile references `backend/` and `requirements.txt` from that root
- Docker 29.6.2 with NVIDIA runtime available locally
- GPU (RTX 5070 Ti) present — CUDA-based build steps will work
- Image tag `swear0.3.5` matches the existing compose file reference
- The existing local image can be retained as a fallback

**CONSTRAINTS:**
- Must run from `/home/stratus/git_projects/Whisper-WebUI/`
- Must use the exact tag `quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5`

**DON'T:**
- Don't change the tag unless quay push fails due to overwrite restrictions
- Don't build with `--no-cache` unless build failures occur — use cache for speed

**VERIFICATION:**
⚠️ UNTESTED — synthesized; standard docker CLI patterns
```bash
# Verify image exists locally with the correct tag
docker images quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5 --format '{{.Repository}}:{{.Tag}} {{.Size}}'

# Verify manifest exists on quay (confirms push succeeded)
docker manifest inspect quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5 | head -3
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 4 entry to Execution Log section
  - Update Remaining Tasks checklist from TASK_QUEUE.md
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
```

---

### TASK 5: Deploy on containers-gpu

**INTENT:** Pull the rebuilt image on containers-gpu and restart the backend service.

**ACCESS PREREQUISITES (verification gate — do not proceed if any check fails):**
1. SSH reachability: `ssh -o ConnectTimeout=5 root@containers-gpu.x86experts.com true` — must return exit code 0
2. Docker running: `ssh root@containers-gpu.x86experts.com "docker info --format '{{.ServerVersion}}' 2>&1"` — must return a version string
3. Compose file exists: `ssh root@containers-gpu.x86experts.com "test -f /AIStuff/Whisper-WebUI/backend/docker-compose.yaml && echo EXISTS"` — must print EXISTS
4. If any check fails: mark task BLOCKED with the specific failure evidence and continue to the next task

**STRUCTURE:**

**Step 1 — Pull the new image:**
⚠️ UNTESTED — requires successful push in Task 4; SSH connectivity ✅ TESTED
```bash
ssh root@containers-gpu.x86experts.com "docker pull quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5"
```

**Step 2 — Restart the service:**
⚠️ UNTESTED — compose path from KB doc `services/whisper-webui.md` (verified 2026-07-13)
```bash
ssh root@containers-gpu.x86experts.com "cd /AIStuff/Whisper-WebUI/backend && docker compose down -v && docker compose up -d"
```

**Step 3 — Wait for the service to become healthy:**
⚠️ UNTESTED — synthesized healthcheck sequence
```bash
sleep 10 && ssh root@containers-gpu.x86experts.com "docker compose -f /AIStuff/Whisper-WebUI/backend/docker-compose.yaml ps --services --filter 'status=running'"
```

**CONTEXT:**
- SSH to containers-gpu verified working in pre-plan checks
- Compose file at `/AIStuff/Whisper-WebUI/backend/docker-compose.yaml`
- Service name: `app`
- Port mapping: 8001:8000
- The `-v` flag on `down` is intentional — it clears the anonymous volume that previously shadowed `backend/main.py` (per KB §4b)
- The compose file references `HF_TOKEN=${HF_TOKEN:-}` which will use the env var from the SSH session's environment or default to empty

**CONSTRAINTS:**
- Use `docker compose down -v` to clear stale anonymous volumes
- Wait at least 10 seconds after `up -d` before healthcheck

**DON'T:**
- Don't modify the compose file
- Don't purge volumes that hold models (`/AIStuff/Whisper-WebUI/models` and `outputs`) — these are bind mounts and survive `-v`

**VERIFICATION:**
⚠️ UNTESTED — synthesized; SSH connectivity ✅ TESTED, compose path from KB
```bash
# Check container is running
ssh root@containers-gpu.x86experts.com "docker compose -f /AIStuff/Whisper-WebUI/backend/docker-compose.yaml ps"

# Check the service is responding
ssh root@containers-gpu.x86experts.com "curl -s -o /dev/null -w '%{http_code}' http://localhost:8001/docs"
# Expected: 200
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 5 entry to Execution Log section
  - Update Remaining Tasks checklist from TASK_QUEUE.md
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
```

---

### TASK 6: Functional test against live endpoint

**INTENT:** Verify all three bugs are fixed by running curl commands against the deployed container on containers-gpu. Tests both happy path and error path per software addendum §S5 and infrastructure §A11.

**STRUCTURE:**

Use a small known audio file for testing (e.g., a 10-second sample). Create one if none is available:

📖 FROM-DOCS — ffmpeg lavfi virtual input (ffmpeg.org/ffmpeg-filters.html#sine)
```bash
# Generate a 10-second sine wave test file if no test audio exists
ffmpeg -y -f lavfi -i "sine=frequency=440:duration=10" -ar 22050 -ac 1 /tmp/test_audio.wav 2>/dev/null
TEST_AUDIO=/tmp/test_audio.wav
```

**Test 1 — Bug #2 fix: `/transcription/?lang=en` (was KeyError):**
⚠️ UNTESTED — endpoint pattern verified in `whisper_bug_report.md`; test file is synthetic
```bash
TASK_ID=$(curl -s -X POST "http://containers-gpu.x86experts.com:8001/transcription/?model_size=tiny&lang=en" \
  -F "file=@${TEST_AUDIO}" | python3 -c "import sys,json;print(json.load(sys.stdin)['identifier'])")
echo "Task ID: $TASK_ID"
sleep 30
curl -s "http://containers-gpu.x86experts.com:8001/task/${TASK_ID}" | python3 -m json.tool
# Expected: status "completed"
```

**Test 2 — Bug #1 fix: `/swear-removal/` (was NameError):**
⚠️ UNTESTED — endpoint pattern verified in `whisper_bug_report.md`; test file is synthetic
```bash
TASK_ID=$(curl -s -X POST "http://containers-gpu.x86experts.com:8001/swear-removal/" \
  -F "file=@${TEST_AUDIO}" \
  -F "output_format=MATCH" \
  -F "channels=1" \
  -F "sample_rate=22050" | python3 -c "import sys,json;print(json.load(sys.stdin)['identifier'])")
echo "Task ID: $TASK_ID"
sleep 30
curl -s "http://containers-gpu.x86experts.com:8001/task/${TASK_ID}" | python3 -m json.tool
# Expected: status "completed" or "in_progress" with progress > 0 (transcription of sine wave yields no swear words, but the endpoint should not crash)
```

**Test 3 — Bug #3 fix: error path propagation:**
⚠️ UNTESTED — error-path test; uses a text file with `.mp3` extension to trigger a processing error
```bash
# Create a deliberately invalid "audio" file (text with .mp3 extension)
echo "not audio" > /tmp/invalid.mp3

TASK_ID=$(curl -s -X POST "http://containers-gpu.x86experts.com:8001/transcription/?model_size=tiny&lang=en" \
  -F "file=@/tmp/invalid.mp3" 2>&1 | python3 -c "import sys,json;print(json.load(sys.stdin)['identifier'])" 2>/dev/null || echo "null")
if [ "$TASK_ID" != "null" ]; then
  sleep 15
  STATUS=$(curl -s "http://containers-gpu.x86experts.com:8001/task/${TASK_ID}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('status','unknown'))")
  echo "Status after invalid file: $STATUS"
  # Expected: "failed" — the try/except should catch the error and persist FAILED
fi
rm -f /tmp/invalid.mp3
```

**CONTEXT:**
- All tests hit `containers-gpu.x86experts.com:8001` (formerly port 8001 mapped to container 8000)
- The test audio is a 10-second 440Hz sine wave — trivial to transcribe, no profanity expected
- Bug #1 fix should make `/swear-removal/` return completed even without finding swear words
- Bug #2 fix should make `/transcription/?lang=en` complete successfully
- Bug #3 fix should make `/task/{id}` report "failed" instead of infinite "in_progress"

**CONSTRAINTS:**
- Use `model_size=tiny` for fast transcription (seconds, not minutes)
- Set `sleep` durations conservatively — the RTX 5060 Ti on containers-gpu should transcribe tiny model in <10s for a 10s file
- If a test fails, log the exact curl response and error before proceeding to the next test

**DON'T:**
- Don't use real audiobook files — keep tests quick with synthetic audio
- Don't skip error path testing (Test 3) — it verifies Bug #3
- Don't modify the compose file or server config

**VERIFICATION:**
Copy the full curl output for each test into the devlog. The commands must be complete (no `...` in URLs or payloads). Tabulate the results:

```
| Test | Bug | Endpoint | Expected | Actual | PASS/FAIL |
|------|-----|----------|----------|--------|-----------|
| 1 | #2 | /transcription/?lang=en | completed | <actual> | |
| 2 | #1 | /swear-removal/ | completed | <actual> | |
| 3 | #3 | /transcription/ + invalid file | failed | <actual> | |
```

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 6 entry to Execution Log section
  - Record all 3 test results in the matrix table
  - Replace Remaining Tasks with Result / Conclusion / Next Steps
  - Update SESSION_BRIEF.md and HANDOFF.md per EXECUTION_PROTOCOL.md Section 4
```

---

### TASK 7: Writeback — KB update, execution protocol, deviation propagation

**INTENT:** Persist the completed state of this plan into the Knowledge Base, execution protocol artifacts, and deviation log so a fresh agent can reconstruct the deployed state without re-reading the full plan.

**STRUCTURE:**

**Step 1 — Update KB doc** (`~/git_projects/scratch_pad/knowledge/services/whisper-webui.md`):
- Bump `updated:` to `2026-07-23`
- Advance `confidence:` to `verified` (the 3 bugs were confirmed and fixed, container rebuilt and deployed)
- Add a note in the summary field: "2026-07-23: Fixed 3 backend bugs — NameError in swear_removal router, KeyError in language dict inversion, missing try/except in transcription background task. Container rebuilt and pushed as quay.io/sovens/transcription/whisper-webui-backend:swear0.3.5."

**Step 2 — Execution protocol writeback:**
- Update `agent_planning/execution/whisper_webui_bugfix/TASK_QUEUE.md` — all 7 tasks marked `done`
- Rewrite `SESSION_BRIEF.md` — current state: all tasks complete, container deployed on containers-gpu
- Rewrite `HANDOFF.md` — notes: 3 bugs fixed, container rebuilt and deployed, functional tests passed. Any deviations from plan documented below.

**Step 3 — Deviation propagation:**
- If any task deviated from the plan during execution, write an Adaptation Notes table to the devlog's Result section:
  ```
  | Plan said | Actually did | Why | Class tag |
  |-----------|--------------|-----|-----------|
  ```
- Classify each deviation: `CMD-SYNTAX`, `API-DRIFT`, `QUERY-LANG`, `INFRA-FACT`, `SCOPE-GAP` (per EXECUTION_PROTOCOL.md §8)
- If no deviations occurred, note "No deviations — executed per plan."

**CONSTRAINTS:**
- KB doc must be written to the exact path `~/git_projects/scratch_pad/knowledge/services/whisper-webui.md`
- Do not create new KB docs — update only the existing one
- Do not modify any source code in this task

**DON'T:**
- Don't skip Step 1 — KB staleness is a known failure mode
- Don't batch Step 2 writebacks — SESSION_BRIEF.md and HANDOFF.md must be rewritten fresh, not appended

**VERIFICATION:**
```bash
# Verify KB doc was updated
grep '2026-07-23' ~/git_projects/scratch_pad/knowledge/services/whisper-webui.md

# Verify execution protocol artifacts exist and reference completed state
ls -la agent_planning/execution/whisper_webui_bugfix/TASK_QUEUE.md \
       agent_planning/execution/whisper_webui_bugfix/SESSION_BRIEF.md \
       agent_planning/execution/whisper_webui_bugfix/HANDOFF.md

# Verify TASK_QUEUE.md has all tasks as done
grep -c '| done ' agent_planning/execution/whisper_webui_bugfix/TASK_QUEUE.md
```

Copy the exact command output into the devlog. Do NOT paraphrase or abbreviate with `...`.

```
DEVLOG: Update agent_planning/execution/whisper_webui_bugfix/devlogs/whisper_webui_bugfix_2026-07-23.md
  - Add Task 7 entry to Execution Log section
  - Under Issues Encountered: document any quay.io auth steps, deployment quirks, or test failures
  - Under Files Modified: list KB doc written + execution protocol artifacts
  - Finalize: Result / Conclusion / Next Steps (all tasks complete)
```
