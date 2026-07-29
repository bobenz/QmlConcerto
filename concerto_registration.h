#ifndef CONCERTO_REGISTRATION_H
#define CONCERTO_REGISTRATION_H
#pragma once
#include <QtQml>
#include <QQmlEngine>
#include <QQmlContext>

#include "phrase.h"
#include "pause.h"
#include "melody.h"
#include "quote.h"
#include "partitura.h"
#include "constantsregistry.h"
#include "report.h"
#include "reportsreceiver.h"

static const char* uri   = "Concerto";
static const int   major = 1;
static const int   minor = 0;

class ConcertoRegistration
{
public:
    ConcertoRegistration(QQmlEngine* engine)
    {
        Q_ASSERT(engine);
        qmlRegisterType<Phrase>        (uri, major, minor, "Phrase");
        qmlRegisterType<Melody>        (uri, major, minor, "Melody");
        qmlRegisterType<Pause>        (uri, major, minor, "Pause");
        qmlRegisterType<Quote>        (uri, major, minor, "Quote");
        qmlRegisterType<ReportsReceiver>(uri, major, minor, "ReportsReceiver");

        qRegisterMetaType<ConstantEntry>("ConstantEntry");
        qRegisterMetaType<Report>("Report");

        // 2. Expose the Registry itself to call functions like lookup() or declare()
        // Names kept as "ErrorRegistry"/"Errors" for backward compatibility — now
        // backed by RegRep's generalized ConstantRegistry.
        engine->rootContext()->setContextProperty("ErrorRegistry", &ConstantRegistry::instance());
        qmlRegisterSingletonType<Partitura>("Concerto", 1, 0, "Partitura", partitura_provider);
        qmlRegisterSingletonType(QUrl("qrc:/Concerto/MelodyPolicies.qml"),
                                 "Concerto", 1, 0, "MelodyPolicies");

        // QML-composition types (Sequence/Chord/...) — registered directly by URL. Source
        // inclusion has no separate plugin to load, so the qmldir+`plugin` mechanism (used by
        // ConcertoPlugin.cpp for the real loaded-plugin path) doesn't apply here at all — this
        // is the only mechanism available for a source-included consumer to expose a QML-file
        // type under the "Concerto" URI, same as MelodyPolicies above.
        qmlRegisterType(QUrl("qrc:/Concerto/Sequence.qml"), uri, major, minor, "Sequence");
        qmlRegisterType(QUrl("qrc:/Concerto/Chord.qml"),    uri, major, minor, "Chord");
        qmlRegisterType(QUrl("qrc:/Concerto/Cadenza.qml"),  uri, major, minor, "Cadenza");
        qmlRegisterType(QUrl("qrc:/Concerto/Reprisa.qml"),  uri, major, minor, "Reprisa");
        qmlRegisterType(QUrl("qrc:/Concerto/Sonata.qml"),   uri, major, minor, "Sonata");
        // 3. Expose the PropertyMap as "Errors" for easy dot-notation access
        // This allows you to write: Errors.shutter_stuck.description
        engine->rootContext()->setContextProperty("Errors", ConstantRegistry::instance().map());
        engine->addImportPath("qrc:/Concerto");
        engine->addImportPath(CONCERTO_HOME);
    }
};

#endif // REGISTRATION_H
