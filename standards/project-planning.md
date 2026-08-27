---
name: project-planning
description: The project plan in a root plan.md - describing a new project fully through conversation with the user before building it, keeping that description current as features are added or changed, and the revision table that records every update. USE FOR starting a new project, scaffolding a greenfield repository, or any request to plan, describe, or scope a project. USE FOR adding, changing, or removing a feature, endpoint, screen, job, or integration. USE FOR reconstructing a plan for a project already under way. USE FOR answering what a project is for or whether something is in scope. DO NOT USE FOR recording a non-obvious fact discovered while working - see learnings. DO NOT USE FOR a session-only task breakdown that nothing reads afterwards. DO NOT USE FOR choosing an architecture or judging an abstraction - see architecture-principles and code-quality.
globs: plan.md,**/plan.md,docs/plan.md
stack: any
---

# Project planning

## One file, at the repository root

`plan.md` is the project's description of intent: what it is for, what it must do,
and what it will not do. It is the answer to "what is this project", and it stays
true for the life of the project.

- Exactly one `plan.md`, at the repository root. Not one per feature.
- The plan states intent. The code states implementation. Do not restate in the
  plan what a reader can read from the code.
- Never put a secret, credential, or personal datum in the plan
  ([[secure-engineering]]).
- The plan holds decided intent; `.learnings/` holds facts discovered while
  working ([[learnings]]). Do not duplicate either into the other.

## Writing the plan for a new project

Produce the plan by interviewing the user, before writing any project code.

1. Ask about the sections below in batches of at most five questions per turn.
2. Offer candidate answers as options whenever obvious candidates exist, rather
   than asking open-ended.
3. Never invent a requirement, user, or constraint. An answer the user has not
   given goes in **Open questions**, named, and is not treated as settled.
4. Write the file, then show the user the sections that are still open.
5. Do not begin implementation until Purpose, Scope, Features and Stack are
   settled, or the user says to start with the rest open.

The plan is as complete as the user can make it, not as complete as you can guess
it. An unanswered question recorded as open is correct; a guess written as a
requirement is a defect.

## Sections, in this order

| Section | Holds |
|---|---|
| Purpose | The problem, and who has it. One paragraph. |
| Users | Each kind of user, and what they need to do. |
| Scope | Two lists: in scope, and explicitly out of scope. |
| Features | One entry per feature: name, what it does, status. |
| Stack | Languages, frameworks, runtime, hosting, and why each. |
| Data | The entities, and where each is stored. |
| Integrations | External systems, and what each is used for. |
| Constraints | Performance, security, compliance, deployment, budget targets, as measurable values. |
| Open questions | Every undecided item, and who must decide it. |
| Milestones | Delivery slices in order. |
| Revision history | The table defined below. |

A feature entry is at most five lines. Status is `planned`, `in progress`, `done`,
or `dropped`. Keep a dropped feature and its entry; deleting it loses the record
that it was considered.

Omit a section only when it cannot apply to the project. An empty section with
`None.` under it is better than a missing one.

## Keeping the plan current

- Update the plan in the same change that adds, changes, or removes a feature.
  A plan update deferred to later does not happen.
- For work the user has asked for, agree the feature entry before implementing
  it. For work already implemented, correct the plan before reporting the task
  done.
- When implementation contradicts the plan, the plan is wrong. Change the plan
  and say what changed.
- Scope changes are the user's decision. Propose an addition to Scope or
  Features; do not widen either on your own initiative.
- A project with no `plan.md` has not recorded one yet. Offer to reconstruct it
  from the code and to confirm each reconstructed section with the user. Mark
  anything inferred from the code as inferred until the user confirms it. Never
  create the file silently.

## Revision history

The last section of the plan is a table, one row per update, newest first:

```markdown
## Revision history

| Date | Change | Summary |
|---|---|---|
| 2026-03-04 | Changed | Export moved from CSV to XLSX; CSV kept for one release. |
| 2026-02-18 | Added | Scheduled report export, admin only. |
| 2026-02-11 | Created | Initial plan from requirements conversation. |
```

- `Date` is an absolute ISO date, `YYYY-MM-DD`. Never "today" or a relative term.
- `Change` is one of `Created`, `Added`, `Changed`, `Removed`, `Dropped`.
- `Summary` is one sentence naming what the plan now says differently. Do not
  describe the code change; describe the plan change.
- One row per update. Never edit or delete an existing row, and never rewrite
  history to look tidier.

## Checklist

- [ ] `plan.md` exists at the repository root, or its absence was raised with the user.
- [ ] Every section present, or absent only because it cannot apply.
- [ ] No requirement in the plan that the user did not state.
- [ ] Every undecided item listed under Open questions with an owner.
- [ ] Feature statuses match reality.
- [ ] A revision row added, dated, for this change.
- [ ] No secret or personal data in the plan.
