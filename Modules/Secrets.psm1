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

function New-OperatorPassphrase {
    [CmdletBinding()]
    param()

    $adjectives = @(
        'Fast','Slow','Blue','Red','Green','Dark','Light','Cold','Warm','Hot',
        'Dry','Wet','Soft','Hard','Sharp','Smooth','Rough','Clean','Clear','Deep',
        'High','Low','Wide','Narrow','Quick','Calm','Bold','Brave','Smart','Wise',
        'Fresh','Bright','Plain','Sweet','Cool','Safe','Firm','Solid','Rapid','Quiet',
        'Loud','Short','Long','Thin','Thick','Flat','Round','True','Prime','Ready',
        'Steep','Mild','Loose','Tight','Clear','Grand','Basic','Neat','Fine','Exact'
    )

    $nouns = @(
        'River','Stone','Cloud','Field','Forest','Hill','Lake','Wind','Rain','Snow',
        'Storm','Sky','Flame','Light','Shadow','Wave','Sound','Noise','Signal','Line',
        'Point','Edge','Core','Frame','Bridge','Road','Track','Path','Gate','Door',
        'Wall','Floor','Roof','Block','Chain','Link','Node','Port','Cable','Wire',
        'Disk','File','Code','Stack','Queue','Loop','Clock','Scope','Shift','Drive',
        'Gear','Motor','Valve','Pump','Tank','Panel','Screen','Board','Chip','Unit'
    )

    $rng = [System.Random]::new()

    $adj  = $adjectives[$rng.Next(0, $adjectives.Count)]
    $noun = $nouns[$rng.Next(0, $nouns.Count)]
    $num  = $rng.Next(10, 100)

    $formats = @(
        "$num-$adj-$noun!",
        "$adj-$noun-$num!"
    )

    return $formats[$rng.Next(0, $formats.Count)]
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

Export-ModuleMember -Function ConvertTo-PlainText, ConvertTo-SecureStringSafe, New-RandomPassword, New-OperatorPassphrase