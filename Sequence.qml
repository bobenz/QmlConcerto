import QtQuick 2.15
import QmlConcerto 1.0

Melody {
    id: root

    onEnter: {
        if (phrases.length === 0) {
            finish()
            return
        }
        // First phrase plays when Sequence enters Playing
        phrases[0].after = Qt.binding(function() { return root.state === Phrase.Playing })
        // Each subsequent phrase plays when the previous one resolves
        for (var i = 1; i < phrases.length; i++) {
            let prev = phrases[i - 1]
            phrases[i].after = Qt.binding(function() { return prev.state === Phrase.Resolved })
        }
    }

    Connections {
        target: phrases.length > 0 ? phrases[phrases.length - 1] : null
        function onStateChanged() {
            var last = phrases[phrases.length - 1]
            if (last.state !== Phrase.Resolved) return
            last.finalized === Phrase.Dissonant ? finish(last.lastError) : finish()
        }
    }
}
