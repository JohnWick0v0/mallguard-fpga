$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
New-Item -ItemType Directory -Force -Path "$root\release" | Out-Null
$sources=Get-ChildItem -LiteralPath "$root\src" -Recurse -Filter '*.cs' | ForEach-Object FullName
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /utf8output /codepage:65001 "/win32manifest:$root\src\app\app.manifest" "/out:$root\release\MallGuardConsole.exe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Management.dll /reference:System.Web.Extensions.dll $sources
if($LASTEXITCODE -ne 0){throw 'C# compilation failed'}
Copy-Item -LiteralPath "$root\src\app\app.config" -Destination "$root\release\MallGuardConsole.exe.config" -Force
Write-Host 'Build passed: release\MallGuardConsole.exe'
