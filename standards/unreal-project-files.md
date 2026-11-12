---
name: unreal-project-files
description: Unreal Engine project files handled without the editor - binary assets an agent cannot edit or merge, what to commit and ignore, Git LFS and file locking, renaming or moving classes and assets with redirects, the config ini hierarchy, and validating a change by building and running headless. USE FOR creating, moving, renaming, or deleting an Unreal class, module, plugin, or asset. USE FOR editing a .uproject, .uplugin, Config ini file, .gitignore, or .gitattributes in an Unreal project. USE FOR setting up Unreal CI, a build script, or an automation test run. DO NOT USE FOR how Unreal C++ is written - see unreal-cpp-conventions. DO NOT USE FOR where gameplay logic lives - see unreal-gameplay-architecture.
globs: **/*.uproject,**/*.uplugin,**/Config/*.ini,**/*.uasset,**/*.umap
stack: unreal
---

# Unreal project files

## Binary assets

- `.uasset` and `.umap` files are binary and owned by the editor. Never
  create, edit, or resolve a merge conflict in one. Blueprints, materials,
  levels, data assets, and input assets are all `.uasset` files.
- When a task needs an asset created or changed, do the C++ side, then tell
  the user exactly what to do in the editor: which asset, which property,
  which value. Do not report the task done until they confirm.
- Never claim to have verified Blueprint logic. You cannot read it.

## Version control

- Commit `Source/`, `Config/`, `Content/`, `Plugins/`, and the `.uproject`.
- Never commit `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`,
  `.vs/`, or the generated `.sln` and `.vcxproj` files. They are rebuilt from
  the sources, and `Saved/` holds local logs and credentials
  ([[secure-engineering]]).
- Binary assets go through Git LFS, or the repository's existing equivalent,
  declared in `.gitattributes` ([[git-and-commits]]). A binary cannot be
  merged, so where the repository uses file locking, lock an asset before a
  user edits it.
- Do not move a file between LFS and plain git, and do not add an LFS pattern,
  without approval.

## Renaming and moving

- Renaming or moving a reflected C++ class, struct, enum, or property breaks
  every asset that saved the old name. Add a core redirect to
  `Config/DefaultEngine.ini` under `[CoreRedirects]` in the same change, and
  say so in the report.
- Never move or rename an asset on disk. Only the editor can update the
  references and leave a redirector. Ask the user to do it.
- Deleting a C++ class that a Blueprint derives from corrupts the Blueprint.
  Search `Content/` for the class name before deleting, and stop if anything
  may depend on it.
- A new module is declared in the `.uproject` or `.uplugin`, has its own
  `Build.cs`, and is added to the targets that need it.

## Configuration

- Project settings live in `Config/Default*.ini`. Never edit files under
  `Saved/Config/`: they are per-machine overrides and are not committed.
- Edit only the keys the task needs, keep the section they belong to, and
  preserve the `+`, `-`, and `.` array prefixes exactly.
- No secret, key, or credential goes in a `Default*.ini` file or anywhere else
  in a packaged build; packaged content can be extracted ([[no-hardcodes]]).
- Change `.uproject` and `.uplugin` files as valid JSON, touching only the
  entries the task needs.

## Validate

The editor is how a human sees a broken project; without it, build and run.

- After changing C++, a `Build.cs`, a `Target.cs`, or a module list, build the
  editor target with the project's own script or UnrealBuildTool and read the
  output. A reflection error from UnrealHeaderTool is a build failure.
- Run the project's automation tests headless where it has them
  (`-ExecCmds="Automation RunTests ..." -unattended -nullrhi -nopause`), and
  treat an `Error:` line in the log as a failure ([[testing-standards]]).
- If no engine is installed where you are running, say that the change is
  unbuilt and untested. Do not describe it as working.

## Checklist

- [ ] No `.uasset` or `.umap` created, edited, moved, or merged by hand.
- [ ] Every editor step the change needs is listed for the user.
- [ ] `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, and generated project files not committed.
- [ ] Every renamed or moved reflected type has a core redirect.
- [ ] No class deleted while content may derive from it.
- [ ] Only `Config/Default*.ini` edited, with array prefixes preserved and no secrets.
- [ ] The editor target builds, or the report states the change is unbuilt.
