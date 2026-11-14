<#
.SYNOPSIS
    Unlazier uninstaller for Windows.

.DESCRIPTION
    Removes only what Unlazier added; everything else in each tool's configuration stays.
    The work is done by install.ps1 in uninstall mode, so both share one harness table.

    From a clone:     .\uninstall.ps1 [-Harness <names|all>] [-Yes]
    Without a clone:  irm https://raw.githubusercontent.com/fco3lho/unlazier/main/uninstall.ps1 | iex

.PARAMETER Harness
    Comma-separated names (claude,opencode,codex,copilot,gemini,amp,kiro,cline,devin) or "all".
    Without it, an interactive menu is shown.

.PARAMETER Yes
    Answer "yes" to confirmations.
#>
param(
    [string]$Harness = '',
    [switch]$Yes
)

# Parameters are forwarded by name rather than through @args, because arguments that arrive
# from "powershell -File" are plain strings and would not bind as switches.
& {
    param([string]$RequestedHarnesses, [bool]$AssumeYes)

    $ErrorActionPreference = 'Stop'

    # Run the sibling installer only when this script is a file in a clone; when piped through
    # "irm | iex" there is no script folder and the installer is downloaded instead.
    $localInstaller = ''
    if ($PSScriptRoot) {
        $localInstaller = [System.IO.Path]::Combine($PSScriptRoot, 'install.ps1')
    }
    if ($localInstaller -and (Test-Path -LiteralPath $localInstaller -PathType Leaf)) {
        & $localInstaller -Uninstall -Harness $RequestedHarnesses -Yes:$AssumeYes
        return
    }

    # Windows PowerShell 5.1 may still default to TLS 1.0, which GitHub refuses.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor
        [System.Net.SecurityProtocolType]::Tls12
    $installer = [scriptblock]::Create((Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/fco3lho/unlazier/main/install.ps1' -UseBasicParsing))
    & $installer -Uninstall -Harness $RequestedHarnesses -Yes:$AssumeYes
} $Harness $Yes.IsPresent
