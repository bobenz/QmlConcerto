# QmlConcerto — Developer Manual

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Core Concepts](#3-core-concepts)
4. [API Reference](#4-api-reference)
   - [Phrase](#41-phrase)
   - [Report](#42-report)
   - [Melody](#43-melody)
   - [Pause](#44-pause)
   - [Quote](#45-quote)
   - [ErrorEntry](#46-errorentry)
   - [ErrorRegistry](#47-errorregistry)
   - [Partitura](#48-partitura)
   - [MelodyPolicies](#49-melodypolicies)
5. [QML Components](#5-qml-components)
   - [Sequence](#51-sequence)
   - [Chord](#52-chord)
   - [Cadenza](#53-cadenza)
   - [Reprisa](#54-reprisa)
   - [Sonata](#55-sonata)
   - [Free-style Melody](#56-free-style-melody)
6. [Adding a Custom Phrase](#6-adding-a-custom-phrase)
7. [Workflow Composition Patterns](#7-workflow-composition-patterns)
8. [Error Handling](#8-error-handling)
9. [Logging and Reporting](#9-logging-and-reporting)

---

## 1. Overview

QmlConcerto is a **composable workflow execution framework** for Qt / QML. It models
multi-step operations as musical phrases that can be played, sequenced, and orchestrated
into larger compositions — hence the orchestral naming.

**Mental model:**
- A `Phrase` is a single executable operation.
- A `Melody` is a container that holds child `Phrase` objects.
- Each child phrase has reactive properties — `after` (play on condition) and
  `finishOn` (stop on condition) — that can be bound to arbitrary QML expressions.
- `Sequence`, `Chord`, `Cadenza`, `Reprisa`, and `Sonata` are convenience QML
  components built on `Melody` that pre-wire common patterns: serial execution,
  parallel execution, first-to-finish racing, looping, and setup/teardown framing.
- `Pause` is a built-in `Phrase` that waits for a condition or an optional timeout.
- For **any** execution graph (DAG, fan-out/fan-in, conditional branching), use
  a bare `Melody` with custom `after`/`finishOn` bindings.

The framework enforces a strict **state machine** at every level so that any
workflow — however deeply nested — exposes a uniform lifecycle interface.

---

## 2. Architecture

```
   QmlConcerto Layer
   ──────────────────────────────────────────────────
   Phrase  (abstract — all executable units)
     │
     ├── Pause   (built-in wait phrase)
     │
     └── Melody  (container) ──► Sequence.qml  (serial)
                                  Chord.qml     (parallel, all must finish)
                                  Cadenza.qml   (parallel, first-to-finish wins)
                                  Reprisa.qml   (loop until finishOn)
                                  Sonata.qml    (preludio → aria → coda)

   ErrorEntry  (value type)
   ErrorRegistry  (singleton) ──► "ErrorRegistry" context property
   QQmlPropertyMap  ──────────►  "Errors"        context property

   Report  (value type — structured log event)
```

### Two-layer design

| Layer | Responsibility |
|-------|---------------|
| **QML** | Orchestration logic (`after` bindings, completion detection, error propagation) |
| **Built-in types** | State transitions, lifecycle guards, error storage, logging signals |

---

## 3. Core Concepts

### Phrase state machine

Every `Phrase` runs through this state machine exactly once per `play()` call:

```
  Silent ──play()──► Playing ──finish()/abort()──► Resolved    ← standard flow
                        │
                   accompany()   ← opt-in, for long-running background phrases
                        │
                      Accompanying ──finish()/abort()──► Resolved
```

**State enum values** (`Phrase.Silent`, `Phrase.Playing`, etc.):

| Value | Meaning |
|-------|---------|
| `Silent` | Initial / idle. Safe to call `play()`. |
| `Playing` | Executing. Awaiting async result or condition. |
| `Accompanying` | Background mode. Opt-in for long-running phrases (services, listeners, monitors) that complete their startup in `Playing` and then transition via `accompany()` to signal ongoing background activity. The phrase remains alive until explicitly `finish()`ed or `abort()`ed. |
| `Paused` | Suspended. Reserved for future use. |
| `Resolved` | Terminal. Inspect `finalized` for the outcome. |

### Finalization outcomes

Once `Resolved`, the `finalized` property tells you why:

| Value | Meaning |
|-------|---------|
| `None` | Not yet finished. |
| `Consonant` | Completed successfully. |
| `Dissonant` | Completed with error — `lastError` is set. |
| `Aborted` | Manually stopped. |

### Reactive trigger properties

`Phrase` exposes four boolean properties that act as reactive triggers when bound
to QML expressions. Setting any of them to `true` fires the corresponding action
immediately.

| Property | Action when set to `true` | Binding use case |
|----------|--------------------------|-----------------|
| `after` | Calls `play()` | Start this phrase when a condition is met |
| `finishOn` | Calls `finish()` — resolves `Consonant` | Complete this phrase when a condition holds |
| `abortOn` | Calls `abort()` — resolves `Aborted` | Cancel this phrase when a condition holds |
| `finishOnError` | Calls `finish(lastError)` when `lastError` is set to a non-`NoError` value | Auto-resolve `Dissonant` when any error is assigned |

**`finishOnBound` / `abortOnBound`** — read-only flags that become `true` the first
time `setFinishOn` / `setAbortOn` is called (including the initial QML binding
evaluation, even when the expression starts as `false`). Use these in subclasses to
distinguish "no condition was ever wired" from "condition wired but not yet true":

```qml
// Example: a custom phrase that logs differently depending on whether
// a finish condition was set
onExit: {
    if (finalized === Phrase.Consonant && !finishOnBound)
        console.log("Completed by timeout (pure delay)")
    else if (finalized === Phrase.Consonant)
        console.log("Condition satisfied")
}
```

`Sequence` and `Chord` use `after` bindings to chain execution automatically.

**Pre-condition skip:** if `finishOn` is already `true` when `play()` is called,
the phrase resolves `Consonant` immediately *without* executing. Same for `abortOn` —
it resolves `Aborted` without executing.

**`finishOnError` usage pattern** — auto-finish on any error assigned externally:

```qml
MyPhrase {
    finishOnError: true
    // Setting lastError to anything other than NoError will
    // automatically call finish(lastError) → Dissonant
}
```

---

## 4. API Reference

### 4.1 Phrase

Abstract base for all executable units in the framework.

#### Properties

| Property | Type | Access | Notify signal |
|----------|------|--------|---------------|
| `state` | `State` | read-only | `stateChanged()` |
| `finalized` | `Finalized` | read-only | `finalizedChanged()` |
| `playing` | `bool` | read-only | `stateChanged()` |
| `after` | `bool` | read/write | `afterChanged()` |
| `finishOn` | `bool` | read/write | `finishOnChanged()` |
| `finishOnBound` | `bool` | read-only | `finishOnBoundChanged()` |
| `abortOn` | `bool` | read/write | `abortOnChanged()` |
| `abortOnBound` | `bool` | read-only | `abortOnBoundChanged()` |
| `finishOnError` | `bool` (default `false`) | read/write | `finishOnErrorChanged()` |
| `lastError` | `ErrorEntry` | read/write | `lastErrorChanged()` |
| `title` | `QString` | read/write | `titleChanged()` |
| `lyric` | `QString` | read/write | `lyricChanged()` |
| `tag` | `QString` | read/write | `tagChanged()` |

**`tag`** — when set to a non-empty string, the phrase registers itself in the
`Partitura` singleton under that key, making it globally accessible from anywhere
in QML as `Partitura.myTag`. The key must match `^[a-z_][a-zA-Z0-9_]*$` (lowercase
start, alphanumeric and underscores only). The phrase deregisters automatically
when `tag` is cleared or the phrase is destroyed. See [§4.8 Partitura](#48-partitura).

**`playing`** is a convenience shortcut for
`state === Phrase.Playing || state === Phrase.Accompanying`.
Use it for bindings that should be true whenever the phrase is actively running,
regardless of whether it has transitioned to background mode:

```qml
// Preferred over the verbose form in after/finishOn bindings
StepB { after: stepA.playing === false && stepA.state === Phrase.Resolved }

// Typical use — disable a button while a phrase is active
Button {
    enabled: !dispenseFlow.playing
    text: dispenseFlow.playing ? "Working…" : "Dispense"
}

// Guard a dependent phrase from starting while another is still live
MyPhrase { after: !serviceCmd.playing }
```

#### Enumerations

```qml
// State
Phrase.Silent
Phrase.Playing
Phrase.Accompanying
Phrase.Paused
Phrase.Resolved

// Finalized
Phrase.None
Phrase.Aborted
Phrase.Dissonant
Phrase.Consonant
```

#### Public slots

| Slot | Description |
|------|-------------|
| `play()` | Transitions to `Playing` and starts execution. Returns `false` if already `Playing`. If `finishOn` is already `true` at call time, resolves `Consonant` immediately without executing. If `abortOn` is already `true` at call time, resolves `Aborted` immediately without executing. |
| `finish(error)` | Resolves the phrase. Pass `NoError` (or no argument) for `Consonant`; pass an `ErrorEntry` for `Dissonant`. Effective while `Playing` or `Accompanying`. |
| `abort()` | Resolves with `Aborted`. Effective while `Playing` or `Accompanying`. |
| `accompany()` | Transitions from `Playing` to `Accompanying`. Used by long-running phrases to signal they are done with startup but remain active in the background. Only effective while `Playing`. |
| `reset()` | Resets back to `Silent` / `finalized = None` / `lastError = NoError`. For `Melody` subclasses, also resets all child phrases. |
| `info(msg)` | Emits `report()` at `Info` level. |
| `warning(msg)` | Emits `report()` at `Warning` level. |
| `error(entry)` | Emits `report()` at `Error` level. Does **not** resolve the phrase — call `finish(entry)` separately. |

#### Signals

| Signal | When emitted |
|--------|-------------|
| `stateChanged()` | Every state transition |
| `finalizedChanged()` | When `finalized` changes (just before `stateChanged` on resolution) |
| `enter()` | Immediately after transitioning to `Playing` |
| `exit()` | Immediately when `finalized` is first set (before `Resolved`) |
| `lastErrorChanged()` | When `lastError` changes |
| `report(Report)` | Structured log event |

#### `play()` execution order

```
play() called
  1. Guard: return false if already Playing
  2. finalized → None       → emits exit() + finalizedChanged()
  3. emit enter()           ← startup actions fire here (Sequence/Chord wiring,
  4. state → Playing            onEnter handlers) BEFORE any after-bindings react
                            → emits stateChanged()
  5. execution begins
     └─ eventually: finish() or abort()
           6. finalized → Consonant|Dissonant|Aborted  → emits exit() + finalizedChanged()
           7. lastError updated
           8. state → Resolved  → emits stateChanged()
```

---

### 4.2 Report

Structured log event emitted by `Phrase::report(Report)`.

#### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `QString` | Hierarchical source path: `"parentPath/phraseTitle"` |
| `category` | `QString` | Severity: `"Info"`, `"Warning"`, `"Error"`, `"Debug"`, `"Critical"` |
| `message` | `QString` | Human-readable message |
| `data` | `QVariant` | Optional attached payload |
| `timestamp` | `QDateTime` | When the event occurred |

---

### 4.3 Melody

Container `Phrase`. Child items declared in QML are automatically appended to
its `phrases` list.

#### Properties

| Property | Type | Notes |
|----------|------|-------|
| `phrases` | list of `Phrase` | Default property — children declared in QML body are appended automatically |
| `activePolicies` | JS array of functions | Each entry is `function(phrases, melody)`. Called once per Melody setup via `runPolicies()`. See [§4.9 MelodyPolicies](#49-melodypolicies). |

#### Methods

| Method | Description |
|--------|-------------|
| `runPolicies()` | Iterates `activePolicies` and calls each function with the phrase list and the Melody itself. Called automatically by `Sequence`, `Chord`, `Cadenza`, and `Reprisa` at the end of their setup. Call manually on a bare `Melody`. |

Melody's own `_play()` signals the QML composition layer to begin. The actual
orchestration is handled by `Sequence.qml` and `Chord.qml` via their reactive
bindings, or by your own `after`/`finishOn` expressions on a bare `Melody`.

---

### 4.4 Pause

A `Phrase` that stays in `Playing` until a condition is met or an optional
timeout elapses.

#### QML usage

```qml
Pause {
    title:    "Wait for card insertion"
    timeout:  5000                              // ms; 0 = no timeout (default)
    finishOn: idc.state === Phrase.Resolved     // condition that ends the wait
}
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `timeout` | `int` (ms) | `0` | Maximum time to wait. `0` means wait indefinitely. |

All other properties are inherited from `Phrase` (`finishOn`, `abortOn`, `after`, etc.).

#### Outcomes

| Trigger | Finalization | Notes |
|---------|-------------|-------|
| `finishOn` becomes `true` | `Consonant` | Normal completion — condition satisfied |
| `timeout` elapses, `finishOn` was bound | `Dissonant` (`pause_timeout`) | Condition wasn't met in time — error code `-9001` |
| `timeout` elapses, no `finishOn` bound | `Consonant` | Pure delay — timeout is the intended finish trigger |
| `abort()` called | `Aborted` | Standard `Phrase` behaviour |

#### Error registered

| Name | Source | Code | Description |
|------|--------|------|-------------|
| `pause_timeout` | `Pause` | `-9001` | Pause timed out |

Access via `Errors.pause_timeout` in QML.

#### Typical patterns

**Wait indefinitely for a device event:**

```qml
Pause {
    title:    "Wait for shutter"
    finishOn: shutter.state === Phrase.Resolved
}
```

**Wait with a deadline:**

```qml
Pause {
    title:   "Card insertion window"
    timeout: 30000   // 30 s

    onExit: {
        if (finalized === Phrase.Dissonant)
            console.warn("Card not inserted in time:", lastError.description)
    }
}
```

**Delay between steps (fixed sleep):**

```qml
Sequence {
    StartMotor  { }
    Pause       { title: "Motor spin-up"; timeout: 500 }
    ReadSensor  { }
}
```

**Abort the enclosing sequence on timeout:**

```qml
Sequence {
    id: cardFlow

    Pause {
        title:    "Wait for card"
        timeout:  10000
        finishOn: idc.cardPresent

        onExit: {
            if (finalized === Phrase.Dissonant)
                cardFlow.abort()
        }
    }

    ReadTrack { }
}
```

> **Note:** `finishOn` is evaluated as a pre-condition at `play()` time. If the
> condition is already `true` when `Pause` starts playing, it resolves `Consonant`
> immediately without waiting.

---

### 4.5 Quote

A `Phrase` that acts as a **transparent proxy** for another `Phrase` called `source`.
`Quote` takes full lifecycle control over the source: it delegates `play()` and
`abort()` to it, then mirrors the source's state and finalization back onto itself.
This lets you embed any existing `Phrase` object into a `Sequence` or `Chord`
without duplicating its implementation.

#### Properties

| Property | Type | Access | Notify signal |
|----------|------|--------|---------------|
| `source` | `Phrase*` | read/write | `sourceChanged()` |

All other properties are inherited from `Phrase`.

#### Lifecycle delegation

| Quote event | What happens |
|-------------|-------------|
| `play()` called | Calls `source->play()`. If `source` is `null`, resolves `Dissonant` immediately. If source is already `Resolved`, mirrors the outcome right away. |
| `abort()` called | Calls `source->abort()` if source is active; otherwise aborts self directly. |
| `reset()` called | Resets both Quote and source to `Silent`. |
| source reaches `Accompanying` | Quote calls `accompany()` — mirrors background mode. |
| source reaches `Resolved/Consonant` | Quote calls `finish()` — resolves `Consonant`. |
| source reaches `Resolved/Dissonant` | Quote calls `finish(source.lastError)` — resolves `Dissonant` with the same error. |
| source reaches `Resolved/Aborted` | Quote calls `abort()` on self — resolves `Aborted`. |

`report()` signals emitted by the source are **forwarded through Quote's own
`report()` signal**, so they participate normally in the report-bubbling hierarchy
of any enclosing `Sequence` or `Chord`.

#### Safety guards

- **Mid-flight `source` swap is rejected.** Setting `source` while Quote is
  `Playing` or `Accompanying` is a no-op (logged as a warning). Swap the source
  only while `Silent` or `Resolved`.
- **Null source** — if `source` is `null` when `play()` is called, Quote resolves
  `Dissonant` immediately and emits a warning report.

#### Registration

```cpp
// main.cpp
qmlRegisterType<Quote>("QmlConcerto", 1, 0, "Quote");
```

#### QML usage examples

**Re-use a shared command inside a Sequence:**

```qml
// cdmService.dispenseCommand is a Phrase that lives elsewhere.
// Quote lets it participate in this flow without moving it.

Sequence {
    Quote { source: cdmService.dispenseCommand }
    PrintReceipt { }
}
```

**Wrap an externally-owned phrase with its own `after` trigger:**

```qml
Quote {
    id: wrappedDispense
    source: cdmService.dispenseCommand
    after: sessionReady && amountConfirmed
}
```

**Re-play the same command object multiple times:**

```qml
// Quote resets source on reset(), so the same underlying Phrase
// can be replayed across multiple Quote instances in a loop.

Sequence {
    id: retryFlow

    Quote { source: connectCmd }   // attempt 1
    Pause { timeout: 1000 }
    Quote { source: connectCmd }   // attempt 2
}
```

**Mirror a long-running (Accompanying) service:**

```qml
// If source calls accompany(), Quote enters Accompanying too,
// staying alive until source finishes or is aborted.

Quote {
    source: monitorService.heartbeatPhrase
    abortOn: sessionEnded
}
```

---

### 4.6 ErrorEntry

Value type representing a single error definition.

#### QML-exposed properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | `QString` | Module identifier (e.g. `"APP"`, `"CDM"`) |
| `code` | `int` | Numeric error code |
| `description` | `QString` | Human-readable message |
| `valid` | `bool` | `true` if the entry has a non-empty name |
| `text` | `QString` | Formatted: `"[source] (code) description"` |

#### Built-in sentinel

`NoError` — pass to `finish()` (or call `finish()` with no arguments) to signal success.

---

### 4.7 ErrorRegistry

Global singleton for error lookup and registration.

**QML context properties:**

| Context property | Use |
|-----------------|-----|
| `ErrorRegistry` | Method calls (lookup, declare) |
| `Errors` | Symbolic property access (`Errors.my_error.code`) |

#### Methods (callable from QML)

| Method | Description |
|--------|-------------|
| `declare({ name, source, code, description })` | Register an error from a JS object literal |
| `lookup(code)` | Find `ErrorEntry` by numeric code. Warns if the code is registered under multiple sources (ambiguous). |
| `lookup(code, source)` | Unambiguous lookup by composite key `(code, source)`. Preferred when the source is known. |
| `lookupByName(name)` | Find `ErrorEntry` by name |
| `describe(code)` | Formatted description string for a code |
| `contains(code)` | Check if code is registered |
| `containsName(name)` | Check if name is registered |

#### QML usage examples

```qml
// Symbolic access via property map
console.log(Errors.session_xpr.code)        // -1001
console.log(Errors.session_xpr.description) // "Session expired"
console.log(Errors.session_xpr.text)        // "[APP] (-1001) Session expired"

// Pass to finish()
finish(Errors.session_xpr)

// Lookup by code
var e = ErrorRegistry.lookup(-1001)

// Register at runtime from QML
Component.onCompleted: {
    ErrorRegistry.declare({
        name: "shutter_stuck",
        source: "CDM",
        code: -2001,
        description: "Shutter mechanism stuck"
    })
}
```

---

### 4.8 Partitura

Global singleton that acts as the **named-phrase registry** for the application.
Inherits `QQmlPropertyMap`, so registered phrases are accessible as direct
properties — `Partitura.myTag` — from any QML file without imports or object
references.

Named after the musical score (*partitura*): the single document that shows
every part at once.

#### Registration in main.cpp

```cpp
qmlRegisterSingletonType<Partitura>(
    "QmlConcerto", 1, 0, "Partitura", partitura_provider);
```

#### How phrases register

Set `tag` on any `Phrase`. Registration and deregistration are automatic:

```qml
DispenseCommand {
    tag: "dispense"   // → Partitura.dispense is now this phrase
}
```

The key must match `^[a-z_][a-zA-Z0-9_]*$`. Invalid keys are rejected with
a console warning and the phrase is not registered.

#### Methods (callable from QML or C++)

| Method | Description |
|--------|-------------|
| `registerPhrase(key, phrase)` | Manually register a phrase under `key`. Prefer `tag` for QML-declared phrases. |
| `deregisterPhrase(key)` | Remove the entry for `key`. |

#### QML usage

```qml
// Any QML file — no id or property passing required
import QmlConcerto 1.0

Button {
    enabled: !Partitura.dispense.playing
    onClicked: Partitura.dispense.play()
}
```

```qml
// Bind finishOn to a tagged phrase's state from a completely different component
Pause {
    finishOn: Partitura.calibration.finalized === Phrase.Consonant
}
```

```qml
// Guard: only proceed when a background service is live
MyPhrase {
    after: Partitura.heartbeat.playing
}
```

#### Key rules

- Keys are **lowercase-start**, alphanumeric + underscores: `dispense`, `card_read`, `pinEntry` is invalid (`E` is uppercase — use `pin_entry`).
- Tag **collisions** (two phrases with the same tag) are logged as warnings; the second registration overwrites the first.
- A phrase with `tag` set **deregisters itself** when destroyed or when `tag` is set to `""`.

---

### 4.9 MelodyPolicies

A built-in QML singleton (`import Concerto 1.0`) that provides seven ready-made
policy functions for `Melody.activePolicies`. Each policy is a
`function(phrases, melody)` — it receives the full phrase list and the Melody,
then attaches signal connections to inject the desired behaviour.

#### Registration

`MelodyPolicies` is automatically registered by `ConcertoRegistration`. No extra
import is needed beyond `import Concerto 1.0`.

#### Built-in policies

| Policy | Trigger | Melody action |
|--------|---------|---------------|
| `dissonantOnFirstError` | Any child → `Dissonant` | `melody.finish(child.lastError)` immediately |
| `abortOnFirstError` | Any child → `Dissonant` | `melody.abort()` immediately |
| `abortSiblingsOnError` | Any child → `Dissonant` | Abort all other `Playing`/`Accompanying` children; melody resolves via its own wiring |
| `oneDissonantAllAborted` | Any child → `Dissonant` | Abort siblings **and** `melody.finish(error)` — combines the two above |
| `keepFirstError` | Any child → `Dissonant` | Set `melody.lastError` only when it is currently `NoError` (don't overwrite) |
| `dissonantOnAllError` | **All** children → `Dissonant` | `melody.finish(lastError)` — resolves `Dissonant` only when every child has failed; resets on `melody.cleanup` for replay |
| `consonantOnFirstSuccess` | Any child → `Consonant` | `melody.finish()` immediately |

Policies in the "error response" group (`dissonantOnFirstError`, `abortOnFirstError`,
`abortSiblingsOnError`, `oneDissonantAllAborted`) are logically mutually exclusive —
enable only one per Melody.

#### QML usage

```qml
import Concerto 1.0

// Built-in policy
Chord {
    activePolicies: [MelodyPolicies.dissonantOnFirstError]

    FetchUsers    { }
    FetchSettings { }
    FetchLicense  { }
}

// Multiple policies
Sequence {
    activePolicies: [
        MelodyPolicies.keepFirstError,
        MelodyPolicies.abortSiblingsOnError
    ]

    StepA { }
    StepB { }
    StepC { }
}

// Custom inline policy alongside a built-in
Melody {
    Component.onCompleted: flow.play()
    id: flow

    activePolicies: [
        MelodyPolicies.dissonantOnFirstError,
        function(phrases, melody) {
            for (var i = 0; i < phrases.length; i++) {
                (function(p) {
                    p.onExit.connect(function() {
                        console.log(p.title, "→", p.finalized)
                    })
                })(phrases[i])
            }
        }
    ]

    StepA { after: flow.state === Phrase.Playing }
    StepB { after: stepA.state === Phrase.Resolved }
}
```

#### Writing a custom policy

A policy function receives the phrase list and the Melody, then uses standard
QML signal connections to attach behaviour. The function is called once during
`Component.onCompleted`; connections persist across plays.

```qml
// Policy that logs every child resolution with its elapsed time
activePolicies: [function(phrases, melody) {
    for (var i = 0; i < phrases.length; i++) {
        (function(p) {
            var startTime
            p.onEnter.connect(function() { startTime = Date.now() })
            p.onExit.connect(function() {
                var ms = Date.now() - startTime
                console.log(p.title, "resolved in", ms, "ms →", p.finalized)
            })
        })(phrases[i])
    }
}]
```

#### Bare `Melody` — call `runPolicies()` manually

`Sequence`, `Chord`, `Cadenza`, and `Reprisa` call `runPolicies()` automatically.
On a bare `Melody` with custom `after`/`finishOn` wiring, call it yourself:

```qml
Melody {
    id: flow
    activePolicies: [MelodyPolicies.dissonantOnFirstError]

    Component.onCompleted: {
        // ... custom after/finishOn wiring ...
        runPolicies()   // ← must be called explicitly on bare Melody
    }

    StepA { id: stepA; after: flow.state === Phrase.Playing }
    StepB { after: stepA.state === Phrase.Resolved }
    finishOn: stepB.state === Phrase.Resolved
}
```

---

## 5. QML Components

`Sequence`, `Chord`, `Cadenza`, `Reprisa`, and `Sonata` are convenience components
built on `Melody`. All are available without an explicit import path.

All are pre-wired patterns of the same underlying mechanism: **`Melody` + `after`/`finishOn` bindings**.
For custom execution graphs, see [§5.6 Free-style Melody](#56-free-style-melody).

### 5.1 Sequence

Executes child phrases **serially**. Each phrase starts only after the previous one
reaches `Resolved`. The last phrase's finalization (and error, if any) propagates to
the `Sequence` itself.

#### Execution flow

```
Sequence.play()
  → phrases[0] starts (bound to root Playing)
  → phrases[0] resolves (Consonant or Dissonant) or enters Accompanying
  → phrases[1] starts
  → ...
  → last phrase resolves → Sequence resolves (carrying last error if Dissonant)
```

**`Accompanying` advance:** if a child phrase calls `accompany()` (transitions to
`Accompanying` background mode), the next phrase starts immediately — the accompanying
child remains live in the background while the sequence continues.

**Error behaviour:** each child phrase propagates its `Dissonant` error to the
Sequence's `lastError`. The sequence continues to the next child even after a `Dissonant`
resolution. If `finishOnError` is enabled on the Sequence, it resolves immediately when
any child reports an error. Otherwise the Sequence completes when the last phrase resolves.

#### Example

```qml
Sequence {
    id: initFlow
    Component.onCompleted: initFlow.play()

    onExit: {
        if (finalized === Phrase.Consonant)
            console.log("Init complete")
        else if (finalized === Phrase.Dissonant)
            console.error("Init failed:", lastError.description)
    }

    OpenDevice   { title: "Open CDM" }
    LoadConfig   { title: "Load config" }
    SelfTest     { title: "Self-test" }
}
```

---

### 5.2 Chord

Executes all child phrases **in parallel**. Resolves when every child reaches
`Resolved`. If any child finishes with `Dissonant`, the `Chord` propagates that error.

#### Execution flow

```
Chord.play()
  → all phrases start simultaneously (all bound to root Playing)
  → as each phrase resolves, Chord checks whether all are done
  → when all are Resolved → Chord resolves (carrying last error if any were Dissonant)
```

**Error behaviour:** each `Dissonant` child propagates its error to the Chord's
`lastError`. The Chord resolves only when *all* children have resolved — there is
no early-exit.

#### Example

```qml
Chord {
    id: fetchAll
    Component.onCompleted: fetchAll.play()

    onExit: {
        if (finalized === Phrase.Consonant)
            console.log("All data fetched")
    }

    FetchUsers    { title: "Users" }
    FetchSettings { title: "Settings" }
    FetchLicense  { title: "License" }
}
```

---

### 5.3 Cadenza

Executes all child phrases **in parallel**. Resolves as soon as **one** child
reaches `Resolved` — the winner's finalization and error propagate to the
`Cadenza`. All remaining active children are **aborted**.

Named after the musical cadenza: a solo passage where one voice emerges from
the ensemble and the others fall silent.

#### Execution flow

```
Cadenza.play()
  → all phrases start simultaneously (all bound to root Playing)
  → first phrase to resolve → wins
      → its finalization (Consonant / Dissonant) propagates to Cadenza
      → all other Playing / Accompanying children are aborted
  → Cadenza resolves
```

**Winner is externally Aborted:** if a child is aborted by something other than
Cadenza itself, it does not count as a winner — the race continues with the
remaining children.

**Error behaviour:** if the winning child resolves `Dissonant`, Cadenza resolves
`Dissonant` with that child's `lastError`. There is no early-exit on error from
*losing* children — only the winner's outcome matters.

#### Example

```qml
// First service to respond wins; others are cancelled
Cadenza {
    id: serviceRace
    Component.onCompleted: serviceRace.play()

    onExit: {
        if (finalized === Phrase.Consonant)
            console.log("Got response from fastest service")
        else if (finalized === Phrase.Dissonant)
            console.error("Winner failed:", lastError.description)
    }

    QueryServiceA { title: "Service A" }
    QueryServiceB { title: "Service B" }
    QueryServiceC { title: "Service C" }
}
```

```qml
// Timeout race: operation vs. deadline
// Pause has no finishOn → timeout resolves Consonant → Cadenza resolves Consonant
// Distinguish the two outcomes by checking which child won, not by Dissonant.
Cadenza {
    id: timedOp
    Component.onCompleted: timedOp.play()

    FetchData { id: fetchData; title: "Fetch" }
    Pause      { title: "Deadline"; timeout: 5000 }

    onExit: {
        if (finalized === Phrase.Dissonant) {
            console.warn("Fetch failed:", lastError.description)
        } else if (fetchData.state !== Phrase.Resolved) {
            // Pause won — fetchData was aborted → timeout
            console.warn("Timed out")
        }
    }
}
```

---

### 5.4 Reprisa

Executes a **single child phrase repeatedly**, replaying it after
each resolution, until `finishOn` becomes `true`.

Named after the musical reprise: a repeated return of a theme.

#### Execution flow

```
Reprisa.play()
  → child starts
  → child resolves:
      Dissonant → Reprisa resolves Dissonant (propagates error)
      Aborted   → Reprisa resolves Aborted
      Consonant + finishOn true  → Reprisa resolves Consonant
      Consonant + finishOn false → child.play() → next iteration
```

**Child responsibility:** Reprisa does not call `reset()` on the child between
iterations. The child phrase is responsible for managing its own state across
replays — resetting internal counters, clearing results, or accumulating state
deliberately. This keeps loop logic encapsulated inside the child where it belongs.

**Error policy:** Reprisa is error-agnostic. To stop the loop on error, set
`finishOnError: true` on the child phrase — it will resolve `Dissonant` and
Reprisa propagates it. To ignore errors and keep looping, the child should
handle the error internally and always resolve `Consonant`.

**`finishOn` timing:** the condition is checked only after each `Consonant`
resolution — it does not interrupt a running iteration. For mid-iteration
interruption use `abortOn` (resolves `Aborted`) or, if a `Consonant` outcome
is needed, wrap in a `Cadenza` racing the child against a `Pause`.

**Child count guard:** `Reprisa` expects exactly one child phrase. If
`phrases.length !== 1` at startup, a console warning is emitted and Reprisa
resolves immediately with an `"Invalid child count"` error.

#### Examples

```qml
// Poll a sensor until it reports ready; stop loop on hardware error
Reprisa {
    id: pollLoop
    Component.onCompleted: pollLoop.play()
    finishOn: sensor.valueReady

    PollSensor {
        title: "Poll sensor"
        finishOnError: true     // Dissonant → Reprisa resolves Dissonant
    }
}
```

```qml
// Loop exactly N times — child owns the counter
Reprisa {
    id: countdown
    Component.onCompleted: countdown.play()

    TickPhrase {
        // TickPhrase increments its own counter and sets finishOn internally
        // when it reaches the target — no external injection needed
    }
}
```

```qml
// Retry a soft step inside a Sequence until it succeeds
Sequence {
    OpenDevice { }

    Reprisa {
        finishOn: calibration.finalized === Phrase.Consonant

        CalibrateDevice {
            id: calibration
            // No finishOnError — soft errors loop again
            // CalibrateDevice resets itself on each play()
        }
    }

    Dispense { }
}
```

---

### 5.5 Sonata

A **three-part framed composition**: Preludio → Aria → Coda. Models the
classical setup / main-work / teardown pattern — the Coda always runs
regardless of how Preludio or Aria resolved, making it the QML equivalent
of a try/finally block.

Named after the sonata form: a structured musical work with a clear
opening, development, and conclusion.

#### Parts

| Part | How it is declared | Role |
|------|--------------------|------|
| `preludio` | `property Phrase` | Setup — runs first |
| `aria` | Single body child (`phrases[0]`) | Main work — the expressive core |
| `coda` | `property Phrase` | Teardown — always runs last |

`aria` is exposed as `readonly property Phrase aria: phrases[0]` — readable
and bindable from outside with no `id` required on the body child.

#### Execution flow

```
Sonata.play()
  → preludio starts
  → preludio Consonant → aria starts
  → preludio Dissonant/Aborted → aria skipped → coda starts
  → aria resolves (any outcome) → coda starts
  → coda resolves:
      Coda Dissonant → Sonata resolves Dissonant (coda error overrides all)
      Coda Aborted   → Sonata resolves Aborted
      Coda Consonant → Sonata delivers pending preludio/aria outcome
```

#### Resolution rules

| Scenario | Sonata resolves as |
|----------|--------------------|
| Preludio Dissonant | Dissonant (preludio error), after coda |
| Preludio Aborted | Aborted, after coda |
| Aria Dissonant | Dissonant (aria error), after coda |
| Aria Aborted | Aborted, after coda |
| Aria Consonant | Consonant, after coda |
| Coda Dissonant | Dissonant (coda error) — overrides aria outcome |
| Coda Aborted | Aborted — overrides aria outcome |

**Coda always runs.** Even if Preludio or Aria fails or is aborted, Coda
is guaranteed to execute. This makes Sonata safe for resource management:
open in Preludio, use in Aria, close in Coda.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `preludio` | `Phrase` | Setup phrase. Default: empty `Phrase {}` (no-op). |
| `coda` | `Phrase` | Teardown phrase. Default: empty `Phrase {}` (no-op). |
| `aria` | `Phrase` (readonly) | The single body child. Readable from outside. |

#### Example — resource management

```qml
Sonata {
    id: session
    Component.onCompleted: session.play()

    preludio: OpenDevice  { title: "Open" }
    coda:     CloseDevice { title: "Close" }   // always runs

    DoMainWork { title: "Work" }   // aria — no id required

    onExit: {
        if (finalized === Phrase.Consonant)
            console.log("Session complete")
        else if (finalized === Phrase.Dissonant)
            console.error("Session failed:", lastError.description)
    }
}
```

#### Example — monitoring aria state from outside

```qml
Sonata {
    id: flow
    preludio: Init    { }
    coda:     Cleanup { }
    Transfer          { }   // aria
}

// Elsewhere — no id needed on Transfer
Text {
    text: flow.aria.state === Phrase.Playing ? "Transferring…" : "Idle"
}
```

#### Example — nested inside a Sequence

```qml
Sequence {
    Authenticate { }

    Sonata {
        preludio: LockMutex   { }
        coda:     UnlockMutex { }   // always releases the lock

        ProcessData { }
    }

    SendReceipt { }
}
```

---

### 5.6 Free-style Melody

**The most generic composition pattern.** Use a bare `Melody` with declarative
`after` and `finishOn` bindings on each child phrase to express **any** execution
graph — DAG, fan-out/fan-in, conditional branching, or any custom orchestration.

#### Core reactive properties

| Property | Purpose | Behavior |
|----------|---------|----------|
| `after` | **Play on condition** | Bind a QML expression; when it evaluates to `true`, the phrase calls `play()` |
| `finishOn` | **Stop on condition** | Bind a QML expression; when it evaluates to `true`, the phrase calls `finish()` (resolves `Consonant`) |

These two properties are the building blocks for all workflow composition.
`Sequence` and `Chord` are simply pre-wired combinations of these bindings.

#### DAG example — fan-out / fan-in

```qml
Melody {
    id: flow
    Component.onCompleted: flow.play()

    StepA {
        id: stepA
        after: flow.state === Phrase.Playing            // starts when Melody plays
    }
    StepB {
        id: stepB
        after: stepA.state === Phrase.Resolved          // after A resolves
    }
    StepC {
        id: stepC
        after: stepA.state === Phrase.Resolved          // after A (parallel with B)
    }
    StepD {
        id: stepD
        after: stepB.state === Phrase.Resolved &&
               stepC.state === Phrase.Resolved          // waits for BOTH B and C
    }

    finishOn: stepD.state === Phrase.Resolved           // Melody finishes when D is done
}
```

**Execution:**

```
flow.play() → state = Playing
  stepA.after → true                     → A plays
  A resolves
  stepB.after → true, stepC.after → true → B and C play in parallel
  B resolves, C resolves
  stepD.after → true                     → D plays
  D resolves
  flow.finishOn → true                   → Melody resolves Consonant
```

#### Conditional branching

```qml
Melody {
    id: flow

    CheckVersion {
        id: check
        after: flow.state === Phrase.Playing
    }
    UpdateFirmware {
        id: update
        after: check.state === Phrase.Resolved && check.finalized === Phrase.Dissonant
        // Only runs if version check failed
    }
    SkipUpdate {
        id: skip
        finishOn: check.finalized === Phrase.Consonant
        // Skips itself (resolves immediately) if check passed
        after: check.state === Phrase.Resolved
    }

    finishOn: update.state === Phrase.Resolved || skip.state === Phrase.Resolved
}
```

#### How `after` and `finishOn` work

Both are reactive boolean properties. The moment their binding evaluates to `true`,
the corresponding action fires immediately. This means you can bind them to **any**
QML expression:

```qml
MyPhrase {
    after:    sensor.temperature > 30    // play when sensor threshold is crossed
    finishOn: timer.expired              // stop when timer expires
}
```

---

## 6. Adding a Custom Phrase

Custom phrases are C++ `Phrase` subclasses exposed to QML via `qmlRegisterType`.
Subclass `Phrase` for atomic operations, or `Melody` for container phrases that
manage child phrases. Override `_play()` to start your work — it must eventually
lead to `finish()` or `abort()` being called, either synchronously or from an
async callback (timer, signal, device response). Register the type, then use it
in QML exactly like any built-in type:

```qml
import QmlConcerto 1.0
import MyApp 1.0

Sequence {
    id: flow
    Component.onCompleted: flow.play()

    onExit: {
        if (finalized === Phrase.Consonant)
            console.log("All done")
        else if (finalized === Phrase.Dissonant)
            console.error("Failed:", lastError.description)
    }

    MyCommand { title: "Step 1"; target: "deviceA" }
    MyCommand { title: "Step 2"; target: "deviceB" }
}

---

## 7. Workflow Composition Patterns

> **All patterns below are built on the same reactive mechanism:** `after` (play on condition)
> and `finishOn` (stop on condition). `Sequence`, `Chord`, `Cadenza`, `Reprisa`, and `Sonata` are convenience wrappers.
> For custom DAGs and conditional branching, see [§5.6 Free-style Melody](#56-free-style-melody).

### Serial execution

```qml
Sequence {
    StepA { }
    StepB { }
    StepC { }
    // A → B → C, one at a time
}
```

### Parallel execution (all must finish)

```qml
Chord {
    FetchUsers    { }
    FetchSettings { }
    FetchLicense  { }
    // All three run concurrently; resolves when all finish
}
```

### Parallel execution (first to finish wins)

```qml
Cadenza {
    QueryServiceA { }
    QueryServiceB { }
    QueryServiceC { }
    // All three start together; first to resolve wins, others are aborted
}
```

### Operation with a timeout (Cadenza pattern)

```qml
// Cleaner alternative to Pause + onExit abort logic
Cadenza {
    id: timedFetch
    FetchData { title: "Fetch" }
    Pause     { title: "Timeout"; timeout: 5000 }
    // If Pause wins → FetchData aborted → Cadenza resolves Consonant
    // (Pause has no finishOn, so timeout resolves Consonant — not an error)
}
```

### Retry loop until condition met

```qml
Reprisa {
    id: pollLoop
    Component.onCompleted: pollLoop.play()
    finishOn: sensor.valueReady

    PollSensor { finishOnError: true }
}
```

### Loop exactly N times

```qml
// The child phrase owns its counter and sets finishOn internally
Reprisa {
    id: loop
    Component.onCompleted: loop.play()

    TickPhrase {
        // increments its own counter on each play();
        // sets finishOn: count >= 5 internally
    }
}
```

### Exit a loop mid-iteration on an external condition

```qml
// abortOn — interrupt immediately, resolves Aborted:
Reprisa {
    id: monitor
    Component.onCompleted: monitor.play()
    abortOn: session.ended      // aborts child + Reprisa right away

    CheckHeartbeat { }
}
```

```qml
// If a Consonant outcome is needed despite mid-iteration interruption,
// race the Reprisa against a Pause inside a Cadenza:
Cadenza {
    Reprisa {
        finishOn: loopDone      // only checked after each Consonant resolution
        MyStep { }
    }
    Pause { finishOn: urgentEvent }  // wins first → Reprisa aborted, Cadenza = Consonant
}
```

### Setup / main work / teardown (guaranteed cleanup)

```qml
Sonata {
    preludio: OpenDevice  { }   // setup
    coda:     CloseDevice { }   // always runs — even if aria fails

    DoMainWork { }              // aria
}
```

### Authenticated session with guaranteed logout

```qml
Sequence {
    Sonata {
        preludio: Login  { }
        coda:     Logout { }   // always logs out

        Sequence {
            FetchData    { }
            ProcessData  { }
            SendReceipt  { }
        }
    }
}
```

### Parallel groups in series

```qml
Sequence {
    // Phase 1: gather data in parallel
    Chord {
        LoadConfig    { }
        LoadFirmware  { }
    }

    // Phase 2: validate (sequential)
    ValidateConfig  { }

    // Phase 3: apply in parallel
    Chord {
        ApplyConfig   { }
        UpdateDisplay { }
    }
}
```

### Fixed delay between steps

```qml
Sequence {
    StartMotor  { }
    Pause       { title: "Motor spin-up delay"; timeout: 500 }
    ReadSensor  { }
}
```

### Waiting for an external event with a deadline

```qml
Sequence {
    id: cardFlow

    Pause {
        title:    "Wait for card"
        timeout:  15000
        finishOn: idc.cardPresent

        onExit: {
            if (finalized === Phrase.Dissonant)
                cardFlow.abort()    // abort the whole sequence on timeout
        }
    }

    ReadTrack { }
    Eject     { }
}
```

### Reacting to outcomes

```qml
Sequence {
    id: workflow
    Component.onCompleted: workflow.play()

    onExit: {
        switch (finalized) {
            case Phrase.Consonant:
                statusLabel.text = "Ready"
                break
            case Phrase.Dissonant:
                statusLabel.text = "Error: " + lastError.description
                break
            case Phrase.Aborted:
                statusLabel.text = "Cancelled"
                break
        }
    }

    MyPhrase { title: "Init" }
    MyPhrase { title: "Connect" }
}
```

### Triggering a sequence from a UI event

```qml
Button {
    onClicked: dispenseFlow.play()
}

Sequence {
    id: dispenseFlow
    // ...
}
```

### Aborting a Sequence early on child error

```qml
Sequence {
    id: criticalFlow

    PhaseA {
        onExit: {
            if (finalized === Phrase.Dissonant)
                criticalFlow.abort()
        }
    }
    PhaseB { }
    PhaseC { }
}
```

---

## 8. Error Handling

### Declaring errors

**Option A — Static declaration (recommended for built-in module errors)**

Declare errors as static class members. They self-register with `ErrorRegistry`
automatically on first use and are then accessible via `Errors.*` in QML.

**Option B — Dynamic registration from QML (runtime)**

```qml
Component.onCompleted: {
    ErrorRegistry.declare({
        name: "bad_pin",
        source: "PIN",
        code: -3001,
        description: "PIN entry failed"
    })
}
```

### Using errors in QML

```qml
// Symbolic access
console.log(Errors.shutter_stuck.code)         // -2001
console.log(Errors.shutter_stuck.description)  // "Shutter mechanism stuck"
console.log(Errors.shutter_stuck.text)         // "[CDM] (-2001) Shutter mechanism stuck"

// Pass to finish() inside a custom handler
finish(Errors.shutter_stuck)    // resolves Dissonant with that error

// Lookup by code (returns ErrorEntry)
var e = ErrorRegistry.lookup(-2001)
```

### Error propagation through Sequence

`Sequence` propagates the error from the last `Dissonant` child. For early abort:

```qml
Sequence {
    id: flow

    PhaseA {
        onExit: {
            if (finalized === Phrase.Dissonant)
                flow.abort()    // abort the whole Sequence immediately
        }
    }
    PhaseB { }
}
```

### Error propagation through Chord

`Chord` reports the last `Dissonant` child's error after *all* children resolve.
There is no early-exit — all parallel branches always run to completion.

---

## 9. Logging and Reporting

Every `Phrase` emits structured `Report` signals through its lifecycle. Reports
bubble up through the hierarchy, so connecting to a `Sequence` or top-level
`Melody` captures all log events from every descendant.

### Connecting the `report` signal in QML

```qml
Sequence {
    id: flow

    onReport: function(r) {
        logModel.append({
            time:    Qt.formatTime(r.timestamp, "hh:mm:ss.zzz"),
            source:  r.source,
            level:   r.category,
            message: r.message
        })
    }

    StepA { }
    StepB { }
}
```

### Report fields quick reference

| Field | Type | Example value |
|-------|------|---------------|
| `source` | `QString` | `"/MyFlow/StepA"` |
| `category` | `QString` | `"Info"`, `"Warning"`, `"Error"`, `"Debug"`, `"Critical"` |
| `message` | `QString` | `"Pause started (timeout=5000 ms)"` |
| `data` | `QVariant` | optional attached data |
| `timestamp` | `QDateTime` | `2026-05-06 14:03:12.045` |

### Log categories

| Category | Emitted by |
|----------|-----------|
| `Info` | `info(msg)` — normal progress |
| `Warning` | `warning(msg)` — recoverable anomaly |
| `Error` | `error(entry)` — error logged (phrase not yet resolved) |
| `Debug` | Internal signal tracing |
| `Critical` | Reserved |
