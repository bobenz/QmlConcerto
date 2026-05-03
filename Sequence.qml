import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root


    finishOn: phrases.length > 0 && (
            phrases[phrases.length - 1].state === Phrase.Resolved ||
            (root.finishOnError && root.lastError.code !== Errors.no_error.code)
        )

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