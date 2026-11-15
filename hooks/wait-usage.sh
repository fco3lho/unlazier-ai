#!/bin/bash
# Unlazier wait for the Claude Code usage window, for Linux and macOS.
#
# Usage: wait-usage.sh [--window five_hour|seven_day] [--stop-at PERCENT] [--grace SECONDS]
#                      [--interval SECONDS] [--max-wait SECONDS] [--state FILE]
#
# Run it in the background: when it exits, the session wakes up and reads its one output line.
# It reads the usage the status line saves to <claude home>/state/rate_limits.json and exits
# 0 as soon as one of these holds:
#   reset      the reset time captured at start, plus --grace (60), has passed
#   dropped    the usage fell below its value at start (the window reset early)
#   threshold  the usage reached --stop-at
#   timeout    --max-wait seconds passed
#
# The reset time and the usage are read once, at start, on purpose. At the reset, resets_at
# moves to the next cycle, so a loop that re-reads it never sees the old one pass and waits
# forever. The reset reason depends on the clock alone, so it still fires when the status
# line stopped refreshing. A snapshot caught while it is being rewritten reads as unchanged.
#
# Output (one line): reset used=<u> start=<s> | dropped used=<u> start=<s> |
#                    threshold used=<u> stop_at=<p> | timeout used=<u>
# Exit status: 0 on a result, 1 when the usage is unavailable at start, 2 on a usage error.
# Installed at <claude home>/unlazier/wait-usage.sh; requires jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$CLAUDE_HOME/state/rate_limits.json"
WINDOW="five_hour"
STOP_AT=""
GRACE_SECONDS=60
INTERVAL_SECONDS=60
MAX_WAIT_SECONDS=""

usage_error() {
    printf 'wait-usage.sh: %s\n' "$1" >&2
    printf 'Usage: wait-usage.sh [--window five_hour|seven_day] [--stop-at PERCENT] [--grace SECONDS]\n' >&2
    printf '                     [--interval SECONDS] [--max-wait SECONDS] [--state FILE]\n' >&2
    exit 2
}

is_number() { printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)([.][0-9]+)?$'; }
is_whole_number() { printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)$'; }

# Sets the variable named by $1 to $3 after checking it with the predicate named by $2.
take_option() {
    local variable="$1" predicate="$2" option="$3" value="${4:-}"
    [ -n "$value" ] || usage_error "$option needs a value"
    "$predicate" "$value" || usage_error "$option needs a number, got '$value'"
    printf -v "$variable" '%s' "$value"
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --window)
                [ "$#" -ge 2 ] || usage_error "--window needs a value"
                case "$2" in
                    five_hour|seven_day) WINDOW="$2" ;;
                    *) usage_error "--window must be five_hour or seven_day, got '$2'" ;;
                esac
                ;;
            --state)
                [ "$#" -ge 2 ] || usage_error "--state needs a value"
                STATE_FILE="$2"
                ;;
            --stop-at) take_option STOP_AT is_number "$1" "${2:-}" ;;
            --grace) take_option GRACE_SECONDS is_whole_number "$1" "${2:-}" ;;
            --interval) take_option INTERVAL_SECONDS is_whole_number "$1" "${2:-}" ;;
            --max-wait) take_option MAX_WAIT_SECONDS is_whole_number "$1" "${2:-}" ;;
            *) usage_error "unknown option '$1'" ;;
        esac
        shift 2
    done
}

# Prints "<used percentage> <reset epoch>" of the watched window; the epoch is 0 when the
# snapshot has none. Fails when the file is unreadable, empty, torn, or lacks the window.
# "+ 0" makes jq print a canonical number (24, not 24.0).
# shellcheck disable=SC2016  # jq program, not a shell expansion
read_window() {
    jq -er --arg window "$WINDOW" '
        .[$window] | select(type == "object" and (.used_percentage | type) == "number")
        | "\(.used_percentage + 0) \((.resets_at | numbers) // 0 | floor)"' "$STATE_FILE" 2>/dev/null
}

# shellcheck disable=SC2016
is_below() { jq -en --argjson value "$1" --argjson limit "$2" '$value < $limit' >/dev/null; }

# shellcheck disable=SC2016
is_at_least() { jq -en --argjson value "$1" --argjson limit "$2" '$value >= $limit' >/dev/null; }

# Prints the one result line and ends the script; the reason is decided by the caller.
finish() {
    printf '%s\n' "$1"
    exit 0
}

wait_for_window() {
    local reading start_used reset_at started now used
    reading="$(read_window)" || {
        printf 'wait-usage.sh: no %s usage in %s\n' "$WINDOW" "$STATE_FILE" >&2
        exit 1
    }
    start_used="${reading% *}"
    reset_at="${reading#* }"
    started="$(date +%s)"
    if [ -n "$STOP_AT" ]; then
        STOP_AT="$(jq -n --argjson value "$STOP_AT" '$value + 0')"
    fi

    while true; do
        if reading="$(read_window)"; then
            used="${reading% *}"
        else
            used="$start_used"
        fi
        now="$(date +%s)"
        if [ "$reset_at" -gt 0 ] && [ "$now" -ge $((reset_at + GRACE_SECONDS)) ]; then
            finish "reset used=$used start=$start_used"
        fi
        if is_below "$used" "$start_used"; then
            finish "dropped used=$used start=$start_used"
        fi
        if [ -n "$STOP_AT" ] && is_at_least "$used" "$STOP_AT"; then
            finish "threshold used=$used stop_at=$STOP_AT"
        fi
        if [ -n "$MAX_WAIT_SECONDS" ] && [ $((now - started)) -ge "$MAX_WAIT_SECONDS" ]; then
            finish "timeout used=$used"
        fi
        sleep "$INTERVAL_SECONDS"
    done
}

command -v jq >/dev/null 2>&1 || { echo "wait-usage.sh: jq is required" >&2; exit 1; }
parse_args "$@"
wait_for_window
