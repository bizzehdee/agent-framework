---
name: default-stacks
description: Suggested default language and framework per project type, offered as a recommendation during stack selection, never enforced. USE FOR recommending a stack for a new or greenfield project, suggesting a language or framework for a CLI tool, HTTP API, web frontend, mobile app, desktop app, game, data pipeline, or library, or answering what stack to start with. DO NOT USE FOR a project that already has a stack - see existing-project-conventions. DO NOT USE FOR writing the plan.md Stack section itself - see project-planning.
globs:
stack: any
---

# Default stack suggestions

## A suggestion, not a policy

This standard offers a default, not a mandate. The user's stated preference,
existing team skills, or a repository's established stack always win
([[existing-project-conventions]]). Never block, warn against, or relitigate a
stack the user has already chosen. Offer the default once, as one option among
several, and move on the moment they pick.

## Order of checks

1. **Existing stack** — a `*.csproj`, `package.json`, `pyproject.toml`, or
   equivalent marker already present means the stack is decided. Do not offer an
   alternative. Detail: [[existing-project-conventions]].
2. **Stated preference** — the user names a language, ecosystem, or constraint
   (team skills, target platform, existing internal libraries). Default within
   that constraint rather than the table below.
3. **No constraint stated** — offer the table's default as the recommended
   option alongside one or two credible alternatives, and let the user choose.

## Defaults by project type

| Project type | Recommended default | Credible alternatives | Why the default |
|---|---|---|---|
| HTTP/REST API, web, SaaS, or server backend | C# + ASP.NET Core (MVC) | Node.js/TypeScript + Fastify; Python + FastAPI | Strong typing, mature tooling, team default for server-side work |
| CLI tool | Go | Python + Typer; C# + System.CommandLine | Single static binary, fast startup, easy cross-compilation |
| Web frontend (SPA) | Angular + Bootstrap | React; Vue | Batteries-included framework, consistent structure across a team |
| Full-stack web app | C# + ASP.NET Core (MVC) + Angular | Django + HTMX | Server-side default carries through; one less language boundary |
| Mobile app (cross-platform) | .NET MAUI | React Native; Flutter | Reuses C#/.NET skills, native performance where needed |
| Desktop app | .NET (Avalonia or WPF) | Electron + TypeScript | Native performance without a bundled browser runtime |
| 2D game, cross-platform incl. web/HTML5 | Phaser + Capacitor | Unity (C#); Godot | Single JS/TS codebase ships to web, iOS, and Android |
| 2D game, no web requirement | Godot | Unity (C#) | Open source, lighter weight than Unity for small teams |
| 3D game | Unity, latest LTS release (C#) | Unreal (C++); Godot | Mature 3D pipeline, asset store, broad platform support |
| Embedded / firmware | C, portable across Clang, GCC, and MSVC | C++ where the platform SDK requires it | Avoids compiler-specific extensions; keeps the target toolchain swappable |
| Data pipeline / ETL / batch job | Python | C# batch console app | Ecosystem depth: pandas, pyarrow, orchestration libraries |
| Data science / ML prototype | Python (Jupyter, pandas, scikit-learn or PyTorch) | R | De facto ecosystem standard, widest library support |
| Browser extension | TypeScript, WebExtensions API | — | Only realistic cross-browser option |
| Static site | Raw HTML/CSS/JS, or SCSS + TypeScript with a build pipeline | Astro; Hugo | No framework runtime or server needed for content that doesn't warrant one |
| Library/package | Match the language of its primary consumer | — | A library serves callers; it does not choose for them |
| Real-time/streaming service | C# | Go | Server-side default carries through; mature concurrency primitives |

Treat this table as a starting point, not an exhaustive catalogue. When a project
type is not listed, reason from the closest row and say so, rather than
inventing a confident-sounding default for an unlisted case. Rust is
deliberately absent from every row above — it is not this framework's default
or alternative for any project type.

## ASP.NET Core specifics

Wherever the table's default is ASP.NET Core:

- Use MVC controllers, never Minimal APIs.
- Use a full class-based `Startup`/`Program.cs` (explicit `Program` class with a
  `Main` method and a startup class wiring services and middleware), never the
  minimal top-level-statements `Program.cs` the SDK templates generate by
  default.

## Offering it

- Ask about platform, deployment target, and team constraints before naming a
  default — the table's "why" column is the reasoning to state, not a script to
  recite unchanged.
- Present the default and its alternatives as options, marking the table's
  choice recommended; do not present it as the only option.
- Record the chosen stack, and the reason, in `plan.md`'s Stack section once
  decided ([[project-planning]]). This standard only supplies the suggestion;
  it does not own where the decision is written down.

## Checklist

- [ ] Checked for an existing stack before suggesting one.
- [ ] Any stated user preference or constraint took priority over the table.
- [ ] Default offered alongside alternatives, not as the only option.
- [ ] Chosen stack and reason hand off to `plan.md`'s Stack section.
