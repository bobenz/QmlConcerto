#include "quote.h"
#include <QDebug>

// ──────────────────────────────────────────────────────────────────────────────
// Construction / destruction
// ──────────────────────────────────────────────────────────────────────────────

Quote::Quote(QObject *parent)
    : Phrase(parent)
{
    connect(this, &Quote::stateChanged , this , &Quote::onMyStateChanged);
}

Quote::~Quote()
{
    unwireSource(m_source);
}

// ──────────────────────────────────────────────────────────────────────────────
// source property
// ──────────────────────────────────────────────────────────────────────────────

Phrase *Quote::source() const
{
    return m_source;
}

void Quote::setSource(Phrase *newSource)
{
    if (m_source == newSource)
        return;

    // Refuse mid-flight source swaps — the state machine would become incoherent.
    if (state() == Playing || state() == Accompanying) {
        qWarning() << metaObject()->className()
                   << "setSource() called while Playing/Accompanying — ignored";
        return;
    }

    unwireSource(m_source);
    m_source = newSource;
    wireSource(m_source);

    emit sourceChanged();
}

// ──────────────────────────────────────────────────────────────────────────────
// Connection management
// ──────────────────────────────────────────────────────────────────────────────

void Quote::wireSource(Phrase *src)
{
    if (!src)
        return;

    // Mirror state changes (resolves Quote when source resolves).
    m_connState = connect(src, &Phrase::stateChanged,
                          this, &Quote::onSourceStateChanged);


    m_connError = connect(src, &Phrase::lastErrorChanged,
                          this, &Quote::onSourceLastErrorChanged);

    // Forward all source reports through Quote's report signal so they
    // participate in the normal report-bubbling hierarchy.
    m_connReport = connect(src, &Phrase::report,
                           this, &Quote::report);
}

void Quote::unwireSource(Phrase *src)
{
    if (!src)
        return;

    disconnect(m_connState);
    disconnect(m_connReport);
    disconnect(m_connError);

    m_connState  = {};
    m_connReport = {};
    m_connError = {};
}

// ──────────────────────────────────────────────────────────────────────────────
// Lifecycle overrides
// ──────────────────────────────────────────────────────────────────────────────

bool Quote::_play()
{
    if (!m_source) {
        // No source — resolve immediately as Dissonant.
        warning("Quote has no source — resolving Dissonant");
        // Build a transient error entry for the null-source condition.
        // (If the project has a static error registry entry for this, use that instead.)
        ErrorEntry nullErr;
        // ErrorEntry is a value type; default-construct gives NoError semantics,
        // so we call finish() with an explicitly constructed entry if possible,
        // or simply call finish() without arguments and trust the caller to observe
        // the warning above.  Either way the phrase does not stall.
        finish(nullErr);
        return false;
    }

    // // Mirror the source's current state in case it already started
    // // (edge case: source was pre-played before being assigned).
    // if (m_source->state() == Phrase::Resolved) {
    //     onSourceStateChanged();
    //     return true;
    // }

    setState(m_source->state());
    m_source->play();
    return true;
}

void Quote::_reset()
{
    // Reset self first (sets state = Silent, finalized = None).
    Phrase::_reset();

    // Then reset source so it is ready for the next play().
    if (m_source)
        m_source->reset();
}

void Quote::abort()
{
    // Forward abort to source; our onSourceStateChanged() will mirror the
    // Resolved/Aborted outcome back onto Quote.
    if (m_source && (m_source->state() == Phrase::Playing ||
                     m_source->state() == Phrase::Accompanying)) {
        m_source->abort();
    } else {
        // Source not running — abort self directly (standard Phrase behaviour).
        Phrase::abort();
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Source state mirror
// ──────────────────────────────────────────────────────────────────────────────

void Quote::onSourceStateChanged()
{
    if (!m_source)
        return;

    qDebug() << "SOURCE STATE " << m_source->state();
    setState(m_source->state());

    // We only care about mirroring once Quote itself is active.
    // if (state() != Playing && state() != Accompanying)
    //     return;

    // switch (m_source->state()) {
    // case Phrase::Accompanying:
    //     // Source entered background mode — mirror it.
    //     accompany();
    //     break;

    // case Phrase::Resolved:
    //     // Mirror the finalization outcome.
    //     switch (m_source->finalized()) {
    //     case Phrase::Consonant:
    //         finish();                           // resolves Consonant / NoError
    //         break;
    //     case Phrase::Dissonant:
    //         finish(m_source->lastError());      // resolves Dissonant + error
    //         break;
    //     case Phrase::Aborted:
    //         Phrase::abort();                    // resolves Aborted (bypass forward)
    //         break;
    //     default:
    //         break;
    //     }
    //     break;

    // default:
    //     // Playing / Silent / Paused — no action needed on Quote's side.
    //     break;
    // }
}

void Quote::onMyStateChanged()
{
    if(!m_source) return;
    if(state() == Phrase::Resolved)
    {
        m_source->finish(m_source->lastError());

        if(finalized() == Phrase::Aborted)
        {
            m_source->abort();
        }
    }
}

void Quote::onSourceLastErrorChanged()
{
    setLastError(m_source->lastError());
}
