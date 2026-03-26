Set-StrictMode -Version Latest

function Test-LocalUserExists {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$UserName)

    return $null -ne (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)
}

function Ensure-LocalUserPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][SecureString]$Password,
        [string]$Description = ''
    )

    if (Test-LocalUserExists -UserName $UserName) {
        Write-Log -Message "Local user already exists: $UserName"
        return
    }

    New-LocalUser -Name $UserName -Password $Password -Description $Description -PasswordNeverExpires:$false -UserMayNotChangePassword:$false | Out-Null
    Write-Log -Message "Created local user: $UserName"
}

function Test-LocalGroupMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$GroupName
    )

    $members = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue
    foreach ($member in $members) {
        if ($member.Name -match "\\$([regex]::Escape($UserName))$" -or $member.Name -eq $UserName) {
            return $true
        }
    }
    return $false
}

function Ensure-UserInGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$GroupName
    )

    if (Test-LocalGroupMembership -UserName $UserName -GroupName $GroupName) {
        Write-Log -Message "$UserName already in group $GroupName"
        return
    }

    Add-LocalGroupMember -Group $GroupName -Member $UserName
    Write-Log -Message "Added $UserName to group $GroupName"
}

function Remove-UserFromGroupIfPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$GroupName
    )

    $members = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue
    foreach ($member in $members) {
        if ($member.Name -match "\\$([regex]::Escape($UserName))$" -or $member.Name -eq $UserName) {
            Remove-LocalGroupMember -Group $GroupName -Member $member.Name -ErrorAction SilentlyContinue
            Write-Log -Message "Removed $UserName from group $GroupName"
            return
        }
    }

    Write-Log -Message "$UserName not present in group $GroupName"
}

function Set-BaselineUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$LocalAdminUser,
        [Parameter(Mandatory = $true)][SecureString]$LocalAdminPassword,
        [Parameter(Mandatory = $true)][string]$StandardUser,
        [Parameter(Mandatory = $true)][SecureString]$StandardUserPassword
    )

    Ensure-LocalUserPresent -UserName $LocalAdminUser -Password $LocalAdminPassword -Description $Config['Users']['LocalAdminDescription']
    Ensure-LocalUserPresent -UserName $StandardUser -Password $StandardUserPassword -Description $Config['Users']['StandardUserDescription']

    Ensure-UserInGroup -UserName $LocalAdminUser -GroupName 'Administrators'
    Ensure-UserInGroup -UserName $StandardUser -GroupName 'Users'
    Remove-UserFromGroupIfPresent -UserName $StandardUser -GroupName 'Administrators'

    if ($Config['Users']['DisableBuiltInAdministrator']) {
        $builtInAdmin = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
        if ($null -ne $builtInAdmin) {
            if ($builtInAdmin.Enabled) {
                Disable-LocalUser -Name 'Administrator'
                Write-Log -Message 'Disabled built-in Administrator account'
            }
            else {
                Write-Log -Message 'Built-in Administrator account already disabled'
            }
        }
    }
}

Export-ModuleMember -Function Set-BaselineUsers
