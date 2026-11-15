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
        GEMINI_CLI_HOME="" KIRO_HOME="" CLINE_DIR="" UNLAZIER_NO_PROMPT=1 \
        bash "$REPO_DIR/install.sh" "$@"
}

run_uninstaller() {
    local home="$1"
    shift
    HOME="$home" XDG_CONFIG_HOME="" CLAUDE_CONFIG_DIR="" CODEX_HOME="" COPILOT_HOME="" \
        GEMINI_CLI_HOME="" KIRO_HOME="" CLINE_DIR="" UNLAZIER_NO_PROMPT=1 \
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
    grep -cxF '<!-- unlazier:start -->' "$1" 2>/dev/null || true
}

has_one_block() { [ "$(block_count "$1")" = "1" ]; }
contains_line() { grep -qxF "$2" "$1"; }
json_has() { [ "$(jq -r "$2" "$1")" = "true" ]; }
file_absent() { [ ! -e "$1" ]; }

# True when the hook config has exactly one Unlazier alert for the event (and matcher).
has_alert_hook() {
    local file="$1" event="$2" matcher="${3:-}"
    [ "$(jq -r --arg event "$event" --arg matcher "$matcher" '
        [(.hooks[$event] // [])[] | select((.matcher // "") == $matcher)
         | .hooks[].command | select(endswith("/unlazier/alert.sh\""))] | length == 1' "$file")" = "true" ]
}

# Principles plus one file per topic rule.
EXPECTED_RULE_FILES=11

rule_file_count() {
    find "$1" -maxdepth 1 -type f -name 'unlazier*.md' | wc -l | tr -d ' '
}

has_all_rule_files() { [ "$(rule_file_count "$1")" = "$EXPECTED_RULE_FILES" ]; }

# Every rule file stays below a character limit and a line limit.
rule_files_within() {
    local folder="$1" max_characters="$2" max_lines="$3" file
    for file in "$folder"/unlazier*.md; do
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
    check "unused status line script not copied" file_absent "$home/.claude/unlazier/claude-statusline.sh"
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
        check "payload in $file/unlazier" test -f "$home/$file/unlazier/reminder.md"
    done
    check "Claude prompt hook" json_has "$home/.claude/settings.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" claude prompt"))'
    check "Claude compaction hook" json_has "$home/.claude/settings.json" \
        '.hooks.SessionStart | any(.matcher == "compact")'
    check "Claude status line installed" json_has "$home/.claude/settings.json" \
        '.statusLine.command | contains("claude-statusline.sh")'
    check "Claude status line refreshes every minute" json_has "$home/.claude/settings.json" \
        '.statusLine.refreshInterval == 60'
    check "Codex hooks registered" json_has "$home/.codex/hooks.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" codex prompt"))'
    check "Gemini hook registered" json_has "$home/.gemini/settings.json" \
        '[.hooks.BeforeAgent[].hooks[].command] | any(contains("inject.sh\" gemini prompt"))'
    check "Devin hook registered" json_has "$home/.config/devin/config.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] | any(contains("inject.sh\" devin prompt"))'
    check "Kiro hooks" json_has "$home/.kiro/hooks/unlazier.json" \
        '[.hooks[].trigger] == ["UserPromptSubmit", "PostCompact"]'
    check "Cline hook executable" test -x "$home/Documents/Cline/Hooks/UserPromptSubmit"
    check "OpenCode plugin" test -f "$home/.config/opencode/plugins/unlazier.ts"
    check "Amp plugin" test -f "$home/.config/amp/plugins/unlazier.ts"
    check "no backup folders" test -z "$(find "$home" -maxdepth 2 -name '*.bak*')"
    check "alert script in payload" test -x "$home/.claude/unlazier/alert.sh"
    check "Claude permission alert" has_alert_hook "$home/.claude/settings.json" Notification permission_prompt
    check "Claude question alert" has_alert_hook "$home/.claude/settings.json" PreToolUse AskUserQuestion
    check "Claude end-of-turn alert" has_alert_hook "$home/.claude/settings.json" Stop
    check "Codex permission alert" has_alert_hook "$home/.codex/hooks.json" PermissionRequest
    check "Codex question alert" has_alert_hook "$home/.codex/hooks.json" PreToolUse '^request_user_input$'
    check "Codex end-of-turn alert" has_alert_hook "$home/.codex/hooks.json" Stop
    check "Gemini attention alert" has_alert_hook "$home/.gemini/settings.json" Notification
    check "Gemini end-of-turn alert" has_alert_hook "$home/.gemini/settings.json" AfterAgent
    check "Devin permission alert" has_alert_hook "$home/.config/devin/config.json" PermissionRequest
    check "Devin question alert" has_alert_hook "$home/.config/devin/config.json" PreToolUse '^ask_user_question$'
    check "Devin end-of-turn alert" has_alert_hook "$home/.config/devin/config.json" Stop
    check "Kiro end-of-turn alert" json_has "$home/.kiro/hooks/unlazier-alert.json" '[.hooks[].trigger] == ["Stop"]'
    check "Copilot alerts" json_has "$home/.copilot/hooks/unlazier.json" \
        '(.hooks.notification[0].matcher == "permission_prompt|elicitation_dialog") and (.hooks.agentStop | length == 1)'
    check "Cline question alert executable" test -x "$home/Documents/Cline/Hooks/PreToolUse"
    check "Cline end-of-turn alert executable" test -x "$home/Documents/Cline/Hooks/TaskComplete"
}

test_cline_question_alert_filters_tools() {
    local home alert_log
    echo "the Cline question alert beeps only for question tools"
    home="$(new_home)"
    run_installer "$home" --harness cline >/dev/null 2>&1
    alert_log="$home/alerts.log"
    # A stub replaces the beep so the test is silent and countable.
    printf '#!/bin/bash\necho alert >> "%s"\n' "$alert_log" > "$home/Documents/Cline/unlazier/alert.sh"

    check "hook answers cancel false" test "$(echo '{"preToolUse":{"toolName":"read_file"}}' \
        | bash "$home/Documents/Cline/Hooks/PreToolUse")" = '{"cancel":false}'
    check "no alert for other tools" file_absent "$alert_log"
    echo '{"preToolUse":{"toolName":"ask_question"}}' | bash "$home/Documents/Cline/Hooks/PreToolUse" >/dev/null
    check "alert for a question" test "$(wc -l < "$alert_log" | tr -d ' ')" = "1"
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
        '[.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("unlazier"))] | length == 1'
    check "one Claude end-of-turn alert" has_alert_hook "$home/.claude/settings.json" Stop
    check "one Codex end-of-turn alert" has_alert_hook "$home/.codex/hooks.json" Stop
    check "one Codex prompt hook" json_has "$home/.codex/hooks.json" \
        '[.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("unlazier"))] | length == 1'
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

# Version 2.0 was named "unlazier-ai": it wrote a block into CLAUDE.md and the single-file
# harnesses, single or split files into the rules folders, and its own folders and plugins.
seed_v2_0_installation() {
    local home="$1" old_block
    old_block='<!-- unlazier-ai:start -->\nold rules\n<!-- unlazier-ai:end -->\n'
    mkdir -p "$home/.claude/unlazier-ai" "$home/.codex" "$home/.kiro/steering" "$home/.kiro/hooks" \
        "$home/.devin/rules" "$home/.config/opencode/plugins"
    # shellcheck disable=SC2059  # the block is a printf format on purpose, for its newlines
    printf "# My notes\n$old_block" > "$home/.claude/CLAUDE.md"
    # shellcheck disable=SC2059
    printf "# Codex notes\n$old_block" > "$home/.codex/AGENTS.md"
    # shellcheck disable=SC2059
    printf "$old_block" > "$home/.kiro/steering/unlazier-ai.md"
    # shellcheck disable=SC2059
    printf "$old_block" > "$home/.devin/rules/unlazier-ai-rules.md"
    printf 'old\n' > "$home/.claude/unlazier-ai/inject.sh"
    printf '{}\n' > "$home/.kiro/hooks/unlazier-ai.json"
    printf 'old\n' > "$home/.config/opencode/plugins/unlazier-ai.ts"
    jq -n '{hooks: {UserPromptSubmit: [{hooks: [{type: "command",
        command: "bash \"/old/.claude/unlazier-ai/inject.sh\" claude prompt"}]}]}}' > "$home/.claude/settings.json"
}

test_upgrade_from_v2_0_layout() {
    local home
    echo "version 2.0 (unlazier-ai) moves to the current names and layout"
    home="$(new_home)"
    seed_v2_0_installation "$home"
    run_installer "$home" --harness claude,codex,kiro,devin,opencode >/dev/null 2>&1

    check "old block removed from CLAUDE.md" test "$(cat "$home/.claude/CLAUDE.md")" = "# My notes"
    check "Claude rule files installed" has_all_rule_files "$home/.claude/rules"
    check "old Codex block replaced" test "$(grep -c 'unlazier-ai' "$home/.codex/AGENTS.md")" = "0"
    check "new Codex block added" has_one_block "$home/.codex/AGENTS.md"
    check "old Kiro rules file removed" file_absent "$home/.kiro/steering/unlazier-ai.md"
    check "old Kiro hook file removed" file_absent "$home/.kiro/hooks/unlazier-ai.json"
    check "old Devin split file removed" file_absent "$home/.devin/rules/unlazier-ai-rules.md"
    check "Devin rule files installed" has_all_rule_files "$home/.devin/rules"
    check "old Claude folder removed" file_absent "$home/.claude/unlazier-ai"
    check "old OpenCode plugin removed" file_absent "$home/.config/opencode/plugins/unlazier-ai.ts"
    check "old Claude hook replaced" json_has "$home/.claude/settings.json" \
        '[.hooks.UserPromptSubmit[].hooks[].command] == ["bash \"'"$home"'/.claude/unlazier/inject.sh\" claude prompt"]'
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

    check "Claude usage line" test "$(last_line bash "$home/.claude/unlazier/inject.sh" claude prompt)" \
        = "Usage: 5h 24% | weekly unknown (source: Claude Code status line, 2 min old)"
    check "Codex usage line" test "$(last_line bash "$home/.codex/unlazier/inject.sh" codex prompt)" \
        = "Usage: 5h 43% | weekly 61% (source: Codex session log, 1 min old)"
    check "Kiro usage unknown" test "$(last_line bash "$home/.kiro/unlazier/inject.sh" kiro prompt)" \
        = "Usage: unknown (this tool does not expose usage windows)"

    jq --argjson old "$((now - 3600))" '.captured_at = $old' "$home/.claude/state/rate_limits.json" \
        > "$home/stale.json" && mv "$home/stale.json" "$home/.claude/state/rate_limits.json"
    check "stale Claude reading is unknown" test "$(last_line bash "$home/.claude/unlazier/inject.sh" claude prompt)" \
        = "Usage: unknown (no usage reading from the last 15 minutes)"
}

# Writes a usage snapshot with one window; an empty resets_at leaves the field out.
write_rate_limits() {
    local home="$1" window="$2" used="$3" resets_at="${4:-null}"
    mkdir -p "$home/.claude/state"
    jq -n --arg window "$window" --argjson used "$used" --argjson resets_at "$resets_at" '
        {($window): ({used_percentage: $used} + (if $resets_at == null then {} else {resets_at: $resets_at} end))}' \
        > "$home/.claude/state/rate_limits.json"
}

exit_status() { "$@" >/dev/null 2>&1; echo $?; }

test_wait_usage_exits() {
    local home now script waiter
    echo "wait-usage ends with one line per reason"
    home="$(new_home)"
    now="$(date +%s)"
    run_installer "$home" --harness claude,codex >/dev/null 2>&1
    script="$home/.claude/unlazier/wait-usage.sh"

    check "script installed and executable for Claude Code" test -x "$script"
    check "script not installed for Codex" file_absent "$home/.codex/unlazier/wait-usage.sh"
    check "missing state file fails fast" test "$(exit_status bash "$script" --interval 1 --max-wait 10)" = "1"

    write_rate_limits "$home" seven_day 30
    check "missing window fails fast" test "$(exit_status bash "$script" --interval 1 --max-wait 10)" = "1"
    check "unknown option is a usage error" test "$(exit_status bash "$script" --unknown)" = "2"
    check "invalid number is a usage error" test "$(exit_status bash "$script" --stop-at ninety)" = "2"

    write_rate_limits "$home" five_hour 24 "$((now - 120))"
    check "passed reset time ends the wait" test "$(bash "$script" --interval 1 --max-wait 10 --grace 60)" \
        = "reset used=24 start=24"

    write_rate_limits "$home" five_hour 96
    check "usage at the stop level ends the wait" test "$(bash "$script" --interval 1 --max-wait 10 --stop-at 95)" \
        = "threshold used=96 stop_at=95"

    write_rate_limits "$home" seven_day 99
    check "weekly window can be watched" test \
        "$(bash "$script" --interval 1 --max-wait 10 --window seven_day --stop-at 99)" = "threshold used=99 stop_at=99"

    write_rate_limits "$home" five_hour 50
    check "no reset time ends only by timeout" test "$(bash "$script" --interval 1 --max-wait 2)" = "timeout used=50"

    cp "$home/.claude/state/rate_limits.json" "$home/other.json"
    rm "$home/.claude/state/rate_limits.json"
    check "state option replaces the default file" test \
        "$(bash "$script" --interval 1 --max-wait 2 --state "$home/other.json")" = "timeout used=50"

    write_rate_limits "$home" five_hour 50 "$((now + 3600))"
    bash "$script" --interval 1 --max-wait 10 > "$home/waiter.out" 2>&1 &
    waiter=$!
    sleep 2
    printf '{"five_hour": {"used_perc' > "$home/.claude/state/rate_limits.json"
    sleep 2
    write_rate_limits "$home" five_hour 10 "$((now + 3600))"
    wait "$waiter"
    check "usage drop ends the wait after a torn snapshot" test "$(cat "$home/waiter.out")" = "dropped used=10 start=50"
}

test_inject_output_formats() {
    local home
    echo "inject prints the shape each harness expects"
    home="$(new_home)"
    run_installer "$home" --harness claude,gemini,devin,cline >/dev/null 2>&1

    check "Claude prompt is the reminder text" test "$(bash "$home/.claude/unlazier/inject.sh" claude prompt | head -n 1)" \
        = "Unlazier rules are active for this session."
    check "Claude compaction starts with the principles" test \
        "$(bash "$home/.claude/unlazier/inject.sh" claude compact | head -n 1)" = "# Global Agent Rules"
    check "Gemini output is JSON" json_has <(bash "$home/.gemini/unlazier/inject.sh" gemini prompt) \
        '.hookSpecificOutput.additionalContext | startswith("Unlazier rules")'
    check "Devin output is JSON" json_has <(bash "$home/.devin/unlazier/inject.sh" devin prompt) \
        '.hookSpecificOutput.additionalContext | startswith("Unlazier rules")'
    check "Cline output is JSON" json_has <(bash "$home/Documents/Cline/unlazier/inject.sh" cline prompt) \
        '.contextModification | startswith("Unlazier rules")'
    check "unknown event fails" test "$(bash "$home/.claude/unlazier/inject.sh" claude other >/dev/null 2>&1; echo $?)" = "2"
}

test_statusline_saves_usage() {
    local home now output
    echo "Claude status line shows and saves usage"
    home="$(new_home)"
    run_installer "$home" --harness claude >/dev/null 2>&1
    now="$(date +%s)"
    output="$(jq -cn --argjson now "$now" '{rate_limits: {
        five_hour: {used_percentage: 24, resets_at: ($now + 600)},
        seven_day: {used_percentage: 94, resets_at: ($now + 3 * 86400 + 11 * 3600 + 30 * 60 + 30)}}}' \
        | bash "$home/.claude/unlazier/claude-statusline.sh")"

    check "status line shows the 5-hour window" test -n "$(printf '%s' "$output" | grep 'Session 5h: .* 24%')"
    check "reset time shows days" test -n "$(printf '%s' "$output" | grep 'Weekly .* resets in 3d 11h 30m$')"
    check "usage saved for the hook" json_has "$home/.claude/state/rate_limits.json" \
        '.five_hour.used_percentage == 24 and (.captured_at | type) == "number"'
    check "broken input degrades" test "$(printf 'garbage' | bash "$home/.claude/unlazier/claude-statusline.sh")" \
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
    test_wait_usage_exits
    test_cline_question_alert_filters_tools
    echo
    echo "$PASSED passed, $FAILED failed"
    [ "$FAILED" -eq 0 ]
}

main
