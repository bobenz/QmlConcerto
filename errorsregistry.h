#pragma once
#include <QString>
#include <QMap>
#include <QObject>
#include <QVariant>
#include <QDebug>
#include <QQmlPropertyMap>

struct ErrorEntryNoRegTag {};

// ── ErrorEntry ───────────────────────────────────────────────────────────────

class ErrorEntry
{
    Q_GADGET
    Q_PROPERTY(QString  source      READ source)
    Q_PROPERTY(int      code        READ code)
    Q_PROPERTY(QString  description READ description)
    Q_PROPERTY(bool     valid       READ isValid)
    Q_PROPERTY(QString  text        READ toString)

public:
    ErrorEntry() = default;



    // Self-registering — for static instances in error definition headers
    ErrorEntry(const QString &name,
               const QString &source,
               int            code,
               const QString &description);

    // Non-registering — used by ErrorRegistry::create() internally
    ErrorEntry(const QString &name,
               const QString &source,
               int            code,
               const QString &description,
               ErrorEntryNoRegTag);

    // Constructor that obtains data from the registry
    inline ErrorEntry(int code);

    QString name()        const { return m_name; }
    QString source()      const { return m_source; }
    int     code()        const { return m_code; }
    QString description() const { return m_description; }
    bool    isValid()     const { return !m_name.isEmpty(); }

    Q_INVOKABLE QString toString() const
    {
        if (!isValid()) return QStringLiteral("<unknown error>");
        return QString("[%1] (%2) %3").arg(m_source).arg(m_code).arg(m_description);
    }

private:
    QString m_name;
    QString m_source;
    int     m_code        { 0 };
    QString m_description;
};

Q_DECLARE_METATYPE(ErrorEntry)
inline bool operator==(const ErrorEntry &lhs, const ErrorEntry &rhs)
{
    return lhs.code() == rhs.code() && lhs.source() == rhs.source();
}

inline bool operator!=(const ErrorEntry &lhs, const ErrorEntry &rhs)
{
    return !(lhs == rhs);
}



class ErrorRegistry : public QObject
{
    Q_OBJECT

public:
    static ErrorRegistry &instance()
    {
        static ErrorRegistry s_instance;
        return s_instance;
    }

    // Returns the QQmlPropertyMap to set as "Errors" context property
    QQmlPropertyMap *map() { return &m_map; }

    // ── Registration ─────────────────────────────────────────────────────────

    // Called by self-registering ErrorEntry ctor
    void registerEntry(const ErrorEntry &entry)
    {
        m_byCode.insert(entry.code(), entry);
        m_byName.insert(entry.name(), entry);
        m_map.insert(entry.name(), QVariant::fromValue(entry));
    }

    // Explicit registration from C++ or Q_INVOKABLE from QML
    Q_INVOKABLE void create(const QString &name,
                            const QString &source,
                            int            code,
                            const QString &description)
    {
        ErrorEntry e(name, source, code, description, ErrorEntryNoRegTag{});
        m_byCode.insert(code, e);
        m_byName.insert(name, e);
        m_map.insert(name, QVariant::fromValue(e));
    }
    // Accepts a JS object literal from QML:
    // { name: "shutter_stuck", source: "CDM", code: 1111,
    //   description: "Shutter mechanism stuck" }
    Q_INVOKABLE void declare(const QVariantMap &def)
    {
        const QString name   = def.value("name").toString();
        const QString source = def.value("source").toString();
        const int     code   = def.value("code").toInt();
        const QString desc   = def.value("description").toString();

        if (name.isEmpty() || source.isEmpty()) {
            qWarning() << "[ErrorRegistry] declare(): missing name or source in" << def;
            return;
        }

        ErrorEntry e(name, source, code, desc, ErrorEntryNoRegTag{});
        m_byCode.insert(code, e);
        m_byName.insert(name, e);
        m_map.insert(name, QVariant::fromValue(e));
    }
    // ── Lookup ───────────────────────────────────────────────────────────────

    Q_INVOKABLE QVariant lookup(int code) const
    {
        return QVariant::fromValue(m_byCode.value(code, ErrorEntry{}));
    }

    Q_INVOKABLE QVariant lookupByName(const QString &name) const
    {
        return QVariant::fromValue(m_byName.value(name, ErrorEntry{}));
    }

    Q_INVOKABLE QString describe(int code) const
    {
        return m_byCode.value(code, ErrorEntry{}).toString();
    }

    Q_INVOKABLE bool contains(int code) const
    {
        return m_byCode.contains(code);
    }

    Q_INVOKABLE bool containsName(const QString &name) const
    {
        return m_byName.contains(name);
    }

private:
    ErrorRegistry(QObject *parent = nullptr) : QObject(parent) {}

    QMap<int,     ErrorEntry>   m_byCode;
    QMap<QString, ErrorEntry>   m_byName;
    QQmlPropertyMap             m_map;
};

// ── Inline constructors ───────────────────────────────────────────────────────

inline ErrorEntry::ErrorEntry(const QString &name,
                              const QString &source,
                              int            code,
                              const QString &description)
    : m_name(name), m_source(source), m_code(code), m_description(description)
{
    ErrorRegistry::instance().registerEntry(*this);
}

inline ErrorEntry::ErrorEntry(const QString &name,
                              const QString &source,
                              int            code,
                              const QString &description,
                              ErrorEntryNoRegTag)
    : m_name(name), m_source(source), m_code(code), m_description(description)
{
    // intentionally does NOT call registerEntry
}

inline ErrorEntry NoError("no_error", "APP", 0, "No error");
inline ErrorEntry UnknownError("unknown_error", "SYS", -1000000, "Unknown error code");

inline ErrorEntry::ErrorEntry(int code)
{
    // Access the registry's internal map
    // We use ErrorRegistry::instance() to find the existing definition
    ErrorRegistry& reg = ErrorRegistry::instance();

    if (reg.contains(code)) {
        // Use the registry's lookup to populate this instance
        // We cast the QVariant back to ErrorEntry
        *this = reg.lookup(code).value<ErrorEntry>();
    } else {
        // Fallback to the UnknownError definition
        *this = UnknownError;
        // Optionally override the code to reflect the requested but missing code
        m_code = code;
    }
}

