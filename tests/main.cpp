#include <QtQuickTest/quicktest.h>
#include <QQmlEngine>
#include <QDir>
#include <QFileInfo>
#include <QLibraryInfo>
#include <cstring>
#include <vector>

#ifdef Q_OS_WIN
#  include <windows.h>
#endif

#include "concerto_registration.h"

// Find the Qt qml/ import directory by asking Windows where QtXCore*.dll was
// loaded from. QLibraryInfo's path lookup can be wrong when no qt.conf sits
// next to the test executable, so we bypass it entirely. Tries Qt6 then Qt5
// module names so the same test binary works under either kit.
static QString qtQmlImportPath()
{
#ifdef Q_OS_WIN
    static const wchar_t *candidates[] = {
        L"Qt6Cored.dll", L"Qt6Core.dll", L"Qt5Cored.dll", L"Qt5Core.dll"
    };
    for (const wchar_t *name : candidates) {
        HMODULE hMod = GetModuleHandleW(name);
        if (!hMod) continue;
        wchar_t buf[32768];
        DWORD n = GetModuleFileNameW(hMod, buf, 32768);
        if (n) {
            // QtXCore(d).dll lives in {QtPrefix}/bin/, QML imports live in {QtPrefix}/qml/
            QString binDir = QFileInfo(QString::fromWCharArray(buf, n)).absoluteDir().absolutePath();
            return QDir::cleanPath(binDir + "/../qml");
        }
    }
#endif
    // Fallback for non-Windows or if GetModuleHandle fails
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    return QLibraryInfo::path(QLibraryInfo::QmlImportsPath);
#else
    return QLibraryInfo::location(QLibraryInfo::Qml2ImportsPath);
#endif
}

class TestSetup : public QObject
{
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->addImportPath(qtQmlImportPath());
        new ConcertoRegistration(engine);
    }
};

// Qt 5.15 bug (QTBUG-84640): Qt Creator injects -qmljsdebugger=… which starts
// the QML debug-server thread at an unsafe moment → assert in qqmldebugserver.
// Strip the argument before the test runner sees it.
int main(int argc, char **argv)
{
    std::vector<char *> args;
    args.reserve(argc);
    for (int i = 0; i < argc; ++i) {
        if (std::strncmp(argv[i], "-qmljsdebugger", 14) != 0)
            args.push_back(argv[i]);
    }
    int filteredArgc = static_cast<int>(args.size());

    TestSetup setup;
    return quick_test_main_with_setup(filteredArgc, args.data(),
                                      "concertotests", SRCDIR "/tst", &setup);
}

#include "main.moc"
