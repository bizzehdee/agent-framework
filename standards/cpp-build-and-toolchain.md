---
name: cpp-build-and-toolchain
description: C and C++ build discipline - target-based CMake with no global flags, a declared language standard with extensions off, presets as the single build entry point, dependencies pinned to an exact version or hash, and a compile database for tooling. USE FOR setting up or modifying a C or C++ build, editing CMakeLists.txt, CMakePresets.json, a Meson or MSBuild project, adding a library, executable, or compile option, adding or updating a C or C++ dependency, or writing CI build steps for a C or C++ project. DO NOT USE FOR which warnings and sanitisers to enable - see memory-and-resource-safety. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management.
globs: **/CMakeLists.txt,**/*.cmake,**/CMakePresets.json,**/meson.build,**/vcpkg.json,**/conanfile.*
stack: c-cpp
---

# C and C++ build and toolchain

Use the build system the repository already has
([[existing-project-conventions]]). The CMake rules below apply where the
project uses CMake; the rest apply to any build system.

## Targets, not globals

- Every option, definition, include path, and dependency is attached to a
  target: `target_compile_options`, `target_compile_definitions`,
  `target_include_directories`, `target_link_libraries`. Never
  `add_compile_options`, `add_definitions`, `include_directories`, or
  `link_libraries`, and never an edit to `CMAKE_CXX_FLAGS`.
- State the visibility of each: `PRIVATE` for what only the target needs,
  `PUBLIC` for what its headers expose, `INTERFACE` for what only consumers
  need. A wrong `PUBLIC` leaks a dependency to every consumer.
- List source files explicitly. `file(GLOB ...)` does not re-run when a file is
  added, so the build silently goes stale.
- Never build in the source tree. Build output goes in a directory that is
  ignored by version control.

## Language standard

- Declare the standard on the target with `target_compile_features` or the
  `CXX_STANDARD` property, with `CXX_STANDARD_REQUIRED ON` and
  `CXX_EXTENSIONS OFF`. An undeclared standard is whatever the compiler
  defaults to, which differs between machines.
- Use only language and library features of the declared standard that every
  compiler the project supports implements. Raising the standard is its own
  change, approved by the user.

## One way to build

- `CMakePresets.json`, or the build system's equivalent, holds every supported
  configuration. CI and developers build with the same preset; a CI-only flag
  set is a build nobody can reproduce.
- The warning and sanitiser configurations required by
  [[memory-and-resource-safety]] are presets, not instructions in a README.
- Export a compile database (`CMAKE_EXPORT_COMPILE_COMMANDS`), so clang-tidy
  and editors see the real flags.
- Where the repository has a `.clang-format` or `.clang-tidy`, new code passes
  both. Never reformat code you did not otherwise change ([[code-quality]]).

## Dependencies

- A dependency comes through the mechanism the repository already uses: vcpkg
  manifest, Conan, `FetchContent`, or a vendored copy. Never mix in a second
  one without approval ([[dependency-management]]).
- Pin exactly: a vcpkg baseline, a Conan lockfile, or a `FetchContent` commit
  hash or archive with `URL_HASH`. A branch name or a bare tag is not a pin.
- Never rely on a library that happens to be installed on the build machine.
  If `find_package` needs it, the manifest or the documented setup provides it.
- A vendored dependency is not edited in place. Record its version and origin
  beside it.

## Checklist

- [ ] Every flag, definition, include path, and link is on a target with stated visibility.
- [ ] Source files listed explicitly; no in-source build.
- [ ] Language standard declared and required, extensions off.
- [ ] CI and local builds use the same preset.
- [ ] Every dependency pinned to an exact version or hash, through the repository's existing mechanism.
