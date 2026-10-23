---
name: project-planning
description: The project plan - a root plan.md overview indexing one source-of-truth document per section in docs/ - written through conversation with the user before building, kept current as features change, and the one-row-per-commit revision table that ends every plan and task document. USE FOR starting a new project, scaffolding a greenfield repository, or any request to plan, describe, or scope a project. USE FOR adding, changing, or removing a feature, endpoint, screen, job, or integration. USE FOR reviewing a plan for ambiguity, contradiction, or missing context. USE FOR reconstructing a plan for a project already under way. USE FOR answering what a project is for or whether something is in scope. DO NOT USE FOR recording a non-obvious fact discovered while working - see learnings. DO NOT USE FOR delivery phases, tasks, or bugs - see task-tracking. DO NOT USE FOR choosing an architecture or judging an abstraction - see architecture-principles and code-quality.
globs: plan.md,**/plan.md,docs/*.md
stack: any
---

# Project planning

## An overview, and one document per section

The plan is the project's description of intent: what it is for, what it must do,
and what it will not do. It is the answer to "what is this project", and it stays
true for the life of the project.

The plan is split across files:

- `plan.md`, at the repository root, is the overview. It holds the project-wide
  sections and indexes every section document. Exactly one, not one per feature.
- `docs/<section>.md` is the single source of truth for one section of the plan.
  One document per section.

Rules for every plan document:

- A fact lives in exactly one document. Every other document links to it and does
  not restate it. `plan.md` summarises each section document in one line, no more.
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
   given goes in the owning document's **Open questions**, named, and is not
   treated as settled.
4. Write `plan.md` and each section document, then show the user the open
   questions that remain.
5. Review the plan (see Reviewing the plan) and resolve every finding.
6. Propose delivery phases and agree them with the user, then write `task.md`
   and a task document for each phase ([[task-tracking]]).
7. Do not begin implementation until Purpose, Scope, Features and Stack are
   settled and the first phase's tasks are written, or the user says to start
   with the rest open.

The plan is as complete as the user can make it, not as complete as you can guess
it. An unanswered question recorded as open is correct; a guess written as a
requirement is a defect.

## Reviewing the plan

The plan must be self-complete and self-consistent before any task is derived from
it. Self-complete: a reader holding only the plan documents, without this
conversation, can build what it describes without asking. Self-consistent: no two
statements in it conflict.

Review the whole plan before writing `task.md`. After that, review each plan change
against every document it touches before deriving a task from it. Read the
documents together, not one at a time, and check for:

| Finding | Examples |
|---|---|
| Ambiguity | A statement with two readings. An unmeasurable term: "fast", "secure", "scalable", "as needed", "etc.". One thing called by two names, or two things by one. |
| Contradiction | A feature that Scope places out of scope. A constraint the Stack cannot meet. Two documents stating different values for one fact. |
| Missing context | A user need with no feature, or a feature serving no user. A feature using data absent from `docs/data.md`, or an external system absent from `docs/integrations.md`. A term, document, or link that is undefined or does not resolve. A fact that exists only in this conversation. |

- Show the user every finding: its document, the statement, its kind, and
  candidate resolutions as options. At most five per turn.
- Fix each finding in the document that owns the fact, as the user resolves it.
  Never resolve one by guessing: the plan states only what the user decided.
- A finding the user chooses to leave undecided goes in its document's Open
  questions. No task may depend on it until it is decided.
- Review again after the fixes. The plan passes when a full review finds nothing
  new.

## `plan.md`: the overview

Sections, in this order:

| Section | Holds |
|---|---|
| Purpose | The problem, and who has it. One paragraph. |
| Users | Each kind of user, and what they need to do. |
| Scope | Two lists: in scope, and explicitly out of scope. |
| Documents | The index table defined below. |
| Open questions | Every undecided project-wide item, and who must decide it. |
| Revision history | The table defined below. |

The Documents index has one row per section document:

```markdown
## Documents

| Document | Covers |
|---|---|
| [Features](docs/features.md) | Every feature, what it does, and its status. |
| [Stack](docs/stack.md) | Languages, frameworks, runtime, and hosting. |
| [Tasks](task.md) | Delivery phases, in order, and their status. |
| [Integrations](docs/integrations.md) | Not applicable: the project calls no external system. |
```

## Section documents

| Document | Holds |
|---|---|
| `docs/features.md` | One entry per feature: name, what it does, status. |
| `docs/stack.md` | Languages, frameworks, runtime, hosting, and why each. |
| `docs/data.md` | The entities, and where each is stored. |
| `docs/integrations.md` | External systems, and what each is used for. |
| `docs/constraints.md` | Performance, security, compliance, deployment, budget targets, as measurable values. |

- Every section document starts with a `#` heading naming the section, and ends
  with **Open questions** then **Revision history**. Open questions holds every
  undecided item in that section, and who must decide it.
- An over-arching aspect of the project not listed above, such as deployment or a
  security model, gets its own `docs/<aspect>.md`, named in lowercase kebab-case,
  and an index row. Do not grow a section document to cover a second aspect.
- When a section cannot apply to the project, create no document for it. Its index
  row says `Not applicable` and why. A section that applies but is undecided gets
  a document with `None.` under its content and the undecided items under Open
  questions.
- When `docs/` already holds a document covering a section, the index links to
  that document. Do not create a second copy. When a section document's name is
  taken by an unrelated document, ask the user what to name it.

A feature entry is at most five lines. Status is `planned`, `in progress`, `done`,
or `dropped`. Keep a dropped feature and its entry; deleting it loses the record
that it was considered.

## Keeping the plan current

- Update the document that owns a section in the same change that alters that
  section. A plan update deferred to later does not happen.
- For work the user has asked for, agree the feature entry before implementing
  it. For work already implemented, correct the plan before reporting the task
  done.
- When implementation contradicts the plan, the plan is wrong. Change the owning
  document and say what changed.
- Scope changes are the user's decision. Propose an addition to Scope or
  Features; do not widen either on your own initiative.
- A project with no `plan.md` has not recorded one yet. Offer to reconstruct it
  from the code and to confirm each reconstructed section with the user. Mark
  anything inferred from the code as inferred until the user confirms it. Never
  create a plan document silently.
- A `plan.md` that holds a section's content inline, or a Milestones section,
  predates this layout. Offer to move each such section into its document, and
  milestones into `task.md` ([[task-tracking]]). Do not move it inside an
  unrelated change.

## Revision history

The last section of every plan document, and of `task.md` and each phase document
([[task-tracking]]), is a table, at most one row per commit that changed the
document, newest first:

```markdown
## Revision history

| Date | Change | Summary |
|---|---|---|
| 2026-03-04 | Changed | Export moved from CSV to XLSX; CSV kept for one release. |
| 2026-02-18 | Added | Scheduled report export, admin only. |
| 2026-02-11 | Created | Initial feature list from requirements conversation. |
```

- `Date` is an absolute ISO date, `YYYY-MM-DD`. Never "today" or a relative term.
- `Change` is one of `Created`, `Added`, `Changed`, `Removed`, `Dropped`.
- `Summary` is one sentence naming what the document now says differently. Do not
  describe the code change; describe the change to the document.
- A row goes in each document the commit changes, and only those. Adding or
  removing a section document changes the index, so it also changes `plan.md`.
  Adding or dropping a phase changes `task.md`.
- One row per document per commit. Before adding a row, check whether the
  newest row is already committed. It is uncommitted when the repository has no
  commits, the document is untracked, or `git diff HEAD -- <document>` shows the
  row as added. If it is uncommitted, update it instead of adding another: set
  `Date` to the current date, keep `Created` if it says `Created`, otherwise set
  `Changed` when the commit mixes kinds of change, and rewrite `Summary` to cover
  everything the commit changes in the document.
- Never edit or delete a committed row, and never rewrite history to look tidier.

## Checklist

- [ ] `plan.md` exists at the repository root, or its absence was raised with the user.
- [ ] Every `plan.md` section present.
- [ ] Every section document indexed in `plan.md`, or its index row says `Not applicable` and why.
- [ ] No fact stated in more than one plan document.
- [ ] No requirement in the plan that the user did not state.
- [ ] The plan passed a review for ambiguity, contradiction, and missing context before any task was derived from it.
- [ ] Every undecided item listed under its document's Open questions with an owner.
- [ ] Feature statuses match reality.
- [ ] Each document this commit alters has exactly one uncommitted revision row, dated and covering the whole commit.
- [ ] No secret or personal data in the plan.
