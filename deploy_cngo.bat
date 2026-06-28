@echo off
setlocal EnableDelayedExpansion

:: ---------------------------------------------------------------------------
:: deploy_cngo.bat  —  Deploy QmlConcerto to C:\CnGO using windeployqt
::
:: Layout on ATM:
::   C:\dev\ImportKey\QmlConcerto\   <- sources + this script
::   C:\CnGO\                        <- final application
::     Concerto\QmlConcerto.dll + qmldir
::     qt5\   <- Qt runtime (filled by windeployqt)
::
:: Usage:
::   deploy_cngo.bat [Debug|Release] [plugin-only]
::
::   plugin-only  — copies only the plugin, skips windeployqt
::                  (use when Qt is already deployed by another app)
:: ---------------------------------------------------------------------------

set CONFIG=%~1
if "%CONFIG%"=="" set CONFIG=Release

set PLUGIN_ONLY=0
if /I "%~2"=="plugin-only" set PLUGIN_ONLY=1

set PROJECT_DIR=C:\dev\ImportKey\QmlConcerto
set CNGO=C:\CnGO

:: Shadow build directory — adjust if Qt Creator uses a different name
set BUILD_DIR=C:\dev\ImportKey\build-QmlConcerto-Desktop_x86_windows_msvc2022_pe_32bit-%CONFIG%
if not exist "%BUILD_DIR%" set BUILD_DIR=%PROJECT_DIR%\build\x86_windows_msvc2022_pe_32bit-%CONFIG%
if not exist "%BUILD_DIR%" (
    echo [ERROR] Build directory not found. Build QmlConcerto.pro first.
    echo   Expected: %BUILD_DIR%
    exit /b 1
)

set PLUGIN_DLL=%BUILD_DIR%\QmlConcerto.dll
if not exist "%PLUGIN_DLL%" (
    echo [ERROR] QmlConcerto.dll not found: %PLUGIN_DLL%
    exit /b 1
)

:: Locate windeployqt — search PATH first, then common Qt install locations
set WINDEPLOY=
for %%X in (windeployqt.exe) do set WINDEPLOY=%%~$PATH:X

if "%WINDEPLOY%"=="" (
    for %%P in (
        "C:\Qt\5.15.2\msvc2019\bin\windeployqt.exe"
        "C:\Qt\5.15.2\msvc2019_64\bin\windeployqt.exe"
        "C:\Qt\5.15\msvc2019\bin\windeployqt.exe"
        "C:\Qt\5.15\msvc2019_64\bin\windeployqt.exe"
    ) do (
        if exist %%P set WINDEPLOY=%%~P
    )
)

echo.
echo ============================================================
echo  Deploy QmlConcerto  ^|  %CONFIG%
echo  Plugin : %PLUGIN_DLL%
echo  Target : %CNGO%
if not "%WINDEPLOY%"=="" echo  windeployqt: %WINDEPLOY%
echo ============================================================
echo.

:: ── 1. Plugin ─────────────────────────────────────────────────────────────
if not exist "%CNGO%\Concerto" mkdir "%CNGO%\Concerto"

copy /Y "%PLUGIN_DLL%"                    "%CNGO%\Concerto\" >nul && echo [OK] Concerto\QmlConcerto.dll
copy /Y "%PROJECT_DIR%\qmldir"            "%CNGO%\Concerto\" >nul && echo [OK] Concerto\qmldir
copy /Y "%PROJECT_DIR%\Sequence.qml"      "%CNGO%\Concerto\" >nul && echo [OK] Concerto\Sequence.qml
copy /Y "%PROJECT_DIR%\Chord.qml"         "%CNGO%\Concerto\" >nul && echo [OK] Concerto\Chord.qml
copy /Y "%PROJECT_DIR%\Cadenza.qml"       "%CNGO%\Concerto\" >nul && echo [OK] Concerto\Cadenza.qml
copy /Y "%PROJECT_DIR%\Reprisa.qml"       "%CNGO%\Concerto\" >nul && echo [OK] Concerto\Reprisa.qml
copy /Y "%PROJECT_DIR%\Sonata.qml"        "%CNGO%\Concerto\" >nul && echo [OK] Concerto\Sonata.qml
copy /Y "%PROJECT_DIR%\MelodyPolicies.qml" "%CNGO%\Concerto\" >nul && echo [OK] Concerto\MelodyPolicies.qml

if "%PLUGIN_ONLY%"=="1" (
    echo [SKIP] windeployqt ^(plugin-only mode^)
    goto done
)

:: ── 2. Qt runtime via windeployqt ─────────────────────────────────────────
if "%WINDEPLOY%"=="" (
    echo [ERROR] windeployqt.exe not found.
    echo   Add Qt bin directory to PATH, for example:
    echo     set PATH=C:\Qt\5.15.2\msvc2019\bin;%%PATH%%
    echo   Then re-run this script.
    exit /b 1
)

if not exist "%CNGO%\qt5" mkdir "%CNGO%\qt5"

echo.
echo [Running windeployqt...]
"%WINDEPLOY%" ^
    --dir "%CNGO%\qt5" ^
    --qmldir "%PROJECT_DIR%" ^
    "%CNGO%\Concerto\QmlConcerto.dll"

if errorlevel 1 (
    echo [ERROR] windeployqt failed.
    exit /b 1
)
echo [OK] Qt runtime deployed to %CNGO%\qt5

:done
echo.
echo ============================================================
echo  C:\CnGO layout:
echo    Concerto\QmlConcerto.dll + qmldir
echo    qt5\Qt5Core.dll ... ^(+ platforms\, qml\ etc^)
echo.
echo  Consumer app main.cpp:
echo    engine.addImportPath("C:/CnGO");
echo    engine.addImportPath("C:/CnGO/qt5/qml");
echo  Add C:\CnGO\qt5 to PATH before launching.
echo ============================================================
endlocal
