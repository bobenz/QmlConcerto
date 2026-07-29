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

# QmlConcerto.dll itself links against RegRep.dll rather than containing it (see
# concerto.pri) — pull in RegRep's include path/link flags/DLL-copy too so consumers
# of QmlConcerto.dll that also touch RegRep types (e.g. ConstantEntry, Reporter)
# directly don't need to know RegRep exists as a separate step.
include($$PWD/../RegRep/regrep_dll.pri)

# ── Deploy root — see deploy.pri for CNGO_DIR/DEPLOY_ROOT/DEPLOY_LIB_DIR ──────
include($$PWD/deploy.pri)
