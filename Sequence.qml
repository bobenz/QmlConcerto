import QtQuick 2.15

// Sequence.qml
Melody {
    id: root

    function _play() {
        if (phrases.length === 0) {
            finish(Concerto.Consonant);
            return;
        }

    }

    Component.onCompleted:
    {

        // The Walk: Assigning the "after" conditions
        for (let i = 0; i < phrases.length; ++i) {
            if (i === 0) {
                // The first phrase is ready immediately
                phrases[i].after = Qt.binding(() => state === Concerto.Playing);
            } else {
                // Each subsequent phrase waits for the predecessor
                let prev = phrases[i - 1];

                // We use a binding or a manual assignment
                // to trigger when the state hits Resolved
                phrases[i].after = Qt.binding(() => prev.state === Concerto.Resolved);
            }
        }
        let lastIndex = phrases.length - 1;
                let lastPhrase = phrases[lastIndex];

                // When the last phrase is Resolved, the entire Melody is Resolved
                state = Qt.binding(() => {
                    return lastPhrase.state === Concerto.Resolved
                           ? Concerto.Resolved
                           : state; // Keep current state (likely Playing) otherwise
                });

                // Optional: Also propagate the "Finalized" (Success/Error) status
                finalized = Qt.binding(() => {
                    return lastPhrase.state === Concerto.Resolved
                           ? lastPhrase.finalized
                           : finalized;
                });

    }
}
