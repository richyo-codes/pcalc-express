// SPDX-License-Identifier: Zlib
/*
 * TINYEXPR++ Wrapper Header - Extern "C" API compatibility wrapper for tinyexpr++.
 *
 * This header declares the C-compatible API for tinyexpr++ to enable usage
 * with Dart FFI or other C-compatible environments.
 */

#ifndef TINYEXPRPP_WRAPPER_H
#define TINYEXPRPP_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

// Evaluate an expression
double tepp_eval(const char* expression);

// Compile an expression
void* tepp_compile(const char* expression, int* error);

// Evaluate a compiled expression
double tepp_eval_compiled(void* compiled_expr);

// Free a compiled expression
void tepp_free(void* compiled_expr);

// Set a constant variable
void tepp_set_constant(void* compiled_expr, const char* name, double value);

// Get a constant variable
double tepp_get_constant(void* compiled_expr, const char* name);

// Returns the last error message (null-terminated string, valid until next call)
const char* tepp_get_last_error_message();

// Returns the last error position (character index, or -1 if none)
int tepp_get_last_error_position();

#ifdef __cplusplus
}
#endif

#endif // TINYEXPRPP_WRAPPER_H
