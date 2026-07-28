import QtQuick 2.15
import QtTest 1.2
import Concerto 1.0

// Tests for free-style Melody: custom after/finishOn bindings,
// DAG fan-out/fan-in, conditional branching, and runPolicies() on bare Melody.
TestCase {
    name: "FreestyleMelody"

    // ── DAG: A → (B ∥ C) → D ────────────────────────────────────────────────
    //  stepA starts when flow plays.
    //  stepB and stepC start in parallel after stepA resolves.
    //  stepD starts after BOTH stepB and stepC resolve.
    //  flow finishes when stepD resolves.
    Melody {
        id: flow

        Pause {
            id: stepA
            after: flow.state === Phrase.Playing
        }
        Pause {
            id: stepB
            after: stepA.state === Phrase.Resolved
        }
        Pause {
            id: stepC
            after: stepA.state === Phrase.Resolved
        }
        Pause {
            id: stepD
            after: stepB.state === Phrase.Resolved &&
                   stepC.state === Phrase.Resolved
        }

        finishOn: stepD.state === Phrase.Resolved

        Component.onCompleted: runPolicies()
    }

    // ── Conditional branching: check → update or skip ────────────────────────
    // checkStep runs first; if it resolves Dissonant → updateStep runs;
    // if it resolves Consonant → skipStep resolves immediately (pre-condition).
    // flow2 finishes when either updateStep or skipStep resolves.
    Melody {
        id: flow2

        Pause {
            id: checkStep
            after: flow2.state === Phrase.Playing
        }
        Pause {
            id: updateStep
            after: checkStep.state === Phrase.Resolved &&
                   checkStep.finalized === Phrase.Dissonant
        }
        Pause {
            id: skipStep
            after:    checkStep.state === Phrase.Resolved &&
                      checkStep.finalized === Phrase.Consonant
            finishOn: checkStep.finalized === Phrase.Consonant
        }

        finishOn: updateStep.state === Phrase.Resolved ||
                  skipStep.state  === Phrase.Resolved

        Component.onCompleted: runPolicies()
    }

    // ── Simple Melody with finishOn ───────────────────────────────────────────
    Melody {
        id: flow3

        Pause {
            id: f3step
            after: flow3.state === Phrase.Playing
        }

        finishOn: f3step.state === Phrase.Resolved

        Component.onCompleted: runPolicies()
    }

    // ── Chord with dissonantOnFirstError policy ───────────────────────────────
    // activePolicies is defined on the QML-layer Chord/Sequence types, not on
    // the bare C++ Melody type. Use Chord here so the property is available.
    Chord {
        id: flowPolicy
        activePolicies: [MelodyPolicies.dissonantOnFirstError]
        Pause { id: fpA }
        Pause { id: fpB }
    }

    // Reports go straight to the global ReportRouter now, not through a
    // per-object "report" signal — a catch-all ReportsReceiver observes them.
    ReportsReceiver { id: melReports }
    SignalSpy { id: melReportSpy; target: melReports; signalName: "reportReceived" }

    function cleanup() {
        flow.reset(); flow2.reset(); flow3.reset()
        flowPolicy.reset()
        melReportSpy.clear()
    }

    // ── DAG: only stepA starts when flow plays ────────────────────────────────
    function test_01_dag_onlyAStartsFirst() {
        flow.play()
        compare(stepA.state, Phrase.Playing)
        compare(stepB.state, Phrase.Silent)
        compare(stepC.state, Phrase.Silent)
        compare(stepD.state, Phrase.Silent)
    }

    // ── DAG: B and C start in parallel after A ────────────────────────────────
    function test_02_dag_fanOut() {
        flow.play()
        stepA.finish()
        compare(stepA.state, Phrase.Resolved)
        compare(stepB.state, Phrase.Playing)
        compare(stepC.state, Phrase.Playing)
        compare(stepD.state, Phrase.Silent)
    }

    // ── DAG: D waits for BOTH B and C ────────────────────────────────────────
    function test_03_dag_fanIn_waitsForBoth() {
        flow.play()
        stepA.finish()
        stepB.finish()
        compare(stepD.state, Phrase.Silent)   // C not done yet
        stepC.finish()
        compare(stepD.state, Phrase.Playing)  // now D starts
    }

    // ── DAG: full execution → Melody Consonant ────────────────────────────────
    function test_04_dag_fullRun() {
        flow.play()
        stepA.finish()
        stepB.finish(); stepC.finish()
        stepD.finish()
        compare(flow.state,     Phrase.Resolved)
        compare(flow.finalized, Phrase.Consonant)
    }

    // ── Conditional: check Dissonant → updateStep runs ───────────────────────
    function test_05_conditional_dissonantTakesUpdatePath() {
        flow2.play()
        checkStep.finish(Errors.pause_timeout)   // check fails → updateStep should start
        compare(updateStep.state, Phrase.Playing)
        compare(skipStep.state,   Phrase.Silent)
        updateStep.finish()
        compare(flow2.finalized, Phrase.Consonant)
    }

    // ── Conditional: check Consonant → skipStep resolves immediately ──────────
    function test_06_conditional_consonantTakesSkipPath() {
        flow2.play()
        checkStep.finish()   // check passes → skipStep resolves immediately (pre-condition)
        compare(updateStep.state,   Phrase.Silent)
        compare(skipStep.finalized, Phrase.Consonant)
        compare(flow2.finalized,    Phrase.Consonant)
    }

    // ── Simple Melody: finishOn wired to child completion ────────────────────
    function test_07_simpleFinishOn() {
        flow3.play()
        compare(f3step.state, Phrase.Playing)
        f3step.finish()
        compare(flow3.state,     Phrase.Resolved)
        compare(flow3.finalized, Phrase.Consonant)
    }

    // ── Chord + dissonantOnFirstError policy resolves Dissonant on first error ─
    function test_08_policyOnChord() {
        flowPolicy.play()
        compare(fpA.state, Phrase.Playing)
        fpA.finish(Errors.pause_timeout)
        tryCompare(flowPolicy, "state",     Phrase.Resolved, 200)
        compare   (flowPolicy.finalized,    Phrase.Dissonant)
    }

    // ── Melody abort() stops execution ───────────────────────────────────────
    function test_09_abortMelody() {
        flow.play()
        stepA.finish()
        flow.abort()
        compare(flow.state,     Phrase.Resolved)
        compare(flow.finalized, Phrase.Aborted)
    }

    // ── Melody reset() and replay ─────────────────────────────────────────────
    function test_10_resetAndReplay() {
        flow3.play()
        f3step.finish()
        flow3.reset()
        flow3.play()
        compare(f3step.state, Phrase.Playing)
        f3step.finish()
        compare(flow3.finalized, Phrase.Consonant)
    }

    // ── after binding does not fire while Melody is Silent ───────────────────
    function test_11_afterDoesNotFireWhileSilent() {
        // flow3 is Silent — f3step.after: flow3.state === Phrase.Playing
        // Since flow3 is not playing, f3step should remain Silent
        compare(f3step.state, Phrase.Silent)
        compare(flow3.state,  Phrase.Silent)
    }

    // ── Reports from a child Phrase are observable via ReportsReceiver ────────
    function test_12_childReportsObservable() {
        flow3.play()
        compare(f3step.state, Phrase.Playing)
        melReportSpy.clear()   // discard state-change reports from play()
        f3step.warning("test warning from child")
        compare(melReportSpy.count, 1)
        f3step.finish()
        melReportSpy.clear()
    }
}
