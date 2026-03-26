$ErrorActionPreference = 'Stop'

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

        $bstr1 = [IntPtr]::Zero
        $bstr2 = [IntPtr]::Zero

        try {
            $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1)
            $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2)

            $s1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr1)
            $s2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr2)

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
        finally {
            if ($bstr1 -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
            }

            if ($bstr2 -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
            }
        }
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

    $standardUserPassword = Read-ConfirmedPassword -Prompt "Operator password"

    Write-Host ""
    Write-Host "=== Summary ==="
    Write-Host "Current admin  : $currentAdminUser"
    Write-Host "Operator user  : $standardUserName"
    Write-Host "Config path    : $configPath"
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

    exit 0
}
catch {
    Write-Host ""
    Write-Host "Provisioning failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}