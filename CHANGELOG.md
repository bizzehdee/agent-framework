# Changelog

User-visible changes to the framework, newest first. `--check` reports the
installed and current standards version hashes; this file is how you find out
what sits between them. Dates are the day the change landed on `main`.

## Unreleased

### Added

- `--lite` on build and install: one always-on `AGENTS.md` for small-context
  local models — the core rules plus each standard's checklist as rules, ~5k
  tokens for all stacks. No skills tree, no adapters; `--check` and `--upgrade`
  keep the mode, and `--upgrade --lite` converts a full install.
- Every standard now ends with a checklist (four gained one); the lite build
  derives from it and the suite enforces it.
- `technical-writing` gains "Reading like a person wrote it": rules against
  machine-sounding prose in human-facing documents and replies, distilled from
  blader/humanizer.

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

- Windows builds and installs run an order of magnitude faster (build 58s to
  2s, install 44s to 6s; the full suite 15+ min to 6 min): one awk pass parses
  all frontmatter and triggers, one awk writes every generated file, one awk
  performs the whole copy and check, stack detection is one `find` instead of
  seventeen, and the leftover walk is one `find` with in-shell set matching.
  Output is byte-identical.

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
