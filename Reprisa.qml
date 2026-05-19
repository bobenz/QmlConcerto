import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root
    activePolicies: [MelodyPolicies.dissonantOnFirstError]

    // Alias the root as 'reprisa' so children can access it
    // consistently even if the QML hierarchy shifts.
    readonly property alias reprisa: root

    Component.onCompleted: {
        if (phrases.length !== 1) {
            console.warn("Reprisa: expected exactly 1 child phrase");
            root.finish("Invalid child count");
            return;
        }
        const child = phrases[0];

        // Ensure the child has a reference to this Reprisa instance.
        // We inject it dynamically so any child can use 'reprisa.propertyName'
        if (child.hasOwnProperty("reprisa")) {
            child.reprisa = root;
        }

        child.after = Qt.binding(() => root.state === Phrase.Playing);

        // Policies run first so their finalizedChanged connections fire before
        // the loop-control handler below (connection order determines fire order).
        runPolicies()

        child.finalizedChanged.connect(() => {
            if (child.state !== Phrase.Resolved) return;

            if (child.finalized === Phrase.Aborted) {
                root.abort();
            } else {
                // Consonant or Dissonant: check exit condition, then loop or finish.
                // Error propagation is handled entirely by activePolicies.
                if (root.finishOn) {
                    root.finish();
                } else {
                    Qt.callLater(() => { if (root.playing) child.play(); })
                }
            }
        });
    }
}