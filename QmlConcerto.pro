TARGET   = QmlConcerto
TEMPLATE = lib
CONFIG  += plugin c++17

# Import lib (.lib) — link-time only, stays in the source tree
win32:CONFIG(debug, debug|release): DESTDIR = $$PWD/lib/debug
else:                                DESTDIR = $$PWD/lib/release

# DLL — goes to C:/CnGO/qml/Concerto/ so the QML module is isolated
# from XfsEngine plugins (both live under C:/CnGO but in separate subtrees).
# qt.conf for the monolithic exe points to C:/CnGO/qml — finds Concerto only.
# qt.conf for the ATM plugin host points to C:/CnGO — finds Concerto + XfsEngine.
DLLDESTDIR = C:/CnGO/qml/Concerto

# Also copy to XfsEngine so Windows finds it when loading xfsengine_*.dll
QMAKE_POST_LINK += && $(COPY_FILE) \
    $$shell_quote($$shell_path($$DLLDESTDIR/QmlConcerto.dll)) \
    $$shell_quote($$shell_path(C:/CnGO/XfsEngine/))

# Export macro so all classes get Q_DECL_EXPORT when building the DLL
DEFINES += QMLCONCERTO_LIBRARY

# Shared module sources, headers, and resources
include(concerto.pri)

# Plugin entry point
HEADERS += ConcertoPlugin.h
SOURCES += ConcertoPlugin.cpp

# Copy qmldir + QML files alongside the DLL on every build
qmldir_copy.files = $$PWD/qmldir
qmldir_copy.path  = C:/CnGO/qml/Concerto
COPIES += qmldir_copy

qml_files_copy.files = \
    $$PWD/Sequence.qml \
    $$PWD/Chord.qml \
    $$PWD/Cadenza.qml \
    $$PWD/Reprisa.qml \
    $$PWD/Sonata.qml \
    $$PWD/MelodyPolicies.qml
qml_files_copy.path = C:/CnGO/qml/Concerto
COPIES += qml_files_copy
