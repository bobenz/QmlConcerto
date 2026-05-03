import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root

    // Logic: The Chord is finished when all phrases are Resolved.
    // Every() returns true if every element in the array matches the condition.
    finishOn: {
        if (!phrases || phrases.length === 0) return true;

        let allResolved = true;
        for (let i = 0; i < phrases.length; ++i) {
            if (phrases[i].state !== Phrase.Resolved) {
                allResolved = false;
                break;
            }
        }
        return allResolved;
    }
    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            // 1. All phrases start simultaneously when the root starts
            currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);

            // 2. Monitor for errors
            currentPhrase.onFinalizedChanged.connect(() => {
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    // Capture the error so the Melody component can handle failure
                    root.lastError = currentPhrase.lastError;
                }
            });
        }
    }
}