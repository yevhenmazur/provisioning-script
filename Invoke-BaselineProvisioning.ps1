#requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [SecureString]$CurrentAdminPassword,

    [Parameter(Mandatory = $true)]
    [string]$StandardUser,

    [Parameter(Mandatory = $true)]
    [SecureString]$StandardUserPassword,

    [string]$ConfigPath = "$PSScriptRoot\config.ini"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

Import-Module "$PSScriptRoot\Modules\Config.psm1" -Force
$config = Import-IniFile -Path $ConfigPath

if ($config.Keys -contains 'General' -and $config['General'].Keys -contains 'LogPath') {
    $logPath = $config['General']['LogPath']
}
else {
    $logPath = Join-Path $PSScriptRoot 'baseline.log'
}

$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Import-Module "$PSScriptRoot\Modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Users.psm1" -Force
Import-Module "$PSScriptRoot\Modules\SecurityBaseline.psm1" -Force
Import-Module "$PSScriptRoot\Modules\WindowsFeatures.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Defender.psm1" -Force
Import-Module "$PSScriptRoot\Modules\BitLocker.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Office.psm1" -Force
Import-Module "$PSScriptRoot\Modules\ScriptHandling.psm1" -Force

Initialize-Logging -Path $logPath

Assert-Administrator

Invoke-Step -Name 'Password policy'         -Action { Set-BaselinePasswordPolicy -Config $config }
Invoke-Step -Name 'Users and privileges'    -Action { Set-BaselineUsers -Config $config -CurrentAdminPassword $CurrentAdminPassword -StandardUser $StandardUser -StandardUserPassword $StandardUserPassword }
Invoke-Step -Name 'UAC'                     -Action { Set-BaselineUAC -Config $config }
Invoke-Step -Name 'BitLocker'               -Action { Set-BaselineBitLocker -Config $config }
Invoke-Step -Name 'Microsoft Defender'      -Action { Set-BaselineDefender -Config $config }
Invoke-Step -Name 'Windows Updates'         -Action { Set-BaselineWindowsUpdate -Config $config }
Invoke-Step -Name 'Firewall'                -Action { Set-BaselineFirewall -Config $config }
Invoke-Step -Name 'Screen lock'             -Action { Set-BaselineScreenLock -Config $config }
Invoke-Step -Name 'Disable legacy features' -Action { Disable-BaselineLegacyFeatures -Config $config }
Invoke-Step -Name 'Office policies'         -Action { Set-BaselineOfficePolicies -Config $config }
Invoke-Step -Name 'Script handling'         -Action { Set-BaselineScriptHandling -Config $config }
Invoke-Step -Name 'SmartScreen'             -Action { Set-BaselineSmartScreen -Config $config }
Invoke-Step -Name 'Auditing'                -Action { Set-BaselineAuditing -Config $config }
Invoke-Step -Name 'Time sync'               -Action { Set-BaselineTimeSync -Config $config }

Write-Log -Message 'Provisioning completed'
Write-Log -Message 'Reboot is strongly recommended' -Level WARN