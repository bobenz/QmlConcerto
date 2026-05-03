# Ensure C++17 and required Qt modules are present in the parent project
QT += quick qml
CONFIG += c++17

# Define the include path so the parent project can find headers easily
INCLUDEPATH += \\\"$$PWD\\\"

# Header files
HEADERS += \
    $$PWD/errorsregistry.h \
    $$PWD/melody.h \
    $$PWD/phrase.h \
    $$PWD/concerto_registration.h

# Source files
SOURCES += \
    $$PWD/melody.cpp \
    $$PWD/phrase.cpp

# Resources
RESOURCES += \
    $$PWD/notes.qrc
