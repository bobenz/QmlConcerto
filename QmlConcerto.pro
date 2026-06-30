TARGET   = QmlConcerto
TEMPLATE = lib
CONFIG  += plugin c++17

win32:CONFIG(debug, debug|release): DESTDIR = $$PWD/lib/debug
else:                                DESTDIR = $$PWD/lib/release

# Export macro so all classes get Q_DECL_EXPORT when building the DLL
DEFINES += QMLCONCERTO_LIBRARY

# Shared module sources, headers, and resources
include(concerto.pri)

# Plugin entry point
HEADERS += ConcertoPlugin.h
SOURCES += ConcertoPlugin.cpp

# Local deploy folder: <project>/deploy/Concerto/
# Run "nmake install" (or "make install") after building to populate it.
# Qt DLLs are assumed to reside at ../qt relative to this project.
CNGO_DIR = C:/CnGO

# "nmake install" deploys the DLL + QML files to the ATM target directory
target.path       = $$CNGO_DIR/Concerto
qmldir_file.files = $$PWD/qmldir
qmldir_file.path  = $$CNGO_DIR/Concerto
qml_files.files   = $$PWD/Sequence.qml \
                    $$PWD/Chord.qml \
                    $$PWD/Cadenza.qml \
                    $$PWD/Reprisa.qml \
                    $$PWD/Sonata.qml \
                    $$PWD/MelodyPolicies.qml
qml_files.path    = $$CNGO_DIR/Concerto
INSTALLS += target qmldir_file qml_files
