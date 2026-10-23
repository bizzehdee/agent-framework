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
SRC_STANDARDS=$(ls "$REPO_ROOT"/standards/*.md | grep -vc '/_' | tr -d ' ')
SRC_DOTNET=$(grep -l '^stack: dotnet' "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
# Standards scoped to any named stack, i.e. excluded from a stacks=any build.
SRC_STACKED=$(grep -L '^stack: any' "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
# Alternation of the dotnet-scoped standard names, so the stack tests do not name
# them literally either.
DOTNET_PATTERN=$(grep -l '^stack: dotnet' "$REPO_ROOT"/standards/*.md |
    sed 's|.*/||; s|\.md$||' | tr '\n' '|' | sed 's/|$//')
SRC_PYTHON=$(grep -l '^stack: python' "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
SRC_GODOT=$(grep -l '^stack: godot' "$REPO_ROOT"/standards/*.md | wc -l | tr -d ' ')
GODOT_PATTERN=$(grep -l '^stack: godot' "$REPO_ROOT"/standards/*.md |
    sed 's|.*/||; s|\.md$||' | tr '\n' '|' | sed 's/|$//')
PYTHON_PATTERN=$(grep -l '^stack: python' "$REPO_ROOT"/standards/*.md |
    sed 's|.*/||; s|\.md$||' | tr '\n' '|' | sed 's/|$//')

sh_build --out "$WORK/def"
assert_eq 'default build root is AGENTS.md + .agents' \
    "$(root_entries "$WORK/def")" '.agents AGENTS.md '
# One SKILL.md per standard, plus AGENTS.md. _core is inlined, never a skill.
assert_eq 'default build emits AGENTS.md plus one skill per standard' \
    "$(count_files "$WORK/def")" "$((SRC_STANDARDS + 1))"
assert_eq 'every skill directory holds a SKILL.md' \
    "$(find "$WORK/def/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
    "$SRC_STANDARDS"

# The skills tree is the only copy. An install that also carried standards/ would
# be back to two copies of every standard, which is the thing this layout removes.
for unwanted in standards .claude .cursor .github CLAUDE.md GEMINI.md CONVENTIONS.md; do
    if [ -e "$WORK/def/$unwanted" ]; then bad "default build omits $unwanted"
    else ok "default build omits $unwanted"; fi
done

# Every skill must satisfy the Agent Skills spec: name matches its directory, and
# the description fits the 1024-character cap.
SPEC_BAD=0
for d in "$WORK/def"/.agents/skills/*/; do
    n=$(basename "$d")
    f="$d/SKILL.md"
    [ "$(awk -F': ' '/^name: /{print $2; exit}' "$f")" = "$n" ] || SPEC_BAD=$((SPEC_BAD + 1))
    desc=$(awk '/^description: /{sub(/^description: /,""); print; exit}' "$f")
    [ "${#desc}" -le 1024 ] && [ -n "$desc" ] || SPEC_BAD=$((SPEC_BAD + 1))
done
assert_eq 'every skill has a spec-valid name and description' "$SPEC_BAD" '0'

# Frontmatter carries only spec fields. stack and globs drive this build; passing
# them through would put non-standard keys in front of every tool that reads them.
assert_eq 'skill frontmatter leaks no build-time keys' \
    "$(awk '/^---$/{n++; next} n==1 && /^(stack|globs):/{c++} END{print c+0}' \
        "$WORK/def"/.agents/skills/*/SKILL.md)" '0'

# _core is inlined into AGENTS.md, and must never become a skill or a rule.
sh_build --out "$WORK/adapters" --adapters all
if [ -e "$WORK/adapters/.agents/skills/_core" ]; then bad '_core is not emitted as a skill'
else ok '_core is not emitted as a skill'; fi

# The whole point of the adapters: discovery metadata their tool needs, pointing
# at the canonical file. A body long enough to be the standard itself is a
# regression back to duplicated text.
for f in "$WORK/adapters"/.claude/skills/*/SKILL.md \
         "$WORK/adapters"/.github/instructions/*.instructions.md; do
    n=$(wc -l < "$f" | tr -d ' ')
    [ "$n" -le 15 ] || { bad "adapter file $f is a pointer, not a copy ($n lines)"; break; }
done
ok 'adapter files are pointers, not copies'

assert_eq 'every claude stub points at the .agents/skills copy' \
    "$(grep -l '`\.agents/skills/[a-z-]*/SKILL\.md`' "$WORK/adapters"/.claude/skills/*/SKILL.md |
        wc -l | tr -d ' ')" "$SRC_STANDARDS"

# --skills-path has to reach every generated reference, or a user install points
# at a project-relative path that does not exist there.
sh_build --out "$WORK/userpath" --adapters claude --skills-path '~/.agents/skills'
assert_eq '--skills-path rewrites the AGENTS.md table' \
    "$(grep -c '`~/\.agents/skills/[a-z-]*/SKILL\.md`' "$WORK/userpath/AGENTS.md")" "$SRC_STANDARDS"
assert_eq '--skills-path rewrites the claude stubs' \
    "$(grep -l '`~/\.agents/skills/[a-z-]*/SKILL\.md`' "$WORK/userpath"/.claude/skills/*/SKILL.md |
        wc -l | tr -d ' ')" "$SRC_STANDARDS"

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
    "$(ls "$WORK/s-any/.agents/skills" | grep -c -E "$DOTNET_PATTERN")" '0'

sh_build --out "$WORK/s-dotnet" --stacks dotnet
assert_eq 'stacks=dotnet includes the dotnet standards' \
    "$(ls "$WORK/s-dotnet/.agents/skills" | grep -c -E "$DOTNET_PATTERN")" "$SRC_DOTNET"

# Every standard except the stack-scoped ones.
assert_eq 'stacks=any yields a shorter trigger table' \
    "$(grep -c '^| `' "$WORK/s-any/AGENTS.md")" "$((SRC_STANDARDS - SRC_STACKED))"

# Detection: a marker file under src/ must be found.
mkdir -p "$WORK/proj-dotnet/src/App" "$WORK/proj-python"
: > "$WORK/proj-dotnet/src/App/App.csproj"
: > "$WORK/proj-python/pyproject.toml"

sh_install "$WORK/proj-dotnet" -y
assert_eq 'a .NET project receives the dotnet standards' \
    "$(ls "$WORK/proj-dotnet/.agents/skills" | grep -c -E "$DOTNET_PATTERN")" "$SRC_DOTNET"

sh_install "$WORK/proj-python" -y
assert_eq 'a Python project receives no dotnet standards' \
    "$(ls "$WORK/proj-python/.agents/skills" | grep -c -E "$DOTNET_PATTERN")" '0'
assert_eq 'a Python project receives the python standards' \
    "$(ls "$WORK/proj-python/.agents/skills" | grep -c -E "$PYTHON_PATTERN")" "$SRC_PYTHON"

# A GDScript-only Godot project is godot alone; a C# one is godot and dotnet.
mkdir -p "$WORK/proj-godot/game" "$WORK/proj-godot-cs/game"
: > "$WORK/proj-godot/game/project.godot"
: > "$WORK/proj-godot-cs/game/project.godot"
: > "$WORK/proj-godot-cs/game/Game.csproj"

sh_install "$WORK/proj-godot" -y
assert_eq 'a Godot project receives the godot standards' \
    "$(ls "$WORK/proj-godot/.agents/skills" | grep -c -E "$GODOT_PATTERN")" "$SRC_GODOT"
assert_eq 'a GDScript Godot project receives no dotnet standards' \
    "$(ls "$WORK/proj-godot/.agents/skills" | grep -c -E "$DOTNET_PATTERN")" '0'

sh_install "$WORK/proj-godot-cs" -y
assert_eq 'a C# Godot project receives the godot and dotnet standards' \
    "$(ls "$WORK/proj-godot-cs/.agents/skills" | grep -c -E "$GODOT_PATTERN|$DOTNET_PATTERN")" \
    "$((SRC_GODOT + SRC_DOTNET))"
assert_eq 'a .NET project receives no python standards' \
    "$(ls "$WORK/proj-dotnet/.agents/skills" | grep -c -E "$PYTHON_PATTERN")" '0'

# --- 9. Install behaviour ------------------------------------------------

section '9. Install behaviour'

mkdir -p "$WORK/inst"
sh_install "$WORK/inst" -y
assert_eq 'install root is AGENTS.md + .agents' \
    "$(root_entries "$WORK/inst")" '.agents AGENTS.md '

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
assert_eq '--adapters claude keeps the .agents/skills copy' \
    "$([ -d "$WORK/inst-claude/.agents/skills" ] && echo yes || echo no)" 'yes'
assert_eq '--adapters claude adds no other tool directory' \
    "$([ -e "$WORK/inst-claude/.cursor" ] || [ -e "$WORK/inst-claude/.github" ] && echo yes || echo no)" 'no'

# Cursor reads .agents/skills natively, so there is nothing left for an adapter
# to do and the name is no longer accepted.
assert_exit 'cursor is no longer an adapter' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst-cursor" -y --adapters cursor

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

printf '\ntampered\n' >> "$WORK/inst/.agents/skills/code-quality/SKILL.md"
assert_exit '--check detects a modified file' 1 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --check

rm -f "$WORK/inst/.agents/skills/code-quality/SKILL.md"
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
                 "stacks-dotnet:--stacks dotnet:-Stacks dotnet" \
                 "skillspath:--adapters all --skills-path ~/.agents/skills:-Adapters all -SkillsPath ~/.agents/skills"; do
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

    rm -rf "$WORK/k-sh" "$WORK/k-ps"
    mkdir -p "$WORK/k-sh/game" "$WORK/k-ps/game"
    : > "$WORK/k-sh/game/project.godot"
    : > "$WORK/k-ps/game/project.godot"
    sh_install "$WORK/k-sh" -y
    ps_install -Target "$WORK/k-ps" -Yes
    assert_same_tree 'stack detection agrees (Godot project)' "$WORK/k-sh" "$WORK/k-ps"

    assert_exit 'ps --check agrees on a clean install' 0 \
        pwsh -NoProfile -File "$REPO_ROOT/install.ps1" -Target "$WORK/i-ps" -Check
else
    skip 'cross-shell build agreement' 'no pwsh'
    skip 'cross-shell install agreement' 'no pwsh'
    skip 'standards version hash agreement' 'no pwsh'
fi

# --- 12. Upgrade --------------------------------------------------------

section '12. Upgrade'

# The legacy layout is fabricated rather than generated: the code that produced it
# is gone from this tree, and what the pruner acts on is the shape on disk. The
# stamp gives --upgrade a version and a stack set to read, as a real one would.
make_legacy() {
    ml_dir="$1"
    mkdir -p "$ml_dir/standards" "$ml_dir/.cursor/rules" "$ml_dir/.claude/skills"
    cp "$REPO_ROOT"/standards/*.md "$ml_dir/standards/"
    for ml_f in "$REPO_ROOT"/standards/*.md; do
        ml_n=$(basename "$ml_f" .md)
        [ "${ml_n#_}" = "$ml_n" ] || continue
        printf -- '---\ndescription: x\nglobs:\nalwaysApply: false\n---\n\nold body\n' \
            > "$ml_dir/.cursor/rules/$ml_n.mdc"
        mkdir -p "$ml_dir/.claude/skills/$ml_n"
        printf -- '---\nname: %s\ndescription: x\n---\n\nold body\n' "$ml_n" \
            > "$ml_dir/.claude/skills/$ml_n/SKILL.md"
    done
    printf '# Agent instructions\n\n<!-- Standards version: 00000000 | stacks: all -->\n' \
        > "$ml_dir/AGENTS.md"
    # A skill of the user's own, in a directory the installer manages. It must
    # survive: the pruner may only touch names that came from standards/.
    mkdir -p "$ml_dir/.claude/skills/my-own-skill"
    printf -- '---\nname: my-own-skill\n---\nkeep me\n' \
        > "$ml_dir/.claude/skills/my-own-skill/SKILL.md"
}

assert_exit '--upgrade on an empty directory exits 2' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/dry" --upgrade
assert_exit '--upgrade with --check is refused' 2 \
    sh "$REPO_ROOT/install.sh" "$WORK/inst" --upgrade --check

# --dry-run first, on the same fixture, so the destructive run has something to do.
make_legacy "$WORK/up-dry"
LEGACY_FILES=$(count_files "$WORK/up-dry")
sh_install "$WORK/up-dry" --upgrade --dry-run
assert_eq '--upgrade --dry-run writes and removes nothing' \
    "$(count_files "$WORK/up-dry")" "$LEGACY_FILES"

make_legacy "$WORK/up"
sh_install "$WORK/up" --upgrade -y

assert_eq 'upgrade adds the skills tree' \
    "$(ls "$WORK/up/.agents/skills" 2>/dev/null | wc -l | tr -d ' ')" "$SRC_STANDARDS"
assert_eq 'upgrade removes the standards directory' \
    "$([ -e "$WORK/up/standards" ] && echo yes || echo no)" 'no'
assert_eq 'upgrade removes the retired cursor directory' \
    "$([ -e "$WORK/up/.cursor" ] && echo yes || echo no)" 'no'

# The claude adapter was inferred from the install, so its stubs are rewritten
# rather than dropped — an upgrade must not silently reduce coverage.
assert_eq 'upgrade keeps the inferred claude adapter' \
    "$(ls "$WORK/up/.claude/skills" 2>/dev/null | grep -c -v my-own-skill)" "$SRC_STANDARDS"
assert_eq 'upgrade replaces the old claude bodies with pointers' \
    "$(grep -c 'old body' "$WORK/up"/.claude/skills/code-quality/SKILL.md)" '0'
assert_eq 'upgrade leaves a skill of your own alone' \
    "$(cat "$WORK/up/.claude/skills/my-own-skill/SKILL.md" 2>/dev/null | grep -c 'keep me')" '1'

assert_exit '--check passes on an upgraded install' 0 \
    sh "$REPO_ROOT/install.sh" "$WORK/up" --check

# Second time through there is nothing left to move, and nothing may be lost.
UPGRADED=$(count_files "$WORK/up")
sh_install "$WORK/up" --upgrade -y
assert_eq 'a second upgrade is a no-op' "$(count_files "$WORK/up")" "$UPGRADED"

if [ "$HAVE_PWSH" -eq 1 ]; then
    make_legacy "$WORK/up-sh"
    make_legacy "$WORK/up-ps"
    sh_install "$WORK/up-sh" --upgrade -y
    ps_install -Target "$WORK/up-ps" -Upgrade -Yes
    assert_same_tree 'upgrade agrees across shells' "$WORK/up-sh" "$WORK/up-ps"
else
    skip 'cross-shell upgrade agreement' 'no pwsh'
fi

# --- Summary ------------------------------------------------------------

printf '\n----------------------------------------\n'
printf '%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
    printf 'Failed:%s\n' "$FAILED_NAMES"
    exit 1
fi
exit 0
