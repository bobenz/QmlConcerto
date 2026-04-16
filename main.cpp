#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "phrase.h"
#include "melody.h"
#include "errorsregistry.h"

static void registerQmlTypes(QQmlApplicationEngine &engine)
{
    qRegisterMetaType<ErrorEntry>("ErrorEntry");
    qRegisterMetaType<Report>("Report");

    qmlRegisterUncreatableType<Phrase>("QmlConcerto", 1, 0, "Phrase",
        "Phrase is abstract — use Melody, Sequence, or Chord");
    qmlRegisterType<Melody>("QmlConcerto", 1, 0, "Melody");

    engine.rootContext()->setContextProperty("ErrorRegistry",
                                             &ErrorRegistry::instance());
    engine.rootContext()->setContextProperty("Errors",
                                             ErrorRegistry::instance().map());
}

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    registerQmlTypes(engine);

    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
