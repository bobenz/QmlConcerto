#include "phrase.h"
#include <QDebug>

Phrase::Phrase(QObject *parent) : QObject(parent) {}

#define REPORT(r)    qDebug() << r; emit report(r)

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
    if(m_finalized != Finalized::None )
    {
        emit exit();
    }
    emit finalizedChanged();
}

bool Phrase::play()
{

    if (m_state == Playing) {
        qWarning() << metaObject()->className() << "play() called while already Playing";
        return false;
    }
    if(m_finishOn)
    {
        setFinalized(Finalized::Consonant);
        return false;
    }
    if(m_abortOn)
    {
        setFinalized(Finalized::Aborted);
        return false;
    }

    setFinalized(None);
    setState(Playing);

    emit enter();
    return _play();
}
void Phrase::accompany()
{
    if (m_state != Playing) {
        qWarning() << metaObject()->className() << "accompany() called outside Playing";
        return;
    }
    setState(Accompanying);
}

void Phrase::finish(const ErrorEntry &error)
{
    if (m_state != Playing && m_state != Accompanying) return;
    setLastError(error);

    if(error == NoError)
    {
        setFinalized(Consonant);

    }
    else
    {

       setFinalized(Dissonant);
    }

    setState(Resolved);
}

void Phrase::abort()
{
    if (m_state != Playing && m_state != Accompanying) return;
    setFinalized(Aborted);
    setState(Resolved);
}

void Phrase::reset()
{
    _reset();
}

void Phrase::info(QString msg) const
{
    Report r = make_report();
    r.category= Report::Category::Info;
    r.message = msg;
    REPORT(r);
}

void Phrase::warning(QString msg) const
{
    Report r = make_report();
    r.category= Report::Category::Warning;
    r.message = msg;
    REPORT(r);
}

void Phrase::error(ErrorEntry entry) const
{
    Report r = make_report();
    r.category = Report::Category::Error;
    r.message = entry.description();
    r.data = QVariant::fromValue(entry);
    REPORT(r);
}

bool Phrase::_play()
{
    finish();
    return true;
}

void Phrase::_reset()
{    
    setFinalized(Finalized::None);
    setLastError(NoError);
    setState(Phrase::Silent);

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

        r.message = st.join(" ");
        r.data = QVariant::fromValue(m_state);
        REPORT(r);
}

void Phrase::log_signal(const QString &signalName, const QVariant &data)
{
    Report r = make_report();
    r.category = Report::Category::Debug;
    r.message = QString("signal: %1").arg(signalName);
    r.data = data;
    REPORT(r);
}

Report Phrase::make_report() const
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
    if(m_after)
    {
        play();
    }
    emit afterChanged();
}

ErrorEntry Phrase::lastError() const
{
    return m_lastError;
}

void Phrase::setLastError(const ErrorEntry &newLastError)
{
    if (m_lastError == newLastError) return;
    m_lastError = newLastError;
    error(m_lastError);
    if(m_lastError  != NoError && m_finishOnError)
    {
        finish(m_lastError);
    }
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


bool Phrase::abortOn() const
{
    return m_abortOn;
}

void Phrase::setAbortOn(bool newAbortOn)
{
    if (m_abortOn == newAbortOn)
        return;
    m_abortOn = newAbortOn;
    if(m_abortOn)
    {
        abort();
    }
    emit abortOnChanged();
}

bool Phrase::finishOn() const
{
    return m_finishOn;
}

void Phrase::setFinishOn(bool newFinishOn)
{
    if (m_finishOn == newFinishOn)
        return;
    m_finishOn = newFinishOn;
    if(m_finishOn)
    {
        finish();
    }
    emit finishOnChanged();
}

bool Phrase::finishOnError() const
{
    return m_finishOnError;
}

void Phrase::setFinishOnError(bool newFinishOnError)
{
    if (m_finishOnError == newFinishOnError)
        return;
    m_finishOnError = newFinishOnError;
    emit finishOnErrorChanged();
}
