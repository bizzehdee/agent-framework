---
name: task-tracking
description: Delivery phases and bugs - a root task.md listing the phases of development, one task document per phase in tasks/, and every reported bug in tasks/bugs.md - and where user feedback goes, feature requests into a phase and bugs into the bug list. USE FOR planning, adding, reordering, or dropping a delivery phase. USE FOR starting, finishing, or adding a task. USE FOR recording a bug the user reports or a feature request the user feeds back. USE FOR deciding whether a phase is done. DO NOT USE FOR describing what the project is for or which features it has - see project-planning. DO NOT USE FOR diagnosing a bug - see elimination-debugging. DO NOT USE FOR a session-only to-do list that nothing reads afterwards.
globs: task.md,tasks/*.md
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
| Tasks | One checkbox per task, each small enough to finish and commit alone ([[git-and-commits]]). |
| Done when | Measurable conditions that end the phase. |
| Open questions | Every undecided item in the phase, and who must decide it. |
| Revision history | The table defined in [[project-planning]]. |

- Add a task to its phase document before starting it. Show the user the tasks
  you drafted for a phase before working through them.
- Tick a task only when it is done and its tests pass ([[testing-standards]]).
- Set a phase `in progress` when its first task starts, and `done` only when
  every task is ticked or removed and every Done when condition holds.
- Ticking a task and changing a phase's status are progress, not revisions; they
  need no revision row. Adding, changing, or removing a phase, a task, or a Done
  when condition does.

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
  ([[elimination-debugging]]), and fix it with a regression test
  ([[testing-standards]]).

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
```

- Number bugs `B1` upwards. Never renumber or reuse a number.
- `Reported` is an absolute ISO date, `YYYY-MM-DD`.
- Status is `open`, `in progress`, `fixed`, or `won't fix`. Set `fixed` only when
  the regression test fails without the fix and passes with it. `won't fix` is the
  user's decision; give the reason on a `Reason:` line.
- Keep every entry, fixed or not. Deleting one loses the record that it happened.
- `tasks/bugs.md` has no revision history: each entry carries its own date, and
  status changes are progress.
- Never put a secret, credential, or personal datum in a bug entry, including in
  pasted logs or reproduction data ([[secure-engineering]]).

## Checklist

- [ ] Every phase and task derives from a plan that passed its review.
- [ ] `task.md` lists every phase with a status that matches reality, each linked to its `tasks/task_phase_<n>.md`.
- [ ] Every task worked on is in its phase document.
- [ ] Every ticked task is done and its tests pass.
- [ ] Every feature request is a task in the current phase or the phase the user named.
- [ ] Every bug the user reported is in `tasks/bugs.md`, and no bug is in a phase document.
- [ ] Every `fixed` bug has a regression test that fails without the fix.
- [ ] `task.md` and each phase document this commit alters has one revision row for it ([[project-planning]]).
