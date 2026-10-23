---
name: task-tracking
description: Delivery phases, task specs, and bugs - a root task.md listing the phases of development, one task document per phase in tasks/, a spec in specs/ written before any work on a task or bug, and every reported bug in tasks/bugs.md - and where user feedback goes, feature requests into a phase and bugs into the bug list. USE FOR planning, adding, reordering, or dropping a delivery phase. USE FOR starting, finishing, or adding a task, or writing a task or bug spec. USE FOR recording a bug the user reports or a feature request the user feeds back. USE FOR deciding whether a phase is done. DO NOT USE FOR describing what the project is for or which features it has - see project-planning. DO NOT USE FOR diagnosing a bug - see elimination-debugging. DO NOT USE FOR a session-only to-do list that nothing reads afterwards.
globs: task.md,tasks/*.md,specs/*.md
stack: any
---

# Task tracking

## Delivery phases

`task.md`, at the repository root, lists the phases of development in delivery
order. It is the single source of truth for which phases exist and their status.
Each phase's tasks live in its own document, `tasks/task_phase_<n>.md`. The plan's
Documents index links to `task.md` ([[project-planning]]).

```markdown
# Tasks

## Phases

| Phase | Goal | Status | Document |
|---|---|---|---|
| 1 | Sign-up, sign-in, and account settings. | done | [Phase 1](tasks/task_phase_1.md) |
| 2 | Scheduled report export. | in progress | [Phase 2](tasks/task_phase_2.md) |

Bugs: [tasks/bugs.md](tasks/bugs.md)
```

- `task.md` holds the phase table, a link to `tasks/bugs.md`, then **Revision
  history**. Goal is one sentence. Status is `planned`, `in progress`, `done`, or
  `dropped`.
- Number phases from 1. Never renumber a phase or reuse its number: links to it
  would break. A phase added later takes the next unused number, and its row goes
  where it falls in delivery order.
- Derive phases and tasks only from a plan that has passed its review for
  ambiguity, contradiction, and missing context ([[project-planning]]). Never
  write `task.md`, or add a task from a plan change, before that review passes.
- Phases and their goals are the user's decision. Propose them; do not add,
  reorder, or drop one on your own initiative.
- Keep a dropped phase, its row, and its document.

## Phase documents

A phase document holds, in this order:

| Section | Holds |
|---|---|
| `# Phase <n>: <name>` | The heading. |
| Goal | One paragraph. Link the features it delivers in `docs/features.md`; do not restate them. |
| Tasks | One checkbox per task, numbered, each small enough to finish and commit alone ([[git-and-commits]]). |
| Done when | Measurable conditions that end the phase. |
| Open questions | Every undecided item in the phase, and who must decide it. |
| Revision history | The table defined in [[project-planning]]. |

- Number tasks `T1` upwards across every phase, so a number names one task in the
  whole project. Never renumber or reuse a number. A task with no number gets the
  next unused one before its spec is written.
- Write a task as `- [ ] T<n>: <what it delivers>`, and link its spec once it
  exists: `- [ ] T5: Schedule exports from the admin screen. [Spec](../specs/spec-TASK-5.md)`.
- Add a task to its phase document before starting it. Show the user the tasks
  you drafted for a phase before working through them.
- Tick a task only when every unit of work in its spec is done, its spec's Done
  when holds, and its tests pass ([[testing-standards]]).
- Set a phase `in progress` when its first task starts, and `done` only when
  every task is ticked or removed and every Done when condition holds.
- Ticking a task and changing a phase's status are progress, not revisions; they
  need no revision row. Adding, changing, or removing a phase, a task, or a Done
  when condition does.

## Specs

Before producing any work on a task or a bug, write its spec in `specs/`:

| Work | Spec |
|---|---|
| Task `T<n>` | `specs/spec-TASK-<n>.md` |
| Bug `B<n>` | `specs/spec-BUG-<n>.md` |

Reading code and investigating come first; for a bug, so does its diagnosis,
including a temporary change made to test a named candidate
([[elimination-debugging]]). No other code, test, configuration, or file change
for the work comes before its spec. Show the user the spec, then begin.

A spec holds, in this order:

| Section | Holds |
|---|---|
| Heading | `# T<n>: <what it delivers>` or `# B<n>: <bug title>`, matching its entry. |
| Source | A task: a link to its phase document, and the features it serves in `docs/features.md`. A bug: a link to its entry in `tasks/bugs.md`, its confirmed root cause, and the evidence that confirmed it. |
| Scope | Two lists: in scope, and explicitly out of scope. |
| Units of work | Numbered. Each names what changes, the files or modules it touches, the tests that prove it, and its own Done when. Each is small enough to commit alone ([[git-and-commits]]). For a bug, the first unit is the regression test that fails for the reported reason ([[testing-standards]]). |
| Done when | Measurable conditions that end the work. |
| Revision history | The table defined in [[project-planning]]. |

- A spec is fully scoped and refined: a reader could carry out every unit without
  asking. No unit says "etc.", "as needed", "and so on", or "TBD".
- A spec holds no open question. Ask the user about anything undecided before
  writing the spec, and record the answer in the plan document that owns it
  ([[project-planning]]).
- A spec covers its task or bug and nothing more. Work beyond it becomes a new
  task, proposed to the user, or a new bug.
- The work follows the spec. When the work must diverge, update the spec first,
  then the work.
- Commit the spec no later than the first unit of work.
- Keep every spec, including a dropped task's or a `won't fix` bug's. Never delete
  one.

## Feature requests and bugs

Classify each change the user feeds back before recording it. A bug is behaviour
that contradicts the plan or the user's stated expectation of delivered work. A
feature request asks for behaviour the plan does not describe. When the user's
description fits both, ask which it is.

- A feature request becomes a task at the end of the current phase's Tasks, or of
  the phase the user names. The current phase is the first phase in `task.md` that
  is neither `done` nor `dropped`. When every phase is `done` or `dropped`,
  propose a new phase. Agree the feature entry first ([[project-planning]]).
- Every bug goes in `tasks/bugs.md`, never in a phase document. A defect in a task
  not yet ticked is part of that task, not a bug.
- Record a bug before starting to fix it. Diagnose it by elimination
  ([[elimination-debugging]]), write its spec (see Specs), then fix it with a
  regression test ([[testing-standards]]).

## The bug list

`tasks/bugs.md` holds one entry per bug, newest first:

```markdown
# Bugs

### B2: Export fails for a report with no rows
- Reported: 2026-03-05
- Status: open
- Observed: The export returns a 500 error.
- Expected: An export containing only the header row.
- Reproduce: Schedule an export of a report filtered to no rows.
- Spec: [spec-BUG-2](../specs/spec-BUG-2.md)
```

- Number every bug `B1` upwards. Never renumber or reuse a number.
- Add the `Spec:` line once the bug's spec exists.
- `Reported` is an absolute ISO date, `YYYY-MM-DD`.
- Status is `open`, `in progress`, `fixed`, or `won't fix`. Set `fixed` only when
  every unit of work in its spec is done, and the regression test fails without
  the fix and passes with it. `won't fix` is the
  user's decision; give the reason on a `Reason:` line.
- Keep every entry, fixed or not. Deleting one loses the record that it happened.
- `tasks/bugs.md` has no revision history: each entry carries its own date, and
  status changes are progress.
- Never put a secret, credential, or personal datum in a bug entry, including in
  pasted logs or reproduction data ([[secure-engineering]]).

## Checklist

- [ ] Every phase and task derives from a plan that passed its review.
- [ ] `task.md` lists every phase with a status that matches reality, each linked to its `tasks/task_phase_<n>.md`.
- [ ] Every task worked on is in its phase document, numbered `T<n>`.
- [ ] Every started task had its `specs/spec-TASK-<n>.md`, and every bug fix its `specs/spec-BUG-<n>.md`, before any other work on it.
- [ ] Every spec is fully scoped, holds no open question, and matches the work done.
- [ ] Every ticked task is done and its tests pass.
- [ ] Every feature request is a task in the current phase or the phase the user named.
- [ ] Every bug the user reported is in `tasks/bugs.md`, numbered `B<n>`, and no bug is in a phase document.
- [ ] Every `fixed` bug has a regression test that fails without the fix.
- [ ] `task.md` and each phase document this commit alters has one revision row for it ([[project-planning]]).
