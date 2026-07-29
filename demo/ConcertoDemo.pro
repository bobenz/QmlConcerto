QT += quick qml quickcontrols2
CONFIG += c++17

TEMPLATE = app
TARGET = ConcertoDemo

include(../concerto.pri)

SOURCES += main.cpp

RESOURCES += demo.qrc

DISTFILES += main.qml
