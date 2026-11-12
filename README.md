# Agent instruction framework

Portable engineering standards for AI coding agents. Every rule has one source,
and an install adds two entries to your repository.

## Quick install

Download a package from the
[latest release](https://github.com/bizzehdee/agent-framework/releases/latest)
and extract it into your project's root directory. You do not need to clone
this repository or run the installer. Each package holds exactly what the
installer writes, with no wrapping folder.

| Package | Use it when | Adds |
|---|---|---|
| `agent-framework-X.Y.Z-generic.zip` | Codex, Cursor, Copilot, OpenCode, Gemini CLI, or any tool that reads `AGENTS.md` | `AGENTS.md` + `.agents/skills/` |
| `agent-framework-X.Y.Z-claude.zip` | Claude Code | the generic contents + `.claude/skills/` |
| `agent-framework-X.Y.Z-generic-lite.zip` | a local model or a small context window | a single `AGENTS.md` with the core rules |

With the GitHub CLI, from your project's root:

```bash
gh release download --repo bizzehdee/agent-framework --pattern '*-generic.zip'
```

```bash
unzip agent-framework-*-generic.zip
```

On Windows, extract with `Expand-Archive agent-framework-*-generic.zip .` instead.

If you run a local model, or any model with a small context window, use the
`generic-lite` package. The full packages rely on the model loading a standard
on demand when its trigger matches, which small models (9B to 12B, or a
27B-class MoE with a 128k window) do not do reliably. Lite puts the core rules
in one always-on `AGENTS.md` of roughly 4k tokens, with nothing else to load.
It carries no language or framework rules; to add them, run the installer with
`--lite=LIST` as described under [Lite](#lite-small-local-models).

The full packages hold the standards for every stack. For an install filtered to
your project's stacks, or to update an existing install, use the
[installer](#install).

## What an install adds

```
my-repo/
  AGENTS.md                       always-on rules + the standards trigger table
  .agents/skills/<name>/SKILL.md  one skill per standard, loaded on demand
```

The install uses two open standards and holds one copy of every rule.
[`AGENTS.md`](https://agents.md) is read natively by Codex, Cursor, Copilot,
Claude Code, Gemini CLI, Aider, Windsurf, Zed and 20+ others.
[`.agents/skills/`](https://agentskills.io) is the vendor-neutral Agent Skills
location, which Codex, Cursor, Copilot/VS Code and OpenCode load natively. A
tool with a skill loader loads each standard on demand. A tool without one
reads `AGENTS.md` and opens the path from its trigger table.

A default install adds no `.cursor/` or `.github/` directory, and no second
copy of the prose.

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
offers the optional adapters. The default is none, so pressing Enter gives the
two-entry install.

To migrate an install made by an earlier version, see
[Upgrading an existing install](#upgrading-an-existing-install).

`--check` and `--upgrade` also work on files extracted from a
[release package](#quick-install), as on any install.

| Flag | Effect |
|---|---|
| `--stacks LIST` / `-Stacks` | Which stacks to install. Default: detected. |
| `--adapters LIST` / `-Adapters` | Add tool-specific directories. Default: none. |
| `--lite` / `-Lite` | One always-on `AGENTS.md` of core rules for small local models. No skills tree, no adapters, no stacks. |
| `--lite=LIST` / `-Lite -Stacks LIST` | The same, plus the standards of the listed stacks. |
| `--check` / `-Check` | Report whether an install is current. Writes nothing. |
| `--upgrade` / `-Upgrade` | Migrate an existing install to the current layout. Implies `--force`. |
| `--yes` / `-Yes` | Accept defaults, no prompt. |
| `--force` / `-Force` | Overwrite existing files (otherwise skipped). |
| `--dry-run` / `-DryRun` | Print the plan without writing. |

When stdin is not a terminal the defaults are used without prompting, so CI never
hangs.

### Globally

A user-level install applies the standards to every project and adds no files
to any repository:

```bash
./install.sh --user
```

| Destination | Serves |
|---|---|
| `~/.agents/skills/` | Codex, Cursor, Copilot/VS Code, OpenCode (always written) |
| `~/.claude/CLAUDE.md` + `~/.claude/skills/` | Claude Code, when detected |
| `~/.codex/AGENTS.md` | Codex, when detected |

One skills tree serves every tool that reads the user-level Agent Skills location.
A user install includes every stack, because it serves all your projects. The
descriptions are stack-scoped, so a .NET standard will not trigger in a Python
project.

### Lite: small local models

The standard layout assumes a model that loads a skill when its trigger
matches. A small local model (9B to 12B dense, or a 27B-class MoE, with a 128k
window) cannot be relied on to do that, and does better with fewer, blunter
words. `--lite` installs one always-on file instead:

```bash
./install.sh /path/to/project --lite
```

It writes a single `AGENTS.md` holding the core rules: the ten non-negotiables
plus the checklist of each universal standard as imperative rules, roughly 4k
tokens. No language or framework standard is included, and a detected stack is
not added. Name the stacks you want:

```bash
./install.sh /path/to/project --lite=dotnet,unreal
```

```powershell
./install.ps1 /path/to/project -Lite -Stacks dotnet,unreal
```

`--lite=LIST` is the same as `--lite --stacks LIST`, and `--lite=all` includes
every stack at roughly 8k tokens. A lite install has
no skills tree, and the installer refuses adapters with it. `--check` and
`--upgrade` read the mode from the stamp, so a lite install stays lite.
`--upgrade --lite` converts a full install to the core rules and prunes the
skills tree; `--upgrade --lite=LIST` keeps the stacks you name.

## Stack scoping

A standard declares `stack:` in its frontmatter. `any` installs everywhere; a named
stack installs only into matching projects, so a Python repo never receives .NET
rules.

Detection looks for marker files up to three levels deep:

| Marker files | Stack |
|---|---|
| `*.csproj`, `*.sln`, `global.json` | `dotnet` |
| `pyproject.toml`, `setup.py`, `requirements.txt` | `python` |
| `Cargo.toml` | `rust` |
| `CMakeLists.txt`, `*.vcxproj` | `c-cpp` |
| `package.json` | `node` |
| `go.mod` | `go` |
| `project.godot` | `godot` |
| `*.uproject`, `*.uplugin` | `unreal` |

A Godot C# project also has a `.csproj`, so it receives both `godot` and
`dotnet`. An Unreal project receives `unreal` alone: the `.sln` and `.vcxproj`
files Unreal generates do not count, and neither does anything under
`Intermediate/`. The general `c-cpp` standards are left out on purpose, because
Unreal garbage-collects its objects and bans exceptions and the standard
containers. Override detection with `--stacks`, or pass `--stacks any` for the
universal standards only.

When no marker is found, the project type is unknown, and the installer asks
which stacks apply. With `-y`, or when it is not run from a terminal, it
installs the universal standards only and says so.

## Optional adapters

Adapters are off unless you request them. Every other tool already reads
`.agents/skills/` or `AGENTS.md`.

| Adapter | Writes | Why it exists |
|---|---|---|
| `claude` | `.claude/skills/<name>/SKILL.md` | Claude Code reads `.claude/skills/` and does not look in `.agents/skills/`. |
| `copilot` | `.github/copilot-instructions.md`, `.github/instructions/` | `applyTo` glob attachment is passive, which no skill loader offers. |
| `hooks` | `.githooks/pre-commit` | Turns the `no-hardcodes` gate into a real git hook, so human commits meet the same gate agents apply. |

```bash
./install.sh /path/to/project --adapters claude
```

`claude` and `copilot` write pointers. An adapter file carries the frontmatter
its tool needs to discover the standard, and a one-line body telling it to read
`.agents/skills/<name>/SKILL.md`, so no adapter file repeats a standard's text.
Copilot's glob files cover only the standards that declare natural globs; the
rest are listed by path in the repo-wide file.

`hooks` writes a POSIX sh pre-commit hook. The hook scans the staged diff's
added lines for secrets and environment-specific values and blocks the commit
on a hit. It reports the file, line, and category of each finding, and does not
print the value. Enable it per clone:

```bash
git config core.hooksPath .githooks
```

Without the `claude` adapter, Claude Code still has every standard: it reads
`AGENTS.md` and opens the path from its table, the same as any tool without a
loader. The adapter adds model-decided activation from the description, at the
cost of a `.claude/` directory in the repository.

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
files an earlier version produced, so an install made before a layout change ends
up holding both. `--upgrade` handles the whole transition:

```bash
./install.sh /path/to/project --upgrade
```

It asks you nothing about the install. It reads the adapter set from the
directories present and the stack set from the stamp, regenerates everything at
the current version, and then removes what is left over:

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

The upgrade limits what it can remove:

- It considers only the directories the installer writes: `standards/`,
  `.agents/skills/`, `.claude/skills/`, `.cursor/rules/`, `.github/instructions/`,
  `.githooks/`, and the user-scope equivalents.
- Inside those directories, it removes only names that came from `standards/`.
  A skill or rule you wrote yourself lives in the same directory and survives
  untouched. The upgrade lists it under "not generated by it".
- It asks before deleting. `--dry-run` prints the whole plan without writing or
  removing anything. `--yes` skips the prompt, as does a non-interactive shell,
  so CI does not hang.

The upgrade then removes empty directories, so a retired adapter's directory
disappears unless it still holds something of yours.

## Requirements

`install.sh` / `build.sh` need POSIX `/bin/sh` plus `awk`, `sed`, `find` (dash, bash,
or Git Bash). `install.ps1` / `build.ps1` need PowerShell 7+. Installed projects need
neither, because the output is plain Markdown.

## The standards

Universal (`stack: any`):

| Standard | Covers |
|---|---|
| `secure-engineering` | Security priority ordering, secrets, boundary validation, privacy. |
| `existing-project-conventions` | Repository conventions outrank these defaults. |
| `elimination-debugging` | Candidate enumeration, the elimination report format, evidence before decisions. |
| `error-handling` | Return expected failures; exceptions are for exceptional cases only. |
| `testing-standards` | Coverage target, definition of done, mocking limits, determinism. |
| `code-quality` | One purpose per file and class, no catch-all utilities, SOLID and DRY, abstraction timing, comments, dead code. |
| `architecture-principles` | Vertical slices, composition, no speculative patterns. |
| `git-and-commits` | Per-task commits in a series, otherwise on request; message format. |
| `no-hardcodes` | Pre-commit gate: blocks secrets and environment-specific values. |
| `dependency-management` | Licence, supply-chain and lockfile discipline. |
| `research-provenance` | Check order before web search, archiving, indexing, and extracts. |
| `project-planning` | The project plan: a `plan.md` overview indexing one source-of-truth document per section in `docs/`. Describe a new project through conversation, keep it current as features land, revision tables. |
| `default-stacks` | Suggested default language and framework per project type, offered as a recommendation during stack selection, never enforced. |
| `canonical-documents` | Documents declared an immutable source of truth (palette, design guide, core loop): work in scope must conform exactly, edits need double sign-off. |
| `task-tracking` | Delivery phases in `task.md`, one task document per phase in `tasks/`, bugs in `tasks/bugs.md`, a spec in `specs/` before any work on a task or bug, and a summary in `summaries/`, naming every deviation, when it ends. Feature requests join a phase; bugs join the bug list. |
| `learnings` | Durable project knowledge in `.learnings/`: record what a task teaches, consult it first. |
| `observability-standards` | Structured logging, what to log, health checks. |
| `performance-discipline` | Measure before optimising; defects to avoid by default. |
| `technical-writing` | Controlled style for human- and machine-facing prose. |
| `process-control` | Waiting on and killing processes by PID, never by a command-line pattern the matching command itself contains. |

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

`stack: node`:

| Standard | Covers |
|---|---|
| `node-packaging` | One package manager per repo, committed lockfiles, exact installs in CI, declared engines, no unpinned npx. |

`stack: go`:

| Standard | Covers |
|---|---|
| `go-modules` | go.mod/go.sum as the record, tidy on every change, toolchain pinning, vendoring policy, gofmt and vet. |

`stack: rust`:

| Standard | Covers |
|---|---|
| `rust-cargo` | Manifest and lockfile discipline, pinned edition, rustfmt and clippy as done, additive features, justified unsafe. |

`stack: c-cpp`:

| Standard | Covers |
|---|---|
| `memory-and-resource-safety` | RAII and ownership, bounded buffers, undefined behaviour, warnings as errors, sanitisers. |
| `cpp-build-and-toolchain` | Target-based CMake, a declared language standard, presets as the one way to build, pinned dependencies. |
| `cpp-undefined-behaviour` | Dangling references and lambda captures, moved-from objects, integer conversions, casts and type punning, initialisation order. |
| `cpp-headers-and-interfaces` | Self-contained headers, the one definition rule, rule of zero or five, `explicit`, const-correctness, parameter passing. |
| `cpp-concurrency` | Guarded shared state, RAII locks in one order, joined threads with a stop path, atomics, ThreadSanitizer. |

`stack: godot` (Godot 4, GDScript and C#):

| Standard | Covers |
|---|---|
| `godot-project-files` | Engine version check, hand-editing `.tscn`/`.tres`, `.uid` and `.import` sidecars, export secrets, headless validation. |
| `godot-scripting` | Static typing, naming and member order, Godot 4 signals, exports, C# partial classes and generated names. |
| `godot-scene-architecture` | Call down and signal up, autoload discipline, shared resources, the frame loop, main-thread rule, freeing, multiplayer authority. |

`stack: unreal` (Unreal Engine C++):

| Standard | Covers |
|---|---|
| `unreal-project-files` | Binary assets an agent cannot edit, what to commit, LFS and locking, core redirects, config ini files, building to validate. |
| `unreal-cpp-conventions` | Engine version check, type prefixes, reflection macros, engine containers and strings, no exceptions or RTTI, logging, `Build.cs` dependencies. |
| `unreal-object-lifetime` | `UPROPERTY` on every stored object pointer, weak and soft references, `NewObject` over `new`, validity checks. |
| `unreal-gameplay-architecture` | The C++ and Blueprint split, framework class roles, components and subsystems, tick off by default, lifecycle. |
| `unreal-replication` | Server authority, replicated properties and `OnRep`, RPC kinds, validating everything a client sends. |

`_core.md` holds the ten non-negotiables. The build injects it inline into
`AGENTS.md` and never emits it as a skill, because these rules must apply before
any skill is loaded.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the frontmatter schema, adding a tool or
stack, and the test suite.
