Set-StrictMode -Version Latest

function Set-BaselineScriptHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $section = $Config['ScriptHandling']

    try {
        Set-ExecutionPolicy `
            -ExecutionPolicy $section['ExecutionPolicy'] `
            -Scope LocalMachine `
            -Force `
            -ErrorAction Stop

        Write-Log -Message "Set PowerShell ExecutionPolicy to $($section['ExecutionPolicy'])"
    }
    catch {
        $errorId = $_.FullyQualifiedErrorId
        $message = $_.Exception.Message

        if ($errorId -like 'ExecutionPolicyOverride*') {
            Write-Log -Message 'ExecutionPolicy is overridden by a more specific scope; continuing with current effective policy' -Level WARN

            $policyList = Get-ExecutionPolicy -List | Out-String
            Write-Log -Message ("ExecutionPolicy scopes:`n{0}" -f $policyList.Trim()) -Level WARN
        }
        else {
            throw
        }
    }

    if ([System.Convert]::ToBoolean($section['AssociatePs1WithTxtFile'])) {
        try {
            cmd /c 'assoc .ps1=txtfile' | Out-Null
            Write-Log -Message 'Associated .ps1 with txtfile to reduce accidental double-click execution'
        }
        catch {
            Write-Log -Message ("Could not change .ps1 association: {0}" -f $_.Exception.Message) -Level WARN
        }
    }
}

Export-ModuleMember -Function Set-BaselineScriptHandling
