#!/bin/bash
# Tests for install.sh, uninstall.sh, hooks/inject.sh, and the Claude Code status line.
#
# Usage: bash tests/install_test.sh
# Requires bash, jq, and standard POSIX tools. Every scenario runs inside a temporary HOME,
# so the real configuration of the machine is never touched.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="$REPO_DIR/tests/fixtures"
ALL_HARNESSES="claude,opencode,codex,copilot,gemini,amp,kiro,cline,devin"
PASSED=0
FAILED=0
TEMPORARY_HOMES=""

cleanup() {
    local home
    for home in $TEMPORARY_HOMES; do
        rm -rf "$home"
    done
}
trap cleanup EXIT

pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }

check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

new_home() {
    local home
    home="$(mktemp -d)"
    TEMPORARY_HOMES="$TEMPORARY_HOMES $home"
    echo "$home"
}

run_installer() {
    local home="$1"
    shift
    HOME="$home" XDG_CONFIG_HOME="" CLAUDE_CONFIG_DIR="" CODEX_HOME="" COPILOT_HOME="" \
        GEMINI_CLI_HOME="" KIRO_HOME="" CLINE_DIR="" UNLAZIER_AI_NO_PROMPT=1 \
        bash "$REPO_DIR/install.sh" "$@"
}

run_uninstaller() {
    local home="$1"
    shift
    HOME="$home" XDG_CONFIG_HOME="" CLAUDE_CONFIG_DIR="" CODEX_HOME="" COPILOT_HOME="" \
        GEMINI_CLI_HOME="" KIRO_HOME="" CLINE_DIR="" UNLAZIER_AI_NO_PROMPT=1 \
        bash "$REPO_DIR/uninstall.sh" "$@"
}

# Lists every file with its checksum; JSON files are normalized because the installer
# rewrites them with jq formatting.
snapshot() {
    local home="$1" file
    (cd "$home" && find . -type f | sort) | while IFS= read -r file; do
        case "$file" in
            *.json) printf '%s %s\n' "$file" "$(jq -cS . "$home/$file" | cksum)" ;;
            *) printf '%s %s\n' "$file" "$(cksum < "$home/$file")" ;;
        esac
    done
}

block_count() {
    grep -cxF '<!-- unlazier-ai:start -->' "$1" 2>/dev/null || true
}

has_one_block() { [ "$(block_count "$1")" = "1" ]; }
contains_line() { grep -qxF "$2" "$1"; }
json_has() { [ "$(jq -r "$2" "$1")" = "true" ]; }
file_absent() { [ ! -e "$1" ]; }

# Principles plus one file per topic rule.
EXPECTED_RULE_FILES=11

rule_file_count() {
    find "$1" -maxdepth 1 -type f -name 'unlazier-ai*.md' | wc -l | tr -d ' '
}

has_all_rule_files() { [ "$(rule_file_count "$1")" = "$EXPECTED_RULE_FILES" ]; }

# Every rule file stays below a character limit and a line limit.
rule_files_within() {
    local folder="$1" max_characters="$2" max_lines="$3" file
    for file in "$folder"/unlazier-ai*.md; do
        [ "$(wc -m < "$file")" -lt "$max_characters" ] || return 1
        [ "$(wc -l < "$file")" -lt "$max_lines" ] || return 1
    done
}

seed_user_configuration() {
    local home="$1"
    mkdir -p "$home/.claude" "$home/.codex" "$home/.gemini" "$home/.copilot" "$home/.config/opencode" \
        "$home/.config/amp" "$home/.config/devin" "$home/.kiro/steering" "$home/Documents/Cline/Rules" "$home/.devin/rules"
    printf '# My notes\nAlways use tabs.\n' > "$home/.claude/CLAUDE.md"
    printf '# Codex notes\n' > "$home/.codex/AGENTS.md"
    printf '# Gemini notes\n' > "$home/.gemini/GEMINI.md"
    jq -n '{model: "opus", statusLine: {type: "command", command: "my-status"},
        hooks: {Stop: [{hooks: [{type: "command", command: "beep"}]}]}}' > "$home/.claude/settings.json"
    jq -n '{hooks: {UserPromptSubmit: [{hooks: [{type: "command", command: "my-codex-hook"}]}]}}' \
        > "$home/.codex/hooks.json"
    jq -n '{theme: "dark"}' > "$home/.gemini/settings.json"
}

test_install_preserves_user_content() {
    local home
    echo "install preserves existing configuration"
    home="$(new_home)"
    seed_user_configuration "$home"
    run_installer "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1

    check "CLAUDE.md untouched" test "$(cat "$home/.claude/CLAUDE.md")" = "$(printf '# My notes\nAlways use tabs.')"
    check "Codex notes kept" contains_line "$home/.codex/AGENTS.md" "# Codex notes"
    check "existing Claude hook kept" json_has "$home/.claude/settings.json" \
        '[.hooks.Stop[].hooks[].command] | index("beep") != null'
    check "existing Claude status line kept" json_has "$home/.claude/settings.json" \
        '.statusLine.command == "my-status"'
    check "unused status line script not copied" file_absent "$home/.claude/unlazier-ai/claude-statusline.sh"
    check "existing Codex hook kept" json_has "$home/.codex/hooks.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | index("my-codex-hook") != null'
    check "Gemini setting kept" json_has "$home/.gemini/settings.json" '.theme == "dark"'
}

test_install_adds_all_layers() {
    local home file
    echo "install adds the three layers to every harness"
    home="$(new_home)"
    run_installer "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1

    for file in .config/opencode/AGENTS.md .codex/AGENTS.md .copilot/copilot-instructions.md \
        .gemini/GEMINI.md .config/amp/AGENTS.md; do
        check "rules block in $file" has_one_block "$home/$file"
    done
    for file in .claude/rules .kiro/steering Documents/Cline/Rules .devin/rules; do
        check "rule files in $file" has_all_rule_files "$home/$file"
        check "rule files in $file are short" rule_files_within "$home/$file" 12000 200
    done
    check "no CLAUDE.md created" file_absent "$home/.claude/CLAUDE.md"
    for file in .claude .config/opencode .codex .copilot .gemini .config/amp .kiro Documents/Cline .devin; do
        check "payload in $file/unlazier-ai" test -f "$home/$file/unlazier-ai/reminder.md"
    done
    check "Claude prompt hook" json_has "$home/.claude/settings.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" claude prompt"))'
    check "Claude compaction hook" json_has "$home/.claude/settings.json" \
        '.hooks.SessionStart | any(.matcher == "compact")'
    check "Claude status line installed" json_has "$home/.claude/settings.json" \
        '.statusLine.command | contains("claude-statusline.sh")'
    check "Codex hooks registered" json_has "$home/.codex/hooks.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" codex prompt"))'
    check "Gemini hook registered" json_has "$home/.gemini/settings.json" \
        '[.hooks.BeforeAgent[].hooks[].command] | any(contains("inject.sh\" gemini prompt"))'
    check "Devin hook registered" json_has "$home/.config/devin/config.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" devin prompt"))'
    check "Kiro hooks" json_has "$home/.kiro/hooks/unlazier-ai.json" \
        '[.hooks[].trigger] == ["UserPromptSubmit", "PostCompact"]'
    check "Cline hook executable" test -x "$home/Documents/Cline/Hooks/UserPromptSubmit"
    check "OpenCode plugin" test -f "$home/.config/opencode/plugins/unlazier-ai.ts"
    check "Amp plugin" test -f "$home/.config/amp/plugins/unlazier-ai.ts"
    check "no backup folders" test -z "$(find "$home" -maxdepth 2 -name '*.bak*')"
}

test_reinstall_is_idempotent() {
    local home
    echo "reinstalling keeps a single copy"
    home="$(new_home)"
    seed_user_configuration "$home"
    run_installer "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1
    run_installer "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1

    check "Claude rule files written once" has_all_rule_files "$home/.claude/rules"
    check "one block in Codex AGENTS.md" has_one_block "$home/.codex/AGENTS.md"
    check "one Claude prompt hook" json_has "$home/.claude/settings.json" \
        '[.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("unlazier-ai"))] | length == 1'
    check "one Codex prompt hook" json_has "$home/.codex/hooks.json" \
        '[.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("unlazier-ai"))] | length == 1'
}

test_uninstall_restores_original_files() {
    local home before after
    echo "uninstall removes only what was added"
    home="$(new_home)"
    seed_user_configuration "$home"
    before="$(snapshot "$home")"
    run_installer "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1
    run_uninstaller "$home" --harness "$ALL_HARNESSES" >/dev/null 2>&1
    after="$(snapshot "$home")"

    check "files identical to the original" test "$before" = "$after"
}

seed_v1_installation() {
    local home="$1"
    mkdir -p "$home/.claude/rules" "$home/.claude/skills"
    sed "s|rules/|$home/.claude/rules/|g" "$FIXTURES_DIR/v1/AGENTS.md" > "$home/.claude/CLAUDE.md"
    cp "$FIXTURES_DIR/v1/rules/"*.md "$home/.claude/rules/"
    cp -R "$FIXTURES_DIR/v1/skills/"* "$home/.claude/skills/"
    printf '# edited by the user\n' >> "$home/.claude/rules/style.md"
    mkdir -p "$home/.claude/skills/my-skill"
    printf 'mine\n' > "$home/.claude/skills/my-skill/SKILL.md"
    mkdir -p "$home/.config/opencode"
    cp "$FIXTURES_DIR/v1/opencode.json" "$home/.config/opencode/opencode.json"
    mkdir -p "$home/.config/opencode/skills/bugfix"
    cp "$FIXTURES_DIR/v1/skills/bugfix/SKILL.md" "$home/.config/opencode/skills/bugfix/"
}

test_v1_leftovers_removed_with_yes() {
    local home
    echo "version 1 files are removed after confirmation"
    home="$(new_home)"
    seed_v1_installation "$home"
    run_installer "$home" --harness claude,opencode --yes >/dev/null 2>&1

    check "v1 rule removed" file_absent "$home/.claude/rules/async.md"
    check "edited v1 rule kept" test -f "$home/.claude/rules/style.md"
    check "v1 skill removed" file_absent "$home/.claude/skills/bugfix"
    check "user skill kept" test -f "$home/.claude/skills/my-skill/SKILL.md"
    check "v1 OpenCode config removed" file_absent "$home/.config/opencode/opencode.json"
    check "v1 CLAUDE.md removed" file_absent "$home/.claude/CLAUDE.md"
    check "v2 rule files installed" has_all_rule_files "$home/.claude/rules"
}

test_v1_leftovers_kept_without_confirmation() {
    local home
    echo "version 1 files are kept without confirmation"
    home="$(new_home)"
    seed_v1_installation "$home"
    run_installer "$home" --harness claude >/dev/null 2>&1

    check "v1 rule kept" test -f "$home/.claude/rules/async.md"
    check "v1 skill kept" test -d "$home/.claude/skills/bugfix"
}

# Version 2.0 wrote a block into CLAUDE.md and single or split files into the rules folders.
seed_v2_0_installation() {
    local home="$1"
    mkdir -p "$home/.claude" "$home/.kiro/steering" "$home/.devin/rules"
    printf '# My notes\n<!-- unlazier-ai:start -->\nold rules\n<!-- unlazier-ai:end -->\n' > "$home/.claude/CLAUDE.md"
    printf '<!-- unlazier-ai:start -->\nold rules\n<!-- unlazier-ai:end -->\n' > "$home/.kiro/steering/unlazier-ai.md"
    printf '<!-- unlazier-ai:start -->\nold rules\n<!-- unlazier-ai:end -->\n' > "$home/.devin/rules/unlazier-ai-rules.md"
}

test_upgrade_from_v2_0_layout() {
    local home
    echo "version 2.0 rules move to one file per rule"
    home="$(new_home)"
    seed_v2_0_installation "$home"
    run_installer "$home" --harness claude,kiro,devin >/dev/null 2>&1

    check "old block removed from CLAUDE.md" test "$(cat "$home/.claude/CLAUDE.md")" = "# My notes"
    check "Claude rule files installed" has_all_rule_files "$home/.claude/rules"
    check "old Kiro file removed" file_absent "$home/.kiro/steering/unlazier-ai.md"
    check "old Devin split file removed" file_absent "$home/.devin/rules/unlazier-ai-rules.md"
    check "Devin rule files installed" has_all_rule_files "$home/.devin/rules"
}

test_invalid_json_left_untouched() {
    local home before
    echo "an unreadable config file is never rewritten"
    home="$(new_home)"
    mkdir -p "$home/.claude"
    printf '{ "model": "opus", // comment\n}\n' > "$home/.claude/settings.json"
    before="$(cksum < "$home/.claude/settings.json")"
    run_installer "$home" --harness claude >/dev/null 2>&1

    check "settings.json unchanged" test "$before" = "$(cksum < "$home/.claude/settings.json")"
    check "rules still installed" has_all_rule_files "$home/.claude/rules"
}

# Builds a PATH with the tools the installer needs, minus jq.
path_without_jq() {
    local directory tool
    directory="$(new_home)"
    for tool in bash cat mkdir cp chmod rm mv awk grep sed tr head tail find sort cksum wc dirname mktemp rmdir; do
        ln -s "$(command -v "$tool")" "$directory/$tool"
    done
    echo "$directory"
}

test_missing_jq_installs_rules_only() {
    local home tools output
    echo "without jq, rules are installed and hooks are skipped"
    home="$(new_home)"
    tools="$(path_without_jq)"
    output="$(PATH="$tools" run_installer "$home" --harness claude,kiro 2>&1)"

    check "Claude rules installed" has_all_rule_files "$home/.claude/rules"
    check "Claude hooks skipped" file_absent "$home/.claude/settings.json"
    check "jq install hint shown" test -n "$(printf '%s' "$output" | grep 'jq is not installed')"
}

write_codex_rollout() {
    local home="$1" now="$2" timestamp
    timestamp="$(jq -rn --argjson epoch "$((now - 60))" '$epoch | todate')"
    mkdir -p "$home/.codex/sessions/2026/11/13" "$home/.codex/sessions/2026/11/14"
    printf '%s\n' '{"timestamp":"2026-11-13T00:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":1,"window_minutes":300}}}}' \
        > "$home/.codex/sessions/2026/11/13/rollout-2026-11-13T00-00-00-a.jsonl"
    jq -cn --arg timestamp "$timestamp" --argjson resets "$((now + 999))" '
        {timestamp: $timestamp, type: "event_msg", payload: {type: "token_count", rate_limits: {
            primary: {used_percent: 42.6, window_minutes: 300, resets_at: $resets},
            secondary: {used_percent: 61.2, window_minutes: 10080, resets_in_seconds: 5000}}}},
        {timestamp: $timestamp, type: "event_msg", payload: {type: "token_count", rate_limits: null}}' \
        > "$home/.codex/sessions/2026/11/14/rollout-2026-11-14T10-00-00-b.jsonl"
}

last_line() { "$@" | tail -n 1; }

test_inject_usage_lines() {
    local home now
    echo "inject reports usage from each source"
    home="$(new_home)"
    now="$(date +%s)"
    run_installer "$home" --harness claude,codex,gemini,devin,cline,kiro >/dev/null 2>&1
    mkdir -p "$home/.claude/state"
    jq -n --argjson now "$now" '{captured_at: ($now - 120),
        five_hour: {used_percentage: 24.4, resets_at: ($now + 3600)},
        seven_day: {used_percentage: 94, resets_at: ($now - 5)}}' > "$home/.claude/state/rate_limits.json"
    write_codex_rollout "$home" "$now"

    check "Claude usage line" test "$(last_line bash "$home/.claude/unlazier-ai/inject.sh" claude prompt)" \
        = "Usage: 5h 24% | weekly unknown (source: Claude Code status line, 2 min old)"
    check "Codex usage line" test "$(last_line bash "$home/.codex/unlazier-ai/inject.sh" codex prompt)" \
        = "Usage: 5h 43% | weekly 61% (source: Codex session log, 1 min old)"
    check "Kiro usage unknown" test "$(last_line bash "$home/.kiro/unlazier-ai/inject.sh" kiro prompt)" \
        = "Usage: unknown (this tool does not expose usage windows)"

    jq --argjson old "$((now - 3600))" '.captured_at = $old' "$home/.claude/state/rate_limits.json" \
        > "$home/stale.json" && mv "$home/stale.json" "$home/.claude/state/rate_limits.json"
    check "stale Claude reading is unknown" test "$(last_line bash "$home/.claude/unlazier-ai/inject.sh" claude prompt)" \
        = "Usage: unknown (no usage reading from the last 15 minutes)"
}

test_inject_output_formats() {
    local home
    echo "inject prints the shape each harness expects"
    home="$(new_home)"
    run_installer "$home" --harness claude,gemini,devin,cline >/dev/null 2>&1

    check "Claude prompt is the reminder text" test "$(bash "$home/.claude/unlazier-ai/inject.sh" claude prompt | head -n 1)" \
        = "Unlazier AI rules are active for this session."
    check "Claude compaction starts with the principles" test \
        "$(bash "$home/.claude/unlazier-ai/inject.sh" claude compact | head -n 1)" = "# Global Agent Rules"
    check "Gemini output is JSON" json_has <(bash "$home/.gemini/unlazier-ai/inject.sh" gemini prompt) \
        '.hookSpecificOutput.additionalContext | startswith("Unlazier AI rules")'
    check "Devin output is JSON" json_has <(bash "$home/.devin/unlazier-ai/inject.sh" devin prompt) \
        '.hookSpecificOutput.additionalContext | startswith("Unlazier AI rules")'
    check "Cline output is JSON" json_has <(bash "$home/Documents/Cline/unlazier-ai/inject.sh" cline prompt) \
        '.contextModification | startswith("Unlazier AI rules")'
    check "unknown event fails" test "$(bash "$home/.claude/unlazier-ai/inject.sh" claude other >/dev/null 2>&1; echo $?)" = "2"
}

test_statusline_saves_usage() {
    local home now output
    echo "Claude status line shows and saves usage"
    home="$(new_home)"
    run_installer "$home" --harness claude >/dev/null 2>&1
    now="$(date +%s)"
    output="$(jq -cn --argjson now "$now" '{rate_limits: {
        five_hour: {used_percentage: 24, resets_at: ($now + 600)},
        seven_day: {used_percentage: 94, resets_at: ($now + 90000)}}}' \
        | bash "$home/.claude/unlazier-ai/claude-statusline.sh")"

    check "status line shows the 5-hour window" test -n "$(printf '%s' "$output" | grep 'Session 5h: .* 24%')"
    check "usage saved for the hook" json_has "$home/.claude/state/rate_limits.json" \
        '.five_hour.used_percentage == 24 and (.captured_at | type) == "number"'
    check "broken input degrades" test "$(printf 'garbage' | bash "$home/.claude/unlazier-ai/claude-statusline.sh")" \
        = "Usage: no data"
}

main() {
    command -v jq >/dev/null 2>&1 || { echo "jq is required to run these tests" >&2; exit 1; }
    test_install_preserves_user_content
    test_install_adds_all_layers
    test_reinstall_is_idempotent
    test_uninstall_restores_original_files
    test_v1_leftovers_removed_with_yes
    test_v1_leftovers_kept_without_confirmation
    test_upgrade_from_v2_0_layout
    test_invalid_json_left_untouched
    test_missing_jq_installs_rules_only
    test_inject_usage_lines
    test_inject_output_formats
    test_statusline_saves_usage
    echo
    echo "$PASSED passed, $FAILED failed"
    [ "$FAILED" -eq 0 ]
}

main
