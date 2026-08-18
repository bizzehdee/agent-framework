# Contributing

Maintainer notes. For installing and using the framework, see [README.md](README.md).

## Layout

```
standards/*.md          Source of truth. The only files you edit.
  _core.md              Always-on rules, injected inline into every output.
  <name>.md             One standard per concern, loaded on demand.

build.ps1  build.sh     Generate into a directory.
install.ps1  install.sh Detect, then generate and copy into a destination.
test.sh                 The test suite.
```

Generated output is never committed. Everything is produced at install time.

## Editing a standard

Standards must be as concise as possible while remaining wholly unambiguous. Add
words only where they remove ambiguity.

Frontmatter is single-line `key: value` pairs, hand-parsed, so there is no YAML
dependency:

```markdown
---
name: testing-standards
description: What this covers. USE FOR <trigger>. DO NOT USE FOR <exclusion>.
globs: **/*test*,**/tests/**
stack: any
---
```

| Key | Required | Purpose |
|---|---|---|
| `name` | Yes | Must equal the filename. Becomes the skill and rule name. |
| `description` | Yes | Drives model-decided loading. |
| `globs` | No | File patterns for glob-attached adapters. Empty means agent-requested only. |
| `stack` | No | `any` (default) or a comma-separated stack list. |

Both generators validate this and fail on a mismatch, so a renamed file cannot
silently produce a broken skill.

### Writing a description

The description is the only thing a model sees when deciding whether to load a
standard. Write triggers as `USE FOR <concrete task>` and exclusions as
`DO NOT USE FOR <near miss>`, naming the standard to use instead.

The `Load when` column in `AGENTS.md` is derived from the `USE FOR` clauses, so it
cannot drift from the frontmatter. `DO NOT USE FOR` content is excluded from that
derivation, and must be: `DO NOT USE FOR` contains the literal `USE FOR`, so
matching it first turns a standard's exclusions into reasons to load it. There is a
regression test for exactly this.

## Adding a tool

A tool that reads `AGENTS.md` already works and needs no code. Add an adapter only
if the tool has its own on-demand loading mechanism.

1. Add a branch to `build.ps1` and the matching branch to `build.sh`, and add the
   name to `$KnownAdapters` / `KNOWN_ADAPTERS`.
2. Add a probe to `Find-Tool` / `detect_tool`, a label to `$ToolLabels` /
   `tool_label`, an entry to `$AdapterNotes` / `adapter_note`, and the name to
   `$candidates` / `CANDIDATES`.

## Adding a stack

Add its marker files to `Get-ProjectStacks` / `detect_stacks`, then set `stack:` on
the standards that apply.

## Cross-shell parity

The sh and PowerShell implementations must produce byte-identical output. Both emit
LF line endings, UTF-8 without a BOM, and exactly one trailing newline.

```bash
sh ./build.sh --out /tmp/a --adapters all
pwsh ./build.ps1 -OutputRoot /tmp/b -Adapters all
diff -r /tmp/a /tmp/b
```

The standards version hash must also agree, which is why it uses ordinal sorting
and strips CR before hashing.

## Tests

```bash
./test.sh
```

One suite, not one per shell: the property under test is that the two
implementations agree, so duplicating the assertions would let the copies drift.
`pwsh` is optional — tests needing it report as skipped, never as passed.

Covers parsing, source and frontmatter validation, argument rejection, default
output shape, trigger-table correctness, output hygiene, stack filtering and
detection, install idempotency, `--force`, `--dry-run`, adapter opt-in, check mode,
and cross-shell agreement.

CI runs the suite on Linux, macOS and Windows.

## Platform gotchas

- **macOS `/bin/sh` is bash 3.2.** It rejects constructs dash accepts, so a green
  local `dash -n` proves nothing about that runner. The macOS CI job is the real
  gate for shell portability. Known case: bash 3.2 mistakes the `)` of a `case`
  pattern inside `$( )` for the closing parenthesis of the command substitution, so
  never put a `case` statement inside a command substitution.
- **MSYS path conversion.** On Windows, paths passed as arguments to `pwsh` get
  translated, but a POSIX path embedded in a quoted `-Command` string does not.
  Pass paths as arguments.
- **POSIX sh has no function-local variables.** Prefix names inside functions so
  they cannot clobber a caller's loop variable.
- **`pwsh -File` does not split comma lists.** `-Adapters a,b` arrives as one
  string, so both scripts split on commas themselves.
