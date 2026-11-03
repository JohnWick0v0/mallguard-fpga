@echo off
setlocal
cd /d "%~dp0"
set "TD_EXE=%TD_HOME%\bin\td_commands_prompt.exe"
if not exist "%TD_EXE%" set "TD_EXE=E:\Study\Anlogic_TD\bin\td_commands_prompt.exe"
if not exist "%TD_EXE%" (
    echo TD not found. Set TD_HOME to the Anlogic TD installation directory.
    exit /b 2
)
set "TD_SCRIPT=batch_build.tcl"
echo Building mall_emergency_multimedia_display. See build.log for progress.
"%TD_EXE%" "%TD_SCRIPT%" > "%~dp0build.log" 2>&1
if errorlevel 1 (
    echo BUILD FAILED. See build.log. No new BIT is certified.
    exit /b 1
)
findstr /c:" ERROR:" "%~dp0build.log" > nul
if not errorlevel 1 (
    echo BUILD FAILED: TD reported an error despite its exit code. See build.log.
    exit /b 1
)
findstr /c:"MALL_BUILD_PASS:" "%~dp0build.log" > nul
if errorlevel 1 (
    echo BUILD FAILED: final validation marker missing. See build.log.
    exit /b 1
)
echo BUILD PASSED. Download release\mall_emergency_multimedia_display.bit
exit /b 0
