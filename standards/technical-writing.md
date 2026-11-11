---
name: technical-writing
description: Controlled technical writing style for prose output, in two modes - machine-to-human (documentation, READMEs, guides, explanations, commit messages, PR descriptions, tickets, chat responses of any length) and machine-to-machine (prompts, skill files, agent instructions, structured specs, schema descriptions) - including how to write for a human reader without machine-sounding prose. USE FOR writing or editing any document, comment block, release note, or instruction text. USE FOR writing anything a human is expected to read, including a reply or report. USE FOR reviewing prose for clarity or removing AI-sounding phrasing. DO NOT USE FOR choosing identifier names or code comment policy - see code-quality.
globs: **/*.md,**/*.mdx,**/*.rst,**/*.txt
stack: any
---

# Technical writing

## Rules for all prose

- Prioritise clarity over elegance.
- One idea per sentence. Prefer 10 to 20 words.
- Use simple, common English and active voice, unless passive is clearer.
- Use one term per concept, chosen once and never varied.
- Replace vague words with measurable values. Not "fast", but a number; not
  "several", but a count.
- Cut unnecessary adjectives and adverbs.
- No marketing, conversational, or emotional language.
- No idioms, metaphors, or colloquialisms.
- No filler: "basically", "simply", "just", "of course".
- No pronoun whose reference could be ambiguous. Repeat the noun.
- Use modal verbs consistently: `must` for a requirement, `should` for a
  recommendation, `may` for an optional action, `can` for a capability.
- If a sentence can be shorter without losing meaning, shorten it.

## Instructions and procedures

- Present actions in execution order, one action per numbered step.
- State the condition before the action it governs: "If the build fails, run X",
  not "Run X if the build fails".
- Describe the expected result when the reader cannot otherwise confirm success.
- Numbered lists for procedures; bullet lists for unordered information.
- Give a positive rule and its matching prohibition together where both matter.
  Prefer an explicit "do not X" over describing only the correct path.
- Do not rely on emphasis to carry meaning. If a rule is mandatory, write `must`.

## Mode A: machine to human

Audience: a person reading documentation, an explanation, or a change description.
Apply the rules above, and do not assume prior knowledge without explanation or a
link.

### Reading like a person wrote it

Prose a human will read must not carry the habits that mark machine writing.

State the point; do not stage it:

- No opener that announces the point is coming, and no closing line that
  restates it.
- No "not X but Y" framing to add weight, and no aphorism in place of the
  specific claim.
- Do not rebut an objection the text never raised.
- In a reply, lead with the answer or decision, and give only the reasoning the
  reader does not already have.

Plain words over inflated ones:

- Replace stock machine vocabulary — delve, crucial, leverage, robust,
  seamless, showcase, underscore, and their kin — with the plain word.
- Prefer "is", "are", and "has" over "serves as", "boasts", and "features". No
  sales adjectives.
- No inflated significance: end on the concrete fact, not a claim about
  importance, legacy, or the future.
- Name the actual relationship instead of "linked to" or "associated with", and
  cut a trailing "-ing" clause that asserts meaning the text has not shown.
- Attribute authority by name, or cut it. "Experts say" is not a source.

Rhythm and formatting follow the content:

- A list of three is a unit of content, not a cadence. Keep three items only
  when the content has three.
- Prefer commas, full stops, and colons over dashes as the default connector.
- Bold marks nothing but genuine structure. A labelled bullet list whose labels
  add nothing is prose; write it as prose. Headings are sentence case and
  descriptive.

Leave no chat residue in a document:

- No greeting, no praise of the question, no offer of further help.
- No first sentence that restates the heading, and no description of the
  document's own revisions, sourcing, or layout.
- No knowledge-cutoff disclaimer, and no plausible guess presented as fact:
  state what the sources do not show.

## Mode B: machine to machine

Audience: another model or a parser. Write as if the reader is a non-native English
speaker with no context. Apply the rules above, and additionally:

- State facts, not opinions.
- Front-load the condition that decides whether the reader acts at all.
- Be exhaustive about prohibitions. An unstated exclusion will be treated as
  permitted.

When output is read by both audiences, apply Mode A.

## Before responding

Confirm terminology is consistent, every instruction is unambiguous, and each
sentence carries one idea.

## Checklist

- [ ] One idea per sentence, in simple active English.
- [ ] One term per concept, never varied.
- [ ] Vague words replaced with measurable values.
- [ ] Modal verbs used consistently: must, should, may, can.
- [ ] Procedures numbered in execution order, condition before action.
- [ ] No filler, idiom, marketing language, or ambiguous pronoun.
- [ ] No staged opener, restated-point closer, or "not X but Y" framing.
- [ ] No stock machine vocabulary, inflated significance, or unnamed authority.
- [ ] No decorative bold, label-only bullet list, or chat residue in a document.
- [ ] Every reply leads with the answer or decision.
