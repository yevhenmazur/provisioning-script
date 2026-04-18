#requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path $scriptRoot 'config.ini'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = New-Object System.Collections.Generic.List[object]

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $PSScriptRoot "baseline-check-$timestamp.log"

function Add-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'FAIL', 'SKIP')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $results.Add([PSCustomObject]@{
        Name    = $Name
        Status  = $Status
        Message = $Message
    })
}

function Add-BooleanResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Success,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Add-Result -Name $Name -Status $(if ($Success) { 'OK' } else { 'FAIL' }) -Message $Message
}

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Check
    )

    try {
        & $Check
    }
    catch {
        Add-Result -Name $Name -Status 'FAIL' -Message $_.Exception.Message
    }
}

function Invoke-ConfigurableCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Config,
        [string]$Section,
        [string]$Key,
        [object]$EnabledValue = $true,
        [string]$SkipReason = 'Disabled by config',
        [Parameter(Mandatory = $true)][scriptblock]$Check
    )

    try {
        if (-not [string]::IsNullOrWhiteSpace($Section) -and -not [string]::IsNullOrWhiteSpace($Key)) {
            $actualConfigValue = Get-ConfigValue -Config $Config -Section $Section -Key $Key -Default $null

            if ($null -eq $actualConfigValue) {
                Add-Result -Name $Name -Status 'SKIP' -Message "Missing config value [$Section] $Key"
                return
            }

            $shouldRun = $false

            if ($EnabledValue -is [bool]) {
                $shouldRun = ([System.Convert]::ToBoolean($actualConfigValue) -eq $EnabledValue)
            }
            else {
                $shouldRun = ($actualConfigValue.ToString() -eq $EnabledValue.ToString())
            }

            if (-not $shouldRun) {
                Add-Result -Name $Name -Status 'SKIP' -Message $SkipReason
                return
            }
        }

        & $Check
    }
    catch {
        Add-Result -Name $Name -Status 'FAIL' -Message $_.Exception.Message
    }
}

function Get-RegValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return (Get-ItemProperty -Path $Path -ErrorAction Stop).$Name
}

function Get-NetAccountsValue {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    $output = net accounts
    $line = $output | Where-Object { $_ -match $Pattern } | Select-Object -First 1

    if (-not $line) {
        throw "Could not parse net accounts output for pattern: $Pattern"
    }

    return ($line -split ':', 2)[1].Trim()
}

function Test-ConfigValueExists {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Config,
        [Parameter(Mandatory = $true)][string]$Section,
        [Parameter(Mandatory = $true)][string]$Key
    )

    return (($Config.Keys -contains $Section) -and ($Config[$Section].Keys -contains $Key))
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Config,
        [Parameter(Mandatory = $true)][string]$Section,
        [Parameter(Mandatory = $true)][string]$Key,
        [object]$Default = $null
    )

    if (Test-ConfigValueExists -Config $Config -Section $Section -Key $Key) {
        return $Config[$Section][$Key]
    }

    return $Default
}

if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

Import-Module "$PSScriptRoot\Modules\Config.psm1" -Force
$config = Import-IniFile -Path $ConfigPath

# --- Users ---

Invoke-ConfigurableCheck -Name 'BuiltInAdministratorDisabled' -Config $config -Section 'Users' -Key 'DisableBuiltInAdministrator' -EnabledValue $true -Check {
    $admin = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue

    if ($null -eq $admin) {
        Add-Result -Name 'BuiltInAdministratorDisabled' -Status 'OK' -Message 'Built-in Administrator account not present'
        return
    }

    Add-BooleanResult -Name 'BuiltInAdministratorDisabled' -Success (-not $admin.Enabled) -Message "Enabled=$($admin.Enabled)"
}

# --- UAC ---

Invoke-Check -Name 'UAC' -Check {
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

    $expectedEnableLUA = [int](Get-ConfigValue -Config $config -Section 'UAC' -Key 'EnableLUA' -Default 1)
    $expectedPrompt = [int](Get-ConfigValue -Config $config -Section 'UAC' -Key 'ConsentPromptBehaviorAdmin' -Default 2)
    $expectedSecureDesktop = [int](Get-ConfigValue -Config $config -Section 'UAC' -Key 'PromptOnSecureDesktop' -Default 1)
    $expectedFilterAdmin = [int](Get-ConfigValue -Config $config -Section 'UAC' -Key 'FilterAdministratorToken' -Default 1)

    $actualEnableLUA = Get-RegValue -Path $path -Name 'EnableLUA'
    $actualPrompt = Get-RegValue -Path $path -Name 'ConsentPromptBehaviorAdmin'
    $actualSecureDesktop = Get-RegValue -Path $path -Name 'PromptOnSecureDesktop'
    $actualFilterAdmin = Get-RegValue -Path $path -Name 'FilterAdministratorToken'

    $ok = ($actualEnableLUA -eq $expectedEnableLUA) -and
          ($actualPrompt -eq $expectedPrompt) -and
          ($actualSecureDesktop -eq $expectedSecureDesktop) -and
          ($actualFilterAdmin -eq $expectedFilterAdmin)

    Add-BooleanResult -Name 'UAC' -Success $ok -Message "EnableLUA=$actualEnableLUA, ConsentPromptBehaviorAdmin=$actualPrompt, PromptOnSecureDesktop=$actualSecureDesktop, FilterAdministratorToken=$actualFilterAdmin"
}

# --- BitLocker ---

Invoke-ConfigurableCheck -Name 'BitLocker' -Config $config -Section 'BitLocker' -Key 'EnableBitLocker' -EnabledValue $true -Check {
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        Add-Result -Name 'BitLocker' -Status 'FAIL' -Message 'BitLocker cmdlets are not available'
        return
    }

    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    $ok = ($bl.ProtectionStatus -eq 'On') -and ($bl.VolumeStatus -in @('FullyEncrypted', 'EncryptionInProgress'))

    Add-BooleanResult -Name 'BitLocker' -Success $ok -Message "ProtectionStatus=$($bl.ProtectionStatus), VolumeStatus=$($bl.VolumeStatus)"
}

# --- Defender ---

Invoke-ConfigurableCheck -Name 'DefenderRealtimeProtection' -Config $config -Section 'Defender' -Key 'EnableRealtimeProtection' -EnabledValue $true -Check {
    $status = Get-MpComputerStatus -ErrorAction Stop
    Add-BooleanResult -Name 'DefenderRealtimeProtection' -Success ([bool]$status.RealTimeProtectionEnabled) -Message "RealTimeProtectionEnabled=$($status.RealTimeProtectionEnabled)"
}

Invoke-ConfigurableCheck -Name 'DefenderCloudProtection' -Config $config -Section 'Defender' -Key 'EnableCloudProtection' -EnabledValue $true -Check {
    $pref = Get-MpPreference -ErrorAction Stop
    $ok = ($pref.MAPSReporting -ne 0)
    Add-BooleanResult -Name 'DefenderCloudProtection' -Success $ok -Message "MAPSReporting=$($pref.MAPSReporting)"
}

Invoke-Check -Name 'DefenderTamperProtection' -Check {
    $status = Get-MpComputerStatus -ErrorAction Stop
    Add-BooleanResult -Name 'DefenderTamperProtection' -Success ([bool]$status.IsTamperProtected) -Message "IsTamperProtected=$($status.IsTamperProtected)"
}

Invoke-ConfigurableCheck -Name 'DefenderPUAProtection' -Config $config -Section 'Defender' -Key 'EnablePUAProtection' -EnabledValue $true -Check {
    $pref = Get-MpPreference -ErrorAction Stop
    $ok = ($pref.PUAProtection -eq 1)
    Add-BooleanResult -Name 'DefenderPUAProtection' -Success $ok -Message "PUAProtection=$($pref.PUAProtection)"
}

Invoke-ConfigurableCheck -Name 'DefenderControlledFolderAccess' -Config $config -Section 'Defender' -Key 'EnableControlledFolderAccess' -EnabledValue $true -Check {
    $pref = Get-MpPreference -ErrorAction Stop
    $ok = ($pref.EnableControlledFolderAccess -eq 1)
    Add-BooleanResult -Name 'DefenderControlledFolderAccess' -Success $ok -Message "EnableControlledFolderAccess=$($pref.EnableControlledFolderAccess)"
}

# --- Windows Update ---

Invoke-Check -Name 'WindowsAutoUpdate' -Check {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

    $expectedNoAutoUpdate = [int](Get-ConfigValue -Config $config -Section 'WindowsUpdate' -Key 'NoAutoUpdate' -Default 0)
    $expectedAUOptions = [int](Get-ConfigValue -Config $config -Section 'WindowsUpdate' -Key 'AUOptions' -Default 4)

    $actualNoAutoUpdate = Get-RegValue -Path $path -Name 'NoAutoUpdate'
    $actualAUOptions = Get-RegValue -Path $path -Name 'AUOptions'

    $ok = ($actualNoAutoUpdate -eq $expectedNoAutoUpdate) -and ($actualAUOptions -eq $expectedAUOptions)

    Add-BooleanResult -Name 'WindowsAutoUpdate' -Success $ok -Message "NoAutoUpdate=$actualNoAutoUpdate, AUOptions=$actualAUOptions"
}

# --- Firewall ---

Invoke-ConfigurableCheck -Name 'FirewallDomainProfile' -Config $config -Section 'Firewall' -Key 'EnableDomainProfile' -EnabledValue $true -Check {
    $expectedInbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultInboundAction' -Default 'Block')
    $expectedOutbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultOutboundAction' -Default 'Allow')

    $profile = Get-NetFirewallProfile -Profile Domain -ErrorAction Stop
    $ok = ($profile.Enabled -eq $true) -and ($profile.DefaultInboundAction -eq $expectedInbound) -and ($profile.DefaultOutboundAction -eq $expectedOutbound)

    Add-BooleanResult -Name 'FirewallDomainProfile' -Success $ok -Message "Enabled=$($profile.Enabled), Inbound=$($profile.DefaultInboundAction), Outbound=$($profile.DefaultOutboundAction)"
}

Invoke-ConfigurableCheck -Name 'FirewallPrivateProfile' -Config $config -Section 'Firewall' -Key 'EnablePrivateProfile' -EnabledValue $true -Check {
    $expectedInbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultInboundAction' -Default 'Block')
    $expectedOutbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultOutboundAction' -Default 'Allow')

    $profile = Get-NetFirewallProfile -Profile Private -ErrorAction Stop
    $ok = ($profile.Enabled -eq $true) -and ($profile.DefaultInboundAction -eq $expectedInbound) -and ($profile.DefaultOutboundAction -eq $expectedOutbound)

    Add-BooleanResult -Name 'FirewallPrivateProfile' -Success $ok -Message "Enabled=$($profile.Enabled), Inbound=$($profile.DefaultInboundAction), Outbound=$($profile.DefaultOutboundAction)"
}

Invoke-ConfigurableCheck -Name 'FirewallPublicProfile' -Config $config -Section 'Firewall' -Key 'EnablePublicProfile' -EnabledValue $true -Check {
    $expectedInbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultInboundAction' -Default 'Block')
    $expectedOutbound = [string](Get-ConfigValue -Config $config -Section 'Firewall' -Key 'DefaultOutboundAction' -Default 'Allow')

    $profile = Get-NetFirewallProfile -Profile Public -ErrorAction Stop
    $ok = ($profile.Enabled -eq $true) -and ($profile.DefaultInboundAction -eq $expectedInbound) -and ($profile.DefaultOutboundAction -eq $expectedOutbound)

    Add-BooleanResult -Name 'FirewallPublicProfile' -Success $ok -Message "Enabled=$($profile.Enabled), Inbound=$($profile.DefaultInboundAction), Outbound=$($profile.DefaultOutboundAction)"
}

# --- Password policy ---

Invoke-Check -Name 'PasswordMinimumLength' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'PasswordPolicy' -Key 'MinimumLength' -Default 12)
    $actual = [int](Get-NetAccountsValue -Pattern 'Minimum password length')
    Add-BooleanResult -Name 'PasswordMinimumLength' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
}

Invoke-Check -Name 'PasswordComplexity' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'PasswordPolicy' -Key 'Complexity' -Default 1)

    $tempFile = Join-Path $env:TEMP 'baseline-check-secpol.inf'
    try {
        secedit /export /cfg $tempFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "secedit export failed with exit code $LASTEXITCODE"
        }

        $line = Get-Content -Path $tempFile | Where-Object { $_ -match '^PasswordComplexity\s*=' } | Select-Object -First 1
        if (-not $line) {
            throw 'PasswordComplexity value not found'
        }

        $actual = [int](($line -split '=', 2)[1].Trim())
        Add-BooleanResult -Name 'PasswordComplexity' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
    }
    finally {
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    }
}

Invoke-Check -Name 'AccountLockoutThreshold' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'PasswordPolicy' -Key 'LockoutThreshold' -Default 5)
    $actual = [int](Get-NetAccountsValue -Pattern 'Lockout threshold')
    Add-BooleanResult -Name 'AccountLockoutThreshold' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
}

Invoke-Check -Name 'AccountLockoutDuration' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'PasswordPolicy' -Key 'LockoutDuration' -Default 15)
    $actual = [int](Get-NetAccountsValue -Pattern 'Lockout duration')
    Add-BooleanResult -Name 'AccountLockoutDuration' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
}

# --- Screen ---

Invoke-Check -Name 'ScreenLockTimeout' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'Screen' -Key 'InactivityTimeoutSeconds' -Default 600)
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $actual = Get-RegValue -Path $path -Name 'InactivityTimeoutSecs'
    Add-BooleanResult -Name 'ScreenLockTimeout' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
}

# --- Legacy features ---

Invoke-ConfigurableCheck -Name 'SMBv1Disabled' -Config $config -Section 'LegacyFeatures' -Key 'DisableSMB1' -EnabledValue $true -Check {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction Stop
    Add-BooleanResult -Name 'SMBv1Disabled' -Success ($feature.State -eq 'Disabled') -Message "State=$($feature.State)"
}

Invoke-ConfigurableCheck -Name 'PowerShellV2Disabled' -Config $config -Section 'LegacyFeatures' -Key 'DisablePowerShellV2' -EnabledValue $true -Check {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName 'MicrosoftWindowsPowerShellV2' -ErrorAction Stop
    Add-BooleanResult -Name 'PowerShellV2Disabled' -Success ($feature.State -eq 'Disabled') -Message "State=$($feature.State)"
}

Invoke-ConfigurableCheck -Name 'AutorunDisabled' -Config $config -Section 'LegacyFeatures' -Key 'DisableAutorun' -EnabledValue $true -Check {
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $noDriveTypeAutoRun = Get-RegValue -Path $path -Name 'NoDriveTypeAutoRun'
    $noAutorun = Get-RegValue -Path $path -Name 'NoAutorun'

    $ok = ($noDriveTypeAutoRun -eq 255) -and ($noAutorun -eq 1)
    Add-BooleanResult -Name 'AutorunDisabled' -Success $ok -Message "NoDriveTypeAutoRun=$noDriveTypeAutoRun, NoAutorun=$noAutorun"
}

# --- Office ---

Invoke-ConfigurableCheck -Name 'OfficePolicies' -Config $config -Section 'Office' -Key 'ConfigureOfficePolicies' -EnabledValue $true -Check {
    $version = [string](Get-ConfigValue -Config $config -Section 'Office' -Key 'OfficeVersion' -Default '16.0')

    $secPath = "HKCU:\Software\Policies\Microsoft\Office\$version\Word\Security"
    $pvPath = "HKCU:\Software\Policies\Microsoft\Office\$version\Word\Security\ProtectedView"

    $expectedVBA = [int](Get-ConfigValue -Config $config -Section 'Office' -Key 'VBAWarnings' -Default 3)
    $expectedInternetPV = [int](Get-ConfigValue -Config $config -Section 'Office' -Key 'DisableInternetFilesInPV' -Default 0)
    $expectedAttachmentsPV = [int](Get-ConfigValue -Config $config -Section 'Office' -Key 'DisableAttachmentsInPV' -Default 0)

    $actualVBA = Get-RegValue -Path $secPath -Name 'VBAWarnings'
    $actualInternetPV = Get-RegValue -Path $pvPath -Name 'DisableInternetFilesInPV'
    $actualAttachmentsPV = Get-RegValue -Path $pvPath -Name 'DisableAttachmentsInPV'

    $ok = ($actualVBA -eq $expectedVBA) -and ($actualInternetPV -eq $expectedInternetPV) -and ($actualAttachmentsPV -eq $expectedAttachmentsPV)

    Add-BooleanResult -Name 'OfficePolicies' -Success $ok -Message "VBAWarnings=$actualVBA, DisableInternetFilesInPV=$actualInternetPV, DisableAttachmentsInPV=$actualAttachmentsPV"
}

# --- Script handling ---

Invoke-Check -Name 'PowerShellExecutionPolicy' -Check {
    $expected = [string](Get-ConfigValue -Config $config -Section 'ScriptHandling' -Key 'ExecutionPolicy' -Default 'RemoteSigned')
    $policies = Get-ExecutionPolicy -List

    $machinePolicy = ($policies | Where-Object { $_.Scope -eq 'MachinePolicy' }).ExecutionPolicy
    $userPolicy    = ($policies | Where-Object { $_.Scope -eq 'UserPolicy' }).ExecutionPolicy
    $currentUser   = ($policies | Where-Object { $_.Scope -eq 'CurrentUser' }).ExecutionPolicy
    $localMachine  = ($policies | Where-Object { $_.Scope -eq 'LocalMachine' }).ExecutionPolicy
    $process       = ($policies | Where-Object { $_.Scope -eq 'Process' }).ExecutionPolicy

    if ($machinePolicy -ne 'Undefined') {
        $actual = $machinePolicy
        $source = 'MachinePolicy'
    }
    elseif ($userPolicy -ne 'Undefined') {
        $actual = $userPolicy
        $source = 'UserPolicy'
    }
    elseif ($currentUser -ne 'Undefined') {
        $actual = $currentUser
        $source = 'CurrentUser'
    }
    else {
        $actual = $localMachine
        $source = 'LocalMachine'
    }

    $ok = ($actual -eq $expected) -or (($expected -eq 'RemoteSigned') -and ($actual -eq 'AllSigned'))

    Add-BooleanResult -Name 'PowerShellExecutionPolicy' -Success $ok -Message "Expected=$expected, Actual=$actual, Source=$source, Process=$process"
}

# --- SmartScreen ---

Invoke-ConfigurableCheck -Name 'SmartScreen' -Config $config -Section 'SmartScreen' -Key 'EnableSmartScreen' -EnabledValue $true -Check {
    $expectedExplorer = [string](Get-ConfigValue -Config $config -Section 'SmartScreen' -Key 'ExplorerSmartScreenEnabled' -Default 'Warn')
    $actualExplorer = Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled'

    $ok = ($actualExplorer -eq $expectedExplorer)
    Add-BooleanResult -Name 'SmartScreen' -Success $ok -Message "Expected=$expectedExplorer, Actual=$actualExplorer"
}

# --- Auditing ---

Invoke-ConfigurableCheck -Name 'AuditLogonEvents' -Config $config -Section 'Auditing' -Key 'EnableLogonAudit' -EnabledValue $true -Check {
    $output = auditpol /get /subcategory:"Logon"
    $line = $output | Where-Object { $_ -match 'Logon' } | Select-Object -Last 1

    if (-not $line) {
        throw 'Could not parse auditpol output for Logon'
    }

    $ok = ($line -match 'Success') -and ($line -match 'Failure')
    Add-BooleanResult -Name 'AuditLogonEvents' -Success $ok -Message $line.Trim()
}

Invoke-ConfigurableCheck -Name 'AuditProcessCreation' -Config $config -Section 'Auditing' -Key 'EnableProcessCreationAudit' -EnabledValue $true -Check {
    $output = auditpol /get /subcategory:"Process Creation"
    $line = $output | Where-Object { $_ -match 'Process Creation' } | Select-Object -Last 1

    if (-not $line) {
        throw 'Could not parse auditpol output for Process Creation'
    }

    $ok = ($line -match 'Success')
    Add-BooleanResult -Name 'AuditProcessCreation' -Success $ok -Message $line.Trim()
}

Invoke-Check -Name 'AuditProcessCommandLine' -Check {
    $expected = [int](Get-ConfigValue -Config $config -Section 'Auditing' -Key 'IncludeProcessCommandLine' -Default 1)

    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    $actual = Get-RegValue -Path $path -Name 'ProcessCreationIncludeCmdLine_Enabled'

    Add-BooleanResult -Name 'AuditProcessCommandLine' -Success ($actual -eq $expected) -Message "Expected=$expected, Actual=$actual"
}

# --- Time sync ---

Invoke-Check -Name 'TimeService' -Check {
    $service = Get-Service -Name 'w32time' -ErrorAction Stop
    Add-BooleanResult -Name 'TimeService' -Success ($service.Status -eq 'Running') -Message "Status=$($service.Status)"
}

# --- Output to console ---

Write-Host ''
Write-Host '=== CHECK RESULTS ==='
Write-Host ''

$failed = $false

foreach ($r in $results) {
    if ($r.Status -eq 'FAIL') {
        $failed = $true
    }

    $line = "[{0,-5}] {1,-32} :: {2}" -f $r.Status, $r.Name, $r.Message

    switch ($r.Status) {
        'OK'   { Write-Host $line -ForegroundColor Green }
        'FAIL' { Write-Host $line -ForegroundColor Red }
        'SKIP' { Write-Host $line -ForegroundColor DarkYellow }
        default { Write-Host $line }
    }
}

Write-Host ''

# --- Write log file ---

$logLines = @()
$logLines += "=== CHECK RESULTS ==="
$logLines += "ConfigPath: $ConfigPath"
$logLines += ""

foreach ($r in $results) {
    $logLines += "[{0}] {1} :: {2}" -f $r.Status, $r.Name, $r.Message
}

$logLines += ""
$logLines += "Result: " + ($(if ($failed) { 'NOT OK' } else { 'OK' }))

$logLines | Set-Content -Path $logPath -Encoding UTF8

# --- Final message ---

if ($failed) {
    Write-Host "Issues detected. Check log file: $logPath" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "Check completed. Log file: $logPath" -ForegroundColor Green
    exit 0
}