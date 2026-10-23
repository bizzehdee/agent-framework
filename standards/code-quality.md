---
name: code-quality
description: Standards for code structure, duplication, abstraction timing, comments, and dead code. Covers one clear purpose per file, class, and module with no monolithic files or catch-all utility classes, SOLID and DRY balanced against a no-premature-abstraction rule, the why-only comment policy, and mandatory removal of dead and commented-out code. USE FOR writing new code, reviewing a diff, refactoring, deciding where new code belongs, splitting a file or class, deciding whether to extract an abstraction, deciding whether to add a comment, or cleaning up a file. DO NOT USE FOR architectural or feature-boundary decisions - see architecture-principles.
globs:
stack: any
---

# Code quality

## One purpose per unit

Every file, class, module, and object has one purpose, in any language. State that
purpose in one short phrase before creating the unit. If the phrase needs "and",
or names no concern, the unit is two units or none.

- Split code into its logical components. A file holds one type, or one cohesive
  group of functions serving one concern. Where the language's idiom differs, such
  as a header and source pair, follow the idiom.
- No monolithic files. A file's concern count is the test, not its length: a long
  file with one concern is acceptable; a short file with two is not. Split a file
  in the change that would add a second concern to it.
- No catch-all units. Never create, or add to, a unit whose name states no purpose:
  `Utils`, `Utilities`, `Helpers`, `Common`, `Misc`, `Shared`, `General`, or
  similar.
- Put a function with the type or module that owns the data or concern it works
  on. When no such unit exists, create one named for that concern
  (`DateRangeFormatter`, not `Utils.formatDate`). Not knowing where code belongs
  is a design question to answer, never a reason for a catch-all.
- A unit's name states its purpose. When its contents outgrow the name, split the
  contents; do not widen the name.
- Splitting by concern moves code into named homes; it is not abstraction, and
  needs no justification under No premature abstraction.

In an existing repository, these rules govern new code ([[existing-project-conventions]]).
Never add to an existing catch-all or multi-concern unit: put the new code in a
unit named for its concern. Propose splitting the existing unit; do not split it
uninvited inside an unrelated change.

## SOLID and DRY, bounded by need

Follow SOLID and avoid duplication, balanced against no-premature-abstraction below.
Extract a common method when the same logic exists in more than one place.

Duplication of *shape* is not duplication of *logic*. Two blocks that look alike but
change for different reasons stay separate.

## No premature abstraction

Abstract only for a need that exists now. A concrete need is one of:

- The same logic exists in two or more places already.
- A second implementation of an interface exists, or the current task requires one.
- A boundary must be crossed for testability now.

State which of these applies before introducing an abstraction. Prefer duplicating a
small amount of code twice over an abstraction whose shape you cannot yet know.

## Comments

Comment only when the *why* is non-obvious. Never explain what the code does —
well-named identifiers do that. Legitimate comments explain:

- A constraint imposed from outside the code.
- A workaround, including what it works around and when it can be removed.
- A subtle invariant a reader could break unknowingly.

If a comment is needed to explain *what*, rename the identifiers or extract a named
method instead. Public API documentation comments are exempt where the codebase's
convention requires them.

## Dead code

- Remove dead code when you find it. Never comment it out.
- Remove commented-out code rather than leaving it. Version control holds the
  history.
- Remove parameters, fields, imports, and private members that your change makes
  unreachable.
- Do not remove code unreachable only from the current entry point but part of a
  published API. Ask first.

## Checklist

- [ ] Every new or changed file, class, and module has one purpose its name states.
- [ ] No file gained a second concern.
- [ ] Nothing added to a catch-all unit such as `Utils` or `Helpers`.
- [ ] No logic duplicated across the change.
- [ ] Every new abstraction has a stated, present-tense justification.
- [ ] Every comment explains a why, not a what.
- [ ] No commented-out code remains.
- [ ] Nothing left unreachable by this change.
