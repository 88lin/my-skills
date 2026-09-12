@echo off
title Update Skills
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\manage-skills.ps1" -Mode update
echo.
pause
