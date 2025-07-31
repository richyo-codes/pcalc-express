// SPDX-License-Identifier: Zlib
/*
 * TINYEXPR++ Wrapper - Extern "C" API compatibility wrapper for tinyexpr++.
 *
 * This wrapper provides a C-compatible API for tinyexpr++ to enable usage
 * with Dart FFI or other C-compatible environments.
 */

#include "tinyexprpp_wrapper.h"
#include "tinyexpr.h"
#include <cstring>
#include <cmath>
#include <stdexcept>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

static thread_local std::string g_last_error_msg;
static thread_local int g_last_error_pos = -1;

// Wrapper for evaluating an expression
double tepp_eval(const char* expression) {
    try {
        te_parser parser;
        double result = parser.evaluate(expression);
        if (!parser.success()) {
            g_last_error_msg = parser.get_last_error_message();
            g_last_error_pos = parser.get_last_error_position();
        } else {
            g_last_error_msg.clear();
            g_last_error_pos = -1;
        }
        return result;
    } catch (const std::exception& e) {
        g_last_error_msg = e.what();
        g_last_error_pos = -1;
        return NAN;
    }
}

// Wrapper for compiling an expression
void* tepp_compile(const char* expression, int* error) {
    try {
        auto* parser = new te_parser();
        if (!parser->compile(expression)) {
            g_last_error_msg = parser->get_last_error_message();
            g_last_error_pos = parser->get_last_error_position();
            if (error) {
                *error = g_last_error_pos;
            }
            delete parser;
            return nullptr;
        }
        g_last_error_msg.clear();
        g_last_error_pos = -1;
        if (error) {
            *error = 0;
        }
        return parser;
    } catch (const std::exception& e) {
        g_last_error_msg = e.what();
        g_last_error_pos = -1;
        if (error) {
            *error = -1;
        }
        return nullptr;
    }
}

// Wrapper for evaluating a compiled expression
double tepp_eval_compiled(void* compiled_expr) {
    if (!compiled_expr) {
        g_last_error_msg = "No compiled expression";
        g_last_error_pos = -1;
        return NAN;
    }
    try {
        auto* parser = static_cast<te_parser*>(compiled_expr);
        double result = parser->evaluate();
        if (!parser->success()) {
            g_last_error_msg = parser->get_last_error_message();
            g_last_error_pos = parser->get_last_error_position();
        } else {
            g_last_error_msg.clear();
            g_last_error_pos = -1;
        }
        return result;
    } catch (const std::exception& e) {
        g_last_error_msg = e.what();
        g_last_error_pos = -1;
        return NAN;
    }
}

// Wrapper for freeing a compiled expression
void tepp_free(void* compiled_expr) {
    if (compiled_expr) {
        delete static_cast<te_parser*>(compiled_expr);
    }
}

// Wrapper for setting a constant variable
void tepp_set_constant(void* compiled_expr, const char* name, double value) {
    if (!compiled_expr || !name) {
        return;
    }
    try {
        auto* parser = static_cast<te_parser*>(compiled_expr);
        parser->set_constant(name, value);
    } catch (const std::exception& e) {
        // Ignore errors
    }
}

// Wrapper for getting a constant variable
double tepp_get_constant(void* compiled_expr, const char* name) {
    if (!compiled_expr || !name) {
        return NAN;
    }
    try {
        auto* parser = static_cast<te_parser*>(compiled_expr);
        return parser->get_constant(name);
    } catch (const std::exception& e) {
        return NAN;
    }
}



// Returns the last error message (valid until next call)
const char* tepp_get_last_error_message() {
    return g_last_error_msg.c_str();
}

// Returns the last error position (character index, or -1 if none)
int tepp_get_last_error_position() {
    return g_last_error_pos;
}

#ifdef __cplusplus
}
#endif
