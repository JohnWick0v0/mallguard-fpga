param([switch]$UiOnly,[switch]$SkipLegacy)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
New-Item -ItemType Directory -Force -Path "$root\tests\bin","$root\docs" | Out-Null
if(!$UiOnly -and !$SkipLegacy){& "$root\tools\test_regression.ps1"}else{& "$root\tools\build.ps1"}
if(!$UiOnly){
 & $compiler /nologo /target:exe /utf8output /codepage:65001 "/out:$root\tests\bin\V27Tests.exe" "$root\src\protocol\DisplaySerialProtocol.cs" "$root\src\services\DemoSequenceController.cs" "$root\src\services\ScheduleMediaModels.cs" "$root\tests\V27Tests.cs"
 if($LASTEXITCODE){throw 'V27 compilation failed'}
 & "$root\tests\bin\V27Tests.exe" "$root\tests\fixtures\telemetry27_capture.txt" *> "$root\docs\V27Tests.log"
 if($LASTEXITCODE){Get-Content "$root\docs\V27Tests.log";throw 'V27 tests failed'}
 Get-Content "$root\docs\V27Tests.log"
}
$taskRun=Start-Process -FilePath "$root\release\MallGuardConsole.exe" -ArgumentList '--guided-smoke-test','--capture-dir',"$root\docs" -WindowStyle Hidden -PassThru -Wait
if($taskRun.ExitCode){Get-Content "$root\docs\guided_smoke.json" -ErrorAction SilentlyContinue;throw 'Guided UI smoke failed'}
$result=Get-Content -LiteralPath "$root\docs\guided_smoke.json" -Raw -Encoding utf8 | ConvertFrom-Json
if(!$result.passed -or $result.physical_port_opened){throw 'Guided UI assertions failed'}
Write-Output 'V5 HOST VERIFICATION PASSED; physical UART unopened'
