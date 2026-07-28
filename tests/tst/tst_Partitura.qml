import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for Partitura: tag-based registration/deregistration,
// key validation, and manual register/deregister API.
TestCase {
    name: "Partitura"

    // ── Phrases used for registration tests ───────────────────────────────────
    Pause { id: pA }
    Pause { id: pB }
    Pause { id: pC }

    // ── A phrase that self-registers via tag ──────────────────────────────────
    Pause { id: pTagged; tag: "tst_reg_phrase" }

    function cleanup() {
        // Clear tags and manual registrations used in tests
        pA.tag = ""
        pB.tag = ""
        pC.tag = ""
        Partitura.deregisterPhrase("tst_manual_a")
        Partitura.deregisterPhrase("tst_manual_b")
    }

    // ── tag auto-registers at creation time ───────────────────────────────────
    function test_01_tagAutoRegisters() {
        // pTagged was created with tag: "tst_reg_phrase"
        verify(Partitura.tst_reg_phrase !== null &&
               Partitura.tst_reg_phrase !== undefined)
    }

    // ── Partitura returns the exact phrase object ─────────────────────────────
    function test_02_returnsCorrectObject() {
        compare(Partitura.tst_reg_phrase, pTagged)
    }

    // ── Setting tag registers the phrase ─────────────────────────────────────
    function test_03_setTagRegisters() {
        pA.tag = "tst_pa_key"
        compare(Partitura.tst_pa_key, pA)
    }

    // ── Clearing tag deregisters the phrase ───────────────────────────────────
    function test_04_clearTagDeregisters() {
        pB.tag = "tst_pb_key"
        compare(Partitura.tst_pb_key, pB)
        pB.tag = ""
        // After deregistration the property returns null/undefined
        var val = Partitura.tst_pb_key
        verify(val === null || val === undefined)
    }

    // ── Invalid key (uppercase start) is rejected ────────────────────────────
    function test_05_invalidKeyUppercaseStart() {
        pC.tag = "InvalidKey"   // should be rejected (uppercase start)
        // Partitura should NOT have this key
        var val = Partitura.InvalidKey
        verify(val === null || val === undefined)
        pC.tag = ""
    }

    // ── Key with digits and underscores is valid ─────────────────────────────
    function test_06_validKeyWithUnderscoreDigit() {
        pC.tag = "tst_c_001"
        compare(Partitura.tst_c_001, pC)
        pC.tag = ""
    }

    // ── registerPhrase() manual API ───────────────────────────────────────────
    function test_07_manualRegister() {
        Partitura.registerPhrase("tst_manual_a", pA)
        compare(Partitura.tst_manual_a, pA)
    }

    // ── deregisterPhrase() manual API ────────────────────────────────────────
    function test_08_manualDeregister() {
        Partitura.registerPhrase("tst_manual_b", pB)
        Partitura.deregisterPhrase("tst_manual_b")
        var val = Partitura.tst_manual_b
        verify(val === null || val === undefined)
    }

    // ── Tag collision: second registration overwrites first ───────────────────
    function test_09_tagCollisionOverwrites() {
        pA.tag = "tst_collision"
        compare(Partitura.tst_collision, pA)
        pB.tag = "tst_collision"   // overwrites pA's registration
        compare(Partitura.tst_collision, pB)
        // cleanup
        pA.tag = ""
        pB.tag = ""
    }

    // ── Phrase can be accessed via Partitura while it is playing ──────────────
    function test_10_accessWhilePlaying() {
        pA.tag = "tst_playing_check"
        pA.play()
        compare(Partitura.tst_playing_check.state, Phrase.Playing)
        pA.finish()
        pA.reset()
        pA.tag = ""
    }
}
