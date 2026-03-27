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

function Read-ConfirmedPassword {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    while ($true) {
        $p1 = Read-Host $Prompt -AsSecureString
        $p2 = Read-Host "Confirm $Prompt" -AsSecureString

        $s1 = ConvertTo-PlainText -SecureString $p1
        $s2 = ConvertTo-PlainText -SecureString $p2

        if ($s1 -ne $s2) {
            Write-Host "Passwords do not match. Try again." -ForegroundColor Yellow
            continue
        }

        if ([string]::IsNullOrWhiteSpace($s1)) {
            Write-Host "Password cannot be empty." -ForegroundColor Yellow
            continue
        }

        return $p1
    }
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

    $currentAdminPassword = Read-ConfirmedPassword -Prompt "New password for current local admin"

    $standardUserName = (Read-Host "Operator user name").Trim()

    if ([string]::IsNullOrWhiteSpace($standardUserName)) {
        throw "Operator user name cannot be empty."
    }

    if ($standardUserName -ieq $currentAdminUser) {
        throw "Operator user name must be different from the current local admin account."
    }

    $standardUserPasswordPlain = New-RandomPassword -Length 16
    $standardUserPassword = ConvertTo-SecureStringSafe -PlainText $standardUserPasswordPlain

    Write-Host ""
    Write-Host "=== Summary ==="
    Write-Host "Current admin              : $currentAdminUser"
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
    Write-Host "Provisioning completed." -ForegroundColor Green
    Write-Host "Operator password: $standardUserPasswordPlain" -ForegroundColor Yellow

    exit 0
}
catch {
    Write-Host ""
    Write-Host "Provisioning failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}