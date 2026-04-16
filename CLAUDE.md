# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This project uses **qmake** (not CMake). Build via Qt Creator or command line:

```bash
qmake QmlConcerto.pro
make           # Linux/macOS
nmake          # Windows MSVC
```

Target platform: **Windows x86 (32-bit), MSVC 2022, Qt 5.15** (with Qt 6 compatibility layer in `main.cpp`).

Build artifacts land in `build/x86_windows_msvc2022_pe_32bit-Debug/`.

## Architecture

QmlConcerto implements an **orchestral execution model**: C++ defines stateful `Phrase` objects and QML composes them into workflows using `Sequence` and `Chord`.

### Core C++ Classes

**`Phrase`** (`phrase.h/cpp`) — Abstract base for all executable units. Implements a state machine:
- States: `Silent → Playing → Paused → Resolved`
- Terminal finalization: `Consonant` (success), `Dissonant` (error), `Aborted`, `None`
- Pure virtual `_play()` must be implemented by subclasses
- `after` property enables binding-based sequencing between phrases
- Emits `report` signal for structured logging (Info/Warning/Error/Debug/Critical)

**`Melody`** (`melody.h/cpp`) — Extends `Phrase`, implements `QQmlParserStatus`. Container for child `Phrase` objects exposed via a `phrases` QML default property (`QQmlListProperty`). Subclasses must implement `_play()`.

**`ErrorRegistry`** (`errorsregistry.h`) — Singleton error namespace. Two QML context properties:
- `ErrorRegistry` — object with methods: `create()`, `declare()`, `lookup(code)`, `lookupByName()`, `describe()`
- `Errors` — `QQmlPropertyMap` for symbolic access: `Errors.session_xpr.code`

`ErrorEntry` is a `Q_GADGET` carrying source, code, and description. `ErrorRegistry::NoError` (code 0) is the neutral result.

### QML Composition Layer

**`Sequence.qml`** — Executes child phrases serially. Each phrase starts only after the previous reaches `Resolved`. The last phrase's finalization propagates to the `Sequence`.

**`Chord.qml`** — Executes all child phrases in parallel. Resolves when all children resolve. Any `Dissonant` child makes the entire `Chord` dissonant.

### Key Design Patterns

- **Template Method**: `Phrase._play()` is pure virtual; `play()` manages state transitions
- **Composite**: `Melody` contains `Phrase` children, is itself a `Phrase`
- **Reactive binding**: `Qt.binding()` in QML connects phrase lifecycle events declaratively
- **Singleton registry**: `ErrorRegistry::instance()` provides a global error namespace

### Adding a New Phrase Subclass

1. Subclass `Phrase` (atomic) or `Melody` (container) in C++
2. Override `_play()`; call `finish(ErrorEntry)` when done
3. Register the type with `qmlRegisterType` or expose via context property
4. Use in QML inside a `Sequence` or `Chord`
