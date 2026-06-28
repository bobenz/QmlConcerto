# Ensure C++17 and required Qt modules are present in the parent project
QT += quick qml
CONFIG += c++17

# Define the include path so the parent project can find headers easily
INCLUDEPATH += $$PWD

# Header files
HEADERS += \
    $$PWD/qmlconcerto_global.h \
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