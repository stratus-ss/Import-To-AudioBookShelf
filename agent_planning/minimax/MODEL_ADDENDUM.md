# Model Addendum — MiniMax M3

This addendum contains M3-specific prompting conventions, failure mode defenses, and context management guidance. Read it after `PLAN_CORE.md` and the domain addendum when executing plans with MiniMax M3.

---

## M1. M3 Context Window and Granularity

**Context window:** M3 has a 1,000,000 token context window (512K guaranteed minimum) via MiniMax Sparse Attention (MSA). Standard billing applies up to 512K tokens; long-context billing (higher rate) applies above 512K on pay-as-you-go.

**Granularity relaxation:** The PLAN_CORE.md ~50 line target may be relaxed to **~100 lines** for well-scoped tasks where structure and context are fully specified. The limit still applies to tasks involving complex cross-file logic, new abstractions, or schema changes — those remain single-focused at ~50 lines.

**Plan size limit:** The ">8 tasks → split into two plans" rule is relaxed to ">15 tasks" for M3.

**Phased splitting:** Phased window approach is NO LONGER REQUIRED for plans ≤15 tasks. M3 can hold the full plan, codebase, and skill docs in one session without goal drift. For very large plans (>15 tasks, or plans referencing >300K tokens of repo context), still consider splitting — not for context capacity, but to keep per-session cost predictable.

**Total session token guidance:** Plans are sized for M3's 1M window; phased splitting is only required if total session tokens would exceed ~800K.

---

## M2. M3 Failure Modes (Plan Authors Must Defend Against All Five)

The following are confirmed for MiniMax M3 (documented post-release, June 2026). Plan tasks must explicitly defend against them.

| # | Failure Mode | Symptom | Plan Defense |
|---|-------------|---------|-------------|
| M3-1 | Parallel tool call misattribution | Silent result swap across parallel calls | Sequence tool calls; never parallelize dependent operations |
| M3-2 | Reasoning spiral (inference collapse) | Infinite self-revision loop, never converges | Explicit convergence stop rule per task; restatement gate as checkpoint |
| M3-3 | High latency | 8+ min TTFT on complex tasks, agent timeouts | Set loop timeouts to 15+ min for Tier 2/3; document expected latency |
| M3-4 | Tool call payload corruption | Silently dropped args, no-op tool calls | Machine-verifiable verification step on every tool-executed step |
| M3-5 | Interleaved thinking state loss | Performance degrades across turns if thinking stripped | Preserve full `response_message` in API history; `reasoning_split=True` |

---

## M3. Detailed Failure Mode Plan Defenses

### M3-1: Parallel Tool Call Misattribution

M3 swaps results across parallel tool calls by positional/arrival order rather than `tool_call_id`. The failure is silent — M3 produces internally consistent but factually wrong output.

**Plan defense:** Never design tasks requiring M3 to dispatch parallel tool calls and reason about their combined results. Sequence dependent operations explicitly (Step 1, Step 2...).

Add to CONSTRAINTS: `"Do not parallelize tool calls — process each target sequentially."`

### M3-2: Reasoning Spiral (Inference Collapse)

M3 can enter an infinite self-revision loop: it recognizes a solution as suboptimal, revises it, finds a different flaw in the revision, revises again, and repeats without converging. It will NOT self-report being stuck.

**Plan defense:** Every multi-step task needs an explicit convergence checkpoint:

```
STOP RULES:
- Stop after the first working solution. Do not optimize further. Surface what you produced.
- If you have revised the same section 3 times without convergence, stop and report.
```

For Tier 2/3 discovery, the restatement gate is the convergence checkpoint — M3 produces the Discovery Summary and stops.

### M3-3: High Latency / Timeout Sensitivity

Time-to-first-token can reach 8+ minutes for complex tasks. Agent loops with short timeouts cancel M3 mid-reasoning with no output.

**Plan defense:** Do not specify short timeouts for complex reasoning tasks. Set agent loop timeouts to 15+ minutes for Tier 2/3 tasks. Document expected latency in the plan when tasks involve complex multi-file reasoning.

### M3-4: Tool Call Payload Corruption

Approximately 1 in 3 tool calls may fail in some environments with malformed hash prefixes, dropped arguments, or silent no-ops where M3 acts as if a tool succeeded when it did not.

**Plan defense:** Verification steps are NOT optional. Every tool-executed step MUST have a machine-verifiable outcome (file exists, service responds, row count matches).

Add to every VERIFICATION section: `"Verify the output of this step before proceeding — do not assume tool success from exit code alone."`

### M3-5: Interleaved Thinking State Loss

M3's chain-of-thought must be preserved in conversation history across turns (`reasoning_split=True`, full `response_message` appended). If the calling agent strips thinking content, M3 loses reasoning context and performance degrades on subsequent turns.

**Plan defense:** When using M3 via API in a multi-turn agent loop, ensure `reasoning_split=True` and the full `response_message` (including thinking content) is preserved in history. Do NOT strip thinking tokens from conversation context. Cursor-based execution handles this automatically; external orchestration must account for it explicitly.

---

## M4. M3 Prompting Best Practices

### Explicit DON'T sections remain MANDATORY

M3 is better at following constraints than older models, but user reports show it still skips files it "didn't bother to look into" and produces confident-but-wrong analysis when scope is open-ended.

### Inline constraint restating

For standard file/code operations, a single CONSTRAINTS section is usually sufficient. For complex skill-constrained tools, still restate inline.

### Creative drift

M3's creative generalization is its strength and its failure mode. It is good at inferring what "should" exist and producing it — which means it will add abstractions, refactor patterns, and extend scope whenever the boundary is implicit rather than explicit. Stop rules make the boundary explicit.

M3 also handles long sessions well, but user reports confirm detail-skipping can emerge after heavy use (~10+ hours). Explicit stop rules reduce the attention budget M3 spends on out-of-scope work.

**The core thesis stands:** M3 works best with strict, detailed plans. It is not a model for open-ended exploration.

---

## M5. M3 Session Management

Signs to end a session and start fresh:
- Accumulated tool output exceeds ~150K tokens
- The agent begins re-reading files it already processed
- A task fails in an unexpected way that requires re-evaluating prior decisions
- More than one blocked task in a row

---

## M6. Multimodal Context (M3 Only)

M3 natively accepts image and video inputs. Plans may reference visual artifacts as context where it reduces ambiguity:

- **UI/design references:** Include the image path in the CONTEXT section. M3 will read the image directly.
- **Schema diagrams:** ER diagrams or architecture diagrams can be passed as context.
- **Format:** Reference image paths in CONTEXT as:
  `[IMAGE: ./docs/design/target_layout.png -- reference for component structure in Task 3]`
- **Constraint:** Image context does not replace explicit STRUCTURE and SCHEMA sections — still enumerate all field names, types, and file paths in text.

---

## M7. M3 Quick Reference Checklist (extends domain and core checklists)

- [ ] No tasks require M3 to parallelize dependent tool calls (M3-1 defense)
- [ ] Multi-step tasks have explicit convergence stop rule: "stop after first working solution" (M3-2 defense)
- [ ] Tier 2/3 tasks document expected latency if >5 minutes; agent loop timeout set to 15+ min (M3-3 defense)
- [ ] Every tool-executed step has machine-verifiable outcome (file exists, service responds) — not just exit code 0 (M3-4 defense)
- [ ] If using M3 via external API: `reasoning_split=True` and full `response_message` preserved in history (M3-5 defense)
- [ ] Context window: phased splitting only required if total session tokens > ~800K
- [ ] Batch-task safety: no single task generates >200 lines of output
