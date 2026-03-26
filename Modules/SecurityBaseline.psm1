Set-StrictMode -Version Latest

function Set-BaselinePasswordPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $tempInf = Join-Path $env:TEMP 'baseline-security.inf'
    $tempDb  = Join-Path $env:TEMP 'baseline-security.sdb'
    $section = $Config['PasswordPolicy']

    $content = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
MinimumPasswordLength = {0}
PasswordComplexity = {1}
LockoutBadCount = {2}
ResetLockoutCount = {3}
LockoutDuration = {4}
'@ -f `
        $section['MinimumLength'],
        $section['Complexity'],
        $section['LockoutThreshold'],
        $section['LockoutWindow'],
        $section['LockoutDuration']

    Set-Content -Path $tempInf -Value $content -Encoding Unicode

    try {
        & secedit /configure /db $tempDb /cfg $tempInf /areas SECURITYPOLICY | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "secedit failed with exit code $LASTEXITCODE"
        }

        & net accounts `
            /minpwlen:$($section['MinimumLength']) `
            /lockoutthreshold:$($section['LockoutThreshold']) `
            /lockoutwindow:$($section['LockoutWindow']) `
            /lockoutduration:$($section['LockoutDuration']) | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "net accounts failed with exit code $LASTEXITCODE"
        }

        Write-Log -Message 'Applied local password policy'
    }
    finally {
        Remove-Item -Path $tempInf -ErrorAction SilentlyContinue
        Remove-Item -Path $tempDb -ErrorAction SilentlyContinue
    }
}

function Set-BaselineUAC {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $section = $Config['UAC']

    Set-RegistryValue -Path $path -Name 'EnableLUA' -Value $section['EnableLUA'] -Type DWord
    Set-RegistryValue -Path $path -Name 'ConsentPromptBehaviorAdmin' -Value $section['ConsentPromptBehaviorAdmin'] -Type DWord
    Set-RegistryValue -Path $path -Name 'PromptOnSecureDesktop' -Value $section['PromptOnSecureDesktop'] -Type DWord
    Set-RegistryValue -Path $path -Name 'FilterAdministratorToken' -Value $section['FilterAdministratorToken'] -Type DWord
}

function Set-BaselineScreenLock {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-RegistryValue -Path $path -Name 'InactivityTimeoutSecs' -Value $Config['Screen']['InactivityTimeoutSeconds'] -Type DWord
}

function Set-BaselineAuditing {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['Auditing']
    if ($section['EnableLogonAudit']) {
        auditpol /set /subcategory:'Logon' /success:enable /failure:enable | Out-Null
    }
    if ($section['EnableProcessCreationAudit']) {
        auditpol /set /subcategory:'Process Creation' /success:enable /failure:enable | Out-Null
    }

    $auditPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    Set-RegistryValue -Path $auditPath -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value $section['IncludeProcessCommandLine'] -Type DWord
    Write-Log -Message 'Enabled basic audit policy'
}

Export-ModuleMember -Function Set-BaselinePasswordPolicy, Set-BaselineUAC, Set-BaselineScreenLock, Set-BaselineAuditing
