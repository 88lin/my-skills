@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT=%USERPROFILE%\.agents\skills\update-impeccable.ps1"
set "SOURCE_PATH=%~1"

if not exist "%SCRIPT%" (
    echo Missing update script:
    echo %SCRIPT%
    pause
    exit /b 1
)

echo Impeccable updater
echo ==================
echo.

if defined SOURCE_PATH (
    if not exist "%SOURCE_PATH%" (
        echo Source path does not exist:
        echo %SOURCE_PATH%
        pause
        exit /b 1
    )
    echo Source: %SOURCE_PATH%
) else (
    echo Source: GitHub/cache default
)

echo.
echo Running preview...
echo.

if defined SOURCE_PATH (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode preview -SourcePath "%SOURCE_PATH%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode preview
)

set "PREVIEW_EXIT=%ERRORLEVEL%"
if not "%PREVIEW_EXIT%"=="0" (
    rem update-impeccable.ps1 already printed the reason and what to do about it,
    rem so this only adds the one fact it cannot know: apply was never reached.
    echo.
    echo No apply was run. The installed skill is unchanged.
    pause
    exit /b %PREVIEW_EXIT%
)

echo.
choice /C YN /N /M "Preview passed. Apply update now? [Y/N] "
if errorlevel 2 (
    echo.
    echo Apply skipped.
    pause
    exit /b 0
)

echo.
echo Running apply...
echo.

if defined SOURCE_PATH (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode apply -SourcePath "%SOURCE_PATH%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode apply
)

set "APPLY_EXIT=%ERRORLEVEL%"
echo.
if "%APPLY_EXIT%"=="0" (
    echo Apply finished.
) else (
    rem Same as above: the script reported the cause, and it restores from the
    rem newest backup itself if the applied copy came out broken.
    echo Apply did not complete. See the reason above.
)

pause
exit /b %APPLY_EXIT%
