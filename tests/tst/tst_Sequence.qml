import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Sequence: serial execution order, error propagation,
// Accompanying-advance, and reset.
//
// NOTE: Sequence starts the first child via Qt.callLater (on enter signal) and
// chains subsequent children via Qt.callLater (on exit). Every child-start and
// every Sequence-resolution check therefore uses tryCompare(…, 500).
TestCase {
    name: "Sequence"

    // ── Three-step sequence ───────────────────────────────────────────────────
    Sequence {
        id: seq3
        Pause { id: s3p0 }
        Pause { id: s3p1 }
        Pause { id: s3p2 }
    }

    // ── Two-step sequence used for error tests ────────────────────────────────
    Sequence {
        id: seq2
        Pause { id: s2p0 }
        Pause { id: s2p1 }
    }

    // ── Single-step sequence ──────────────────────────────────────────────────
    Sequence {
        id: seq1
        Pause { id: s1p0 }
    }

    // Reports go straight to the global ReportRouter now, not through a
    // per-object "report" signal — a catch-all ReportsReceiver observes them.
    ReportsReceiver { id: allReports }
    SignalSpy { id: reportSpy; target: allReports; signalName: "reportReceived" }

    function cleanup() {
        seq3.reset(); seq2.reset(); seq1.reset()
        reportSpy.clear()
    }

    // ── Only first child starts when Sequence plays ───────────────────────────
    function test_01_onlyFirstStartsOnPlay() {
        seq3.play()
        tryCompare(s3p0, "state", Phrase.Playing, 500)
        compare(s3p1.state, Phrase.Silent)
        compare(s3p2.state, Phrase.Silent)
    }

    // ── Serial order: p0 → p1 → p2 ───────────────────────────────────────────
    function test_02_serialOrder() {
        seq3.play()
        tryCompare(s3p0, "state", Phrase.Playing, 500)
        s3p0.finish()
        compare(s3p0.state, Phrase.Resolved)
        tryCompare(s3p1, "state", Phrase.Playing, 500)
        compare(s3p2.state, Phrase.Silent)
        s3p1.finish()
        compare(s3p1.state, Phrase.Resolved)
        tryCompare(s3p2, "state", Phrase.Playing, 500)
        s3p2.finish()
        compare(s3p2.state, Phrase.Resolved)
        tryCompare(seq3, "state",     Phrase.Resolved,  500)
        compare   (seq3.finalized,    Phrase.Consonant)
    }

    // ── All Consonant → Sequence Consonant ───────────────────────────────────
    function test_03_allConsonantResult() {
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.finish()
        tryCompare(s2p1, "state", Phrase.Playing, 500)
        s2p1.finish()
        tryCompare(seq2, "finalized", Phrase.Consonant, 500)
    }

    // ── Dissonant child propagates error to Sequence.lastError ────────────────
    function test_04_errorPropagation() {
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.finish(Errors.pause_timeout)
        compare(seq2.lastError.code, Errors.pause_timeout.code)
    }

    // ── Sequence continues to next child after Dissonant child ────────────────
    function test_05_continuesAfterDissonant() {
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.finish(Errors.pause_timeout)
        // p1 must have started despite p0 being Dissonant
        tryCompare(s2p1, "state", Phrase.Playing, 500)
    }

    // ── Last child Dissonant → Sequence Dissonant ────────────────────────────
    function test_06_lastDissonantPropagatesToSequence() {
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.finish()                          // p0 OK
        tryCompare(s2p1, "state", Phrase.Playing, 500)
        s2p1.finish(Errors.pause_timeout)      // p1 fails
        tryCompare(seq2, "finalized",      Phrase.Dissonant,           500)
        compare   (seq2.lastError.code,    Errors.pause_timeout.code)
    }

    // ── finishOnError: true → Sequence aborts on first child error ───────────
    function test_07_finishOnError() {
        seq2.finishOnError = true
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.finish(Errors.pause_timeout)
        // finishOnError triggers setLastError → finish() synchronously via keepLastError
        compare(seq2.state,     Phrase.Resolved)
        compare(seq2.finalized, Phrase.Dissonant)
        seq2.finishOnError = false
    }

    // ── Sequence aborted from outside ────────────────────────────────────────
    function test_08_abortFromOutside() {
        seq3.play()
        tryCompare(s3p0, "state", Phrase.Playing, 500)
        seq3.abort()
        compare(seq3.state,     Phrase.Resolved)
        compare(seq3.finalized, Phrase.Aborted)
    }

    // ── Accompanying child: next child starts immediately ────────────────────
    function test_09_accompanyingAdvance() {
        seq2.play()
        tryCompare(s2p0, "state", Phrase.Playing, 500)
        s2p0.accompany()          // p0 goes Accompanying — p1 should start now
        compare(s2p0.state, Phrase.Accompanying)
        tryCompare(s2p1, "state", Phrase.Playing, 500)   // p1 started
        // p0 still alive in background
        compare(s2p0.playing, true)
    }

    // ── reset() clears Sequence and all children ─────────────────────────────
    function test_10_reset() {
        seq3.play()
        tryCompare(s3p0, "state", Phrase.Playing, 500)
        s3p0.finish()
        tryCompare(s3p1, "state", Phrase.Playing, 500)
        seq3.reset()
        compare(seq3.state, Phrase.Silent)
        compare(s3p0.state, Phrase.Silent)
        compare(s3p1.state, Phrase.Silent)
        compare(s3p2.state, Phrase.Silent)
    }

    // ── Single-child sequence ────────────────────────────────────────────────
    function test_11_singleChild() {
        seq1.play()
        tryCompare(s1p0, "state", Phrase.Playing, 500)
        s1p0.finish()
        tryCompare(seq1, "state",     Phrase.Resolved,  500)
        compare   (seq1.finalized,    Phrase.Consonant)
    }

    // ── Reports from a child Phrase are observable via ReportsReceiver ────────
    function test_12_childReportsObservable() {
        seq3.play()
        tryCompare(s3p0, "state", Phrase.Playing, 500)
        reportSpy.clear()   // discard state-change reports from play()
        s3p0.info("step 0 running")
        compare(reportSpy.count, 1)
    }

    // ── Sequence can be replayed after reset ──────────────────────────────────
    function test_13_replay() {
        seq1.play()
        tryCompare(s1p0, "state", Phrase.Playing, 500)
        s1p0.finish()
        tryCompare(seq1, "state", Phrase.Resolved, 500)
        seq1.reset()
        seq1.play()
        tryCompare(s1p0, "state", Phrase.Playing, 500)
        s1p0.finish()
        tryCompare(seq1, "finalized", Phrase.Consonant, 500)
    }
}
