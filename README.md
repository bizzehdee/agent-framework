# Agent instruction framework

Portable engineering standards for AI coding agents. One source of truth, a minimal
footprint in the repositories you install into.

## What an install adds

```
my-repo/
  AGENTS.md                       always-on rules + the standards trigger table
  .agents/skills/<name>/SKILL.md  one skill per standard, loaded on demand
```

Two open standards, one copy of every rule. [`AGENTS.md`](https://agents.md) is read
natively by Codex, Cursor, Copilot, Claude Code, Gemini CLI, Aider, Windsurf, Zed
and 20+ others. [`.agents/skills/`](https://agentskills.io) is the vendor-neutral
Agent Skills location, which Codex, Cursor, Copilot/VS Code and OpenCode load
natively — a tool with a skill loader gets real progressive disclosure, and one
without reads `AGENTS.md` and opens the path from its trigger table.

No `.cursor/` or `.github/`, and no second copy of the prose anywhere.

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

To migrate an install made by an earlier version, see
[Upgrading an existing install](#upgrading-an-existing-install).

| Flag | Effect |
|---|---|
| `--stacks LIST` / `-Stacks` | Which stacks to install. Default: detected. |
| `--adapters LIST` / `-Adapters` | Add tool-specific directories. Default: none. |
| `--check` / `-Check` | Report whether an install is current. Writes nothing. |
| `--upgrade` / `-Upgrade` | Migrate an existing install to the current layout. Implies `--force`. |
| `--yes` / `-Yes` | Accept defaults, no prompt. |
| `--force` / `-Force` | Overwrite existing files (otherwise skipped). |
| `--dry-run` / `-DryRun` | Print the plan without writing. |

When stdin is not a terminal the defaults are used without prompting, so CI never
hangs.

### Globally

The way to apply the standards everywhere without touching any repository:

```bash
./install.sh --user
```

| Destination | Serves |
|---|---|
| `~/.agents/skills/` | Codex, Cursor, Copilot/VS Code, OpenCode — always written |
| `~/.claude/CLAUDE.md` + `~/.claude/skills/` | Claude Code, when detected |
| `~/.codex/AGENTS.md` | Codex, when detected |

One skills tree serves every tool that reads the user-level Agent Skills location.
A user install includes every stack, since it serves all your projects — the
descriptions are stack-scoped, so a .NET standard will not trigger in a Python
project.

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

Off unless requested. There are only two, because every other tool reads
`.agents/skills/` or `AGENTS.md` already.

| Adapter | Writes | Why it exists |
|---|---|---|
| `claude` | `.claude/skills/<name>/SKILL.md` | Claude Code reads `.claude/skills/` and does not look in `.agents/skills/`. |
| `copilot` | `.github/copilot-instructions.md`, `.github/instructions/` | `applyTo` glob attachment is passive, which no skill loader offers. |

```bash
./install.sh /path/to/project --adapters claude
```

Both write **pointers**, never a second copy: an adapter file carries the frontmatter
its tool needs to discover the standard, and a one-line body telling it to read
`.agents/skills/<name>/SKILL.md`. Copilot's glob files cover only the standards that
declare natural globs; the rest are listed by path in the repo-wide file.

Skipping the `claude` adapter is not a loss of coverage — Claude Code then reads
`AGENTS.md` and opens the path from its table, the same as any tool without a
loader. The adapter buys model-decided activation from the description, at the cost
of a `.claude/` directory in the repository.

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

## Upgrading an existing install

`--force` rewrites the files the current version produces. It does not know about
files an *earlier* version produced, so an install made before a layout change ends
up holding both. `--upgrade` handles the whole transition:

```bash
./install.sh /path/to/project --upgrade
```

It reads the install rather than asking you about it — the adapter set from the
directories present, the stack set from the stamp — regenerates everything at the
current version, and then removes what is left over:

```
Upgrading: /path/to/project
Adapters kept: claude,copilot
Stacks kept:   dotnet

46 file(s) written, 0 skipped.

Left over from an earlier layout, to remove:
  - /path/to/project/standards/code-quality.md
  - /path/to/project/.cursor/rules/code-quality.mdc
Remove these 37 file(s)? [y/N]
```

Three properties make it safe to run on a repository you care about:

- **It only touches directories it writes** — `standards/`, `.agents/skills/`,
  `.claude/skills/`, `.cursor/rules/`, `.github/instructions/`, and the user-scope
  equivalents. Nothing outside them is even considered.
- **Inside those, it only removes names that came from `standards/`.** A skill or
  rule you wrote yourself lives in the same directory and survives untouched; it is
  reported under *not generated by it* so you can see the decision.
- **It asks before deleting**, and `--dry-run` prints the whole plan without
  writing or removing anything. `--yes` skips the prompt, as does a non-interactive
  shell, so CI does not hang.

Empty directories are cleaned up afterwards, so a retired adapter's directory
disappears — unless something of yours is still in it.

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
| `project-planning` | The project plan: a `plan.md` overview indexing one source-of-truth document per section in `docs/`. Delivery phases in `task.md`, one task document per phase in `tasks/`, bugs in `tasks/bugs.md`. Describe a new project through conversation, keep it current as work lands, revision tables. |
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

`_core.md` holds the eight non-negotiables. It is injected inline into `AGENTS.md`
and never becomes a skill of its own — a rule that applies only once loaded is not a
non-negotiable.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the frontmatter schema, adding a tool or
stack, and the test suite.
