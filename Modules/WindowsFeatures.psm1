Set-StrictMode -Version Latest


function Set-BaselineFirewall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $section = $Config['Firewall']

    $defaultInboundAction = $section['DefaultInboundAction']
    $defaultOutboundAction = $section['DefaultOutboundAction']

    if ($defaultInboundAction -notin @('Block', 'Allow', 'NotConfigured')) {
        throw "Invalid Firewall.DefaultInboundAction value: $defaultInboundAction"
    }

    if ($defaultOutboundAction -notin @('Block', 'Allow', 'NotConfigured')) {
        throw "Invalid Firewall.DefaultOutboundAction value: $defaultOutboundAction"
    }

    $profiles = @(
        @{ Name = 'Domain';  Enabled = [System.Convert]::ToBoolean($section['EnableDomainProfile']) }
        @{ Name = 'Private'; Enabled = [System.Convert]::ToBoolean($section['EnablePrivateProfile']) }
        @{ Name = 'Public';  Enabled = [System.Convert]::ToBoolean($section['EnablePublicProfile']) }
    )

    foreach ($profile in $profiles) {
        $enabledValue = if ($profile.Enabled) { 'True' } else { 'False' }

        Set-NetFirewallProfile `
            -Profile $profile.Name `
            -Enabled $enabledValue `
            -DefaultInboundAction $defaultInboundAction `
            -DefaultOutboundAction $defaultOutboundAction
    }

    Write-Log -Message 'Configured Windows Firewall profiles'
}


function Set-BaselineWindowsUpdate {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['WindowsUpdate']
    $auPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    Set-RegistryValue -Path $auPath -Name 'NoAutoUpdate' -Value $section['NoAutoUpdate'] -Type DWord
    Set-RegistryValue -Path $auPath -Name 'AUOptions' -Value $section['AUOptions'] -Type DWord

    $uxPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    Ensure-RegistryKey -Path $uxPath

    foreach ($name in @('PauseUpdatesStartTime','PauseUpdatesExpiryTime','PauseQualityUpdatesStartTime','PauseQualityUpdatesEndTime','PauseFeatureUpdatesStartTime','PauseFeatureUpdatesEndTime')) {
        Remove-ItemProperty -Path $uxPath -Name $name -ErrorAction SilentlyContinue
    }

    Set-RegistryValue -Path $uxPath -Name 'ActiveHoursStart' -Value $section['ActiveHoursStart'] -Type DWord
    Set-RegistryValue -Path $uxPath -Name 'ActiveHoursEnd' -Value $section['ActiveHoursEnd'] -Type DWord
}

function Disable-BaselineLegacyFeatures {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['LegacyFeatures']

    if ($section['DisableSMB1']) {
        try {
            Disable-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log -Message 'Disabled feature: SMB1Protocol'
        }
        catch {
            Write-Log -Message "Could not disable SMB1Protocol: $($_.Exception.Message)" -Level WARN
        }
    }

    if ($section['DisablePowerShellV2']) {
        foreach ($feature in @('MicrosoftWindowsPowerShellV2','MicrosoftWindowsPowerShellV2Root')) {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Message "Disabled feature: ${feature}"
            }
            catch {
                Write-Log -Message "Could not disable ${feature}: $($_.Exception.Message)" -Level WARN
            }
        }
    }

    if ($section['DisableAutorun']) {
        $explorerPolicies = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
        Set-RegistryValue -Path $explorerPolicies -Name 'NoDriveTypeAutoRun' -Value 255 -Type DWord
        Set-RegistryValue -Path $explorerPolicies -Name 'NoAutorun' -Value 1 -Type DWord
    }

    if ($section['DisableAutoplayForNonVolume']) {
        $explorerPolicies2 = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
        Set-RegistryValue -Path $explorerPolicies2 -Name 'NoAutoplayfornonVolume' -Value 1 -Type DWord
    }
}

function Set-BaselineTimeSync {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $ntpServer = [string]$Config['General']['NtpServer']
    w32tm /config /manualpeerlist:$ntpServer /syncfromflags:manual /update | Out-Null
    Restart-Service w32time -ErrorAction SilentlyContinue
    w32tm /resync /force | Out-Null
    Write-Log -Message "Configured NTP sync using $ntpServer"
}

Export-ModuleMember -Function Set-BaselineFirewall, Set-BaselineWindowsUpdate, Disable-BaselineLegacyFeatures, Set-BaselineTimeSync
