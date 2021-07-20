#ifndef _CJavaScriptKit_h
#define _CJavaScriptKit_h

#include <stdlib.h>
#include <stdbool.h>

/// `JavaScriptObjectRef` represents JavaScript object reference that is referenced by Swift side.
/// This value is an address of `SwiftRuntimeHeap`.
typedef unsigned int JavaScriptObjectRef;
/// `JavaScriptHostFuncRef` represents Swift closure that is referenced by JavaScript side.
/// This value is produced by `JSClosure`.
typedef unsigned int JavaScriptHostFuncRef;

/// `JavaScriptValueKind` represents the kind of JavaScript primitive value.
typedef enum __attribute__((enum_extensibility(closed))) {
  JavaScriptValueKindInvalid = -1,
  JavaScriptValueKindBoolean = 0,
  JavaScriptValueKindString = 1,
  JavaScriptValueKindNumber = 2,
  JavaScriptValueKindObject = 3,
  JavaScriptValueKindNull = 4,
  JavaScriptValueKindUndefined = 5,
  JavaScriptValueKindFunction = 6,
} JavaScriptValueKind;

typedef struct {
  JavaScriptValueKind kind: 31;
  bool isException: 1;
} JavaScriptValueKindAndFlags;

typedef unsigned JavaScriptPayload1;
typedef double JavaScriptPayload2;

/// `RawJSValue` is abstract representaion of JavaScript primitive value.
///
/// For boolean value:
///    payload1: 1 or 0
///    payload2: 0
///
/// For string value:
///    payload1: `JavaScriptObjectRef` of string
///    payload2: 0
///
/// For number value:
///    payload1: 0
///    payload2: double number
///
/// For object value:
///    payload1: `JavaScriptObjectRef`
///    payload2: 0
/// For null value:
///    payload1: 0
///    payload2: 0
///
/// For undefined value:
///    payload1: 0
///    payload2: 0
///
/// For function value:
///    payload1: the target `JavaScriptHostFuncRef`
///    payload2: 0
///
typedef struct {
  JavaScriptValueKind kind;
  JavaScriptPayload1 payload1;
  JavaScriptPayload2 payload2;
} RawJSValue;

#if __wasm32__

/// `_set_prop` sets a value of `_this` JavaScript object.
///
/// @param _this The target JavaScript object to set the given value.
/// @param prop A JavaScript string object to reference a member of `_this` object.
/// @param kind A kind of JavaScript value to set the target object.
/// @param payload1 The first payload of JavaScript value to set the target object.
/// @param payload2 The second payload of JavaScript value to set the target object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_set_prop")))
extern void _set_prop(const JavaScriptObjectRef _this,
                      const JavaScriptObjectRef prop,
                      const JavaScriptValueKind kind,
                      const JavaScriptPayload1 payload1,
                      const JavaScriptPayload2 payload2);

/// `_get_prop` gets a value of `_this` JavaScript object.
///
/// @param _this The target JavaScript object to get its member value.
/// @param prop A JavaScript string object to reference a member of `_this` object.
/// @param kind A result pointer of JavaScript value kind to get.
/// @param payload1 A result pointer of first payload of JavaScript value to set the target object.
/// @param payload2 A result pointer of second payload of JavaScript value to set the target object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_get_prop")))
extern void _get_prop(const JavaScriptObjectRef _this,
                      const JavaScriptObjectRef prop,
                      JavaScriptValueKind *kind,
                      JavaScriptPayload1 *payload1,
                      JavaScriptPayload2 *payload2);

/// `_set_subscript` sets a value of `_this` JavaScript object.
///
/// @param _this The target JavaScript object to set its member value.
/// @param index A subscript index to set value.
/// @param kind A kind of JavaScript value to set the target object.
/// @param payload1 The first payload of JavaScript value to set the target object.
/// @param payload2 The second payload of JavaScript value to set the target object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_set_subscript")))
extern void _set_subscript(const JavaScriptObjectRef _this,
                           const int index,
                           const JavaScriptValueKind kind,
                           const JavaScriptPayload1 payload1,
                           const JavaScriptPayload2 payload2);

/// `_get_subscript` gets a value of `_this` JavaScript object.
///
/// @param _this The target JavaScript object to get its member value.
/// @param index A subscript index to get value.
/// @param kind A result pointer of JavaScript value kind to get.
/// @param payload1 A result pointer of first payload of JavaScript value to get the target object.
/// @param payload2 A result pointer of second payload of JavaScript value to get the target object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_get_subscript")))
extern void _get_subscript(const JavaScriptObjectRef _this,
                           const int index,
                           JavaScriptValueKind *kind,
                           JavaScriptPayload1 *payload1,
                           JavaScriptPayload2 *payload2);

/// `_encode_string` encodes the `str_obj` to bytes sequence and returns the length of bytes.
///
/// @param str_obj A JavaScript string object ref to encode.
/// @param bytes_result A result pointer of bytes sequence representation in JavaScript.
///                    This value will be used to load the actual bytes using `_load_string`.
/// @result The length of bytes sequence. This value will be used to allocate Swift side string buffer to load the actual bytes.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_encode_string")))
extern int _encode_string(const JavaScriptObjectRef str_obj, JavaScriptObjectRef *bytes_result);

/// `_decode_string` decodes the given bytes sequence into JavaScript string object.
///
/// @param bytes_ptr A `uint8_t` byte sequence to decode.
/// @param length The length of `bytes_ptr`.
/// @result The decoded JavaScript string object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_decode_string")))
extern JavaScriptObjectRef _decode_string(const unsigned char *bytes_ptr, const int length);

/// `_load_string` loads the actual bytes sequence of `bytes` into `buffer` which is a Swift side memory address.
///
/// @param bytes A bytes sequence representation in JavaScript to load. This value should be derived from `_encode_string`.
/// @param buffer A Swift side string buffer to load the bytes.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_load_string")))
extern void _load_string(const JavaScriptObjectRef bytes, unsigned char *buffer);

/// `_call_function` calls JavaScript function with given arguments list.
///
/// @param ref The target JavaScript function to call.
/// @param argv A list of `RawJSValue` arguments to apply.
/// @param argc The length of `argv``.
/// @param result_kind A result pointer of JavaScript value kind of returned result or thrown exception.
/// @param result_payload1 A result pointer of first payload of JavaScript value of returned result or thrown exception.
/// @param result_payload2 A result pointer of second payload of JavaScript value of returned result or thrown exception.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_call_function")))
extern void _call_function(const JavaScriptObjectRef ref, const RawJSValue *argv,
                           const int argc, JavaScriptValueKindAndFlags *result_kind,
                           JavaScriptPayload1 *result_payload1,
                           JavaScriptPayload2 *result_payload2);

/// `_call_function_with_this` calls JavaScript function with given arguments list and given `_this`.
///
/// @param _this The value of `this` provided for the call to `func_ref`.
/// @param func_ref The target JavaScript function to call.
/// @param argv A list of `RawJSValue` arguments to apply.
/// @param argc The length of `argv``.
/// @param result_kind A result pointer of JavaScript value kind of returned result or thrown exception.
/// @param result_payload1 A result pointer of first payload of JavaScript value of returned result or thrown exception.
/// @param result_payload2 A result pointer of second payload of JavaScript value of returned result or thrown exception.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_call_function_with_this")))
extern void _call_function_with_this(const JavaScriptObjectRef _this,
                                     const JavaScriptObjectRef func_ref,
                                     const RawJSValue *argv, const int argc,
                                     JavaScriptValueKindAndFlags *result_kind,
                                     JavaScriptPayload1 *result_payload1,
                                     JavaScriptPayload2 *result_payload2);

/// `_call_new` calls JavaScript object constructor with given arguments list.
///
/// @param ref The target JavaScript constructor to call.
/// @param argv A list of `RawJSValue` arguments to apply.
/// @param argc The length of `argv``.
/// @param result_obj A result pointer of the constructed object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_call_new")))
extern void _call_new(const JavaScriptObjectRef ref,
                      const RawJSValue *argv, const int argc,
                      JavaScriptObjectRef *result_obj);

/// `_call_throwing_new` calls JavaScript object constructor with given arguments list.
///
/// @param ref The target JavaScript constructor to call.
/// @param argv A list of `RawJSValue` arguments to apply.
/// @param argc The length of `argv``.
/// @param result_obj A result pointer of the constructed object.
/// @param exception_kind A result pointer of JavaScript value kind of thrown exception.
/// @param exception_payload1 A result pointer of first payload of JavaScript value of thrown exception.
/// @param exception_payload2 A result pointer of second payload of JavaScript value of thrown exception.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_call_throwing_new")))
extern void _call_throwing_new(const JavaScriptObjectRef ref,
                               const RawJSValue *argv, const int argc,
                               JavaScriptObjectRef *result_obj,
                               JavaScriptValueKindAndFlags *exception_kind,
                               JavaScriptPayload1 *exception_payload1,
                               JavaScriptPayload2 *exception_payload2);

/// `_instanceof` acts like JavaScript `instanceof` operator.
///
/// @param obj The target object to check its prototype chain.
/// @param constructor The `constructor` object to check against.
/// @result Return `true` if `constructor` appears anywhere in the prototype chain of `obj`. Return `false` if not.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_instanceof")))
extern bool _instanceof(const JavaScriptObjectRef obj,
                        const JavaScriptObjectRef constructor);

/// `_create_function` creates a JavaScript thunk function that calls Swift side closure.
/// See also comments on JSFunction.swift
///
/// @param host_func_id The target Swift side function called by the created thunk function.
/// @param func_ref_ptr A result pointer of created thunk function.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_create_function")))
extern void _create_function(const JavaScriptHostFuncRef host_func_id,
                             const JavaScriptObjectRef *func_ref_ptr);

/// Decrements reference count of `ref` retained by `SwiftRuntimeHeap` in JavaScript side.
///
/// @param ref The target JavaScript object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_release")))
extern void _release(const JavaScriptObjectRef ref);

/// Instantiate a new `TypedArray` object with given elements
/// This is used to provide an efficient way to create `TypedArray`.
///
/// @param constructor The `TypedArray` constructor.
/// @param elements_ptr The elements pointer to initialize. They are assumed to be the same size of `constructor` elements size.
/// @param length The length of `elements_ptr`
/// @param result_obj A result pointer of the constructed object.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_create_typed_array")))
extern void _create_typed_array(const JavaScriptObjectRef constructor,
                                const void *elements_ptr, const int length,
                                JavaScriptObjectRef *result_obj);

/// Unwind Wasm module execution stack and rewind it after specified milliseconds,
/// allowing JavaScript events to continue to be processed.
/// **Important**: Wasm module must be [asyncified](https://emscripten.org/docs/porting/asyncify.html),
/// otherwise JavaScriptKit's runtime will throw an exception.
///
/// @param ms Length of time in milliseconds to pause execution for.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_sleep")))
extern void _sleep(const int ms);

/// Unwind Wasm module execution stack and rewind it after promise is fulfilled.
/// **Important**: Wasm module must be [asyncified](https://emscripten.org/docs/porting/asyncify.html),
/// otherwise JavaScriptKit's runtime will throw an exception.
///
/// @param promise target JavaScript promise.
/// @param result_kind A result pointer of JavaScript value kind of returned result or thrown exception.
/// @param result_payload1 A result pointer of first payload of JavaScript value of returned result or thrown exception.
/// @param result_payload2 A result pointer of second payload of JavaScript value of returned result or thrown exception.
__attribute__((__import_module__("javascript_kit"),
               __import_name__("swjs_sync_await")))
extern void _syncAwait(const JavaScriptObjectRef promise,
                       JavaScriptValueKindAndFlags *result_kind,
                       JavaScriptPayload1 *result_payload1,
                       JavaScriptPayload2 *result_payload2);

#endif

#endif /* _CJavaScriptKit_h */
