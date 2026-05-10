#pragma once
#ifndef PHRASE_H
#define PHRASE_H

#include <QObject>

#include "errorsregistry.h"
#include <QDateTime>

struct Report {
    Q_GADGET
    Q_PROPERTY(QString source MEMBER source)
    Q_PROPERTY(QString category MEMBER category)
    Q_PROPERTY(QString message MEMBER message)
    Q_PROPERTY(QVariant data MEMBER data)
    Q_PROPERTY(QDateTime timestamp MEMBER timestamp)
public:
    enum Category {
        Info,
        Warning,
        Error,
        Debug,
        Critical
    };
    Q_ENUM(Category)
    QString source;
    QString category;
    QString message;
    QVariant data;
    QDateTime timestamp;
};

inline QDebug operator<<(QDebug debug, const Report &report)
{
    QDebugStateSaver saver(debug);
    debug.nospace() << "Report("
                    << "Source: "    << report.source
                    << ", Category: " << report.category
                    << ", Message: "  << report.message
                    << ", Data: "     << report.data
                    << ", Time: "     << report.timestamp.toString(Qt::ISODateWithMs)
                    << ")";
    return debug;
}

class Phrase : public QObject
{
    Q_OBJECT

    Q_PROPERTY(State     state     READ state     NOTIFY stateChanged     FINAL)
    Q_PROPERTY(Finalized finalized READ finalized NOTIFY finalizedChanged FINAL)
    Q_PROPERTY(bool after READ after WRITE setAfter NOTIFY afterChanged FINAL)
    Q_PROPERTY(ErrorEntry lastError READ lastError WRITE setLastError NOTIFY lastErrorChanged FINAL)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    Q_PROPERTY(QString lyric READ lyric WRITE setLyric NOTIFY lyricChanged FINAL)
    Q_PROPERTY(bool abortOn READ abortOn WRITE setAbortOn NOTIFY abortOnChanged FINAL)
    Q_PROPERTY(bool finishOn READ finishOn WRITE setFinishOn NOTIFY finishOnChanged FINAL)
    Q_PROPERTY(bool finishOnError READ finishOnError  WRITE setFinishOnError NOTIFY finishOnErrorChanged FINAL)

public:
    enum State {
        Silent,    // Initial / idle
        Playing,   // Executing
        Accompanying, //Playing on background
        Paused,    // Suspended
        Resolved   // Terminal — check finalized for outcome
    };
    Q_ENUM(State)

    enum Finalized {
        None,      // Not yet finished
        Aborted,   // Manually stopped
        Dissonant, // Finished with error
        Consonant  // Finished with success
    };
    Q_ENUM(Finalized)

    explicit Phrase(QObject *parent = nullptr);

    State     state()     const { return m_state; }
    Finalized finalized() const { return m_finalized; }

    // C++-only write — no WRITE in Q_PROPERTY
    void setState(State s);
    void setFinalized(Finalized f);

    bool after() const;
    void setAfter(bool newAfter);

    ErrorEntry lastError() const;
    void setLastError(const ErrorEntry &newLastError);

    QString title() const;
    void setTitle(const QString &newTitle);

    QString lyric() const;
    void setLyric(const QString &newLyric);

    void setParentPath(QString p) { m_parentPath = p;}

    bool abortOn() const;
    void setAbortOn(bool newAbortOn);

    bool finishOn() const;
    void setFinishOn(bool newFinishOn);

    bool finishOnError() const;
    void setFinishOnError(bool newFinishOnError);

public slots:
    bool play();
    void finish(const ErrorEntry &newLastError =NoError);
    void abort();
    void reset();
    void accompany();


    ////logging
    ///
    void info(QString msg) const;
    void warning(QString msg) const;
    void error(ErrorEntry) const;


signals:
    void stateChanged();
    void finalizedChanged();

    void enter();
    void exit();
    void cleanup(); //called after _reset;
    void cancel(); //called after _abort;

    void afterChanged();

    void lastErrorChanged();

    void titleChanged();

    void lyricChanged();
    void report(Report) const;

    void abortOnChanged();

    void finishOnChanged();

    void finishOnErrorChanged();

protected:
    virtual bool _play();
    virtual void _reset();
    virtual void _abort();

    void log_signal(const QString &signalName, const QVariant &data = QVariant());
    Report make_report() const;

private:
    void log_state();
    State     m_state     = Silent;
    Finalized m_finalized = None;
    bool m_after = false;
    ErrorEntry m_lastError;
    QString m_title;
    QString m_lyric;
    QString m_parentPath = "";
    // phrase.cpp — private helper, not exposed in header
    inline QString label() const
    {
        return m_title.isEmpty() ? QLatin1String(metaObject()->className()) : m_title;
    }

    bool m_abortOn = false;
    bool m_finishOn = false;
    bool m_finishOnError = true;
};

#endif // PHRASE_H
