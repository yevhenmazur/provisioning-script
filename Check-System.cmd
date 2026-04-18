@echo off
setlocal

set SCRIPT_DIR=%~dp0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-BaselineCheck.ps1"

set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
    echo System check FAILED with exit code %EXITCODE%.
) else (
    echo System check PASSED.
)

pause
exit /b %EXITCODE%