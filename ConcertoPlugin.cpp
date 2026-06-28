#include "ConcertoPlugin.h"

#include <QtQml>
#include <QQmlEngine>
#include <QQmlContext>

#include "phrase.h"
#include "melody.h"
#include "pause.h"
#include "quote.h"
#include "partitura.h"
#include "errorsregistry.h"

void ConcertoPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(QLatin1String(uri) == QLatin1String("Concerto"));

    qmlRegisterUncreatableType<Phrase>(uri, 1, 0, "Phrase",
        QStringLiteral("Phrase is abstract — subclass it in C++ or use Melody/Sequence/Chord"));
    qmlRegisterType<Melody>(uri, 1, 0, "Melody");
    qmlRegisterType<Pause> (uri, 1, 0, "Pause");
    qmlRegisterType<Quote> (uri, 1, 0, "Quote");

    qRegisterMetaType<ErrorEntry>("ErrorEntry");
    qRegisterMetaType<Report>("Report");

    qmlRegisterSingletonType<Partitura>(uri, 1, 0, "Partitura", partitura_provider);

    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/Concerto/MelodyPolicies.qml")),
                             uri, 1, 0, "MelodyPolicies");
}

void ConcertoPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    Q_UNUSED(uri)
    engine->rootContext()->setContextProperty(QStringLiteral("ErrorRegistry"),
                                              &ErrorRegistry::instance());
    engine->rootContext()->setContextProperty(QStringLiteral("Errors"),
                                              ErrorRegistry::instance().map());
}
