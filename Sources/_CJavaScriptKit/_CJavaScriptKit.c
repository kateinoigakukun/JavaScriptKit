#include "_CJavaScriptKit.h"
#include <stdlib.h>

#if __wasm32__

void _call_host_function_impl(const JavaScriptHostFuncRef host_func_ref,
                              const RawJSValue *argv, const int argc,
                              const JavaScriptObjectRef callback_func);

__attribute__((export_name("swjs_call_host_function")))
void swjs_call_host_function(const JavaScriptHostFuncRef host_func_ref,
                             const RawJSValue *argv, const int argc,
                             const JavaScriptObjectRef callback_func) {
    _call_host_function_impl(host_func_ref, argv, argc, callback_func);
}

__attribute__((export_name("swjs_prepare_host_function_call")))
void *swjs_prepare_host_function_call(const int argc) {
    return malloc(argc * sizeof(RawJSValue));
}

__attribute__((export_name("swjs_cleanup_host_function_call")))
void swjs_cleanup_host_function_call(void *argv_buffer) {
    free(argv_buffer);
}

/// The compatibility runtime library version.
/// Notes: If you change any interface of runtime library, please increment
/// this and `SwiftRuntime.version` in `./Runtime/src/index.ts`.
__attribute__((export_name("swjs_library_version")))
int swjs_library_version() {
    return 701;
}

/// The structure pointing to the Asyncify stack buffer
typedef struct __attribute__((packed)) {
    void *start;
    void *end;
} _asyncify_data_pointer;

__attribute__((export_name("swjs_allocate_asyncify_buffer")))
void *_allocate_asyncify_buffer(const int size) {
    void *buffer = malloc(size);
    _asyncify_data_pointer *pointer = malloc(sizeof(_asyncify_data_pointer));
    pointer->start = buffer;
    pointer->end = (void *)((int)buffer + size);
    return pointer;
}

#endif
