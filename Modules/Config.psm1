Set-StrictMode -Version Latest

function Convert-IniValue {
    param([string]$Value)

    if ($null -eq $Value) { return $null }

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?i:true|false)$') {
        return [System.Convert]::ToBoolean($trimmed)
    }
    if ($trimmed -match '^-?\d+$') {
        return [int]$trimmed
    }
    return $trimmed
}

function Import-IniFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "INI file not found: $Path"
    }

    $result = [ordered]@{}
    $currentSection = $null

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }

        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim()
            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }
            continue
        }

        if ($trimmed -match '^(.*?)=(.*)$') {
            if (-not $currentSection) {
                throw "INI key-value pair found outside section: $line"
            }
            $key = $matches[1].Trim()
            $value = $matches[2]
            $result[$currentSection][$key] = Convert-IniValue -Value $value
        }
    }

    return $result
}

function Get-IniArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Section,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Delimiter = ','
    )

    if (-not $Section.Contains($Key)) { return @() }
    $value = [string]$Section[$Key]
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }

    return @($value -split [regex]::Escape($Delimiter) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

Export-ModuleMember -Function Import-IniFile, Get-IniArray
