#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include "concerto_registration.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    new ConcertoRegistration(&engine);

    engine.load(QUrl(QStringLiteral("qrc:/demo/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
