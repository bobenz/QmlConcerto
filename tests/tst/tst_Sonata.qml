import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Sonata: three-part framing (Preludio → Aria → Coda),
// coda-always-runs guarantee, and resolution rules.
TestCase {
    name: "Sonata"

    // ── Main sonata: preludio + aria (body child) + coda ─────────────────────
    Sonata {
        id: son

        preludio: Pause { id: preP }
        coda:     Pause { id: codP }

        Pause { id: ariaP }   // phrases[0] → accessible as son.aria
    }

    // ── Second sonata for independent tests ───────────────────────────────────
    Sonata {
        id: son2

        preludio: Pause { id: pre2P }
        coda:     Pause { id: cod2P }

        Pause { id: aria2P }
    }

    function cleanup() { son.reset(); son2.reset() }

    // ── aria property returns the body child ──────────────────────────────────
    function test_01_ariaProperty() {
        verify(son.aria !== null)
        compare(son.aria, ariaP)
    }

    // ── Normal flow: Preludio → Aria → Coda, all Consonant ───────────────────
    function test_02_normalFlow() {
        son.play()

        // preludio starts first
        compare(preP.state,  Phrase.Playing)
        compare(ariaP.state, Phrase.Silent)
        compare(codP.state,  Phrase.Silent)

        preP.finish()   // preludio Consonant → aria starts (Qt.callLater → async)
        compare(preP.state,  Phrase.Resolved)
        tryCompare(ariaP, "state", Phrase.Playing, 500)
        compare(codP.state,  Phrase.Silent)

        ariaP.finish()  // aria Consonant → coda starts

        compare(ariaP.state, Phrase.Resolved)
        compare(codP.state,  Phrase.Playing)

        codP.finish()   // coda Consonant → Sonata Consonant

        compare(son.state,     Phrase.Resolved)
        compare(son.finalized, Phrase.Consonant)
    }

    // ── Coda always runs when Aria is Dissonant ───────────────────────────────
    function test_03_codaRunsOnAriaDis() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.finish(Errors.pause_timeout)   // aria Dissonant

        // coda must still run
        compare(codP.state, Phrase.Playing)
        codP.finish()

        compare(son.finalized,      Phrase.Dissonant)
        compare(son.lastError.code, Errors.pause_timeout.code)
    }

    // ── Coda always runs when Aria is Aborted ─────────────────────────────────
    function test_04_codaRunsOnAriaAborted() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.abort()

        compare(codP.state, Phrase.Playing)
        codP.finish()

        compare(son.finalized, Phrase.Aborted)
    }

    // ── Preludio Dissonant → Aria is skipped → Coda still runs ───────────────
    function test_05_preludioDissonantSkipsAria() {
        son2.play()
        pre2P.finish(Errors.pause_timeout)   // preludio fails

        // aria must be skipped (stays Silent)
        compare(aria2P.state, Phrase.Silent)

        // coda must still run
        compare(cod2P.state, Phrase.Playing)
        cod2P.finish()

        compare(son2.finalized,      Phrase.Dissonant)
        compare(son2.lastError.code, Errors.pause_timeout.code)
    }

    // ── Preludio Aborted → Aria skipped → Coda runs → Sonata Aborted ─────────
    function test_06_preludioAbortedSkipsAria() {
        son2.play()
        pre2P.abort()

        compare(aria2P.state, Phrase.Silent)
        compare(cod2P.state,  Phrase.Playing)
        cod2P.finish()

        compare(son2.finalized, Phrase.Aborted)
    }

    // ── Coda Dissonant overrides Aria Consonant ───────────────────────────────
    function test_07_codaErrorOverridesAria() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.finish()   // aria OK

        compare(codP.state, Phrase.Playing)
        codP.finish(Errors.pause_timeout)   // coda fails — overrides aria outcome

        compare(son.finalized,      Phrase.Dissonant)
        compare(son.lastError.code, Errors.pause_timeout.code)
    }

    // ── Coda Aborted overrides Aria Consonant ─────────────────────────────────
    function test_08_codaAbortedOverridesAria() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.finish()
        codP.abort()

        compare(son.finalized, Phrase.Aborted)
    }

    // ── son.aria is readable from outside (no id required) ───────────────────
    function test_09_ariaReadableFromOutside() {
        son.play()
        preP.finish()
        // son.aria.state is observable from outside (aria starts async via Qt.callLater)
        tryCompare(son.aria, "state", Phrase.Playing, 500)
        ariaP.finish()
        compare(son.aria.state, Phrase.Resolved)
    }

    // ── reset() resets all three parts ────────────────────────────────────────
    function test_10_reset() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.finish()
        codP.finish()
        son.reset()
        compare(son.state,   Phrase.Silent)
        compare(preP.state,  Phrase.Silent)
        compare(ariaP.state, Phrase.Silent)
        compare(codP.state,  Phrase.Silent)
    }

    // ── Sonata can be replayed ────────────────────────────────────────────────
    function test_11_replay() {
        son.play()
        preP.finish()
        tryCompare(ariaP, "state", Phrase.Playing, 500)   // aria starts async
        ariaP.finish()
        codP.finish()
        son.reset()
        son.play()
        compare(preP.state, Phrase.Playing)
    }
}
