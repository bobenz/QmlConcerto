#pragma once
// ============================================================================
//  errorsregistry.h — backward-compatible shim
//
//  ErrorEntry/ErrorRegistry were generalized into RegRep's ConstantEntry/
//  ConstantRegistry (adds a `type` field, defaulting to "error", plus a
//  free-form `data` payload). This header keeps the old names as aliases so
//  existing self-registering error headers (e.g. xfserrors_ptr.h) that do
//  `#include "errorsregistry.h"` and declare `static ErrorEntry foo{...}`
//  keep compiling unchanged — ErrorEntry *is* ConstantEntry, not a copy.
// ============================================================================

#include "constantsregistry.h"

using ErrorEntry    = ConstantEntry;
using ErrorRegistry = ConstantRegistry;
