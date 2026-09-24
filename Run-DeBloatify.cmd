@echo off
rem Double-click this file to start DeBloatify. It asks for administrator rights.
rem Any arguments are passed on, e.g.  Run-DeBloatify.cmd -Preset Recommended

rem Opened from inside a ZIP, Windows unpacks only this one file to a temp folder.
if not exist "%~dp0DeBloatify.ps1" goto notextracted
if not exist "%~dp0src\Core.ps1" goto notextracted

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeBloatify.ps1" %*
set rc=%errorlevel%
if not "%rc%"=="0" pause
exit /b %rc%

:notextracted
echo.
echo  DeBloatify can't find its files.
echo.
echo  It looks like you opened it from inside the ZIP. Windows only unpacks the
echo  one file you double-click, so the rest of DeBloatify is missing.
echo.
echo  Right-click the ZIP, choose "Extract All...", then run Run-DeBloatify.cmd
echo  from the extracted folder.
echo.
pause
exit /b 1
