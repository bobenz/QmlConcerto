#include "phrase.h"
#include <QDebug>

Phrase::Phrase(QObject *parent) : QObject(parent) {}

void Phrase::setState(State s)
{
    if (m_state == s) return;
    m_state = s;
    log_state();
    emit stateChanged();
}

void Phrase::setFinalized(Finalized f)
{
    if (m_finalized == f) return;
    m_finalized = f;
    emit exit();
    emit finalizedChanged();
}

bool Phrase::play()
{
    if (m_state == Playing) {
        qWarning() << metaObject()->className() << "play() called while already Playing";
        return false;
    }
    setFinalized(None);
    setState(Playing);

    emit enter();
    return _play();
}

void Phrase::finish(const ErrorEntry &error)
{
    if (m_state != Playing) return;
    if(error == NoError)
    {
        setFinalized(Consonant);

    }
    else
    {
       setFinalized(Dissonant);
    }
    setLastError(error);
    setState(Resolved);
}

void Phrase::abort()
{
    if (m_state != Playing) return;
    setFinalized(Aborted);
    setState(Resolved);
}

void Phrase::info(QString msg)
{
    Report r = make_report();
    r.category= Report::Category::Info;
    r.message = msg;
    emit report(r);
}

void Phrase::warning(QString msg)
{
    Report r = make_report();
    r.category= Report::Category::Warning;
    r.message = msg;
    emit report(r);
}

void Phrase::error(ErrorEntry entry)
{
    Report r = make_report();
    r.category = Report::Category::Error;
    r.message = entry.toString();
    emit report(r);
}

void Phrase::log_state()
{
    Report r = make_report();
    r.category = Report::Category::Info;
    QList<QString> st;
    switch (m_state)
        {
        case Silent: st << "Silent";break;
        case Playing: st <<"Playing"; break;   // Executing
        case Paused: st << "Paused"; break; // Suspended
        case Resolved:
            st << "Resolved";
            switch (m_finalized)
            {
            case Aborted:   st << "Aborted";   break;
            case Consonant: st << "Consonant"; break;
            case Dissonant: st << "Dissonant"; break;
            default: break;
            }
            break;
        default: break;
        }


    emit report(r);
}

void Phrase::log_signal(const QString &signalName, const QVariant &data)
{
    Report r = make_report();
    r.category = Report::Category::Debug;
    r.message = QString("signal: %1").arg(signalName);
    r.data = data;
    emit report(r);
}

Report Phrase::make_report()
{


    Report r;
    r.timestamp = QDateTime::currentDateTime();
    r.source = QString("%1/%2").arg(m_parentPath).arg(label());
    return r;
}

bool Phrase::after() const
{
    return m_after;
}

void Phrase::setAfter(bool newAfter)
{
    if (m_after == newAfter)
        return;
    m_after = newAfter;
    if(m_after) play();
    emit afterChanged();
}

ErrorEntry Phrase::lastError() const
{
    return m_lastError;
}

void Phrase::setLastError(const ErrorEntry &newLastError)
{
    m_lastError = newLastError;
    emit lastErrorChanged();
}

QString Phrase::title() const
{
    return m_title;
}

void Phrase::setTitle(const QString &newTitle)
{
    if(m_title == newTitle) return;
    m_title = newTitle;
    emit titleChanged();
}

QString Phrase::lyric() const
{
    return m_lyric;
}

void Phrase::setLyric(const QString &newLyric)
{
    if(m_lyric == newLyric) return;
    m_lyric = newLyric;
    emit lyricChanged();
}

