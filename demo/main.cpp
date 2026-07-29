#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#ifdef Q_OS_WIN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

int main(int argc, char *argv[])
{
    qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &msg) {
        fprintf(stderr, "%s\n", qPrintable(msg));
        fflush(stderr);
    });

    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Load Concerto/RegRep from the shared deploy tree (see ../deploy.pri and
    // ../BUILD_DEPLOYMENT_CONVENTIONS.md) instead of compiling their sources
    // in — CNGO_DIR overrides the default at runtime, same env var qmake reads
    // at build time for the plugins' own deploy step. Debug reads from the
    // sibling "d"-suffixed root, matching deploy.pri's own convention.
    QString deployRoot = qEnvironmentVariable("CNGO_DIR", QStringLiteral("C:/CnGO"));
#ifdef QT_DEBUG
    deployRoot += QStringLiteral("d");
#endif
    const QString deployLibDir = deployRoot + QStringLiteral("/lib");

#ifdef Q_OS_WIN
    // QmlConcerto.dll depends on RegRep.dll; Windows doesn't auto-search a
    // loaded plugin's own directory for its dependencies, so the shared lib/
    // directory must be added to the process's DLL search path explicitly.
    SetDllDirectoryW(reinterpret_cast<const wchar_t *>(deployLibDir.utf16()));
#endif

    QQmlApplicationEngine engine;
    engine.addImportPath(deployRoot);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &engine,
                      [](const QList<QQmlError> &warnings) {
                          for (const QQmlError &w : warnings)
                              qWarning().noquote() << w.toString();
                      });

    engine.load(QUrl(QStringLiteral("qrc:/demo/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qWarning() << "Failed to load main.qml from deploy root" << deployRoot;
        return -1;
    }

    return app.exec();
}
