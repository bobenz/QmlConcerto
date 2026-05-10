#include "pause.h"

// ---------------------------------------------------------------------------
// Static error — self-registers with ErrorRegistry on first use.
// ---------------------------------------------------------------------------
ErrorEntry Pause::ERR_PAUSE_TIMEOUT(
    "pause_timeout",          // symbolic name  → Errors.pause_timeout
    "Pause",                  // source tag
    -9001,                    // error code
    "Pause timed out"         // human-readable description
    );

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------
Pause::Pause(QObject *parent)
    : Phrase(parent)
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &Pause::onTimeout);
}

// ---------------------------------------------------------------------------
// Property accessors
// ---------------------------------------------------------------------------
int Pause::timeout() const
{
    return m_timeout;
}

void Pause::setTimeout(int ms)
{
    if (m_timeout == ms)
        return;
    m_timeout = ms;
    emit timeoutChanged();
}

// ---------------------------------------------------------------------------
// _play() — enter Playing and wait.
//
//   • If timeout > 0, arm the single-shot timer.
//   • finishOn is handled entirely by the Phrase base class — when the bound
//     QML expression evaluates to true, the framework calls finish() for us.
//     Nothing extra is needed here.
// ---------------------------------------------------------------------------
bool Pause::_play()
{
    info(QString("Pause started (timeout=%1 ms)").arg(m_timeout));

    if (m_timeout > 0)
        m_timer.start(m_timeout);

    return true;
    // _play() returns; the phrase remains in Playing until:
    //   a) finishOn becomes true  → Phrase base calls finish()     → Consonant
    //   b) onTimeout() fires      → we call finish(ERR_PAUSE_TIMEOUT) → Dissonant
    //   c) abort() is called      → standard Phrase base behaviour  → Aborted
}

// ---------------------------------------------------------------------------
// Timeout handler
// ---------------------------------------------------------------------------
void Pause::onTimeout()
{
    // Guard: may already be Resolved if finishOn and timeout race.
    if (state() != Phrase::Playing && state() != Phrase::Accompanying)
        return;

    warning("Pause timed out");
    error(ERR_PAUSE_TIMEOUT);
    finish(ERR_PAUSE_TIMEOUT);
}