Set-StrictMode -Version Latest

function Set-BaselineOfficePolicies {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Config)

    $section = $Config['Office']
    if (-not $section['ConfigureOfficePolicies']) {
        Write-Log -Message 'Office policy step skipped'
        return
    }

    $apps = @($section['Apps'] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $version = [string]$section['OfficeVersion']

    foreach ($app in $apps) {
        $securityPath = "HKCU:\Software\Policies\Microsoft\Office\$version\$app\Security"
        $trustedDocsPath = Join-Path $securityPath 'Trusted Documents'
        $protectedViewPath = Join-Path $securityPath 'ProtectedView'

        Set-RegistryValue -Path $securityPath -Name 'VBAWarnings' -Value $section['VBAWarnings'] -Type DWord
        Set-RegistryValue -Path $securityPath -Name 'blockcontentexecutionfrominternet' -Value $section['BlockContentExecutionFromInternet'] -Type DWord
        Set-RegistryValue -Path $protectedViewPath -Name 'DisableInternetFilesInPV' -Value $section['DisableInternetFilesInPV'] -Type DWord
        Set-RegistryValue -Path $protectedViewPath -Name 'DisableAttachmentsInPV' -Value $section['DisableAttachmentsInPV'] -Type DWord
        Set-RegistryValue -Path $trustedDocsPath -Name 'DisableTrustBar' -Value $section['DisableTrustBar'] -Type DWord
    }

    $wordOptionsPath = "HKCU:\Software\Microsoft\Office\$version\Word\Options"
    Set-RegistryValue -Path $wordOptionsPath -Name 'DontUpdateLinks' -Value $section['DontUpdateLinks'] -Type DWord

    Write-Log -Message 'Applied Office best-effort policies'
    Write-Log -Message 'DDE/OLE hardening remains partial and should be validated against the actual Office build.' -Level WARN
}

Export-ModuleMember -Function Set-BaselineOfficePolicies
