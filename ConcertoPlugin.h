#pragma once
#ifndef CONCERTOPLUGIN_H
#define CONCERTOPLUGIN_H

#include <QQmlExtensionPlugin>
#include "errorsregistry.h"

class QMLCONCERTO_EXPORT ConcertoPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override;
    void initializeEngine(QQmlEngine *engine, const char *uri) override;
};

#endif // CONCERTOPLUGIN_H
