#!/bin/bash
# Unlazier AI installer for Linux and macOS.
#
# Usage:
#   ./install.sh [--harness <names|all>] [--yes] [--uninstall]
#   curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash
#
#   --harness    comma-separated names (claude,opencode,codex,copilot,gemini,amp,kiro,cline,devin)
#                or "all". Without it, an interactive menu is shown.
#   --yes        answer "yes" to confirmations (removal of files left by version 1).
#   --uninstall  remove Unlazier AI from the selected harnesses.
#
# Every harness receives the same three layers: the rules (a marked block in its global
# instructions file), a reinforcement hook that re-injects a short reminder, and a usage
# line inside that reminder. Existing user content is never replaced and no backups are made.

set -euo pipefail

REPO="fco3lho/unlazier-ai"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

ALL_HARNESSES="claude opencode codex copilot gemini amp kiro cline devin"
RULE_NAMES="structure correctness style completeness performance testability async naming documentation parallelism"
PAYLOAD_FILES="AGENTS.md reminder.md hooks/inject.sh statusline/claude-statusline.sh plugins/opencode.ts plugins/amp.ts"
MARKER_START="<!-- unlazier-ai:start -->"
MARKER_END="<!-- unlazier-ai:end -->"
PAYLOAD_DIR_NAME="unlazier-ai"

# Version 1 files are recognized by checksum (POSIX cksum: CRC and size) so that files the
# user edited are never removed.
V1_RULE_CHECKSUMS="structure 777963179 1423
correctness 1739082089 1122
style 1567952051 1306
completeness 113781707 1096
performance 1314288283 723
testability 3565322618 948
async 3753529978 969
naming 1175597733 1247
documentation 927091628 979"
V1_SKILL_CHECKSUMS="bugfix 1429495546 1065
code-review 4077940051 2292
refactoring 3722468995 1349"
V1_OPENCODE_CONFIG='{"$schema":"https://opencode.ai/config.json","instructions":["~/.config/opencode/AGENTS.md","~/.config/opencode/rules/*.md"],"skills":{"paths":["~/.config/opencode/skills"]}}'
V1_GLOBAL_HEADING="# Global Agent Rules"

MODE="install"
ASSUME_YES=false
REQUESTED_HARNESSES=""
SOURCE_DIR=""
DOWNLOAD_DIR=""
HAS_JQ=false
NOTICES=""

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
add_notice() { NOTICES="${NOTICES}  - $*
"; }

# ---------------------------------------------------------------------------
# Harness adapters: the only part that differs between harnesses.
# ---------------------------------------------------------------------------

harness_label() {
    case "$1" in
        claude) echo "Claude Code" ;;
        opencode) echo "OpenCode" ;;
        codex) echo "Codex CLI" ;;
        copilot) echo "GitHub Copilot CLI" ;;
        gemini) echo "Gemini CLI" ;;
        amp) echo "Amp" ;;
        kiro) echo "Kiro" ;;
        cline) echo "Cline" ;;
        devin) echo "Devin Desktop (formerly Windsurf)" ;;
        *) die "unknown harness '$1'" ;;
    esac
}

harness_home() {
    case "$1" in
        claude) echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
        opencode) echo "${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ;;
        codex) echo "${CODEX_HOME:-$HOME/.codex}" ;;
        copilot) echo "${COPILOT_HOME:-$HOME/.copilot}" ;;
        gemini) echo "${GEMINI_CLI_HOME:-$HOME}/.gemini" ;;
        amp) echo "${XDG_CONFIG_HOME:-$HOME/.config}/amp" ;;
        kiro) echo "${KIRO_HOME:-$HOME/.kiro}" ;;
        cline) echo "$HOME/Documents/Cline" ;;
        devin) echo "$HOME/.devin" ;;
        *) die "unknown harness '$1'" ;;
    esac
}

harness_binaries() {
    case "$1" in
        kiro) echo "kiro-cli kiro" ;;
        devin) echo "devin-desktop devin windsurf" ;;
        *) echo "$1" ;;
    esac
}

# Prints "<file> <part>" lines: where the rules block goes and which part of the rules it holds.
rule_targets() {
    local home
    home="$(harness_home "$1")"
    case "$1" in
        claude) echo "$home/CLAUDE.md all" ;;
        opencode|codex|amp) echo "$home/AGENTS.md all" ;;
        copilot) echo "$home/copilot-instructions.md all" ;;
        gemini) echo "$home/GEMINI.md all" ;;
        kiro) echo "$home/steering/unlazier-ai.md all" ;;
        cline) echo "$home/Rules/unlazier-ai.md all" ;;
        # Devin limits each rules file to 12,000 characters, so the rules are split in two.
        devin)
            echo "$home/rules/unlazier-ai-principles.md principles"
            echo "$home/rules/unlazier-ai-rules.md topics"
            ;;
        *) die "unknown harness '$1'" ;;
    esac
}

is_detected() {
    local binary
    for binary in $(harness_binaries "$1"); do
        command -v "$binary" >/dev/null 2>&1 && return 0
    done
    [ -d "$(harness_home "$1")" ]
}

hook_command() {
    printf 'bash "%s/%s/inject.sh" %s %s' "$(harness_home "$1")" "$PAYLOAD_DIR_NAME" "$1" "$2"
}

# Claude Code, Codex, Gemini CLI, and Devin share the same hook layout:
# {"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "..."}]}]}}.
# Entries whose command mentions unlazier-ai are ours; everything else is left untouched.
# shellcheck disable=SC2016  # jq programs, not shell expansions
JQ_HOOK_HELPERS='
def without_ours:
    if type == "array" then
        map(if (.hooks | type) == "array"
            then .hooks |= map(select((.command // "") | tostring | contains("unlazier-ai") | not))
            else . end)
        | map(select((.hooks | type) != "array" or (.hooks | length) > 0))
    else . end;
def add_hook($event; $matcher; $command):
    .hooks[$event] = (((.hooks // {})[$event] // []) | without_ours)
        + [(if $matcher == "" then {} else {matcher: $matcher} end)
           + {hooks: [{type: "command", command: $command}]}];
def remove_ours:
    if (.hooks | type) == "object" then
        .hooks |= (with_entries(.value |= without_ours)
            | with_entries(select((.value | type) != "array" or (.value | length) > 0)))
        | if .hooks == {} then del(.hooks) else . end
    else . end;
'

# Applies a jq program to a JSON config file in place. A missing file starts as {}; an
# unreadable one is left untouched so a hand-edited config is never damaged.
update_json_file() {
    local file="$1" program="$2"
    shift 2
    local input="{}" temporary_file
    if [ -f "$file" ]; then
        if ! jq empty "$file" >/dev/null 2>&1; then
            warn "$file is not valid JSON; skipped. Add the Unlazier AI hook by hand (see README)."
            return 1
        fi
        input="$(cat "$file")"
        # jq reads a blank file as no input at all, which would empty it on write.
        [ -n "$(printf '%s' "$input" | tr -d '[:space:]')" ] || input="{}"
    fi
    mkdir -p "$(dirname "$file")"
    temporary_file="$file.unlazier-ai.tmp"
    # Explicit checks: callers run this inside conditions, where errexit does not apply.
    if ! printf '%s' "$input" | jq "$@" "$JQ_HOOK_HELPERS $program" > "$temporary_file"; then
        rm -f "$temporary_file"
        warn "could not update $file; it was left unchanged."
        return 1
    fi
    mv "$temporary_file" "$file"
}

# Removes our entries; deletes the file if nothing else remains in it. A file without our
# entries is not rewritten, so its formatting stays as the user left it.
clean_json_file() {
    local file="$1" program="$2"
    [ -f "$file" ] && grep -q "unlazier-ai" "$file" || return 0
    update_json_file "$file" "$program" || return 0
    if [ "$(jq -c . "$file")" = "{}" ]; then
        rm -f "$file"
    fi
}

register_hooks() {
    local harness="$1" home
    home="$(harness_home "$harness")"
    case "$harness" in
        claude)
            update_json_file "$home/settings.json" \
                'add_hook("UserPromptSubmit"; ""; $prompt) | add_hook("SessionStart"; "compact"; $compact)' \
                --arg prompt "$(hook_command claude prompt)" --arg compact "$(hook_command claude compact)"
            ;;
        codex)
            update_json_file "$home/hooks.json" \
                'add_hook("UserPromptSubmit"; ""; $prompt) | add_hook("SessionStart"; "compact"; $compact)' \
                --arg prompt "$(hook_command codex prompt)" --arg compact "$(hook_command codex compact)" \
                && add_notice "Codex: open Codex and run /hooks once to trust the Unlazier AI hooks."
            ;;
        gemini)
            update_json_file "$home/settings.json" \
                'add_hook("BeforeAgent"; ""; $prompt)' \
                --arg prompt "$(hook_command gemini prompt)"
            ;;
        devin)
            # Devin documents no output format for PostCompaction, so only the prompt hook is used.
            update_json_file "$(devin_hooks_file)" \
                'add_hook("UserPromptSubmit"; ""; $prompt)' \
                --arg prompt "$(hook_command devin prompt)"
            ;;
        kiro)
            mkdir -p "$home/hooks"
            jq -n --arg prompt "$(hook_command kiro prompt)" --arg compact "$(hook_command kiro compact)" '
                {version: "v1", hooks: [
                    {name: "unlazier-ai-prompt", trigger: "UserPromptSubmit",
                     action: {type: "command", command: $prompt}, timeout: 30},
                    {name: "unlazier-ai-compact", trigger: "PostCompact",
                     action: {type: "command", command: $compact}, timeout: 30}]}' \
                > "$home/hooks/unlazier-ai.json"
            ;;
        cline)
            write_cline_hook "$home/Hooks/UserPromptSubmit" \
                && add_notice "Cline: turn on 'Enable Hooks' in Cline Feature Settings so the reminder is re-injected."
            ;;
        opencode|amp)
            install_plugin "$harness"
            ;;
        copilot)
            add_notice "Copilot CLI: rules installed; Copilot ignores prompt-hook output, so there is no reminder hook."
            ;;
        *) die "unknown harness '$harness'" ;;
    esac
}

unregister_hooks() {
    local harness="$1" home
    home="$(harness_home "$harness")"
    case "$harness" in
        claude|gemini) clean_json_file "$home/settings.json" 'remove_ours' ;;
        codex) clean_json_file "$home/hooks.json" 'remove_ours' ;;
        devin) clean_json_file "$(devin_hooks_file)" 'remove_ours' ;;
        kiro) rm -f "$home/hooks/unlazier-ai.json" ;;
        cline) remove_cline_hook "$home/Hooks/UserPromptSubmit" ;;
        opencode) rm -f "$home/plugins/unlazier-ai.ts" ;;
        amp) rm -f "$home/plugins/unlazier-ai.ts" ;;
        copilot) ;;
        *) die "unknown harness '$harness'" ;;
    esac
}

devin_hooks_file() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/devin/config.json"
}

# Cline runs an executable named after the event; if the user already has one, it is kept
# and the reminder is not wired in, because one event can only have one script.
write_cline_hook() {
    local hook_file="$1"
    if [ -f "$hook_file" ] && ! grep -q "unlazier-ai" "$hook_file"; then
        warn "$hook_file already exists; the Cline reminder hook was not installed."
        return 1
    fi
    mkdir -p "$(dirname "$hook_file")"
    printf '#!/bin/bash\nexec %s\n' "$(hook_command cline prompt)" > "$hook_file"
    chmod +x "$hook_file"
}

remove_cline_hook() {
    local hook_file="$1"
    if [ -f "$hook_file" ] && grep -q "unlazier-ai" "$hook_file"; then
        rm -f "$hook_file"
    fi
}

install_plugin() {
    local harness="$1" home
    home="$(harness_home "$harness")"
    mkdir -p "$home/plugins"
    case "$harness" in
        opencode) cp "$SOURCE_DIR/plugins/opencode.ts" "$home/plugins/unlazier-ai.ts" ;;
        amp) cp "$SOURCE_DIR/plugins/amp.ts" "$home/plugins/unlazier-ai.ts" ;;
        *) die "no plugin for '$harness'" ;;
    esac
}

# Claude Code passes usage windows only to the status line, so the status line is the usage
# source. An existing status line is never replaced.
install_statusline() {
    local home settings
    home="$(harness_home claude)"
    settings="$home/settings.json"
    if [ -f "$settings" ] && [ "$(jq 'has("statusLine")' "$settings" 2>/dev/null)" = "true" ]; then
        [ -f "$home/state/rate_limits.json" ] \
            || add_notice "Claude Code: you already have a status line, so it was kept. To give the agent its usage, make it save the 'rate_limits' it receives to $home/state/rate_limits.json (see README)."
        return 1
    fi
    update_json_file "$settings" '.statusLine = {type: "command", command: $command}' \
        --arg command "bash \"$home/$PAYLOAD_DIR_NAME/claude-statusline.sh\""
}

uninstall_statusline() {
    local settings
    settings="$(harness_home claude)/settings.json"
    clean_json_file "$settings" \
        'if ((.statusLine.command // "") | contains("unlazier-ai")) then del(.statusLine) else . end'
}

# ---------------------------------------------------------------------------
# Rules layer: a marked block inside the harness's instructions file.
# ---------------------------------------------------------------------------

render_part() {
    local part="$1" name
    case "$part" in
        principles) cat "$SOURCE_DIR/AGENTS.md" ;;
        topics)
            for name in $RULE_NAMES; do
                echo
                cat "$SOURCE_DIR/rules/$name.md"
            done
            ;;
        all)
            render_part principles
            render_part topics
            ;;
        *) die "unknown rules part '$part'" ;;
    esac
}

# Replaces the block between the markers, or appends it when the file has none.
write_block() {
    local file="$1" part="$2" block_file temporary_file
    mkdir -p "$(dirname "$file")"
    block_file="$(mktemp)"
    {
        echo "$MARKER_START"
        render_part "$part"
        echo "$MARKER_END"
    } > "$block_file"

    if [ -f "$file" ] && grep -qxF "$MARKER_START" "$file"; then
        temporary_file="$file.unlazier-ai.tmp"
        awk -v start="$MARKER_START" -v end="$MARKER_END" -v block="$block_file" '
            $0 == start { while ((getline line < block) > 0) print line; skipping = 1; next }
            skipping && $0 == end { skipping = 0; next }
            !skipping { print }
        ' "$file" > "$temporary_file" || { rm -f "$temporary_file" "$block_file"; die "could not update $file"; }
        mv "$temporary_file" "$file"
    else
        # A file without a final newline would glue the marker to its last line.
        if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
            echo >> "$file"
        fi
        cat "$block_file" >> "$file"
    fi
    rm -f "$block_file"
}

# Removes the block; deletes the file when only whitespace is left.
remove_block() {
    local file="$1" temporary_file
    [ -f "$file" ] && grep -qxF "$MARKER_START" "$file" || return 0
    temporary_file="$file.unlazier-ai.tmp"
    awk -v start="$MARKER_START" -v end="$MARKER_END" '
        $0 == start { skipping = 1; next }
        skipping && $0 == end { skipping = 0; next }
        !skipping { print }
    ' "$file" > "$temporary_file" || { rm -f "$temporary_file"; die "could not update $file"; }
    mv "$temporary_file" "$file"
    if ! grep -q '[^[:space:]]' "$file"; then
        rm -f "$file"
    fi
}

# Copies the files the hook reads into <harness home>/unlazier-ai/.
install_payload() {
    local harness="$1" target
    target="$(harness_home "$harness")/$PAYLOAD_DIR_NAME"
    mkdir -p "$target"
    cp "$SOURCE_DIR/AGENTS.md" "$SOURCE_DIR/reminder.md" "$SOURCE_DIR/hooks/inject.sh" "$target/"
    chmod +x "$target/inject.sh"
    if [ "$harness" = "claude" ]; then
        cp "$SOURCE_DIR/statusline/claude-statusline.sh" "$target/"
        chmod +x "$target/claude-statusline.sh"
    fi
}

remove_payload() {
    local target
    target="$(harness_home "$1")/$PAYLOAD_DIR_NAME"
    # The folder holds only files this installer copied, so removing it whole is safe.
    if [ -d "$target" ]; then
        rm -rf "$target"
    fi
}

# ---------------------------------------------------------------------------
# Version 1 leftovers (Claude Code and OpenCode only).
# ---------------------------------------------------------------------------

matches_checksum() {
    local file="$1" expected="$2"
    [ -f "$file" ] && [ "$(cksum < "$file" | awk '{print $1" "$2}')" = "$expected" ]
}

find_v1_leftovers() {
    local harness="$1" home global_file name crc size
    [ "$harness" = "claude" ] || [ "$harness" = "opencode" ] || return 0
    home="$(harness_home "$harness")"

    global_file="$home/AGENTS.md"
    [ "$harness" = "claude" ] && global_file="$home/CLAUDE.md"
    if [ -f "$global_file" ] && [ "$(head -n 1 "$global_file")" = "$V1_GLOBAL_HEADING" ] \
        && ! grep -qxF "$MARKER_START" "$global_file"; then
        echo "$global_file"
    fi

    while read -r name crc size; do
        matches_checksum "$home/rules/$name.md" "$crc $size" && echo "$home/rules/$name.md"
    done <<EOF
$V1_RULE_CHECKSUMS
EOF

    while read -r name crc size; do
        if matches_checksum "$home/skills/$name/SKILL.md" "$crc $size" \
            && [ "$(find "$home/skills/$name" -type f | wc -l | tr -d ' ')" = "1" ]; then
            echo "$home/skills/$name"
        fi
    done <<EOF
$V1_SKILL_CHECKSUMS
EOF

    if [ "$harness" = "opencode" ] && [ "$HAS_JQ" = true ] && [ -f "$home/opencode.json" ] \
        && [ "$(jq -cS . "$home/opencode.json" 2>/dev/null)" = "$(printf '%s' "$V1_OPENCODE_CONFIG" | jq -cS .)" ]; then
        echo "$home/opencode.json"
    fi
    return 0
}

remove_v1_leftovers() {
    local leftovers="$1" path
    [ -n "$leftovers" ] || return 0
    log ""
    log "Files from Unlazier AI version 1 were found:"
    printf '%s\n' "$leftovers" | sed 's/^/  - /'
    log "Version 2 replaces them. If you added your own notes to any of these files, answer 'n'."
    if ! confirm "Remove these files?"; then
        add_notice "Version 1 files were kept; rules may load twice until you remove them."
        return 0
    fi
    while IFS= read -r path; do
        rm -rf "$path"
        rmdir "$(dirname "$path")" 2>/dev/null || true
    done <<EOF
$leftovers
EOF
}

# ---------------------------------------------------------------------------
# Interaction and setup.
# ---------------------------------------------------------------------------

# Reads one line from the terminal even when the script itself arrives through a pipe.
# UNLAZIER_AI_NO_PROMPT=1 behaves as if no terminal were attached (used by automation and tests).
read_from_terminal() {
    local answer
    [ "${UNLAZIER_AI_NO_PROMPT:-}" = "1" ] && return 1
    { exec 3</dev/tty; } 2>/dev/null || return 1
    IFS= read -r answer <&3 || answer=""
    exec 3<&-
    printf '%s' "$answer"
}

confirm() {
    local answer
    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi
    printf '%s [y/N] ' "$1"
    answer="$(read_from_terminal)" || { echo; return 1; }
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

validate_harnesses() {
    local name
    for name in $1; do
        case " $ALL_HARNESSES " in
            *" $name "*) ;;
            *) die "unknown harness '$name'. Valid names: $ALL_HARNESSES" ;;
        esac
    done
}

select_harnesses() {
    local detected="" harness index=1 marker answer chosen="" number
    if [ -n "$REQUESTED_HARNESSES" ]; then
        if [ "$REQUESTED_HARNESSES" = "all" ]; then
            echo "$ALL_HARNESSES"
        else
            validate_harnesses "$(echo "$REQUESTED_HARNESSES" | tr ',' ' ')"
            echo "$REQUESTED_HARNESSES" | tr ',' ' '
        fi
        return 0
    fi

    for harness in $ALL_HARNESSES; do
        is_detected "$harness" && detected="$detected $harness"
    done

    {
        log ""
        log "Choose the tools to $MODE Unlazier AI for (* = found on this computer):"
        for harness in $ALL_HARNESSES; do
            marker=" "
            case " $detected " in *" $harness "*) marker="*" ;; esac
            log "  $index) $marker $(harness_label "$harness")"
            index=$((index + 1))
        done
        printf 'Type numbers separated by spaces, "all", or press Enter for the tools marked with *: '
    } >&2
    if ! answer="$(read_from_terminal)"; then
        echo >&2
        [ -n "$detected" ] || die "no tool was found and no terminal is available; pass --harness <names>."
        echo "$detected"
        return 0
    fi

    case "$answer" in
        "") chosen="$detected" ;;
        all) chosen="$ALL_HARNESSES" ;;
        *)
            for number in $answer; do
                case "$number" in
                    *[!0-9]*|"") die "'$number' is not a number from the list." ;;
                esac
                # awk's field 0 is the whole line, so 0 would select every tool.
                [ "$number" -ge 1 ] || die "$number is not in the list."
                harness="$(echo "$ALL_HARNESSES" | awk -v position="$number" '{print $position}')"
                [ -n "$harness" ] || die "$number is not in the list."
                chosen="$chosen $harness"
            done
            ;;
    esac
    [ -n "$chosen" ] || die "no tool selected."
    echo "$chosen"
}

prepare_source() {
    local script_path="${BASH_SOURCE[0]:-}" relative_path
    if [ -n "$script_path" ] && [ -f "$script_path" ]; then
        SOURCE_DIR="$(cd "$(dirname "$script_path")" && pwd)"
        if [ -f "$SOURCE_DIR/AGENTS.md" ] && [ -f "$SOURCE_DIR/hooks/inject.sh" ]; then
            return 0
        fi
    fi
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
    DOWNLOAD_DIR="$(mktemp -d)"
    trap 'rm -rf "$DOWNLOAD_DIR"' EXIT
    log "Downloading Unlazier AI from $RAW_BASE..."
    for relative_path in $PAYLOAD_FILES $(for name in $RULE_NAMES; do echo "rules/$name.md"; done); do
        mkdir -p "$DOWNLOAD_DIR/$(dirname "$relative_path")"
        curl -fsSL "$RAW_BASE/$relative_path" -o "$DOWNLOAD_DIR/$relative_path" \
            || die "failed to download $relative_path"
    done
    SOURCE_DIR="$DOWNLOAD_DIR"
}

print_jq_help() {
    local command="your package manager"
    if command -v brew >/dev/null 2>&1; then command="brew install jq"
    elif command -v apt-get >/dev/null 2>&1; then command="sudo apt-get install -y jq"
    elif command -v dnf >/dev/null 2>&1; then command="sudo dnf install -y jq"
    elif command -v pacman >/dev/null 2>&1; then command="sudo pacman -S jq"
    elif command -v zypper >/dev/null 2>&1; then command="sudo zypper install -y jq"
    elif command -v apk >/dev/null 2>&1; then command="sudo apk add jq"
    fi
    add_notice "jq is not installed, so the reminder hooks and the Claude Code status line were skipped. Install it with: $command - then run this installer again."
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --harness)
                [ "$#" -ge 2 ] || die "--harness needs a value"
                REQUESTED_HARNESSES="$2"
                shift 2
                ;;
            --yes) ASSUME_YES=true; shift ;;
            --uninstall) MODE="uninstall"; shift ;;
            -h|--help)
                sed -n '2,15p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'
                exit 0
                ;;
            *) die "unknown option '$1' (see --help)" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Per-harness pipelines: identical steps for every harness.
# ---------------------------------------------------------------------------

harness_warnings() {
    local harness="$1" home
    home="$(harness_home "$harness")"
    case "$harness" in
        codex)
            [ -f "$home/AGENTS.override.md" ] \
                && add_notice "Codex: $home/AGENTS.override.md exists, and Codex ignores AGENTS.md while it does."
            ;;
        opencode)
            [ -f "$(harness_home claude)/CLAUDE.md" ] && [ ! -f "$home/AGENTS.md" ] \
                && add_notice "OpenCode: it stops reading ~/.claude/CLAUDE.md once $home/AGENTS.md exists."
            ;;
    esac
    return 0
}

install_harness() {
    local harness="$1" file part
    log ""
    log "$(harness_label "$harness"):"
    harness_warnings "$harness"
    install_payload "$harness"
    while read -r file part; do
        write_block "$file" "$part"
        log "  rules      -> $file"
    done <<EOF
$(rule_targets "$harness")
EOF
    case "$harness" in
        opencode|amp|copilot)
            register_hooks "$harness"
            ;;
        *)
            if [ "$HAS_JQ" = true ] && register_hooks "$harness"; then
                log "  reminder   -> hook registered"
            fi
            ;;
    esac
    if [ "$harness" = "claude" ] && [ "$HAS_JQ" = true ] && install_statusline; then
        log "  usage      -> status line"
    fi
}

uninstall_harness() {
    local harness="$1" file part
    log ""
    log "$(harness_label "$harness"):"
    while read -r file part; do
        remove_block "$file"
    done <<EOF
$(rule_targets "$harness")
EOF
    case "$harness" in
        claude|codex|gemini|devin)
            if [ "$HAS_JQ" = true ]; then
                unregister_hooks "$harness"
                [ "$harness" = "claude" ] && uninstall_statusline
            else
                add_notice "$(harness_label "$harness"): install jq and run the uninstaller again to remove the hook entries."
            fi
            ;;
        *) unregister_hooks "$harness" ;;
    esac
    remove_payload "$harness"
    log "  removed"
}

main() {
    local harnesses harness leftovers=""
    parse_args "$@"
    command -v jq >/dev/null 2>&1 && HAS_JQ=true
    harnesses="$(select_harnesses)"

    if [ "$MODE" = "uninstall" ]; then
        for harness in $harnesses; do
            uninstall_harness "$harness"
        done
    else
        prepare_source
        [ "$HAS_JQ" = true ] || print_jq_help
        for harness in $harnesses; do
            leftovers="$leftovers$(find_v1_leftovers "$harness")
"
        done
        remove_v1_leftovers "$(printf '%s' "$leftovers" | sed '/^$/d')"
        for harness in $harnesses; do
            install_harness "$harness"
        done
    fi

    if [ -n "$NOTICES" ]; then
        log ""
        log "Notes:"
        printf '%s' "$NOTICES"
    fi
    log ""
    log "Done. Restart your tools for the changes to take effect."
}

main "$@"
