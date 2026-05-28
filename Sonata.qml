import QtQuick 2.15
import Concerto 1.0

// Sonata — structured three-part composition: Preludio → Aria → Coda
//
// • preludio        — setup phrase (property); runs first
// • aria            — the single child declared in the body; the main work
// • coda            — teardown phrase (property); always runs last, regardless of outcome
//
// Resolution rules (coda always runs):
//   • Preludio Dissonant → skip aria, run coda, resolve Dissonant (preludio error)
//   • Preludio Aborted   → skip aria, run coda, resolve Aborted
//   • Aria Dissonant     → run coda, resolve Dissonant (aria error)
//   • Aria Aborted       → run coda, resolve Aborted
//   • Aria Consonant     → run coda, resolve Consonant
//   • Coda Dissonant     → overrides everything, resolve Dissonant (coda error)
//   • Coda Aborted       → resolve Aborted
//
// Usage:
//   Sonata {
//       preludio: OpenDevice  { }
//       coda:     CloseDevice { }
//
//       DoMainWork { }   // ← aria: no id required
//   }

Melody {
    id: root

    property Phrase preludio: Phrase {}
    property Phrase coda:     Phrase {}
    property Phrase aria

    // Pending outcome recorded after preludio/aria, delivered after coda.
    property var _pendingFinalized: Phrase.None
    property var _pendingError:     null

    Component.onCompleted: {
        // ── Aria ──────────────────────────────────────────────────────────────
        // Assign aria once at construction so son.aria is never null.
        if (phrases.length > 0) {
            aria = phrases[0];

            aria.finalizedChanged.connect(() => {
                if (aria.finalized === Phrase.None) return;  // spurious signal guard (reset)

                root._pendingFinalized = aria.finalized;
                root._pendingError     = aria.finalized === Phrase.Dissonant
                                         ? aria.lastError
                                         : null;
                _runCoda();
            });
        }

        // ── Preludio ──────────────────────────────────────────────────────────
        preludio.after = Qt.binding(() => root.state === Phrase.Playing);

        preludio.exit.connect(() => {
            if (preludio.finalized === Phrase.Consonant) {
                // Start aria after preludio is fully Resolved (Qt.callLater defers
                // until after setState(Resolved) fires on preludio).
                if (aria) Qt.callLater(aria.play);
            } else {
                // Dissonant or Aborted — skip aria, go straight to coda.
                root._pendingFinalized = preludio.finalized;
                root._pendingError     = preludio.finalized === Phrase.Dissonant
                                         ? preludio.lastError
                                         : null;
                _runCoda();
            }
        });

        // ── Reset handler ─────────────────────────────────────────────────────
        // preludio and coda are property Phrase, not phrases[] list children,
        // so Melody._reset() won't reach them — reset them manually here.
        root.cleanup.connect(() => {
            preludio.reset();
            coda.reset();
            root._pendingFinalized = Phrase.None;
            root._pendingError     = null;
        });

        // ── Coda ──────────────────────────────────────────────────────────────
        coda.finalizedChanged.connect(() => {
            if (coda.finalized === Phrase.None) return;  // spurious signal guard (reset)

            if (coda.finalized === Phrase.Dissonant) {
                // Coda failure overrides everything.
                root.finish(coda.lastError);
            } else if (coda.finalized === Phrase.Aborted) {
                root.abort();
            } else {
                // Deliver the pending outcome from preludio / aria.
                if (root._pendingFinalized === Phrase.Dissonant) {
                    root.finish(root._pendingError);
                } else if (root._pendingFinalized === Phrase.Aborted) {
                    root.abort();
                } else {
                    root.finish();
                }
            }
        });
    }

    // Resets and plays coda. Always called — never skipped.
    function _runCoda() {
        coda.reset();
        coda.play();
    }
}
