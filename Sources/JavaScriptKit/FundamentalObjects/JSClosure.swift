import _CJavaScriptKit

fileprivate var sharedClosures: [JavaScriptHostFuncRef: ([JSValue]) -> JSValue] = [:]

/// JSClosureProtocol abstracts closure object in JavaScript, whose lifetime is manualy managed
public protocol JSClosureProtocol: JSValueCompatible {

    /// Release this function resource.
    /// After calling `release`, calling this function from JavaScript will fail.
    func release()
}

/// `JSOneshotClosure` is a JavaScript function that can be called only once.
public class JSOneshotClosure: JSObject, JSClosureProtocol {
    private var hostFuncRef: JavaScriptHostFuncRef = 0

    public init(_ body: @escaping ([JSValue]) -> JSValue) {
        // 1. Fill `id` as zero at first to access `self` to get `ObjectIdentifier`.
        super.init(id: 0)
        let objectId = ObjectIdentifier(self)
        let funcRef = JavaScriptHostFuncRef(bitPattern: Int32(objectId.hashValue))
        // 2. Retain the given body in static storage by `funcRef`.
        sharedClosures[funcRef] = {
            defer { self.release() }
            return body($0)
        }
        // 3. Create a new JavaScript function which calls the given Swift function.
        var objectRef: JavaScriptObjectRef = 0
        _create_function(funcRef, &objectRef)

        hostFuncRef = funcRef
        id = objectRef
    }

    /// Release this function resource.
    /// After calling `release`, calling this function from JavaScript will fail.
    public func release() {
        sharedClosures[hostFuncRef] = nil
    }
}

/// `JSClosure` represents a JavaScript function the body of which is written in Swift.
/// This type can be passed as a callback handler to JavaScript functions.
/// Note that the lifetime of `JSClosure` should be managed by users manually
/// due to GC boundary between Swift and JavaScript.
/// For further discussion, see also [swiftwasm/JavaScriptKit #33](https://github.com/swiftwasm/JavaScriptKit/pull/33)
///
/// e.g.
/// ```swift
/// let eventListenter = JSClosure { _ in
///     ...
///     return JSValue.undefined
/// }
///
/// button.addEventListener!("click", JSValue.function(eventListenter))
/// ...
/// button.removeEventListener!("click", JSValue.function(eventListenter))
/// eventListenter.release()
/// ```
///
public class JSClosure: JSObject, JSClosureProtocol {
    private var hostFuncRef: JavaScriptHostFuncRef = 0
    var isReleased: Bool = false

    @available(*, deprecated, message: "This initializer will be removed in the next minor version update. Please use `init(_ body: @escaping ([JSValue]) -> JSValue)` and add `return .undefined` to the end of your closure")
    @_disfavoredOverload
    public convenience init(_ body: @escaping ([JSValue]) -> ()) {
        self.init({
            body($0)
            return .undefined
        })
    }

    public init(_ body: @escaping ([JSValue]) -> JSValue) {
        // 1. Fill `id` as zero at first to access `self` to get `ObjectIdentifier`.
        super.init(id: 0)
        let objectId = ObjectIdentifier(self)
        let funcRef = JavaScriptHostFuncRef(bitPattern: Int32(objectId.hashValue))
        // 2. Retain the given body in static storage by `funcRef`.
        sharedClosures[funcRef] = body
        // 3. Create a new JavaScript function which calls the given Swift function.
        var objectRef: JavaScriptObjectRef = 0
        _create_function(funcRef, &objectRef)

        hostFuncRef = funcRef
        id = objectRef
    }

    public func release() {
        isReleased = true
        sharedClosures[hostFuncRef] = nil
    }

    deinit {
        guard isReleased else {
            // Safari doesn't support `FinalizationRegistry`, so we cannot automatically manage the lifetime of Swift objects
            fatalError("release() must be called on JSClosure objects manually before they are deallocated")
        }
    }
}

// MARK: - `JSClosure` mechanism note
//
// 1. Create a thunk in the JavaScript world, which has a reference
//    to a Swift closure.
// ┌─────────────────────┬──────────────────────────┐
// │     Swift side      │   JavaScript side        │
// │                     │                          │
// │                     │                          │
// │                     │   ┌──────[Thunk]───────┐ │
// │          ┌ ─ ─ ─ ─ ─│─ ─│─ ─ ─ ─ ─ ┐         │ │
// │          ↓          │   │          │         │ │
// │  [Swift Closure]    │   │  Host Function ID  │ │
// │                     │   │                    │ │
// │                     │   └────────────────────┘ │
// └─────────────────────┴──────────────────────────┘
//
// 2. When the thunk function is invoked, it calls the Swift closure via
//    `_call_host_function` and receives the result through a callback.
// ┌─────────────────────┬──────────────────────────┐
// │     Swift side      │   JavaScript side        │
// │                     │                          │
// │                     │                          │
// │                   Apply ┌──────[Thunk]───────┐ │
// │          ┌ ─ ─ ─ ─ ─│─ ─│─ ─ ─ ─ ─ ┐         │ │
// │          ↓          │   │          │         │ │
// │  [Swift Closure]    │   │  Host Function ID  │ │
// │          │          │   │                    │ │
// │          │          │   └────────────────────┘ │
// │          │          │                    ↑     │
// │          │        Apply                  │     │
// │          └─[Result]─┼───>[Callback func]─┘     │
// │                     │                          │
// └─────────────────────┴──────────────────────────┘

@_cdecl("_call_host_function_impl")
func _call_host_function_impl(
    _ hostFuncRef: JavaScriptHostFuncRef,
    _ argv: UnsafePointer<RawJSValue>, _ argc: Int32,
    _ callbackFuncRef: JavaScriptObjectRef
) {
    guard let hostFunc = sharedClosures[hostFuncRef] else {
        fatalError("The function was already released")
    }
    let arguments = UnsafeBufferPointer(start: argv, count: Int(argc)).map {
        $0.jsValue()
    }
    let result = hostFunc(arguments)
    let callbackFuncRef = JSFunction(id: callbackFuncRef)
    _ = callbackFuncRef(result)
}
