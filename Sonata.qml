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

    property Phrase preludio: Phrase { }
    property Phrase coda:     Phrase { }
    readonly property Phrase aria: phrases[0]

    // Pending outcome recorded after preludio/aria, delivered after coda.
    property var _pendingFinalized: Phrase.None
    property var _pendingError:     null

    Component.onCompleted: {
        if (phrases.length !== 1) {
            console.warn("Sonata: expected exactly 1 aria (body child), got "
                         + phrases.length);
            return;
        }

        // ── Preludio ──────────────────────────────────────────────────────────
        preludio.after = Qt.binding(() => root.state === Phrase.Playing);

        preludio.finalizedChanged.connect(() => {
            if (preludio.state !== Phrase.Resolved) return;

            if (preludio.finalized === Phrase.Consonant) {
                aria.play();
            } else {
                // Dissonant or Aborted — skip aria, go straight to coda.
                root._pendingFinalized = preludio.finalized;
                root._pendingError     = preludio.finalized === Phrase.Dissonant
                                         ? preludio.lastError
                                         : null;
                _runCoda();
            }
        });

        // ── Aria ──────────────────────────────────────────────────────────────
        // Driven imperatively from preludio's handler — not via `after` binding —
        // so it only ever starts after a clean Consonant preludio resolution.

        aria.finalizedChanged.connect(() => {
            if (aria.state !== Phrase.Resolved) return;

            root._pendingFinalized = aria.finalized;
            root._pendingError     = aria.finalized === Phrase.Dissonant
                                     ? aria.lastError
                                     : null;
            _runCoda();
        });

        // ── Coda ──────────────────────────────────────────────────────────────
        coda.finalizedChanged.connect(() => {
            if (coda.state !== Phrase.Resolved) return;

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
