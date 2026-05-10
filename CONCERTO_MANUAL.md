# QmlConcerto — Developer Manual

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Core Concepts](#3-core-concepts)
4. [API Reference](#4-api-reference)
   - [Phrase](#41-phrase)
   - [Report](#42-report)
   - [Melody](#43-melody)
   - [ErrorEntry](#44-errorentry)
   - [ErrorRegistry](#45-errorregistry)
5. [QML Components](#5-qml-components)
   - [Sequence](#51-sequence)
   - [Chord](#52-chord)
   - [Free-style Melody](#53-free-style-melody)
6. [Adding a Custom Phrase](#6-adding-a-custom-phrase)
7. [Workflow Composition Patterns](#7-workflow-composition-patterns)
8. [Error Handling](#8-error-handling)
9. [Logging and Reporting](#9-logging-and-reporting)

---

## 1. Overview

QmlConcerto is a **composable workflow execution framework** for Qt 5.15 / QML. It models
multi-step operations as musical phrases that can be played, sequenced, and orchestrated
into larger compositions — hence the orchestral naming.

**Mental model:**
- A `Phrase` is a single executable operation (C++ class).
- A `Melody` is a container that holds child `Phrase` objects.
- Each child phrase has reactive properties — `after` (play on condition) and
  `finishOn` (stop on condition) — that can be bound to arbitrary QML expressions.
- `Sequence` and `Chord` are convenience QML components built on `Melody` that
  pre-wire common patterns: serial and parallel execution.
- For **any** execution graph (DAG, fan-out/fan-in, conditional branching), use
  a bare `Melody` with custom `after`/`finishOn` bindings.

The framework enforces a strict **state machine** at every level so that any
workflow — however deeply nested — exposes a uniform lifecycle interface.

---

## 2. Architecture

```
   C++ Layer                          QML Composition Layer
   ──────────────────────────         ────────────────────────────────
   Phrase  (abstract, Q_OBJECT)
     │
     └── Melody  (container)  ──────► Sequence.qml  (serial)
                                       Chord.qml     (parallel)

   ErrorEntry  (Q_GADGET value type)
   ErrorRegistry  (singleton QObject) ──► "ErrorRegistry" context property
   QQmlPropertyMap  ─────────────────►  "Errors" context property

   Report  (Q_GADGET value type)
```

### Two-layer design

| Layer | Responsibility |
|-------|---------------|
| C++ | State transitions, lifecycle guards, error storage, logging signals |
| QML | Orchestration logic (`after` bindings, completion detection, error propagation) |

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
| `Playing` | Executing. `_play()` is running or awaiting async result. |
| `Accompanying` | Playing on background. Opt-in for long-running phrases that complete their startup in `Playing`, then transition to `Accompanying` via `accompany()` to indicate ongoing background activity (e.g. services, listeners, monitors). The phrase remains alive until explicitly `finish()`ed or `abort()`ed. |
| `Paused` | Suspended. Reserved for future use. |
| `Resolved` | Terminal. Inspect `finalized` for the outcome. |

### Finalization outcomes

Once `Resolved`, the `finalized` property tells you why:

| Value | Set by | Meaning |
|-------|--------|---------|
| `None` | (initial) | Not yet finished. |
| `Consonant` | `finish()` with `NoError` | Completed successfully. |
| `Dissonant` | `finish(error)` with a real error | Completed with error. `lastError` is set. |
| `Aborted` | `abort()` | Manually stopped. |

### Reactive trigger properties

`Phrase` exposes four boolean properties that act as reactive triggers when bound
to QML expressions. Setting any of them to `true` fires the corresponding action
immediately.

| Property | Action when set to `true` | Binding use case |
|----------|--------------------------|-----------------|
| `after` | Calls `play()` | Start this phrase when a condition is met |
| `finishOn` | Calls `finish()` — resolves `Consonant` | Skip/short-circuit this phrase if condition holds |
| `abortOn` | Calls `abort()` — resolves `Aborted` | Cancel this phrase if a condition holds |
| `finishOnError` | Calls `finish(lastError)` when `lastError` is set to a non-`NoError` value | Auto-resolve `Dissonant` when any error is assigned |

`Sequence` and `Chord` use `after` bindings to chain execution:

```qml
phrases[i].after = Qt.binding(function() { return prev.state === Phrase.Resolved })
```

**`finishOn` pre-condition skip:** if `finishOn` is already `true` when `play()` is called,
the phrase resolves `Consonant` immediately *without* entering `Playing` or executing `_play()`.
Same for `abortOn` — it resolves `Aborted` without executing.

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

**File:** [`phrase.h`](phrase.h), [`phrase.cpp`](phrase.cpp)  
**Base:** `QObject`  
**Abstract:** yes (pure virtual `_play()`)

#### Properties

| Property | Type | Access | Notify signal |
|----------|------|--------|---------------|
| `state` | `State` | read-only from QML | `stateChanged()` |
| `finalized` | `Finalized` | read-only from QML | `finalizedChanged()` |
| `after` | `bool` | read/write | `afterChanged()` |
| `finishOn` | `bool` | read/write | `finishOnChanged()` |
| `abortOn` | `bool` | read/write | `abortOnChanged()` |
| `finishOnError` | `bool` | read/write | `finishOnErrorChanged()` |
| `lastError` | `ErrorEntry` | read/write | `lastErrorChanged()` |
| `title` | `QString` | read/write | `titleChanged()` |
| `lyric` | `QString` | read/write | `lyricChanged()` |

> **Note:** `state` and `finalized` are writable from C++ via `setState()` / `setFinalized()`,
> but have no `WRITE` accessor exposed to QML — they are framework-controlled.

#### Enumerations

```cpp
enum State    { Silent, Playing, Accompanying, Paused, Resolved };
enum Finalized{ None, Aborted, Dissonant, Consonant };
```

#### Public slots

| Slot | Signature | Description |
|------|-----------|-------------|
| `play` | `bool play()` | Resets finalization, transitions to `Playing`, emits `enter()`, calls `_play()`. Returns `false` if already `Playing`. |
| `finish` | `void finish(const ErrorEntry &error = NoError)` | Transitions to `Resolved`. Sets `Consonant` if `error == NoError`, otherwise `Dissonant`. Effective while `Playing` or `Accompanying`. |
| `abort` | `void abort()` | Transitions to `Resolved` with `Aborted`. Effective while `Playing` or `Accompanying`. |
| `accompany` | `void accompany()` | Transitions from `Playing` to `Accompanying`. Used by long-running phrases to signal they are done with startup but remain active in the background. Only effective while `Playing`. |
| `reset` | `void reset()` | Resets the phrase back to `Silent` with `finalized = None` and `lastError = NoError`. For `Melody` subclasses, also resets all child phrases. |
| `info` | `void info(QString msg)` | Emits `report()` at `Info` level. |
| `warning` | `void warning(QString msg)` | Emits `report()` at `Warning` level. |
| `error` | `void error(ErrorEntry)` | Emits `report()` at `Error` level with the entry's formatted text. |

#### Signals

| Signal | When emitted |
|--------|-------------|
| `stateChanged()` | Every state transition |
| `finalizedChanged()` | When `finalized` changes (just before `stateChanged` on resolution) |
| `enter()` | Immediately after transitioning to `Playing` (inside `play()`) |
| `exit()` | Immediately when `finalized` is first set (before `Resolved`) |
| `afterChanged()` | When `after` changes |
| `finishOnChanged()` | When `finishOn` changes |
| `abortOnChanged()` | When `abortOn` changes |
| `finishOnErrorChanged()` | When `finishOnError` changes |
| `lastErrorChanged()` | When `lastError` changes |
| `titleChanged()` | When `title` changes |
| `lyricChanged()` | When `lyric` changes |
| `report(Report)` | Structured log event |

#### Protected interface (for subclasses)

```cpp
virtual bool _play() = 0;
// Start your work here. Return true. Call finish() or abort() when done.

void log_signal(const QString &signalName, const QVariant &data = QVariant());
// Emit a Debug-level report naming a signal event.

Report make_report();
// Factory: returns a Report pre-filled with timestamp and source path.

void setParentPath(QString p);
// Set the hierarchy path used in report source strings.
```

#### `play()` execution order

```
play() called
  1. Guard: return false if already Playing
  2. setFinalized(None)        → emits exit() + finalizedChanged()
  3. setState(Playing)         → emits stateChanged()
  4. emit enter()
  5. _play()                   ← subclass takes over here
     └─ eventually calls finish() or abort()
           6. setFinalized(Consonant|Dissonant|Aborted) → emits exit() + finalizedChanged()
           7. setLastError(error)
           8. setState(Resolved)   → emits stateChanged()
```

---

### 4.2 Report

**File:** [`phrase.h`](phrase.h)  
**Type:** `Q_GADGET` (value type, not `QObject`)

Structured log event emitted by `Phrase::report(Report)`.

#### Fields

| Field | Type | Description |
|-------|------|-------------|
| `source` | `QString` | Hierarchical source path: `"parentPath/phraseTitle"` |
| `category` | `QString` | Severity string (matches `Category` enum name) |
| `message` | `QString` | Human-readable message |
| `data` | `QVariant` | Optional attached payload |
| `timestamp` | `QDateTime` | When the event occurred |

#### Category enum

```cpp
enum Category { Info, Warning, Error, Debug, Critical };
```

---

### 4.3 Melody

**File:** [`melody.h`](melody.h), `melody.cpp`  
**Base:** `Phrase`, `QQmlParserStatus`

Container `Phrase`. Exposes children as `QQmlListProperty<Phrase>` with
`DefaultProperty` so child items in QML are automatically appended to `phrases`.

#### Properties

| Property | Type | ClassInfo |
|----------|------|-----------|
| `phrases` | `QQmlListProperty<Phrase>` | `DefaultProperty` |

#### Methods

| Method | Description |
|--------|-------------|
| `QQmlListProperty<Phrase> phrases()` | QML-accessible list of child phrases |
| `QList<Phrase*> phraseList() const` | C++ access to children |

#### `_play()` implementation

```cpp
bool Melody::_play() {
    emit enter();   // signals QML compositions (Sequence, Chord) to begin
    return true;
}
```

Melody's `_play()` only emits `enter()`. The actual orchestration is handled
by `Sequence.qml` and `Chord.qml` via their `onEnter:` handlers.

---

### 4.4 ErrorEntry

**File:** [`errorsregistry.h`](errorsregistry.h)  
**Type:** `Q_GADGET`, `Q_DECLARE_METATYPE`

Value type representing a single error definition.

#### QML-exposed properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | `QString` | Module identifier (e.g. `"APP"`, `"CDM"`) |
| `code` | `int` | Numeric error code |
| `description` | `QString` | Human-readable message |
| `valid` | `bool` | `true` if `name` is non-empty |
| `text` | `QString` | Formatted: `"[source] (code) description"` |

#### Constructors

```cpp
// Self-registering — use for static definitions in header files
ErrorEntry("session_xpr", "APP", -1001, "Session expired");

// Non-registering — used internally by ErrorRegistry::create()
ErrorEntry(name, source, code, description, ErrorEntryNoRegTag{});

// Default — creates invalid entry (valid == false)
ErrorEntry();
```

#### Built-in sentinel

```cpp
inline ErrorEntry NoError("no_error", "APP", 0, "No error");
```

Pass `NoError` to `finish()` (or call `finish()` with no arguments) to signal success.

---

### 4.5 ErrorRegistry

**File:** [`errorsregistry.h`](errorsregistry.h)  
**Type:** Meyers singleton `QObject`  
**QML context property:** `"ErrorRegistry"`

#### Accessing from QML

Two context properties are registered in `main.cpp`:

```cpp
engine.rootContext()->setContextProperty("ErrorRegistry",
                                         &ErrorRegistry::instance());
engine.rootContext()->setContextProperty("Errors",
                                         ErrorRegistry::instance().map());
```

| Context property | Type | Use |
|-----------------|------|-----|
| `ErrorRegistry` | `ErrorRegistry*` | Method calls |
| `Errors` | `QQmlPropertyMap*` | Symbolic property access |

#### Q_INVOKABLE methods (callable from QML and C++)

| Method | Signature | Description |
|--------|-----------|-------------|
| `create` | `void create(name, source, code, description)` | Register a new error. |
| `declare` | `void declare(QVariantMap def)` | Register from a JS object literal: `{ name, source, code, description }`. |
| `lookup` | `QVariant lookup(int code)` | Find `ErrorEntry` by numeric code. Returns invalid entry if not found. |
| `lookupByName` | `QVariant lookupByName(QString name)` | Find `ErrorEntry` by name. |
| `describe` | `QString describe(int code)` | Formatted description string for a code. |
| `contains` | `bool contains(int code)` | Check if code is registered. |
| `containsName` | `bool containsName(QString name)` | Check if name is registered. |

#### QML usage examples

```qml
// Symbolic access via property map
console.log(Errors.session_xpr.code)        // -1001
console.log(Errors.session_xpr.description) // "Session expired"
console.log(Errors.session_xpr.text)        // "[APP] (-1001) Session expired"

// Pass to finish()
finish(Errors.session_xpr)

// Lookup by code
var e = ErrorRegistry.lookup(-1001)    // returns QVariant<ErrorEntry>

// Register at runtime from QML
ErrorRegistry.declare({
    name: "shutter_stuck",
    source: "CDM",
    code: -2001,
    description: "Shutter mechanism stuck"
})
```

---

## 5. QML Components

`Sequence` and `Chord` are convenience components built on `Melody`. They are in
`notes.qrc` and available without an explicit `import` path.

Both are pre-wired patterns of the generic mechanism: **`Melody` + `after`/`finishOn` bindings**.
For custom execution graphs, see [§5.3 Free-style Melody](#53-free-style-melody).

### 5.1 Sequence

**File:** [`Sequence.qml`](Sequence.qml)  
**Base:** `Melody`

Executes child phrases **serially**. Each phrase starts only after the previous one
reaches `Resolved`. The last phrase's finalization (and error, if any) propagates to
the `Sequence` itself.

#### Full source

```qml
import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root

    finishOn: phrases.length > 0 && (
            phrases[phrases.length - 1].state === Phrase.Resolved ||
            (root.finishOnError && root.lastError.code !== Errors.no_error.code)
        )

    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            if (i === 0) {
                // First phrase starts when the Melody (root) starts playing
                currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);
            } else {
                // Subsequent phrases depend on the previous one
                let previousPhrase = phrases[i - 1];
                currentPhrase.after = Qt.binding(() => previousPhrase.state === Phrase.Resolved);
            }

            // Connect signal
            currentPhrase.onFinalizedChanged.connect(() => {
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    root.lastError = currentPhrase.lastError;
                }
            });
        }
    }
}
```

#### Execution flow

```
Component.onCompleted fires (QML tree fully loaded)
  → for each phrases[i]:
       i === 0: bind after to (root.state === Playing)
       i > 0:   bind after to (phrases[i-1].state === Resolved)
       connect onFinalizedChanged → propagate errors to root.lastError

Sequence.play()
  → state = Playing
  → enter() emitted
  → phrases[0].after becomes true (root.state === Playing)  → plays immediately
  → phrases[0] resolves
  → phrases[1].after becomes true (phrases[0].state === Resolved)  → plays
  → ...
  → last phrase resolves
       onFinalizedChanged propagates error if Dissonant
       finishOn binding evaluates to true
       root.finish() called with lastError or NoError
  → Sequence state = Resolved
```

**Error behavior:** each child phrase propagates its `Dissonant` error to the Sequence's
`lastError`. If `finishOnError` is enabled on the Sequence, it will resolve immediately
when any child reports an error. Otherwise, the Sequence completes when the last phrase
resolves, carrying the last error encountered.

---

### 5.2 Chord

**File:** [`Chord.qml`](Chord.qml)  
**Base:** `Melody`

Executes all child phrases **in parallel**. Resolves when every child reaches `Resolved`.
If any child finishes with `Dissonant`, the `Chord` propagates that error.

#### Full source

```qml
import QtQuick 2.15
import Concerto 1.0

Melody {
    id: root

    // Logic: The Chord is finished when all phrases are Resolved.
    finishOn: {
        if (!phrases || phrases.length === 0) return true;

        let allResolved = true;
        for (let i = 0; i < phrases.length; ++i) {
            if (phrases[i].state !== Phrase.Resolved) {
                allResolved = false;
                break;
            }
        }
        return allResolved;
    }

    Component.onCompleted: {
        if (phrases.length === 0) return;

        for (let i = 0; i < phrases.length; i++) {
            let currentPhrase = phrases[i];

            // 1. All phrases start simultaneously when the root starts
            currentPhrase.after = Qt.binding(() => root.state === Phrase.Playing);

            // 2. Monitor for errors
            currentPhrase.onFinalizedChanged.connect(() => {
                if (currentPhrase.finalized === Phrase.Dissonant) {
                    // Capture the error so the Melody component can handle failure
                    root.lastError = currentPhrase.lastError;
                }
            });
        }
    }
}
```

#### Execution flow

```
Component.onCompleted fires (QML tree fully loaded)
  → for each phrases[i]:
       bind after to (root.state === Playing)
       connect onFinalizedChanged → propagate errors to root.lastError

Chord.play()
  → state = Playing
  → enter() emitted
  → all phrases[i].after become true (root.state === Playing)  → all play simultaneously
  → as each phrase resolves:
       onFinalizedChanged propagates error if Dissonant
       finishOn binding re-evaluates
       when all phrases are Resolved:
           finishOn returns true
           Chord.finish() called with lastError or NoError
  → Chord state = Resolved
```

**Error behavior:** each `Dissonant` child propagates its error to the Chord's `lastError`.
The Chord resolves only when *all* children have resolved (no early-exit). The last error
written to `root.lastError` is the one carried by the Chord's finalization.

---

### 5.3 Free-style Melody

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
  stepA.after → true                    → A plays
  A resolves
  stepB.after → true, stepC.after → true → B and C play in parallel
  B resolves, C resolves
  stepD.after → true                    → D plays
  D resolves
  flow.finishOn → true                  → Melody resolves Consonant
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

    finishOn: (update.state === Phrase.Resolved || skip.state === Phrase.Resolved)
}
```

#### How `after` and `finishOn` work under the hood

Both are reactive boolean properties. When their binding evaluates to `true`,
the corresponding action fires immediately inside the property's WRITE method:

```cpp
// Inside phrase.cpp — simplified
void Phrase::setAfter(bool newAfter) {
    m_after = newAfter;
    if (m_after) play();       // ← triggers play() when binding becomes true
    emit afterChanged();
}

void Phrase::setFinishOn(bool newFinishOn) {
    m_finishOn = newFinishOn;
    if (m_finishOn) finish();  // ← triggers finish() when binding becomes true
    emit finishOnChanged();
}
```

This means you can bind them to **any** QML expression — they are not limited
to state checks. For example:

```qml
MyPhrase {
    after: sensor.temperature > 30       // play when sensor threshold crossed
    finishOn: timer.expired              // stop when timer expires
}
```

---

## 6. Adding a Custom Phrase

### Step 1 — Subclass `Phrase` in C++

```cpp
// mycommand.h
#pragma once
#include "phrase.h"
#include <QTimer>

class MyCommand : public Phrase
{
    Q_OBJECT
    Q_PROPERTY(QString target READ target WRITE setTarget NOTIFY targetChanged)

public:
    explicit MyCommand(QObject *parent = nullptr);

    QString target() const;
    void setTarget(const QString &t);

signals:
    void targetChanged();

protected:
    bool _play() override;

private:
    QString m_target;
    QTimer  m_timer;
};
```

### Step 2 — Implement `_play()`

```cpp
// mycommand.cpp
#include "mycommand.h"

MyCommand::MyCommand(QObject *parent) : Phrase(parent)
{
    // Wire async completion back to finish()
    connect(&m_timer, &QTimer::timeout, this, [this]() {
        if (m_target.isEmpty()) {
            static ErrorEntry e("bad_target", "APP", -5001, "No target specified");
            finish(e);
        } else {
            info(QString("MyCommand completed for %1").arg(m_target));
            finish();          // success
        }
    });
    m_timer.setSingleShot(true);
}

bool MyCommand::_play()
{
    info(QString("Starting MyCommand on %1").arg(m_target));
    m_timer.start(200);   // simulate async work
    return true;          // _play() must return true
}

QString MyCommand::target() const { return m_target; }
void MyCommand::setTarget(const QString &t)
{
    if (m_target == t) return;
    m_target = t;
    emit targetChanged();
}
```

### Step 3 — Register the type

```cpp
// main.cpp — inside registerQmlTypes()
qmlRegisterType<MyCommand>("MyApp", 1, 0, "MyCommand");
```

### Step 4 — Use in QML

```qml
import QtQuick 2.15
import QtQuick.Window 2.15
import MyApp 1.0

Window {
    width: 640; height: 480; visible: true

    Sequence {
        id: flow
        Component.onCompleted: flow.play()

        onFinalizedChanged: {
            if (finalized === Phrase.Consonant)
                console.log("All done")
            else if (finalized === Phrase.Dissonant)
                console.error("Failed:", lastError.text)
        }

        MyCommand { title: "Step 1"; target: "deviceA" }
        MyCommand { title: "Step 2"; target: "deviceB" }
    }
}
```

---

## 7. Workflow Composition Patterns

> **All patterns below are built on the same reactive mechanism:** `after` (play on condition)
> and `finishOn` (stop on condition). `Sequence` and `Chord` are convenience wrappers.
> For custom DAGs and conditional branching, see [§5.3 Free-style Melody](#53-free-style-melody).

### Free-style execution (most generic)

```qml
Melody {
    id: flow
    Component.onCompleted: flow.play()

    StepA { id: a; after: flow.state === Phrase.Playing }
    StepB { id: b; after: a.state === Phrase.Resolved }
    StepC { id: c; after: a.state === Phrase.Resolved }   // parallel with B
    StepD { id: d; after: b.state === Phrase.Resolved &&
                         c.state === Phrase.Resolved }    // fan-in

    finishOn: d.state === Phrase.Resolved
}
```

### Serial execution (convenience)

```qml
Sequence {
    StepA { }
    StepB { }
    StepC { }
    // A → B → C, one at a time
}
```

### Parallel execution

```qml
Chord {
    FetchUsers    { }
    FetchSettings { }
    FetchLicense  { }
    // All three run concurrently; resolves when all finish
}
```

### Parallel groups in series (most common ATM pattern)

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

### Reacting to outcomes

```qml
Sequence {
    id: workflow
    Component.onCompleted: workflow.play()

    onFinalizedChanged: {
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

### Triggering a sequence from an event

```qml
Button {
    onClicked: dispenseFlow.play()
}

Sequence {
    id: dispenseFlow
    // ...
}
```

---

## 8. Error Handling

### Declaring errors

**Option A — Static C++ definition (recommended for module-level errors)**

```cpp
// In a header file included by the module
static ErrorEntry ERR_SHUTTER_STUCK("shutter_stuck", "CDM", -2001,
                                    "Shutter mechanism stuck");
```

The self-registering constructor adds the entry to `ErrorRegistry` automatically on first use.

**Option B — Dynamic C++ registration**

```cpp
ErrorRegistry::instance().create("session_xpr", "APP", -1001, "Session expired");
```

**Option C — From QML (runtime)**

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

### Passing errors to `finish()`

```qml
// In a custom Phrase or JS handler:
finish(Errors.shutter_stuck)       // Dissonant, lastError = shutter_stuck entry

// Or from C++ _play():
finish(ERR_SHUTTER_STUCK);
```

### Error propagation through Sequence

`Sequence` watches the *last* phrase and propagates its error. If you need early abort:

```qml
Sequence {
    PhaseA {
        onFinalizedChanged: {
            if (finalized === Phrase.Dissonant)
                parent.abort()    // abort the whole Sequence
        }
    }
    PhaseB { }
}
```

### Error propagation through Chord

`Chord` reports the first `Dissonant` child's error after *all* children resolve.
There is no early-exit in the current implementation.

---

## 9. Logging and Reporting

### Emitting from a custom Phrase

```cpp
bool MyCommand::_play()
{
    info("Starting command");          // Report::Info
    warning("Target looks odd");       // Report::Warning

    if (someFailure)
        error(ERR_SHUTTER_STUCK);      // Report::Error (does NOT call finish)

    finish(ERR_SHUTTER_STUCK);         // call finish() separately to resolve
    return true;
}
```

> `error(entry)` logs the report but does **not** transition state.
> You must still call `finish(entry)` to resolve the phrase.

### Connecting the `report` signal

```cpp
// C++ — forward all reports to qDebug
connect(&myPhrase, &Phrase::report, [](const Report &r) {
    qDebug() << r.timestamp.toString("hh:mm:ss.zzz")
             << r.source << r.category << r.message;
});
```

```qml
// QML — forward reports from a Sequence to a ListView model
Sequence {
    id: flow
    onReport: function(r) {
        logModel.append({ time: r.timestamp, msg: r.source + ": " + r.message })
    }
    // ...
}
```

### Report fields quick reference

| Field | Type | Example value |
|-------|------|---------------|
| `source` | `QString` | `"/MyFlow/StepA"` |
| `category` | `QString` | `"Info"`, `"Warning"`, `"Error"`, `"Debug"`, `"Critical"` |
| `message` | `QString` | `"Starting command"` |
| `data` | `QVariant` | optional attached data |
| `timestamp` | `QDateTime` | `2026-04-22 14:03:12.045` |
