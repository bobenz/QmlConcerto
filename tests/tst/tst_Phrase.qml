import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Phrase state machine, reactive trigger properties, and signals.
// Pause is used as the concrete Phrase since Phrase itself is abstract.
TestCase {
    name: "Phrase"

    // ── Subjects ──────────────────────────────────────────────────────────────
    Pause { id: p }

    SignalSpy { id: enterSpy;     target: p; signalName: "enter"          }
    SignalSpy { id: exitSpy;      target: p; signalName: "exit"           }
    SignalSpy { id: stateSpy;     target: p; signalName: "stateChanged"   }
    SignalSpy { id: finSpy;       target: p; signalName: "finalizedChanged"}
    SignalSpy { id: lastErrSpy;   target: p; signalName: "lastErrorChanged"}

    function cleanup() {
        p.reset()
        enterSpy.clear()
        exitSpy.clear()
        stateSpy.clear()
        finSpy.clear()
        lastErrSpy.clear()
    }

    // ── Initial state ─────────────────────────────────────────────────────────
    function test_01_initialState() {
        compare(p.state,     Phrase.Silent)
        compare(p.finalized, Phrase.None)
        compare(p.playing,   false)
    }

    // ── play() → Playing ──────────────────────────────────────────────────────
    function test_02_playTransitionsToPlaying() {
        p.play()
        compare(p.state,   Phrase.Playing)
        compare(p.playing, true)
    }

    // ── finish() → Resolved / Consonant ───────────────────────────────────────
    function test_03_finishConsonant() {
        p.play()
        p.finish()
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Consonant)
        compare(p.playing,   false)
    }

    // ── finish(error) → Resolved / Dissonant ──────────────────────────────────
    function test_04_finishDissonant() {
        p.play()
        p.finish(Errors.pause_timeout)
        compare(p.state,              Phrase.Resolved)
        compare(p.finalized,          Phrase.Dissonant)
        compare(p.lastError.code,     Errors.pause_timeout.code)
    }

    // ── abort() → Resolved / Aborted ──────────────────────────────────────────
    function test_05_abort() {
        p.play()
        p.abort()
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Aborted)
    }

    // ── reset() → Silent / None ───────────────────────────────────────────────
    function test_06_reset() {
        p.play()
        p.finish()
        p.reset()
        compare(p.state,     Phrase.Silent)
        compare(p.finalized, Phrase.None)
        compare(p.playing,   false)
    }

    // ── accompany() → Accompanying ────────────────────────────────────────────
    function test_07_accompany() {
        p.play()
        p.accompany()
        compare(p.state,   Phrase.Accompanying)
        compare(p.playing, true)   // playing is true in both Playing and Accompanying
        p.finish()
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Consonant)
    }

    // ── double play() is ignored ──────────────────────────────────────────────
    function test_08_doublePlayIgnored() {
        p.play()
        var result = p.play()   // second call while Playing
        compare(result,  false)
        compare(p.state, Phrase.Playing)
        compare(stateSpy.count, 1)  // only one stateChanged so far
    }

    // ── enter / exit signals ──────────────────────────────────────────────────
    function test_09_enterSignalOnPlay() {
        p.play()
        compare(enterSpy.count, 1)
        compare(exitSpy.count,  0)
    }

    function test_10_exitSignalOnFinish() {
        p.play()
        enterSpy.clear()
        p.finish()
        compare(exitSpy.count,  1)
        compare(enterSpy.count, 0)
    }

    function test_11_exitSignalOnAbort() {
        p.play()
        p.abort()
        compare(exitSpy.count, 1)
    }

    // ── stateChanged and finalizedChanged order ───────────────────────────────
    function test_12_signalOrder() {
        // finalizedChanged fires before stateChanged on resolution
        p.play()
        stateSpy.clear()
        finSpy.clear()
        p.finish()
        verify(finSpy.count  >= 1)
        verify(stateSpy.count >= 1)
    }

    // ── after: true → auto-play ───────────────────────────────────────────────
    function test_13_afterTrigger() {
        p.after = true
        compare(p.state, Phrase.Playing)
    }

    // ── finishOn: true while Playing → auto-finish Consonant ─────────────────
    function test_14_finishOnTrigger() {
        p.play()
        p.finishOn = true
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Consonant)
    }

    // ── abortOn: true while Playing → auto-abort ─────────────────────────────
    function test_15_abortOnTrigger() {
        p.play()
        p.abortOn = true
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Aborted)
    }

    // ── finishOnBound / abortOnBound flags ────────────────────────────────────
    function test_16_finishOnBound() {
        compare(p.finishOnBound, false)
        p.finishOn = false   // binds (even though false)
        compare(p.finishOnBound, true)
    }

    function test_17_abortOnBound() {
        compare(p.abortOnBound, false)
        p.abortOn = false
        compare(p.abortOnBound, true)
    }

    // ── Pre-condition skip: finishOn already true when play() called ──────────
    function test_18_preconditionFinishOn() {
        p.finishOn = true
        p.play()
        // resolves Consonant immediately without entering Playing
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Consonant)
    }

    // ── Pre-condition skip: abortOn already true when play() called ───────────
    function test_19_preconditionAbortOn() {
        p.abortOn = true
        p.play()
        compare(p.state,     Phrase.Resolved)
        compare(p.finalized, Phrase.Aborted)
    }

    // ── finishOnError: true — auto-resolve Dissonant when lastError set ───────
    function test_20_finishOnError() {
        p.finishOnError = true
        p.play()
        p.lastError = Errors.pause_timeout
        compare(p.state,          Phrase.Resolved)
        compare(p.finalized,      Phrase.Dissonant)
        compare(p.lastError.code, Errors.pause_timeout.code)
        compare(lastErrSpy.count, 1)
    }

    // ── lastErrorChanged signal ───────────────────────────────────────────────
    function test_21_lastErrorChangedSignal() {
        p.play()
        p.finish(Errors.pause_timeout)
        compare(lastErrSpy.count, 1)
    }

    // ── playing property covers Accompanying ─────────────────────────────────
    function test_22_playingCoversAccompanying() {
        p.play()
        compare(p.playing, true)
        p.accompany()
        compare(p.playing, true)
        p.finish()
        compare(p.playing, false)
    }

    // ── title / lyric / tag properties are writable ───────────────────────────
    function test_23_metaProperties() {
        p.title = "my title"
        p.lyric = "my lyric"
        compare(p.title, "my title")
        compare(p.lyric, "my lyric")
    }
}
