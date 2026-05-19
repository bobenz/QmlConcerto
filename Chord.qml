import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root
    // keepLastError accumulates the final error across all children so that
    // root.finish(root.lastError) below propagates the last Dissonant result.
    activePolicies: [MelodyPolicies.keepLastError]

    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);

            // Abort all children whenever root resolves (policy-triggered or external).
            currentPhrase.abortOn = Qt.binding(() => root.state === Phrase.Resolved);

            // When any phrase exits, check if all have resolved; finish if so.
            currentPhrase.onExit.connect(() => {
                for (let j = 0; j < phrases.length; j++) {
                    if (phrases[j].state !== Phrase.Resolved) return;
                }
                if (root.playing) root.finish(root.lastError);
            });
        }

        runPolicies()
    }
}
