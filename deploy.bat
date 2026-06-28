@echo off
setlocal EnableDelayedExpansion

:: ---------------------------------------------------------------------------
:: deploy.bat  —  Package QmlConcerto plugin for distribution
::
:: Assumptions
::   • Qt 5.15 MSVC2022 x86 DLLs are at ..\qt\bin   (sibling of this project)
::   • Build output (Debug or Release) is passed as first argument.
::     Defaults to Debug.
::   • Run from the QmlConcerto project root.
::
:: Usage
::   deploy.bat [Debug|Release]
::
:: Result
::   deploy\
::     Concerto\
::       QmlConcerto.dll    <- plugin
::       qmldir             <- QML module descriptor
::     qt\                  <- Qt runtime DLLs (symlinked or copied from ..\qt)
::       Qt5Core.dll
::       Qt5Gui.dll
::       Qt5Qml.dll
::       Qt5QmlModels.dll
::       Qt5Quick.dll
::       Qt5Network.dll
::       Qt5QuickControls2.dll  (optional — include if consumers use Controls)
::     platforms\
::       qwindows.dll       <- Qt platform plugin
::     qml\
::       QtQuick\           <- built-in QML type plugins
::       QtQml\
:: ---------------------------------------------------------------------------

set CONFIG=%~1
if "%CONFIG%"=="" set CONFIG=Debug

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR:~0,-1%
set QT_DIR=%PROJECT_DIR%\..\qt
set BUILD_DIR=%PROJECT_DIR%\build\x86_windows_msvc2022_pe_32bit-%CONFIG%
set DEPLOY_DIR=%PROJECT_DIR%\deploy

:: Resolve build dir: Qt Creator sometimes uses slightly different names
if not exist "%BUILD_DIR%" (
    set BUILD_DIR=%PROJECT_DIR%\build\x86_windows_msvc2022_pe_32bit-%CONFIG%d
)
if not exist "%BUILD_DIR%" (
    echo [ERROR] Build directory not found. Build the project first.
    echo   Expected: %BUILD_DIR%
    exit /b 1
)

if not exist "%QT_DIR%\bin\Qt5Core.dll" (
    echo [ERROR] Qt DLLs not found at %QT_DIR%\bin
    echo   Place Qt 5.15 MSVC2022 x86 alongside this project as ..\qt
    exit /b 1
)

set PLUGIN_DLL=%BUILD_DIR%\QmlConcerto.dll
if not exist "%PLUGIN_DLL%" (
    echo [ERROR] Plugin DLL not found: %PLUGIN_DLL%
    echo   Build QmlConcerto.pro first.
    exit /b 1
)

echo.
echo === QmlConcerto deploy ===
echo   Config   : %CONFIG%
echo   Build    : %BUILD_DIR%
echo   Qt       : %QT_DIR%
echo   Output   : %DEPLOY_DIR%
echo.

:: ── 1. Plugin files ──────────────────────────────────────────────────────────
set CONCERTO_OUT=%DEPLOY_DIR%\Concerto
if not exist "%CONCERTO_OUT%" mkdir "%CONCERTO_OUT%"

copy /Y "%PLUGIN_DLL%"          "%CONCERTO_OUT%\" >nul
copy /Y "%PROJECT_DIR%\qmldir"  "%CONCERTO_OUT%\" >nul
echo [OK] Concerto\QmlConcerto.dll
echo [OK] Concerto\qmldir

:: ── 2. Public headers ────────────────────────────────────────────────────────
set INCLUDE_OUT=%DEPLOY_DIR%\include
if not exist "%INCLUDE_OUT%" mkdir "%INCLUDE_OUT%"

set PUBLIC_HEADERS=qmlconcerto_global.h errorsregistry.h phrase.h melody.h pause.h quote.h partitura.h concerto_registration.h
for %%H in (%PUBLIC_HEADERS%) do (
    copy /Y "%PROJECT_DIR%\%%H" "%INCLUDE_OUT%\" >nul
    echo [OK] include\%%H
)

:: Also copy the import lib so linkers can resolve DLL symbols
set IMPORT_LIB=%BUILD_DIR%\QmlConcerto.lib
if exist "%IMPORT_LIB%" (
    copy /Y "%IMPORT_LIB%" "%INCLUDE_OUT%\" >nul
    echo [OK] include\QmlConcerto.lib
) else (
    echo [WARN] include\QmlConcerto.lib not found — build first
)

:: ── 3. Qt runtime DLLs ───────────────────────────────────────────────────────
set QT_OUT=%DEPLOY_DIR%\qt
if not exist "%QT_OUT%" mkdir "%QT_OUT%"

set QT_DLLS=Qt5Core Qt5Gui Qt5Network Qt5Qml Qt5QmlModels Qt5Quick Qt5QuickControls2 Qt5QuickTemplates2 Qt5Widgets
if /I "%CONFIG%"=="Debug" (
    set QT_DLLS=Qt5Cored Qt5Guid Qt5Networkd Qt5Qmld Qt5QmlModelsd Qt5Quickd Qt5QuickControls2d Qt5QuickTemplates2d Qt5Widgetsd
)

for %%D in (%QT_DLLS%) do (
    if exist "%QT_DIR%\bin\%%D.dll" (
        copy /Y "%QT_DIR%\bin\%%D.dll" "%QT_OUT%\" >nul
        echo [OK] qt\%%D.dll
    ) else (
        echo [SKIP] qt\%%D.dll  ^(not found, may be optional^)
    )
)

:: ── 4. Platform plugin ───────────────────────────────────────────────────────
set PLATFORMS_OUT=%DEPLOY_DIR%\platforms
if not exist "%PLATFORMS_OUT%" mkdir "%PLATFORMS_OUT%"

set PLATFORM_DLL=qwindows.dll
if /I "%CONFIG%"=="Debug" set PLATFORM_DLL=qwindowsd.dll

if exist "%QT_DIR%\plugins\platforms\%PLATFORM_DLL%" (
    copy /Y "%QT_DIR%\plugins\platforms\%PLATFORM_DLL%" "%PLATFORMS_OUT%\" >nul
    echo [OK] platforms\%PLATFORM_DLL%
) else (
    echo [WARN] platforms\%PLATFORM_DLL% not found — consumer app needs this
)

:: ── 5. QML stdlib plugins (QtQuick, QtQml) ───────────────────────────────────
:: These are needed if consumers use any built-in QML types.
set QML_SRC=%QT_DIR%\qml
set QML_OUT=%DEPLOY_DIR%\qml

for %%M in (QtQml QtQuick QtQuick.2) do (
    if exist "%QML_SRC%\%%M" (
        if not exist "%QML_OUT%\%%M" mkdir "%QML_OUT%\%%M"
        xcopy /Y /Q "%QML_SRC%\%%M\*" "%QML_OUT%\%%M\" >nul
        echo [OK] qml\%%M\
    )
)

echo.
echo === Deploy complete ===
echo.
echo Consumer app setup:
echo   1. Add deploy\Concerto to your QML import path:
echo        engine.addImportPath("path/to/deploy");
echo   2. Add deploy\qt to your PATH (or place DLLs alongside your exe).
echo   3. Place deploy\platforms\ alongside your exe.
echo   4. C++ inheritance — in consumer.pro:
echo        INCLUDEPATH += path/to/deploy/include
echo        LIBS        += -Lpath/to/deploy/include -lQmlConcerto
echo.
endlocal
