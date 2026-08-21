# Agent instruction framework

Portable engineering standards for AI coding agents. One source of truth, a minimal
footprint in the repositories you install into.

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

Both scripts take the same arguments and produce identical output. Use whichever
suits your platform.

```bash
./install.sh /path/to/project
```

```bash
pwsh ./install.ps1 -Target C:\code\my-project
```

The installer detects the project's stacks and which agentic tools you have, then
offers the optional adapters with **none** as the default. Press Enter for the clean
two-entry install.

| Flag | Effect |
|---|---|
| `--stacks LIST` / `-Stacks` | Which stacks to install. Default: detected. |
| `--adapters LIST` / `-Adapters` | Add tool-specific directories. Default: none. |
| `--check` / `-Check` | Report whether an install is current. Writes nothing. |
| `--yes` / `-Yes` | Accept defaults, no prompt. |
| `--force` / `-Force` | Overwrite existing files (otherwise skipped). |
| `--dry-run` / `-DryRun` | Print the plan without writing. |

When stdin is not a terminal the defaults are used without prompting, so CI never
hangs.

### Globally

The way to get real skill loading without touching any repository:

```bash
./install.sh --user
```

| Tool | Destination |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/standards/` |
| Codex | `~/.codex/AGENTS.md`, `~/.codex/standards/` |

Cursor user rules are set in the app; Copilot is repository-level only. Skills *are*
written here, because `~/.claude` is not a repository. A user install includes every
stack, since it serves all your projects.

## Stack scoping

A standard declares `stack:` in its frontmatter. `any` installs everywhere; a named
stack installs only into matching projects, so a Python repo never receives .NET
rules.

Detection looks for marker files up to three levels deep: `*.csproj`/`*.sln`/
`global.json` → `dotnet`; `pyproject.toml`/`setup.py`/`requirements.txt` → `python`;
`Cargo.toml` → `rust`; `CMakeLists.txt`/`*.vcxproj` → `c-cpp`; `package.json` →
`node`; `go.mod` → `go`. Override with `--stacks`, or `--stacks any` for universal
standards only.

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

Only Claude Code does on-demand loading well. Cursor's is agent-requested; Copilot
has no such mode, so only standards with natural globs become auto-attached files.
Without an adapter a tool reads the `AGENTS.md` table and opens what it needs — one
extra file read for a clean repository. Prefer a global install if you want skill
loading.

## Keeping installs current

Installed copies are snapshots. Each generated file records the framework revision
and the stack set it was built from, so you can ask whether an install is current.
It writes nothing, and exits 1 when out of date:

```bash
./install.sh /path/to/project --check
```

```
Installed version: 2872b676
Current version:   4e9f10ab
12 up to date, 1 differ, 1 missing.
Out of date. Re-install: ./install.sh /path/to/project --force
```

To update, edit a file in `standards/` and re-run the installer with `--force`.

## Requirements

`install.sh` / `build.sh` need POSIX `/bin/sh` plus `awk`, `sed`, `find` (dash, bash,
or Git Bash). `install.ps1` / `build.ps1` need PowerShell 7+. Installed projects need
neither — the output is plain Markdown.

## The standards

Universal (`stack: any`):

| Standard | Covers |
|---|---|
| `secure-engineering` | Security priority ordering, secrets, boundary validation, privacy. |
| `existing-project-conventions` | Repository conventions outrank these defaults. |
| `elimination-debugging` | Candidate enumeration, the elimination report format, evidence before decisions. |
| `error-handling` | Return expected failures; exceptions are for exceptional cases only. |
| `testing-standards` | Coverage target, definition of done, mocking limits, determinism. |
| `code-quality` | SOLID and DRY, abstraction timing, comments, dead code. |
| `architecture-principles` | Vertical slices, composition, no speculative patterns. |
| `git-and-commits` | Per-task commits in a series, otherwise on request; message format. |
| `no-hardcodes` | Pre-commit gate: blocks secrets and environment-specific values. |
| `dependency-management` | Licence, supply-chain and lockfile discipline. |
| `research-provenance` | Check order before web search, archiving, indexing, and extracts. |
| `learnings` | Durable project knowledge in `.learnings/`: record what a task teaches, consult it first. |
| `observability-standards` | Structured logging, what to log, health checks. |
| `performance-discipline` | Measure before optimising; defects to avoid by default. |
| `technical-writing` | Controlled style for human- and machine-facing prose. |

`stack: dotnet`:

| Standard | Covers |
|---|---|
| `concurrency-and-async` | Default to async, never block, bound parallelism, safe shared state. |
| `data-and-migrations` | EF Core migrations, expand and contract, tracking and transactions. |
| `playwright-integration-tests` | Web projects only: when a behaviour needs a real-browser Playwright test, and e2e conventions. |

`stack: python`:

| Standard | Covers |
|---|---|
| `environments-and-packaging` | Virtual environments, pyproject as source of truth, lockfiles, no path hacks. |

`stack: c-cpp`:

| Standard | Covers |
|---|---|
| `memory-and-resource-safety` | RAII and ownership, bounded buffers, undefined behaviour, warnings as errors, sanitisers. |

`_core.md` holds the eight non-negotiables, injected inline into every output rather
than loaded on demand — a rule that applies only once loaded is not a
non-negotiable.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the frontmatter schema, adding a tool or
stack, and the test suite.
