#pragma once
#include <QtCore/qglobal.h>

#ifndef QMLCONCERTO_EXPORT
#  if defined(QMLCONCERTO_LIBRARY)
#    define QMLCONCERTO_EXPORT Q_DECL_EXPORT   // building the DLL
#  elif defined(QMLCONCERTO_DLL)
#    define QMLCONCERTO_EXPORT Q_DECL_IMPORT   // consuming the DLL
#  else
#    define QMLCONCERTO_EXPORT                 // source-inclusion / static build
#  endif
#endif
