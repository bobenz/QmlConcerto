QT      += quick qml
CONFIG  += c++17
INCLUDEPATH += $$PWD
DEFINES     += "CONCERTO_HOME=\\\"$$PWD\\\"" QMLCONCERTO_DLL

# Deploy root — see deploy.pri for CNGO_DIR/DEPLOY_ROOT/DEPLOY_LIB_DIR.
include($$PWD/deploy.pri)

# Link against the import lib in the shared deploy tree — QmlConcerto.pro's own
# post-link step puts QmlConcerto.lib/.dll there, so build QmlConcerto first.
LIBS += -L$$DEPLOY_LIB_DIR -lQmlConcerto

# QmlConcerto.dll itself links against RegRep.dll rather than containing it (see
# concerto.pri) — pull in RegRep's include path/link flags/DLL-copy too so consumers
# of QmlConcerto.dll that also touch RegRep types (e.g. ConstantEntry, Reporter)
# directly don't need to know RegRep exists as a separate step.
include($$PWD/../RegRep/regrep_dll.pri)
