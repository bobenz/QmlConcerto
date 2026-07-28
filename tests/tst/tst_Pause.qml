import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Pause: timeout outcomes, finishOn outcomes, and error registration.
TestCase {
    name: "Pause"

    // ── Subjects ──────────────────────────────────────────────────────────────
    Pause { id: p1 }
    Pause { id: p2 }
    Pause { id: p3 }

    function cleanup() { p1.reset(); p2.reset(); p3.reset() }

    // ── pause_timeout is pre-registered ───────────────────────────────────────
    function test_01_pauseTimeoutErrorRegistered() {
        compare(Errors.pause_timeout.code,        -9001)
        compare(Errors.pause_timeout.source,      "Pause")
        verify(Errors.pause_timeout.description.length > 0)
        verify(Errors.pause_timeout.valid)
    }

    // ── pause_timeout text format ─────────────────────────────────────────────
    function test_02_pauseTimeoutText() {
        var txt = Errors.pause_timeout.text
        verify(txt.indexOf("Pause")   >= 0)
        verify(txt.indexOf("-9001")   >= 0)
    }

    // ── Pure delay: timeout with no finishOn → Consonant ─────────────────────
    function test_03_pureDelay() {
        p1.timeout = 30
        p1.play()
        compare(p1.state, Phrase.Playing)
        tryCompare(p1, "state", Phrase.Resolved, 500)
        compare(p1.finalized, Phrase.Consonant)
    }

    // ── finishOn already true at play() time → immediate Consonant ───────────
    function test_04_finishOnPreCondition() {
        p1.timeout  = 5000   // long timeout — should never fire
        p1.finishOn = true
        p1.play()
        compare(p1.state,     Phrase.Resolved)
        compare(p1.finalized, Phrase.Consonant)
    }

    // ── finishOn becomes true while Playing → Consonant ──────────────────────
    function test_05_finishOnDuringPlay() {
        p1.timeout = 5000
        p1.play()
        compare(p1.state, Phrase.Playing)
        p1.finishOn = true
        compare(p1.state,     Phrase.Resolved)
        compare(p1.finalized, Phrase.Consonant)
    }

    // ── Timeout with finishOn bound but not satisfied → Dissonant ────────────
    function test_06_timeoutWithFinishOnBound_isDissonant() {
        p2.timeout  = 30
        p2.finishOn = false   // bound but never true
        p2.play()
        tryCompare(p2, "state", Phrase.Resolved, 500)
        compare(p2.finalized,      Phrase.Dissonant)
        compare(p2.lastError.code, -9001)
    }

    // ── abort() while Playing → Aborted ──────────────────────────────────────
    function test_07_abortWhileWaiting() {
        p3.timeout = 5000
        p3.play()
        p3.abort()
        compare(p3.state,     Phrase.Resolved)
        compare(p3.finalized, Phrase.Aborted)
    }

    // ── Manual finish() while Playing → Consonant ────────────────────────────
    function test_08_manualFinish() {
        p1.play()   // no timeout, no finishOn — blocks indefinitely
        compare(p1.state, Phrase.Playing)
        p1.finish()
        compare(p1.state,     Phrase.Resolved)
        compare(p1.finalized, Phrase.Consonant)
    }

    // ── Manual finish(error) while Playing → Dissonant ───────────────────────
    function test_09_manualFinishError() {
        p1.play()
        p1.finish(Errors.pause_timeout)
        compare(p1.state,          Phrase.Resolved)
        compare(p1.finalized,      Phrase.Dissonant)
        compare(p1.lastError.code, -9001)
    }

    // ── Pause.finishOnBound: not bound before assignment ──────────────────────
    function test_10_finishOnBoundFlag() {
        compare(p1.finishOnBound, false)
        p1.finishOn = false     // binds the property
        compare(p1.finishOnBound, true)
    }

    // ── Pure-delay timeout (no finishOn bound) → Consonant even with timeout ──
    function test_11_pureDelayFinishOnBoundFalse() {
        p1.timeout = 30
        p1.play()
        compare(p1.finishOnBound, false)
        tryCompare(p1, "finalized", Phrase.Consonant, 500)
    }
}
