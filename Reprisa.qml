import QtQuick 2.15
import Concerto 1.0

// Reprisa — loops a single child Phrase, resetting and replaying it
// until finishOn becomes true.
//
// Lifecycle:
//   • Starts the child when Reprisa enters Playing.
//   • finishOn is live: if it becomes true mid-iteration, the child is
//     aborted and Reprisa resolves Consonant immediately.
//   • If the child resolves Consonant and finishOn is true → done, Consonant.
//   • If the child resolves Consonant and finishOn is false → reset + replay.
//   • If the child resolves Dissonant → Reprisa stops, resolves Dissonant
//     with the child's lastError (fail-fast).
//   • If the child resolves Aborted → Reprisa resolves Aborted
//     (external abort or finishOn-triggered abort already handled).
//
// Usage:
//   Reprisa {
//       id: pollLoop
//       finishOn: sensor.valueReady
//       PollSensor { title: "Poll" }
//   }

Melody {
    id: root

    // Internal: tracks whether we triggered the abort ourselves (via finishOn)
    // so we can distinguish it from an external abort().
    property bool _finishing: false

    Component.onCompleted: {
        if (phrases.length !== 1) {
            console.warn("Reprisa: expected exactly 1 child phrase, got " + phrases.length);
            return;
        }

        const child = phrases[0];

        // Start child when Reprisa starts playing.
        child.after = Qt.binding(() => root.state === Phrase.Playing);

        // Live finishOn watcher — fires mid-iteration if condition is met.
        // Aborts the running child; resolution is then handled in finalizedChanged.
        root.finishOnChanged.connect(() => {
            if (!root.finishOn) return;
            if (root.state !== Phrase.Playing) return;

            if (   child.state === Phrase.Playing
                || child.state === Phrase.Accompanying) {
                root._finishing = true;
                child.abort();
                // Resolution flows through finalizedChanged below.
            } else if (child.state === Phrase.Resolved) {
                // Child already resolved this iteration — finishOn just became
                // true between the resolve and the next reset(). Finish cleanly.
                root.finish();
            }
        });

        // Child resolution handler — the heart of the loop.
        child.finalizedChanged.connect(() => {
            if (child.state !== Phrase.Resolved) return;

            if (child.finalized === Phrase.Dissonant) {
                // Fail-fast: propagate error upward.
                root.finish(child.lastError);

            } else if (child.finalized === Phrase.Aborted) {
                if (root._finishing) {
                    // We aborted the child because finishOn became true.
                    root._finishing = false;
                    root.finish();              // Consonant — condition satisfied
                } else {
                    // External abort() on Reprisa itself — propagate.
                    root.abort();
                }

            } else {
                // child.finalized === Phrase.Consonant
                if (root.finishOn) {
                    root.finish();              // Condition already met — stop.
                } else {
                    // Loop: reset and replay.
                    child.reset();
                    child.play();
                }
            }
        });
    }
}
