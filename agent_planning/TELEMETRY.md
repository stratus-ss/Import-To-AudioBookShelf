# Framework Telemetry Schema

This document defines the JSONL telemetry emitted by `agent_planning/scripts/`
during plan execution. The file is local to the agent's working environment;
no network call is made and no secrets are recorded.

**Sink:** `agent_planning/execution/_telemetry.jsonl` (gitignored).

## Schema fields

A telemetry line is one JSON object per invocation. Each hook emits exactly
one line.

| Field | Type | Description |
|-------|------|-------------|
| `ts` | ISO-8601 string | Wall-clock time of the event |
| `hook` | string | One of `plan_review`, `init_execution_dir` |
| `project` | string | `agent_planning/execution/<project_name>` slug |
| `tier` | int | Plan tier (1, 2, or 3) when known, else `null` |
| `addendum` | string | Comma-separated addendum names (`software`, `code-quality`, `infrastructure`, `automation`, `creative`, `pipeline`) when known, else `null` |
| `model` | string | Reviewer model id, when the hook ran a reviewer |
| `protocol_lines_read` | int | Approx. lines of PLAN_CORE / addendum text read by the hook (heuristic; `null` when not measured) |
| `state_writes` | int | Number of state files written by this invocation (e.g. STATE.md, TASK_QUEUE.md) |
| `tool_calls` | int | Approx. count of tool / shell invocations the hook performed |
| `round_trips` | int | Number of operator round-trips the hook performed (questions printed, model-switch pauses, etc.) |
| `findings` | int | Number of reviewer findings, when `hook == plan_review` |
| `defects` | int | Number of `status: FAIL` reviewer findings, when `hook == plan_review` |
| `deviations` | int | Number of recorded deviations (init_execution_dir captures the `--skip-plan-lint` count) |
| `rework` | int | `1` when the hook performed re-work (e.g. retry on stale session), else `0` |
| `recovery_success` | bool | `true` when bootstrap or review produced a recoverable STATE.md / review.json, `false` otherwise |
| `plan_bytes` | int | Plan file size in bytes (review cost context) |
| `raw_bytes` | int | Reviewer raw stdout/stderr size in bytes (the dominant review output cost) |
| `elapsed_s` | int | Wall-clock seconds consumed by the review invocation |
| `pass` | int | Review pass number — always `1` under the single-pass policy |
| `approved` | bool | `true` when the operator approval gate passed (a refused run emits no line) |
| `counterfactual` | string | Free-text closeout question the operator answers at closeout, e.g. "would removing the model-switch pause have saved a round-trip?" |

Unknown or unset fields are emitted as `null`. Fields are added over time;
older consumers should ignore unknown keys.

## Hook: `plan_review`

Appended once per completed `agent_planning/scripts/plan_review.sh <plan>`
invocation (after the JSON findings object is written). Plan review is
**optional and operator-run** — R7 (the former pre-execution review gate) was
retired 2026-10-04. The wrapper refuses to run unattended (no interactive
terminal) unless `PLAN_REVIEW_AUTORUN=1` is set, and hard-refuses a second
review of the same plan. The hook records findings, defects, the reviewer
model, and cost telemetry (`plan_bytes`, `raw_bytes`, `elapsed_s`, `pass`,
`approved`). A refused run emits no line — nothing was spent.

## Hook: `init_execution_dir`

Appended once per `agent_planning/scripts/init_execution_dir.sh` invocation
(after STATE.md is written or the directory is migrated). The hook records the
`--skip-plan-lint` deviation count plus a `recovery_success` flag. It does not
record an R7 outcome — R7 (re-instated 2026-10-25) is the agent-side
plan-validator subagent dispatch (PLAN_CORE.md §8.7), not a bootstrap script
event.

## Closeout counterfactual question

At the closeout of every plan, the executor records a one-line answer to the
counterfactual prompt:

> "Without the framework changes in this plan, what would the plan-execution
> session have looked like — same shape with more round-trips, or a different
> shape entirely?"

The answer is appended as the `counterfactual` field of the closing telemetry
line (or as a free-text devlog entry linked from the closing line).

## Operational notes

- The file is appended by the framework scripts at the close of each hook.
- The file MUST NOT contain plan-task secrets, API tokens, or pasted
  credentials; hooks are expected to redact or omit such material before
  writing.
- A `.gitignore` entry (`agent_planning/execution/_telemetry.jsonl`) is
  created in the framework tree at the same task that adds the file; the
  entry excludes the file from version control.
