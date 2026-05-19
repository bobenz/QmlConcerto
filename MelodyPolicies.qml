pragma Singleton
import QtQuick 2.15
import Concerto 1.0

// Built-in policy functions for Melody.activePolicies.
// Each policy is a function(phrases, melody) that walks the phrase list
// and attaches signal connections to implement the desired behaviour.
// Policies survive reset() and replay correctly — state is reset via
// melody.cleanup signal where needed.

QtObject {

    // Resolve Melody Dissonant the moment any child resolves Dissonant.
    readonly property var dissonantOnFirstError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === Phrase.Dissonant && melody.playing)
                        melody.finish(p.lastError)
                })
            })(phrases[i])
        }
    }

    // Abort the Melody the moment any child resolves Dissonant.
    readonly property var abortOnFirstError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === Phrase.Dissonant && melody.playing)
                        melody.abort()
                })
            })(phrases[i])
        }
    }

    // When any child resolves Dissonant, abort all other Playing/Accompanying
    // siblings. The Melody resolves via its own normal wiring.
    readonly property var abortSiblingsOnError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized !== Phrase.Dissonant) return
                    for (var j = 0; j < phrases.length; j++) {
                        var sibling = phrases[j]
                        if (sibling !== p && sibling.playing)
                            sibling.abort()
                    }
                })
            })(phrases[i])
        }
    }

    // Abort siblings AND resolve the Melody Dissonant on the first child error.
    // Equivalent to dissonantOnFirstError + abortSiblingsOnError.
    readonly property var oneDissonantAllAborted: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized !== Phrase.Dissonant || !melody.playing) return
                    for (var j = 0; j < phrases.length; j++) {
                        var sibling = phrases[j]
                        if (sibling !== p && sibling.playing)
                            sibling.abort()
                    }
                    melody.finish(p.lastError)
                })
            })(phrases[i])
        }
    }

    // Set melody.lastError only when it is currently NoError — preserve the
    // first error and ignore any subsequent ones.
    readonly property var keepFirstError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === Phrase.Dissonant
                            && melody.lastError === NoError)
                        melody.lastError = p.lastError
                })
            })(phrases[i])
        }
    }

    // Resolve Melody Dissonant only when ALL children have resolved Dissonant.
    // If any child resolves Consonant the condition can never be met; the
    // Melody resolves via its normal wiring instead.
    // Counter resets on melody.cleanup so the policy works across replays.
    readonly property var dissonantOnAllError: function(phrases, melody) {
        var dissonantCount = 0
        var total = phrases.length

        melody.cleanup.connect(function() { dissonantCount = 0 })

        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.state !== Phrase.Resolved) return
                    if (p.finalized === Phrase.Dissonant) {
                        dissonantCount++
                        if (dissonantCount === total && melody.playing)
                            melody.finish(p.lastError)
                    } else {
                        // Any non-Dissonant resolution means "not all errored"
                        dissonantCount = -(total + 1)
                    }
                })
            })(phrases[i])
        }
    }

    // Resolve Melody Consonant the moment any child resolves Consonant.
    readonly property var consonantOnFirstSuccess: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === Phrase.Consonant && melody.playing)
                        melody.finish()
                })
            })(phrases[i])
        }
    }
}
