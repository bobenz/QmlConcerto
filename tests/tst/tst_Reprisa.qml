import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Reprisa: loop-until-finishOn, error stops loop,
// abort stops loop, abortOn interrupts.
//
// NOTE: The child phrase manages its own reset between iterations.
// We use Pause with finishOn: true so it resolves Consonant immediately
// (pre-condition skip), giving Reprisa a completed child in each iteration.
// For multi-iteration tests we count iterations via onEnter.
TestCase {
    name: "Reprisa"

    // ── Single-iteration: finishOn already true → loop exits after one run ────
    Reprisa {
        id: rep1
        finishOn: true
        Pause { id: rp1; finishOn: true }
    }

    // ── Dissonant stops loop ──────────────────────────────────────────────────
    Reprisa {
        id: repErr
        Pause { id: rpErr }
    }

    // ── abortOn interrupts the Reprisa ────────────────────────────────────────
    property bool abortTrigger: false
    Reprisa {
        id: repAbortOn
        abortOn: abortTrigger
        Pause { id: rpAbortOn }
    }

    // ── Child Aborted → Reprisa Aborted ──────────────────────────────────────
    Reprisa {
        id: repChildAbort
        Pause { id: rpChildAbort }
    }

    // ── Invalid child count guard ─────────────────────────────────────────────
    Reprisa {
        id: repNoChild
        // intentionally empty — should warn and resolve with error
    }

    function cleanup() {
        rep1.reset()
        repErr.reset()
        abortTrigger = false; repAbortOn.reset()
        repChildAbort.reset()
        repNoChild.reset()
    }

    // ── finishOn=true from start → resolves Consonant after one iteration ─────
    function test_01_finishOnTrue_resolvesConsonant() {
        rep1.play()
        compare(rep1.state,     Phrase.Resolved)
        compare(rep1.finalized, Phrase.Consonant)
    }

    // ── Child Dissonant → Reprisa Dissonant ──────────────────────────────────
    function test_02_childDissonant_reprisaDissonant() {
        repErr.play()
        rpErr.finish(Errors.pause_timeout)
        compare(repErr.state,          Phrase.Resolved)
        compare(repErr.finalized,      Phrase.Dissonant)
        compare(repErr.lastError.code, Errors.pause_timeout.code)
    }

    // ── Child Aborted → Reprisa Aborted ──────────────────────────────────────
    function test_03_childAborted_reprisaAborted() {
        repChildAbort.play()
        rpChildAbort.abort()
        compare(repChildAbort.state,     Phrase.Resolved)
        compare(repChildAbort.finalized, Phrase.Aborted)
    }

    // ── abortOn: fires → Reprisa Aborted (mid-iteration) ─────────────────────
    function test_04_abortOn() {
        repAbortOn.play()
        compare(rpAbortOn.state, Phrase.Playing)
        abortTrigger = true         // triggers abortOn
        compare(repAbortOn.state,     Phrase.Resolved)
        compare(repAbortOn.finalized, Phrase.Aborted)
    }

    // ── abort() on Reprisa stops the loop ────────────────────────────────────
    function test_05_abortReprisa() {
        repErr.play()
        compare(rpErr.state, Phrase.Playing)
        repErr.abort()
        compare(repErr.state,     Phrase.Resolved)
        compare(repErr.finalized, Phrase.Aborted)
    }

    // ── Invalid (0-child) Reprisa resolves with error ─────────────────────────
    function test_06_invalidChildCount() {
        repNoChild.play()
        compare(repNoChild.state,     Phrase.Resolved)
        compare(repNoChild.finalized, Phrase.Dissonant)
    }

    // ── Reprisa can be replayed after reset ───────────────────────────────────
    function test_07_replay() {
        // cleanup() runs after each test, which clears finishOn via _reset_complete.
        // Restore before each play (pre-condition fires immediately → Consonant).
        rep1.finishOn = true
        rep1.play()
        compare(rep1.finalized, Phrase.Consonant)
        rep1.reset()
        rep1.finishOn = true
        rep1.play()
        compare(rep1.finalized, Phrase.Consonant)
    }

    // ── finishOn checked only after Consonant — not mid-iteration ────────────
    // We verify that setting finishOn while child is Playing does not
    // interrupt the running iteration (abortOn would be needed for that).
    property bool midIterFinish: false
    Reprisa {
        id: repMidIter
        finishOn: midIterFinish
        Pause { id: rpMid }
    }

    function test_08_finishOnCheckedAfterConsonant() {
        repMidIter.play()
        compare(rpMid.state, Phrase.Playing)
        midIterFinish = true       // condition becomes true while child running
        // Reprisa must NOT interrupt the running iteration
        compare(rpMid.state, Phrase.Playing)
        // Now finish the child → Reprisa checks finishOn → true → exits
        rpMid.finish()
        compare(repMidIter.finalized, Phrase.Consonant)
    }

    function cleanupTestCase() {
        repMidIter.reset()
        midIterFinish = false
    }
}
