# Ensure C++17 and required Qt modules are present in the parent project
QT += quick qml
CONFIG += c++17

# Define the include path so the parent project can find headers easily
INCLUDEPATH += $$PWD

# RegRep supplies the generalized constants registry (ConstantEntry/ConstantRegistry)
# and the reporting pipeline (Report/Reporter/ReportRouter/ReportsReceiver) — linked as a
# shared library (build RegRep.pro first) rather than source-included, so ConstantRegistry/
# ReportRouter are guaranteed to be true process-wide singletons even if more than one
# consumer of this .pri ends up loaded in the same process.
include($$PWD/../RegRep/regrep_dll.pri)

# Header files
HEADERS += \
    $$PWD/errorsregistry.h \
    $$PWD/melody.h \
    $$PWD/partitura.h \
    $$PWD/pause.h \
    $$PWD/phrase.h \
    $$PWD/quote.h \
    $$PWD/concerto_registration.h

# Source files
SOURCES += \
    $$PWD/melody.cpp \
    $$PWD/partitura.cpp \
    $$PWD/pause.cpp \
    $$PWD/quote.cpp \
    $$PWD/phrase.cpp

# Resources
RESOURCES += \
    $$PWD/notes.qrc

# QML files and module descriptor — listed so Qt Creator shows them in the project tree
DISTFILES += \
    $$PWD/qmldir \
    $$PWD/Sequence.qml \
    $$PWD/Chord.qml \
    $$PWD/Cadenza.qml \
    $$PWD/Reprisa.qml \
    $$PWD/Sonata.qml \
    $$PWD/MelodyPolicies.qml

DEFINES += "CONCERTO_HOME=\\\"$$PWD\\\""