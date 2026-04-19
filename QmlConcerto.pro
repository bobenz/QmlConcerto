TARGET = MyConcertoApp
TEMPLATE = app

# Include the module
include(concerto.pri)

# Only keep app-specific sources here
SOURCES += main.cpp

# Deployment and other app-level configs
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
