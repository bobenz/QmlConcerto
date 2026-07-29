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

    qmlRegisterSingletonType<Partitura>(uri, 1, 0, "Partitura", partitura_provider);

    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/Concerto/MelodyPolicies.qml")),
                             uri, 1, 0, "MelodyPolicies");

    // QML-composition types (Sequence/Chord/...) — registered directly by URL rather than
    // relying on qmldir-based directory resolution, which isn't reliable here either (the
    // project's qmldir and the plugin DLL/qmldir a deployed build copies things to don't
    // consistently land in a single "Concerto"-named directory) — same mechanism
    // MelodyPolicies above already uses.
    qmlRegisterType(QUrl(QStringLiteral("qrc:/Concerto/Sequence.qml")), uri, 1, 0, "Sequence");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/Concerto/Chord.qml")),    uri, 1, 0, "Chord");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/Concerto/Cadenza.qml")),  uri, 1, 0, "Cadenza");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/Concerto/Reprisa.qml")),  uri, 1, 0, "Reprisa");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/Concerto/Sonata.qml")),   uri, 1, 0, "Sonata");
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
