#include "phrase.h"
#include <QDebug>
#include "partitura.h"

Phrase::Phrase(QObject *parent) : QObject(parent) {}

#define REPORT(r)  qDebug() << r; emit report(r)

// ── State / Finalized setters ─────────────────────────────────────────────────

void Phrase::setState(State s)
{
    if (m_state == s) return;
    bool wasPlaying = playing();
    m_state = s;
    log_state();
    if (playing() != wasPlaying)
        emit playingChanged();
    emit stateChanged();
}

void Phrase::setFinalized(Finalized f)
{
    if (m_finalized == f) return;
    m_finalized = f;
    if (m_finalized != Finalized::None)
        emit exit();
    emit finalizedChanged();
}

// ── Public slots ──────────────────────────────────────────────────────────────

bool Phrase::play()
{
    if (m_state == Playing) {
        qWarning() << metaObject()->className() << "play() called while already Playing";
        return false;
    }
    if (m_finishOn) {
        setFinalized(Finalized::Consonant);
        return false;
    }
    if (m_abortOn) {
        setFinalized(Finalized::Aborted);
        return false;
    }

    setFinalized(None);
    setState(Playing);
    emit enter();
    return _play();
    // No _play_complete(): completion is driven by the subclass via
    // finish() or accompany(), exactly as before.
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

    m_pendingFinishError = error;

    if (_finish())
        _finish_complete(error);
    // else: subclass calls _finish_complete() when async teardown is done.
}

void Phrase::abort()
{
    if (!playing()) return;

    if (_abort())
        _abort_complete();
    // else: subclass calls _abort_complete() when async teardown is done.
}

void Phrase::reset()
{
    if (_reset())
        _reset_complete();
    // else: subclass calls _reset_complete() when async teardown is done.
}

// ── Completion methods ────────────────────────────────────────────────────────

void Phrase::_abort_complete()
{
    if (m_state != Playing && m_state != Accompanying) {
        qWarning() << metaObject()->className()
        << "_abort_complete() called outside Playing/Accompanying — ignored";
        return;
    }
    emit cancel();
    setFinalized(Aborted);
    setState(Resolved);
}

void Phrase::_finish_complete()
{
    _finish_complete(m_pendingFinishError);
}

void Phrase::_finish_complete(const ErrorEntry &error)
{
    if (m_state != Playing && m_state != Accompanying) {
        qWarning() << metaObject()->className()
        << "_finish_complete() called outside Playing/Accompanying — ignored";
        return;
    }
    setLastError(error);
    setFinalized(error == NoError ? Consonant : Dissonant);
    setState(Resolved);
}

void Phrase::_reset_complete()
{
    emit cleanup();
    setFinalized(Finalized::None);
    setLastError(NoError);
    setState(Silent);
}

// ── Default virtual implementations — synchronous no-ops ─────────────────────

bool Phrase::_play()
{
    finish();
    return true;
}

bool Phrase::_abort()
{
    return true;
}

bool Phrase::_finish()
{
    return true;
}

bool Phrase::_reset()
{
    return true;
}

// ── Logging ───────────────────────────────────────────────────────────────────

void Phrase::info(QString msg) const
{
    Report r = make_report();
    r.category = Report::Category::Info;
    r.message  = msg;
    REPORT(r);
}

void Phrase::warning(QString msg) const
{
    Report r = make_report();
    r.category = Report::Category::Warning;
    r.message  = msg;
    REPORT(r);
}

void Phrase::error(ErrorEntry entry) const
{
    Report r = make_report();
    r.category = Report::Category::Error;
    r.message  = entry.description();
    r.data     = QVariant::fromValue(entry);
    REPORT(r);
}

void Phrase::log_state()
{
    Report r = make_report();
    r.category = Report::Category::Info;
    QList<QString> st;
    switch (m_state) {
    case Silent:      st << "Silent";      break;
    case Playing:     st << "Playing";     break;
    case Accompanying:st << "Accompanying";break;
    case Paused:      st << "Paused";      break;
    case Resolved:
        st << "Resolved";
        switch (m_finalized) {
        case Aborted:   st << "Aborted";   break;
        case Consonant: st << "Consonant"; break;
        case Dissonant: st << "Dissonant"; break;
        default: break;
        }
        break;
    default: break;
    }
    r.message = st.join(" ");
    r.data    = QVariant::fromValue(m_state);
    REPORT(r);
}

void Phrase::log_signal(const QString &signalName, const QVariant &data)
{
    Report r = make_report();
    r.category = Report::Category::Debug;
    r.message  = QString("signal: %1").arg(signalName);
    r.data     = data;
    REPORT(r);
}

Report Phrase::make_report() const
{
    Report r;
    r.timestamp = QDateTime::currentDateTime();
    r.source    = QString("%1/%2").arg(m_parentPath).arg(label());
    return r;
}

// ── Property accessors ────────────────────────────────────────────────────────

bool Phrase::after() const { return m_after; }

void Phrase::setAfter(bool newAfter)
{
    if (m_after == newAfter) return;
    m_after = newAfter;
    if (m_after)
        play();
    emit afterChanged();
}

ErrorEntry Phrase::lastError() const { return m_lastError; }

void Phrase::setLastError(const ErrorEntry &newLastError)
{
    if (m_lastError == newLastError) return;
    m_lastError = newLastError;
    error(m_lastError);
    if (m_lastError != NoError && m_finishOnError)
        finish(m_lastError);
    emit lastErrorChanged();
}

QString Phrase::title() const { return m_title; }

void Phrase::setTitle(const QString &newTitle)
{
    if (m_title == newTitle) return;
    m_title = newTitle;
    emit titleChanged();
}

QString Phrase::lyric() const { return m_lyric; }

void Phrase::setLyric(const QString &newLyric)
{
    if (m_lyric == newLyric) return;
    m_lyric = newLyric;
    emit lyricChanged();
}

bool Phrase::abortOn() const { return m_abortOn; }

void Phrase::setAbortOn(bool newAbortOn)
{
    if (m_abortOn == newAbortOn) return;
    m_abortOn = newAbortOn;
    if (m_abortOn)
        abort();
    emit abortOnChanged();
}

bool Phrase::finishOn() const { return m_finishOn; }

void Phrase::setFinishOn(bool newFinishOn)
{
    if (m_finishOn == newFinishOn) return;
    m_finishOn = newFinishOn;
    if (m_finishOn)
        finish();
    emit finishOnChanged();
}

bool Phrase::finishOnError() const { return m_finishOnError; }

void Phrase::setFinishOnError(bool newFinishOnError)
{
    if (m_finishOnError == newFinishOnError) return;
    m_finishOnError = newFinishOnError;
    emit finishOnErrorChanged();
}

bool Phrase::playing() const
{
    return m_state == Phrase::Playing || m_state == Phrase::Accompanying;
}

QString Phrase::tag() const { return m_tag; }

void Phrase::setTag(const QString &newTag)
{
    if (m_tag == newTag) return;
    if (!m_tag.isEmpty())
        Partitura::instance()->deregisterPhrase(m_tag);
    m_tag = newTag;
    if (!newTag.isEmpty())
        Partitura::instance()->registerPhrase(m_tag, this);
    emit tagChanged();
}
