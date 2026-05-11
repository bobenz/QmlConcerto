#pragma once
#ifndef QUOTE_H
#define QUOTE_H

#include "phrase.h"

/**
 * @brief Quote — a transparent Phrase proxy that delegates its lifecycle to a
 *               source Phrase.
 *
 * Quote "quotes" another Phrase, taking full control over it:
 *
 *   Quote::play()   → source->play()
 *   Quote::abort()  → source->abort()
 *   source resolves → Quote mirrors the outcome via finish() / abort()
 *
 * State is kept in sync: every source state change is mirrored on Quote so
 * that listeners watching Quote.state / Quote.finalized see identical values.
 *
 * Typical QML usage
 * -----------------
 * @code
 * // Wrap a raw Phrase so it fits into a Sequence without duplication:
 *
 * Sequence {
 *     Quote { source: myGlobalCommand }  // re-plays the same command object
 *     CleanUp { }
 * }
 *
 * // Or re-expose a service command from another component:
 *
 * Quote {
 *     id: wrappedDispense
 *     source: cdmService.dispenseCommand
 *     after: sessionReady
 * }
 * @endcode
 *
 * Notes
 * -----
 * - If source is null when play() is called, Quote resolves immediately as
 *   Dissonant with an internal "null source" error.
 * - Changing source while Playing is a no-op (logged as a warning).
 * - reset() resets both Quote and source.
 * - report() signals from source are forwarded through Quote's own report()
 *   so they participate in the normal report-bubbling hierarchy.
 */
class Quote : public Phrase
{
    Q_OBJECT

    Q_PROPERTY(Phrase* source READ source WRITE setSource NOTIFY sourceChanged FINAL)

public:
    explicit Quote(QObject *parent = nullptr);
    ~Quote() override;

    Phrase *source() const;
    void setSource(Phrase *newSource);

signals:
    void sourceChanged();

protected:
    bool _play()  override;
    bool _abort() override;
    bool _reset() override;

private slots:
    void onSourceStateChanged();
    void onMyStateChanged();
    void onSourceLastErrorChanged();

private:
    void wireSource(Phrase *src);
    void unwireSource(Phrase *src);

    Phrase  *m_source     = nullptr;
    QMetaObject::Connection m_connState;
    QMetaObject::Connection m_connReport;
    QMetaObject::Connection m_connError;
};

#endif // QUOTE_H
