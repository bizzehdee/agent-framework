---
name: _core
description: Always-on rules. Injected inline into every generated instruction file. Never emitted as an on-demand standard.
globs:
stack: any
---

## Non-negotiables

These apply always. Do not wait to load a standard before honouring them.

1. **Security and privacy rank above simplicity, effort, and delivery speed.**
   Never trade them for simpler code or faster delivery. Default to the secure
   option and say that you did. Surface a genuine tradeoff to the user before
   implementing it; never silently pick the weaker side.
   Detail: `secure-engineering`.
2. **An existing repository's conventions beat every default here.** Establish the
   repository's build command, test command, structure, and conventions before
   your first change. Read `.learnings/` — its index and every relevant entry —
   before your first change, and record what this task teaches back into it,
   creating the directory if it does not exist yet.
   Read `plan.md`, and the `docs/` documents it indexes, for what the project is
   for and what is in scope. Update the document that owns the changed section —
   with a dated revision row — in the same change that adds, changes, or removes
   a feature. Read `task.md` and the current phase's document in `tasks/`
   before starting work, and tick a task there only when it is done.
   Detail: `existing-project-conventions`, `learnings`, `project-planning`.
3. **Tests must pass before a task is done.** Do not mark a checkbox or report
   completion until you have run the tests and observed them pass. If they fail,
   include the output. Detail: `testing-standards`.
4. **Do not guess.** Do not assume unstated requirements. Ask when requirements
   are ambiguous, and when obvious candidate answers exist, present them as
   options rather than asking open-ended.
5. **Prefer modifying existing working code over rewriting it.**
6. **Justify before you abstract, and ask before you re-architect.** State why a
   new abstraction is needed before adding it. Obtain approval before an
   architectural change. Detail: `code-quality`, `architecture-principles`.
7. **Diagnose by elimination, never by fix-first.** Do not change code to see what
   happens. Change code only to test a named candidate, and name it first.
   Detail: `elimination-debugging`.
8. **Report outcomes faithfully.** If a step was skipped, say so. If a result is
   unverified, label it unverified. Do not describe intended behaviour as
   observed behaviour.
