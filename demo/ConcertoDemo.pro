QT += quick qml quickcontrols2
CONFIG += c++17

TEMPLATE = app
TARGET = ConcertoDemo

# A console alongside the GUI window in Debug builds only, so plugin-load
# warnings (see main.cpp) are actually visible while diagnosing deploy issues.
CONFIG(debug, debug|release): CONFIG += console

# No dependency on Concerto/RegRep sources or their .pri files — this demo only
# ever talks to them through QML (`import Concerto 1.0` in main.qml), loading
# QmlConcerto.dll/RegRep.dll from the shared deploy tree at runtime exactly like
# a real downstream consumer would (see ../BUILD_DEPLOYMENT_CONVENTIONS.md).
SOURCES += main.cpp

RESOURCES += demo.qrc

DISTFILES += main.qml
