import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root
    // Finish when every phrase has resolved
    finishOn:{
        for (let i = 0; i < phrases.length; i++) {
            if (phrases[i].state !== Phrase.Resolved) return false;
        }
        return true;
    }
    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            // All phrases start simultaneously when root starts
            currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);

            // Abort all playing phrases when root is aborted
            currentPhrase.abortOn = Qt.binding(() =>
                root.state === Phrase.Resolved &&
                root.finalized === Phrase.Aborted
            );

            // Error propagation
            currentPhrase.onFinalizedChanged.connect(() => {
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    root.lastError = currentPhrase.lastError;
                }
            });
        }

        runPolicies()
    }
}