# Unlazier wait for the Claude Code usage window, for Windows.
#
# Usage: wait-usage.ps1 [-Window five_hour|seven_day] [-StopAt PERCENT] [-Grace SECONDS]
#                       [-Interval SECONDS] [-MaxWait SECONDS] [-State FILE]
#
# Run it in the background: when it exits, the session wakes up and reads its one output line.
# It reads the usage the status line saves to <claude home>\state\rate_limits.json and exits
# 0 as soon as one of these holds:
#   reset      the reset time captured at start, plus -Grace (60), has passed
#   dropped    the usage fell below its value at start (the window reset early)
#   threshold  the usage reached -StopAt
#   timeout    -MaxWait seconds passed
#
# The reset time and the usage are read once, at start, on purpose. At the reset, resets_at
# moves to the next cycle, so a loop that re-reads it never sees the old one pass and waits
# forever. The reset reason depends on the clock alone, so it still fires when the status
# line stopped refreshing. A snapshot caught while it is being rewritten reads as unchanged.
#
# Output (one line, the same as wait-usage.sh): reset used=<u> start=<s> |
#     dropped used=<u> start=<s> | threshold used=<u> stop_at=<p> | timeout used=<u>
# Exit status: 0 on a result, 1 when the usage is unavailable at start, 2 on a usage error.
# The numbers are declared as strings so that a bad value is a usage error (exit 2, as in
# wait-usage.sh) instead of a parameter binding failure (exit 1).
# Installed at <claude home>\unlazier\wait-usage.ps1. This file is kept ASCII-only because
# Windows PowerShell 5.1 reads scripts without a byte order mark in the legacy code page.

[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Window = 'five_hour',
    [string]$StopAt,
    [string]$Grace = '60',
    [string]$Interval = '60',
    [string]$MaxWait,
    [string]$State,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UnrecognizedArguments
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ClaudeHome = Split-Path -Parent $PSScriptRoot
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Stop-WithUsageError {
    param([string]$Message)
    [Console]::Error.WriteLine("wait-usage.ps1: $Message")
    [Console]::Error.WriteLine('Usage: wait-usage.ps1 [-Window five_hour|seven_day] [-StopAt PERCENT] [-Grace SECONDS]')
    [Console]::Error.WriteLine('                      [-Interval SECONDS] [-MaxWait SECONDS] [-State FILE]')
    exit 2
}

function Test-OptionValue {
    param([string]$Name, [string]$Value, [string]$Pattern)
    if ($Value -notmatch $Pattern) {
        Stop-WithUsageError "-$Name needs a number, got '$Value'"
    }
}

# Opens the file with FileShare.ReadWrite because the status line may be rewriting it; the
# default sharing mode would fail with a sharing violation.
function Read-SharedText {
    param([string]$Path)
    $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        $reader = New-Object System.IO.StreamReader($stream, $Utf8NoBom)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($Object -is [System.Management.Automation.PSCustomObject] -and $null -ne $Object.PSObject.Properties[$Name]) {
        return $Object.PSObject.Properties[$Name].Value
    }
    return $null
}

function Test-Number {
    param($Value)
    return ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal])
}

# Returns @{ Used; ResetsAt } of the watched window (ResetsAt is 0 when the snapshot has
# none), or $null when the file is unreadable, empty, torn, or lacks the window. The callers
# decide what that means: a failure at start, an unchanged reading inside the loop.
function Read-Window {
    param([string]$Path, [string]$Name)
    try {
        $document = (Read-SharedText $Path) | ConvertFrom-Json
    } catch {
        return $null
    }
    $entry = Get-JsonProperty $document $Name
    $used = Get-JsonProperty $entry 'used_percentage'
    if (-not (Test-Number $used)) {
        return $null
    }
    $resetsAt = Get-JsonProperty $entry 'resets_at'
    if (-not (Test-Number $resetsAt)) {
        $resetsAt = 0
    }
    return @{ Used = [double]$used; ResetsAt = [long][System.Math]::Floor([double]$resetsAt) }
}

function Format-Number {
    param([double]$Value)
    return $Value.ToString('R', $InvariantCulture)
}

function Get-UnixNow {
    return [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

# Prints the one result line and ends the script; the reason is decided by the caller.
function Complete-Wait {
    param([string]$Line)
    Write-Output $Line
    exit 0
}

function Wait-ForWindow {
    param([string]$Path, [string]$Name, $StopLevel, [long]$GraceSeconds, [long]$IntervalSeconds, $MaxWaitSeconds)
    $reading = Read-Window $Path $Name
    if ($null -eq $reading) {
        [Console]::Error.WriteLine("wait-usage.ps1: no $Name usage in $Path")
        exit 1
    }
    $startUsed = $reading.Used
    $resetAt = $reading.ResetsAt
    $started = Get-UnixNow
    $startText = Format-Number $startUsed

    while ($true) {
        $reading = Read-Window $Path $Name
        $used = $startUsed
        if ($null -ne $reading) {
            $used = $reading.Used
        }
        $usedText = Format-Number $used
        $now = Get-UnixNow
        if ($resetAt -gt 0 -and $now -ge ($resetAt + $GraceSeconds)) {
            Complete-Wait "reset used=$usedText start=$startText"
        }
        if ($used -lt $startUsed) {
            Complete-Wait "dropped used=$usedText start=$startText"
        }
        if ($null -ne $StopLevel -and $used -ge $StopLevel) {
            Complete-Wait "threshold used=$usedText stop_at=$(Format-Number $StopLevel)"
        }
        if ($null -ne $MaxWaitSeconds -and ($now - $started) -ge $MaxWaitSeconds) {
            Complete-Wait "timeout used=$usedText"
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

if ($UnrecognizedArguments) {
    Stop-WithUsageError "unknown option '$($UnrecognizedArguments[0])'"
}
if ($Window -ne 'five_hour' -and $Window -ne 'seven_day') {
    Stop-WithUsageError "-Window must be five_hour or seven_day, got '$Window'"
}
$NumberPattern = '^(0|[1-9][0-9]*)(\.[0-9]+)?$'
$WholeNumberPattern = '^(0|[1-9][0-9]*)$'
$StopLevel = $null
if ($PSBoundParameters.ContainsKey('StopAt')) {
    Test-OptionValue 'StopAt' $StopAt $NumberPattern
    $StopLevel = [double]::Parse($StopAt, $InvariantCulture)
}
$MaxWaitSeconds = $null
if ($PSBoundParameters.ContainsKey('MaxWait')) {
    Test-OptionValue 'MaxWait' $MaxWait $WholeNumberPattern
    $MaxWaitSeconds = [long]$MaxWait
}
Test-OptionValue 'Grace' $Grace $WholeNumberPattern
Test-OptionValue 'Interval' $Interval $WholeNumberPattern
$StatePath = [System.IO.Path]::Combine($ClaudeHome, 'state', 'rate_limits.json')
if ($PSBoundParameters.ContainsKey('State')) {
    $StatePath = $State
}
Wait-ForWindow $StatePath $Window $StopLevel ([long]$Grace) ([long]$Interval) $MaxWaitSeconds
