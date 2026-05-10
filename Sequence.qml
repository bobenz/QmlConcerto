import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root

    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];
            let prevPhrase = (i > 0) ? phrases[i - 1] : null;

            // Start condition
            if (i === 0) {
                currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);
            } else {
                // Only start if previous phrase resolved AND was NOT aborted
                currentPhrase.after = Qt.binding(() =>
                    prevPhrase.state === Phrase.Resolved &&
                    prevPhrase.finalized !== Phrase.Aborted
                );
            }

            // Abort propagation: if root is aborted, abort the current (playing) phrase
            currentPhrase.abortOn = Qt.binding(() => root.state === Phrase.Resolved &&
                                                      root.finalized === Phrase.Aborted);

            // Error propagation
            currentPhrase.onFinalizedChanged.connect(() => {
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    root.lastError = currentPhrase.lastError;
                }
            });
        }

        // Melody finishes when last phrase resolves
        let last = phrases[phrases.length - 1];
        root.finishOn = Qt.binding(() =>
            last.state === Phrase.Resolved &&
            last.finalized !== Phrase.Aborted
        );
    }
}