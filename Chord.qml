
Melody {
    id: root

    function _play() {
        if (phrases.length === 0) {
            state = Concerto.Resolved;
            finalized = Concerto.Consonant;
            return;
        }
    }

    Component.onCompleted: {
        if (phrases.length === 0) return;

        // 1. The Attack: All phrases start simultaneously when the Chord plays
        for (let i = 0; i < phrases.length; ++i) {
            phrases[i].after = Qt.binding(() => state === Concerto.Playing);
        }

        // 2. The Resolution: The Chord is Resolved only when EVERY phrase is Resolved
        state = Qt.binding(() => {
            let allResolved = true;
            for (let i = 0; i < phrases.length; ++i) {
                if (phrases[i].state !== Concerto.Resolved) {
                    allResolved = false;
                    break;
                }
            }
            return allResolved ? Concerto.Resolved : state;
        });

        // 3. The Finalization: If any phrase is Dissonant, the Chord is Dissonant
        finalized = Qt.binding(() => {
            let hasDiscord = false;
            let allResolved = true;

            for (let i = 0; i < phrases.length; ++i) {
                if (phrases[i].state === Concerto.Resolved) {
                    if (phrases[i].finalized === Concerto.Dissonant) {
                        hasDiscord = true;
                    }
                } else {
                    allResolved = false;
                }
            }

            if (!allResolved) return finalized;
            return hasDiscord ? Concerto.Dissonant : Concerto.Consonant;
        });
    }
}
