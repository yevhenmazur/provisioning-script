Set-StrictMode -Version Latest

function Set-BaselineBitLocker {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['BitLocker']
    if (-not $section['EnableBitLocker']) {
        Write-Log -Message 'BitLocker step skipped'
        return
    }

    $osDrive = $env:SystemDrive
    $volume = Get-BitLockerVolume -MountPoint $osDrive -ErrorAction SilentlyContinue
    if ($null -eq $volume) {
        Write-Log -Message 'BitLocker cmdlets not available or volume not found' -Level WARN
        return
    }

    if ($volume.ProtectionStatus -eq 'On') {
        Write-Log -Message "BitLocker already enabled on $osDrive"
        return
    }

    $tpm = Get-Tpm
    if ($section['RequireTPM'] -and (-not $tpm.TpmPresent -or -not $tpm.TpmReady)) {
        Write-Log -Message 'TPM is not present or not ready. BitLocker skipped.' -Level WARN
        return
    }

    $recoveryDir = [string]$Config['General']['BitLockerRecoveryKeyPath']
    if (-not (Test-Path -LiteralPath $recoveryDir)) {
        New-Item -Path $recoveryDir -ItemType Directory -Force | Out-Null
    }

    $usedSpaceOnly = [bool]$section['UseUsedSpaceOnly']
    $method = [string]$section['EncryptionMethod']
    Enable-BitLocker -MountPoint $osDrive -EncryptionMethod $method -UsedSpaceOnly:$usedSpaceOnly -TpmProtector -SkipHardwareTest

    if ($section['AddRecoveryPasswordProtector']) {
        $recoveryProtector = Add-BitLockerKeyProtector -MountPoint $osDrive -RecoveryPasswordProtector
        $fileName = 'BitLocker-Recovery-{0}-{1}.txt' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss')
        $filePath = Join-Path $recoveryDir $fileName
        @"
ComputerName: $env:COMPUTERNAME
MountPoint: $osDrive
RecoveryPassword: $($recoveryProtector.RecoveryPassword)
Created: $(Get-Date -Format s)
"@ | Set-Content -Path $filePath -Encoding UTF8
        Write-Log -Message "Recovery key saved to $filePath" -Level WARN
    }

    Write-Log -Message "BitLocker enabled on $osDrive"
}

Export-ModuleMember -Function Set-BaselineBitLocker
