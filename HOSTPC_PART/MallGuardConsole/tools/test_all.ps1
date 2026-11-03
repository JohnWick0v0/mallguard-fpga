# 复用既有协议/模型/离线界面断言，不访问物理串口。
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'test_regression.ps1')
& (Join-Path $PSScriptRoot 'test_guided.ps1') -SkipLegacy
& (Join-Path $PSScriptRoot 'test_stable_ui.ps1')
Write-Output 'MALLGUARD HOST REGRESSION PASSED'
