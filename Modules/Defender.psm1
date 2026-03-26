Set-StrictMode -Version Latest

function Set-BaselineDefender {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['Defender']

    if ($section['EnableRealtimeProtection']) {
        try {
            Set-MpPreference -DisableRealtimeMonitoring $false
            Write-Log -Message 'Enabled Defender real-time protection'
        }
        catch {
            Write-Log -Message "Could not enforce real-time protection: $($_.Exception.Message)" -Level WARN
        }
    }

    if ($section['EnableCloudProtection']) {
        try {
            Set-MpPreference -MAPSReporting Advanced
            Write-Log -Message 'Enabled Defender cloud-delivered protection'
        }
        catch {
            Write-Log -Message "Could not configure cloud protection: $($_.Exception.Message)" -Level WARN
        }
    }

    if ($section['EnableSampleSubmission']) {
        try {
            Set-MpPreference -SubmitSamplesConsent SendSafeSamples
            Write-Log -Message 'Configured Defender sample submission'
        }
        catch {
            Write-Log -Message "Could not configure sample submission: $($_.Exception.Message)" -Level WARN
        }
    }

    if ($section['EnablePUAProtection']) {
        try {
            Set-MpPreference -PUAProtection Enabled
            Write-Log -Message 'Enabled Defender PUA protection'
        }
        catch {
            Write-Log -Message "Could not enable PUA protection: $($_.Exception.Message)" -Level WARN
        }
    }

    if ($section['EnableControlledFolderAccess']) {
        try {
            Set-MpPreference -EnableControlledFolderAccess Enabled
            Write-Log -Message 'Enabled Controlled Folder Access'
        }
        catch {
            Write-Log -Message "Could not enable Controlled Folder Access: $($_.Exception.Message)" -Level WARN
        }
    }

    try {
        $status = Get-MpComputerStatus
        Write-Log -Message "Defender status :: RealTimeProtectionEnabled=$($status.RealTimeProtectionEnabled)"
        Write-Log -Message "Defender status :: IsTamperProtected=$($status.IsTamperProtected)"
    }
    catch {
        Write-Log -Message "Could not query Defender status: $($_.Exception.Message)" -Level WARN
    }
}

function Set-BaselineSmartScreen {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['SmartScreen']
    $systemPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    $explorerPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'

    Set-RegistryValue -Path $systemPath -Name 'EnableSmartScreen' -Value $section['EnableSmartScreen'] -Type DWord
    Set-RegistryValue -Path $systemPath -Name 'ShellSmartScreenLevel' -Value $section['ShellSmartScreenLevel'] -Type String
    Set-RegistryValue -Path $explorerPath -Name 'SmartScreenEnabled' -Value $section['ExplorerSmartScreenEnabled'] -Type String
}

Export-ModuleMember -Function Set-BaselineDefender, Set-BaselineSmartScreen
