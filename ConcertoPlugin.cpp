#include "ConcertoPlugin.h"

#include <QtQml>
#include <QQmlEngine>
#include <QQmlContext>

#include "phrase.h"
#include "melody.h"
#include "pause.h"
#include "quote.h"
#include "partitura.h"
#include "constantsregistry.h"
#include "report.h"
#include "reportsreceiver.h"

void ConcertoPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(QLatin1String(uri) == QLatin1String("Concerto"));

    qmlRegisterType<Phrase>(uri, 1, 0, "Phrase");
    qmlRegisterType<Melody>(uri, 1, 0, "Melody");
    qmlRegisterType<Pause> (uri, 1, 0, "Pause");
    qmlRegisterType<Quote> (uri, 1, 0, "Quote");
    qmlRegisterType<ReportsReceiver>(uri, 1, 0, "ReportsReceiver");

    qRegisterMetaType<ConstantEntry>("ConstantEntry");
    qRegisterMetaType<Report>("Report");

    // Lowercase name: Report is a Q_GADGET/value type, and Qt6's QML type
    // system expects value types to use a lowercase name (like "point", "rect").
    qmlRegisterUncreatableType<Report>(uri, 1, 0, "report",
        QStringLiteral("Report is a value type — read it from ReportsReceiver.onReportReceived"));

    qmlRegisterSingletonType<Partitura>(uri, 1, 0, "Partitura", partitura_provider);

    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/Concerto/MelodyPolicies.qml")),
                             uri, 1, 0, "MelodyPolicies");
}

void ConcertoPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    Q_UNUSED(uri)
    // Names kept as "ErrorRegistry"/"Errors" for backward compatibility — now
    // backed by RegRep's generalized ConstantRegistry.
    engine->rootContext()->setContextProperty(QStringLiteral("ErrorRegistry"),
                                              &ConstantRegistry::instance());
    engine->rootContext()->setContextProperty(QStringLiteral("Errors"),
                                              ConstantRegistry::instance().map());
}
