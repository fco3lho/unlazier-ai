# Unlazier context hook for Windows.
#
# Usage: inject.ps1 <harness> <prompt|compact>
#   prompt   prints the short reminder and the usage line; runs on every user prompt.
#   compact  prints the core principles, the reminder, and the usage line; runs after
#            context compaction, when the original instructions may have been summarized away.
#
# Rules loaded at session start lose weight as the context window fills, so the harness
# calls this hook to place a compact copy near the end of the context. Installed at
# <harness home>\unlazier\inject.ps1 next to reminder.md and AGENTS.md. The output is
# byte-for-byte the same as inject.sh. This file is kept ASCII-only because Windows
# PowerShell 5.1 reads scripts without a byte order mark in the legacy code page.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ScriptDirectory = $PSScriptRoot
$HarnessHome = Split-Path -Parent $ScriptDirectory
$MaxReadingAgeSeconds = 900
$MaxSectionTitles = 12
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Opens the file with FileShare.ReadWrite because Codex keeps its session log open for
# writing; the default sharing mode would fail with a sharing violation.
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

# A Windows checkout may convert the payload to CRLF; LF keeps the output identical to inject.sh.
function Read-PayloadText {
    param([string]$Name)
    return (Read-SharedText ([System.IO.Path]::Combine($ScriptDirectory, $Name))) -replace "`r`n", "`n"
}

function Get-JsonProperty {
    param($Object, [string]$Name)
    if ($Object -is [System.Management.Automation.PSCustomObject] -and $null -ne $Object.PSObject.Properties[$Name]) {
        return , $Object.PSObject.Properties[$Name].Value
    }
    return $null
}

function Get-UnixTimeNow {
    return [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
}

# PowerShell 7 turns ISO dates into DateTime while 5.1 keeps strings; both are accepted.
# Fractions of a second are dropped, as jq's fromdateiso8601 does.
function ConvertTo-UnixSeconds {
    param($Value)
    if ($Value -is [System.DateTime]) {
        $utc = $Value
        if ($Value.Kind -eq [System.DateTimeKind]::Local) {
            $utc = $Value.ToUniversalTime()
        }
        return [double]([System.DateTimeOffset]::new([System.DateTime]::SpecifyKind($utc, 'Utc'))).ToUnixTimeSeconds()
    }
    if ($Value -is [string]) {
        $parsed = [System.DateTimeOffset]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal)
        return [double]$parsed.ToUnixTimeSeconds()
    }
    return $null
}

function Test-Number {
    param($Value)
    return ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal])
}

# A window counts only while its reset time is still in the future.
function Get-LivePercent {
    param($Percent, $ResetsAt, [double]$Now)
    if (-not (Test-Number $Percent)) {
        return $null
    }
    if ($null -eq $ResetsAt) {
        $ResetsAt = $Now + 1
    }
    if ([double]$ResetsAt -gt $Now) {
        return [double]$Percent
    }
    return $null
}

function Read-ClaudeUsage {
    param([double]$Now)
    $stateFile = [System.IO.Path]::Combine($HarnessHome, 'state', 'rate_limits.json')
    if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
        return $null
    }
    $state = (Read-SharedText $stateFile) | ConvertFrom-Json
    $fiveHour = Get-JsonProperty $state 'five_hour'
    $sevenDay = Get-JsonProperty $state 'seven_day'
    $capturedAt = Get-JsonProperty $state 'captured_at'
    if (-not (Test-Number $capturedAt)) {
        $capturedAt = $null
    }
    return @{
        FiveHour = Get-LivePercent (Get-JsonProperty $fiveHour 'used_percentage') (Get-JsonProperty $fiveHour 'resets_at') $Now
        Weekly = Get-LivePercent (Get-JsonProperty $sevenDay 'used_percentage') (Get-JsonProperty $sevenDay 'resets_at') $Now
        CapturedAt = $capturedAt
    }
}

function Find-NewestRollout {
    $sessionsDirectory = [System.IO.Path]::Combine($HarnessHome, 'sessions')
    if (-not (Test-Path -LiteralPath $sessionsDirectory -PathType Container)) {
        return $null
    }
    [string[]]$rollouts = @(Get-ChildItem -LiteralPath $sessionsDirectory -Recurse -File -Force |
        Where-Object { $_.Name -like 'rollout-*.jsonl' } |
        ForEach-Object { $_.FullName })
    if ($rollouts.Count -eq 0) {
        return $null
    }
    # Rollout paths are sessions\YYYY\MM\DD\rollout-<timestamp>-<id>.jsonl, so the ordinal
    # maximum is the most recent session.
    [System.Array]::Sort($rollouts, [System.StringComparer]::Ordinal)
    return $rollouts[$rollouts.Count - 1]
}

function Find-LastRateLimitEvent {
    param([string]$Path)
    $lines = (Read-SharedText $Path) -split "`n"
    for ($index = $lines.Count - 1; $index -ge 0; $index--) {
        # Parsing every line of a long session is slow; only token_count lines can match.
        if (-not $lines[$index].Contains('"token_count"')) {
            continue
        }
        try {
            $record = $lines[$index] | ConvertFrom-Json
        } catch {
            # The last line can be half-written while Codex appends to the log; the previous
            # complete event is the latest reading, as with jq in inject.sh.
            continue
        }
        $payload = Get-JsonProperty $record 'payload'
        if ((Get-JsonProperty $record 'type') -eq 'event_msg' -and (Get-JsonProperty $payload 'type') -eq 'token_count' `
                -and $null -ne (Get-JsonProperty $payload 'rate_limits')) {
            return $record
        }
    }
    return $null
}

function Read-CodexUsage {
    param([double]$Now)
    $rollout = Find-NewestRollout
    if ($null -eq $rollout) {
        return $null
    }
    $record = Find-LastRateLimitEvent $rollout
    if ($null -eq $record) {
        return $null
    }
    $capturedAt = ConvertTo-UnixSeconds (Get-JsonProperty $record 'timestamp')
    if ($null -eq $capturedAt) {
        return $null
    }
    $rateLimits = Get-JsonProperty (Get-JsonProperty $record 'payload') 'rate_limits'
    $windows = @(@((Get-JsonProperty $rateLimits 'primary'), (Get-JsonProperty $rateLimits 'secondary')) |
        Where-Object { $null -ne $_ })
    return @{
        FiveHour = Select-CodexWindow $windows 300 $capturedAt $Now
        Weekly = Select-CodexWindow $windows 10080 $capturedAt $Now
        CapturedAt = $capturedAt
    }
}

# Windows are matched by length (300 minutes = 5 hours, 10080 = one week), not by position.
function Select-CodexWindow {
    param([object[]]$Windows, [int]$Minutes, [double]$CapturedAt, [double]$Now)
    foreach ($window in $Windows) {
        if ((Get-JsonProperty $window 'window_minutes') -ne $Minutes) {
            continue
        }
        $resetsAt = Get-JsonProperty $window 'resets_at'
        $resetsInSeconds = Get-JsonProperty $window 'resets_in_seconds'
        if ($null -eq $resetsAt -and (Test-Number $resetsInSeconds)) {
            $resetsAt = $CapturedAt + $resetsInSeconds
        }
        $percent = Get-LivePercent (Get-JsonProperty $window 'used_percent') $resetsAt $Now
        if ($null -ne $percent) {
            return $percent
        }
    }
    return $null
}

function Format-Percent {
    param($Value)
    if ($null -eq $Value) {
        return 'unknown'
    }
    return ([long][System.Math]::Floor($Value + 0.5)).ToString([System.Globalization.CultureInfo]::InvariantCulture) + '%'
}

function Get-UsageLine {
    param([string]$Harness)
    $now = Get-UnixTimeNow
    switch ($Harness) {
        'claude' { $source = 'Claude Code status line' }
        'codex' { $source = 'Codex session log' }
        default { return 'Usage: unknown (this tool does not expose usage windows)' }
    }
    # A missing or corrupt usage file must not break the hook: the reading becomes unknown, as
    # in inject.sh, and the cause goes to stderr where the harness logs it.
    try {
        if ($Harness -eq 'claude') {
            $reading = Read-ClaudeUsage $now
        } else {
            $reading = Read-CodexUsage $now
        }
    } catch {
        [Console]::Error.WriteLine("inject.ps1: usage reading failed: $($_.Exception.Message)")
        $reading = $null
    }
    if ($null -eq $reading) {
        return 'Usage: unknown (no usage reading available)'
    }
    if ($null -eq $reading.CapturedAt -or ($now - $reading.CapturedAt) -gt $MaxReadingAgeSeconds) {
        return 'Usage: unknown (no usage reading from the last 15 minutes)'
    }
    $ageMinutes = ([long][System.Math]::Floor(($now - $reading.CapturedAt) / 60)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    return "Usage: 5h $(Format-Percent $reading.FiveHour) | weekly $(Format-Percent $reading.Weekly) (source: $source, $ageMinutes min old)"
}

# The harness runs the hook from the project, so the repository root comes from the working
# directory, or the directory itself outside a repository or without git.
function Get-ProjectRoot {
    $location = (Get-Location).ProviderPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return $location
    }
    # Windows PowerShell 5.1 turns native stderr into terminating errors under 'Stop'.
    $ErrorActionPreference = 'Continue'
    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        return $location
    }
    return [System.IO.Path]::GetFullPath(@($root)[0])
}

# The project's own instruction file for the harness, or $null for harnesses without one.
function Find-ProjectRulesFile {
    param([string]$Harness)
    switch ($Harness) {
        'claude' { $names = @('CLAUDE.md', '.claude/CLAUDE.md') }
        { $_ -in @('codex', 'opencode', 'amp') } { $names = @('AGENTS.md') }
        'gemini' { $names = @('GEMINI.md') }
        default { return $null }
    }
    $root = Get-ProjectRoot
    foreach ($name in $names) {
        $path = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $name))
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }
    return $null
}

# The "## " titles of a Markdown file, comma-separated, skipping fenced code blocks.
function Get-SectionTitles {
    param([string]$Path)
    $titles = New-Object System.Collections.Generic.List[string]
    $count = 0
    $isFenced = $false
    foreach ($line in ((Read-SharedText $Path) -split "`n")) {
        if ($line -match '^(```|~~~)') {
            $isFenced = -not $isFenced
            continue
        }
        if (-not $isFenced -and $line -match '^## +(.*)$') {
            $count++
            if ($count -le $MaxSectionTitles) {
                $titles.Add($Matches[1].TrimEnd(' ', "`t", "`r"))
            }
        }
    }
    $text = $titles -join ', '
    if ($count -gt $MaxSectionTitles) {
        $text += ', ...'
    }
    return $text
}

# The project's rules lose weight between compactions like the global ones, but repeating the
# whole file on every prompt would fill the context, so the reminder names it and its sections.
function Get-ProjectRulesLine {
    param([string]$Harness)
    $path = Find-ProjectRulesFile $Harness
    if ($null -eq $path) {
        return ''
    }
    # A file that cannot be read still gets its line, without sections: the reminder must not
    # break, and the path lets the agent open the file and see the error itself.
    try {
        $titles = Get-SectionTitles $path
    } catch [System.IO.IOException], [System.UnauthorizedAccessException] {
        $titles = ''
    }
    if ($titles) {
        return "- Project rules: $path apply ($titles); re-read the relevant section before acting on it.`n"
    }
    return "- Project rules: $path apply; re-read the relevant section before acting on it.`n"
}

# Mirrors the shell version: the pieces are printed in order and command substitution
# strips the trailing newlines before the final one is added.
function Get-Context {
    param([string]$Harness, [string]$EventName)
    switch ($EventName) {
        'prompt' {
            $text = (Read-PayloadText 'reminder.md') + (Get-ProjectRulesLine $Harness) + (Get-UsageLine $Harness) + "`n"
        }
        'compact' {
            $text = (Read-PayloadText 'AGENTS.md') + "`n" + (Read-PayloadText 'reminder.md') + (Get-UsageLine $Harness) + "`n"
        }
        default {
            return $null
        }
    }
    return $text.TrimEnd("`n")
}

# Escapes a string the way jq does: control characters as \u00xx, non-ASCII left as UTF-8.
function ConvertTo-JsonString {
    param([string]$Text)
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    foreach ($character in $Text.ToCharArray()) {
        $code = [int]$character
        switch ($code) {
            0x22 { [void]$builder.Append('\"') }
            0x5C { [void]$builder.Append('\\') }
            0x0A { [void]$builder.Append('\n') }
            0x0D { [void]$builder.Append('\r') }
            0x09 { [void]$builder.Append('\t') }
            0x08 { [void]$builder.Append('\b') }
            0x0C { [void]$builder.Append('\f') }
            default {
                if ($code -lt 0x20 -or $code -eq 0x7F) {
                    [void]$builder.Append('\u').Append($code.ToString('x4'))
                } else {
                    [void]$builder.Append($character)
                }
            }
        }
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

# Each harness expects its own output shape; see the adapter table in README.md. The JSON is
# laid out exactly as jq prints it.
function Format-HookOutput {
    param([string]$Harness, [string]$Context)
    $value = ConvertTo-JsonString $Context
    switch ($Harness) {
        { $_ -in @('claude', 'codex', 'kiro', 'opencode', 'amp') } {
            return $Context + "`n"
        }
        'gemini' {
            return "{`n  `"hookSpecificOutput`": {`n    `"hookEventName`": `"BeforeAgent`",`n    `"additionalContext`": $value`n  }`n}`n"
        }
        'devin' {
            return "{`n  `"hookSpecificOutput`": {`n    `"hookEventName`": `"UserPromptSubmit`",`n    `"additionalContext`": $value`n  }`n}`n"
        }
        'cline' {
            return "{`n  `"cancel`": false,`n  `"contextModification`": $value`n}`n"
        }
        default {
            return $null
        }
    }
}

function Invoke-Main {
    param([string[]]$Arguments)
    if ($Arguments.Count -ne 2) {
        [Console]::Error.WriteLine('Usage: inject.ps1 <harness> <prompt|compact>')
        exit 2
    }
    $harness = $Arguments[0]
    $eventName = $Arguments[1]
    $context = Get-Context $harness $eventName
    if ($null -eq $context) {
        [Console]::Error.WriteLine("inject.ps1: unknown event '$eventName' (expected prompt or compact)")
        exit 2
    }
    $output = Format-HookOutput $harness $context
    if ($null -eq $output) {
        [Console]::Error.WriteLine("inject.ps1: unknown harness '$harness'")
        exit 1
    }
    # Raw UTF-8 bytes on stdout: Console.OutputEncoding defaults to the legacy code page and
    # setting it fails when the hook runs without a console.
    $bytes = $Utf8NoBom.GetBytes($output)
    $standardOutput = [Console]::OpenStandardOutput()
    try {
        $standardOutput.Write($bytes, 0, $bytes.Length)
        $standardOutput.Flush()
    } finally {
        $standardOutput.Dispose()
    }
}

Invoke-Main -Arguments $args
