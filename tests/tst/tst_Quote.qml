import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Quote: transparent proxy lifecycle delegation, safety guards.
TestCase {
    name: "Quote"

    // ── Subjects ──────────────────────────────────────────────────────────────
    // src has an explicit title so its report source ("/QuoteReportSrc") is
    // unambiguous — ReportRouter is a single process-wide bus shared by every
    // Phrase instance in this test binary.
    Pause { id: src; title: "QuoteReportSrc" }
    Quote { id: q; source: src }

    Pause { id: src2  }
    Quote { id: q2; source: src2 }

    Quote { id: qNull }   // source left null for null-source tests

    // Quote no longer forwards/re-emits its source's reports under its own
    // identity — reports go straight to the global ReportRouter carrying the
    // emitting Phrase's own source path. Observe them via ReportsReceiver.
    ReportsReceiver { id: srcReports; sourceFilter: "QuoteReportSrc" }
    SignalSpy { id: reportSpy; target: srcReports; signalName: "reportReceived" }

    function cleanup() {
        src.reset();   q.reset()
        src2.reset();  q2.reset()
        qNull.reset()
        reportSpy.clear()
    }

    // ── play() on Quote delegates to source ───────────────────────────────────
    function test_01_playDelegatesToSource() {
        q.play()
        compare(src.state, Phrase.Playing)
        compare(q.state,   Phrase.Playing)
    }

    // ── source Consonant → Quote Consonant ────────────────────────────────────
    function test_02_mirrorsConsonant() {
        q.play()
        src.finish()
        compare(src.state,   Phrase.Resolved)
        compare(q.state,     Phrase.Resolved)
        compare(q.finalized, Phrase.Consonant)
    }

    // ── source Dissonant → Quote Dissonant with same error ────────────────────
    function test_03_mirrorsDissonant() {
        q.play()
        src.finish(Errors.pause_timeout)
        compare(q.state,          Phrase.Resolved)
        compare(q.finalized,      Phrase.Dissonant)
        compare(q.lastError.code, Errors.pause_timeout.code)
    }

    // ── source Aborted → Quote Aborted ────────────────────────────────────────
    function test_04_mirrorsAborted() {
        q.play()
        src.abort()
        compare(q.state,     Phrase.Resolved)
        compare(q.finalized, Phrase.Aborted)
    }

    // ── abort() on Quote propagates to source ─────────────────────────────────
    function test_05_abortDelegatesToSource() {
        q.play()
        q.abort()
        compare(src.state,   Phrase.Resolved)
        compare(src.finalized, Phrase.Aborted)
        compare(q.state,     Phrase.Resolved)
        compare(q.finalized, Phrase.Aborted)
    }

    // ── null source → Dissonant immediately ───────────────────────────────────
    function test_06_nullSource() {
        qNull.play()
        compare(qNull.state,     Phrase.Resolved)
        compare(qNull.finalized, Phrase.Dissonant)
    }

    // ── reset() resets both Quote and source ──────────────────────────────────
    function test_07_resetBoth() {
        q.play()
        src.finish()
        compare(q.state,   Phrase.Resolved)
        compare(src.state, Phrase.Resolved)
        q.reset()
        compare(q.state,   Phrase.Silent)
        compare(src.state, Phrase.Silent)
    }

    // ── source accompany() → Quote enters Accompanying ────────────────────────
    function test_08_accompanyMirror() {
        q.play()
        src.accompany()
        compare(src.state, Phrase.Accompanying)
        compare(q.state,   Phrase.Accompanying)
        compare(q.playing, true)
        src.finish()
        compare(q.state,     Phrase.Resolved)
        compare(q.finalized, Phrase.Consonant)
    }

    // ── source swap rejected while Playing ────────────────────────────────────
    function test_09_swapGuardWhilePlaying() {
        q2.play()
        compare(q2.state, Phrase.Playing)
        var original = q2.source
        q2.source = null   // should be rejected (no-op + warning)
        compare(q2.source, original)
    }

    // ── source can be changed while Silent ────────────────────────────────────
    function test_10_swapWhileSilent() {
        // q2 is Silent — swap is allowed
        var newSrc = src
        q2.source = newSrc
        compare(q2.source, newSrc)
    }

    // ── reports from the wrapped source are observable via ReportsReceiver ───
    function test_11_sourceReportsObservable() {
        q.play()
        reportSpy.clear()   // discard state-change reports from play()
        src.info("hello from source")
        compare(reportSpy.count, 1)
    }

    // ── source already Resolved when play() called → mirrors immediately ──────
    function test_12_alreadyResolvedSource() {
        src.play()
        src.finish()
        compare(src.state, Phrase.Resolved)
        // Now play the Quote whose source is already Resolved/Consonant
        q.play()
        compare(q.state,     Phrase.Resolved)
        compare(q.finalized, Phrase.Consonant)
    }
}
