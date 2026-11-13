---
name: developing-on-linux
description: Working on a Linux development machine running Fedora or Ubuntu and Debian - identifying the distribution before acting, dnf versus apt and their differing package names, no sudo and no system-wide installs without approval, never touching the system Python or other distribution-owned runtimes, POSIX shell portability, file permissions, SELinux and AppArmor denials, and systemd user services. USE FOR running commands, scripts, builds, or tests on Linux, installing a tool or build dependency, writing a shell script, setting file permissions, running a container, or diagnosing a command or library not found, a permission denied error, or an SELinux or AppArmor denial. DO NOT USE FOR making committed code portable across systems - see platform-agnostic-development. DO NOT USE FOR working on Windows - see developing-on-windows.
globs: **/*.sh,**/Dockerfile,**/Containerfile
stack: any
---

# Developing on Linux

What you commit still follows [[platform-agnostic-development]]. This
standard covers operating the machine, on the Fedora family and on Ubuntu and
Debian.

## Identify the system

- Before installing anything or giving distribution-specific instructions,
  read `/etc/os-release`. `ID` and `ID_LIKE` say which family this is, and
  `VERSION_ID` which release.
- Never assume one family. Instructions you write for others cover both, or
  say which they are for.

## Packages

| | Fedora family | Ubuntu and Debian |
|---|---|---|
| Install | `dnf install` | `apt-get install` |
| Find the package that owns a file | `dnf provides '*/name'` | `apt-file search name` |
| Headers for a library | `name-devel` | `libname-dev` |
| C and C++ toolchain | `dnf group install development-tools`, or `gcc gcc-c++ make` | `build-essential` |

- Package names differ between the families: `python3-devel` and
  `python3-dev`, `openssl-devel` and `libssl-dev`. Look the name up; do not
  translate by guesswork.
- Use `apt-get`, not `apt`, in a script: `apt` is for interactive use and its
  output is not stable. Run `apt-get update` before an install in a fresh
  environment, and pass `-y` in automation.
- A missing header or library at build time means a development package is
  missing. Find the package that provides the file; do not download a header
  or build the library by hand.
- Do not add a third-party repository, PPA, COPR, or a `curl | sh` installer
  without approval ([[dependency-management]]).

## Privilege and system state

- Never run `sudo`, and never install system-wide, without approval. Say what
  the command is and why it is needed, and let the user run it or agree
  ([[secure-engineering]]).
- Prefer an install that needs no privilege: the project's own toolchain
  manager, a per-user install under the home directory, or a container.
- Never build or run the project as root, and never `chown` or `chmod`
  recursively to make an error go away.
- The distribution owns the system Python and other system runtimes. Never
  `pip install` into them, with or without `sudo`, and never pass
  `--break-system-packages`. Use a virtual environment or the project's
  environment manager.
- Never edit files under `/etc`, `/usr`, or `/opt`, or change a system
  service, as a side effect. Per-user configuration goes under
  `~/.config`, following the XDG directories.

## Shell

- Know which shell runs a script. `/bin/sh` is dash on Ubuntu and Debian and
  bash on Fedora, so a bashism in a `#!/bin/sh` script passes on Fedora and
  fails on Ubuntu. Write POSIX `sh`, or use `#!/usr/bin/env bash` and write
  bash.
- Start a script with `set -eu`, and `set -o pipefail` where the shell is
  bash. Quote every expansion: `"$var"`, `"$@"`.
- Not POSIX, so not for a `sh` script: arrays, double-bracket tests,
  `function name`, `local`, `echo -e`, `source`, here strings, `$'...'`
  quoting, and `&>`.
- Use `printf` rather than `echo` for anything with an escape or a variable.
- GNU and BSD tools differ. `sed -i`, `date -d`, `readlink -f`, and
  `grep -P` are GNU forms that fail on macOS; avoid them in a script that
  must also run there.
- Never parse the output of `ls`. Use a glob or `find`.
- Wait for and stop processes by PID ([[process-control]]).

## Files and permissions

- The file system is case-sensitive. `Makefile` and `makefile` are different
  files, and an import that worked on Windows or macOS with the wrong case
  fails here.
- A script needs its executable bit, and git records it. Set it with
  `git update-index --chmod=+x` or `chmod +x` and commit the mode change.
- Never `chmod 777` anything. Give the narrowest mode that works, and `600`
  to a file holding a secret.
- Create temporary files with `mktemp`, never a fixed name under `/tmp`, and
  remove them in a `trap` on exit.
- Text files end with a newline and use LF. A CRLF script fails with
  "bad interpreter" or a syntax error that does not mention line endings.

## Mandatory access control

- Fedora enforces SELinux; Ubuntu uses AppArmor. A "permission denied" that
  the file modes do not explain is usually one of them: check the audit log
  (`ausearch -m avc -ts recent`, or `journalctl` and `dmesg` for AppArmor)
  before changing anything ([[elimination-debugging]]).
- Never disable SELinux or AppArmor, and never set SELinux permissive, to
  make something work. Fix the label or the policy, with approval.
- A bind mount into a container on an SELinux system needs the `:Z` or `:z`
  option, or the container cannot read it.
- Fedora ships Podman where Ubuntu users usually have Docker. Use the engine
  the project's scripts call, and do not assume a daemon or root.

## Services

- Use `systemctl --user` and a user unit for something that must keep
  running in a development session. Never install or enable a system unit
  without approval.
- Read logs with `journalctl`, scoped to the unit and time
  ([[observability-standards]]).

## Checklist

- [ ] Distribution identified from `/etc/os-release` before any distribution-specific step.
- [ ] Package names looked up for the family in use; instructions cover both families or name one.
- [ ] No `sudo`, system-wide install, or third-party repository without approval.
- [ ] Nothing installed into the system Python or another distribution-owned runtime.
- [ ] Each script's shebang matches the syntax it uses; a `sh` script has no bashisms.
- [ ] Executable bits committed; no `chmod 777`; secrets are mode `600`.
- [ ] Temporary files come from `mktemp` and are cleaned up.
- [ ] An unexplained denial is checked against SELinux or AppArmor, and neither is disabled.
