@echo off
setlocal EnableDelayedExpansion

:: ---------------------------------------------------------------------------
:: deploy.bat  —  Package QmlConcerto plugin for distribution
::
:: Assumptions
::   • Qt 5.15 MSVC2019 x86 DLLs are at ..\qt\bin   (sibling of this project) —
::     this is the actual redistribution target, independent of whatever Qt
::     kit built the plugin (see the project's CLAUDE.md).
::   • QmlConcerto.pro and ..\RegRep\RegRep.pro have already been built for the
::     requested config — their own QMAKE_POST_LINK step deploys DLLs/qmldir
::     into the shared %CNGO_DIR%/%CNGO_DIR%d tree automatically (see
::     deploy.pri). This script only reads from that tree and packages it,
::     it does not build or copy DLLs into it itself.
::   • Run from the QmlConcerto project root.
::
:: Usage
::   deploy.bat [Debug|Release]
::   (Optionally set CNGO_DIR first to override the default C:\CnGO root.)
::
:: Result
::   deploy\
::     lib\
::       QmlConcerto.dll    <- plugin
::       RegRep.dll         <- runtime dependency (linked, not source-included)
::     Concerto\
::       qmldir             <- QML module descriptor ("plugin QmlConcerto ../lib")
::       Sequence.qml, Chord.qml, Cadenza.qml, Reprisa.qml, Sonata.qml,
::       MelodyPolicies.qml
::     RegRep\
::       qmldir             <- QML module descriptor ("plugin RegRep ../lib")
::     include\             <- public headers + import libs, for C++ consumers
::     qt\                  <- Qt runtime DLLs (copied from ..\qt)
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
set DEPLOY_DIR=%PROJECT_DIR%\deploy

set CONFIG_DIR=release
if /I "%CONFIG%"=="Debug" set CONFIG_DIR=debug

:: Same CNGO_DIR/DEPLOY_ROOT convention as deploy.pri: CNGO_DIR env var
:: overrides the default C:\CnGO; Debug reads from the sibling root with a
:: "d" suffix (two complete, independent trees), not a nested subdir.
if "%CNGO_DIR%"=="" set CNGO_DIR=C:\CnGO
set CNGO_ROOT=%CNGO_DIR%
if /I "%CONFIG%"=="Debug" set CNGO_ROOT=%CNGO_DIR%d

if not exist "%CNGO_ROOT%\lib\QmlConcerto.dll" (
    echo [ERROR] %CNGO_ROOT%\lib\QmlConcerto.dll not found.
    echo   Build QmlConcerto.pro ^(%CONFIG%^) first — its post-link step deploys
    echo   here automatically, see deploy.pri.
    exit /b 1
)
if not exist "%CNGO_ROOT%\lib\RegRep.dll" (
    echo [ERROR] %CNGO_ROOT%\lib\RegRep.dll not found.
    echo   Build ..\RegRep\RegRep.pro ^(%CONFIG%^) first.
    exit /b 1
)

if not exist "%QT_DIR%\bin\Qt5Core.dll" (
    echo [ERROR] Qt DLLs not found at %QT_DIR%\bin
    echo   Place Qt 5.15 MSVC2019 x86 alongside this project as ..\qt
    exit /b 1
)

echo.
echo === QmlConcerto deploy ===
echo   Config    : %CONFIG%
echo   CNGO tree : %CNGO_ROOT%
echo   Qt        : %QT_DIR%
echo   Output    : %DEPLOY_DIR%
echo.

:: ── 1. Plugin tree — mirror %CNGO_ROOT% exactly: lib\ + one folder per module ─
if not exist "%DEPLOY_DIR%\lib" mkdir "%DEPLOY_DIR%\lib"
xcopy /Y /Q "%CNGO_ROOT%\lib\*" "%DEPLOY_DIR%\lib\" >nul
echo [OK] lib\  (QmlConcerto.dll, RegRep.dll)

if not exist "%DEPLOY_DIR%\Concerto" mkdir "%DEPLOY_DIR%\Concerto"
xcopy /Y /Q "%CNGO_ROOT%\Concerto\*" "%DEPLOY_DIR%\Concerto\" >nul
echo [OK] Concerto\  (qmldir + composition .qml files)

if not exist "%DEPLOY_DIR%\RegRep" mkdir "%DEPLOY_DIR%\RegRep"
xcopy /Y /Q "%CNGO_ROOT%\RegRep\*" "%DEPLOY_DIR%\RegRep\" >nul
echo [OK] RegRep\  (qmldir)

:: ── 2. Public headers ────────────────────────────────────────────────────────
set INCLUDE_OUT=%DEPLOY_DIR%\include
if not exist "%INCLUDE_OUT%" mkdir "%INCLUDE_OUT%"

set PUBLIC_HEADERS=qmlconcerto_global.h errorsregistry.h phrase.h melody.h pause.h quote.h partitura.h concerto_registration.h
for %%H in (%PUBLIC_HEADERS%) do (
    copy /Y "%PROJECT_DIR%\%%H" "%INCLUDE_OUT%\" >nul
    echo [OK] include\%%H
)

:: RegRep headers — sibling project, linked (not source-included) into QmlConcerto (see concerto.pri)
set REGREP_DIR=%PROJECT_DIR%\..\RegRep
set REGREP_HEADERS=regrep_global.h constantsregistry.h report.h reportrouter.h reportsreceiver.h reporter.h
for %%H in (%REGREP_HEADERS%) do (
    copy /Y "%REGREP_DIR%\%%H" "%INCLUDE_OUT%\" >nul
    echo [OK] include\%%H
)

:: Import libs (.lib) — link-time only, live in each project's own source-relative
:: lib\debug|release\, never in the %CNGO_ROOT% runtime tree (see RegRep.pro /
:: QmlConcerto.pro comments on DESTDIR vs deploy.pri).
set IMPORT_LIB=%PROJECT_DIR%\lib\%CONFIG_DIR%\QmlConcerto.lib
if exist "%IMPORT_LIB%" (
    copy /Y "%IMPORT_LIB%" "%INCLUDE_OUT%\" >nul
    echo [OK] include\QmlConcerto.lib
) else (
    echo [WARN] include\QmlConcerto.lib not found — build first
)

set REGREP_LIB=%REGREP_DIR%\lib\%CONFIG_DIR%\RegRep.lib
if exist "%REGREP_LIB%" (
    copy /Y "%REGREP_LIB%" "%INCLUDE_OUT%\" >nul
    echo [OK] include\RegRep.lib
) else (
    echo [WARN] include\RegRep.lib not found — build RegRep.pro first
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
echo   1. Add deploy\ to your QML import path:
echo        engine.addImportPath("path/to/deploy");
echo   2. Add deploy\qt and deploy\lib to your PATH (or place DLLs alongside
echo      your exe) — a plugin DLL's own dependencies aren't auto-searched in
echo      its own directory on Windows, so deploy\lib must be reachable too.
echo   3. Place deploy\platforms\ alongside your exe.
echo   4. C++ inheritance — in consumer.pro:
echo        INCLUDEPATH += path/to/deploy/include
echo        LIBS        += -Lpath/to/deploy/include -lQmlConcerto -lRegRep
echo.
endlocal
