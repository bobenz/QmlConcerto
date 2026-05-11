#include "quote.h"
#include <QDebug>

// ──────────────────────────────────────────────────────────────────────────────
// Construction / destruction
// ──────────────────────────────────────────────────────────────────────────────

Quote::Quote(QObject *parent)
    : Phrase(parent)
{
    connect(this, &Quote::stateChanged, this, &Quote::onMyStateChanged);
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
    m_connError  = {};
}

// ──────────────────────────────────────────────────────────────────────────────
// Phrase virtual hooks
// ──────────────────────────────────────────────────────────────────────────────

bool Quote::_play()
{
    if (!m_source) {
        // No source — resolve immediately as Dissonant.
        warning("Quote has no source — resolving Dissonant");
        ErrorEntry nullErr;
        finish(nullErr);
        return false;
    }

    setState(m_source->state());
    m_source->play();
    return true;
}

// _abort(): forward to source if it is running; otherwise sync teardown.
// Phrase::abort() calls _abort(); if it returns true, transitions immediately.
// Source mirroring via onSourceStateChanged() will also fire — that is fine
// since _abort_complete() guards against double-resolution.
bool Quote::_abort()
{
    if (m_source && (m_source->state() == Phrase::Playing ||
                     m_source->state() == Phrase::Accompanying)) {
        m_source->abort();
        // Source will resolve; onSourceStateChanged mirrors the Aborted outcome
        // back via Phrase::abort() → _abort_complete(). Return true here so
        // Phrase::abort() also transitions Quote immediately — both Quote and
        // source end up Resolved/Aborted in the same call stack.
    }
    return true;
}

bool Quote::_reset()
{
    if (m_source)
        m_source->reset();
    return true;
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
}

void Quote::onMyStateChanged()
{
    if (!m_source) return;
    if (state() == Phrase::Resolved)
    {
        m_source->finish(m_source->lastError());

        if (finalized() == Phrase::Aborted)
            m_source->abort();
    }
}

void Quote::onSourceLastErrorChanged()
{
    setLastError(m_source->lastError());
}
