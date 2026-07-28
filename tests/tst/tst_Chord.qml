import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Chord: parallel start, all-must-finish semantics, error propagation.
TestCase {
    name: "Chord"

    // ── Three-child chord ─────────────────────────────────────────────────────
    Chord {
        id: chord3
        Pause { id: c3p0 }
        Pause { id: c3p1 }
        Pause { id: c3p2 }
    }

    // ── Two-child chord for error tests ───────────────────────────────────────
    Chord {
        id: chord2
        Pause { id: c2p0 }
        Pause { id: c2p1 }
    }

    function cleanup() { chord3.reset(); chord2.reset() }

    // ── All children start simultaneously when Chord plays ────────────────────
    function test_01_parallelStart() {
        chord3.play()
        compare(c3p0.state, Phrase.Playing)
        compare(c3p1.state, Phrase.Playing)
        compare(c3p2.state, Phrase.Playing)
    }

    // ── Chord stays Playing until all children resolve ─────────────────────────
    function test_02_staysPlayingUntilAll() {
        chord3.play()
        c3p0.finish()
        compare(chord3.state, Phrase.Playing)   // still two children running
        c3p1.finish()
        compare(chord3.state, Phrase.Playing)   // one still running
        c3p2.finish()
        // Chord resolves via Qt.callLater (deferred to avoid abortOn reentrancy)
        tryCompare(chord3, "state",     Phrase.Resolved,  500)
        compare   (chord3.finalized,    Phrase.Consonant)
    }

    // ── Partial resolution does not finish Chord ──────────────────────────────
    function test_03_partialDoesNotFinish() {
        chord2.play()
        c2p0.finish()
        compare(chord2.state, Phrase.Playing)
        compare(c2p1.state,   Phrase.Playing)
    }

    // ── All Consonant → Chord Consonant ───────────────────────────────────────
    function test_04_allConsonant() {
        chord2.play()
        c2p0.finish()
        c2p1.finish()
        tryCompare(chord2, "finalized", Phrase.Consonant, 500)
    }

    // ── Dissonant child → error propagated to Chord.lastError ─────────────────
    function test_05_errorPropagation() {
        chord2.play()
        c2p0.finish(Errors.pause_timeout)
        // Chord still running (p1 not done yet)
        compare(chord2.state, Phrase.Playing)
        compare(chord2.lastError.code, Errors.pause_timeout.code)
    }

    // ── All children always run to completion, even after one errors ──────────
    // Chord resolves Consonant by default; the error is carried in lastError.
    // Use dissonantOnFirstError policy to get Dissonant finalization.
    function test_06_allRunToCompletion() {
        chord2.play()
        c2p0.finish(Errors.pause_timeout)
        compare(c2p1.state, Phrase.Playing)   // p1 still running!
        c2p1.finish()
        // Chord resolves via Qt.callLater
        tryCompare(chord2, "state",          Phrase.Resolved,           500)
        compare   (chord2.finalized,         Phrase.Consonant)          // Chord = Consonant
        compare   (chord2.lastError.code,    Errors.pause_timeout.code) // error in lastError
    }

    // ── Dissonant child error is carried in lastError; Chord finalized = Consonant
    function test_07_errorCarriedInLastError() {
        chord2.play()
        c2p0.finish()
        c2p1.finish(Errors.pause_timeout)
        // Chord resolves via Qt.callLater
        tryCompare(chord2, "finalized",      Phrase.Consonant,          500)
        compare   (chord2.lastError.code,    Errors.pause_timeout.code) // error recorded
    }

    // ── abort() on Chord ──────────────────────────────────────────────────────
    function test_08_abortChord() {
        chord3.play()
        chord3.abort()
        compare(chord3.state,     Phrase.Resolved)
        compare(chord3.finalized, Phrase.Aborted)
    }

    // ── reset() clears all children ───────────────────────────────────────────
    function test_09_reset() {
        chord2.play()
        c2p0.finish()
        chord2.reset()
        compare(chord2.state, Phrase.Silent)
        compare(c2p0.state,   Phrase.Silent)
        compare(c2p1.state,   Phrase.Silent)
    }

    // ── Chord can be replayed after reset ─────────────────────────────────────
    function test_10_replay() {
        chord2.play()
        c2p0.finish(); c2p1.finish()
        chord2.reset()
        chord2.play()
        compare(c2p0.state, Phrase.Playing)
        compare(c2p1.state, Phrase.Playing)
    }

    // ── Order of completion does not matter ───────────────────────────────────
    function test_11_reverseCompletionOrder() {
        chord3.play()
        c3p2.finish()
        compare(chord3.state, Phrase.Playing)
        c3p0.finish()
        compare(chord3.state, Phrase.Playing)
        c3p1.finish()
        // Chord resolves via Qt.callLater
        tryCompare(chord3, "finalized", Phrase.Consonant, 500)
    }
}
