Set-StrictMode -Version Latest

function ConvertTo-PlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SecureString]$SecureString
    )

    $bstr = [IntPtr]::Zero

    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function ConvertTo-SecureStringSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlainText
    )

    return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
}

function New-OperatorPassword {
    [CmdletBinding()]
    param()

    $letters = 'abcdefghjkmnpqrstuvwxyz'  # без l, o
    $digits  = '23456789'                 # без 0, 1

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        function Get-RandomChar {
            param(
                [Parameter(Mandatory)][char[]]$Chars,
                [Parameter(Mandatory)][System.Security.Cryptography.RandomNumberGenerator]$Rng
            )

            $bytes = New-Object byte[] 4
            $Rng.GetBytes($bytes)
            $index = [BitConverter]::ToUInt32($bytes, 0) % $Chars.Length
            return $Chars[$index]
        }

        $result = @()

        for ($i = 0; $i -lt 4; $i++) {
            $result += Get-RandomChar -Chars $letters.ToCharArray() -Rng $rng
        }

        for ($i = 0; $i -lt 2; $i++) {
            $result += Get-RandomChar -Chars $digits.ToCharArray() -Rng $rng
        }

        return -join $result
    }
    finally {
        $rng.Dispose()
    }
}


function New-RandomPassword {
    [CmdletBinding()]
    param(
        [int]$Length = 10,
        [int]$MinLength = 8
    )

    if ($Length -lt $MinLength) {
        throw "Password length must be at least $MinLenght."
    }

    $lower   = 'abcdefghijkmnopqrstuvwxyz'
    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $digits  = '23456789'
    $special = '!@#$%^&*_-+=?'

    $all = ($lower + $upper + $digits + $special).ToCharArray()
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        function Get-RandomChar {
            param(
                [Parameter(Mandatory)]
                [char[]]$Chars,

                [Parameter(Mandatory)]
                [System.Security.Cryptography.RandomNumberGenerator]$Rng
            )

            $bytes = New-Object byte[] 4
            $Rng.GetBytes($bytes)
            $index = [BitConverter]::ToUInt32($bytes, 0) % $Chars.Length
            return $Chars[$index]
        }

        $passwordChars = New-Object System.Collections.Generic.List[char]
        $passwordChars.Add((Get-RandomChar -Chars $lower.ToCharArray() -Rng $rng))
        $passwordChars.Add((Get-RandomChar -Chars $upper.ToCharArray() -Rng $rng))
        $passwordChars.Add((Get-RandomChar -Chars $digits.ToCharArray() -Rng $rng))
        $passwordChars.Add((Get-RandomChar -Chars $special.ToCharArray() -Rng $rng))

        for ($i = $passwordChars.Count; $i -lt $Length; $i++) {
            $passwordChars.Add((Get-RandomChar -Chars $all -Rng $rng))
        }

        $shuffled = $passwordChars.ToArray()

        for ($i = $shuffled.Length - 1; $i -gt 0; $i--) {
            $bytes = New-Object byte[] 4
            $rng.GetBytes($bytes)
            $j = [BitConverter]::ToUInt32($bytes, 0) % ($i + 1)

            $tmp = $shuffled[$i]
            $shuffled[$i] = $shuffled[$j]
            $shuffled[$j] = $tmp
        }

        return -join $shuffled
    }
    finally {
        $rng.Dispose()
    }
}

Export-ModuleMember -Function ConvertTo-PlainText, ConvertTo-SecureStringSafe, New-RandomPassword, New-OperatorPassword