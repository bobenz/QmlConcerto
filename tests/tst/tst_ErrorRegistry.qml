import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for ErrorRegistry and Errors context property.
// Uses error codes in the -88xxx range to avoid collisions with production errors.
TestCase {
    name: "ErrorRegistry"

    // ── Register test errors once before all tests run ────────────────────────
    function initTestCase() {
        ErrorRegistry.declare({ name: "tst_alpha", source: "TST", code: -88001,
                                 description: "Alpha test error" })
        ErrorRegistry.declare({ name: "tst_beta",  source: "TST", code: -88002,
                                 description: "Beta test error"  })
        ErrorRegistry.declare({ name: "tst_gamma", source: "OTH", code: -88003,
                                 description: "Gamma test error" })
    }

    // ── pause_timeout is pre-registered by the framework ─────────────────────
    function test_01_pauseTimeoutPreregistered() {
        verify(ErrorRegistry.contains(-9001))
        verify(ErrorRegistry.containsName("pause_timeout"))
    }

    // ── declared error is accessible via Errors property map ─────────────────
    function test_02_errorsSymbolicAccess() {
        var e = Errors.tst_alpha
        verify(e !== undefined && e !== null)
        compare(e.code,        -88001)
        compare(e.source,      "TST")
        compare(e.description, "Alpha test error")
        verify(e.valid)
    }

    // ── ErrorEntry.text format: "[source] (code) description" ────────────────
    function test_03_textFormat() {
        var txt = Errors.tst_alpha.text
        verify(txt.indexOf("TST")              >= 0)
        verify(txt.indexOf("-88001")           >= 0)
        verify(txt.indexOf("Alpha test error") >= 0)
    }

    // ── lookup(code) returns the correct entry ────────────────────────────────
    function test_04_lookupByCode() {
        var e = ErrorRegistry.lookup(-88001)
        compare(e.code,   -88001)
        compare(e.source, "TST")
    }

    // ── lookup(code, source) — unambiguous composite-key lookup ──────────────
    function test_05_lookupByCodeAndSource() {
        var e = ErrorRegistry.lookup(-88001, "TST")
        compare(e.code,   -88001)
        compare(e.source, "TST")
    }

    // ── lookupByName(name) ────────────────────────────────────────────────────
    function test_06_lookupByName() {
        var e = ErrorRegistry.lookupByName("tst_beta")
        compare(e.code,        -88002)
        compare(e.description, "Beta test error")
    }

    // ── contains(code) ────────────────────────────────────────────────────────
    function test_07_containsByCode() {
        verify(ErrorRegistry.contains(-88001))
        verify(!ErrorRegistry.contains(-99999))   // not registered
    }

    // ── containsName(name) ────────────────────────────────────────────────────
    function test_08_containsByName() {
        verify(ErrorRegistry.containsName("tst_alpha"))
        verify(!ErrorRegistry.containsName("no_such_error"))
    }

    // ── describe(code) returns a non-empty string ─────────────────────────────
    function test_09_describe() {
        var desc = ErrorRegistry.describe(-88001)
        verify(desc.length > 0)
        verify(desc.indexOf("Alpha") >= 0)
    }

    // ── ErrorEntry.valid is false for an unregistered name ───────────────────
    function test_10_unknownEntryNotValid() {
        var e = ErrorRegistry.lookup(-77777)   // not registered
        // lookup returns an empty/invalid entry
        verify(!e.valid)
    }

    // ── Errors.tst_gamma from a different source ──────────────────────────────
    function test_11_differentSource() {
        var e = Errors.tst_gamma
        compare(e.code,   -88003)
        compare(e.source, "OTH")
    }

    // ── finish(Errors.tst_alpha) resolves Phrase Dissonant correctly ──────────
    Pause { id: errPhrase }

    function test_12_useInFinish() {
        errPhrase.play()
        errPhrase.finish(Errors.tst_alpha)
        compare(errPhrase.state,          Phrase.Resolved)
        compare(errPhrase.finalized,      Phrase.Dissonant)
        compare(errPhrase.lastError.code, -88001)
        errPhrase.reset()
    }
}
