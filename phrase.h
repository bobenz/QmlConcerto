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



class Phrase : public QObject
{
    Q_OBJECT

    Q_PROPERTY(State     state     READ state     NOTIFY stateChanged     FINAL)
    Q_PROPERTY(Finalized finalized READ finalized NOTIFY finalizedChanged FINAL)
    Q_PROPERTY(bool after READ after WRITE setAfter NOTIFY afterChanged FINAL)
    Q_PROPERTY(ErrorEntry lastError READ lastError WRITE setLastError NOTIFY lastErrorChanged FINAL)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    Q_PROPERTY(QString lyric READ lyric WRITE setLyric NOTIFY lyricChanged FINAL)

public:
    enum State {
        Silent,    // Initial / idle
        Playing,   // Executing
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

public slots:
    bool play();
    void finish(const ErrorEntry &newLastError =NoError);
    void abort();


    ////logging
    ///
    void info(QString msg);
    void warning(QString msg);
    void error(ErrorEntry);


signals:
    void stateChanged();
    void finalizedChanged();

    void enter();
    void exit();

    void afterChanged();

    void lastErrorChanged();

    void titleChanged();

    void lyricChanged();
    void report(Report);

protected:
    virtual bool _play() = 0;

    void log_signal(const QString &signalName, const QVariant &data = QVariant());
    Report make_report();

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

};

#endif // PHRASE_H
