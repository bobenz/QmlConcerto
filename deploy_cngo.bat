@echo off
setlocal EnableDelayedExpansion

:: ---------------------------------------------------------------------------
:: deploy_cngo.bat  —  Build output  →  C:\CnGO  (final ATM application)
::
:: Directory layout on ATM:
::   C:\dev\ImportKey\QmlConcerto\   <- sources + this script
::   C:\dev\ImportKey\qt\            <- Qt 5.15 MSVC runtime
::   C:\CnGO\                        <- final application (no sources)
::
:: Usage (run from C:\dev\ImportKey\QmlConcerto\):
::   deploy_cngo.bat [Debug|Release] [plugin-only]
::
::   plugin-only  — copies only Concerto\QmlConcerto.dll + qmldir
::                  skips Qt DLLs (already deployed by another app)
:: ---------------------------------------------------------------------------

set CONFIG=%~1
if "%CONFIG%"=="" set CONFIG=Release

set PLUGIN_ONLY=0
if /I "%~2"=="plugin-only" set PLUGIN_ONLY=1

set PROJECT_DIR=C:\dev\ImportKey\QmlConcerto
set QT_DIR=C:\dev\ImportKey\qt
set CNGO=C:\CnGO

:: Qt Creator places shadow builds one level up from the project
:: Adjust this path to match your actual Qt Creator build directory
set BUILD_DIR=C:\dev\ImportKey\build-QmlConcerto-Desktop_x86_windows_msvc2022_pe_32bit-%CONFIG%
if not exist "%BUILD_DIR%" (
    :: Fallback: in-source build
    set BUILD_DIR=%PROJECT_DIR%\build\x86_windows_msvc2022_pe_32bit-%CONFIG%
)
if not exist "%BUILD_DIR%" (
    echo [ERROR] Build directory not found: %BUILD_DIR%
    echo   Build QmlConcerto.pro in Qt Creator first, then check the path above.
    exit /b 1
)

set PLUGIN_DLL=%BUILD_DIR%\QmlConcerto.dll
if not exist "%PLUGIN_DLL%" (
    echo [ERROR] QmlConcerto.dll not found at: %PLUGIN_DLL%
    exit /b 1
)

if not exist "%QT_DIR%\bin\Qt5Core.dll" (
    if not exist "%QT_DIR%\bin\Qt5Cored.dll" (
        echo [ERROR] Qt not found at %QT_DIR%\bin
        exit /b 1
    )
)

echo.
echo ============================================================
echo  Deploy QmlConcerto  ^|  %CONFIG%
echo  From : %BUILD_DIR%
echo  Qt   : %QT_DIR%
echo  To   : %CNGO%
echo ============================================================
echo.

:: ── 1. QML plugin ─────────────────────────────────────────────────────────
if not exist "%CNGO%\Concerto" mkdir "%CNGO%\Concerto"

copy /Y "%PLUGIN_DLL%"              "%CNGO%\Concerto\" >nul && echo [OK] Concerto\QmlConcerto.dll
copy /Y "%PROJECT_DIR%\qmldir"      "%CNGO%\Concerto\" >nul && echo [OK] Concerto\qmldir

if "%PLUGIN_ONLY%"=="1" (
    echo [SKIP] Qt DLLs ^(plugin-only mode^)
    goto done
)

:: ── 2. Qt runtime DLLs ────────────────────────────────────────────────────
if not exist "%CNGO%\qt5" mkdir "%CNGO%\qt5"

if /I "%CONFIG%"=="Release" (
    set DLLS=Qt5Core Qt5Gui Qt5Network Qt5Qml Qt5QmlModels Qt5Quick Qt5QuickControls2 Qt5QuickTemplates2 Qt5Widgets Qt5Svg
) else (
    set DLLS=Qt5Cored Qt5Guid Qt5Networkd Qt5Qmld Qt5QmlModelsd Qt5Quickd Qt5QuickControls2d Qt5QuickTemplates2d Qt5Widgetsd Qt5Svgd
)

for %%D in (%DLLS%) do (
    if exist "%QT_DIR%\bin\%%D.dll" (
        copy /Y "%QT_DIR%\bin\%%D.dll" "%CNGO%\qt5\" >nul
        echo [OK] qt5\%%D.dll
    ) else (
        echo [SKIP] qt5\%%D.dll
    )
)

:: ── 3. Platform plugin ─────────────────────────────────────────────────────
if not exist "%CNGO%\qt5\platforms" mkdir "%CNGO%\qt5\platforms"

if /I "%CONFIG%"=="Release" (set PLAT=qwindows.dll) else (set PLAT=qwindowsd.dll)

if exist "%QT_DIR%\plugins\platforms\%PLAT%" (
    copy /Y "%QT_DIR%\plugins\platforms\%PLAT%" "%CNGO%\qt5\platforms\" >nul
    echo [OK] qt5\platforms\%PLAT%
) else (
    echo [WARN] %QT_DIR%\plugins\platforms\%PLAT% not found
)

:: ── 4. Qt QML standard library ─────────────────────────────────────────────
if not exist "%CNGO%\qt5\qml" mkdir "%CNGO%\qt5\qml"

for %%M in (QtQml QtQml.2 QtQuick QtQuick.2 Qt QtGraphicalEffects) do (
    if exist "%QT_DIR%\qml\%%M" (
        xcopy /Y /Q /E "%QT_DIR%\qml\%%M" "%CNGO%\qt5\qml\%%M\" >nul
        echo [OK] qt5\qml\%%M\
    )
)

echo.
echo ============================================================
echo  C:\CnGO layout after deploy:
echo.
echo    Concerto\
echo      QmlConcerto.dll
echo      qmldir
echo    qt5\
echo      Qt5Core.dll  Qt5Qml.dll  Qt5Quick.dll  ...
echo      platforms\qwindows.dll
echo      qml\QtQuick\  QtQml\  ...
echo.
echo  In your app main.cpp:
echo    engine.addImportPath("C:/CnGO");          // finds Concerto plugin
echo    engine.addImportPath("C:/CnGO/qt5/qml");  // finds QtQuick etc.
echo  Add C:\CnGO\qt5 to PATH so Qt DLLs are found.
echo ============================================================
:done
endlocal
