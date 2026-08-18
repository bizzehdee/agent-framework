#!/bin/sh
# Installs the agent instruction framework into a project or into user-level config.
#
# POSIX sh. Behaviourally identical to install.ps1.
#
# A project install adds two entries and nothing else:
#   AGENTS.md     the always-on rules and the standards trigger table
#   standards/    one file per standard, read only when its trigger matches
#
# Every supported tool reads AGENTS.md, so that is a complete installation.
# Tool-specific directories (.claude/, .cursor/, .github/) are never written
# unless you ask for them with --adapters.
#
# Usage:
#   ./install.sh <target-dir> [options]     Install into a project directory.
#   ./install.sh --user [options]           Install to user-level config (claude, codex).
#
# Options:
#   --adapters LIST  Add tool-specific directories: claude,copilot,cursor,all,none
#                    (default: none). Passing this skips the prompt.
#   --yes, -y        Accept the defaults without prompting.
#   --force          Overwrite existing files.
#   --dry-run        Report what would be written without changing the destination.
#   -h, --help       Show this help.
#
# When stdin is not a terminal, the defaults are used without prompting.
#
# Examples:
#   ./install.sh ../my-project                        AGENTS.md + standards/ only
#   ./install.sh ../my-project --adapters claude      also .claude/skills/
#   ./install.sh --user -y                            global setup, no repo files

set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
BUILD_SCRIPT="$REPO_ROOT/build.sh"
[ -f "$BUILD_SCRIPT" ] || { echo "Missing build.sh next to install.sh." >&2; exit 1; }

TARGET=""
USER_SCOPE=0
ADAPTERS="none"
ADAPTERS_EXPLICIT=0
ASSUME_YES=0
FORCE=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --user) USER_SCOPE=1 ;;
        --adapters) shift; [ $# -gt 0 ] || { echo "--adapters needs a value" >&2; exit 2; }
                    ADAPTERS="$1"; ADAPTERS_EXPLICIT=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
        if [ "$DRY_RUN" -eq 1 ]; then echo "Would create target directory: $TARGET"; else mkdir -p "$TARGET"; fi
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
        claude)  echo ".claude/skills/    model-decided skill loading" ;;
        cursor)  echo ".cursor/rules/     agent-requested rule loading" ;;
        copilot) echo ".github/           glob-attached instructions" ;;
    esac
}

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
    echo "Every tool above reads AGENTS.md, so no tool-specific files are required."
    echo ""

    if [ "$ADAPTERS_EXPLICIT" -eq 0 ]; then
        echo "Optional adapters add directories to the repository, in exchange for"
        echo "on-demand loading rather than one always-present table:"
        echo ""
        OFFERED="claude cursor copilot"
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

echo "Installing to: $LABEL"
if [ "$USER_SCOPE" -eq 1 ]; then
    printf 'Tools: %s\n' "$(echo "$SELECTED_TOOLS" | tr -s ' ' | sed 's/ /, /g')"
elif [ -z "$ADAPTER_LIST" ] || [ "$ADAPTER_LIST" = "none" ]; then
    echo "Contents: AGENTS.md + standards/ only"
else
    printf 'Contents: AGENTS.md + standards/ + adapters (%s)\n' "$ADAPTER_LIST"
fi
[ "$DRY_RUN" -eq 0 ] || echo "Dry run: no files will be written."
echo ""

# --- Generate to a staging directory --------------------------------------

STAGING="${TMPDIR:-/tmp}/agent-framework-install-$$"
COUNT_DIR="$STAGING.counts"
rm -rf "$STAGING" "$COUNT_DIR"
mkdir -p "$COUNT_DIR"
trap 'rm -rf "$STAGING" "$COUNT_DIR"' EXIT INT TERM
: > "$COUNT_DIR/written"
: > "$COUNT_DIR/skipped"

sh "$BUILD_SCRIPT" --out "$STAGING" --adapters "${ADAPTER_LIST:-none}" >/dev/null

# MAPPINGS holds "source-root<TAB>staged-path<TAB>destination-path" lines.
# Project installs are a straight copy. User installs relocate into the per-tool
# config directories, because there is no project root to sit in.
MAPPINGS=""
add_mapping() { MAPPINGS="$MAPPINGS$1	$2	$3
"; }

if [ "$USER_SCOPE" -eq 1 ]; then
    case " $SELECTED_TOOLS " in *" claude "*)
        add_mapping "$STAGING" ".claude/skills" ".claude/skills"
        # Claude Code reads ~/.claude/CLAUDE.md as global always-on context.
        add_mapping "$STAGING" "AGENTS.md" ".claude/CLAUDE.md"
        add_mapping "$STAGING" "standards" ".claude/standards" ;;
    esac
    case " $SELECTED_TOOLS " in *" codex "*)
        add_mapping "$STAGING" "AGENTS.md" ".codex/AGENTS.md"
        add_mapping "$STAGING" "standards" ".codex/standards" ;;
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
    cp_src="$1"; cp_dest="$2"
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
            copy_one "$map_src/$rel" "$DESTINATION/$map_to/$rel"
        done
    else
        copy_one "$map_src" "$DESTINATION/$map_to"
    fi
done

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
