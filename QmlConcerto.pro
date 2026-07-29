TARGET   = QmlConcerto
TEMPLATE = lib
CONFIG  += plugin c++17

# Import lib (.lib) — link-time only, stays in the source tree
win32:CONFIG(debug, debug|release): DESTDIR = $$PWD/lib/debug
else:                                DESTDIR = $$PWD/lib/release

# RegRep.dll is a runtime dependency now (linked, not source-included — see
# concerto.pri) — still needs to reach C:\CnGO\XfsEngine\ alongside QmlConcerto.dll
# for that separate, unrelated XfsEngine loader (XfsEngine.Base/.Comm depend on
# Concerto). This flat copy is a fixed, hardcoded XfsEngine expectation, kept as-is
# regardless of CNGO_DIR — see deploy.pri below for the real, consolidated deploy tree.
win32:CONFIG(debug, debug|release) {
    _DLL = $$shell_path($$PWD/lib/debug/$${TARGET}.dll)
    _REGREP_DLL = $$shell_path($$PWD/../RegRep/lib/debug/RegRep.dll)
} else {
    _DLL = $$shell_path($$PWD/lib/release/$${TARGET}.dll)
    _REGREP_DLL = $$shell_path($$PWD/../RegRep/lib/release/RegRep.dll)
}

# Deploy: QmlConcerto.dll + RegRep.dll -> $$DEPLOY_LIB_DIR (every plugin DLL, one
# place). RegRep.dll is already sitting in local lib/... thanks to regrep_dll.pri's
# own copy-to-DESTDIR. Both DLL copies (XfsEngine + the deploy tree) MUST be
# QMAKE_POST_LINK, not COPIES — COPIES treats its .files as static pre-existing
# sources, and pointing it at this project's own just-built DLL creates a
# dependency cycle ("cycle in dependency tree for target ...dll").
include(deploy.pri)

QMAKE_POST_LINK = cmd /c \
    "copy /y $$shell_path($$_DLL) C:\CnGO\XfsEngine\ \
    && copy /y $$_REGREP_DLL C:\CnGO\XfsEngine\ \
    && (if not exist $$shell_path($$DEPLOY_LIB_DIR) mkdir $$shell_path($$DEPLOY_LIB_DIR)) \
    && copy /y $$shell_path($$_DLL) $$shell_path($$DEPLOY_LIB_DIR) \
    && copy /y $$_REGREP_DLL $$shell_path($$DEPLOY_LIB_DIR)\\"

# Export macro so all classes get Q_DECL_EXPORT when building the DLL
DEFINES += QMLCONCERTO_LIBRARY

# Shared module sources, headers, and resources
include(concerto.pri)

# Plugin entry point
HEADERS += ConcertoPlugin.h
SOURCES += ConcertoPlugin.cpp

# qmldir + the six QML composition files -> $$DEPLOY_ROOT/Concerto/ (its "plugin
# QmlConcerto ../lib" line points back at $$DEPLOY_LIB_DIR). These are static
# source files (not build outputs), so COPIES is safe here.
concerto_qmldir_deploy.files = \
    $$PWD/qmldir \
    $$PWD/Sequence.qml \
    $$PWD/Chord.qml \
    $$PWD/Cadenza.qml \
    $$PWD/Reprisa.qml \
    $$PWD/Sonata.qml \
    $$PWD/MelodyPolicies.qml
concerto_qmldir_deploy.path = $$DEPLOY_ROOT/Concerto
COPIES += concerto_qmldir_deploy
