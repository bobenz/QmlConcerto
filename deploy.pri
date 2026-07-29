# Shared deployment root, consumed by QmlConcerto.pro (and RegRep.pro has its
# own identical copy — RegRep stays decoupled from QmlConcerto/CnGO by design,
# so this is duplicated rather than reached via a relative include).
# Override by setting the CNGO_DIR environment variable before running qmake;
# defaults to C:\CnGO. Debug builds deploy to a sibling root with a "d" suffix
# (C:\CnGOd) — two complete, independent trees — rather than a nested subdir,
# so each is self-contained: lib/ (every DLL) + one folder per QML module
# (qmldir only, pointing back at ../lib).
CNGO_DIR = $$(CNGO_DIR)
isEmpty(CNGO_DIR): CNGO_DIR = C:/CnGO

win32:CONFIG(debug, debug|release): DEPLOY_ROOT = $${CNGO_DIR}d
else:                                DEPLOY_ROOT = $$CNGO_DIR
DEPLOY_LIB_DIR = $$DEPLOY_ROOT/lib
