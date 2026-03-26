#requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\config.ini"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\Modules\Config.psm1" -Force
$config = Import-IniFile -Path $ConfigPath
$config['SRP']['ConfigureSRP'] = $true

Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\Modules\SRP.psm1" -Force

Initialize-Logging -Path $config['General']['LogPath']
Assert-Administrator

Write-Log -Message 'SRP rollout is separate by design. Validate in a test machine before broad use.' -Level WARN
Invoke-Step -Name 'Software Restriction Policies rollout' -Action { Set-BaselineSRP -Config $config }
Write-Log -Message 'SRP rollout completed. Reboot and validate critical workflows before release.' -Level WARN
