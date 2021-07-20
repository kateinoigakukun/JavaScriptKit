import _CJavaScriptKit

/// Unwind Wasm module execution stack and rewind it after specified milliseconds,
/// allowing JavaScript events to continue to be processed.
/// **Important**: Wasm module must be [asyncified](https://emscripten.org/docs/porting/asyncify.html),
/// otherwise JavaScriptKit's runtime will throw an exception.
public func pauseExecution(milliseconds: Int32) {
    _sleep(milliseconds)
}


extension JSPromise {
    /// Unwind Wasm module execution stack and rewind it after promise resolves,
    /// allowing JavaScript events to continue to be processed in the meantime.
    /// - Parameters:
    ///     - timeout: If provided, method will return a failure if promise cannot resolve
    ///      before timeout is reached.
    ///
    /// **Important**: Wasm module must be [asyncified](https://emscripten.org/docs/porting/asyncify.html),
    /// otherwise JavaScriptKit's runtime will throw an exception.
    public func syncAwait() -> Result<JSValue, JSValue> {
        var kindAndFlags = JavaScriptValueKindAndFlags()
        var payload1 = JavaScriptPayload1()
        var payload2 = JavaScriptPayload2()
        
        _syncAwait(jsObject.id, &kindAndFlags, &payload1, &payload2)
        let result = RawJSValue(kind: kindAndFlags.kind, payload1: payload1, payload2: payload2).jsValue()
        if kindAndFlags.isException {
            return .failure(result)
        } else {
            return .success(result)
        }
    }
}
