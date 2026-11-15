<#
.SYNOPSIS
    Unlazier installer for Windows.

.DESCRIPTION
    Every harness receives the same three layers: the rules (a marked block in its global
    instructions file), a reinforcement hook that re-injects a short reminder, and a usage
    line inside that reminder. Existing user content is never replaced and no backups are made.

    From a clone:     .\install.ps1 [-Harness <names|all>] [-Yes] [-Uninstall]
    Without a clone:  irm https://raw.githubusercontent.com/fco3lho/unlazier/main/install.ps1 | iex
    With options:     & ([scriptblock]::Create((irm https://raw.githubusercontent.com/fco3lho/unlazier/main/install.ps1))) -Harness codex

.PARAMETER Harness
    Comma-separated names (claude,opencode,codex,copilot,gemini,amp,kiro,cline,devin) or "all".
    Without it, an interactive menu is shown.

.PARAMETER Yes
    Answer "yes" to confirmations (removal of files left by version 1).

.PARAMETER Uninstall
    Remove Unlazier from the selected harnesses.
#>
param(
    [string]$Harness = '',
    [switch]$Yes,
    [switch]$Uninstall
)

# Everything runs inside one script block so that "irm | iex" leaves no functions, variables,
# or strict-mode settings behind in the user's session. This file is kept ASCII-only because
# Windows PowerShell 5.1 reads scripts without a byte order mark in the legacy code page.
& {
    param([string]$RequestedHarnesses, [bool]$AssumeYes, [bool]$IsUninstall)

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 2.0

    $RawBase = 'https://raw.githubusercontent.com/fco3lho/unlazier/main'
    $AllHarnesses = @('claude', 'opencode', 'codex', 'copilot', 'gemini', 'amp', 'kiro', 'cline', 'devin')
    $RuleNames = @('structure', 'correctness', 'style', 'completeness', 'performance', 'testability', 'async',
        'naming', 'documentation', 'parallelism')
    $PayloadFiles = @('AGENTS.md', 'reminder.md', 'hooks/inject.ps1', 'hooks/alert.ps1',
        'statusline/claude-statusline.ps1', 'plugins/opencode.ts', 'plugins/amp.ts')
    $MarkerStart = '<!-- unlazier:start -->'
    $MarkerEnd = '<!-- unlazier:end -->'
    $PayloadDirectoryName = 'unlazier'

    # Version 2.0 used the name "unlazier-ai" for its markers, folders, and files.
    $LegacyName = 'unlazier-ai'
    $LegacyMarkerStart = '<!-- unlazier-ai:start -->'
    $LegacyMarkerEnd = '<!-- unlazier-ai:end -->'
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    # Version 1 files are recognized by the SHA-256 of their LF-normalized text, so files the
    # user edited are never removed and a CRLF checkout still matches.
    $V1RuleHashes = [ordered]@{
        structure = '50c7847bc6028e3aa05fcd16b4e900db931add85c34fa6dd2876f776ea6af4dd'
        correctness = '433b07ea07e853c0d0777dd79498e97e4cfd856d7d4bbfac20f8cbbff35162f1'
        style = '7355aafe8ac15d558e559d1a438c361d437ea389b2273c7d2305b2e9e825428c'
        completeness = 'b0d1ccaad006b3a80c021e5ace32ee04af90d2aa089fcf0a454fa7c8299e9937'
        performance = '66ba1ed98dd71ecd8244a761d498d2998985f63d8dd9ecc3f8761ff27304a370'
        testability = 'ba9db45fff917017318c672f8cd93d48e5d468fd2f5850c90657f905d266e970'
        async = '7b91f29fd67d1afa14977a0579966eb0febf3b41a9ee412c186906bc0f4c539c'
        naming = '0394477016365aa80c7306adc712f5d2e79b80e77ff474d0eaf486fdc42ad111'
        documentation = '03314d59d1808518680a28c4856623e21b5ea589a9737e6c47ba063967a44aa7'
    }
    $V1SkillHashes = [ordered]@{
        'bugfix' = '82f28d1a67d1e00fa0c160e409e801221f03e672614ae3cc2c46c271b33302e0'
        'code-review' = '9d726ebefa475e8e7bdc99e6775558ef13c3d53f88dcad43033fa45846b8a86b'
        'refactoring' = '0bf86046b84bae55f534bbf283153ece35b291f8c7bd55041171f5261f9e9315'
    }
    $V1OpenCodeConfig = '{"$schema":"https://opencode.ai/config.json","instructions":["~/.config/opencode/AGENTS.md","~/.config/opencode/rules/*.md"],"skills":{"paths":["~/.config/opencode/skills"]}}'
    $V1GlobalHeading = '# Global Agent Rules'

    # Mutable run state lives in one object so functions can update it without scope modifiers.
    $State = @{
        SourceDirectory = ''
        DownloadDirectory = ''
        Notices = New-Object System.Collections.Generic.List[string]
    }

    function Write-Log {
        param([string]$Message)
        Write-Host $Message
    }

    function Add-Notice {
        param([string]$Message)
        $State.Notices.Add("  - $Message")
    }

    # -----------------------------------------------------------------------
    # Harness adapters: the only part that differs between harnesses.
    # -----------------------------------------------------------------------

    function Get-HarnessLabel {
        param([string]$Name)
        switch ($Name) {
            'claude' { return 'Claude Code' }
            'opencode' { return 'OpenCode' }
            'codex' { return 'Codex CLI' }
            'copilot' { return 'GitHub Copilot CLI' }
            'gemini' { return 'Gemini CLI' }
            'amp' { return 'Amp' }
            'kiro' { return 'Kiro' }
            'cline' { return 'Cline' }
            'devin' { return 'Devin Desktop (formerly Windsurf)' }
            default { throw "unknown harness '$Name'" }
        }
    }

    function Get-EnvironmentOrDefault {
        param([string]$Name, [string]$Default)
        $value = [Environment]::GetEnvironmentVariable($Name)
        if ([string]::IsNullOrEmpty($value)) {
            return $Default
        }
        return $value
    }

    # Cline keeps its global rules under the user's Documents folder, which Windows may redirect
    # (for example to OneDrive). UNLAZIER_DOCUMENTS_DIR overrides it because the real folder
    # comes from the registry and cannot be isolated otherwise; the tests rely on it.
    function Get-DocumentsDirectory {
        $override = [Environment]::GetEnvironmentVariable('UNLAZIER_DOCUMENTS_DIR')
        if (-not [string]::IsNullOrEmpty($override)) {
            return $override
        }
        if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
            return [Environment]::GetFolderPath('MyDocuments')
        }
        return [System.IO.Path]::Combine($HOME, 'Documents')
    }

    function Get-HarnessHome {
        param([string]$Name)
        switch ($Name) {
            'claude' { return Get-EnvironmentOrDefault 'CLAUDE_CONFIG_DIR' ([System.IO.Path]::Combine($HOME, '.claude')) }
            'opencode' { return [System.IO.Path]::Combine($HOME, '.config', 'opencode') }
            'codex' { return Get-EnvironmentOrDefault 'CODEX_HOME' ([System.IO.Path]::Combine($HOME, '.codex')) }
            'copilot' { return Get-EnvironmentOrDefault 'COPILOT_HOME' ([System.IO.Path]::Combine($HOME, '.copilot')) }
            'gemini' { return [System.IO.Path]::Combine((Get-EnvironmentOrDefault 'GEMINI_CLI_HOME' $HOME), '.gemini') }
            'amp' { return [System.IO.Path]::Combine($HOME, '.config', 'amp') }
            'kiro' { return Get-EnvironmentOrDefault 'KIRO_HOME' ([System.IO.Path]::Combine($HOME, '.kiro')) }
            'cline' { return [System.IO.Path]::Combine((Get-DocumentsDirectory), 'Cline') }
            'devin' { return [System.IO.Path]::Combine($HOME, '.devin') }
            default { throw "unknown harness '$Name'" }
        }
    }

    function Get-HarnessBinaries {
        param([string]$Name)
        switch ($Name) {
            'kiro' { return @('kiro-cli', 'kiro') }
            'devin' { return @('devin-desktop', 'devin', 'windsurf') }
            default { return @($Name) }
        }
    }

    # Harnesses that always load every file in a rules folder get one small file per rule there,
    # which keeps each file short (Claude Code recommends under 200 lines per file) and leaves the
    # user's own instructions file untouched. Returns '' for the other harnesses.
    function Get-RulesFolder {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        switch ($Name) {
            { $_ -in @('claude', 'devin') } { return [System.IO.Path]::Combine($harnessHome, 'rules') }
            'kiro' { return [System.IO.Path]::Combine($harnessHome, 'steering') }
            'cline' { return [System.IO.Path]::Combine($harnessHome, 'Rules') }
            # Copilot's instructions folder holds path-specific files, so it is not used.
            { $_ -in @('opencode', 'codex', 'amp', 'copilot', 'gemini') } { return '' }
            default { throw "unknown harness '$Name'" }
        }
    }

    # The single global instructions file that holds the rules block, for harnesses without a
    # rules folder.
    function Get-RulesFile {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        switch ($Name) {
            { $_ -in @('opencode', 'codex', 'amp') } { return [System.IO.Path]::Combine($harnessHome, 'AGENTS.md') }
            'copilot' { return [System.IO.Path]::Combine($harnessHome, 'copilot-instructions.md') }
            'gemini' { return [System.IO.Path]::Combine($harnessHome, 'GEMINI.md') }
            default { throw "'$Name' uses a rules folder, not a single rules file" }
        }
    }

    function Test-HarnessDetected {
        param([string]$Name)
        foreach ($binary in (Get-HarnessBinaries $Name)) {
            if ($null -ne (Get-Command $binary -ErrorAction SilentlyContinue)) {
                return $true
            }
        }
        return (Test-Path -LiteralPath (Get-HarnessHome $Name) -PathType Container)
    }

    # Forward slashes work in every shell that runs hooks on Windows: Git Bash (Claude Code),
    # cmd.exe (Codex), and PowerShell (Gemini CLI).
    function Get-ScriptCommand {
        param([string]$ScriptPath, [string]$Arguments)
        $command = 'powershell -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f ($ScriptPath -replace '\\', '/')
        if ($Arguments) {
            $command = "$command $Arguments"
        }
        return $command
    }

    function Get-HookCommand {
        param([string]$Name, [string]$EventName)
        $scriptPath = [System.IO.Path]::Combine((Get-HarnessHome $Name), $PayloadDirectoryName, 'inject.ps1')
        return Get-ScriptCommand $scriptPath "$Name $EventName"
    }

    function Get-AlertCommand {
        param([string]$Name)
        $scriptPath = [System.IO.Path]::Combine((Get-HarnessHome $Name), $PayloadDirectoryName, 'alert.ps1')
        return Get-ScriptCommand $scriptPath ''
    }

    function Get-DevinHooksFile {
        $appData = [Environment]::GetEnvironmentVariable('APPDATA')
        if ([string]::IsNullOrEmpty($appData)) {
            return [System.IO.Path]::Combine($HOME, '.config', 'devin', 'config.json')
        }
        return [System.IO.Path]::Combine($appData, 'devin', 'config.json')
    }

    # -----------------------------------------------------------------------
    # Text and JSON files.
    # -----------------------------------------------------------------------

    # Keeps the user's byte order mark so that removing the block restores the file exactly.
    function Read-TextFile {
        param([string]$Path)
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $offset = 0
        if ($hasBom) {
            $offset = 3
        }
        return [pscustomobject]@{
            Text = $Utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)
            HasBom = $hasBom
        }
    }

    function Write-TextFile {
        param([string]$Path, [string]$Text, [bool]$HasBom)
        [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
        [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($HasBom)))
    }

    function Read-SourceText {
        param([string]$RelativePath)
        $path = [System.IO.Path]::Combine($State.SourceDirectory, $RelativePath)
        return (Read-TextFile $path).Text -replace "`r`n", "`n"
    }

    function Get-JsonProperty {
        param($Object, [string]$Name)
        if ($Object -is [System.Management.Automation.PSCustomObject] -and $null -ne $Object.PSObject.Properties[$Name]) {
            return , $Object.PSObject.Properties[$Name].Value
        }
        return $null
    }

    function Set-JsonProperty {
        param($Object, [string]$Name, $Value)
        if ($null -ne $Object.PSObject.Properties[$Name]) {
            $Object.PSObject.Properties[$Name].Value = $Value
        } else {
            Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value
        }
    }

    # PowerShell 7.5+ can keep date-like strings as strings; older versions turn them into
    # DateTime, which would change how they are written back.
    function ConvertFrom-JsonText {
        param([string]$Text)
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
            return ($Text | ConvertFrom-Json -DateKind String)
        }
        return ($Text | ConvertFrom-Json)
    }

    # PowerShell 7's ConvertFrom-Json accepts comments and trailing commas; a strict parse keeps a
    # hand-edited file with comments from being rewritten without them.
    # System.Text.Json is loaded once in Invoke-Main on PowerShell 7.
    function Assert-StrictJson {
        param([string]$Text)
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            [System.Text.Json.JsonDocument]::Parse($Text, (New-Object System.Text.Json.JsonDocumentOptions)).Dispose()
        }
    }

    # Returns the parsed object, an empty object for a missing or blank file, or $null when the
    # file cannot be parsed, so callers leave a hand-edited config untouched.
    function Read-JsonConfig {
        param([string]$Path)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return [pscustomobject]@{}
        }
        $text = (Read-TextFile $Path).Text
        if ([string]::IsNullOrWhiteSpace($text)) {
            return [pscustomobject]@{}
        }
        try {
            Assert-StrictJson $text
            $document = ConvertFrom-JsonText $text
        } catch {
            Write-Warning "$Path is not valid JSON ($($_.Exception.Message)); skipped. Add the Unlazier hook by hand (see README)."
            return $null
        }
        if ($document -isnot [System.Management.Automation.PSCustomObject]) {
            Write-Warning "$Path does not hold a JSON object; skipped. Add the Unlazier hook by hand (see README)."
            return $null
        }
        return $document
    }

    function Write-JsonConfig {
        param([string]$Path, $Document)
        $json = (ConvertTo-Json -InputObject $Document -Depth 20) -replace "`r`n", "`n"
        Write-TextFile $Path ($json + "`n") $false
    }

    function ConvertTo-CompactJson {
        param($Document)
        return ConvertTo-Json -InputObject $Document -Depth 20 -Compress
    }

    # Claude Code, Codex, Gemini CLI, and Devin share the same hook layout:
    # {"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "..."}]}]}}.
    # Entries whose command mentions unlazier are ours; everything else is left untouched.
    function Test-OurCommand {
        param($Hook)
        $command = Get-JsonProperty $Hook 'command'
        return ($null -ne $command) -and ([string]$command).Contains('unlazier')
    }

    function Remove-OurHookEntries {
        param([object[]]$Entries)
        $kept = New-Object System.Collections.ArrayList
        foreach ($entry in $Entries) {
            $hooks = Get-JsonProperty $entry 'hooks'
            if ($hooks -is [array]) {
                [object[]]$remaining = @($hooks | Where-Object { -not (Test-OurCommand $_) })
                if ($remaining.Count -eq 0) {
                    continue
                }
                Set-JsonProperty $entry 'hooks' $remaining
            }
            [void]$kept.Add($entry)
        }
        return , ([object[]]$kept.ToArray())
    }

    # Returns $false when the existing layout is not the expected one, so the file is left alone.
    function Add-HookEntry {
        param($Document, [string]$EventName, [string]$Matcher, [string]$Command)
        $hooks = Get-JsonProperty $Document 'hooks'
        if ($null -eq $hooks) {
            $hooks = [pscustomobject]@{}
            Set-JsonProperty $Document 'hooks' $hooks
        } elseif ($hooks -isnot [System.Management.Automation.PSCustomObject]) {
            return $false
        }
        $existing = Get-JsonProperty $hooks $EventName
        [object[]]$entries = @()
        if ($null -ne $existing) {
            if ($existing -isnot [array]) {
                return $false
            }
            $entries = Remove-OurHookEntries $existing
        }
        $entry = [ordered]@{}
        if ($Matcher) {
            $entry['matcher'] = $Matcher
        }
        $entry['hooks'] = [object[]]@([pscustomobject]@{ type = 'command'; command = $Command })
        Set-JsonProperty $hooks $EventName ([object[]]($entries + @([pscustomobject]$entry)))
        return $true
    }

    function Remove-OurHooks {
        param($Document)
        $hooks = Get-JsonProperty $Document 'hooks'
        if ($hooks -isnot [System.Management.Automation.PSCustomObject]) {
            return
        }
        foreach ($property in @($hooks.PSObject.Properties)) {
            if ($property.Value -isnot [array]) {
                continue
            }
            [object[]]$remaining = Remove-OurHookEntries $property.Value
            if ($remaining.Count -eq 0) {
                $hooks.PSObject.Properties.Remove($property.Name)
            } else {
                $property.Value = $remaining
            }
        }
        if (@($hooks.PSObject.Properties).Count -eq 0) {
            $Document.PSObject.Properties.Remove('hooks')
        }
    }

    # Applies the registrations to a hook config; returns $false when the file was left unchanged.
    function Update-HookConfig {
        param([string]$Path, [object[]]$Registrations)
        $document = Read-JsonConfig $Path
        if ($null -eq $document) {
            return $false
        }
        foreach ($registration in $Registrations) {
            if (-not (Add-HookEntry $document $registration.EventName $registration.Matcher $registration.Command)) {
                Write-Warning "could not update $Path; it was left unchanged."
                return $false
            }
        }
        Write-JsonConfig $Path $document
        return $true
    }

    function New-Registration {
        param([string]$EventName, [string]$Matcher, [string]$Command)
        return @{ EventName = $EventName; Matcher = $Matcher; Command = $Command }
    }

    # Removes our entries; deletes the file if nothing else remains in it. A file without our
    # entries is not rewritten, so its formatting stays as the user left it.
    function Clear-HookConfig {
        param([string]$Path, [bool]$IncludeStatusLine)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return
        }
        $document = Read-JsonConfig $Path
        if ($null -eq $document) {
            return
        }
        $before = ConvertTo-CompactJson $document
        Remove-OurHooks $document
        if ($IncludeStatusLine) {
            $statusCommand = Get-JsonProperty (Get-JsonProperty $document 'statusLine') 'command'
            if ($null -ne $statusCommand -and ([string]$statusCommand).Contains('unlazier')) {
                $document.PSObject.Properties.Remove('statusLine')
            }
        }
        if (@($document.PSObject.Properties).Count -eq 0) {
            Remove-Item -LiteralPath $Path -Force
        } elseif ((ConvertTo-CompactJson $document) -ne $before) {
            Write-JsonConfig $Path $document
        }
    }

    function Register-Hooks {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        switch ($Name) {
            'claude' {
                return Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) @(
                    (New-Registration 'UserPromptSubmit' '' (Get-HookCommand 'claude' 'prompt')),
                    (New-Registration 'SessionStart' 'compact' (Get-HookCommand 'claude' 'compact'))
                )
            }
            'codex' {
                $isUpdated = Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'hooks.json')) @(
                    (New-Registration 'UserPromptSubmit' '' (Get-HookCommand 'codex' 'prompt')),
                    (New-Registration 'SessionStart' 'compact' (Get-HookCommand 'codex' 'compact'))
                )
                if ($isUpdated) {
                    Add-Notice 'Codex: open Codex and run /hooks once to trust the Unlazier hooks.'
                }
                return $isUpdated
            }
            'gemini' {
                return Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) @(
                    (New-Registration 'BeforeAgent' '' (Get-HookCommand 'gemini' 'prompt'))
                )
            }
            'devin' {
                # Devin documents no output format for PostCompaction, so only the prompt hook is used.
                return Update-HookConfig (Get-DevinHooksFile) @(
                    (New-Registration 'UserPromptSubmit' '' (Get-HookCommand 'devin' 'prompt'))
                )
            }
            'kiro' {
                $hookFile = [System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier.json')
                Write-JsonConfig $hookFile ([pscustomobject]@{
                    version = 'v1'
                    hooks = [object[]]@(
                        [pscustomobject]@{
                            name = 'unlazier-prompt'; trigger = 'UserPromptSubmit'
                            action = [pscustomobject]@{ type = 'command'; command = (Get-HookCommand 'kiro' 'prompt') }
                            timeout = 30
                        },
                        [pscustomobject]@{
                            name = 'unlazier-compact'; trigger = 'PostCompact'
                            action = [pscustomobject]@{ type = 'command'; command = (Get-HookCommand 'kiro' 'compact') }
                            timeout = 30
                        }
                    )
                })
                return $true
            }
            'cline' {
                Add-Notice 'Cline: hooks are not supported on Windows, so there are no reminder or alert hooks.'
                return $false
            }
            { $_ -in @('opencode', 'amp') } {
                Install-Plugin $Name
                return $true
            }
            'copilot' {
                Add-Notice 'Copilot CLI: Copilot ignores prompt-hook output, so there is no reminder hook.'
                return $false
            }
            default { throw "unknown harness '$Name'" }
        }
    }

    # Layer 4: three beeps when the agent asks for permission, asks a question, or finishes its
    # turn, using each harness's own events. OpenCode and Amp get it from their plugin.
    function Register-Alerts {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        $alert = Get-AlertCommand $Name
        switch ($Name) {
            'claude' {
                return Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) @(
                    (New-Registration 'Notification' 'permission_prompt' $alert),
                    (New-Registration 'PreToolUse' 'AskUserQuestion' $alert),
                    (New-Registration 'Stop' '' $alert)
                )
            }
            'codex' {
                return Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'hooks.json')) @(
                    (New-Registration 'PermissionRequest' '' $alert),
                    (New-Registration 'PreToolUse' '^request_user_input$' $alert),
                    (New-Registration 'Stop' '' $alert)
                )
            }
            'gemini' {
                # Gemini's Notification event covers both permission prompts and questions.
                return Update-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) @(
                    (New-Registration 'Notification' '' $alert),
                    (New-Registration 'AfterAgent' '' $alert)
                )
            }
            'devin' {
                return Update-HookConfig (Get-DevinHooksFile) @(
                    (New-Registration 'PermissionRequest' '' $alert),
                    (New-Registration 'PreToolUse' '^ask_user_question$' $alert),
                    (New-Registration 'Stop' '' $alert)
                )
            }
            'kiro' {
                # Kiro has no permission or question event; only the end of the turn beeps.
                $hookFile = [System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier-alert.json')
                Write-JsonConfig $hookFile ([pscustomobject]@{
                    version = 'v1'
                    hooks = [object[]]@(
                        [pscustomobject]@{
                            name = 'unlazier-alert'; trigger = 'Stop'
                            action = [pscustomobject]@{ type = 'command'; command = $alert }
                            timeout = 10
                        }
                    )
                })
                return $true
            }
            'copilot' {
                $hookFile = [System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier.json')
                Write-JsonConfig $hookFile ([pscustomobject]@{
                    version = 1
                    hooks = [pscustomobject]@{
                        notification = [object[]]@(
                            [pscustomobject]@{
                                matcher = 'permission_prompt|elicitation_dialog'; type = 'command'
                                powershell = $alert; timeoutSec = 10
                            }
                        )
                        agentStop = [object[]]@(
                            [pscustomobject]@{ type = 'command'; powershell = $alert; timeoutSec = 10 }
                        )
                    }
                })
                return $true
            }
            # Windows has no Cline hooks (see Register-Hooks); OpenCode and Amp use their plugin.
            { $_ -in @('cline', 'opencode', 'amp') } { return $false }
            default { throw "unknown harness '$Name'" }
        }
    }

    function Unregister-Hooks {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        switch ($Name) {
            'claude' { Clear-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) $true }
            'gemini' { Clear-HookConfig ([System.IO.Path]::Combine($harnessHome, 'settings.json')) $false }
            'codex' { Clear-HookConfig ([System.IO.Path]::Combine($harnessHome, 'hooks.json')) $false }
            'devin' { Clear-HookConfig (Get-DevinHooksFile) $false }
            'kiro' {
                Remove-FileIfPresent ([System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier.json'))
                Remove-FileIfPresent ([System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier-alert.json'))
            }
            { $_ -in @('opencode', 'amp') } {
                Remove-FileIfPresent ([System.IO.Path]::Combine($harnessHome, 'plugins', 'unlazier.ts'))
            }
            'copilot' { Remove-FileIfPresent ([System.IO.Path]::Combine($harnessHome, 'hooks', 'unlazier.json')) }
            # Nothing was registered for Cline on Windows.
            'cline' { }
            default { throw "unknown harness '$Name'" }
        }
    }

    function Remove-FileIfPresent {
        param([string]$Path)
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force
        }
    }

    function Install-Plugin {
        param([string]$Name)
        $pluginDirectory = [System.IO.Path]::Combine((Get-HarnessHome $Name), 'plugins')
        [void][System.IO.Directory]::CreateDirectory($pluginDirectory)
        $source = [System.IO.Path]::Combine($State.SourceDirectory, 'plugins', "$Name.ts")
        Copy-Item -LiteralPath $source -Destination ([System.IO.Path]::Combine($pluginDirectory, 'unlazier.ts')) -Force
    }

    # Claude Code passes usage windows only to the status line, so the status line is the usage
    # source. An existing status line is never replaced. The 60-second refresh keeps the saved
    # usage fresh while no message is sent; a reading older than 15 minutes counts as unknown.
    function Install-StatusLine {
        $claudeHome = Get-HarnessHome 'claude'
        $settingsPath = [System.IO.Path]::Combine($claudeHome, 'settings.json')
        $document = Read-JsonConfig $settingsPath
        if ($null -eq $document) {
            return $false
        }
        if ($null -ne $document.PSObject.Properties['statusLine']) {
            $stateFile = [System.IO.Path]::Combine($claudeHome, 'state', 'rate_limits.json')
            if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
                Add-Notice "Claude Code: you already have a status line, so it was kept. To give the agent its usage, make it save the 'rate_limits' it receives to $stateFile (see README)."
            }
            return $false
        }
        $scriptPath = [System.IO.Path]::Combine($claudeHome, $PayloadDirectoryName, 'claude-statusline.ps1')
        Copy-Item -LiteralPath ([System.IO.Path]::Combine($State.SourceDirectory, 'statusline', 'claude-statusline.ps1')) `
            -Destination $scriptPath -Force
        Set-JsonProperty $document 'statusLine' ([pscustomobject]@{
            type = 'command'; command = (Get-ScriptCommand $scriptPath ''); refreshInterval = 60 })
        Write-JsonConfig $settingsPath $document
        return $true
    }

    # -----------------------------------------------------------------------
    # Rules layer: one file per rule in a rules folder, or a marked block inside the
    # harness's single instructions file.
    # -----------------------------------------------------------------------

    function Get-RulesText {
        $builder = New-Object System.Text.StringBuilder
        [void]$builder.Append((Read-SourceText 'AGENTS.md'))
        foreach ($name in $RuleNames) {
            [void]$builder.Append("`n").Append((Read-SourceText "rules/$name.md"))
        }
        return $builder.ToString()
    }

    function Test-HasMarker {
        param([string]$Text, [string]$Start = $MarkerStart)
        foreach ($line in ($Text -split "`n")) {
            if ($line.TrimEnd("`r") -eq $Start) {
                return $true
            }
        }
        return $false
    }

    # Replaces the lines from the start marker to the end marker with $Block, or drops them when
    # $Block is $null. Every other line keeps its exact bytes, including CRLF endings.
    function Set-MarkedBlock {
        param([string]$Text, $Block, [string]$Start = $MarkerStart, [string]$End = $MarkerEnd)
        $result = New-Object System.Collections.Generic.List[string]
        $isSkipping = $false
        foreach ($line in ($Text -split "`n")) {
            $bareLine = $line.TrimEnd("`r")
            if ($isSkipping) {
                if ($bareLine -eq $End) {
                    $isSkipping = $false
                }
                continue
            }
            if ($bareLine -eq $Start) {
                if ($null -ne $Block) {
                    $result.Add($Block)
                }
                $isSkipping = $true
                continue
            }
            $result.Add($line)
        }
        return ($result -join "`n")
    }

    # Replaces the block between the markers, or appends it when the file has none.
    function Write-RulesBlock {
        param([string]$Path)
        $block = $MarkerStart + "`n" + (Get-RulesText) + $MarkerEnd
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Write-TextFile $Path ($block + "`n") $false
            return
        }
        $file = Read-TextFile $Path
        if (Test-HasMarker $file.Text) {
            Write-TextFile $Path (Set-MarkedBlock $file.Text $block) $file.HasBom
            return
        }
        # A file without a final newline would glue the marker to its last line.
        $separator = ''
        if ($file.Text.Length -gt 0 -and -not $file.Text.EndsWith("`n")) {
            $separator = "`n"
        }
        Write-TextFile $Path ($file.Text + $separator + $block + "`n") $file.HasBom
    }

    # Removes the block (marked with the current markers unless others are given); deletes the
    # file when only whitespace is left.
    function Remove-RulesBlock {
        param([string]$Path, [string]$Start = $MarkerStart, [string]$End = $MarkerEnd)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return
        }
        $file = Read-TextFile $Path
        if (-not (Test-HasMarker $file.Text $Start)) {
            return
        }
        $remaining = Set-MarkedBlock $file.Text $null $Start $End
        if ([string]::IsNullOrWhiteSpace($remaining)) {
            Remove-Item -LiteralPath $Path -Force
            return
        }
        Write-TextFile $Path $remaining $file.HasBom
    }

    # Our files are recognized by the "unlazier" prefix; the pattern also covers the
    # unlazier-ai*.md files that version 2.0 wrote to these folders.
    function Remove-RuleFiles {
        param([string]$Folder)
        if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
            return
        }
        Get-ChildItem -LiteralPath $Folder -File -Filter 'unlazier*.md' | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }

    function Write-RuleFiles {
        param([string]$Folder)
        Remove-RuleFiles $Folder
        [void][System.IO.Directory]::CreateDirectory($Folder)
        Copy-Item -LiteralPath ([System.IO.Path]::Combine($State.SourceDirectory, 'AGENTS.md')) `
            -Destination ([System.IO.Path]::Combine($Folder, 'unlazier-principles.md')) -Force
        foreach ($name in $RuleNames) {
            Copy-Item -LiteralPath ([System.IO.Path]::Combine($State.SourceDirectory, 'rules', "$name.md")) `
                -Destination ([System.IO.Path]::Combine($Folder, "unlazier-$name.md")) -Force
        }
    }

    function Install-Rules {
        param([string]$Name)
        $folder = Get-RulesFolder $Name
        if (-not $folder) {
            $file = Get-RulesFile $Name
            Write-RulesBlock $file
            Write-Log "  rules      -> $file"
            return
        }
        Write-RuleFiles $folder
        Write-Log "  rules      -> $([System.IO.Path]::Combine($folder, 'unlazier-*.md'))"
    }

    function Uninstall-Rules {
        param([string]$Name)
        $folder = Get-RulesFolder $Name
        if (-not $folder) {
            Remove-RulesBlock (Get-RulesFile $Name)
            return
        }
        Remove-RuleFiles $folder
    }

    # Removes what version 2.0 installed under its old name, so it does not load next to the
    # renamed files. Hook entries, the status line, and rule files need nothing extra: their
    # names contain "unlazier", which matches both names.
    function Remove-LegacyNames {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        $folder = Get-RulesFolder $Name
        if (-not $folder) {
            Remove-RulesBlock (Get-RulesFile $Name) $LegacyMarkerStart $LegacyMarkerEnd
        } elseif ($Name -eq 'claude') {
            # Version 2.0 put the Claude Code rules in a block inside CLAUDE.md.
            Remove-RulesBlock ([System.IO.Path]::Combine($harnessHome, 'CLAUDE.md')) $LegacyMarkerStart $LegacyMarkerEnd
        }
        $legacyFiles = @()
        switch ($Name) {
            { $_ -in @('opencode', 'amp') } { $legacyFiles = @([System.IO.Path]::Combine($harnessHome, 'plugins', "$LegacyName.ts")) }
            'kiro' { $legacyFiles = @([System.IO.Path]::Combine($harnessHome, 'hooks', "$LegacyName.json")) }
        }
        foreach ($path in $legacyFiles) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Remove-Item -LiteralPath $path -Force
            }
        }
        $legacyFolder = [System.IO.Path]::Combine($harnessHome, $LegacyName)
        if (Test-Path -LiteralPath $legacyFolder -PathType Container) {
            Remove-Item -LiteralPath $legacyFolder -Recurse -Force
        }
    }

    # Copies the files the hook reads into <harness home>\unlazier\.
    function Install-Payload {
        param([string]$Name)
        $target = [System.IO.Path]::Combine((Get-HarnessHome $Name), $PayloadDirectoryName)
        [void][System.IO.Directory]::CreateDirectory($target)
        $files = @('AGENTS.md', 'reminder.md', 'hooks/inject.ps1', 'hooks/alert.ps1')
        foreach ($relativePath in $files) {
            $source = [System.IO.Path]::Combine($State.SourceDirectory, $relativePath)
            Copy-Item -LiteralPath $source -Destination ([System.IO.Path]::Combine($target, (Split-Path -Leaf $relativePath))) -Force
        }
    }

    function Remove-Payload {
        param([string]$Name)
        $target = [System.IO.Path]::Combine((Get-HarnessHome $Name), $PayloadDirectoryName)
        # The folder holds only files this installer copied, so removing it whole is safe.
        if (Test-Path -LiteralPath $target -PathType Container) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }

    # -----------------------------------------------------------------------
    # Version 1 leftovers (Claude Code and OpenCode only).
    # -----------------------------------------------------------------------

    function Get-NormalizedHash {
        param([string]$Path)
        $text = (Read-TextFile $Path).Text -replace "`r`n", "`n"
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $algorithm.ComputeHash($Utf8NoBom.GetBytes($text))
        } finally {
            $algorithm.Dispose()
        }
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }

    function Test-HashMatch {
        param([string]$Path, [string]$Expected)
        return (Test-Path -LiteralPath $Path -PathType Leaf) -and ((Get-NormalizedHash $Path) -eq $Expected)
    }

    function Test-V1OpenCodeConfig {
        param([string]$Path)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $false
        }
        $text = (Read-TextFile $Path).Text
        try {
            $document = ConvertFrom-JsonText $text
        } catch {
            # A file that does not parse cannot be the generated version 1 config.
            return $false
        }
        return (ConvertTo-CompactJson $document) -eq (ConvertTo-CompactJson (ConvertFrom-JsonText $V1OpenCodeConfig))
    }

    function Find-V1Leftovers {
        param([string]$Name)
        $leftovers = New-Object System.Collections.Generic.List[string]
        if ($Name -ne 'claude' -and $Name -ne 'opencode') {
            return , $leftovers
        }
        $harnessHome = Get-HarnessHome $Name

        $globalFile = [System.IO.Path]::Combine($harnessHome, 'AGENTS.md')
        if ($Name -eq 'claude') {
            $globalFile = [System.IO.Path]::Combine($harnessHome, 'CLAUDE.md')
        }
        if (Test-Path -LiteralPath $globalFile -PathType Leaf) {
            $text = (Read-TextFile $globalFile).Text
            $firstLine = ($text -split "`n")[0].TrimEnd("`r")
            if ($firstLine -eq $V1GlobalHeading -and -not (Test-HasMarker $text)) {
                $leftovers.Add($globalFile)
            }
        }

        foreach ($ruleName in $V1RuleHashes.Keys) {
            $rulePath = [System.IO.Path]::Combine($harnessHome, 'rules', "$ruleName.md")
            if (Test-HashMatch $rulePath $V1RuleHashes[$ruleName]) {
                $leftovers.Add($rulePath)
            }
        }

        foreach ($skillName in $V1SkillHashes.Keys) {
            $skillDirectory = [System.IO.Path]::Combine($harnessHome, 'skills', $skillName)
            $skillFile = [System.IO.Path]::Combine($skillDirectory, 'SKILL.md')
            if ((Test-HashMatch $skillFile $V1SkillHashes[$skillName]) -and
                    @(Get-ChildItem -LiteralPath $skillDirectory -Recurse -File -Force).Count -eq 1) {
                $leftovers.Add($skillDirectory)
            }
        }

        $openCodeConfig = [System.IO.Path]::Combine($harnessHome, 'opencode.json')
        if ($Name -eq 'opencode' -and (Test-V1OpenCodeConfig $openCodeConfig)) {
            $leftovers.Add($openCodeConfig)
        }
        return , $leftovers
    }

    function Remove-V1Leftovers {
        param([string[]]$Leftovers)
        if ($Leftovers.Count -eq 0) {
            return
        }
        Write-Log ''
        Write-Log 'Files from Unlazier version 1 were found:'
        foreach ($path in $Leftovers) {
            Write-Log "  - $path"
        }
        Write-Log "Version 2 replaces them. If you added your own notes to any of these files, answer 'n'."
        if (-not (Confirm-Action 'Remove these files?')) {
            Add-Notice 'Version 1 files were kept; rules may load twice until you remove them.'
            return
        }
        foreach ($path in $Leftovers) {
            Remove-Item -LiteralPath $path -Recurse -Force
            $parent = Split-Path -Parent $path
            if (@(Get-ChildItem -LiteralPath $parent -Force).Count -eq 0) {
                Remove-Item -LiteralPath $parent -Force
            }
        }
    }

    # -----------------------------------------------------------------------
    # Interaction and setup.
    # -----------------------------------------------------------------------

    # Returns the typed line, or $null when nobody can answer. UNLAZIER_NO_PROMPT=1 behaves
    # as if no terminal were attached (used by automation and tests).
    function Read-Answer {
        if ([Environment]::GetEnvironmentVariable('UNLAZIER_NO_PROMPT') -eq '1') {
            return $null
        }
        try {
            return Read-Host
        } catch [System.Management.Automation.PSInvalidOperationException] {
            # Read-Host refuses to run in a non-interactive session; treat it as no terminal.
            return $null
        }
    }

    function Confirm-Action {
        param([string]$Question)
        if ($AssumeYes) {
            return $true
        }
        Write-Host -NoNewline "$Question [y/N] "
        $answer = Read-Answer
        if ($null -eq $answer) {
            Write-Host ''
            return $false
        }
        return @('y', 'Y', 'yes', 'YES') -ccontains $answer.Trim()
    }

    function Select-Harnesses {
        $mode = 'install'
        if ($IsUninstall) {
            $mode = 'uninstall'
        }
        if ($RequestedHarnesses) {
            if ($RequestedHarnesses -eq 'all') {
                return , $AllHarnesses
            }
            [string[]]$names = @($RequestedHarnesses -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            foreach ($name in $names) {
                if ($AllHarnesses -notcontains $name) {
                    throw "unknown harness '$name'. Valid names: $($AllHarnesses -join ' ')"
                }
            }
            return , $names
        }

        [string[]]$detected = @($AllHarnesses | Where-Object { Test-HarnessDetected $_ })
        Write-Log ''
        Write-Log "Choose the tools to $mode Unlazier for (* = found on this computer):"
        for ($index = 0; $index -lt $AllHarnesses.Count; $index++) {
            $marker = ' '
            if ($detected -contains $AllHarnesses[$index]) {
                $marker = '*'
            }
            Write-Log "  $($index + 1)) $marker $(Get-HarnessLabel $AllHarnesses[$index])"
        }
        Write-Host -NoNewline 'Type numbers separated by spaces, "all", or press Enter for the tools marked with *: '
        $answer = Read-Answer
        if ($null -eq $answer) {
            Write-Host ''
            if ($detected.Count -eq 0) {
                throw 'no tool was found and no terminal is available; pass -Harness <names>.'
            }
            return , $detected
        }

        $answer = $answer.Trim()
        [string[]]$chosen = @()
        if ($answer -eq '') {
            $chosen = $detected
        } elseif ($answer -eq 'all') {
            $chosen = $AllHarnesses
        } else {
            foreach ($number in ($answer -split '\s+')) {
                if ($number -notmatch '^\d+$') {
                    throw "'$number' is not a number from the list."
                }
                $position = [int]$number
                if ($position -lt 1 -or $position -gt $AllHarnesses.Count) {
                    throw "$number is not in the list."
                }
                $chosen += $AllHarnesses[$position - 1]
            }
        }
        if ($chosen.Count -eq 0) {
            throw 'no tool selected.'
        }
        return , $chosen
    }

    function Initialize-Source {
        if ($PSScriptRoot -and
                (Test-Path -LiteralPath ([System.IO.Path]::Combine($PSScriptRoot, 'AGENTS.md')) -PathType Leaf) -and
                (Test-Path -LiteralPath ([System.IO.Path]::Combine($PSScriptRoot, 'hooks', 'inject.ps1')) -PathType Leaf)) {
            $State.SourceDirectory = $PSScriptRoot
            return
        }
        # The progress bar makes Invoke-WebRequest many times slower on Windows PowerShell 5.1.
        $ProgressPreference = 'SilentlyContinue'
        # Windows PowerShell 5.1 may still default to TLS 1.0, which GitHub refuses.
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor
            [System.Net.SecurityProtocolType]::Tls12
        $State.DownloadDirectory = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "unlazier-$([guid]::NewGuid())")
        $State.SourceDirectory = $State.DownloadDirectory
        Write-Log "Downloading Unlazier from $RawBase..."
        $relativePaths = $PayloadFiles + @($RuleNames | ForEach-Object { "rules/$_.md" })
        foreach ($relativePath in $relativePaths) {
            $destination = [System.IO.Path]::Combine($State.DownloadDirectory, $relativePath)
            [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
            try {
                Invoke-WebRequest -Uri "$RawBase/$relativePath" -OutFile $destination -UseBasicParsing
            } catch {
                throw "failed to download ${relativePath}: $($_.Exception.Message)"
            }
        }
    }

    # -----------------------------------------------------------------------
    # Per-harness pipelines: identical steps for every harness.
    # -----------------------------------------------------------------------

    function Add-HarnessWarnings {
        param([string]$Name)
        $harnessHome = Get-HarnessHome $Name
        switch ($Name) {
            'codex' {
                $override = [System.IO.Path]::Combine($harnessHome, 'AGENTS.override.md')
                if (Test-Path -LiteralPath $override -PathType Leaf) {
                    Add-Notice "Codex: $override exists, and Codex ignores AGENTS.md while it does."
                }
            }
            'opencode' {
                $claudeRules = [System.IO.Path]::Combine((Get-HarnessHome 'claude'), 'CLAUDE.md')
                $openCodeRules = [System.IO.Path]::Combine($harnessHome, 'AGENTS.md')
                if ((Test-Path -LiteralPath $claudeRules -PathType Leaf) -and -not (Test-Path -LiteralPath $openCodeRules -PathType Leaf)) {
                    Add-Notice "OpenCode: it stops reading ~/.claude/CLAUDE.md once $openCodeRules exists."
                }
            }
            default { }
        }
    }

    function Install-Harness {
        param([string]$Name)
        Write-Log ''
        Write-Log "$(Get-HarnessLabel $Name):"
        Add-HarnessWarnings $Name
        Remove-LegacyNames $Name
        Install-Payload $Name
        Install-Rules $Name
        if ($Name -in @('opencode', 'amp')) {
            # One plugin carries both the reminder and the alerts.
            [void](Register-Hooks $Name)
            Write-Log '  reminder   -> plugin'
            Write-Log '  alerts     -> plugin'
        } else {
            if (Register-Hooks $Name) {
                Write-Log '  reminder   -> hook registered'
            }
            if (Register-Alerts $Name) {
                Write-Log '  alerts     -> hook registered'
            }
        }
        if ($Name -eq 'claude' -and (Install-StatusLine)) {
            Write-Log '  usage      -> status line'
        }
    }

    function Uninstall-Harness {
        param([string]$Name)
        Write-Log ''
        Write-Log "$(Get-HarnessLabel $Name):"
        Remove-LegacyNames $Name
        Uninstall-Rules $Name
        Unregister-Hooks $Name
        Remove-Payload $Name
        Write-Log '  removed'
    }

    function Invoke-Main {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Add-Type -AssemblyName System.Text.Json
        }
        [string[]]$harnesses = Select-Harnesses
        if ($IsUninstall) {
            foreach ($name in $harnesses) {
                Uninstall-Harness $name
            }
        } else {
            try {
                Initialize-Source
                $leftovers = New-Object System.Collections.Generic.List[string]
                foreach ($name in $harnesses) {
                    foreach ($path in (Find-V1Leftovers $name)) {
                        $leftovers.Add($path)
                    }
                }
                Remove-V1Leftovers $leftovers.ToArray()
                foreach ($name in $harnesses) {
                    Install-Harness $name
                }
            } finally {
                if ($State.DownloadDirectory -and (Test-Path -LiteralPath $State.DownloadDirectory)) {
                    Remove-Item -LiteralPath $State.DownloadDirectory -Recurse -Force
                }
            }
        }

        if ($State.Notices.Count -gt 0) {
            Write-Log ''
            Write-Log 'Notes:'
            foreach ($notice in $State.Notices) {
                Write-Log $notice
            }
        }
        Write-Log ''
        Write-Log 'Done. Restart your tools for the changes to take effect.'
    }

    Invoke-Main
} $Harness $Yes.IsPresent $Uninstall.IsPresent
