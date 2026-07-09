@echo off
REM ====================================================================
REM  XAU SMC Scalper Pro — Installer for MetaTrader 5
REM  Copyright 2026, MotionMind
REM  https://motionmind.store
REM ====================================================================
setlocal EnableDelayedExpansion

echo.
echo  =====================================================
echo   XAU SMC Scalper Pro — MT5 Installer
echo   Copyright 2026, MotionMind
echo  =====================================================
echo.

REM --- Step 1: Detect MT5 Data Folder ---
echo [1/4] Detecting MetaTrader 5 installation...

set "MT5_DATA="

REM Try common registry paths
for %%K in (
    "HKLM\SOFTWARE\MetaQuotes\Terminal"
    "HKCU\SOFTWARE\MetaQuotes\Terminal"
) do (
    for /f "tokens=*" %%A in ('reg query "%%~K" 2^>nul') do (
        set "REG_LINE=%%A"
        if "!REG_LINE:Terminal=" neq "!REG_LINE!" (
            for /f "tokens=2*" %%B in ("%%A") do (
                if exist "%%C\MQL5" (
                    set "MT5_DATA=%%C"
                    goto :found_mt5
                )
            )
        )
    )
)

REM Try common installation paths
for %%P in (
    "%APPDATA%\MetaQuotes\Terminal"
    "%LOCALAPPDATA%\MetaQuotes\Terminal"
    "C:\Program Files\MetaTrader 5"
    "C:\Program Files (x86)\MetaTrader 5"
    "%USERPROFILE%\AppData\Roaming\MetaQuotes\Terminal"
) do (
    if exist "%%~P\MQL5" (
        set "MT5_DATA=%%~P"
        goto :found_mt5
    )
    REM Scan subdirectories for terminal folders
    for /d %%D in (%%~P\*) do (
        if exist "%%D\MQL5" (
            set "MT5_DATA=%%D"
            goto :found_mt5
        )
    )
)

REM Try to find via MT5 terminal.exe
where terminal64.exe >nul 2>&1 && (
    for /f "delims=" %%T in ('where terminal64.exe') do (
        set "MT5_EXE=%%T"
        for %%i in ("!MT5_EXE!") do set "MT5_PARENT=%%~dpi"
        if exist "!MT5_PARENT!MQL5" (
            set "MT5_DATA=!MT5_PARENT!"
            goto :found_mt5
        )
    )
)

REM Manual input
echo.
echo  [!] Could not auto-detect MetaTrader 5 installation.
echo.
set /p "MT5_DATA=  Enter MT5 Data Folder path: "

if not exist "%MT5_DATA%\MQL5" (
    echo.
    echo  [ERROR] MQL5 folder not found in: %MT5_DATA%
    echo  Please verify the path and try again.
    echo.
    pause
    exit /b 1
)

:found_mt5
echo  Found MT5 at: %MT5_DATA%
echo.

REM --- Step 2: Create directory structure ---
echo [2/4] Creating directory structure...

set "EA_DIR=%MT5_DATA%\MQL5\Experts"
set "INCLUDE_DIR=%MT5_DATA%\MQL5\Include\SMC_Scalper"

if not exist "%EA_DIR%" (
    mkdir "%EA_DIR%"
    echo   Created: %EA_DIR%
)

if not exist "%INCLUDE_DIR%" (
    mkdir "%INCLUDE_DIR%"
    echo   Created: %INCLUDE_DIR%
)

if not exist "%INCLUDE_DIR%\Core"       mkdir "%INCLUDE_DIR%\Core"
if not exist "%INCLUDE_DIR%\Config"     mkdir "%INCLUDE_DIR%\Config"
if not exist "%INCLUDE_DIR%\Models"     mkdir "%INCLUDE_DIR%\Models"
if not exist "%INCLUDE_DIR%\Rules"      mkdir "%INSTALL_DIR%\Rules"
if not exist "%INCLUDE_DIR%\Services"   mkdir "%INCLUDE_DIR%\Services"

echo   Directory structure ready.
echo.

REM --- Step 3: Copy files ---
echo [3/4] Copying EA files...

REM Get source directory (where this batch file is located)
set "SRC_DIR=%~dp0"

REM Copy main EA file
if exist "%SRC_DIR%Experts\XAU_SMC_SCALPER.mq5" (
    copy /Y "%SRC_DIR%Experts\XAU_SMC_SCALPER.mq5" "%EA_DIR%\XAU_SMC_SCALPER.mq5" >nul
    echo   Copied: XAU_SMC_SCALPER.mq5 → Experts\
) else (
    echo   [WARNING] XAU_SMC_SCALPER.mq5 not found in source
)

REM Copy Core modules
for %%F in ("%SRC_DIR%Core\*.mqh") do (
    copy /Y "%%F" "%INCLUDE_DIR%\Core\" >nul
    echo   Copied: Core\%%~nxF
)

REM Copy Config
for %%F in ("%SRC_DIR%Config\*.mqh") do (
    copy /Y "%%F" "%INCLUDE_DIR%\Config\" >nul
    echo   Copied: Config\%%~nxF
)

REM Copy Models
for %%F in ("%SRC_DIR%Models\*.mqh") do (
    copy /Y "%%F" "%INCLUDE_DIR%\Models\" >nul
    echo   Copied: Models\%%~nxF
)

REM Copy Rules
for %%F in ("%SRC_DIR%Rules\*.mqh") do (
    copy /Y "%%F" "%INCLUDE_DIR%\Rules\" >nul
    echo   Copied: Rules\%%~nxF
)

REM Copy Services
for %%F in ("%SRC_DIR%Services\*.mqh") do (
    copy /Y "%%F" "%INCLUDE_DIR%\Services\" >nul
    echo   Copied: Services\%%~nxF
)

echo.
echo   All files copied successfully.
echo.

REM --- Step 4: Instructions ---
echo [4/4] Post-installation instructions...
echo.
echo  =====================================================
echo   Installation Complete!
echo  =====================================================
echo.
echo  Next steps:
echo.
echo  1. Open MetaTrader 5
echo  2. Open MetaEditor (press F4 in MT5)
echo  3. In MetaEditor, navigate to:
echo     Experts\XAU_SMC_SCALPER.mq5
echo  4. Press F7 to compile
echo  5. If compilation succeeds, return to MT5
echo  6. Drag "XAU SMC Scalper Pro" onto XAUUSD M5 chart
echo  7. Enable "Allow Algo Trading"
echo  8. Configure inputs as needed (see README.md)
echo.
echo  File locations:
echo    EA:       %EA_DIR%\XAU_SMC_SCALPER.mq5
echo    Include:  %INCLUDE_DIR%\
echo.
echo  =====================================================
echo.

REM Ask to open MetaEditor
set /p "OPEN_ME=  Open MetaEditor now? (Y/N): "
if /i "%OPEN_ME%"=="Y" (
    if exist "%MT5_DATA%\metaeditor64.exe" (
        start "" "%MT5_DATA%\metaeditor64.exe" "%EA_DIR%\XAU_SMC_SCALPER.mq5"
    ) else if exist "%MT5_DATA%\..\metaeditor64.exe" (
        start "" "%MT5_DATA%\..\metaeditor64.exe" "%EA_DIR%\XAU_SMC_SCALPER.mq5"
    ) else (
        echo   [INFO] Could not find metaeditor64.exe. Please open MetaEditor manually.
    )
)

echo.
echo  Press any key to exit...
pause >nul
endlocal
