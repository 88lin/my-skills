@echo off
chcp 65001 >nul
title Register Skill
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Computer\.agents\skills\register-skill-interactive.ps1"
echo.
pause
