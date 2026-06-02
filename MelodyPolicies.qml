pragma Singleton
import QtQuick 2.15
//import Concerto 1.0

// Built-in policy functions for Melody.activePolicies.
// Each policy is a function(phrases, melody) that walks the phrase list
// and attaches signal connections to implement the desired behaviour.
// Policies survive reset() and replay correctly — state is reset via
// melody.cleanup signal where needed.

QtObject {

        readonly property int none:0   // 0
        readonly property int aborted:1   // 1
        readonly property int dissonant:2 // 2
        readonly property int consonant :3 // 3

    // Resolve Melody Dissonant the moment any child resolves Dissonant.
    readonly property var dissonantOnFirstError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === dissonant && melody.playing)
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
                    if (p.finalized === dissonant && melody.playing)
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
                    if (p.finalized !== dissonant) return
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
                    if (p.finalized !== dissonant || !melody.playing) return
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

    // Always overwrite melody.lastError with the most recent child error.
    // Use as Chord's default so the final error reflects the last Dissonant child.
    readonly property var keepLastError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === dissonant)
                        melody.lastError = p.lastError
                })
            })(phrases[i])
        }
    }

    // Set melody.lastError only when it is currently NoError (code===0) — preserve
    // the first error and ignore any subsequent ones.
    readonly property var keepFirstError: function(phrases, melody) {
        for (var i = 0; i < phrases.length; i++) {
            (function(p) {
                p.finalizedChanged.connect(function() {
                    if (p.finalized === dissonant
                            && melody.lastError.code === 0)  // NoError has code=0
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
                    if (p.finalized === None) return  // spurious signal guard (reset)
                    if (p.finalized === dissonant) {
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
                    if (p.finalized === consonant && melody.playing)
                        melody.finish()
                })
            })(phrases[i])
        }
    }
}
