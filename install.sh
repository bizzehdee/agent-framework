#!/bin/sh
# Installs the agent instruction framework into a project or into user-level config.
#
# POSIX sh. Behaviourally identical to install.ps1.
#
# A project install adds two entries and nothing else:
#   AGENTS.md        the always-on rules and the standards trigger table
#   .agents/skills/  one skill per standard, loaded only when its trigger matches
#
# .agents/skills/ is the vendor-neutral Agent Skills location: Codex, Cursor,
# Copilot/VS Code and OpenCode load it natively, and every other tool reads
# AGENTS.md and opens the path from its table. One copy serves all of them.
#
# Claude Code is the exception - it reads only .claude/skills/ - so --adapters
# claude writes pointer stubs there. Nothing duplicates a standard's text.
#
# Usage:
#   ./install.sh <target-dir> [options]     Install into a project directory.
#   ./install.sh --user [options]           Install to user-level config (claude, codex).
#
# Options:
#   --adapters LIST  Add tool-specific directories: claude,copilot,all,none
#                    (default: none). Passing this skips the prompt.
#   --stacks LIST    Which stacks to install: all, any, dotnet, python, rust, c-cpp,
#                    node, go. Default: detected from the target project.
#   --check          Report whether an existing install matches the current
#                    standards. Writes nothing. Exit 1 if it is out of date.
#   --upgrade        Bring an existing install to the current layout: infer what
#                    was installed, regenerate it, and remove what earlier
#                    versions left behind. Implies --force.
#   --yes, -y        Accept the defaults without prompting.
#   --force          Overwrite existing files.
#   --dry-run        Report what would be written without changing the destination.
#   -h, --help       Show this help.
#
# When stdin is not a terminal, the defaults are used without prompting.
#
# Examples:
#   ./install.sh ../my-project                        AGENTS.md + .agents/skills/
#   ./install.sh ../my-project --adapters claude      also .claude/skills/ stubs
#   ./install.sh ../my-project --upgrade              migrate an older install
#   ./install.sh --user -y                            global setup, no repo files

set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$REPO_ROOT/build.sh"
[ -f "$BUILD_SCRIPT" ] || { echo "Missing build.sh next to install.sh." >&2; exit 1; }

TARGET=""
USER_SCOPE=0
ADAPTERS="none"
ADAPTERS_EXPLICIT=0
STACKS="all"
STACKS_EXPLICIT=0
CHECK=0
UPGRADE=0
ASSUME_YES=0
FORCE=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --user) USER_SCOPE=1 ;;
        --adapters) shift; [ $# -gt 0 ] || { echo "--adapters needs a value" >&2; exit 2; }
                    ADAPTERS="$1"; ADAPTERS_EXPLICIT=1 ;;
        --stacks) shift; [ $# -gt 0 ] || { echo "--stacks needs a value" >&2; exit 2; }
                  STACKS="$1"; STACKS_EXPLICIT=1 ;;
        --check) CHECK=1 ;;
        --upgrade) UPGRADE=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) [ -z "$TARGET" ] || { echo "Unexpected argument: $1" >&2; exit 2; }; TARGET="$1" ;;
    esac
    shift
done

if [ "$USER_SCOPE" -eq 1 ] && [ -n "$TARGET" ]; then
    echo "Choose either a target directory or --user, not both." >&2; exit 2
fi
if [ "$USER_SCOPE" -eq 0 ] && [ -z "$TARGET" ]; then
    echo "Usage: ./install.sh <target-dir> [options]   or   ./install.sh --user [options]" >&2; exit 2
fi
if [ "$CHECK" -eq 1 ] && [ "$UPGRADE" -eq 1 ]; then
    echo "--check reports and --upgrade rewrites. Choose one." >&2; exit 2
fi
# An upgrade replaces the files it manages by definition, so asking again for
# --force would only be a way to get it half done.
[ "$UPGRADE" -eq 0 ] || FORCE=1

# Both modes read an existing install rather than prompting for a new one.
INSPECT=0
[ "$CHECK" -eq 0 ] && [ "$UPGRADE" -eq 0 ] || INSPECT=1

HOME_DIR="${HOME:-${USERPROFILE:-}}"

# --- Resolve destination --------------------------------------------------

if [ "$USER_SCOPE" -eq 1 ]; then
    [ -n "$HOME_DIR" ] || { echo "Cannot determine the home directory." >&2; exit 1; }
    DESTINATION="$HOME_DIR"
    LABEL="user scope ($HOME_DIR)"
    # Only these two have a documented user-level file location.
    CANDIDATES="claude codex"
else
    if [ ! -d "$TARGET" ]; then
        if [ "$DRY_RUN" -eq 1 ] || [ "$CHECK" -eq 1 ]; then
            echo "Target directory does not exist: $TARGET"
        else mkdir -p "$TARGET"; fi
    fi
    if [ -d "$TARGET" ]; then DESTINATION=$(CDPATH='' cd -- "$TARGET" && pwd); else DESTINATION="$TARGET"; fi
    [ "$DESTINATION" != "$REPO_ROOT" ] || {
        echo "Target is the framework repository itself. Choose another directory." >&2; exit 2; }
    LABEL="$DESTINATION"
    CANDIDATES="claude copilot cursor codex gemini aider windsurf zed"
fi

# --- Detection ------------------------------------------------------------
# Each tool is probed for a CLI on PATH, a user config directory, an installed
# application, and a marker inside the destination project. The first hit wins
# and is reported as the evidence, so the report is auditable.

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Echoes evidence and returns 0 when found; returns 1 when not.
detect_tool() {
    dt_name="$1"
    dt_local="${LOCALAPPDATA:-$HOME_DIR/AppData/Local}"

    case "$dt_name" in
        claude)
            have_cmd claude && { echo "claude on PATH"; return 0; }
            [ -d "$HOME_DIR/.claude" ] && { echo "~/.claude"; return 0; }
            [ -d "$DESTINATION/.claude" ] && { echo ".claude in project"; return 0; }
            ;;
        codex)
            have_cmd codex && { echo "codex on PATH"; return 0; }
            [ -d "$HOME_DIR/.codex" ] && { echo "~/.codex"; return 0; }
            ;;
        copilot)
            have_cmd copilot && { echo "copilot on PATH"; return 0; }
            for d in "$HOME_DIR/.vscode/extensions" "$HOME_DIR/.vscode-insiders/extensions" \
                     "$HOME_DIR/.vscode-server/extensions"; do
                [ -d "$d" ] || continue
                if ls -d "$d"/github.copilot-* >/dev/null 2>&1; then
                    echo "VS Code Copilot extension"; return 0
                fi
            done
            [ -f "$DESTINATION/.github/copilot-instructions.md" ] && {
                echo "copilot-instructions.md in project"; return 0; }
            ;;
        cursor)
            have_cmd cursor && { echo "cursor on PATH"; return 0; }
            [ -d "$HOME_DIR/.cursor" ] && { echo "~/.cursor"; return 0; }
            [ -d "/Applications/Cursor.app" ] && { echo "/Applications/Cursor.app"; return 0; }
            [ -d "$dt_local/Programs/cursor" ] && { echo "Cursor in LOCALAPPDATA"; return 0; }
            [ -d "$DESTINATION/.cursor" ] && { echo ".cursor in project"; return 0; }
            ;;
        gemini)
            have_cmd gemini && { echo "gemini on PATH"; return 0; }
            [ -d "$HOME_DIR/.gemini" ] && { echo "~/.gemini"; return 0; }
            ;;
        aider)
            have_cmd aider && { echo "aider on PATH"; return 0; }
            [ -f "$HOME_DIR/.aider.conf.yml" ] && { echo "~/.aider.conf.yml"; return 0; }
            ;;
        windsurf)
            have_cmd windsurf && { echo "windsurf on PATH"; return 0; }
            [ -d "$HOME_DIR/.codeium/windsurf" ] && { echo "~/.codeium/windsurf"; return 0; }
            [ -d "/Applications/Windsurf.app" ] && { echo "/Applications/Windsurf.app"; return 0; }
            [ -d "$dt_local/Programs/Windsurf" ] && { echo "Windsurf in LOCALAPPDATA"; return 0; }
            ;;
        zed)
            have_cmd zed && { echo "zed on PATH"; return 0; }
            [ -d "$HOME_DIR/.config/zed" ] && { echo "~/.config/zed"; return 0; }
            [ -d "/Applications/Zed.app" ] && { echo "/Applications/Zed.app"; return 0; }
            [ -d "$dt_local/Zed" ] && { echo "Zed in LOCALAPPDATA"; return 0; }
            ;;
    esac
    return 1
}

# --- Stack detection ------------------------------------------------------
# Stack-specific standards install only into projects that match, so a Python
# repository never receives .NET rules. Marker files are searched a few levels
# deep, because projects commonly sit under src/.

detect_stacks() {
    ds_found=""
    ds_add() { case " $ds_found " in *" $1 "*) ;; *) ds_found="$ds_found $1" ;; esac; }

    ds_has() {
        find "$DESTINATION" -maxdepth 3 -name "$1" -not -path '*/node_modules/*' \
            -not -path '*/.git/*' -print 2>/dev/null | head -n 1 | grep -q .
    }

    ds_has '*.sln'          && ds_add dotnet
    ds_has '*.slnx'         && ds_add dotnet
    ds_has '*.csproj'       && ds_add dotnet
    ds_has '*.fsproj'       && ds_add dotnet
    ds_has '*.vbproj'       && ds_add dotnet
    ds_has 'global.json'    && ds_add dotnet
    ds_has 'pyproject.toml' && ds_add python
    ds_has 'setup.py'       && ds_add python
    ds_has 'requirements.txt' && ds_add python
    ds_has 'Pipfile'        && ds_add python
    ds_has 'Cargo.toml'     && ds_add rust
    ds_has 'CMakeLists.txt' && ds_add c-cpp
    ds_has '*.vcxproj'      && ds_add c-cpp
    ds_has 'meson.build'    && ds_add c-cpp
    ds_has 'package.json'   && ds_add node
    ds_has 'go.mod'         && ds_add go

    echo "$ds_found" | sed 's/^ //'
}

tool_label() {
    case "$1" in
        claude)   echo "Claude Code" ;;
        codex)    echo "OpenAI Codex" ;;
        copilot)  echo "GitHub Copilot" ;;
        cursor)   echo "Cursor" ;;
        gemini)   echo "Gemini CLI" ;;
        aider)    echo "Aider" ;;
        windsurf) echo "Windsurf" ;;
        zed)      echo "Zed" ;;
        *)        echo "$1" ;;
    esac
}

adapter_note() {
    case "$1" in
        claude)  echo ".claude/skills/    Claude Code does not read .agents/skills/" ;;
        copilot) echo ".github/           glob-attached instructions" ;;
    esac
}

if [ "$STACKS_EXPLICIT" -eq 0 ]; then
    if [ "$USER_SCOPE" -eq 1 ]; then
        # User config serves every project, so every stack is included. The
        # descriptions are stack-scoped, so a .NET standard will not trigger in a
        # Python project.
        STACKS="all"
    else
        DETECTED_STACKS=$(detect_stacks)
        if [ -n "$DETECTED_STACKS" ]; then
            # --check and --upgrade override this from the install's own stamp, so
            # printing it here would announce a set that is about to be discarded.
            [ "$INSPECT" -eq 1 ] || printf 'Detected stacks: %s\n\n' \
                "$(echo "$DETECTED_STACKS" | tr ' ' ',' | sed 's/,/, /g')"
            STACKS=$(echo "$DETECTED_STACKS" | tr ' ' ',')
        else
            if [ "$INSPECT" -eq 0 ]; then
                echo "No stack markers found. Installing universal standards only."
                echo ""
            fi
            STACKS="any"
        fi
    fi
fi

# --- Check and upgrade modes ----------------------------------------------
# Both read an existing install instead of prompting for a new one: the adapter
# set and the stack set come from what is actually on disk. Both reuse the normal
# staging build and path mappings, so no mode can disagree with another about
# where a file belongs. --check then compares instead of copying; --upgrade
# copies with --force and prunes what is left over afterwards.

if [ "$INSPECT" -eq 1 ]; then
    [ -e "$DESTINATION/AGENTS.md" ] || [ -e "$DESTINATION/.claude/CLAUDE.md" ] || \
    [ -e "$DESTINATION/.codex/AGENTS.md" ] || {
        echo "Nothing installed at $LABEL." >&2
        echo "Install first: ./install.sh $([ "$USER_SCOPE" -eq 1 ] && echo '--user' || echo "$TARGET")" >&2
        exit 2; }

    # Infer the adapter set from what is actually present, so the comparison
    # covers exactly what was installed rather than today's defaults.
    if [ "$ADAPTERS_EXPLICIT" -eq 0 ]; then
        ADAPTERS=""
        [ -d "$DESTINATION/.claude/skills" ] && ADAPTERS="$ADAPTERS,claude"
        [ -f "$DESTINATION/.github/copilot-instructions.md" ] && ADAPTERS="$ADAPTERS,copilot"
        # .cursor/rules is a retired adapter, not a current one: Cursor reads
        # .agents/skills natively now. Inferring "cursor" here would fail the
        # build, so it is only noted, and the directory is pruned on upgrade.
        ADAPTERS=$(echo "$ADAPTERS" | sed 's/^,//')
        [ -n "$ADAPTERS" ] || ADAPTERS="none"
    fi

    STAMP_FILES="$DESTINATION/AGENTS.md $DESTINATION/.claude/CLAUDE.md $DESTINATION/.codex/AGENTS.md"

    INSTALLED_VERSION=$(grep -ho 'Standards version: [0-9a-f]*' $STAMP_FILES 2>/dev/null |
        head -n 1 | sed 's/.*: //')
    [ -n "$INSTALLED_VERSION" ] || INSTALLED_VERSION="unstamped"

    # Use the stack set recorded at install time. Re-detecting would compare
    # against a different set whenever the project has no marker files but was
    # installed with an explicit --stacks.
    if [ "$STACKS_EXPLICIT" -eq 0 ]; then
        STAMPED_STACKS=$(grep -ho 'stacks: [a-z0-9,-]*' $STAMP_FILES 2>/dev/null |
            head -n 1 | sed 's/.*: //')
        [ -z "$STAMPED_STACKS" ] || STACKS="$STAMPED_STACKS"
    fi

    # The current version is read from the staging build below, so each mode
    # generates exactly once.
    if [ "$UPGRADE" -eq 1 ]; then
        echo "Upgrading: $LABEL"
        printf 'Adapters kept: %s\n' "$ADAPTERS"
        printf 'Stacks kept:   %s\n\n' "$STACKS"
    else
        echo "Checking: $LABEL"
        printf 'Adapters checked: %s\n\n' "$ADAPTERS"
    fi

    if [ "$USER_SCOPE" -eq 1 ]; then
        SELECTED_TOOLS=""
        [ -d "$DESTINATION/.claude" ] && SELECTED_TOOLS="$SELECTED_TOOLS claude"
        [ -d "$DESTINATION/.codex" ] && SELECTED_TOOLS="$SELECTED_TOOLS codex"
        SELECTED_TOOLS=$(echo "$SELECTED_TOOLS" | sed 's/^ //')
    fi
    ADAPTER_LIST="$ADAPTERS"
else

DETECTED=""
echo "Detected agentic tools:"
echo ""
for t in $CANDIDATES; do
    if evidence=$(detect_tool "$t"); then
        DETECTED="$DETECTED $t"
        printf '  [x] %-9s %-16s %s\n' "$t" "$(tool_label "$t")" "$evidence"
    else
        printf '  [ ] %-9s %-16s %s\n' "$t" "$(tool_label "$t")" "not detected"
    fi
done
DETECTED=$(echo "$DETECTED" | sed 's/^ //')
echo ""

if [ "$USER_SCOPE" -eq 1 ]; then
    # User scope has no repository to keep clean, so Claude Code skills are
    # included: they give on-demand loading with zero project footprint.
    [ -n "$DETECTED" ] || {
        echo "Neither Claude Code nor Codex detected. Nothing to set up at user level." >&2
        echo "Install into a project instead: ./install.sh <target-dir>" >&2
        exit 2; }
    SELECTED_TOOLS="$DETECTED"
    ADAPTER_LIST=""
    case " $SELECTED_TOOLS " in *" claude "*) ADAPTER_LIST="claude" ;; esac
else
    echo "Codex, Cursor, Copilot and OpenCode load .agents/skills/ natively, and every"
    echo "other tool reads AGENTS.md, so no tool-specific files are required."
    echo ""

    if [ "$ADAPTERS_EXPLICIT" -eq 0 ]; then
        echo "Optional adapters add a directory that points at .agents/skills/, for the"
        echo "two tools that need one. They never copy a standard's text:"
        echo ""
        OFFERED="claude copilot"
        idx=0
        for a in $OFFERED; do
            idx=$((idx + 1))
            mark=""
            case " $DETECTED " in *" $a "*) mark=" (detected)" ;; esac
            printf '  %s) %-9s %s%s\n' "$idx" "$a" "$(adapter_note "$a")" "$mark"
        done
        echo ""

        if [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ] && [ -t 0 ]; then
            printf "Add any? Numbers separated by spaces, or Enter for none (recommended): "
            reply=""
            read -r reply < /dev/tty || reply=""
            reply=$(echo "$reply" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            case "$reply" in
                "") ADAPTERS="none" ;;
                a|A|all) ADAPTERS="all" ;;
                *)
                    picked=""
                    for num in $(echo "$reply" | tr ',' ' '); do
                        case "$num" in
                            *[!0-9]*) echo "Not a number: $num" >&2; exit 2 ;;
                        esac
                        name=$(echo "$OFFERED" | tr ' ' '\n' | sed -n "${num}p")
                        [ -n "$name" ] || { echo "No such option: $num" >&2; exit 2; }
                        picked="$picked $name"
                    done
                    [ -n "$picked" ] || { echo "Nothing selected." >&2; exit 2; }
                    ADAPTERS=$(echo "$picked" | sed 's/^ //' | tr ' ' ',')
                    ;;
            esac
        else
            ADAPTERS="none"
            [ "$ASSUME_YES" -eq 1 ] || echo "Not a terminal: using the defaults without prompting."
        fi
        echo ""
    fi
    ADAPTER_LIST="$ADAPTERS"
fi

fi

if [ "$INSPECT" -eq 0 ]; then
    echo "Installing to: $LABEL"
    if [ "$USER_SCOPE" -eq 1 ]; then
        printf 'Tools: %s\n' "$(echo "$SELECTED_TOOLS" | tr -s ' ' | sed 's/ /, /g')"
    elif [ -z "$ADAPTER_LIST" ] || [ "$ADAPTER_LIST" = "none" ]; then
        echo "Contents: AGENTS.md + .agents/skills/ only"
    else
        printf 'Contents: AGENTS.md + .agents/skills/ + adapters (%s)\n' "$ADAPTER_LIST"
    fi
    [ "$DRY_RUN" -eq 0 ] || echo "Dry run: no files will be written."
    echo ""
fi
if [ "$UPGRADE" -eq 1 ] && [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: nothing will be written or removed."
    echo ""
fi

# --- Generate to a staging directory --------------------------------------

STAGING="${TMPDIR:-/tmp}/agent-framework-install-$$"
COUNT_DIR="$STAGING.counts"
rm -rf "$STAGING" "$COUNT_DIR"
mkdir -p "$COUNT_DIR"
trap 'rm -rf "$STAGING" "$COUNT_DIR"' EXIT INT TERM
: > "$COUNT_DIR/written"
: > "$COUNT_DIR/skipped"
: > "$COUNT_DIR/missing"
: > "$COUNT_DIR/differs"
: > "$COUNT_DIR/same"
# Every destination path the current build accounts for. The upgrade pruner needs
# it to tell a file that still belongs from one an earlier version left behind.
: > "$COUNT_DIR/expected"

# A user install has no project root, so the skills land in ~/.agents/skills and
# every generated reference has to say so.
if [ "$USER_SCOPE" -eq 1 ]; then SKILLS_PATH="~/.agents/skills"; else SKILLS_PATH=".agents/skills"; fi

sh "$BUILD_SCRIPT" --out "$STAGING" --adapters "${ADAPTER_LIST:-none}" --stacks "$STACKS" \
    --skills-path "$SKILLS_PATH" >/dev/null

# MAPPINGS holds "source-root<TAB>staged-path<TAB>destination-path" lines.
# Project installs are a straight copy. User installs relocate into the per-tool
# config directories, because there is no project root to sit in.
MAPPINGS=""
add_mapping() { MAPPINGS="$MAPPINGS$1	$2	$3
"; }

if [ "$USER_SCOPE" -eq 1 ]; then
    # One skills tree for everyone. ~/.agents/skills is the documented user-level
    # location for Codex, Cursor and Copilot/VS Code alike, so this is written
    # whichever of them is present.
    add_mapping "$STAGING" ".agents/skills" ".agents/skills"
    case " $SELECTED_TOOLS " in *" claude "*)
        # Claude Code reads neither ~/.agents/skills nor AGENTS.md at user level,
        # so it gets the stubs plus CLAUDE.md as global always-on context.
        add_mapping "$STAGING" ".claude/skills" ".claude/skills"
        add_mapping "$STAGING" "AGENTS.md" ".claude/CLAUDE.md" ;;
    esac
    case " $SELECTED_TOOLS " in *" codex "*)
        add_mapping "$STAGING" "AGENTS.md" ".codex/AGENTS.md" ;;
    esac
else
    for entry in $(ls -A "$STAGING"); do
        add_mapping "$STAGING" "$entry" "$entry"
    done
fi

# --- Copy -----------------------------------------------------------------
# POSIX sh has no function-local variables. These names are prefixed so the
# function cannot clobber the caller's loop variables while walking a directory.

copy_one() {
    cp_src="$1"; cp_dest="$2"; cp_rel="$3"
    # Recorded before any early return, so the list is complete in every mode.
    # Destination-relative, because that is the one spelling of a path both this
    # function and the leftover walk can derive without normalising anything.
    echo "$cp_rel" >> "$COUNT_DIR/expected"
    if [ "$CHECK" -eq 1 ]; then
        if [ ! -e "$cp_dest" ]; then
            echo "  missing  $cp_dest"; echo x >> "$COUNT_DIR/missing"
        elif ! cmp -s "$cp_src" "$cp_dest"; then
            echo "  differs  $cp_dest"; echo x >> "$COUNT_DIR/differs"
        else
            echo x >> "$COUNT_DIR/same"
        fi
        return
    fi
    if [ -e "$cp_dest" ] && [ "$FORCE" -eq 0 ]; then
        echo "  skip (exists) $cp_dest"
        echo x >> "$COUNT_DIR/skipped"
        return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  would write   $cp_dest"
        echo x >> "$COUNT_DIR/written"
        return
    fi
    mkdir -p "$(dirname "$cp_dest")"
    cp -f "$cp_src" "$cp_dest"
    echo "  + $cp_dest"
    echo x >> "$COUNT_DIR/written"
}

echo "$MAPPINGS" | while IFS='	' read -r map_root map_from map_to; do
    [ -n "$map_from" ] || continue
    map_src="$map_root/$map_from"
    [ -e "$map_src" ] || continue
    if [ -d "$map_src" ]; then
        ( cd "$map_src" && find . -type f -print ) | sed 's|^\./||' | while IFS= read -r rel; do
            copy_one "$map_src/$rel" "$DESTINATION/$map_to/$rel" "$map_to/$rel"
        done
    else
        copy_one "$map_src" "$DESTINATION/$map_to" "$map_to"
    fi
done

if [ "$CHECK" -eq 1 ]; then
    MISSING=$(wc -l < "$COUNT_DIR/missing" | tr -d ' ')
    DIFFERS=$(wc -l < "$COUNT_DIR/differs" | tr -d ' ')
    SAME=$(wc -l < "$COUNT_DIR/same" | tr -d ' ')

    CURRENT_VERSION=$(grep -o 'Standards version: [0-9a-f]*' "$STAGING/AGENTS.md" 2>/dev/null |
        head -n 1 | sed 's/.*: //')

    echo ""
    printf 'Installed version: %s\n' "$INSTALLED_VERSION"
    printf 'Current version:   %s\n' "${CURRENT_VERSION:-unknown}"
    printf '%s up to date, %s differ, %s missing.\n' "$SAME" "$DIFFERS" "$MISSING"
    if [ "$DIFFERS" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
        echo "Out of date. Re-install: ./install.sh $([ "$USER_SCOPE" -eq 1 ] && echo '--user' || echo "$TARGET") --force"
        exit 1
    fi
    echo "Up to date."
    exit 0
fi

WRITTEN=$(wc -l < "$COUNT_DIR/written" | tr -d ' ')
SKIPPED=$(wc -l < "$COUNT_DIR/skipped" | tr -d ' ')

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s file(s) would be written, %s skipped.\n' "$WRITTEN" "$SKIPPED"
else
    printf '%s file(s) written, %s skipped.\n' "$WRITTEN" "$SKIPPED"
fi
if [ "$SKIPPED" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    echo "Re-run with --force to overwrite existing files."
fi

# --- Leftovers ------------------------------------------------------------
# Only these directories are ever written by this installer, so only these are
# considered. Within them, only a file whose name corresponds to a source
# standard is treated as ours: a skill or rule you wrote yourself sits in the
# same directory and must survive an upgrade untouched.

MANAGED_DIRS="standards .agents/skills .claude/skills .claude/standards
.codex/standards .cursor/rules .github/instructions"

# Every source standard, including _core and those excluded by stack, so a file
# left behind by a stack change is still recognised as ours rather than yours.
SOURCE_NAMES=$(for sn in "$REPO_ROOT"/standards/*.md; do basename "$sn" .md; done)

# Collected through files rather than variables: the walk reads find's output on a
# pipe, so a subshell's assignments would not survive it, and a path holding a
# space must not be split into two.
printf '%s\n' "$SOURCE_NAMES" > "$COUNT_DIR/names"
: > "$COUNT_DIR/stale"
: > "$COUNT_DIR/foreign"

for md in $MANAGED_DIRS; do
    [ -d "$DESTINATION/$md" ] || continue
    ( cd "$DESTINATION/$md" && find . -type f -print ) | sed 's|^\./||' |
    while IFS= read -r rel; do
        grep -Fxq "$md/$rel" "$COUNT_DIR/expected" && continue
        # The standard's name is the directory for a skill, the basename otherwise.
        case "$rel" in
            */*/*)             lo_name="" ;;
            */SKILL.md)        lo_name=${rel%/SKILL.md} ;;
            */*)               lo_name="" ;;
            *.instructions.md) lo_name=${rel%.instructions.md} ;;
            *.*)               lo_name=${rel%.*} ;;
            *)                 lo_name="" ;;
        esac
        if [ -n "$lo_name" ] && grep -Fxq "$lo_name" "$COUNT_DIR/names"; then
            printf '%s\n' "$md/$rel" >> "$COUNT_DIR/stale"
        else
            printf '%s\n' "$md/$rel" >> "$COUNT_DIR/foreign"
        fi
    done
done

STALE_COUNT=$(wc -l < "$COUNT_DIR/stale" | tr -d ' ')

if [ -s "$COUNT_DIR/foreign" ]; then
    echo ""
    echo "In a directory this installer manages, but not generated by it:"
    sed 's|^|  '"$DESTINATION"'/|' "$COUNT_DIR/foreign"
    echo "Left untouched."
fi

if [ "$STALE_COUNT" -eq 0 ]; then
    if [ "$UPGRADE" -eq 1 ]; then
        echo ""
        echo "Nothing left over. The install is on the current layout."
    fi
elif [ "$UPGRADE" -eq 0 ]; then
    echo ""
    echo "Left over from an earlier layout, no longer referenced by anything:"
    sed 's|^|  '"$DESTINATION"'/|' "$COUNT_DIR/stale"
    printf 'Remove them with: ./install.sh %s --upgrade\n' \
        "$([ "$USER_SCOPE" -eq 1 ] && echo '--user' || echo "$TARGET")"
else
    echo ""
    echo "Left over from an earlier layout, to remove:"
    sed 's|^|  - '"$DESTINATION"'/|' "$COUNT_DIR/stale"

    REMOVE=1
    if [ "$DRY_RUN" -eq 1 ]; then
        REMOVE=0
        printf '%s file(s) would be removed.\n' "$STALE_COUNT"
    elif [ "$ASSUME_YES" -eq 0 ] && [ -r /dev/tty ] && [ -t 0 ]; then
        printf 'Remove these %s file(s)? [y/N] ' "$STALE_COUNT"
        confirm=""
        read -r confirm < /dev/tty || confirm=""
        case "$confirm" in
            y|Y|yes|YES) ;;
            *) REMOVE=0; echo "Left in place." ;;
        esac
    fi

    if [ "$REMOVE" -eq 1 ]; then
        while IFS= read -r o; do
            [ -n "$o" ] || continue
            rm -f "$DESTINATION/$o"
        done < "$COUNT_DIR/stale"
        # rmdir only ever removes an empty directory, so a directory still holding
        # something of yours survives without needing a second check for it.
        # Deepest first, then the parents the managed directories sat in.
        for md in $MANAGED_DIRS; do
            [ -d "$DESTINATION/$md" ] || continue
            find "$DESTINATION/$md" -type d 2>/dev/null | LC_ALL=C sort -r |
                while IFS= read -r dir; do rmdir "$dir" 2>/dev/null || true; done
        done
        for md in ".cursor" ".claude" ".codex" ".github" ".agents"; do
            rmdir "$DESTINATION/$md" 2>/dev/null || true
        done
        printf '%s file(s) removed.\n' "$STALE_COUNT"
    fi
fi
