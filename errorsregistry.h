#pragma once
#include <QString>
#include <QMap>
#include <QObject>
#include <QVariant>
#include <QDebug>
#include <QQmlPropertyMap>

struct ErrorEntryNoRegTag {};

// ── Composite key ─────────────────────────────────────────────────────────────
//
// Errors are keyed by (code, source) so that different subsystems can reuse
// the same numeric code without collision (e.g. CDM code -100 vs PTR code -100).

struct ErrorKey
{
    int     code   { 0 };
    QString source;

    bool operator<(const ErrorKey &o) const
    {
        if (code != o.code) return code < o.code;
        return source < o.source;
    }
    bool operator==(const ErrorKey &o) const
    {
        return code == o.code && source == o.source;
    }
};

// ── ErrorEntry ────────────────────────────────────────────────────────────────

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

    // Self-registering — for static instances in error-definition headers.
    ErrorEntry(const QString &name,
               const QString &source,
               int            code,
               const QString &description);

    // Non-registering — used by ErrorRegistry::create() / declare() internally.
    ErrorEntry(const QString &name,
               const QString &source,
               int            code,
               const QString &description,
               ErrorEntryNoRegTag);

    // Unambiguous lookup constructor.
    // Finds the entry with exactly this (code, source) pair.
    // If not found, falls back to UnknownError and logs a warning.
    inline ErrorEntry(int code, const QString &source);

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

// ── ErrorRegistry ─────────────────────────────────────────────────────────────

class ErrorRegistry : public QObject
{
    Q_OBJECT

public:
    static ErrorRegistry &instance()
    {
        static ErrorRegistry s_instance;
        return s_instance;
    }

    // Returns the QQmlPropertyMap to expose as the "Errors" context property.
    QQmlPropertyMap *map() { return &m_map; }

    // ── Registration ─────────────────────────────────────────────────────────

    void registerEntry(const ErrorEntry &entry)
    {
        ErrorKey key{ entry.code(), entry.source() };
        m_byKey.insert(key, entry);
        m_byName.insert(entry.name(), entry);
        m_map.insert(entry.name(), QVariant::fromValue(entry));
    }

    Q_INVOKABLE void create(const QString &name,
                            const QString &source,
                            int            code,
                            const QString &description)
    {
        ErrorEntry e(name, source, code, description, ErrorEntryNoRegTag{});
        ErrorKey key{ code, source };
        m_byKey.insert(key, e);
        m_byName.insert(name, e);
        m_map.insert(name, QVariant::fromValue(e));
    }

    // Accepts a JS object literal from QML:
    // { name: "shutter_stuck", source: "CDM", code: -2001,
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
        ErrorKey key{ code, source };
        m_byKey.insert(key, e);
        m_byName.insert(name, e);
        m_map.insert(name, QVariant::fromValue(e));
    }

    // ── Lookup ───────────────────────────────────────────────────────────────

    // Preferred: unambiguous lookup by (code, source).
    Q_INVOKABLE QVariant lookup(int code, const QString &source) const
    {
        return QVariant::fromValue(m_byKey.value({ code, source }, ErrorEntry{}));
    }

    // Legacy: lookup by code only. Succeeds if exactly one entry carries that
    // code across all sources; logs a warning if there are multiple matches.
    Q_INVOKABLE QVariant lookup(int code) const
    {
        return QVariant::fromValue(uniqueByCode(code));
    }

    Q_INVOKABLE QVariant lookupByName(const QString &name) const
    {
        return QVariant::fromValue(m_byName.value(name, ErrorEntry{}));
    }

    // Preferred describe / contains overloads.
    Q_INVOKABLE QString describe(int code, const QString &source) const
    {
        return m_byKey.value({ code, source }, ErrorEntry{}).toString();
    }

    // Legacy describe — warns on ambiguity, same rules as lookup(int).
    Q_INVOKABLE QString describe(int code) const
    {
        return uniqueByCode(code).toString();
    }

    Q_INVOKABLE bool contains(int code, const QString &source) const
    {
        return m_byKey.contains({ code, source });
    }

    // Legacy contains — true if at least one entry with this code exists.
    Q_INVOKABLE bool contains(int code) const
    {
        return !matchingCodes(code).isEmpty();
    }

    Q_INVOKABLE bool containsName(const QString &name) const
    {
        return m_byName.contains(name);
    }

private:
    ErrorRegistry(QObject *parent = nullptr) : QObject(parent) {}

    // Collect all entries whose numeric code matches (ignoring source).
    QList<ErrorEntry> matchingCodes(int code) const
    {
        QList<ErrorEntry> result;
        for (auto it = m_byKey.cbegin(); it != m_byKey.cend(); ++it) {
            if (it.key().code == code)
                result.append(it.value());
        }
        return result;
    }

    // Returns the unique entry for a bare code, or warns + returns invalid.
    ErrorEntry uniqueByCode(int code) const
    {
        const QList<ErrorEntry> matches = matchingCodes(code);
        if (matches.isEmpty()) {
            return ErrorEntry{};
        }
        if (matches.size() > 1) {
            QStringList sources;
            for (const ErrorEntry &e : matches)
                sources << e.source();
            qWarning() << "[ErrorRegistry] lookup(" << code << ") is ambiguous — "
                                                               "multiple sources registered this code:" << sources
                       << "— use lookup(code, source) for an unambiguous result.";
        }
        return matches.first();
    }

    QMap<ErrorKey,  ErrorEntry>   m_byKey;   // primary store: (code, source) → entry
    QMap<QString,   ErrorEntry>   m_byName;  // secondary: name → entry
    QQmlPropertyMap               m_map;     // QML "Errors.*" property map
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

inline ErrorEntry::ErrorEntry(int code, const QString &source)
{
    ErrorRegistry &reg = ErrorRegistry::instance();
    if (reg.contains(code, source)) {
        *this = reg.lookup(code, source).value<ErrorEntry>();
    } else {
        qWarning() << "[ErrorEntry] No entry found for code" << code
                   << "source" << source << "— substituting UnknownError.";
        // Populated below after UnknownError is defined.
        m_source = source;
        m_code   = code;
        // m_name stays empty → isValid() == false, toString() → "<unknown error>"
    }
}

// ── Built-in sentinel entries ─────────────────────────────────────────────────

inline ErrorEntry NoError     ("no_error",      "APP", 0,        "No error");
inline ErrorEntry UnknownError("unknown_error", "SYS", -1000000, "Unknown error code");
