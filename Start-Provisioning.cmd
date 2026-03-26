@echo off
setlocal

set SCRIPT_DIR=%~dp0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Start-Provisioning.ps1"

set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
    echo Provisioning failed with exit code %EXITCODE%.
) else (
    echo Provisioning completed successfully.
)

pause
exit /b %EXITCODE%