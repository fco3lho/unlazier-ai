# Tests for install.ps1, uninstall.ps1, hooks\inject.ps1, and the Claude Code status line.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests\install_test.ps1
#        (or pwsh -File tests/install_test.ps1)
#
# Every scenario runs the scripts in a child PowerShell process whose home folder points to a
# temporary directory, so the real configuration of the machine is never touched. The child
# process reads USERPROFILE/HOME (home folder), APPDATA (Devin), and UNLAZIER_AI_DOCUMENTS_DIR
# (Cline, whose Documents folder otherwise comes from the registry). This file is kept
# ASCII-only because Windows PowerShell 5.1 reads scripts without a byte order mark in the
# legacy code page.

$ErrorActionPreference = 'Stop'

$RepositoryDirectory = Split-Path -Parent $PSScriptRoot
$FixturesDirectory = [System.IO.Path]::Combine($PSScriptRoot, 'fixtures')
$InstallScript = [System.IO.Path]::Combine($RepositoryDirectory, 'install.ps1')
$UninstallScript = [System.IO.Path]::Combine($RepositoryDirectory, 'uninstall.ps1')
$PowerShellPath = (Get-Process -Id $PID).Path
$AllHarnesses = 'claude,opencode,codex,copilot,gemini,amp,kiro,cline,devin'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$IsolatedVariables = @('USERPROFILE', 'HOME', 'APPDATA', 'UNLAZIER_AI_DOCUMENTS_DIR', 'UNLAZIER_AI_NO_PROMPT',
    'CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'COPILOT_HOME', 'GEMINI_CLI_HOME', 'KIRO_HOME')
$Results = @{ Passed = 0; Failed = 0 }
$TemporaryHomes = New-Object System.Collections.Generic.List[string]

function Assert-That {
    param([string]$Description, [scriptblock]$Condition)
    $detail = ''
    try {
        $isSatisfied = [bool](& $Condition)
    } catch {
        $isSatisfied = $false
        $detail = " ($($_.Exception.Message))"
    }
    if ($isSatisfied) {
        $Results.Passed++
        Write-Host "  ok    $Description"
    } else {
        $Results.Failed++
        Write-Host "  FAIL  $Description$detail"
    }
}

function New-TestHome {
    $path = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "unlazier-ai-test-$([guid]::NewGuid())")
    [void][System.IO.Directory]::CreateDirectory($path)
    $TemporaryHomes.Add($path)
    return $path
}

function Join-TestPath {
    param([string]$Root, [string]$RelativePath)
    return [System.IO.Path]::Combine($Root, ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar))
}

function Write-TestFile {
    param([string]$Path, [string]$Text)
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Write-TestJson {
    param([string]$Path, $Document)
    Write-TestFile $Path ((ConvertTo-Json -InputObject $Document -Depth 20) + "`n")
}

function Read-TestJson {
    param([string]$Path)
    return ([System.IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

# Points the child process at the temporary home; the original values are restored at the end.
function Set-IsolatedEnvironment {
    param([string]$TestHome)
    foreach ($name in $IsolatedVariables) {
        [Environment]::SetEnvironmentVariable($name, $null)
    }
    [Environment]::SetEnvironmentVariable('USERPROFILE', $TestHome)
    [Environment]::SetEnvironmentVariable('HOME', $TestHome)
    [Environment]::SetEnvironmentVariable('APPDATA', (Join-TestPath $TestHome 'AppData/Roaming'))
    [Environment]::SetEnvironmentVariable('UNLAZIER_AI_DOCUMENTS_DIR', (Join-TestPath $TestHome 'Documents'))
    [Environment]::SetEnvironmentVariable('UNLAZIER_AI_NO_PROMPT', '1')
}

# Runs a script in a child process; returns its combined output and exit code.
function Invoke-TestScript {
    param([string]$TestHome, [string]$ScriptPath, [string[]]$Arguments, [string]$InputText)
    Set-IsolatedEnvironment $TestHome
    # Windows PowerShell 5.1 turns child stderr into terminating errors under 'Stop'.
    $ErrorActionPreference = 'Continue'
    $commandLine = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
    if ($PSBoundParameters.ContainsKey('InputText')) {
        $output = $InputText | & $PowerShellPath @commandLine 2>&1
    } else {
        $output = & $PowerShellPath @commandLine 2>&1
    }
    return [pscustomobject]@{
        Lines = [string[]]@($output | ForEach-Object { "$_" })
        ExitCode = $LASTEXITCODE
    }
}

function Invoke-Installer {
    param([string]$TestHome, [string[]]$Arguments)
    return Invoke-TestScript $TestHome $InstallScript $Arguments
}

function Invoke-Uninstaller {
    param([string]$TestHome, [string[]]$Arguments)
    return Invoke-TestScript $TestHome $UninstallScript $Arguments
}

function Invoke-Inject {
    param([string]$TestHome, [string]$PayloadDirectory, [string]$Harness, [string]$EventName)
    $scriptPath = [System.IO.Path]::Combine((Join-TestPath $TestHome $PayloadDirectory), 'unlazier-ai', 'inject.ps1')
    return Invoke-TestScript $TestHome $scriptPath @($Harness, $EventName)
}

function Get-BlockCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 0
    }
    return @([System.IO.File]::ReadAllText($Path) -split "`n" | Where-Object { $_.TrimEnd("`r") -eq '<!-- unlazier-ai:start -->' }).Count
}

function Test-ContainsLine {
    param([string]$Path, [string]$Line)
    return @([System.IO.File]::ReadAllText($Path) -split "`n" | Where-Object { $_.TrimEnd("`r") -eq $Line }).Count -gt 0
}

function Get-HookCommands {
    param($Document, [string]$EventName)
    return @($Document.hooks.$EventName | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
}

# Lists every file with its hash; JSON files are compared by content because the installer
# rewrites them with its own formatting.
function Get-Snapshot {
    param([string]$Root)
    $entries = Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        $relativePath = $_.FullName.Substring($Root.Length)
        if ($_.Extension -eq '.json') {
            "$relativePath $(ConvertTo-Json -InputObject (Read-TestJson $_.FullName) -Depth 20 -Compress)"
        } else {
            "$relativePath $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
        }
    }
    return ($entries -join "`n")
}

function Initialize-UserConfiguration {
    param([string]$TestHome)
    foreach ($directory in @('.claude', '.codex', '.gemini', '.copilot', '.config/opencode', '.config/amp',
            'AppData/Roaming/devin', '.kiro/steering', 'Documents/Cline/Rules', '.devin/rules')) {
        [void][System.IO.Directory]::CreateDirectory((Join-TestPath $TestHome $directory))
    }
    Write-TestFile (Join-TestPath $TestHome '.claude/CLAUDE.md') "# My notes`nAlways use tabs.`n"
    Write-TestFile (Join-TestPath $TestHome '.codex/AGENTS.md') "# Codex notes`n"
    Write-TestFile (Join-TestPath $TestHome '.gemini/GEMINI.md') "# Gemini notes`n"
    Write-TestJson (Join-TestPath $TestHome '.claude/settings.json') ([pscustomobject]@{
        model = 'opus'
        statusLine = [pscustomobject]@{ type = 'command'; command = 'my-status' }
        hooks = [pscustomobject]@{ Stop = [object[]]@([pscustomobject]@{
            hooks = [object[]]@([pscustomobject]@{ type = 'command'; command = 'beep' }) }) }
    })
    Write-TestJson (Join-TestPath $TestHome '.codex/hooks.json') ([pscustomobject]@{
        hooks = [pscustomobject]@{ UserPromptSubmit = [object[]]@([pscustomobject]@{
            hooks = [object[]]@([pscustomobject]@{ type = 'command'; command = 'my-codex-hook' }) }) }
    })
    Write-TestJson (Join-TestPath $TestHome '.gemini/settings.json') ([pscustomobject]@{ theme = 'dark' })
}

function Test-InstallPreservesUserContent {
    Write-Host 'install preserves existing configuration'
    $testHome = New-TestHome
    Initialize-UserConfiguration $testHome
    [void](Invoke-Installer $testHome @('-Harness', $AllHarnesses))

    Assert-That 'Claude notes kept' { Test-ContainsLine (Join-TestPath $testHome '.claude/CLAUDE.md') 'Always use tabs.' }
    Assert-That 'Codex notes kept' { Test-ContainsLine (Join-TestPath $testHome '.codex/AGENTS.md') '# Codex notes' }
    Assert-That 'existing Claude hook kept' {
        (Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.claude/settings.json')) 'Stop') -contains 'beep'
    }
    Assert-That 'existing Claude status line kept' {
        (Read-TestJson (Join-TestPath $testHome '.claude/settings.json')).statusLine.command -eq 'my-status'
    }
    Assert-That 'existing Codex hook kept' {
        (Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.codex/hooks.json')) 'UserPromptSubmit') -contains 'my-codex-hook'
    }
    Assert-That 'Gemini setting kept' { (Read-TestJson (Join-TestPath $testHome '.gemini/settings.json')).theme -eq 'dark' }
}

function Test-InstallAddsAllLayers {
    Write-Host 'install adds the three layers to every harness'
    $testHome = New-TestHome
    [void](Invoke-Installer $testHome @('-Harness', $AllHarnesses))

    foreach ($file in @('.claude/CLAUDE.md', '.config/opencode/AGENTS.md', '.codex/AGENTS.md',
            '.copilot/copilot-instructions.md', '.gemini/GEMINI.md', '.config/amp/AGENTS.md',
            '.kiro/steering/unlazier-ai.md', 'Documents/Cline/Rules/unlazier-ai.md',
            '.devin/rules/unlazier-ai-principles.md', '.devin/rules/unlazier-ai-rules.md')) {
        $path = Join-TestPath $testHome $file
        Assert-That "rules block in $file" { (Get-BlockCount $path) -eq 1 }
    }
    foreach ($directory in @('.claude', '.config/opencode', '.codex', '.copilot', '.gemini', '.config/amp', '.kiro',
            'Documents/Cline', '.devin')) {
        $path = Join-TestPath $testHome "$directory/unlazier-ai/reminder.md"
        Assert-That "payload in $directory/unlazier-ai" { Test-Path -LiteralPath $path -PathType Leaf }
    }
    Assert-That 'Devin principles under 12,000 characters' {
        [System.IO.File]::ReadAllText((Join-TestPath $testHome '.devin/rules/unlazier-ai-principles.md')).Length -lt 12000
    }
    Assert-That 'Devin topic rules under 12,000 characters' {
        [System.IO.File]::ReadAllText((Join-TestPath $testHome '.devin/rules/unlazier-ai-rules.md')).Length -lt 12000
    }
    $claudeSettings = Read-TestJson (Join-TestPath $testHome '.claude/settings.json')
    Assert-That 'Claude prompt hook' {
        @(Get-HookCommands $claudeSettings 'UserPromptSubmit' | Where-Object { $_.Contains('inject.ps1" claude prompt') }).Count -eq 1
    }
    Assert-That 'Claude compaction hook' { @($claudeSettings.hooks.SessionStart | Where-Object { $_.matcher -eq 'compact' }).Count -eq 1 }
    Assert-That 'Claude status line installed' { $claudeSettings.statusLine.command.Contains('claude-statusline.ps1') }
    Assert-That 'Codex hooks registered' {
        @(Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.codex/hooks.json')) 'UserPromptSubmit' |
            Where-Object { $_.Contains('inject.ps1" codex prompt') }).Count -eq 1
    }
    Assert-That 'Gemini hook registered' {
        @(Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.gemini/settings.json')) 'BeforeAgent' |
            Where-Object { $_.Contains('inject.ps1" gemini prompt') }).Count -eq 1
    }
    Assert-That 'Devin hook registered' {
        @(Get-HookCommands (Read-TestJson (Join-TestPath $testHome 'AppData/Roaming/devin/config.json')) 'UserPromptSubmit' |
            Where-Object { $_.Contains('inject.ps1" devin prompt') }).Count -eq 1
    }
    Assert-That 'Kiro hooks' {
        (@((Read-TestJson (Join-TestPath $testHome '.kiro/hooks/unlazier-ai.json')).hooks | ForEach-Object { $_.trigger }) -join ',') `
            -eq 'UserPromptSubmit,PostCompact'
    }
    Assert-That 'Cline hook skipped on Windows' {
        -not (Test-Path -LiteralPath (Join-TestPath $testHome 'Documents/Cline/Hooks'))
    }
    Assert-That 'OpenCode plugin' { Test-Path -LiteralPath (Join-TestPath $testHome '.config/opencode/plugins/unlazier-ai.ts') -PathType Leaf }
    Assert-That 'Amp plugin' { Test-Path -LiteralPath (Join-TestPath $testHome '.config/amp/plugins/unlazier-ai.ts') -PathType Leaf }
    Assert-That 'no backup folders' {
        @(Get-ChildItem -LiteralPath $testHome -Recurse -Depth 1 -Force -Filter '*.bak*').Count -eq 0
    }
}

function Test-ReinstallIsIdempotent {
    Write-Host 'reinstalling keeps a single copy'
    $testHome = New-TestHome
    Initialize-UserConfiguration $testHome
    [void](Invoke-Installer $testHome @('-Harness', $AllHarnesses))
    [void](Invoke-Installer $testHome @('-Harness', $AllHarnesses))

    Assert-That 'one block in CLAUDE.md' { (Get-BlockCount (Join-TestPath $testHome '.claude/CLAUDE.md')) -eq 1 }
    Assert-That 'one Claude prompt hook' {
        @(Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.claude/settings.json')) 'UserPromptSubmit' |
            Where-Object { $_.Contains('unlazier-ai') }).Count -eq 1
    }
    Assert-That 'one Codex prompt hook' {
        @(Get-HookCommands (Read-TestJson (Join-TestPath $testHome '.codex/hooks.json')) 'UserPromptSubmit' |
            Where-Object { $_.Contains('unlazier-ai') }).Count -eq 1
    }
}

function Test-UninstallRestoresOriginalFiles {
    Write-Host 'uninstall removes only what was added'
    $testHome = New-TestHome
    Initialize-UserConfiguration $testHome
    $before = Get-Snapshot $testHome
    [void](Invoke-Installer $testHome @('-Harness', $AllHarnesses))
    [void](Invoke-Uninstaller $testHome @('-Harness', $AllHarnesses))
    $after = Get-Snapshot $testHome

    Assert-That 'files identical to the original' { $before -eq $after }
    if ($before -ne $after) {
        Compare-Object ($before -split "`n") ($after -split "`n") | ForEach-Object {
            Write-Host "        $($_.SideIndicator) $($_.InputObject)"
        }
    }
}

function Initialize-V1Installation {
    param([string]$TestHome)
    $v1 = [System.IO.Path]::Combine($FixturesDirectory, 'v1')
    $claudeHome = Join-TestPath $TestHome '.claude'
    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($claudeHome, 'rules'))
    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($claudeHome, 'skills'))
    Copy-Item -LiteralPath ([System.IO.Path]::Combine($v1, 'AGENTS.md')) -Destination ([System.IO.Path]::Combine($claudeHome, 'CLAUDE.md'))
    Get-ChildItem -LiteralPath ([System.IO.Path]::Combine($v1, 'rules')) -File |
        Copy-Item -Destination ([System.IO.Path]::Combine($claudeHome, 'rules'))
    Get-ChildItem -LiteralPath ([System.IO.Path]::Combine($v1, 'skills')) -Directory |
        Copy-Item -Destination ([System.IO.Path]::Combine($claudeHome, 'skills')) -Recurse
    $editedRule = [System.IO.Path]::Combine($claudeHome, 'rules', 'style.md')
    [System.IO.File]::AppendAllText($editedRule, "# edited by the user`n", $Utf8NoBom)
    Write-TestFile ([System.IO.Path]::Combine($claudeHome, 'skills', 'my-skill', 'SKILL.md')) "mine`n"

    $openCodeHome = Join-TestPath $TestHome '.config/opencode'
    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($openCodeHome, 'skills'))
    Copy-Item -LiteralPath ([System.IO.Path]::Combine($v1, 'opencode.json')) -Destination ([System.IO.Path]::Combine($openCodeHome, 'opencode.json'))
    Copy-Item -LiteralPath ([System.IO.Path]::Combine($v1, 'skills', 'bugfix')) -Destination ([System.IO.Path]::Combine($openCodeHome, 'skills')) -Recurse
}

function Test-V1LeftoversRemovedWithYes {
    Write-Host 'version 1 files are removed after confirmation'
    $testHome = New-TestHome
    Initialize-V1Installation $testHome
    [void](Invoke-Installer $testHome @('-Harness', 'claude,opencode', '-Yes'))

    Assert-That 'v1 rule removed' { -not (Test-Path -LiteralPath (Join-TestPath $testHome '.claude/rules/async.md')) }
    Assert-That 'edited v1 rule kept' { Test-Path -LiteralPath (Join-TestPath $testHome '.claude/rules/style.md') -PathType Leaf }
    Assert-That 'v1 skill removed' { -not (Test-Path -LiteralPath (Join-TestPath $testHome '.claude/skills/bugfix')) }
    Assert-That 'user skill kept' { Test-Path -LiteralPath (Join-TestPath $testHome '.claude/skills/my-skill/SKILL.md') -PathType Leaf }
    Assert-That 'v1 OpenCode config removed' { -not (Test-Path -LiteralPath (Join-TestPath $testHome '.config/opencode/opencode.json')) }
    Assert-That 'v1 CLAUDE.md replaced by a block only' {
        ([System.IO.File]::ReadAllText((Join-TestPath $testHome '.claude/CLAUDE.md')) -split "`n")[0] -eq '<!-- unlazier-ai:start -->'
    }
}

function Test-V1LeftoversKeptWithoutConfirmation {
    Write-Host 'version 1 files are kept without confirmation'
    $testHome = New-TestHome
    Initialize-V1Installation $testHome
    [void](Invoke-Installer $testHome @('-Harness', 'claude'))

    Assert-That 'v1 rule kept' { Test-Path -LiteralPath (Join-TestPath $testHome '.claude/rules/async.md') -PathType Leaf }
    Assert-That 'v1 skill kept' { Test-Path -LiteralPath (Join-TestPath $testHome '.claude/skills/bugfix') -PathType Container }
}

function Test-InvalidJsonLeftUntouched {
    Write-Host 'an unreadable config file is never rewritten'
    $testHome = New-TestHome
    $settings = Join-TestPath $testHome '.claude/settings.json'
    Write-TestFile $settings "{ `"model`": `"opus`", // comment`n}`n"
    $before = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
    [void](Invoke-Installer $testHome @('-Harness', 'claude'))

    Assert-That 'settings.json unchanged' { (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash -eq $before }
    Assert-That 'rules still installed' { (Get-BlockCount (Join-TestPath $testHome '.claude/CLAUDE.md')) -eq 1 }
}

function Get-UnixNow {
    return [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Write-CodexRollouts {
    param([string]$TestHome, [long]$Now)
    $timestamp = [System.DateTimeOffset]::FromUnixTimeSeconds($Now - 60).UtcDateTime.ToString(
        "yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    Write-TestFile (Join-TestPath $TestHome '.codex/sessions/2026/11/13/rollout-2026-11-13T00-00-00-a.jsonl') (
        '{"timestamp":"2026-11-13T00:00:00Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":1,"window_minutes":300}}}}' + "`n")
    $reading = [pscustomobject]@{
        timestamp = $timestamp; type = 'event_msg'
        payload = [pscustomobject]@{ type = 'token_count'; rate_limits = [pscustomobject]@{
            primary = [pscustomobject]@{ used_percent = 42.6; window_minutes = 300; resets_at = $Now + 999 }
            secondary = [pscustomobject]@{ used_percent = 61.2; window_minutes = 10080; resets_in_seconds = 5000 } } }
    }
    $empty = [pscustomobject]@{
        timestamp = $timestamp; type = 'event_msg'
        payload = [pscustomobject]@{ type = 'token_count'; rate_limits = $null }
    }
    $lines = @((ConvertTo-Json -InputObject $reading -Depth 10 -Compress), (ConvertTo-Json -InputObject $empty -Depth 10 -Compress))
    Write-TestFile (Join-TestPath $TestHome '.codex/sessions/2026/11/14/rollout-2026-11-14T10-00-00-b.jsonl') (($lines -join "`n") + "`n")
}

function Get-LastLine {
    param($Result)
    return $Result.Lines[$Result.Lines.Count - 1]
}

function Test-InjectUsageLines {
    Write-Host 'inject reports usage from each source'
    $testHome = New-TestHome
    $now = Get-UnixNow
    [void](Invoke-Installer $testHome @('-Harness', 'claude,codex,gemini,devin,cline,kiro'))
    $stateFile = Join-TestPath $testHome '.claude/state/rate_limits.json'
    Write-TestJson $stateFile ([pscustomobject]@{
        captured_at = $now - 120
        five_hour = [pscustomobject]@{ used_percentage = 24.4; resets_at = $now + 3600 }
        seven_day = [pscustomobject]@{ used_percentage = 94; resets_at = $now - 5 }
    })
    Write-CodexRollouts $testHome $now

    Assert-That 'Claude usage line' {
        (Get-LastLine (Invoke-Inject $testHome '.claude' 'claude' 'prompt')) -eq 'Usage: 5h 24% | weekly unknown (source: Claude Code status line, 2 min old)'
    }
    Assert-That 'Codex usage line' {
        (Get-LastLine (Invoke-Inject $testHome '.codex' 'codex' 'prompt')) -eq 'Usage: 5h 43% | weekly 61% (source: Codex session log, 1 min old)'
    }
    Assert-That 'Kiro usage unknown' {
        (Get-LastLine (Invoke-Inject $testHome '.kiro' 'kiro' 'prompt')) -eq 'Usage: unknown (this tool does not expose usage windows)'
    }

    $state = Read-TestJson $stateFile
    $state.captured_at = $now - 3600
    Write-TestJson $stateFile $state
    Assert-That 'stale Claude reading is unknown' {
        (Get-LastLine (Invoke-Inject $testHome '.claude' 'claude' 'prompt')) -eq 'Usage: unknown (no usage reading from the last 15 minutes)'
    }
}

function ConvertFrom-OutputJson {
    param($Result)
    return (($Result.Lines -join "`n") | ConvertFrom-Json)
}

function Test-InjectOutputFormats {
    Write-Host 'inject prints the shape each harness expects'
    $testHome = New-TestHome
    [void](Invoke-Installer $testHome @('-Harness', 'claude,gemini,devin,cline'))

    Assert-That 'Claude prompt is the reminder text' {
        (Invoke-Inject $testHome '.claude' 'claude' 'prompt').Lines[0] -eq 'Unlazier AI rules are active for this session.'
    }
    Assert-That 'Claude compaction starts with the principles' {
        (Invoke-Inject $testHome '.claude' 'claude' 'compact').Lines[0] -eq '# Global Agent Rules'
    }
    Assert-That 'Gemini output is JSON' {
        (ConvertFrom-OutputJson (Invoke-Inject $testHome '.gemini' 'gemini' 'prompt')).hookSpecificOutput.additionalContext.StartsWith('Unlazier AI rules')
    }
    Assert-That 'Devin output is JSON' {
        (ConvertFrom-OutputJson (Invoke-Inject $testHome '.devin' 'devin' 'prompt')).hookSpecificOutput.additionalContext.StartsWith('Unlazier AI rules')
    }
    Assert-That 'Cline output is JSON' {
        (ConvertFrom-OutputJson (Invoke-Inject $testHome 'Documents/Cline' 'cline' 'prompt')).contextModification.StartsWith('Unlazier AI rules')
    }
    Assert-That 'unknown event fails' { (Invoke-Inject $testHome '.claude' 'claude' 'other').ExitCode -eq 2 }
}

function Test-StatusLineSavesUsage {
    Write-Host 'Claude status line shows and saves usage'
    $testHome = New-TestHome
    [void](Invoke-Installer $testHome @('-Harness', 'claude'))
    $now = Get-UnixNow
    $statusLineScript = Join-TestPath $testHome '.claude/unlazier-ai/claude-statusline.ps1'
    $payload = ConvertTo-Json -Depth 10 -Compress -InputObject ([pscustomobject]@{ rate_limits = [pscustomobject]@{
        five_hour = [pscustomobject]@{ used_percentage = 24; resets_at = $now + 600 }
        seven_day = [pscustomobject]@{ used_percentage = 94; resets_at = $now + 90000 } } })
    $result = Invoke-TestScript $testHome $statusLineScript @() $payload

    Assert-That 'status line shows the 5-hour window' { @($result.Lines | Where-Object { $_ -match '^Session 5h: .* 24%' }).Count -eq 1 }
    Assert-That 'usage saved for the hook' {
        $saved = Read-TestJson (Join-TestPath $testHome '.claude/state/rate_limits.json')
        $saved.five_hour.used_percentage -eq 24 -and $null -ne $saved.captured_at
    }
    Assert-That 'broken input degrades' { (Get-LastLine (Invoke-TestScript $testHome $statusLineScript @() 'garbage')) -eq 'Usage: no data' }
}

$originalEnvironment = @{}
foreach ($name in $IsolatedVariables) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    Test-InstallPreservesUserContent
    Test-InstallAddsAllLayers
    Test-ReinstallIsIdempotent
    Test-UninstallRestoresOriginalFiles
    Test-V1LeftoversRemovedWithYes
    Test-V1LeftoversKeptWithoutConfirmation
    Test-InvalidJsonLeftUntouched
    Test-InjectUsageLines
    Test-InjectOutputFormats
    Test-StatusLineSavesUsage
} finally {
    foreach ($name in $IsolatedVariables) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name])
    }
    foreach ($path in $TemporaryHomes) {
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Continue
    }
}

Write-Host ''
Write-Host "$($Results.Passed) passed, $($Results.Failed) failed"
if ($Results.Failed -gt 0) {
    exit 1
}
