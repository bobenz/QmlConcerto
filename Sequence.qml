import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root





    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            // Use 'let' so each iteration has its own scope
            let currentPhrase = phrases[i];

            if (i === 0) {
                // First phrase starts when the Melody (root) starts playing
                currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);
            } else {
                // Subsequent phrases depend on the previous one
                let previousPhrase = phrases[i - 1];
                currentPhrase.after = Qt.binding(() => previousPhrase.state === Phrase.Resolved);
            }

            var last = phrases[phrases.length - 1]
            root.finishOn = Qt.binding(function() {
                return last.state === Phrase.Resolved ||
                       (root.finishOnError && last.finalized === Phrase.Dissonant)
            })

            // Connect signal (note the plural 'phrases')
            currentPhrase.onFinalizedChanged.connect(() => {
                // Your logic here, for example:
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    root.lastError = currentPhrase.lastError;
                }
            });
        }
    }


}