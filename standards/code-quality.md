---
name: code-quality
description: Standards for code structure, duplication, abstraction timing, comments, and dead code. Covers SOLID and DRY balanced against a no-premature-abstraction rule, the why-only comment policy, and mandatory removal of dead and commented-out code. USE FOR writing new code, reviewing a diff, refactoring, deciding whether to extract an abstraction, deciding whether to add a comment, or cleaning up a file. DO NOT USE FOR architectural or feature-boundary decisions - see architecture-principles.
globs: 
alwaysApply: false
---

# Code quality

## SOLID and DRY, bounded by need

- Code should follow SOLID principles and avoid duplication (DRY), balanced
  against the no-premature-abstraction rule below.
- Avoid duplicated logic. Prefer extracting a common method when the same logic
  exists in more than one place.
- Duplication of *shape* is not duplication of *logic*. Two blocks that look alike
  but change for different reasons must stay separate.

## No premature abstraction

- Abstract only when a concrete need exists. Do not abstract in anticipation of a
  future need.
- A concrete need means one of:
  - The same logic exists in two or more places now.
  - A second implementation of an interface exists now, or is required by the
    current task.
  - A boundary must be crossed for testability now.
- Before introducing a new abstraction, state in your response why it is needed,
  citing one of the conditions above.
- Prefer duplicating a small amount of code twice over introducing an abstraction
  whose shape you cannot yet know.

## Comments

- Do not add a comment unless the *why* is non-obvious.
- Do not explain what code does. Well-named identifiers do that.
- Comment only to explain:
  - A hidden constraint imposed from outside the code.
  - A workaround, including what it works around and when it can be removed.
  - A subtle invariant a reader could break unknowingly.
- If a comment is needed to explain *what* the code does, rename the identifiers
  or extract a named method instead.
- Public API documentation comments are not covered by this rule. Write them where
  the codebase's convention requires them.

## Dead code

- No dead code. When you identify it, remove it. Do not comment it out.
- Remove commented-out code rather than leaving it in place. Version control holds
  the history.
- Remove unused parameters, fields, imports, and private members that the current
  change makes unreachable.
- Do not remove code that is unreachable only from the current entry point but is
  part of a published API. Ask first.

## Review checklist

- [ ] No logic is duplicated across the change.
- [ ] Every new abstraction has a stated, present-tense justification.
- [ ] Every comment explains a why, not a what.
- [ ] No commented-out code remains.
- [ ] No code left unreachable by this change remains.
