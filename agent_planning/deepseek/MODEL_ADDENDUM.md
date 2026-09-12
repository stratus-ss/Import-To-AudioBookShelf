# Model Addendum — DeepSeek V4 Pro

This addendum contains V4 Pro-specific prompting conventions, failure mode defenses, and context management guidance. Read it after `PLAN_CORE.md` and the domain addendum when executing plans with DeepSeek V4 Pro.

---

## D1. V4 Pro Context Window and Granularity

**Context window:** V4 Pro has a 1,000,000-token context window with up to 384,000 output tokens.

**Granularity relaxation:** The PLAN_CORE.md ~50 line target may be relaxed to **~100 lines** for V4 Pro. Tasks over 150 LOC increase the risk of silent incompletion.

**Plan size limit:** Break large plans (>12 tasks) into two sequential plans with explicit non-regression constraints.

**Token budget guidance:**
- Keep plan introductions concise. Front-load role and task before any large context block.
- Plans should stay under ~500K total tokens (plan + code read + expected output).
- For Think Max tasks: size `max_tokens` to at least 8x the expected output length to accommodate the reasoning trace.

**Cache-friendly layout:**
- Put the stable system prompt, schemas, and few-shot examples at the very front of the system message; keep them bit-identical across calls.
- Never interpolate timestamps, request IDs, or per-user names into the stable prefix — this breaks context caching.
- Monitor `prompt_cache_hit_tokens` and `prompt_cache_miss_tokens` in the `usage` response field.

**Phased execution:**
- Window 1: Framework setup (scaffolding, config, test harness)
- Window 2: Iterate through implementation tasks

---

## D2. V4 Pro Prompting: Six-Part Anatomy

Every effective V4 Pro prompt has these six parts. Skip any and quality degrades:

1. **Role** — who the model acts as ("senior Go engineer", "database administrator with 15 years of Postgres experience")
2. **Task** — one verb-led instruction. Not three, not five.
3. **Context** — the code, data, or background needed
4. **Constraints** — length, banned patterns, must-include items
5. **Output format** — JSON schema, markdown table, function signature
6. **Examples** — one or two Wrong/Right pairs for non-obvious formats

**Early tokens are weighted more heavily than later tokens.** Role and task must appear before the context block. This is why **INTENT** and **STRUCTURE** labels come before **CONTEXT** in the canonical task format (Section 2).

For long context (>500 tokens), add a one-line restatement of the task after the context block. Without this restatement, the instruction is buried and V4 Pro will weight the context content over the directive.

---

## D3. V4 Pro Task Format: Bold-Label Sections

DeepSeek V4 Pro parses bold-label sections reliably. Plan task sections use a markdown `### Task N: Title` heading with bold labels underneath (`**INTENT:**`, `**STRUCTURE:**`, `**CONTEXT:**`, etc.), inside the TASKS section. The deterministic gate (`agent_planning/scripts/plan_lint.sh` `--require-full-tasks`) is the authoritative parser for this framework; bold labels match what the gate enforces and are required for a plan to pass lint.

```markdown
### Task 1: Add Config Parser

<reasoning="think-high" temperature="0.0">   <!-- per-task annotation; optional
                                                 wrapper above remains allowed
                                                 as documentation only -->

**INTENT:** Create a YAML config parser that validates required keys...

**STRUCTURE:**
  File: src/config/parser.go
  Function: func ParseConfig(path string) (*Config, error)

**CONTEXT:** Follow the pattern in src/config/loader.go

**CONSTRAINTS:**
  - Do not add new imports beyond "gopkg.in/yaml.v3"
  - Config struct is already defined in src/config/types.go — do not redefine it

**VERIFICATION:**
  go test ./src/config/...
  PASS: all tests pass
```

**Notes:**
- The plan's top-level outline (OBJECTIVE, PROJECT CONTEXT, KEY FILES, TASKS) still uses markdown headers for human readability. Bold labels apply only to individual task content.
- XML elements are documentation only. The deterministic gate is the parser of record; the bold-label form is what it requires.
- `reasoning` / `temperature` remain documentable per-task intent — either as an inline annotation line (`<reasoning="..." temperature="...">`) above the bold labels, or as a single-line markdown note. Temperature has no effect in thinking mode (see §D5); document intent, not the agent's actual sampling setting.
- For plans authored under the older XML-element grammar (this addendum's rev-1 form), re-render task bodies into bold labels before submitting for execution.

---

## D4. V4 Pro Hallucination Guardrails

V4 Pro has a **94% non-abstention rate** when uncertain (Artificial Analysis) — when it does not know an answer, it provides a confident-sounding response 94% of the time rather than admitting uncertainty. Plans must compensate:

- Every task's VERIFICATION section must produce machine-checkable output. Subjective "looks fine" gates will be reported as passed.
- When referencing specific values from source code (field names, counts, enum values), instruct V4 Pro to read the source file and use the value it finds — do NOT hardcode values without marking them "(exact — do not deviate)".
- When the correct answer may be unknown at runtime: `"If you cannot determine X from the provided context, output 'unknown' rather than guessing."`

**Negative examples over bare "don't":**

V4 Pro responds more reliably to concrete counterexamples:

```
WRONG: if err != nil { log.Fatal(err) }
RIGHT: if err != nil { return fmt.Errorf("processAudio: %w", err) }
```

For each DON'T item that matters, provide a Wrong/Right pair.

---

## D5. Temperature Settings

| Use case | Temperature | Notes |
|----------|-------------|-------|
| Code generation, mathematics | `0.0` | Lowest randomness; near-deterministic in non-thinking mode |
| Data analysis, cleaning | `1.0` | DeepSeek's recommended default |
| General conversation, translation | `1.3` | Balanced output |
| Creative writing | `1.5` | More variation; expect reruns |

**Critical:** temperature, `top_p`, `presence_penalty`, and `frequency_penalty` have no effect in thinking mode.

**Task-level vs agent-level temperature:** The temperature in a `<task>` element documents intent for the task. Configure the agent's chat temperature separately.

---

## D6. Reasoning Mode Selection

- **Non-think:** Use for formatting, classification, translation, and structured extraction. Pass `extra_body={"thinking": {"type": "disabled"}}`.
- **Think High:** Use for most coding and planning tasks. Default in the V4 API. Pair with `reasoning_effort="high"`.
- **Think Max:** Reserve for hard debugging, complex algorithm design, and formal proofs. Set `reasoning_effort="max"` and ensure the total request context window (input + reasoning trace + output) is >= 384K tokens.

**`reasoning_content` passback rules (official API):**
- Non-tool-call turns: `reasoning_content` is ignored if passed — omit it for cost savings.
- Tool-call sub-turns: You **must** pass the full assistant message including `reasoning_content` or the API returns 400.

---

## D7. Tool Calling Caveats

V4 Pro emits tool calls correctly only ~79% of the time. 11% of calls appear as plain text in `content` instead of the `tool_calls` field.

V4 Pro uses **DSML** (DeepSeek Markup Language) internally for tool invocations. When using the OpenAI-compatible API surface, tool calls are translated automatically — but the 11% plain-text leakage means the raw DSML format may occasionally surface in `content`.

**Plans that require tool use MUST:**
- Specify single-tool-call-per-turn in the system prompt
- Instruct the model to never invent tool results
- Include a parser that checks both `tool_calls` and `content` for DSML-formatted invocations

**Strict tool-call mode:** Use `base_url="https://api.deepseek.com/beta"` with `"strict": true` on tool function definitions.

---

## D8. API Model Selection

- **Model ID:** `deepseek-v4-pro`
- **Legacy models:** `deepseek-chat` and `deepseek-reasoner` are deprecated, sunset **2026-07-24 15:59 UTC**
- **Default thinking mode:** Enabled with `reasoning_effort="high"`. Explicit `extra_body={"thinking": {"type": "disabled"}}` is required for non-think tasks.
- **Agent client overrides:** Some agent clients (e.g., Cursor, OpenCode) may auto-set `reasoning_effort="max"`.

---

## D9. Output Anchors

End prompts with the first tokens of the expected output to reduce preamble drift:

- "Begin your reply with the line: `## Summary`"
- "Output only the modified function. Start with `func `."
- "Return only valid JSON. Start your response with `{`."

---

## D10. JSON Mode Rules

JSON mode (`response_format={"type": "json_object"}`) is designed to return valid JSON, not guaranteed:
1. Include the literal word "json" in the system or user message.
2. Show a small example schema inline.
3. Set `max_tokens` high enough that the JSON cannot be truncated mid-string.

Always wrap JSON parsing in a retry with try/except.

---

## D11. V4 Pro Quick Reference Checklist (extends domain and core checklists)

- [ ] Plan tasks use a `### Task N: Title` heading with bold labels (**INTENT**, **STRUCTURE**, **CONTEXT**, **CONSTRAINTS**, **VERIFICATION**, plus **DON'T** and any other applicable labels from the §2 label set)
- [ ] Role and task appear before the context block in each task
- [ ] Long context (>500 tokens) has task restatement after the context block
- [ ] Verification sections produce machine-checkable output (not subjective "looks fine")
- [ ] Field names and counts from source code are not hardcoded without "(exact)" or "(approximate)" marks
- [ ] DON'T items have Wrong/Right pairs (not bare prohibitions)
- [ ] Plans requiring tool use: single-tool-call-per-turn, never invent tool results
- [ ] API usage: `deepseek-v4-pro` model ID used (not deprecated `deepseek-chat`)
- [ ] Think Max tasks: total request context window >= 384K tokens
- [ ] Sensitive uncertainty cases: CONSTRAINTS include "output 'unknown' if uncertain"
