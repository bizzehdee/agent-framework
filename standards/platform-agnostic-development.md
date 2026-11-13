---
name: platform-agnostic-development
description: Writing code, scripts, and repository files that behave the same on Windows, Linux, and macOS - paths built with the path API, case-exact file names, line endings fixed in .gitattributes, explicit text encoding, no assumed shell, locale, time zone, or installed tool, and a CI matrix that proves it. USE FOR writing code or a script that touches the file system, paths, environment variables, processes, line endings, text encoding, time zones, or locale, adding a build, setup, or CI script, naming or renaming a file, editing .gitattributes or .editorconfig, or diagnosing something that works on one machine or operating system and fails on another. DO NOT USE FOR working on a Windows machine yourself - see developing-on-windows. DO NOT USE FOR working on a Linux machine yourself - see developing-on-linux.
globs: **/.gitattributes,**/.editorconfig
stack: any
---

# Platform-agnostic development

Unless the project states a single target platform, everything committed
works on Windows, Linux, and macOS. Where it does state one, follow it
([[existing-project-conventions]]), and do not add support for the others
unasked.

## Paths and file names

- Build a path with the language's path API (`Path.Combine`, `os.path.join`
  or `pathlib`, `path.join`, `filepath.Join`). Never concatenate with `/` or
  `\`, and never split on one.
- No absolute path and no home, temp, or drive location as a literal. Ask the
  platform: the temp directory API, the user-profile API, the standard
  config and data directories ([[no-hardcodes]]).
- A file is referenced with exactly the case it has on disk. A wrong case
  works on Windows and macOS and fails on Linux.
- Never create two names in one directory that differ only by case.
- File names avoid what any platform rejects: `< > : " / \ | ? *`, a trailing
  dot or space, and the reserved names `CON`, `PRN`, `AUX`, `NUL`, `COM1` to
  `COM9`, `LPT1` to `LPT9`, with or without an extension.
- Keep paths short. Deep nesting breaks the 260-character limit on Windows
  machines that have not lifted it.
- Do not rely on a symbolic link, a hard link, or a POSIX permission bit
  existing. Where one is needed, detect the failure and say what to do.

## Text

- Line endings are decided by `.gitattributes`, not by each machine: text
  files normalised (`* text=auto`), with `eol=lf` for shell scripts and
  `eol=crlf` only for files a Windows tool requires. Mark binaries `binary`.
  A shell script with CRLF endings fails with an error that does not mention
  line endings.
- Code that reads text accepts both `\n` and `\r\n`. Code that writes a file
  a tool will parse writes one, stated.
- State the encoding on every read and write of text: UTF-8, without a byte
  order mark unless a consumer needs one. The platform default differs.
- Compare and sort with an explicit culture or ordinal rule, and format
  numbers and dates for machines with the invariant culture. A comma decimal
  separator on one machine breaks parsing on another.
- Store and exchange times in UTC with an offset. Never depend on the
  machine's time zone.

## Processes and environment

- Run a program by passing an argument list to the process API. Never build a
  shell command string, which is quoted differently by every shell
  ([[secure-engineering]]).
- Do not assume a shell. Automation that must run everywhere is written in
  the project's own language or task runner, or provided once per platform,
  as this repository does with `.sh` and `.ps1`
  ([[existing-project-conventions]]).
- Do not assume a tool is installed: `sed`, `grep`, `curl`, `make`, `bash`,
  PowerShell. Declare what a script needs, check for it, and fail with a
  message that names it.
- A POSIX script targets `sh`, not bash, unless its shebang says bash, and
  uses `#!/usr/bin/env` rather than a fixed interpreter path.
- Environment variable names are treated as case-sensitive and written in one
  case. Join path lists with the platform's separator constant.
- Do not assume an executable's extension, and do not assume the current
  directory is on the search path.
- Exit with `0` for success and a small positive number for failure. Do not
  rely on a signal: Windows has no `SIGTERM` or `SIGHUP`
  ([[process-control]]).
- A file that is open cannot be deleted or renamed on Windows. Close handles
  before moving or deleting, and do not rely on replacing a running
  executable.

## Proof

- Behaviour that differs by platform sits behind one small abstraction, with
  the platform check in one place, not scattered conditionals.
- CI runs the tests on every platform the project supports. A platform not
  in the matrix is not supported, whatever the README says
  ([[testing-standards]]).
- When you could only run something on one platform, say which, and say the
  others are unverified.

## Checklist

- [ ] Paths built with the path API; no literal separator, absolute path, or home or temp location.
- [ ] Every file reference matches the on-disk case; no names differing only by case.
- [ ] No file name that any supported platform rejects.
- [ ] `.gitattributes` fixes line endings; scripts are LF.
- [ ] Encoding stated on every text read and write; culture and time zone never implicit.
- [ ] Processes started with an argument list, not a shell string.
- [ ] No shell or tool assumed without a check and a clear failure message.
- [ ] Platform-specific behaviour isolated in one place, and CI covers each supported platform.
- [ ] The report names the platforms the change was actually run on.
