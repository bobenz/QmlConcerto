import QtQuick 2.15
import QmlConcerto 1.0

Melody {
    id: root

    property int _resolvedCount: 0
    property var _watchers: []

    onEnter: {
        if (phrases.length === 0) {
            finish()
            return
        }
        _resolvedCount = 0
        _watchers = []
        // All phrases start simultaneously when the Chord enters Playing
        for (var i = 0; i < phrases.length; i++) {
            phrases[i].after = Qt.binding(function() { return root.state === Phrase.Playing })
            var fn = _makeWatcher(phrases[i])
            _watchers.push({ phrase: phrases[i], fn: fn })
            phrases[i].stateChanged.connect(fn)
        }
    }

    function _makeWatcher(phrase) {
        return function() {
            if (phrase.state !== Phrase.Resolved) return
            // Disconnect this watcher
            for (var i = 0; i < _watchers.length; i++) {
                if (_watchers[i].phrase === phrase) {
                    phrase.stateChanged.disconnect(_watchers[i].fn)
                    break
                }
            }
            _resolvedCount++
            if (_resolvedCount < phrases.length) return
            // All resolved — find first error if any
            var err = null
            for (var j = 0; j < phrases.length; j++) {
                if (phrases[j].finalized === Phrase.Dissonant) { err = phrases[j].lastError; break }
            }
            err !== null ? finish(err) : finish()
        }
    }
}
