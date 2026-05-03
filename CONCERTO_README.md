# QmlConcerto

A **composable workflow execution framework** for Qt 5.15 / QML.

QmlConcerto models multi-step operations as musical phrases that can be played, sequenced, and orchestrated into larger compositions. C++ defines stateful `Phrase` objects; QML composes them into workflows using `Sequence` (serial) and `Chord` (parallel).

## Architecture

```
   C++ Layer                          QML Composition Layer
   ──────────────────────────         ────────────────────────────────
   Phrase  (abstract, Q_OBJECT)
     │
     └── Melody  (container)  ──────► Sequence.qml  (serial execution)
                                       Chord.qml     (parallel execution)

   ErrorEntry  (Q_GADGET value type)
   ErrorRegistry  (singleton QObject) ──► "ErrorRegistry" context property
   QQmlPropertyMap  ─────────────────►  "Errors" context property

   Report  (Q_GADGET value type)
```

| Layer | Responsibility |
|-------|---------------|
| **C++** | State transitions, lifecycle guards, error storage, logging signals |
| **QML** | Orchestration logic (`after` bindings, completion detection, error propagation) |

## Phrase State Machine

Every `Phrase` follows a strict lifecycle:

```
  Silent ──play()──► Playing ──finish()/abort()──► Resolved    ← standard flow
                        │
                    accompany()     ← opt-in, for long-running background phrases
                        │
                    Accompanying ──finish()/abort()──► Resolved
```

| State | Meaning |
|-------|---------|
| `Silent` | Initial / idle. Safe to call `play()`. |
| `Playing` | Executing. `_play()` is running or awaiting async result. |
| `Accompanying` | Playing on background. Opt-in for long-running phrases (services, listeners, monitors). |
| `Paused` | Suspended. Reserved for future use. |
| `Resolved` | Terminal. Inspect `finalized` for the outcome. |

| Finalized | Meaning |
|-----------|---------|
| `Consonant` | Completed successfully |
| `Dissonant` | Completed with error (`lastError` is set) |
| `Aborted` | Manually stopped |
| `None` | Not yet finished |

## Quick Start

### Build

This project uses **qmake** (not CMake). Build via Qt Creator or command line:

```bash
qmake QmlConcerto.pro
make           # Linux/macOS
nmake          # Windows MSVC
```

**Target platform:** Windows x86 (32-bit), MSVC 2022, Qt 5.15 (with Qt 6 compatibility layer).

Build artifacts land in `build/x86_windows_msvc2022_pe_32bit-Debug/`.

### Minimal Example

```qml
import QtQuick 2.15
import QtQuick.Window 2.15
import QmlConcerto 1.0

Window {
    width: 640; height: 480; visible: true

    Sequence {
        id: workflow
        Component.onCompleted: workflow.play()

        onFinalizedChanged: {
            if (finalized === Phrase.Consonant)
                console.log("All steps completed successfully")
            else if (finalized === Phrase.Dissonant)
                console.error("Failed:", lastError.text)
        }

        MyCommand { title: "Step 1"; target: "deviceA" }
        MyCommand { title: "Step 2"; target: "deviceB" }
    }
}
```

### Composing Workflows

The core reactive building blocks for all workflow composition are two properties on every `Phrase`:

| Property | Purpose | Behavior |
|----------|---------|----------|
| `after` | **Play on condition** | Bind a QML expression; when it evaluates to `true`, the phrase starts playing |
| `finishOn` | **Stop on condition** | Bind a QML expression; when it evaluates to `true`, the phrase resolves as `Consonant` |

#### Free-style execution (most generic)

Use a bare `Melody` with `after` and `finishOn` bindings on each child to express **any** execution graph:

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

This can express **any DAG** (fan-out, fan-in, conditional branching, etc.).

#### Serial execution — `Sequence`

A convenience wrapper over `Melody` that chains children one after another:

```qml
Sequence {
    StepA { }
    StepB { }
    StepC { }
    // A → B → C, one at a time
}
```

Equivalent to setting `after: prev.state === Phrase.Resolved` on each child.

#### Parallel execution — `Chord`

A convenience wrapper over `Melody` that starts all children simultaneously:

```qml
Chord {
    FetchUsers    { }
    FetchSettings { }
    FetchLicense  { }
    // All three run concurrently; resolves when all finish
}
```

Equivalent to setting `after: root.state === Phrase.Playing` on every child.

#### Mixed — parallel groups in series

Nest `Chord` inside `Sequence` (or vice versa) for complex workflows:

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

## Project Structure

```
QmlConcerto/
├── QmlConcerto.pro          # Application project file
├── concerto.pri             # Reusable module include (SOURCES, HEADERS, RESOURCES)
├── concerto_registration.h  # Convenience class for registering QML types
├── main.cpp                 # Application entry point, QML type registration
├── main.qml                 # Application window
├── phrase.h / phrase.cpp    # Phrase — abstract base class for all executable units
├── melody.h / melody.cpp    # Melody — container Phrase with child phrases
├── errorsregistry.h         # ErrorEntry (value type) + ErrorRegistry (singleton)
├── Sequence.qml             # Serial execution (Melody subclass)
├── Chord.qml                # Parallel execution (Melody subclass)
├── notes.qrc                # QML resources (Sequence.qml, Chord.qml)
├── qml.qrc                  # Application QML resources (main.qml)
├── CLAUDE.md                # AI assistant guidance
├── MANUAL.md                # Full API reference and developer manual
└── .gitignore
```

## Adding a Custom Phrase

1. **Subclass `Phrase`** (for atomic operations) or `Melody` (for containers) in C++
2. **Override `_play()`** — start your work here; call `finish()` or `abort()` when done
3. **Register the type** with `qmlRegisterType` in `main.cpp`
4. **Use in QML** inside a `Sequence` or `Chord`

See the [`MANUAL.md`](MANUAL.md) for the complete step-by-step guide with code examples.

## Error Handling

Errors are managed through a centralized `ErrorRegistry` singleton:

```qml
// Symbolic access via property map
Errors.session_xpr.code         // -1001
Errors.session_xpr.description  // "Session expired"

// Register at runtime from QML
ErrorRegistry.declare({
    name: "shutter_stuck",
    source: "CDM",
    code: -2001,
    description: "Shutter mechanism stuck"
})
```

## Logging

Every `Phrase` emits structured `Report` signals through its lifecycle:

```qml
Sequence {
    onReport: function(r) {
        console.log(r.timestamp, r.source, r.category, r.message)
    }
}
```

## Documentation

- **[`MANUAL.md`](MANUAL.md)** — Full API reference, workflow patterns, error handling, and logging
- **[`CLAUDE.md`](CLAUDE.md)** — AI assistant guidance for working with this codebase

## License

See [GitHub](https://github.com/bobenz/QmlConcerto) for repository details.