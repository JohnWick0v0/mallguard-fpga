$ErrorActionPreference = 'Stop'

function Get-Sha256([string] $Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try {
            [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '')
        } finally {
            $algorithm.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

$tools = Join-Path $PSScriptRoot 'HOSTPC_PART\MallGuardConsole\release\tools'
$parts = Join-Path $tools 'ffmpeg.parts'
$output = Join-Path $tools 'ffmpeg.exe'
$expectedSha256 = '2ce797a0f88d7f067180338fb227f7b1928ea727bd9a4d7a1d022f7c52af71a3'
$partLengths = @(24000000, 24000000, 24000000, 15638016)

if (Test-Path -LiteralPath $output) {
    if ((Get-Sha256 $output) -ne $expectedSha256) {
        throw 'An existing ffmpeg.exe has a different SHA-256. Move it before restoring.'
    }
    Write-Output 'ffmpeg.exe is already restored and verified.'
    exit 0
}

$temp = Join-Path $tools ('ffmpeg.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    $destination = [IO.File]::Open($temp, [IO.FileMode]::CreateNew)
    try {
        for ($index = 0; $index -lt $partLengths.Count; $index++) {
            $name = 'ffmpeg.exe.part{0:D2}' -f ($index + 1)
            $part = Get-Item -LiteralPath (Join-Path $parts $name)
            if ($part.Length -ne $partLengths[$index]) {
                throw "Unexpected size for $name."
            }
            $inputStream = [IO.File]::OpenRead($part.FullName)
            try {
                $inputStream.CopyTo($destination)
            } finally {
                $inputStream.Dispose()
            }
        }
    } finally {
        $destination.Dispose()
    }
    if ((Get-Sha256 $temp) -ne $expectedSha256) {
        throw 'SHA-256 verification failed. Check the downloaded parts.'
    }
    [IO.File]::Move($temp, $output)
    Write-Output 'Restored and verified ffmpeg.exe.'
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp
    }
}
