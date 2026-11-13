---
name: developing-on-windows
description: Working on a Windows development machine - establishing which shell a command runs in, PowerShell syntax and its differences from POSIX shells, path and quoting rules, line endings and encoding of files you write, locked files, long paths, native tools instead of assumed Unix ones, and never changing system configuration unasked. USE FOR running commands, scripts, builds, or tests on Windows, writing a PowerShell or batch script, choosing between PowerShell, cmd, Git Bash, and WSL, installing a tool on Windows, or diagnosing a command not found, a path or quoting error, an access-denied or file-in-use error, or an execution-policy block. DO NOT USE FOR making committed code portable across systems - see platform-agnostic-development. DO NOT USE FOR working on Linux - see developing-on-linux.
globs: **/*.ps1,**/*.psm1,**/*.psd1,**/*.bat,**/*.cmd
stack: any
---

# Developing on Windows

What you commit still follows [[platform-agnostic-development]]. This
standard covers operating the machine.

## Know your shell

- Before running a command, establish which shell it will run in: PowerShell
  7 (`pwsh`), Windows PowerShell 5.1 (`powershell`), `cmd`, Git Bash, or WSL.
  Each has different syntax, quoting, and path rules, and a command written
  for one fails or misbehaves in another.
- Use the shell the project's scripts are written for
  ([[existing-project-conventions]]). Do not run a `.sh` script through Git
  Bash when a `.ps1` equivalent exists.
- WSL is a separate Linux machine: its own file system, tools, and
  environment. Do not move between `C:\` and `/mnt/c` mid-task, and do not
  run a Windows build from inside WSL or the reverse.

## PowerShell

- Unix commands are not there. `grep`, `sed`, `awk`, `head`, `tail`, `touch`,
  `which`, `rm -rf`, and `export` either do not exist or are aliases with
  different parameters. Use the cmdlets: `Select-String`, `Get-Content
  -TotalCount` and `-Tail`, `Get-Command`, `Remove-Item -Recurse -Force`,
  `$env:NAME = 'value'`.
- `curl` and `wget` are aliases for `Invoke-WebRequest` in Windows
  PowerShell 5.1. Call `curl.exe` when you mean curl.
- `&&` and `||` exist only in PowerShell 7. In 5.1, test `$LASTEXITCODE` or
  `$?`.
- A native program's failure does not stop a script. Check `$LASTEXITCODE`
  after each one that matters, and set `$ErrorActionPreference = 'Stop'` for
  cmdlet errors.
- Quote with single quotes for a literal and double quotes for
  interpolation. The escape character is the backtick, not the backslash.
- Call a program whose path has spaces with the call operator:
  `& "C:\Program Files\App\app.exe" arg`.
- The pipeline carries objects, not text. Do not parse formatted table
  output; select the properties.
- Never use an interactive cmdlet in automation: `Read-Host`,
  `Get-Credential`, `pause`, or anything that waits for a confirmation
  prompt.
- Do not change the execution policy for the machine or the user. Run one
  script with `-ExecutionPolicy Bypass` on the `pwsh -File` command when that
  is needed, and say so.

## Files and paths

- Quote every path. Spaces are normal: `C:\Program Files`, `C:\Users\First
  Last`.
- Files you write are UTF-8 without a byte order mark, with the line endings
  the repository's `.gitattributes` asks for. Windows PowerShell 5.1 writes
  UTF-16 from `>` and `Out-File` and adds a byte order mark from
  `Set-Content -Encoding UTF8`: state the encoding, or use PowerShell 7.
- The file system is case-insensitive but case-preserving. A reference with
  the wrong case works here and fails on Linux, so match the case exactly.
  Renaming a file only by case needs `git mv` in two steps.
- An open file cannot be deleted, moved, or overwritten. An "access denied"
  or "in use" error usually means a running process holds it: a build
  server, a test host, an editor, a dev server. Find and stop that process by
  PID ([[process-control]]); do not retry in a loop.
- Paths over 260 characters fail in many tools. Work from a short root
  directory rather than changing the system setting.
- Never write to `C:\Windows`, `C:\Program Files`, or the registry's
  machine hive. Use the user profile and the temp directory.

## Tools and system state

- Check that a tool exists (`Get-Command name`) before using it, and prefer
  the one the project pins. Do not install software, globally or otherwise,
  without approval; when approved, use the package manager the user already
  uses (`winget`, `scoop`, `choco`) ([[dependency-management]]).
- Never require elevation, and never work around a missing permission by
  running as administrator. If a step needs it, stop and say which step and
  why.
- Never change the persistent `PATH`, environment variables, registry,
  services, firewall, Defender exclusions, or execution policy as a side
  effect. Set what you need for the current process only
  ([[secure-engineering]]).
- A new entry on `PATH` is not visible to a shell that was already open.
  Start a new process before concluding an install failed.

## Checklist

- [ ] The shell in use is known, and every command is written in that shell's syntax.
- [ ] No Unix command or alias assumed in PowerShell.
- [ ] Native program failures checked through `$LASTEXITCODE`.
- [ ] Every path quoted; file references match on-disk case.
- [ ] Files written as UTF-8 without a byte order mark, with the repository's line endings.
- [ ] A locked file is resolved by finding the process that holds it, not by retrying.
- [ ] Nothing installed, elevated, or changed in system or user configuration without approval.
