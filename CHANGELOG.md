# Changelog

User-visible changes to the framework, newest first. `--check` reports the
installed and current standards version hashes; this file is how you find out
what sits between them. Dates are the day the change landed on `main`.

## Unreleased

### Added

- `java`, `kotlin`, and `android` stacks, detected by reading a project's
  Gradle or Maven build files: `com.android` adds `android`, any mention of
  `kotlin` makes it `kotlin`, and otherwise it is `java`. Nine standards:
  `jvm-build-and-dependencies` (all three stacks), `java-language`,
  `java-concurrency`, `kotlin-language`, `kotlin-coroutines`,
  `android-project-files`, `android-architecture`, `android-ui`, and
  `android-platform-safety`.
- Three universal standards for the machine and for portability:
  `platform-agnostic-development`, `developing-on-windows`, and
  `developing-on-linux` (Fedora, and Ubuntu and Debian). Being universal, they
  are part of bare `--lite`, which grows to about 5k tokens.

- `unreal` stack, detected from `*.uproject` or `*.uplugin`, with five
  standards: `unreal-project-files`, `unreal-cpp-conventions`,
  `unreal-object-lifetime`, `unreal-gameplay-architecture`, and
  `unreal-replication`. An Unreal project receives `unreal` alone: the `.sln`
  and `.vcxproj` files it generates no longer count as `dotnet` or `c-cpp`.
- Four more `c-cpp` standards: `cpp-build-and-toolchain`,
  `cpp-undefined-behaviour`, `cpp-headers-and-interfaces`, and
  `cpp-concurrency`.

- Release workflow: a `release/X.Y.Z` tag publishes a GitHub release with
  prebuilt `generic`, `claude`, and `generic-lite` zip packages attached.

- `process-control`: wait on and kill processes by PID, never by a
  command-line pattern the matching command itself contains, which makes a
  `pgrep -f` loop spin forever and a `pkill -f` kill its own shell.

- `--lite` on build and install: one always-on `AGENTS.md` for small-context
  local models — the core rules plus each standard's checklist as rules. No
  skills tree, no adapters; `--check` and `--upgrade` keep the mode, and
  `--upgrade --lite` converts a full install.
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

- `--lite` is now the core rules only: the non-negotiables plus the universal
  standards. It no longer adds detected stacks. Name the
  stacks to include with `--lite=LIST` (`-Lite -Stacks LIST` in PowerShell).
  An existing lite install keeps its stamped stacks on `--upgrade`. The
  `generic-lite` release package now holds the core rules only.
- Stack detection skips `Intermediate/` directories.
- When no stack marker is found, the installer asks which stacks apply instead
  of silently installing the universal standards only. With `-y` or without a
  terminal it still falls back to the universal standards.

- Testing is split by platform. `test.sh` tests the sh scripts on Linux and
  macOS; the new `test.ps1` tests the PowerShell scripts natively on Windows
  (86 tests in under 30 seconds, where the sh suite under Git Bash took 6+
  minutes). No machine runs both shells: each suite writes a manifest of test
  names and file hashes, and a CI `parity` job diffs them.

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
