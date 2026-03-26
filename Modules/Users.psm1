Set-StrictMode -Version Latest

function Get-CurrentLocalUserName {
    [CmdletBinding()]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ([string]::IsNullOrWhiteSpace($identity)) {
        throw "Cannot determine current Windows identity."
    }

    return $identity.Split('\')[-1]
}

function Test-LocalUserExists {
    param([string]$UserName)

    return $null -ne (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)
}

function Test-UserIsLocalAdministrator {
    param([string]$UserName)

    $members = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        if ($m.Name -match "\\$([regex]::Escape($UserName))$" -or $m.Name -eq $UserName) {
            return $true
        }
    }

    return $false
}

function Set-LocalUserPasswordSafe {
    param(
        [string]$UserName,
        [SecureString]$Password
    )

    if (-not (Test-LocalUserExists $UserName)) {
        throw "User not found: $UserName"
    }

    try {
        Set-LocalUser -Name $UserName -Password $Password -ErrorAction Stop
    }
    catch {
        throw ("Failed to set password for {0}: {1}" -f $UserName, $_.Exception.Message)
    }
}

function Ensure-LocalUserPresent {
    param(
        [string]$UserName,
        [SecureString]$Password,
        [string]$Description
    )

    if (Test-LocalUserExists $UserName) {
        Write-Log -Message "User already exists: $UserName"
        return
    }

    New-LocalUser `
        -Name $UserName `
        -Password $Password `
        -Description $Description `
        -PasswordNeverExpires:$false `
        -UserMayNotChangePassword:$false | Out-Null

    Write-Log -Message "Created user: $UserName"
}

function Ensure-UserInGroup {
    param(
        [string]$UserName,
        [string]$GroupName
    )

    $members = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue

    foreach ($m in $members) {
        if ($m.Name -match "\\$([regex]::Escape($UserName))$" -or $m.Name -eq $UserName) {
            return
        }
    }

    Add-LocalGroupMember -Group $GroupName -Member $UserName
}

function Remove-UserFromGroupIfPresent {
    param(
        [string]$UserName,
        [string]$GroupName
    )

    $members = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue

    foreach ($m in $members) {
        if ($m.Name -match "\\$([regex]::Escape($UserName))$" -or $m.Name -eq $UserName) {
            Remove-LocalGroupMember -Group $GroupName -Member $m.Name -ErrorAction SilentlyContinue
        }
    }
}

function Set-BaselineUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][SecureString]$CurrentAdminPassword,
        [Parameter(Mandatory)][string]$StandardUser,
        [Parameter(Mandatory)][SecureString]$StandardUserPassword
    )

    $usersSection = $Config['Users']
    $currentAdmin = Get-CurrentLocalUserName

    Write-Log -Message "Detected current admin: $currentAdmin"

    if (-not (Test-LocalUserExists $currentAdmin)) {
        throw "Current user not found as local account: $currentAdmin"
    }

    if (-not (Test-UserIsLocalAdministrator $currentAdmin)) {
        throw "Current user is not local administrator: $currentAdmin"
    }

    # --- Set password for current admin ---
    Set-LocalUserPasswordSafe -UserName $currentAdmin -Password $CurrentAdminPassword
    Write-Log -Message "Updated password for current admin"

    # --- Validate operator name ---
    if ([string]::Equals($currentAdmin, $StandardUser, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Operator user cannot be the same as admin"
    }

    # --- Create operator ---
    Ensure-LocalUserPresent `
        -UserName $StandardUser `
        -Password $StandardUserPassword `
        -Description $usersSection['StandardUserDescription']

    # --- Enforce groups ---
    Ensure-UserInGroup -UserName $currentAdmin -GroupName 'Administrators'
    Ensure-UserInGroup -UserName $StandardUser -GroupName 'Users'
    Remove-UserFromGroupIfPresent -UserName $StandardUser -GroupName 'Administrators'

    # --- Disable built-in Administrator ---
    if ([System.Convert]::ToBoolean($usersSection['DisableBuiltInAdministrator'])) {
        $builtin = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
        if ($null -ne $builtin -and $builtin.Enabled) {
            Disable-LocalUser -Name 'Administrator'
            Write-Log -Message "Disabled built-in Administrator"
        }
    }
}

Export-ModuleMember -Function Set-BaselineUsers