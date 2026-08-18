---
name: technical-writing
description: Controlled technical writing style for prose output, in two modes - machine-to-human (documentation, READMEs, guides, explanations, commit messages, PR descriptions, tickets, chat responses of any length) and machine-to-machine (prompts, skill files, agent instructions, structured specs, schema descriptions). USE FOR writing or editing any document, comment block, release note, or instruction text. USE FOR reviewing prose for clarity. DO NOT USE FOR choosing identifier names or code comment policy - see code-quality.
globs: **/*.md,**/*.mdx,**/*.rst,**/*.txt
alwaysApply: false
---

# Technical writing

Two modes. Pick by audience. When output is read by both, apply machine-to-human.

---

## Mode A: machine to human

Audience: a person reading documentation, an explanation, or a change
description. Write in a controlled technical style.

### Principles

- Prioritise clarity over elegance.
- Use simple, common English.
- Prefer short sentences of 10 to 20 words.
- Express one idea per sentence.
- Use active voice unless passive voice is clearer.
- Use the same term for the same concept throughout the document. Choose the term
  once and do not vary it.
- Avoid unnecessary adjectives and adverbs.
- Avoid marketing, conversational, or emotional language.
- Use concrete, measurable statements instead of vague language. Replace "fast"
  with a number. Replace "several" with a count.
- Use modal verbs consistently:
  - `must` for a requirement.
  - `should` for a recommendation.
  - `may` for an optional action.
  - `can` for a capability.

### Instructions and procedures

- Present actions in execution order.
- One action per numbered step.
- State a condition before the action that depends on it. Write "If the build
  fails, run X", not "Run X if the build fails".
- Describe the expected result when the reader cannot otherwise confirm success.
- Use numbered lists for procedures. Use bullet lists for unordered information.

### Language prohibitions

Do not:

- Use synonyms for an established technical term.
- Use filler words such as "basically", "simply", "just", or "of course".
- Use idioms, metaphors, or colloquialisms.
- Assume prior knowledge without explanation or a link.
- Use a pronoun when its reference could be ambiguous. Repeat the noun instead.

### Verification before responding

Confirm all three:

1. Terminology is consistent throughout.
2. Every instruction is unambiguous.
3. Each sentence communicates one primary idea.

---

## Mode B: machine to machine

Audience: another model or a parser. Write as if the reader is a non-native
English speaker with no context.

Rules:

- Be precise.
- Be unambiguous.
- Be concise.
- Prefer common words.
- Keep sentences short.
- One idea per sentence.
- Use active voice.
- Keep terminology consistent.
- Do not use idioms, metaphors, or marketing language.
- State facts, not opinions.
- Give instructions in execution order.
- Use `must`, `should`, `may`, and `can` consistently, as defined in Mode A.
- Replace a vague word with a measurable value whenever a value exists.
- State the trigger condition before the instruction it governs.
- Prefer an explicit prohibition over an implied one. Write "do not X" rather than
  describing only the correct path.

If a sentence can be made shorter without losing meaning, shorten it.

### Additional rules for instruction text

- Front-load the condition that decides whether the reader acts at all.
- Give a positive rule and its matching prohibition together where both matter.
- Do not rely on emphasis to carry meaning. If a rule is mandatory, write `must`.
