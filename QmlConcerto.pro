TARGET   = QmlConcerto
TEMPLATE = lib
CONFIG  += plugin c++17

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
DEPLOY_DIR = $$PWD/deploy/Concerto

target.path       = $$DEPLOY_DIR
qmldir_file.files = $$PWD/qmldir
qmldir_file.path  = $$DEPLOY_DIR
INSTALLS += target qmldir_file
