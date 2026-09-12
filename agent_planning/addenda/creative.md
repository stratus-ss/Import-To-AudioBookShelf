# Plan Addendum — Creative & Content Writing

_Last updated: 2026-07-28_

Applies to: blog posts, technical articles, product documentation narratives, editorial rewrites, release notes, README prose, presentation scripts, meeting/sprint notes, long-form written content.

Read this after `PLAN_CORE.md`. This addendum **reduces ceremony** — skip sections of PLAN_CORE that are marked as optional or infrastructure-specific when working on content.

---

## CR1. Reduced Ceremony

Content writing work does not require:
- Decision Records (DRs)
- ACCESS & CREDENTIAL PREREQUISITES
- HANDOFF.md / SESSION_BRIEF.md (for single-session work)
- Production image verification
- Per-task devlog steps (devlog is OPTIONAL for single-session content work)

**Devlog IS required when:**
- The plan spans multiple sessions
- The plan modifies a shared reference document that future plans depend on (e.g., a style guide, a shared glossary, a canonical README that other docs link to)
- The plan includes an automated processing step (e.g., LLM rewrite pass, batch export)

---

## CR2. Simplified Interview (4 Questions)

For content plans, the 7-category interview reduces to 4 questions:

1. **Scope:** What content is being created or modified? What is explicitly out of scope?
2. **Acceptance criteria:** What does "done" look like? (word count, section list, format, tone)
3. **Output path:** Where does the output go? What is the exact filename?
4. **Style/voice constraints:** What must be preserved? (brand voice, terminology, reading level, audience, formatting conventions)

After these 4 answers, produce the Restatement Gate (PLAN_CORE §0). Plan authoring is blocked until confirmed.

---

## CR3. Style and Voice Preservation

When a plan edits existing content:

- **CONTEXT section MUST list preserved elements explicitly:**
  - Audience and reading level (e.g., "engineer audience, assumes Linux familiarity")
  - Tone and voice (formal/informal, first/third person, active/passive)
  - Terminology and naming conventions (product names, acronym usage, capitalization rules)
  - Structural conventions (section order, heading style, callout/admonition format)
  - Series continuity items (recurring concepts, prior sections already written, established facts)

- **DON'T section MUST include:**
  - "Do not change established product names, acronyms, or defined terms"
  - "Do not alter the tone from [X] — the audience expects [Y]"
  - "Do not change the structural convention: [describe it]"

---

## CR4. Output Format Specification

The STRUCTURE section for any content task MUST specify:

- **Output file path** (exact, not "somewhere appropriate")
- **Format** (markdown, plain text, HTML, reStructuredText, etc.)
- **Length target** (word count, section count, or "match source length ±10%")
- **Section structure** (if the output has multiple parts: H2 headings, numbered sections, etc.)

Example:
```
OUTPUT:
  File: docs/guides/getting-started.md
  Format: markdown
  Structure: H2 sections: Prerequisites, Installation, Configuration, Verification
  Length: 600-800 words
  Audience: first-time users, no prior product knowledge assumed
```

---

## CR5. Iterative Rewrite Rules

When a plan rewrites or edits existing content (not creating from scratch):

1. **Pre-extraction:** Before rewriting, extract a content inventory from the source:
   - Key claims or facts that must be preserved
   - Defined terms and their definitions
   - Structural elements (headings, numbered steps, callout blocks)
   - Links and cross-references that must remain valid

2. **Section-level granularity:** One task per major section (for long-form content) or one task per document (for shorter content). Do not rewrite the full document in a single task.

3. **Non-regression:** The rewrite MUST preserve all items from the pre-extraction inventory. Add a DON'T entry for each one.

4. **Review before finalizing:** After all rewrite tasks complete, include a final review task:
   - Read the rewritten sections against the inventory
   - Confirm no key claims, defined terms, or cross-references were lost
   - Confirm formatting conventions are consistent

---

## CR6. Content Checklist (replaces most of PLAN_CORE §12)

For single-session content plans, verify:

- [ ] Simplified 4-question interview completed (scope, acceptance criteria, output path, style constraints)
- [ ] Restatement gate confirmed
- [ ] Output file path is explicit (not "appropriate location")
- [ ] Output format is specified (markdown, plain text, etc.)
- [ ] Length target or section structure is defined
- [ ] Audience and tone are stated in CONTEXT
- [ ] DON'T section lists specific terminology and tone preservation constraints
- [ ] For rewrites: content inventory extracted before first rewrite task

For multi-session content plans, also add:
- [ ] Devlog location specified
- [ ] SESSION_BRIEF.md and HANDOFF.md used (from EXECUTION_PROTOCOL §7)
- [ ] Final review task included after all rewrite tasks
