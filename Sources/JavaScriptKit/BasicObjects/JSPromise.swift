/** A wrapper around [the JavaScript `Promise` class](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise)
that exposes its functions in a type-safe and Swifty way. The `JSPromise` API is generic over both
`Success` and `Failure` types, which improves compatibility with other statically-typed APIs such
as Combine. If you don't know the exact type of your `Success` value, you should use `JSValue`, e.g.
`JSPromise<JSValue, JSError>`. In the rare case, where you can't guarantee that the error thrown
is of actual JavaScript `Error` type, you should use `JSPromise<JSValue, JSValue>`.

This doesn't 100% match the JavaScript API, as `then` overload with two callbacks is not available.
It's impossible to unify success and failure types from both callbacks in a single returned promise
without type erasure. You should chain `then` and `catch` in those cases to avoid type erasure.

**IMPORTANT**: instances of this class must have the same lifetime as the actual `Promise` object in
the JavaScript environment, because callback handlers will be deallocated when `JSPromise.deinit` is
executed.

If the actual `Promise` object in JavaScript environment lives longer than this `JSPromise`, it may
attempt to call a deallocated `JSClosure`.
*/
public final class JSPromise<Success, Failure>: JSValueConvertible, JSValueConstructible {
    /// The underlying JavaScript `Promise` object.
    public let jsObject: JSObject

    private var callbacks = [JSClosure]()

    /// The underlying JavaScript `Promise` object wrapped as `JSValue`.
    public func jsValue() -> JSValue {
        .object(jsObject)
    }

    /// This private initializer assumes that the passed object is a JavaScript `Promise`
    private init(unsafe object: JSObject) {
        self.jsObject = object
    }

    /** Creates a new `JSPromise` instance from a given JavaScript `Promise` object. If `jsObject`
    is not an instance of JavaScript `Promise`, this initializer will return `nil`.
    */
    public init?(_ jsObject: JSObject) {
        guard jsObject.isInstanceOf(JSObject.global.Promise.function!) else { return nil }
        self.jsObject = jsObject
    }

    /** Creates a new `JSPromise` instance from a given JavaScript `Promise` object. If `value`
    is not an object and is not an instance of JavaScript `Promise`, this function will 
    return `nil`.
    */
    public static func construct(from value: JSValue) -> Self? {
        guard case let .object(jsObject) = value else { return nil }
        return Self.init(jsObject)
    }

    /** Schedules the `success` closure to be invoked on sucessful completion of `self`.
    */
    public func then(success: @escaping () -> ()) {
        let closure = JSClosure { _ in success() }
        callbacks.append(closure)
        _ = jsObject.then!(closure)
    }

    /** Schedules the `failure` closure to be invoked on either successful or rejected completion of 
    `self`.
    */
    public func finally(successOrFailure: @escaping () -> ()) -> Self {
        let closure = JSClosure { _ in
            successOrFailure()
        }
        callbacks.append(closure)
        return .init(unsafe: jsObject.finally!(closure).object!)
    }

    deinit {
        callbacks.forEach { $0.release() }
    }
}

extension JSPromise where Success == (), Failure == Never {
    /** Creates a new `JSPromise` instance from a given `resolver` closure. `resolver` takes 
    a closure that your code should call to resolve this `JSPromise` instance.
    */
    public convenience init(resolver: @escaping (@escaping () -> ()) -> ()) {
        let closure = JSClosure { arguments -> () in
            // The arguments are always coming from the `Promise` constructor, so we should be
            // safe to assume their type here
            resolver { arguments[0].function!() }
        }
        self.init(unsafe: JSObject.global.Promise.function!.new(closure))
        callbacks.append(closure)
    }
}

extension JSPromise where Failure: JSValueConvertible {
    /** Creates a new `JSPromise` instance from a given `executor` closure. `resolver` takes 
    two closure that your code should call to either resolve or reject this `JSPromise` instance.
    */
    public convenience init(resolver: @escaping (@escaping (Result<Success, JSError>) -> ()) -> ()) {
        let closure = JSClosure { arguments -> () in
            // The arguments are always coming from the `Promise` constructor, so we should be
            // safe to assume their type here
            let resolve = arguments[0].function!
            let reject = arguments[1].function!

            resolver {
                switch $0 {
                case .success:
                    resolve()
                case let .failure(error):
                    reject(error.jsValue())
                }
            }
        }
        self.init(unsafe: JSObject.global.Promise.function!.new(closure))
        callbacks.append(closure)
    }
}

extension JSPromise where Success: JSValueConvertible, Failure: JSError {
    /** Creates a new `JSPromise` instance from a given `executor` closure. `executor` takes 
    a closure that your code should call to either resolve or reject this `JSPromise` instance.
    */
    public convenience init(resolver: @escaping (@escaping (Result<Success, JSError>) -> ()) -> ()) {
        let closure = JSClosure { arguments -> () in
            // The arguments are always coming from the `Promise` constructor, so we should be
            // safe to assume their type here
            let resolve = arguments[0].function!
            let reject = arguments[1].function!

            resolver {
                switch $0 {
                case let .success(success):
                    resolve(success.jsValue())
                case let .failure(error):
                    reject(error.jsValue())
                }
            }
        }
        self.init(unsafe: JSObject.global.Promise.function!.new(closure))
        callbacks.append(closure)
    }
}

extension JSPromise where Success: JSValueConstructible {
    /** Schedules the `success` closure to be invoked on sucessful completion of `self`.
    */
    public func then(
        success: @escaping (Success) -> (),
        file: StaticString = #file,
        line: Int = #line
    ) {
        let closure = JSClosure { arguments -> () in
            guard let result = Success.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap success value for `then` callback")
            }
            success(result)
        }
        callbacks.append(closure)
        _ = jsObject.then!(closure)
    }

    /** Returns a new promise created from chaining the current `self` promise with the `success`
    closure invoked on sucessful completion of `self`. The returned promise will have a new 
    `Success` type equal to the return type of `success`.
    */
    public func then<ResultType: JSValueConvertible>(
        success: @escaping (Success) -> ResultType,
        file: StaticString = #file,
        line: Int = #line
    ) -> JSPromise<ResultType, Failure> {
        let closure = JSClosure { arguments -> JSValue in
            guard let result = Success.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap success value for `then` callback")
            }
            return success(result).jsValue()
        }
        callbacks.append(closure)
        return .init(unsafe: jsObject.then!(closure).object!)
    }

    /** Returns a new promise created from chaining the current `self` promise with the `success`
    closure invoked on sucessful completion of `self`. The returned promise will have a new type
    equal to the return type of `success`.
    */
    public func then<ResultSuccess: JSValueConvertible, ResultFailure: JSValueConstructible>(
        success: @escaping (Success) -> JSPromise<ResultSuccess, ResultFailure>,
        file: StaticString = #file,
        line: Int = #line
    ) -> JSPromise<ResultSuccess, ResultFailure> {
        let closure = JSClosure { arguments -> JSValue in
            guard let result = Success.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap success value for `then` callback")
            }
            return success(result).jsValue()
        }
        callbacks.append(closure)
        return .init(unsafe: jsObject.then!(closure).object!)
    }
}

extension JSPromise where Failure: JSValueConstructible {
    /** Returns a new promise created from chaining the current `self` promise with the `failure`
    closure invoked on rejected completion of `self`. The returned promise will have a new `Success`
    type equal to the return type of the callback, while the `Failure` type becomes `Never`.
    */
    public func `catch`<ResultSuccess: JSValueConvertible>(
        failure: @escaping (Failure) -> ResultSuccess,
        file: StaticString = #file,
        line: Int = #line
    ) -> JSPromise<ResultSuccess, Never> {
        let closure = JSClosure { arguments -> JSValue in
            guard let error = Failure.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap error value for `catch` callback")
            }
            return failure(error).jsValue()
        }
        callbacks.append(closure)
        return .init(unsafe: jsObject.then!(JSValue.undefined, closure).object!)
    }

    /** Schedules the `failure` closure to be invoked on rejected completion of `self`.
    */
    public func `catch`(
        failure: @escaping (Failure) -> (),
        file: StaticString = #file,
        line: Int = #line
    ) {
        let closure = JSClosure { arguments -> () in
            guard let error = Failure.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap error value for `catch` callback")
            }
            failure(error)
        }
        callbacks.append(closure)
        _ = jsObject.then!(JSValue.undefined, closure)
    }

    /** Returns a new promise created from chaining the current `self` promise with the `failure`
    closure invoked on rejected completion of `self`.  The returned promise will have a new type
    equal to the return type of `success`.
    */
    public func `catch`<ResultSuccess: JSValueConvertible, ResultFailure: JSValueConstructible>(
        failure: @escaping (Failure) -> JSPromise<ResultSuccess, ResultFailure>,
        file: StaticString = #file,
        line: Int = #line
    ) -> JSPromise<ResultSuccess, ResultFailure> {
        let closure = JSClosure { arguments -> JSValue in
            guard let error = Failure.construct(from: arguments[0]) else {
                fatalError("\(file):\(line): failed to unwrap error value for `catch` callback")
            }
            return failure(error).jsValue()
        }
        callbacks.append(closure)
        return .init(unsafe: jsObject.then!(JSValue.undefined, closure).object!)
    }
}
