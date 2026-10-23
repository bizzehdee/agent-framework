---
name: godot-project-files
description: Godot 4 project files edited without the editor - confirming the engine version before writing code, hand-editing .tscn and .tres text resources safely, keeping .uid and .import sidecars with their files, what to commit and ignore, export credentials, and validating every change by running the project headless. USE FOR any first change in a Godot project. USE FOR creating, editing, moving, renaming, or deleting a scene, resource, script, or asset in a Godot project. USE FOR editing project.godot, export_presets.cfg, or a Godot .gitignore. USE FOR setting up Godot CI or a headless check. DO NOT USE FOR how scripts are written - see godot-scripting. DO NOT USE FOR how scenes and nodes communicate - see godot-scene-architecture.
globs: **/project.godot,**/*.tscn,**/*.tres,**/*.import,**/*.uid,**/export_presets.cfg
stack: godot
---

# Godot project files

## Godot 4 only

Before your first change, read `project.godot` and establish the engine version.

- `config_version=5` and a version under `config/features`, such as
  `PackedStringArray("4.3", "Forward Plus")`, mark a Godot 4 project. A C# project
  also names it in the `.csproj` SDK: `Godot.NET.Sdk/4.3.0`.
- Any other `config_version` is not Godot 4. Stop and tell the user: these
  standards cover Godot 4 only.
- Use only the API of the project's minor version. Most published Godot examples
  are Godot 3, so check every engine class, method, annotation, and signal you
  write against the class reference for that version. A Godot 3 name in a Godot 4
  project is a defect: `yield`, `export var`, `onready var`, `KinematicBody`,
  `Spatial`, `connect("signal", self, "method")`.
- Never change the engine version as a side effect. Upgrading is the user's
  decision.

## Text resources

`.tscn` scenes and `.tres` resources are text, but the editor owns their format.
When you edit one by hand:

- Keep the `[gd_scene ...]` or `[gd_resource ...]` header, and `format=3`.
- Declare every `[ext_resource]` and `[sub_resource]` once, with a unique `id`, and
  reference each only through `ExtResource("id")` or `SubResource("id")` with an
  id that exists.
- Never invent or change a `uid="uid://..."` value. Copy it from the target's
  header, `.uid` file, or `.import` file, or omit the `uid` attribute and rely on
  `path`.
- Every `res://` path must resolve to a file that exists, with matching case.
- A node's `parent` must name a node declared above it.
- Remove an `[ext_resource]` when nothing references it any more.

## Sidecar files

- `.import` files, and from Godot 4.4 `.uid` files, belong to the file they sit
  beside. Commit them. Never add them to `.gitignore`.
- Move, rename, or delete a file together with its sidecars, then update every
  `res://` path that named it in `.tscn`, `.tres`, `.gd`, `.cs`, and
  `project.godot`. Search the project for the old path before reporting the move
  done.
- Never commit `.godot/`. It is a generated cache, and it holds
  `export_credentials.cfg`.

## Exports and secrets

- `export_presets.cfg` holds no secrets and is committed.
- Passwords and encryption keys live in `.godot/export_credentials.cfg`. Never
  move them into a committed file ([[secure-engineering]]).
- An exported `.pck` can be extracted, encrypted or not. Never ship a secret,
  API key, or credential inside the game ([[no-hardcodes]]).

## Validate headless

The editor is how a human sees a broken scene; without it, run the engine.

- After changing any project file, import and run the project headless and read
  the output: `godot --headless --import`, then `godot --headless --quit`. Treat
  every `ERROR:` or `SCRIPT ERROR:` line as a failure.
- A fresh clone has no `.godot/`, so global `class_name` types are unregistered
  until an import runs. CI must import before running tests.
- In a C# project, run `dotnet build` before the headless run.
- Run the tests headless with the framework the repository already uses, such as
  GUT or gdUnit4 ([[testing-standards]]). Do not add a test framework without
  approval ([[dependency-management]]).

## Checklist

- [ ] Engine version read from `project.godot`; Godot 4 confirmed.
- [ ] Every engine API used exists in the project's minor version.
- [ ] Every hand-edited `.tscn` and `.tres` has resolving ids, paths, and parents, and no invented `uid`.
- [ ] Every moved or renamed file moved with its `.import` and `.uid`, and no reference names the old path.
- [ ] `.godot/` not committed; `.import` and `.uid` files committed.
- [ ] No secret in a committed file or in the exported game.
- [ ] Headless import and run show no `ERROR:` lines.
