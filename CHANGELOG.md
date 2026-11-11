# Changelog

User-visible changes to the framework, newest first. `--check` reports the
installed and current standards version hashes; this file is how you find out
what sits between them. Dates are the day the change landed on `main`.

## Unreleased

### Added

- Canonical documents: a `> **Canonical.** ` marker after a document's heading
  makes it a binding, locked source of truth. Work in its scope must conform
  exactly, and edits need double sign-off. New `canonical-documents` standard
  and a new core non-negotiable.
- `default-stacks`: suggested default language and framework per project type,
  offered during stack selection, never enforced.
- `hooks` adapter: `--adapters hooks` writes `.githooks/pre-commit`, a working
  no-hardcodes gate for human commits. Enable per clone with
  `git config core.hooksPath .githooks`.
- Starter standards for three detected stacks that had none: `node-packaging`,
  `go-modules`, `rust-cargo`.
- Scale rule in `project-planning`: a small project may keep its whole plan
  inline in `plan.md`, and the document set is the user's decision.
- Suite now validates `[[links]]` between standards, and CI runs on macOS
  (bash 3.2) as well as Linux and Windows.

### Changed

- Core rule 2 split in two: repository conventions and learnings, and the
  planning and tracking documents, are now separate non-negotiables (ten in
  all).
- The coverage exclusion in `testing-standards` names schema migrations, not
  EF Core specifically.
- A canonical marker binds even when no `plan.md` indexes the document.

## Before 2026-11-11

The changelog starts here. Earlier history is in `git log`: the initial
standards set, the AGENTS.md + `.agents/skills/` layout, stack scoping and
detection, the claude and copilot adapters, `--check` and `--upgrade`, and the
cross-shell test suite.
