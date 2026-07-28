QT += testlib qml quick
CONFIG -= app_bundle
CONFIG +=  qmltestcase
TEMPLATE = app

include(../concerto.pri)

DEFINES += SRCDIR=\\\"$$PWD\\\"

SOURCES += main.cpp

DISTFILES += \
    tst/tst_Phrase.qml \
    tst/tst_Pause.qml \
    tst/tst_Quote.qml \
    tst/tst_Sequence.qml \
    tst/tst_Chord.qml \
    tst/tst_Cadenza.qml \
    tst/tst_Reprisa.qml \
    tst/tst_Sonata.qml \
    tst/tst_ErrorRegistry.qml \
    tst/tst_Partitura.qml \
    tst/tst_MelodyPolicies.qml \
    tst/tst_FreestyleMelody.qml
