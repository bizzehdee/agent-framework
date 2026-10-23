#!/bin/sh
# Generates agent instruction files from standards/*.md.
#
# POSIX sh. Functionally identical to build.ps1 and emits byte-identical output.
#
# Output is AGENTS.md plus .agents/skills/<name>/SKILL.md, one skill per
# standard. .agents/skills/ is the vendor-neutral Agent Skills location, read
# natively by Codex, Cursor, Copilot/VS Code, OpenCode and others. A tool with no
# skill loader reads AGENTS.md and opens the path from its trigger table, so
# there is exactly one copy of every standard.
#
# Adapters cover the two tools that need something else, and are off by default.
# Claude Code reads only .claude/skills/; Copilot additionally supports
# glob-attached instructions. Both emit pointers to the .agents/skills/ copy,
# never a second copy of the text.
#
# Usage:
#   ./build.sh --out DIR [options]
#
# Options:
#   --adapters LIST     Optional adapters: claude,copilot,all,none (default: none).
#   --stacks LIST       Which stacks to include: all, any, dotnet, ... (default: all).
#                       A standard with "stack: any" is always included.
#   --skills-path PATH  Where AGENTS.md and the adapters say the skills live
#                       (default: .agents/skills). A user-level install passes
#                       ~/.agents/skills, because there is no project root.
#   -h, --help          Show this help.

set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
STANDARDS_DIR="$REPO_ROOT/standards"
OUTPUT_ROOT=""
ADAPTERS="none"
STACKS="all"
SKILLS_PATH=".agents/skills"

while [ $# -gt 0 ]; do
    case "$1" in
        --out) shift; [ $# -gt 0 ] || { echo "--out needs a directory" >&2; exit 2; }; OUTPUT_ROOT="$1" ;;
        --adapters) shift; [ $# -gt 0 ] || { echo "--adapters needs a value" >&2; exit 2; }; ADAPTERS="$1" ;;
        --stacks) shift; [ $# -gt 0 ] || { echo "--stacks needs a value" >&2; exit 2; }; STACKS="$1" ;;
        --skills-path) shift; [ $# -gt 0 ] || { echo "--skills-path needs a value" >&2; exit 2; }
                       SKILLS_PATH=$(echo "$1" | sed 's|/*$||') ;;
        -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

[ -d "$STANDARDS_DIR" ] || { echo "Source directory not found: $STANDARDS_DIR" >&2; exit 1; }
[ -n "$OUTPUT_ROOT" ] || { echo "Usage: ./build.sh --out DIR [--adapters LIST]" >&2; exit 2; }

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT=$(CDPATH='' cd -- "$OUTPUT_ROOT" && pwd)

# Everything else reads .agents/skills/ natively, or falls back to the AGENTS.md
# table. Only these two need a directory of their own: Claude Code does not read
# .agents/skills/ at all, and Copilot has a glob-attach mechanism that skills do
# not cover.
KNOWN_ADAPTERS="claude copilot"

REQUESTED=$(echo "$ADAPTERS" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')
for a in $REQUESTED; do
    case " all none $KNOWN_ADAPTERS " in
        *" $a "*) ;;
        *) echo "Unknown adapter: $a" >&2
           echo "Valid: none, all, $(echo "$KNOWN_ADAPTERS" | sed 's/ /, /g')" >&2; exit 2 ;;
    esac
done

case " $REQUESTED " in
    *" all "*)  SELECTED="$KNOWN_ADAPTERS" ;;
    *" none "*) SELECTED="" ;;
    *)
        SELECTED=""
        for a in $REQUESTED; do
            case " $SELECTED " in *" $a "*) ;; *) SELECTED="$SELECTED $a" ;; esac
        done
        SELECTED=$(echo "$SELECTED" | sed 's/^ //')
        ;;
esac

has_adapter() { case " $SELECTED " in *" $1 "*) return 0 ;; *) return 1 ;; esac }

# --- Source parsing -------------------------------------------------------
# Frontmatter is hand-parsed: single-line "key: value" pairs only, so there is
# no YAML dependency. Mirrors Read-Standard in build.ps1.

# Spawns one awk per lookup, and is called several times per standard per adapter,
# so a full build costs a few hundred processes. Process creation dominates the
# runtime: roughly 29s on Windows against 2s for build.ps1, much closer on Linux
# and macOS. Cache the parsed frontmatter in shell variables if that becomes a
# problem.
frontmatter_value() {
    awk -v key="$2" '
        NR == 1 { if ($0 !~ /^---[[:space:]]*$/) { exit 1 } ; next }
        /^---[[:space:]]*$/ { exit }
        {
            i = index($0, ":")
            if (i < 2) next
            k = substr($0, 1, i - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            if (k != key) next
            v = substr($0, i + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            print v
            exit
        }
    ' "$1"
}

standard_body() {
    # Everything after the closing frontmatter delimiter, blank edges trimmed.
    awk '
        NR == 1 { next }
        !seen && /^---[[:space:]]*$/ { seen = 1; next }
        seen { print }
    ' "$1" | awk 'NF { started = 1 } started { print }' | awk '
        { lines[NR] = $0 }
        END { last = 0; for (i = 1; i <= NR; i++) if (lines[i] ~ /[^[:space:]]/) last = i
              for (i = 1; i <= last; i++) print lines[i] }
    '
}

validate_standard() {
    vs_file="$1"
    vs_base=$(basename "$vs_file" .md)
    head -n 1 "$vs_file" | grep -q '^---[[:space:]]*$' || {
        echo "$vs_file: missing opening frontmatter delimiter '---' on line 1." >&2; exit 1; }
    awk 'NR > 1 && /^---[[:space:]]*$/ { found = 1; exit } END { exit !found }' "$vs_file" || {
        echo "$vs_file: missing closing frontmatter delimiter '---'." >&2; exit 1; }
    for vs_key in name description; do
        vs_val=$(frontmatter_value "$vs_file" "$vs_key")
        [ -n "$vs_val" ] || {
            echo "$vs_file: frontmatter is missing required key '$vs_key'." >&2; exit 1; }
    done
    vs_name=$(frontmatter_value "$vs_file" name)
    [ "$vs_name" = "$vs_base" ] || {
        echo "$vs_file: frontmatter name '$vs_name' must match the filename '$vs_base'." >&2; exit 1; }
}

# Short hash identifying the framework revision. Covers every source standard,
# including _core, so one version identifies the whole set regardless of which
# stacks a given install selected. C-locale sort and CR stripping keep it equal to
# the value build.ps1 computes.
sha256_hex() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 | sed 's/^.*[= ]//'
    else
        echo "No SHA-256 tool found (need sha256sum, shasum, or openssl)." >&2
        exit 1
    fi
}

standards_version() {
    for sv_f in $(ls "$STANDARDS_DIR"/*.md | LC_ALL=C sort); do
        printf '%s\n' "$(basename "$sv_f")"
        tr -d '\r' < "$sv_f"
    done | sha256_hex | cut -c1-8
}

STANDARDS_VERSION=$(standards_version)

CORE_FILE="$STANDARDS_DIR/_core.md"
[ -f "$CORE_FILE" ] || { echo "Missing $CORE_FILE" >&2; exit 1; }
validate_standard "$CORE_FILE"
CORE_BODY=$(standard_body "$CORE_FILE")

STANDARD_NAMES=$(
    for f in "$STANDARDS_DIR"/*.md; do
        b=$(basename "$f" .md)
        # Skip underscore-prefixed files such as _core.md. ${b#_} strips one
        # leading underscore, so a difference means there was one.
        # Do not use a case statement here: this runs inside $( ), and macOS
        # /bin/sh (bash 3.2) mistakes the ')' of a case pattern for the closing
        # parenthesis of the command substitution.
        [ "${b#_}" = "$b" ] || continue
        echo "$b"
    done | LC_ALL=C sort
)
[ -n "$STANDARD_NAMES" ] || { echo "No standards found in $STANDARDS_DIR." >&2; exit 1; }

for n in $STANDARD_NAMES; do validate_standard "$STANDARDS_DIR/$n.md"; done

# --- Stack filter ---------------------------------------------------------
# A standard applies when it is universal ("stack: any"), or when its declared
# stack list intersects the requested stacks. "all" requests everything.
# Mirrors Test-StackMatch in build.ps1.

REQUESTED_STACKS=$(echo "$STACKS" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')

# Recorded in every generated file so --check can compare against the stack set
# that was actually installed, rather than re-detecting and disagreeing.
STACKS_STAMP=$(echo "$REQUESTED_STACKS" | tr -s ' ' | sed 's/^ //;s/ $//' | tr ' ' ',')

stack_matches() {
    sm_declared=$(frontmatter_value "$STANDARDS_DIR/$1.md" stack)
    [ -n "$sm_declared" ] || sm_declared="any"
    [ "$sm_declared" != "any" ] || return 0
    case " $REQUESTED_STACKS " in *" all "*) return 0 ;; esac
    for sm_d in $(echo "$sm_declared" | tr ',' ' '); do
        case " $REQUESTED_STACKS " in *" $sm_d "*) return 0 ;; esac
    done
    return 1
}

INCLUDED=""
EXCLUDED=""
for n in $STANDARD_NAMES; do
    if stack_matches "$n"; then
        INCLUDED="$INCLUDED$n
"
    else
        EXCLUDED="$EXCLUDED, $n ($(frontmatter_value "$STANDARDS_DIR/$n.md" stack))"
    fi
done
STANDARD_NAMES=$(printf '%s' "$INCLUDED")
[ -n "$STANDARD_NAMES" ] || { echo "No standards match --stacks $STACKS." >&2; exit 1; }

COUNT=$(echo "$STANDARD_NAMES" | wc -l | tr -d ' ')
printf 'Source: %s standards + core\n' "$COUNT"
printf 'Output: %s\n' "$OUTPUT_ROOT"
[ -z "$EXCLUDED" ] || printf 'Excluded by stack: %s\n' "$(echo "$EXCLUDED" | sed 's/^, //')"

# --- Helpers --------------------------------------------------------------

write_generated() {
    wg_rel="$1"
    wg_full="$OUTPUT_ROOT/$wg_rel"
    mkdir -p "$(dirname "$wg_full")"
    # Strip CR, drop trailing blank lines, guarantee exactly one final newline,
    # so output matches build.ps1 byte for byte on every platform.
    tr -d '\r' | awk '
        { lines[NR] = $0 }
        END { last = 0; for (i = 1; i <= NR; i++) if (lines[i] ~ /[^[:space:]]/) last = i
              for (i = 1; i <= last; i++) print lines[i] }
    ' > "$wg_full"
    printf '  + %s\n' "$wg_rel"
}

get_trigger() {
    # One-line trigger derived from the description's USE FOR clauses, so the
    # table and the frontmatter can never disagree. Mirrors Get-Trigger.
    frontmatter_value "$STANDARDS_DIR/$1.md" description | awk '
        {
            # Drop the DO NOT USE FOR clause first. "DO NOT USE FOR" contains the
            # literal "USE FOR", so matching it first would capture exclusions as
            # triggers and invert the rule.
            i = index($0, "DO NOT USE FOR")
            if (i > 0) $0 = substr($0, 1, i - 1)

            out = ""
            rest = $0
            while ((j = index(rest, "USE FOR ")) > 0) {
                rest = substr(rest, j + 8)
                k = index(rest, "USE FOR ")
                clause = (k > 0) ? substr(rest, 1, k - 1) : rest
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", clause)
                sub(/\.$/, "", clause)
                if (clause != "") out = (out == "") ? clause : out "; " clause
                if (k == 0) break
            }
            if (out == "") { out = $0; sub(/\..*$/, "", out) }
            gsub(/[[:space:]]+/, " ", out)
            print out
        }
    '
}

GENERATED_NOTICE="<!-- GENERATED FILE. Do not edit.
     Source: standards/*.md in the agent-framework repository.
     Standards version: $STANDARDS_VERSION | stacks: $STACKS_STAMP -->"

# --- .agents/skills/ ------------------------------------------------------
# The canonical copy, and the only one. Agent Skills is an open format, so a
# single tree serves every tool with a skill loader; AGENTS.md points the rest at
# the same paths.
#
# Frontmatter carries only the two fields the spec requires. "stack" and "globs"
# are build-time inputs to this script, not part of the format, so they are not
# passed through. A standard excluded by stack is never emitted, or the target
# gains rules for a language it does not use.

for n in $STANDARD_NAMES; do
    {
        printf -- '---\nname: %s\ndescription: %s\n---\n\n' \
            "$n" "$(frontmatter_value "$STANDARDS_DIR/$n.md" description)"
        printf '%s\n\n' "$GENERATED_NOTICE"
        standard_body "$STANDARDS_DIR/$n.md"
    } | write_generated ".agents/skills/$n/SKILL.md"
done

# --- AGENTS.md ------------------------------------------------------------
# The vendor-neutral entry point. Read natively by Codex, Cursor, Copilot,
# Claude Code, Gemini CLI, Aider, Windsurf, Zed, Jules and others. Always
# emitted, and on its own it is a complete installation.

{
    printf '# Agent instructions\n\n%s\n\n' "$GENERATED_NOTICE"
    cat <<'EOF'
This file holds only the rules that apply to every turn. Detailed standards are
separate files, listed below. Load one **before** starting the work it governs,
not after.

**How to load a standard**, in order of preference for your runtime:

1. If you have a skill or rule loader that already lists it, use that.
2. Otherwise, read the file at the path in the third column. Read it in full
   before acting on the work it governs.

EOF
    printf '%s\n\n' "$CORE_BODY"
    cat <<'EOF'
## Standards

Load by trigger. When two or more triggers match, load all of them.

| Standard | Load when | Path |
|---|---|---|
EOF
    for n in $STANDARD_NAMES; do
        printf '| `%s` | %s | `%s/%s/SKILL.md` |\n' "$n" "$(get_trigger "$n")" "$SKILLS_PATH" "$n"
    done
    cat <<'EOF'

## Precedence

Highest authority first:

1. An explicit instruction from the user in the current conversation.
2. This repository's own documented conventions and tooling configuration.
3. The patterns used in the surrounding code.
4. The conventions of the language being written: its official style guide, its
   reference documentation, and its standard library's own practice.
5. The standards listed above.

When a language convention overrides a standard, state why in your report of the
work: name the standard's rule, name the convention and its source, and say why
the two conflict. A convention with no citable source, or a preference, is not a
justification; follow the standard.

The single exception is security. Rule 1 of the non-negotiables outranks a
repository or language convention that is insecure. Raise it rather than
following it.
EOF
} | write_generated 'AGENTS.md'

# --- Optional adapters ----------------------------------------------------
# Each adds a tool-specific directory. Off unless explicitly requested. Neither
# repeats a standard's text: they carry the discovery metadata their tool needs
# and point at the .agents/skills/ copy.

# Claude Code reads .claude/skills/ only, so without this adapter it falls back
# to the AGENTS.md table like any tool with no loader. The stub gives it a real
# skill entry: name and description are what drive activation, and the body is
# one instruction to read the canonical file.
if has_adapter claude; then
    for n in $STANDARD_NAMES; do
        {
            printf -- '---\nname: %s\ndescription: %s\n---\n\n' \
                "$n" "$(frontmatter_value "$STANDARDS_DIR/$n.md" description)"
            printf '%s\n\n' "$GENERATED_NOTICE"
            printf 'Read `%s/%s/SKILL.md` in full before starting this work, then\n' \
                "$SKILLS_PATH" "$n"
            printf 'follow it. That file is the standard; this one only points at it.\n'
        } | write_generated ".claude/skills/$n/SKILL.md"
    done
fi

# Copilot has no agent-requested mode. Instructions are either repository-wide
# or glob-attached via applyTo. Only standards with globs become auto-attached
# files; the rest are referenced by path from the repository-wide file.
if has_adapter copilot; then
    {
        printf '# Copilot instructions\n\n%s\n\n' "$GENERATED_NOTICE"
        printf '%s\n\n' "$CORE_BODY"
        cat <<'EOF'
## Standards

Read the matching file before starting the work it governs. When two or more
triggers match, read all of them.

| Path | Read when |
|---|---|
EOF
        for n in $STANDARD_NAMES; do
            printf '| `%s/%s/SKILL.md` | %s |\n' "$SKILLS_PATH" "$n" "$(get_trigger "$n")"
        done
    } | write_generated '.github/copilot-instructions.md'

    for n in $STANDARD_NAMES; do
        globs=$(frontmatter_value "$STANDARDS_DIR/$n.md" globs)
        [ -n "$globs" ] || continue
        {
            printf -- "---\napplyTo: '%s'\n---\n%s\n\n" "$globs" "$GENERATED_NOTICE"
            printf 'Read `%s/%s/SKILL.md` in full before editing these files, then\n' \
                "$SKILLS_PATH" "$n"
            printf 'follow it. That file is the standard; this one only points at it.\n'
        } | write_generated ".github/instructions/$n.instructions.md"
    done
fi

echo ""
if [ -z "$SELECTED" ]; then
    printf 'Done. AGENTS.md + %s/ only, no tool-specific directories.\n' "$SKILLS_PATH"
else
    printf 'Done. Adapters: %s\n' "$(echo "$SELECTED" | tr -s ' ' | sed 's/ /, /g')"
fi
