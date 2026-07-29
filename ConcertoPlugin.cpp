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

    // QML-composition types (Sequence/Chord/Cadenza/Reprisa/Sonata/MelodyPolicies) are NOT
    // registered here — qmldir is the single source of truth for them. When this plugin is
    // loaded via `import Concerto 1.0`, Qt already found this DLL through a real on-disk
    // qmldir (see the project-root qmldir and the deploy tree it gets copied into), and that
    // same qmldir's own type-mapping lines resolve those six types relative to its own
    // directory — nothing extra needed here.
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
