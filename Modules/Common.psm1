Set-StrictMode -Version Latest

$script:LogPath = $null

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $script:LogPath = $Path
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    if ($script:LogPath) {
        Add-Content -Path $script:LogPath -Value $line
    }

    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
}

function Invoke-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Log -Message "START: $Name"
    try {
        & $Action
        Write-Log -Message "DONE: $Name" -Level OK
    }
    catch {
        Write-Log -Message "FAILED: $Name :: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Assert-Administrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must be run from an elevated PowerShell session.'
    }
}

function Ensure-RegistryKey {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Set-RegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)]
        [ValidateSet('String','ExpandString','Binary','DWord','MultiString','QWord')]
        [string]$Type
    )

    Ensure-RegistryKey -Path $Path

    $current = $null
    try {
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
    }
    catch {
        $current = $null
    }

    $needsUpdate = $true
    if ($Type -eq 'MultiString') {
        if ($null -ne $current) {
            $needsUpdate = -not ((@($current) -join "`n") -eq (@($Value) -join "`n"))
        }
    }
    else {
        $needsUpdate = -not ($current -eq $Value)
    }

    if ($needsUpdate) {
        New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
        Write-Log -Message "Set registry: $Path :: $Name = $Value"
    }
    else {
        Write-Log -Message "Registry already set: $Path :: $Name"
    }
}

Export-ModuleMember -Function Initialize-Logging, Write-Log, Invoke-Step, Assert-Administrator, Ensure-RegistryKey, Set-RegistryValue
