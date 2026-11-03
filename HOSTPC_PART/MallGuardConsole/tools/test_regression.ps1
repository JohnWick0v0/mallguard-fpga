param([switch]$UiOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
New-Item -ItemType Directory -Force -Path "$root\tests\bin","$root\tests\work","$root\docs" | Out-Null
& "$root\tools\build.ps1"
if(!$UiOnly){
foreach($suite in 'ProtocolTests','V21Tests','V23Tests','V25Tests'){
    $sources=@("$root\src\protocol\DisplaySerialProtocol.cs","$root\tests\$suite.cs")
    $refs=@()
    if($suite -eq 'V21Tests'){$sources+=@("$root\src\services\FinderNoticeRenderer.cs");$refs+=@('/reference:System.Drawing.dll')}
    if($suite -eq 'V25Tests'){$sources+=@("$root\src\services\ScheduleMediaModels.cs","$root\src\services\MediaAssetConverter.cs");$refs+=@('/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll')}
    & $compiler /nologo /target:exe /utf8output /codepage:65001 "/out:$root\tests\bin\$suite.exe" $refs $sources
    if($LASTEXITCODE){throw "$suite compilation failed"}
    if($suite -eq 'ProtocolTests'){$arguments=@("$root\tests\fixtures\telemetry20_capture.txt")}
    elseif($suite -eq 'V21Tests'){$arguments=@("$root\tests\fixtures\telemetry21_capture.txt")}
    elseif($suite -eq 'V23Tests'){$arguments=@("$root\tests\fixtures\telemetry23_capture.txt")}
    else{$arguments=@("$root\tests\work","$root\release\tools\ffmpeg.exe","$root\tests\fixtures\telemetry25_capture.txt")}
    & "$root\tests\bin\$suite.exe" @arguments *> "$root\docs\${suite}.log"
    if($LASTEXITCODE){Get-Content "$root\docs\${suite}.log";throw "$suite failed"}
    Get-Content "$root\docs\${suite}.log"
}
}
$modes=@(@('smoke-test','ui_smoke.json'),@('finder-smoke-test','finder_smoke.json'),@('playback-smoke-test','playback_smoke.json'),@('experience-smoke-test','experience_smoke.json'))
foreach($mode in $modes){
    $taskRun=Start-Process -FilePath "$root\release\MallGuardConsole.exe" -ArgumentList "--$($mode[0])",'--capture-dir',"$root\docs" -WindowStyle Hidden -PassThru -Wait
    if($taskRun.ExitCode){throw "$($mode[0]) failed"}
    $result=Get-Content -LiteralPath (Join-Path "$root\docs" $mode[1]) -Raw -Encoding utf8 | ConvertFrom-Json
    if(!$result.passed -or $result.physical_port_opened){throw "$($mode[0]) assertions failed"}
    Write-Output "$($mode[0]) PASSED; physical UART unopened"
}
Write-Output 'V4 HOST VERIFICATION PASSED'
