QT      += quick qml
CONFIG  += c++17
INCLUDEPATH += $$PWD
DEFINES     += "CONCERTO_HOME=\\\"$$PWD\\\"" QMLCONCERTO_DLL

# Link against the import lib in the source-relative lib/ folder.
# Build QmlConcerto first so lib/debug or lib/release is populated.
win32:CONFIG(debug, debug|release) {
    LIBS += -L$$PWD/lib/debug   -lQmlConcerto
} else {
    LIBS += -L$$PWD/lib/release -lQmlConcerto
}

# ── Deploy root — change once here, propagates to all plugin DESTDIRs ────────
CNGO_DIR = C:/CnGO
