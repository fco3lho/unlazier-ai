#!/bin/bash
# Unlazier AI context hook for Linux and macOS.
#
# Usage: inject.sh <harness> <prompt|compact>
#   prompt   prints the short reminder and the usage line; runs on every user prompt.
#   compact  prints the core principles, the reminder, and the usage line; runs after
#            context compaction, when the original instructions may have been summarized away.
#
# Rules loaded at session start lose weight as the context window fills, so the harness
# calls this hook to place a compact copy near the end of the context. Installed at
# <harness home>/unlazier-ai/inject.sh next to reminder.md and AGENTS.md; requires jq.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_HOME="$(dirname "$SCRIPT_DIR")"
MAX_READING_AGE_SECONDS=900

# Normalized usage reading: {"five_hour": <percent|null>, "weekly": <percent|null>, "captured_at": <epoch>}.
# A window counts only while its reset time is still in the future.
# shellcheck disable=SC2016  # jq programs, not shell expansions
CLAUDE_USAGE_PROGRAM='
def live($window): if $window.used_percentage != null and (($window.resets_at // now + 1) > now)
    then $window.used_percentage else null end;
{five_hour: live(.five_hour // {}), weekly: live(.seven_day // {}), captured_at: .captured_at}
'

# shellcheck disable=SC2016
CODEX_USAGE_PROGRAM='
def epoch: sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
(.timestamp | epoch) as $captured_at
| [.payload.rate_limits.primary, .payload.rate_limits.secondary] | map(select(. != null))
| map(. + {resets_epoch: (.resets_at // (if .resets_in_seconds != null then $captured_at + .resets_in_seconds else null end))})
| def pick($minutes): (map(select(.window_minutes == $minutes and .used_percent != null
        and ((.resets_epoch // now + 1) > now))) | first | .used_percent) // null;
{five_hour: pick(300), weekly: pick(10080), captured_at: $captured_at}
'

# shellcheck disable=SC2016
FORMAT_USAGE_PROGRAM='
def percent: if . == null then "unknown" else "\(. + 0.5 | floor)%" end;
if .captured_at == null or (now - .captured_at) > $max_age then
    "Usage: unknown (no usage reading from the last 15 minutes)"
else
    "Usage: 5h \(.five_hour | percent) | weekly \(.weekly | percent) (source: \($source), \((now - .captured_at) / 60 | floor) min old)"
end
'

read_claude_usage() {
    local state_file="$HARNESS_HOME/state/rate_limits.json"
    [ -f "$state_file" ] || return 1
    jq -c "$CLAUDE_USAGE_PROGRAM" "$state_file" 2>/dev/null
}

read_codex_usage() {
    local sessions_dir="$HARNESS_HOME/sessions" newest_rollout last_event
    [ -d "$sessions_dir" ] || return 1
    # Rollout paths are sessions/YYYY/MM/DD/rollout-<timestamp>-<id>.jsonl, so the
    # lexicographic maximum is the most recent session.
    newest_rollout="$(find "$sessions_dir" -type f -name 'rollout-*.jsonl' | sort | tail -n 1)"
    [ -n "$newest_rollout" ] || return 1
    last_event="$(jq -c 'select(.type == "event_msg" and .payload.type == "token_count"
        and .payload.rate_limits != null)' "$newest_rollout" 2>/dev/null | tail -n 1)"
    [ -n "$last_event" ] || return 1
    printf '%s' "$last_event" | jq -c "$CODEX_USAGE_PROGRAM" 2>/dev/null
}

usage_line() {
    local harness="$1" reading="" source=""
    case "$harness" in
        claude)
            source="Claude Code status line"
            reading="$(read_claude_usage)" || reading=""
            ;;
        codex)
            source="Codex session log"
            reading="$(read_codex_usage)" || reading=""
            ;;
        *)
            echo "Usage: unknown (this tool does not expose usage windows)"
            return 0
            ;;
    esac
    if [ -z "$reading" ]; then
        echo "Usage: unknown (no usage reading available)"
        return 0
    fi
    printf '%s' "$reading" | jq -r --arg source "$source" --argjson max_age "$MAX_READING_AGE_SECONDS" \
        "$FORMAT_USAGE_PROGRAM"
}

build_context() {
    local harness="$1" event="$2"
    case "$event" in
        prompt)
            cat "$SCRIPT_DIR/reminder.md"
            ;;
        compact)
            cat "$SCRIPT_DIR/AGENTS.md"
            echo
            cat "$SCRIPT_DIR/reminder.md"
            ;;
        *)
            echo "inject.sh: unknown event '$event' (expected prompt or compact)" >&2
            return 1
            ;;
    esac
    usage_line "$harness"
}

# Each harness expects its own output shape; see the adapter table in README.md.
emit() {
    local harness="$1" context="$2"
    case "$harness" in
        # The OpenCode and Amp plugins read this plain text and hand it to the model themselves.
        claude|codex|kiro|opencode|amp)
            printf '%s\n' "$context"
            ;;
        gemini)
            jq -n --arg context "$context" \
                '{hookSpecificOutput: {hookEventName: "BeforeAgent", additionalContext: $context}}'
            ;;
        devin)
            jq -n --arg context "$context" \
                '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $context}}'
            ;;
        cline)
            jq -n --arg context "$context" '{cancel: false, contextModification: $context}'
            ;;
        *)
            echo "inject.sh: unknown harness '$harness'" >&2
            return 1
            ;;
    esac
}

main() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: inject.sh <harness> <prompt|compact>" >&2
        exit 2
    fi
    local context
    context="$(build_context "$1" "$2")" || exit 2
    emit "$1" "$context"
}

main "$@"
