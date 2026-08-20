#!/bin/sh
# Test suite for the agent instruction framework.
#
# Verifies build.sh, build.ps1, install.sh and install.ps1, and that the sh and
# PowerShell implementations agree byte for byte.
#
# There is one suite rather than one per shell, because the property under test is
# agreement between the two. Duplicating the assertions would let the copies drift.
#
# Requires: POSIX sh, awk, sed, find, cmp, diff. pwsh is optional; tests needing it
# are reported as skipped when it is absent, never as passed.
#
# Usage:
#   ./test.sh            Run everything.
#   ./test.sh -v         Also print each command's output on failure.

set -u

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
WORK="${TMPDIR:-/tmp}/agent-framework-test-$$"
VERBOSE=0
[ "${1:-}" != "-v" ] || VERBOSE=1

PASS=0
FAIL=0
SKIP=0
FAILED_NAMES=""

rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

HAVE_PWSH=0
command -v pwsh >/dev/null 2>&1 && HAVE_PWSH=1

# --- Harness --------------------------------------------------------------

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); FAILED_NAMES="$FAILED_NAMES
  - $1"; printf '  FAIL  %s\n' "$1"
         [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s (%s)\n' "$1" "$2"; }

section() { printf '\n%s\n' "$1"; }

# assert_eq <name> <actual> <expected>
assert_eq() {
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3], got [$2]"; fi
}

# assert_exit <name> <expected-code> <command...>
assert_exit() {
    ae_name="$1"; ae_want="$2"; shift 2
    if [ "$VERBOSE" -eq 1 ]; then "$@" >"$WORK/out" 2>&1; else "$@" >/dev/null 2>&1; fi
    ae_got=$?
    if [ "$ae_got" -eq "$ae_want" ]; then ok "$ae_name"
    else
        bad "$ae_name" "expected exit $ae_want, got $ae_got"
        [ "$VERBOSE" -eq 0 ] || sed 's/^/        | /' "$WORK/out"
    fi
}

# assert_same_tree <name> <dir-a> <dir-b>
assert_same_tree() {
    if diff -r "$2" "$3" >"$WORK/diff" 2>&1; then ok "$1"
    else bad "$1" "$(head -n 3 "$WORK/diff" | tr '\n' ' ')"; fi
}

sh_build()   { sh "$REPO_ROOT/build.sh" "$@" >/dev/null 2>&1; }
ps_build()   { pwsh -NoProfile -File "$REPO_ROOT/build.ps1" "$@" >/dev/null 2>&1; }
sh_install() { sh "$REPO_ROOT/install.sh" "$@" </dev/null >/dev/null 2>&1; }
ps_install() { pwsh -NoProfile -File "$REPO_ROOT/install.ps1" "$@" >/dev/null 2>&1; }

count_files() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }
root_entries() { ls -A "$1" 2>/dev/null | LC_ALL=C sort | tr '\n' ' '; }

printf 'Agent framework test suite\n'
printf 'Repo: %s\n' "$REPO_ROOT"
[ "$HAVE_PWSH" -eq 1 ] || printf 'pwsh not found: cross-shell tests will be skipped.\n'

# --- 1. Scripts parse -----------------------------------------------------

section '1. Scripts parse'

for s in build.sh install.sh; do
    assert_exit "$s parses under sh -n" 0 sh -n "$REPO_ROOT/$s"
done

if [ "$HAVE_PWSH" -eq 1 ]; then
    # A helper script rather than -Command: paths passed as arguments get
    # translated by MSYS on Windows, whereas a POSIX path embedded in a quoted
    # -Command string reaches PowerShell unconverted and cannot be resolved.
    cat > "$WORK/parse-check.ps1" <<'PSEOF'
param([Parameter(Mandatory)][string]$Path)
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
exit 0
PSEOF

    for s in build.ps1 install.ps1; do
        if pwsh -NoProfile -File "$WORK/parse-check.ps1" "$REPO_ROOT/$s" >"$WORK/parse.out" 2>&1
        then ok "$s parses"
        else bad "$s parses" "$(head -n 2 "$WORK/parse.out" | tr '\n' ' ')"
        fi
    done
else
    skip 'PowerShell scripts parse' 'no pwsh'
fi

# --- 2. Source validation -------------------------------------------------

section '2. Source validation'

# The trigger table is derived from USE FOR clauses. Without one, a standard
# silently falls back to its first sentence.
MISSING_USEFOR=""
for f in "$REPO_ROOT"/standards/*.md; do
    b=$(basename "$f" .md)
    [ "${b#_}" = "$b" ] || continue
    if ! sed -n 's/^description: //p' "$f" | grep -q 'USE FOR'; then
        MISSING_USEFOR="$MISSING_USEFOR $b"
    fi
done
assert_eq 'every standard declares at least one USE FOR' "${MISSING_USEFOR:-none}" 'none'

# name must equal the filename, or the generated skill name is wrong.
NAME_MISMATCH=""
for f in "$REPO_ROOT"/standards/*.md; do
    b=$(basename "$f" .md)
    n=$(sed -n 's/^name: //p' "$f" | head -n 1)
    [ "$n" = "$b" ] || NAME_MISMATCH="$NAME_MISMATCH $b(=$n)"
done
assert_eq 'every name matches its filename' "${NAME_MISMATCH:-none}" 'none'

# stack must be present and non-empty; an empty value would silently mean "any".
STACK_MISSING=""
for f in "$REPO_ROOT"/standards/*.md; do
    b=$(basename "$f" .md)
    v=$(sed -n 's/^stack: //p' "$f" | head -n 1)
    [ -n "$v" ] || STACK_MISSING="$STACK_MISSING $b"
done
assert_eq 'every standard declares a stack' "${STACK_MISSING:-none}" 'none'

# --- 3. Frontmatter validation is enforced --------------------------------

section '3. Frontmatter validation is enforced'

BADSRC="$WORK/badsrc"
mkdir -p "$BADSRC/standards"
cp "$REPO_ROOT/build.sh" "$BADSRC/"
cp "$REPO_ROOT"/standards/_core.md "$BADSRC/standards/"
cp "$REPO_ROOT"/standards/code-quality.md "$BADSRC/standards/"

# name that disagrees with the filename
sed 's/^name: code-quality$/name: wrong-name/' "$REPO_ROOT/standards/code-quality.md" \
    > "$BADSRC/standards/code-quality.md"
assert_exit 'build rejects a name/filename mismatch' 1 \
    sh "$BADSRC/build.sh" --out "$WORK/badout"

# missing description
cp "$REPO_ROOT/standards/code-quality.md" "$BADSRC/standards/code-quality.md"
grep -v '^description:' "$REPO_ROOT/standards/code-quality.md" \
    > "$BADSRC/standards/code-quality.md.tmp"
mv "$BADSRC/standards/code-quality.md.tmp" "$BADSRC/standards/code-quality.md"
assert_exit 'build rejects a missing description' 1 \
    sh "$BADSRC/build.sh" --out "$WORK/badout2"

# missing opening delimiter
printf 'name: code-quality\n' > "$BADSRC/standards/code-quality.md"
assert_exit 'build rejects absent frontmatter' 1 \
    sh "$BADSRC/build.sh" --out "$WORK/badout3"

# --- 4. Argument validation ----------------------------------------------

section '4. Argument validation'

assert_exit 'build rejects an unknown adapter' 2 \
    sh "$REPO_ROOT/build.sh" --out "$WORK/x" --adapters bogus
assert_exit 'build requires --out' 2 sh "$REPO_ROOT/build.sh"
assert_exit 'install rejects an unknown option' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/x" --bogus
assert_exit 'install rejects target and --user together' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/x" --user
assert_exit 'install refuses the framework repo as target' 2 \
    sh "$REPO_ROOT/install.sh" "$REPO_ROOT"

# --- 5. Default output shape ---------------------------------------------

section '5. Default output shape'

# Counts are derived from standards/, never hardcoded. A hardcoded count goes stale
# the moment a standard is added, which is how this suite last broke.
SRC_FILES=$(ls "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
SRC_STANDARDS=$(ls "$REPO_ROOT"/standards/*.md | grep -vc '/_' | tr -d ' ')
SRC_DOTNET=$(grep -l '^stack: dotnet' "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
# Alternation of the dotnet-scoped standard names, so the stack tests do not name
# them literally either.
DOTNET_PATTERN=$(grep -l '^stack: dotnet' "$REPO_ROOT"/standards/*.md |
    sed 's|.*/||; s|\.md$||' | tr '\n' '|' | sed 's/|$//')

sh_build --out "$WORK/def"
assert_eq 'default build root is AGENTS.md + standards' "$(root_entries "$WORK/def")" 'AGENTS.md standards '
assert_eq 'default build emits AGENTS.md plus every source file' \
    "$(count_files "$WORK/def")" "$((SRC_FILES + 1))"

for unwanted in .claude .cursor .github CLAUDE.md GEMINI.md CONVENTIONS.md; do
    if [ -e "$WORK/def/$unwanted" ]; then bad "default build omits $unwanted"
    else ok "default build omits $unwanted"; fi
done

# _core is inlined into AGENTS.md, and must never become a skill or a rule.
sh_build --out "$WORK/adapters" --adapters all
if [ -e "$WORK/adapters/.claude/skills/_core" ]; then bad '_core is not emitted as a skill'
else ok '_core is not emitted as a skill'; fi
assert_eq '_core is present in standards/' \
    "$([ -f "$WORK/adapters/standards/_core.md" ] && echo yes || echo no)" 'yes'

# --- 6. Trigger table correctness ---------------------------------------

section '6. Trigger table correctness'

# Regression: "DO NOT USE FOR" contains "USE FOR". Matching it first turned each
# standard's exclusions into reasons to load it.
EXCLUSION_LEAK=0
while IFS= read -r line; do
    trigger=$(printf '%s' "$line" | awk -F'|' '{print $3}')
    for phrase in 'see technical-writing' 'see architecture-principles' \
                  'see elimination-debugging' 'see observability-standards' \
                  'see performance-discipline' 'greenfield work'; do
        case "$trigger" in *"$phrase"*) EXCLUSION_LEAK=1 ;; esac
    done
done < "$WORK/def/AGENTS.md"
assert_eq 'no exclusion text leaks into the Load when column' "$EXCLUSION_LEAK" '0'

# _core is inlined into AGENTS.md rather than listed, so it has no row.
assert_eq 'trigger table has one row per standard' \
    "$(grep -c '^| `' "$WORK/def/AGENTS.md")" "$SRC_STANDARDS"

assert_eq 'AGENTS.md carries a standards version' \
    "$(grep -c 'Standards version: [0-9a-f]\{8\}' "$WORK/def/AGENTS.md")" '1'

# --- 7. Output hygiene ---------------------------------------------------

section '7. Output hygiene'

TRAILING=$(find "$WORK/adapters" -type f -exec grep -l ' $' {} \; 2>/dev/null | wc -l | tr -d ' ')
assert_eq 'no generated file has trailing whitespace' "$TRAILING" '0'

# awk rather than a $'\r' pattern: $'...' is a bashism and would be a literal
# backslash-r under POSIX sh, so the test would pass regardless of the content.
CR_FILES=$(find "$WORK/adapters" -type f -exec awk '/\r/ { print FILENAME; exit }' {} \; 2>/dev/null |
    wc -l | tr -d ' ')
assert_eq 'no generated file contains CR' "$CR_FILES" '0'

NO_EOL=0
for f in $(find "$WORK/adapters" -type f); do
    [ -n "$(tail -c 1 "$f")" ] && NO_EOL=$((NO_EOL + 1))
done
assert_eq 'every generated file ends with a newline' "$NO_EOL" '0'

# --- 8. Stack filtering -------------------------------------------------

section '8. Stack filtering'

sh_build --out "$WORK/s-any" --stacks any
assert_eq 'stacks=any excludes the dotnet standards' \
    "$(ls "$WORK/s-any/standards" | grep -c -E "$DOTNET_PATTERN")" '0'

sh_build --out "$WORK/s-dotnet" --stacks dotnet
assert_eq 'stacks=dotnet includes the dotnet standards' \
    "$(ls "$WORK/s-dotnet/standards" | grep -c -E "$DOTNET_PATTERN")" "$SRC_DOTNET"

# Every standard except the stack-scoped ones.
assert_eq 'stacks=any yields a shorter trigger table' \
    "$(grep -c '^| `' "$WORK/s-any/AGENTS.md")" "$((SRC_STANDARDS - SRC_DOTNET))"

# Detection: a marker file under src/ must be found.
mkdir -p "$WORK/proj-dotnet/src/App" "$WORK/proj-python"
: > "$WORK/proj-dotnet/src/App/App.csproj"
: > "$WORK/proj-python/pyproject.toml"

sh_install "$WORK/proj-dotnet" -y
assert_eq 'a .NET project receives the dotnet standards' \
    "$(ls "$WORK/proj-dotnet/standards" | grep -c -E "$DOTNET_PATTERN")" "$SRC_DOTNET"

sh_install "$WORK/proj-python" -y
assert_eq 'a Python project receives no dotnet standards' \
    "$(ls "$WORK/proj-python/standards" | grep -c -E "$DOTNET_PATTERN")" '0'

# --- 9. Install behaviour ------------------------------------------------

section '9. Install behaviour'

mkdir -p "$WORK/inst"
sh_install "$WORK/inst" -y
assert_eq 'install root is AGENTS.md + standards' "$(root_entries "$WORK/inst")" 'AGENTS.md standards '

BEFORE=$(count_files "$WORK/inst")
sh "$REPO_ROOT/install.sh" "$WORK/inst" -y </dev/null 2>&1 | grep -q '^0 file(s) written' \
    && ok 're-install writes nothing' || bad 're-install writes nothing'
assert_eq 're-install changes no file count' "$(count_files "$WORK/inst")" "$BEFORE"

sh "$REPO_ROOT/install.sh" "$WORK/inst" -y --force </dev/null 2>&1 \
    | grep -q "^$BEFORE file(s) written" \
    && ok '--force rewrites every file' || bad '--force rewrites every file'

sh_install "$WORK/inst-claude" -y --adapters claude
assert_eq '--adapters claude adds .claude' \
    "$([ -d "$WORK/inst-claude/.claude/skills" ] && echo yes || echo no)" 'yes'
assert_eq '--adapters claude does not add .cursor' \
    "$([ -d "$WORK/inst-claude/.cursor" ] && echo yes || echo no)" 'no'

sh_install "$WORK/inst-cursor" -y --adapters cursor
assert_eq '--adapters cursor adds .cursor/rules' \
    "$([ -d "$WORK/inst-cursor/.cursor/rules" ] && echo yes || echo no)" 'yes'

sh_install "$WORK/inst-copilot" -y --adapters copilot
assert_eq '--adapters copilot adds copilot-instructions.md' \
    "$([ -f "$WORK/inst-copilot/.github/copilot-instructions.md" ] && echo yes || echo no)" 'yes'

# --dry-run must not touch the destination.
mkdir -p "$WORK/dry"
sh_install "$WORK/dry" -y --dry-run
assert_eq '--dry-run writes nothing' "$(count_files "$WORK/dry")" '0'

# --- 10. Check mode -----------------------------------------------------

section '10. Check mode'

assert_exit '--check on an empty directory exits 2' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/dry" --check

assert_exit '--check on a fresh install exits 0' 0 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --check

printf '\ntampered\n' >> "$WORK/inst/standards/code-quality.md"
assert_exit '--check detects a modified file' 1 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --check

rm -f "$WORK/inst/standards/code-quality.md"
assert_exit '--check detects a missing file' 1 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --check

sh_install "$WORK/inst" -y --force
assert_exit '--check passes again after repair' 0 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --check

# --- 11. Cross-shell agreement -----------------------------------------

section '11. Cross-shell agreement'

if [ "$HAVE_PWSH" -eq 1 ]; then
    for combo in "default::" "adapters:--adapters all:-Adapters all" \
                 "stacks-any:--stacks any:-Stacks any" \
                 "stacks-dotnet:--stacks dotnet:-Stacks dotnet"; do
        name=$(printf '%s' "$combo" | cut -d: -f1)
        shargs=$(printf '%s' "$combo" | cut -d: -f2)
        psargs=$(printf '%s' "$combo" | cut -d: -f3)

        rm -rf "$WORK/x-sh-$name" "$WORK/x-ps-$name"
        # shellcheck disable=SC2086
        sh_build --out "$WORK/x-sh-$name" $shargs
        # shellcheck disable=SC2086
        ps_build -OutputRoot "$WORK/x-ps-$name" $psargs
        assert_same_tree "build agrees ($name)" "$WORK/x-sh-$name" "$WORK/x-ps-$name"
    done

    assert_eq 'the standards version hash agrees' \
        "$(grep -o 'Standards version: [0-9a-f]*' "$WORK/x-sh-default/AGENTS.md")" \
        "$(grep -o 'Standards version: [0-9a-f]*' "$WORK/x-ps-default/AGENTS.md")"

    rm -rf "$WORK/i-sh" "$WORK/i-ps"
    sh_install "$WORK/i-sh" -y --adapters all --stacks all
    ps_install -Target "$WORK/i-ps" -Yes -Adapters all -Stacks all
    assert_same_tree 'install agrees (all adapters)' "$WORK/i-sh" "$WORK/i-ps"

    rm -rf "$WORK/j-sh" "$WORK/j-ps"
    mkdir -p "$WORK/j-sh/src" "$WORK/j-ps/src"
    : > "$WORK/j-sh/src/A.csproj"
    : > "$WORK/j-ps/src/A.csproj"
    sh_install "$WORK/j-sh" -y
    ps_install -Target "$WORK/j-ps" -Yes
    assert_same_tree 'stack detection agrees (.NET project)' "$WORK/j-sh" "$WORK/j-ps"

    assert_exit 'ps --check agrees on a clean install' 0 \
        pwsh -NoProfile -File "$REPO_ROOT/install.ps1" -Target "$WORK/i-ps" -Check
else
    skip 'cross-shell build agreement' 'no pwsh'
    skip 'cross-shell install agreement' 'no pwsh'
    skip 'standards version hash agreement' 'no pwsh'
fi

# --- Summary ------------------------------------------------------------

printf '\n----------------------------------------\n'
printf '%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
    printf 'Failed:%s\n' "$FAILED_NAMES"
    exit 1
fi
exit 0
