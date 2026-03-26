Set-StrictMode -Version Latest

function Set-BaselineSRP {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['SRP']
    if (-not $section['ConfigureSRP']) {
        Write-Log -Message 'SRP step skipped'
        return
    }

    $base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers'
    Ensure-RegistryKey -Path $base

    Set-RegistryValue -Path $base -Name 'DefaultLevel' -Value $section['DefaultLevel'] -Type DWord
    Set-RegistryValue -Path $base -Name 'PolicyScope' -Value $section['PolicyScope'] -Type DWord
    Set-RegistryValue -Path $base -Name 'TransparentEnabled' -Value $section['TransparentEnabled'] -Type DWord
    Set-RegistryValue -Path $base -Name 'AuthenticodeEnabled' -Value $section['AuthenticodeEnabled'] -Type DWord

    $executableTypes = @($section['ExecutableTypes'] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Set-RegistryValue -Path $base -Name 'ExecutableTypes' -Value $executableTypes -Type MultiString

    $pathsRoot = Join-Path $base '0\Paths'
    Ensure-RegistryKey -Path $pathsRoot

    Get-ChildItem -Path $pathsRoot -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    function Add-SrpPathRule {
        param(
            [Parameter(Mandatory = $true)][string]$PathPattern,
            [Parameter(Mandatory = $true)][ValidateSet('Unrestricted','Disallowed')][string]$Level,
            [Parameter(Mandatory = $true)][string]$Description
        )

        $guid = [guid]::NewGuid().ToString('B')
        $rulePath = Join-Path $pathsRoot $guid
        Ensure-RegistryKey -Path $rulePath

        Set-RegistryValue -Path $rulePath -Name 'ItemData' -Value $PathPattern -Type String
        Set-RegistryValue -Path $rulePath -Name 'Description' -Value $Description -Type String
        Set-RegistryValue -Path $rulePath -Name 'SaferFlags' -Value ($(if ($Level -eq 'Unrestricted') { 0x00040000 } else { 0x00000000 })) -Type DWord
    }

    $allowPaths = @($section['AllowPaths'] -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $blockPaths = @($section['BlockPaths'] -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    foreach ($path in $allowPaths) {
        Add-SrpPathRule -PathPattern $path -Level 'Unrestricted' -Description "Allow $path"
    }
    foreach ($path in $blockPaths) {
        Add-SrpPathRule -PathPattern $path -Level 'Disallowed' -Description "Block $path"
    }

    Write-Log -Message 'Configured SRP baseline'
    Write-Log -Message 'SRP requires validation and usually a reboot before relying on it.' -Level WARN
}

Export-ModuleMember -Function Set-BaselineSRP
