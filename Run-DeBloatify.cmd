@echo off
rem Double-click this file to start DeBloatify. It asks for administrator rights.
rem Any arguments are passed on, e.g.  Run-DeBloatify.cmd -Preset Recommended
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DeBloatify.ps1" %*
