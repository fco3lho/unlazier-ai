#!/bin/bash
# Unlazier alert for Linux and macOS: three short beeps when the agent needs attention (a
# permission prompt or a question) or finishes its turn.
#
# Several harnesses read hook output as JSON, so nothing is printed to stdout: the terminal
# bell goes to /dev/tty and every sound command is silenced. The alert never fails the hook.
# Installed at <harness home>/unlazier/alert.sh.

ring_terminal_bell() {
    for _ in 1 2 3; do
        { printf '\a' > /dev/tty; } 2>/dev/null
        sleep 0.05
    done
}

play_alert() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL has no Linux sound device, so Windows plays the beep.
        powershell.exe -NoProfile -Command \
            'for ($i = 0; $i -lt 3; $i++) { [console]::beep(700, 200); Start-Sleep -Milliseconds 5 }' \
            >/dev/null 2>&1
    elif [[ "$OSTYPE" == darwin* ]]; then
        for _ in 1 2 3; do
            afplay /System/Library/Sounds/Tink.aiff >/dev/null 2>&1 || ring_terminal_bell
        done
    elif command -v paplay >/dev/null 2>&1; then
        for _ in 1 2 3; do
            paplay /usr/share/sounds/freedesktop/stereo/button-pressed.oga >/dev/null 2>&1 \
                || { printf '\a' > /dev/tty; } 2>/dev/null
            sleep 0.05
        done
    else
        ring_terminal_bell
    fi
}

play_alert
exit 0
