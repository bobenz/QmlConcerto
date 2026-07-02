TARGET   = QmlConcerto
TEMPLATE = lib
CONFIG  += plugin c++17

# Import lib (.lib) — link-time only, stays in the source tree
win32:CONFIG(debug, debug|release): DESTDIR = $$PWD/lib/debug
else:                                DESTDIR = $$PWD/lib/release

# DLL destinations — both copies done in one cmd /c "... && ..." so order is guaranteed.
# 1. build output  →  C:\CnGO\qml\Concerto\   (QML plugin location)
# 2. qml\Concerto  →  C:\CnGO\XfsEngine\       (so Windows finds it via XfsEngine loader)
win32:CONFIG(debug, debug|release): _DLL = $$shell_path($$PWD/lib/debug/$${TARGET}.dll)
else:                                _DLL = $$shell_path($$PWD/lib/release/$${TARGET}.dll)

QMAKE_POST_LINK = cmd /c \
    "copy /y $$shell_path($$_DLL) C:\CnGO\Concerto\ \
    && copy /y C:\CnGO\Concerto\QmlConcerto.dll C:\CnGO\XfsEngine\\"

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
