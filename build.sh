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
#   --adapters LIST     Optional adapters: claude,copilot,hooks,all,none (default: none).
#   --stacks LIST       Which stacks to include: all, any, dotnet, ... (default: all).
#                       A standard with "stack: any" is always included.
#   --skills-path PATH  Where AGENTS.md and the adapters say the skills live
#                       (default: .agents/skills). A user-level install passes
#                       ~/.agents/skills, because there is no project root.
#   --lite              Emit a single AGENTS.md for small-context local models:
#                       the core rules plus the checklist of each universal
#                       standard, inline. No skills tree, and adapters are
#                       refused. No stack-scoped standard is included.
#   --lite=LIST         The same, plus the standards of the listed stacks
#                       (--lite=dotnet,unreal). Same as --lite --stacks LIST.
#   -h, --help          Show this help.

set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
STANDARDS_DIR="$REPO_ROOT/standards"
OUTPUT_ROOT=""
ADAPTERS="none"
STACKS="all"
SKILLS_PATH=".agents/skills"
LITE=0
STACKS_SET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --out) shift; [ $# -gt 0 ] || { echo "--out needs a directory" >&2; exit 2; }; OUTPUT_ROOT="$1" ;;
        --adapters) shift; [ $# -gt 0 ] || { echo "--adapters needs a value" >&2; exit 2; }; ADAPTERS="$1" ;;
        --stacks) shift; [ $# -gt 0 ] || { echo "--stacks needs a value" >&2; exit 2; }
                  STACKS="$1"; STACKS_SET=1 ;;
        --skills-path) shift; [ $# -gt 0 ] || { echo "--skills-path needs a value" >&2; exit 2; }
                       SKILLS_PATH=$(echo "$1" | sed 's|/*$||') ;;
        --lite) LITE=1 ;;
        --lite=*) LITE=1; STACKS="${1#--lite=}"; STACKS_SET=1
                  [ -n "$STACKS" ] || { echo "--lite= needs a stack list" >&2; exit 2; } ;;
        -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

# Lite is the core rules and the universal standards unless stacks are named.
if [ "$LITE" -eq 1 ] && [ "$STACKS_SET" -eq 0 ]; then STACKS="any"; fi

[ -d "$STANDARDS_DIR" ] || { echo "Source directory not found: $STANDARDS_DIR" >&2; exit 1; }
[ -n "$OUTPUT_ROOT" ] || { echo "Usage: ./build.sh --out DIR [--adapters LIST]" >&2; exit 2; }

mkdir -p "$OUTPUT_ROOT"
OUTPUT_ROOT=$(CDPATH='' cd -- "$OUTPUT_ROOT" && pwd)

# Everything else reads .agents/skills/ natively, or falls back to the AGENTS.md
# table. Claude Code does not read .agents/skills/ at all, Copilot has a
# glob-attach mechanism that skills do not cover, and hooks turns the
# no-hardcodes gate into a real git pre-commit hook.
KNOWN_ADAPTERS="claude copilot hooks"

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

# Lite is one always-on file: there is no skills tree for an adapter to point at.
if [ "$LITE" -eq 1 ] && [ -n "$SELECTED" ]; then
    echo "--lite emits a single AGENTS.md; adapters do not apply." >&2; exit 2
fi

# --- Source parsing -------------------------------------------------------
# Frontmatter is hand-parsed: single-line "key: value" pairs only, so there is
# no YAML dependency. Mirrors Read-Standard in build.ps1.

# Process creation dominates the runtime on Windows, where a spawn costs
# 50-100x what it does on Linux, so the frontmatter of every standard is parsed
# once, by one awk pass, into shell variables. A lookup is then a parameter
# expansion, not a process.

# Pure sh, no fork: converts a standard name to a variable-name-safe form in
# MANGLED ("code-quality" -> "code_quality").
mangle() {
    MANGLED=""
    m_rest=$1
    while [ -n "$m_rest" ]; do
        m_c=${m_rest%"${m_rest#?}"}
        m_rest=${m_rest#?}
        [ "$m_c" != "-" ] || m_c="_"
        MANGLED="$MANGLED$m_c"
    done
}

# Emits FM_<key>_<mangled-name>='value' assignments for every standard, plus
# FM_open_/FM_closed_ flags for the delimiter checks, then evals them. Values
# are single-quote escaped by awk, and only the four known keys are emitted, so
# the eval cannot execute file content. Mirrors Read-Standard in build.ps1.
load_frontmatter() {
    eval "$(awk '
        # The trigger is derived here too, in the same pass, so the table needs
        # no further process per standard. Mirrors Get-Trigger in build.ps1.
        function trigger(d,   out, rest, j, k2, clause, i2) {
            i2 = index(d, "DO NOT USE FOR")
            if (i2 > 0) d = substr(d, 1, i2 - 1)
            out = ""; rest = d
            while ((j = index(rest, "USE FOR ")) > 0) {
                rest = substr(rest, j + 8)
                k2 = index(rest, "USE FOR ")
                clause = (k2 > 0) ? substr(rest, 1, k2 - 1) : rest
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", clause)
                sub(/\.$/, "", clause)
                if (clause != "") out = (out == "") ? clause : out "; " clause
                if (k2 == 0) break
            }
            if (out == "") { out = d; sub(/\..*$/, "", out) }
            gsub(/[[:space:]]+/, " ", out)
            return out
        }
        FNR == 1 {
            name = FILENAME; sub(/.*\//, "", name); sub(/\.md$/, "", name)
            mangled = name; gsub(/-/, "_", mangled)
            infm = 0
            if ($0 ~ /^---[[:space:]]*$/) { infm = 1; print "FM_open_" mangled "=1" }
            next
        }
        infm && /^---[[:space:]]*$/ { infm = 0; print "FM_closed_" mangled "=1"; next }
        infm {
            i = index($0, ":")
            if (i < 2) next
            k = substr($0, 1, i - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            if (k !~ /^(name|description|globs|stack)$/) next
            if (seen[mangled, k]++) next
            v = substr($0, i + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (k == "description") {
                t = trigger(v)
                gsub(/\047/, "\047\\\047\047", t)
                print "FM_trigger_" mangled "=\047" t "\047"
            }
            gsub(/\047/, "\047\\\047\047", v)
            print "FM_" k "_" mangled "=\047" v "\047"
        }
    ' "$STANDARDS_DIR"/*.md)"
}

frontmatter_value() {
    fv_base=${1##*/}; fv_base=${fv_base%.md}
    mangle "$fv_base"
    eval "printf '%s\n' \"\${FM_${2}_${MANGLED}:-}\""
}

validate_standard() {
    vs_file="$1"
    vs_base=${vs_file##*/}; vs_base=${vs_base%.md}
    mangle "$vs_base"; vs_m=$MANGLED
    eval "vs_open=\${FM_open_$vs_m:-0}"
    [ "$vs_open" = "1" ] || {
        echo "$vs_file: missing opening frontmatter delimiter '---' on line 1." >&2; exit 1; }
    eval "vs_closed=\${FM_closed_$vs_m:-0}"
    [ "$vs_closed" = "1" ] || {
        echo "$vs_file: missing closing frontmatter delimiter '---'." >&2; exit 1; }
    for vs_key in name description; do
        eval "vs_val=\${FM_${vs_key}_$vs_m:-}"
        [ -n "$vs_val" ] || {
            echo "$vs_file: frontmatter is missing required key '$vs_key'." >&2; exit 1; }
    done
    eval "vs_name=\${FM_name_$vs_m:-}"
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
    # One awk over every file, not one tr per file: this runs on each build and
    # Windows pays dearly per process. awk re-adds a missing final newline where
    # tr would not, so a source file must end with one; the cross-shell hash
    # test catches a divergence.
    # shellcheck disable=SC2046
    awk '
        FNR == 1 { n = FILENAME; sub(/.*\//, "", n); print n }
        { gsub(/\r/, ""); print }
    ' $(ls "$STANDARDS_DIR"/*.md | LC_ALL=C sort) | sha256_hex | cut -c1-8
}

load_frontmatter
STANDARDS_VERSION=$(standards_version)

CORE_FILE="$STANDARDS_DIR/_core.md"
[ -f "$CORE_FILE" ] || { echo "Missing $CORE_FILE" >&2; exit 1; }
validate_standard "$CORE_FILE"

STANDARD_NAMES=$(
    for f in "$STANDARDS_DIR"/*.md; do
        b=${f##*/}; b=${b%.md}
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
    mangle "$1"
    eval "sm_declared=\${FM_stack_$MANGLED:-}"
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
        mangle "$n"
        eval "ex_stack=\${FM_stack_$MANGLED:-any}"
        EXCLUDED="$EXCLUDED, $n ($ex_stack)"
    fi
done
STANDARD_NAMES=$(printf '%s' "$INCLUDED")
[ -n "$STANDARD_NAMES" ] || { echo "No standards match --stacks $STACKS." >&2; exit 1; }

COUNT=$(echo "$STANDARD_NAMES" | wc -l | tr -d ' ')
printf 'Source: %s standards + core\n' "$COUNT"
printf 'Output: %s\n' "$OUTPUT_ROOT"
[ -z "$EXCLUDED" ] || printf 'Excluded by stack: %s\n' "$(echo "$EXCLUDED" | sed 's/^, //')"

# --- Emission -------------------------------------------------------------
# Every generated file is written by one awk process fed a control stream, and
# every output directory is created by one mkdir: anything per-file would be a
# process per file, which Windows makes expensive. The stream's directives:
#
#   ===FILE=== <relative path>    start the next output file
#   ===BODY=== <source .md>       inline a standard's body: frontmatter
#                                 skipped, blank edges trimmed
#   ===CHECKLIST=== <source .md>  inline a standard's checklist, each
#                                 "- [ ] item" emitted as "- item"
#
# Everything else is literal content. Per file, the writer strips CR, drops
# trailing blank lines, and guarantees exactly one final newline, so output
# matches build.ps1 byte for byte on every platform.

# The mode is stamped so --check and --upgrade regenerate what was installed
# rather than comparing a lite install against a full build.
MODE_STAMP=""
[ "$LITE" -eq 0 ] || MODE_STAMP=" | mode: lite"

GENERATED_NOTICE="<!-- GENERATED FILE. Do not edit.
     Source: standards/*.md in the agent-framework repository.
     Standards version: $STANDARDS_VERSION | stacks: $STACKS_STAMP$MODE_STAMP -->"

# Every output directory, one mkdir. "$@" is the only POSIX array, and it
# preserves a path holding spaces.
set --
if [ "$LITE" -eq 0 ]; then
    for n in $STANDARD_NAMES; do set -- "$@" "$OUTPUT_ROOT/.agents/skills/$n"; done
fi
if has_adapter claude; then
    for n in $STANDARD_NAMES; do set -- "$@" "$OUTPUT_ROOT/.claude/skills/$n"; done
fi
if has_adapter copilot; then
    set -- "$@" "$OUTPUT_ROOT/.github"
    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "cg=\${FM_globs_$MANGLED:-}"
        # The instructions directory exists only when a glob file will land in
        # it, or build.ps1, which creates directories per file, would disagree.
        if [ -n "$cg" ]; then set -- "$@" "$OUTPUT_ROOT/.github/instructions"; break; fi
    done
fi
if has_adapter hooks; then set -- "$@" "$OUTPUT_ROOT/.githooks"; fi
[ $# -eq 0 ] || mkdir -p "$@"

emit_stream() {

# --- .agents/skills/ ------------------------------------------------------
# The canonical copy, and the only one. Agent Skills is an open format, so a
# single tree serves every tool with a skill loader; AGENTS.md points the rest at
# the same paths.
#
# Frontmatter carries only the two fields the spec requires. "stack" and "globs"
# are build-time inputs to this script, not part of the format, so they are not
# passed through. A standard excluded by stack is never emitted, or the target
# gains rules for a language it does not use.

if [ "$LITE" -eq 0 ]; then
    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "sk_desc=\${FM_description_$MANGLED:-}"
        printf '===FILE=== .agents/skills/%s/SKILL.md\n' "$n"
        printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$n" "$sk_desc"
        printf '%s\n\n' "$GENERATED_NOTICE"
        printf '===BODY=== %s\n' "$STANDARDS_DIR/$n.md"
    done
fi

# --- AGENTS.md (lite) -------------------------------------------------------
# One always-on file for models with small context windows and weak on-demand
# loading: the core rules plus each standard's checklist, inline. No trigger
# table, because a small model cannot be relied on to go and load a file.

if [ "$LITE" -eq 1 ]; then
    printf '===FILE=== AGENTS.md\n'
    printf '# Agent instructions\n\n%s\n\n' "$GENERATED_NOTICE"
    cat <<'EOF'
This is the lite build. Every rule is in this one file; there is nothing else
to load. Follow the non-negotiables always. Each standard below binds whenever
its "When" line matches the work you are doing.
EOF
    printf '\n'
    printf '===BODY=== %s\n' "$CORE_FILE"
    printf '\n## Standards\n'
    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "lt_trigger=\${FM_trigger_$MANGLED:-}"
        printf '\n### %s\n\nWhen: %s.\n\n' "$n" "$lt_trigger"
        printf '===CHECKLIST=== %s\n' "$STANDARDS_DIR/$n.md"
    done
    cat <<'EOF'

## Precedence

Highest authority first:

1. An explicit instruction from the user in the current conversation.
2. This repository's own documented conventions and tooling configuration.
3. The patterns used in the surrounding code.
4. The conventions of the language being written.
5. The standards listed above.

The single exception is security. Rule 1 of the non-negotiables outranks a
repository or language convention that is insecure. Raise it rather than
following it.
EOF
else

# --- AGENTS.md ------------------------------------------------------------
# The vendor-neutral entry point. Read natively by Codex, Cursor, Copilot,
# Claude Code, Gemini CLI, Aider, Windsurf, Zed, Jules and others. Always
# emitted, and on its own it is a complete installation.

    printf '===FILE=== AGENTS.md\n'
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
    printf '===BODY=== %s\n\n' "$CORE_FILE"
    cat <<'EOF'
## Standards

Load by trigger. When two or more triggers match, load all of them.

| Standard | Load when | Path |
|---|---|---|
EOF
    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "ag_trigger=\${FM_trigger_$MANGLED:-}"
        printf '| `%s` | %s | `%s/%s/SKILL.md` |\n' "$n" "$ag_trigger" "$SKILLS_PATH" "$n"
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

fi

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
        mangle "$n"
        eval "cl_desc=\${FM_description_$MANGLED:-}"
        printf '===FILE=== .claude/skills/%s/SKILL.md\n' "$n"
        printf -- '---\nname: %s\ndescription: %s\n---\n\n' "$n" "$cl_desc"
        printf '%s\n\n' "$GENERATED_NOTICE"
        printf 'Read `%s/%s/SKILL.md` in full before starting this work, then\n' \
            "$SKILLS_PATH" "$n"
        printf 'follow it. That file is the standard; this one only points at it.\n'
    done
fi

# Copilot has no agent-requested mode. Instructions are either repository-wide
# or glob-attached via applyTo. Only standards with globs become auto-attached
# files; the rest are referenced by path from the repository-wide file.
if has_adapter copilot; then
    printf '===FILE=== .github/copilot-instructions.md\n'
    printf '# Copilot instructions\n\n%s\n\n' "$GENERATED_NOTICE"
    printf '===BODY=== %s\n\n' "$CORE_FILE"
    cat <<'EOF'
## Standards

Read the matching file before starting the work it governs. When two or more
triggers match, read all of them.

| Path | Read when |
|---|---|
EOF
    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "co_trigger=\${FM_trigger_$MANGLED:-}"
        printf '| `%s/%s/SKILL.md` | %s |\n' "$SKILLS_PATH" "$n" "$co_trigger"
    done

    for n in $STANDARD_NAMES; do
        mangle "$n"
        eval "globs=\${FM_globs_$MANGLED:-}"
        [ -n "$globs" ] || continue
        printf '===FILE=== .github/instructions/%s.instructions.md\n' "$n"
        printf -- "---\napplyTo: '%s'\n---\n%s\n\n" "$globs" "$GENERATED_NOTICE"
        printf 'Read `%s/%s/SKILL.md` in full before editing these files, then\n' \
            "$SKILLS_PATH" "$n"
        printf 'follow it. That file is the standard; this one only points at it.\n'
    done
fi

# The hooks adapter is tooling, not a pointer: it turns the no-hardcodes
# standard's pre-commit gate into a real git hook, so a human commit meets the
# same gate an agent applies. Enabled per clone with:
#   git config core.hooksPath .githooks
if has_adapter hooks; then
    printf '===FILE=== .githooks/pre-commit\n'
    printf '#!/bin/sh\n'
    printf '# GENERATED FILE. Do not edit.\n'
    printf '# Source: standards/no-hardcodes.md in the agent-framework repository.\n'
    printf '# Standards version: %s | stacks: %s\n' "$STANDARDS_VERSION" "$STACKS_STAMP"
    cat <<'HOOK'
#
# Pre-commit gate from the no-hardcodes standard: scans the staged diff's
# added lines for secrets and environment-specific values, and blocks the
# commit on a hit. Enable it per clone with:
#
#   git config core.hooksPath .githooks
#
# Only the user may waive a finding, and only after hearing the risk. Agents
# must never bypass this hook.

findings=$(git diff --cached --diff-filter=ACM --unified=0 --no-color | awk '
    /^\+\+\+ / { file = substr($0, 7); next }
    /^@@ /     { split($0, h, "+"); split(h[2], p, /[, ]/); line = p[1] - 1; next }
    /^\+/ {
        line = line + 1
        if (file ~ /^\.githooks\//) next
        text = substr($0, 2)
        lower = tolower(text)
        # Obvious placeholders and local-dev values never block.
        if (lower ~ /<[a-z_-]+>|changeme|xxxx|example\.com|localhost|127\.0\.0\.1/) next
        hit = ""
        if (lower ~ /-----begin [a-z ]*private key-----/)
            hit = "private key"
        else if (lower ~ /(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*[^[:space:]]/)
            hit = "password"
        else if (lower ~ /(api[_-]?key|secret|token|accountkey)[[:space:]]*[=:][[:space:]]*["]?[a-z0-9+\/_.=-]{12,}/)
            hit = "credential"
        else if (text ~ /AKIA[0-9A-Z]{16}/)
            hit = "AWS access key"
        else if (lower ~ /[a-z+.-]+:\/\/[^\/[:space:]:]+:[^\/[:space:]@]+@/)
            hit = "credential in URL"
        # Report the location and category only. Never echo the value itself.
        if (hit != "") printf "  %s:%d  %s\n", file, line, hit
        next
    }
')

if [ -n "$findings" ]; then
    echo "no-hardcodes: commit blocked. Staged lines that look like secrets or"
    echo "environment-specific values:"
    echo ""
    printf '%s\n' "$findings"
    echo ""
    echo "Move each value to configuration or a secret store, then stage the"
    echo "change again. See the no-hardcodes standard for the remedy rules."
    exit 1
fi
exit 0
HOOK
fi

}

# The writer: one awk for every file. It buffers each file's lines, resolves
# the body and checklist directives by reading the source standard itself, and
# flushes with the trailing-blank trim and final newline on the next file
# marker or at the end.
emit_stream | awk -v root="$OUTPUT_ROOT" '
    function flush(   i, last) {
        if (cur == "") return
        last = 0
        for (i = 1; i <= n; i++) if (lines[i] ~ /[^[:space:]]/) last = i
        for (i = 1; i <= last; i++) print lines[i] > cur
        close(cur)
        printf "  + %s\n", rel
    }
    /^===FILE=== / { flush(); rel = substr($0, 12); cur = root "/" rel; n = 0; next }
    /^===BODY=== / {
        src = substr($0, 12)
        fnr = 0; fm = 0; started = 0; bstart = n
        while ((getline l < src) > 0) {
            fnr++; gsub(/\r/, "", l)
            if (fnr == 1) continue
            if (!fm) { if (l ~ /^---[[:space:]]*$/) fm = 1; continue }
            if (!started && l !~ /[^[:space:]]/) continue
            started = 1; lines[++n] = l
        }
        close(src)
        while (n > bstart && lines[n] !~ /[^[:space:]]/) n--
        next
    }
    /^===CHECKLIST=== / {
        src = substr($0, 17)
        incl = 0
        while ((getline l < src) > 0) {
            gsub(/\r/, "", l)
            if (l ~ /^## Checklist/) { incl = 1; continue }
            if (incl && l ~ /^## /) break
            if (incl && index(l, "- [ ] ") == 1) lines[++n] = "- " substr(l, 7)
        }
        close(src)
        next
    }
    { gsub(/\r/, ""); lines[++n] = $0 }
    END { flush() }
'

if has_adapter hooks; then
    chmod +x "$OUTPUT_ROOT/.githooks/pre-commit" 2>/dev/null || true
fi

echo ""
if [ -z "$SELECTED" ]; then
    printf 'Done. AGENTS.md + %s/ only, no tool-specific directories.\n' "$SKILLS_PATH"
else
    printf 'Done. Adapters: %s\n' "$(echo "$SELECTED" | tr -s ' ' | sed 's/ /, /g')"
fi
