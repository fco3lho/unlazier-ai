# Claude Code status line for Unlazier AI (Windows).
#
# Claude Code sends the usage windows (5-hour and weekly) only to the status line command.
# This script shows them and saves them to <claude home>\state\rate_limits.json, where the
# Unlazier AI hook reads them to tell the agent its current usage.
#
# Installed at <claude home>\unlazier-ai\claude-statusline.ps1. This file is kept ASCII-only
# because Windows PowerShell 5.1 reads scripts without a byte order mark in the legacy code
# page; the bar characters are built from their code points instead.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ClaudeHome = Split-Path -Parent $PSScriptRoot
$StateFile = [System.IO.Path]::Combine($ClaudeHome, 'state', 'rate_limits.json')
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$BarWidth = 10
$FilledCharacter = [string][char]0x2588
$EmptyCharacter = [string][char]0x2591
$MiddleDot = [string][char]0x00B7

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($Object -is [System.Management.Automation.PSCustomObject] -and $null -ne $Object.PSObject.Properties[$Name]) {
        return , $Object.PSObject.Properties[$Name].Value
    }
    return $null
}

function Format-Bar {
    param([double]$Percent)
    $filled = [System.Math]::Max(0, [System.Math]::Min($BarWidth, [int][System.Math]::Floor($Percent / 10 + 0.5)))
    return ($FilledCharacter * $filled) + ($EmptyCharacter * ($BarWidth - $filled))
}

function Format-Remaining {
    param($ResetsAt, [double]$Now)
    if ($null -eq $ResetsAt) {
        return '?'
    }
    $seconds = [long][System.Math]::Max([System.Math]::Floor([double]$ResetsAt - $Now), 0)
    $hours = [long][System.Math]::Floor($seconds / 3600)
    $minutes = [long][System.Math]::Floor(($seconds % 3600) / 60)
    if ($hours -gt 0) {
        return "${hours}h ${minutes}m"
    }
    return "${minutes}m"
}

# Renders one window as: "Session 5h: [##........] 24% . resets in 1h 2m" (with block characters).
function Format-Window {
    param([string]$Label, $Window, [double]$Now)
    $percent = Get-JsonProperty $Window 'used_percentage'
    if ($null -eq $percent) {
        return "${Label}: no data"
    }
    $rounded = [long][System.Math]::Floor([double]$percent + 0.5)
    $remaining = Format-Remaining (Get-JsonProperty $Window 'resets_at') $Now
    return "${Label}: [$(Format-Bar ([double]$percent))] $rounded% $MiddleDot resets in $remaining"
}

function Save-RateLimits {
    param($RateLimits)
    $snapshot = [ordered]@{ captured_at = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    foreach ($property in $RateLimits.PSObject.Properties) {
        $snapshot[$property.Name] = $property.Value
    }
    $json = ConvertTo-Json -InputObject ([pscustomobject]$snapshot) -Depth 20 -Compress
    $temporaryFile = "$StateFile.tmp"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $StateFile))
    [System.IO.File]::WriteAllText($temporaryFile, $json, $Utf8NoBom)
    Move-Item -LiteralPath $temporaryFile -Destination $StateFile -Force
}

function Write-Text {
    param([string]$Text)
    # Raw UTF-8 bytes: the console code page cannot represent the bar characters.
    $bytes = $Utf8NoBom.GetBytes($Text)
    $standardOutput = [Console]::OpenStandardOutput()
    try {
        $standardOutput.Write($bytes, 0, $bytes.Length)
        $standardOutput.Flush()
    } finally {
        $standardOutput.Dispose()
    }
}

function Invoke-Main {
    $payloadText = [Console]::In.ReadToEnd()
    try {
        $payload = $payloadText | ConvertFrom-Json
    } catch {
        # A broken payload should degrade the status line, not replace it with an error.
        Write-Text "Usage: no data`n"
        return
    }
    $rateLimits = Get-JsonProperty $payload 'rate_limits'
    if ($rateLimits -is [System.Management.Automation.PSCustomObject] -and @($rateLimits.PSObject.Properties).Count -gt 0) {
        try {
            Save-RateLimits $rateLimits
        } catch {
            [Console]::Error.WriteLine("rate_limits not saved to ${StateFile}: $($_.Exception.Message)")
        }
    }
    $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
    $lines = @(
        (Format-Window 'Session 5h' (Get-JsonProperty $rateLimits 'five_hour') $now),
        (Format-Window 'Weekly    ' (Get-JsonProperty $rateLimits 'seven_day') $now)
    )
    Write-Text (($lines -join "`n") + "`n")
}

Invoke-Main
