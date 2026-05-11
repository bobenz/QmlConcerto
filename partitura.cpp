#include "partitura.h"

void Partitura::registerPhrase(const QString &key, QObject* phrase) {

    if (!isValidKey(key)) {
        qWarning() << "Partitura Error: Invalid key name" << key
                   << ". Must start with lowercase/underscore and be alphanumeric.";
        return ;
    }

    if (phrase) {
        insert(key, QVariant::fromValue(phrase));
    }
}


void Partitura::deregisterPhrase(const QString &key) {
    if (contains(key)) {
        clear(key);
    }
}