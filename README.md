# Agent instruction framework

Portable engineering standards for AI coding agents. One source of truth, a
minimal footprint in the repositories you install it into.

Source-only: no generated file is committed here.

## What an install adds

```
my-repo/
  AGENTS.md          always-on rules + the standards trigger table
  standards/         one file per standard, read only when its trigger matches
```

No `.claude/`, `.cursor/` or `.github/`. `AGENTS.md` is a vendor-neutral standard
read natively by Codex, Cursor, Copilot, Claude Code, Gemini CLI, Aider, Windsurf,
Zed and 20+ others, so on its own it is a complete installation.

## Install

Both scripts take the same arguments and produce identical output.

```bash
./install.sh /path/to/project
```

```bash
pwsh ./install.ps1 -Target C:\code\my-project
```

The installer reports which tools it detected, then offers the optional adapters
with **none** as the default. Press Enter for the clean two-entry install.

| Flag | Effect |
|---|---|
| `--yes` / `-Yes` | Accept defaults, no prompt. |
| `--adapters LIST` / `-Adapters` | Skip the prompt; add exactly these. |
| `--force` / `-Force` | Overwrite existing files (otherwise skipped and reported). |
| `--dry-run` / `-DryRun` | Print the plan without writing. |

When stdin is not a terminal the defaults are used without prompting, so CI never
hangs.

### Globally

The recommended way to get real skill loading without touching any repository:

```bash
./install.sh --user
```

| Tool | Destination |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/standards/` |
| Codex | `~/.codex/AGENTS.md`, `~/.codex/standards/` |

Cursor user rules are set in the app; Copilot is repository-level only. Skills
*are* written here, because `~/.claude` is not a repository.

## Optional adapters

Off unless requested. Each adds a directory and buys on-demand loading for one tool.

| Adapter | Writes | Loading |
|---|---|---|
| `claude` | `.claude/skills/<name>/SKILL.md` | Model-decided, via the Skill tool. |
| `cursor` | `.cursor/rules/<name>.mdc` | Agent-requested from the description. |
| `copilot` | `.github/copilot-instructions.md`, `.github/instructions/` | Repo-wide + `applyTo` globs. |

```bash
./install.sh /path/to/project --adapters claude,cursor
```

Only Claude Code does on-demand loading well. Cursor's is agent-requested;
Copilot has no such mode, so only the two standards with natural globs become
auto-attached files. Without an adapter a tool reads the `AGENTS.md` table and
opens what it needs — one extra file read for a clean repository. Prefer a global
install if you want skill loading.

## Editing the standards

Edit a file in `standards/`, then re-run the installer with `--force`. Installed
copies are snapshots. Nothing is generated inside this repository, so nothing
here can go stale.

### Frontmatter

```markdown
---
name: testing-standards
description: What this covers. USE FOR <trigger>. DO NOT USE FOR <exclusion>.
globs: **/*test*,**/*Test*,**/tests/**
alwaysApply: false
---
```

| Key | Required | Purpose |
|---|---|---|
| `name` | Yes | Must equal the filename. Becomes the skill and rule name. |
| `description` | Yes | Drives model-decided loading. |
| `globs` | No | File patterns. Empty means agent-requested only. |
| `alwaysApply` | No | Reserved for `_core.md`. |

Both generators validate this and fail on a mismatch.

The `Load when` column in `AGENTS.md` is derived from the `USE FOR` clauses, so it
cannot drift from the frontmatter. `DO NOT USE FOR` content is excluded — it must
be, or the table would advertise a standard's exclusions as reasons to load it.
So write triggers as `USE FOR <concrete task>`, and exclusions as
`DO NOT USE FOR <near miss>`, naming the standard to use instead.

## Adding a tool

If it reads `AGENTS.md`, it already works. Add an adapter only if the tool has its
own on-demand loading:

1. Add a branch to `build.ps1` and `build.sh`; add the name to `$KnownAdapters` /
   `KNOWN_ADAPTERS`.
2. Add a probe to `Find-Tool` / `detect_tool`, a label to `$ToolLabels` /
   `tool_label`, an entry to `$AdapterNotes` / `adapter_note`, and the name to
   `$candidates` / `CANDIDATES`.
3. Check both generators still agree:

   ```bash
   sh ./build.sh --out /tmp/a --adapters all && pwsh ./build.ps1 -OutputRoot /tmp/b -Adapters all && diff -r /tmp/a /tmp/b
   ```

Both emit LF, UTF-8 without BOM, and one trailing newline, so output is
comparable byte for byte. CI enforces that on Linux, macOS and Windows, and
asserts a default install adds nothing but `AGENTS.md` and `standards/`.

## Requirements

`install.sh` / `build.sh` need POSIX `/bin/sh` plus `awk`, `sed`, `find` (dash,
bash, or Git Bash). `install.ps1` / `build.ps1` need PowerShell 7+. Installed
projects need neither — the output is plain Markdown.

## The standards

| Standard | Covers |
|---|---|
| `secure-engineering` | Security priority ordering, secrets, boundary validation, privacy. |
| `existing-project-conventions` | Repository conventions outrank these defaults. |
| `elimination-debugging` | Candidate enumeration and the elimination report format. |
| `testing-standards` | Coverage target, definition of done, mocking limits, determinism. |
| `code-quality` | SOLID and DRY, abstraction timing, comments, dead code. |
| `architecture-principles` | Vertical slices, composition, no speculative patterns. |
| `observability-standards` | Structured logging, what to log, health checks. |
| `performance-discipline` | Measure before optimising; defects to avoid by default. |
| `technical-writing` | Controlled style for human- and machine-facing prose. |

`_core.md` holds the eight non-negotiables, injected inline into every output
rather than loaded on demand — a rule that applies only once loaded is not a
non-negotiable.
