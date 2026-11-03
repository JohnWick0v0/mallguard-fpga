$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskCompiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $taskCompiler /nologo /target:exe /utf8output /codepage:65001 "/out:$taskRoot\release\StableReloadUiTests.exe" "/reference:$taskRoot\release\MallGuardConsole.exe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll "$taskRoot\tests\StableReloadUiTests.cs"
if($LASTEXITCODE){throw 'Stable host test compilation failed'}
& "$taskRoot\release\StableReloadUiTests.exe" "$taskRoot\docs\stable_reload_ui.json" *> "$taskRoot\docs\stable_reload_ui.log"
if($LASTEXITCODE){Get-Content -LiteralPath "$taskRoot\docs\stable_reload_ui.log";throw 'Stable host test failed'}
Get-Content -LiteralPath "$taskRoot\docs\stable_reload_ui.log"
