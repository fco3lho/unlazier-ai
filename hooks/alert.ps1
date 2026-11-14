# Unlazier alert for Windows: three short beeps when the agent needs attention (a permission
# prompt or a question) or finishes its turn.
#
# Several harnesses read hook output as JSON, so nothing is printed to stdout, and the alert
# never fails the hook. Installed at <harness home>\unlazier\alert.ps1. This file is kept
# ASCII-only because Windows PowerShell 5.1 reads scripts without a byte order mark in the
# legacy code page.

try {
    for ($count = 0; $count -lt 3; $count++) {
        [console]::Beep(700, 200)
        Start-Sleep -Milliseconds 5
    }
} catch {
    # Some machines have no beep device; the hook must still succeed.
    [Console]::Error.WriteLine("alert.ps1: beep unavailable: $($_.Exception.Message)")
}
exit 0
