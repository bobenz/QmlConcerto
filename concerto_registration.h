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
#include "errorsregistry.h"

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
        qRegisterMetaType<ErrorEntry>("ErrorEntry");

        // 2. Expose the Registry itself to call functions like lookup() or declare()
        engine->rootContext()->setContextProperty("ErrorRegistry", &ErrorRegistry::instance());

        // 3. Expose the PropertyMap as "Errors" for easy dot-notation access
        // This allows you to write: Errors.shutter_stuck.description
        engine->rootContext()->setContextProperty("Errors", ErrorRegistry::instance().map());
    }
};

#endif // REGISTRATION_H
