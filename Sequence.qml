import QtQuick 2.15
import Concerto 1.0
Melody {
    id: root
    property Phrase first
    onEnter:Qt.callLater(() =>{if (root.first) root.first.play()})
    Component.onCompleted: {
        if (phrases.length === 0) return;
        for (let i = 0; i < phrases.length; i++) {
            let current = phrases[i];
            if(i === 0) root.first = current
            let next = (i < phrases.length - 1) ? phrases[i + 1] : null;
            // Abort propagation
            current.abortOn = Qt.binding(() => root.finalized === Phrase.Aborted);
            // Error propagation
            current.onExit.connect(() => {
                if (current.finalized === Phrase.Dissonant)
                    root.lastError = current.lastError;
            });
            if (next !== null) {
                // Chain to next on any resolution except Aborted
                current.onExit.connect(() => {
                    if (current.finalized === Phrase.Consonant || current.finalized === Phrase.Dissonant)
                        Qt.callLater(() => next.play());
                });
                // Chain to next when entering Accompanying
                current.onStateChanged.connect(() => {
                    if (current.state === Phrase.Accompanying)
                        Qt.callLater(() => next.play());
                });
            } else {
                // Last phrase — finish the sequence
                current.onExit.connect(() => {
                    switch (current.finalized) {
                        case Phrase.Consonant:  Qt.callLater(() => root.finish());                   break;
                        case Phrase.Dissonant:  Qt.callLater(() => root.finish(current.lastError));  break;
                        case Phrase.Aborted:    Qt.callLater(() => root.abort());                    break;
                    }
                });
                current.onStateChanged.connect(() => {
                    if (current.state === Phrase.Accompanying)
                        Qt.callLater(() => root.finish());
                });
            }
        }
        runPolicies()
    }
}