$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules\Secrets.psm1') -Force

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CurrentLocalUserName {
    $identityName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    if ([string]::IsNullOrWhiteSpace($identityName)) {
        throw "Cannot determine current Windows identity."
    }

    return $identityName.Split('\')[-1]
}

try {
    if (-not (Test-IsAdministrator)) {
        throw "Start-Provisioning.ps1 must be run as Administrator."
    }

    $currentAdminUser = Get-CurrentLocalUserName
    $configPath = Join-Path $PSScriptRoot 'config.ini'

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    Write-Host "=== Provisioning wizard ==="
    Write-Host ""
    Write-Host "Detected current local admin: $currentAdminUser"
    Write-Host ""

    $currentAdminPasswordPlain = New-RandomPassword -Length 10
    $currentAdminPassword = ConvertTo-SecureStringSafe -PlainText $currentAdminPasswordPlain
    $standardUserName = (Read-Host "Set name for operator account").Trim()

    if ([string]::IsNullOrWhiteSpace($standardUserName)) {
        throw "Operator user name cannot be empty."
    }

    if ($standardUserName -ieq $currentAdminUser) {
        throw "Operator user name must be different from the current local admin account."
    }

    $standardUserPasswordPlain = New-OperatorPassword
    $standardUserPassword = ConvertTo-SecureStringSafe -PlainText $standardUserPasswordPlain

    Write-Host ""
    Write-Host "=== Summary ==="
    Write-Host "Current admin              : $currentAdminUser"
    Write-Host "Generated admin password   : $currentAdminPasswordPlain"
    Write-Host "Operator user              : $standardUserName"
    Write-Host "Generated operator password: $standardUserPasswordPlain"
    Write-Host "Config path                : $configPath"
    Write-Host ""

    $confirm = (Read-Host "Proceed with provisioning? (Y/N)").Trim()
    if ($confirm -notin @('Y', 'y')) {
        Write-Host "Provisioning cancelled."
        exit 0
    }

    $params = @{
        CurrentAdminPassword = $currentAdminPassword
        StandardUser         = $standardUserName
        StandardUserPassword = $standardUserPassword
        ConfigPath           = $configPath
    }

    & (Join-Path $PSScriptRoot 'Invoke-BaselineProvisioning.ps1') @params

    Write-Host ""
    Write-Host "Provisioning successfully completed." -ForegroundColor Green
    Write-Host "Please save the passwords in a secure storage. They are not stored in logs!" -ForegroundColor Yellow
    Write-Host "Admin password   : $currentAdminPasswordPlain" -ForegroundColor Yellow
    Write-Host "Operator password: $standardUserPasswordPlain" -ForegroundColor Yellow

    exit 0
}
catch {
    Write-Host ""
    Write-Host "Provisioning failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}