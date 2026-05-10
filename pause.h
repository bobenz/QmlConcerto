#ifndef PAUSE_H
#define PAUSE_H
#pragma once

#include "phrase.h"

#include <QTimer>

// ---------------------------------------------------------------------------
// Pause — a Phrase that stays in Playing until finishOn becomes true
//         OR an optional timeout elapses.
//
// QML usage:
//
//   Pause {
//       title:     "Wait for card"
//       timeout:   5000                        // ms; 0 = no timeout (default)
//       finishOn:  idc.state === Phrase.Resolved
//   }
//
// Outcomes:
//   • finishOn becomes true  → finish()  → Consonant  (normal)
//   • timeout fires first    → finish()  → Dissonant  (ERR_PAUSE_TIMEOUT)
//   • abort() called         → Aborted               (standard Phrase behaviour)
//
// Notes:
//   • finishOn is inherited from Phrase and wired by the framework; no extra
//     C++ code is required for the condition-based path.
//   • Setting timeout: 0 (default) disables the timer — the phrase waits
//     indefinitely until finishOn fires or abort() is called externally.
//   • The timer is single-shot and is stopped/destroyed on resolution to
//     prevent stale callbacks.
// ---------------------------------------------------------------------------

class Pause : public Phrase
{
    Q_OBJECT

    // Timeout in milliseconds.  0 = no timeout.
    Q_PROPERTY(int timeout READ timeout WRITE setTimeout NOTIFY timeoutChanged)

public:
    explicit Pause(QObject *parent = nullptr);
    ~Pause() override = default;

    int  timeout() const;
    void setTimeout(int ms);

signals:
    void timeoutChanged();

protected:
    bool _play() override;

private slots:
    void onTimeout();

private:
    int    m_timeout { 0 };
    QTimer m_timer;

    // Error declared once at class scope; self-registers with ErrorRegistry.
    static ErrorEntry ERR_PAUSE_TIMEOUT;
};
#endif // PAUSE_H
