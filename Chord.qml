import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root
    // keepLastError accumulates child errors in root.lastError without stopping the chord.
    // root.finish() (no arg) resolves Consonant; preserved lastError is still observable.
    activePolicies: [MelodyPolicies.keepLastError]

    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);

            // Abort all children whenever root resolves (policy-triggered or external).
            currentPhrase.abortOn = Qt.binding(() => root.state === Phrase.Resolved);

            // When any phrase exits, check if all have finalized; finish if so.
            // Use Qt.callLater to defer root.finish() until after setState(Resolved)
            // fires on the triggering child — avoids reentrancy via abortOn bindings.
            currentPhrase.onExit.connect(() => {
                for (let j = 0; j < phrases.length; j++) {
                    if (phrases[j].finalized === Phrase.None) return;
                }
                Qt.callLater(() => { if (root.playing) root.finish(); });
            });
        }

        runPolicies()
    }
}
