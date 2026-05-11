#ifndef PARTITURA_H
#define PARTITURA_H

#include <QQmlPropertyMap>
#include <QQmlEngine>
#include <QRegularExpression>

/**
 * @brief The Partitura is the Score.
 * Inheriting from QQmlPropertyMap allows direct property access: Partitura.shortcutName
 */
class Partitura : public QQmlPropertyMap
{
    Q_OBJECT
public:
    // Standard Singleton access for C++
    static Partitura* instance() {
        static Partitura* _instance = new Partitura();
        return _instance;
    }

    // Explicitly invokable for registration from other modules
    Q_INVOKABLE void registerPhrase(const QString &key, QObject* phrase);
    Q_INVOKABLE void deregisterPhrase(const QString &key);


private:
    // Private constructor for singleton pattern
    explicit Partitura(QObject *parent = nullptr) : QQmlPropertyMap(parent) {}


    bool isValidKey(const QString &key) const {
        static QRegularExpression re("^[a-z_][a-zA-Z0-9_]*$");
        return re.match(key).hasMatch();
    }
};

// Provider function for QML
static QObject* partitura_provider(QQmlEngine *engine, QJSEngine *scriptEngine) {
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return Partitura::instance();
}

#endif // PARTITURA_H