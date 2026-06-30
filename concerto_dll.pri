QT      += quick qml
CONFIG  += c++17
INCLUDEPATH += $$PWD
DEFINES     += "CONCERTO_HOME=\\\"$$PWD\\\"" QMLCONCERTO_DLL

# ── Deploy root — change once here, propagates everywhere ────────────────────
CNGO_QT_DIR = C:/CnGO/qt5

# QmlConcerto.lib sits in the Concerto QML module folder alongside the DLL
LIBS += -L$$CNGO_QT_DIR/Concerto -lQmlConcerto
