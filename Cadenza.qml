import QtQuick 2.15
import Concerto 1.0

// Race — parallel Melody that resolves as soon as ONE child resolves.
// The winning child's finalization (Consonant/Dissonant) and lastError
// propagate to the Race itself. All other still-active children are aborted.
//
// Semantics:
//   • All children start simultaneously when Race starts playing.
//   • The first child to reach Resolved triggers resolution of Race.
//   • Remaining children in Playing or Accompanying state are aborted.
//   • A child that was already Resolved before the winner fires is ignored
//     (it either tied or was already done — first finalizedChanged wins).
//   • Race itself resolves with the winner's finalized + lastError.

Melody {
    id: root

    Component.onCompleted: {
        if (phrases.length === 0) return;

        // Guard: only the first winner is processed.
        let raceOver = false;

        for (let i = 0; i < phrases.length; i++) {
            let p = phrases[i];

            // All children fire when root enters Playing.
            p.after = Qt.binding(() => root.state === Phrase.Playing);

            // Each child watches for resolution and volunteers as winner.
            p.finalizedChanged.connect(() => {
                if (p.state !== Phrase.Resolved) return;  // spurious signal guard
                if (raceOver) return;                      // another child already won
                raceOver = true;

                // Propagate winner's outcome to root.
                root.lastError = p.lastError;              // NoError if Consonant

                // Abort all losers that are still active.
                for (let j = 0; j < phrases.length; ++j) {
                    let loser = phrases[j];
                    if (loser === p) continue;             // skip the winner
                    if (   loser.state === Phrase.Playing
                        || loser.state === Phrase.Accompanying) {
                        loser.abort();
                    }
                }

                // Resolve root with the same outcome as the winner.
                if (p.finalized === Phrase.Consonant) {
                    root.finish();                         // Consonant
                } else if (p.finalized === Phrase.Dissonant) {
                    root.finish(p.lastError);              // Dissonant
                } else {
                    // Winner was itself Aborted (external abort()) —
                    // treat as if it never won; wait for next resolver.
                    raceOver = false;
                }
            });
        }
    }
}
