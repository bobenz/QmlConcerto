import QtQuick 2.15
import QtTest 1.12
import Concerto 1.0
//import "qrc:/concerto"
// Tests for Cadenza: first-to-finish wins; losers are aborted;
// winner outcome propagates; external abort does not count as win.
//
// NOTE: Cadenza resolves one QML binding cycle after a child finishes, so
// checks on Cadenza's own state use tryCompare(…, 200) rather than compare.
TestCase {
    name: "Cadenza"

    Cadenza {
        id: cad3
        Pause { id: ca3p0 }
        Pause { id: ca3p1 }
        Pause { id: ca3p2 }
    }

    Cadenza {
        id: cad2
        Pause { id: ca2p0 }
        Pause { id: ca2p1 }
    }

    function cleanup() { cad3.reset(); cad2.reset() }

    // ── All children start simultaneously ─────────────────────────────────────
    function test_01_parallelStart() {
        cad3.play()
        compare(ca3p0.state, Phrase.Playing)
        compare(ca3p1.state, Phrase.Playing)
        compare(ca3p2.state, Phrase.Playing)
    }

    // ── First to finish wins (Consonant) ──────────────────────────────────────
    function test_02_firstWinsConsonant() {
        cad3.play()
        ca3p1.finish()
        tryCompare(cad3, "state",     Phrase.Resolved, 200)
        compare   (cad3.finalized,    Phrase.Consonant)
    }

    // ── Losing children are aborted once Cadenza resolves ────────────────────
    function test_03_losersAborted() {
        cad3.play()
        ca3p1.finish()
        tryCompare(cad3, "state",    Phrase.Resolved, 200)
        compare(ca3p0.finalized,     Phrase.Aborted)
        compare(ca3p2.finalized,     Phrase.Aborted)
    }

    // ── Winner Dissonant → Cadenza Dissonant ─────────────────────────────────
    function test_04_winnerDissonantPropagates() {
        cad2.play()
        ca2p0.finish(Errors.pause_timeout)
        tryCompare(cad2, "state",        Phrase.Resolved,  200)
        compare(cad2.finalized,          Phrase.Dissonant)
        compare(cad2.lastError.code,     Errors.pause_timeout.code)
    }

    // ── After winner resolves, loser is aborted and winner outcome stands ─────
    function test_05_loserAbortedWinnerOutcomeStands() {
        cad2.play()
        ca2p0.finish(Errors.pause_timeout)
        tryCompare(cad2, "state",    Phrase.Resolved, 200)
        compare(cad2.finalized,      Phrase.Dissonant)
        compare(ca2p1.finalized,     Phrase.Aborted)
    }

    // ── External abort does not count as a win — race continues ──────────────
    function test_06_externalAbortNotAWin() {
        cad3.play()
        ca3p0.abort()
        compare(cad3.state,  Phrase.Playing)
        compare(ca3p1.state, Phrase.Playing)
        compare(ca3p2.state, Phrase.Playing)
    }

    // ── After external abort, next winner resolves Cadenza ───────────────────
    function test_07_raceAfterExternalAbort() {
        cad3.play()
        ca3p0.abort()
        ca3p2.finish()
        tryCompare(cad3, "state",   Phrase.Resolved,  200)
        compare(cad3.finalized,     Phrase.Consonant)
        compare(ca3p1.finalized,    Phrase.Aborted)
    }

    // ── abort() on Cadenza stops the whole race ───────────────────────────────
    function test_08_abortCadenza() {
        cad3.play()
        cad3.abort()
        compare(cad3.state,     Phrase.Resolved)
        compare(cad3.finalized, Phrase.Aborted)
    }

    // ── reset() clears all children ───────────────────────────────────────────
    function test_09_reset() {
        cad2.play()
        ca2p0.finish()
        tryCompare(cad2, "state", Phrase.Resolved, 200)
        cad2.reset()
        compare(cad2.state,  Phrase.Silent)
        compare(ca2p0.state, Phrase.Silent)
        compare(ca2p1.state, Phrase.Silent)
    }

    // ── Cadenza timeout-race pattern: winning Pause → loser aborted ───────────
    function test_10_timeoutRacePattern() {
        cad2.play()
        ca2p1.finish()
        tryCompare(cad2, "state",    Phrase.Resolved, 200)
        compare(ca2p0.finalized,     Phrase.Aborted)
        compare(cad2.finalized,      Phrase.Consonant)
    }
}
