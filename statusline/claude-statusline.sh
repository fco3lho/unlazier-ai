#!/bin/bash
# Claude Code status line for Unlazier AI.
#
# Claude Code sends the usage windows (5-hour and weekly) only to the status line command.
# This script shows them and saves them to <claude home>/state/rate_limits.json, where the
# Unlazier AI hook reads them to tell the agent its current usage.
#
# Installed at <claude home>/unlazier-ai/claude-statusline.sh; requires jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$CLAUDE_HOME/state/rate_limits.json"

# Renders one window as: "Session 5h: [██░░░░░░░░] 24% · resets in 1h 2m"
# shellcheck disable=SC2016  # jq program, not a shell expansion
FORMAT_PROGRAM='
def bar($percent):
    ([([($percent / 10 + 0.5 | floor), 10] | min), 0] | max) as $filled
    | ([range(0; $filled)] | map("█") | join("")) + ([range($filled; 10)] | map("░") | join(""));
def remaining($resets_at):
    if $resets_at == null then "?"
    else ([($resets_at - now | floor), 0] | max) as $seconds
        | ($seconds / 3600 | floor) as $hours
        | (($seconds % 3600) / 60 | floor) as $minutes
        | if $hours > 0 then "\($hours)h \($minutes)m" else "\($minutes)m" end
    end;
def window($label; $data):
    if $data == null or $data.used_percentage == null then "\($label): no data"
    else "\($label): [\(bar($data.used_percentage))] \($data.used_percentage + 0.5 | floor)% · resets in \(remaining($data.resets_at))"
    end;
window("Session 5h"; .five_hour), window("Weekly    "; .seven_day)
'

save_rate_limits() {
    local rate_limits="$1"
    local temporary_file="$STATE_FILE.tmp"
    mkdir -p "$(dirname "$STATE_FILE")" || return 1
    printf '%s' "$rate_limits" \
        | jq -c --argjson captured_at "$(date +%s)" '{captured_at: $captured_at} + .' > "$temporary_file" \
        && mv "$temporary_file" "$STATE_FILE"
}

main() {
    local payload rate_limits
    payload="$(cat)"
    if ! rate_limits="$(printf '%s' "$payload" | jq -c '.rate_limits // {}' 2>/dev/null)"; then
        # A broken payload should degrade the status line, not replace it with an error.
        echo "Usage: no data"
        return 0
    fi
    if [ "$rate_limits" != "{}" ]; then
        save_rate_limits "$rate_limits" || echo "rate_limits not saved to $STATE_FILE" >&2
    fi
    printf '%s' "$rate_limits" | jq -r "$FORMAT_PROGRAM"
}

main
