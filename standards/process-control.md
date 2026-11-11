---
name: process-control
description: Waiting on and killing processes from a shell without matching your own command - capture the PID at launch, wait and kill by PID, use a pidfile across commands, and never match a process by a command-line pattern that the matching command itself contains. USE FOR starting a background or long-running process, waiting for a process or job to finish, polling for completion, killing or stopping a process, or writing any command that uses pgrep, pkill, ps piped to grep, kill, or wait. DO NOT USE FOR diagnosing why a process hangs or crashes - see elimination-debugging. DO NOT USE FOR designing concurrency inside application code - see performance-discipline.
globs:
stack: any
---

# Process control

## Waiting on and killing processes

Never match a process by command-line pattern (`pgrep -f`, `pkill -f`, `ps | grep`) from a
shell command that contains that same pattern: the shell running the command matches itself,
so a `while pgrep -f X` loop never ends and a `pkill -f X` kills its own shell.

- Capture the PID at launch (`cmd & pid=$!`) and wait with `wait $pid` or
  `while kill -0 $pid 2>/dev/null; do sleep 5; done`. Kill by PID.
- For jobs started in an earlier command, have the launcher write a pidfile and read that.
- If a pattern match is unavoidable, match the executable name only (`pgrep -x qemu-system-x86_64`),
  or break the self-match with a bracket (`pgrep -f 'run-16[7]\.sh'`).
- Never wait on a background job with a polling loop when the harness will notify on exit:
  run the job itself as the background command.

## Checklist

- [ ] No `pgrep -f`, `pkill -f`, or `ps | grep` runs from a command that contains the pattern it matches.
- [ ] Every process to be waited on or killed has its PID captured at launch, or read from a pidfile.
- [ ] Every wait and every kill targets a PID, not a pattern.
- [ ] Any unavoidable pattern match uses the executable name only, or a bracket that breaks the self-match.
- [ ] No polling loop waits on a job the harness would report on exit.
