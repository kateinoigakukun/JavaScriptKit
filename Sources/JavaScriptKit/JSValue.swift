import _CJavaScriptKit

/// `JSValue` represents a value in JavaScript.
public enum JSValue: Equatable {
    case boolean(Bool)
    case string(JSString)
    case number(Double)
    case object(JSObject)
    case null
    case undefined
    case function(JSFunction)

    /// Returns the `Bool` value of this JS value if its type is boolean.
    /// If not, returns `nil`.
    public var boolean: Bool? {
        switch self {
        case let .boolean(boolean): return boolean
        default: return nil
        }
    }

    /// Returns the `String` value of this JS value if the type is string.
    /// If not, returns `nil`.
    ///
    /// Note that this accessor may copy the JS string value into Swift side memory.
    ///
    /// To avoid the copying, please consider the `jsString` instead.
    public var string: String? {
        jsString.map(String.init)
    }

    /// Returns the `JSString` value of this JS value if the type is string.
    /// If not, returns `nil`.
    ///
    public var jsString: JSString? {
        switch self {
        case let .string(string): return string
        default: return nil
        }
    }

    /// Returns the `Double` value of this JS value if the type is number.
    /// If not, returns `nil`.
    public var number: Double? {
        switch self {
        case let .number(number): return number
        default: return nil
        }
    }

    /// Returns the `JSObject` of this JS value if its type is object.
    /// If not, returns `nil`.
    public var object: JSObject? {
        switch self {
        case let .object(object): return object
        default: return nil
        }
    }

    /// Returns the `JSFunction` of this JS value if its type is function.
    /// If not, returns `nil`.
    public var function: JSFunction? {
        switch self {
        case let .function(function): return function
        default: return nil
        }
    }

    /// Returns the `true` if this JS value is null.
    /// If not, returns `false`.
    public var isNull: Bool {
        return self == .null
    }

    /// Returns the `true` if this JS value is undefined.
    /// If not, returns `false`.
    public var isUndefined: Bool {
        return self == .undefined
    }
}

extension JSValue {
    public func fromJSValue<Type>() -> Type? where Type: JSValueConstructible {
        return Type.construct(from: self)
    }
}

extension JSValue {

    public static func string(_ value: String) -> JSValue {
        .string(JSString(value))
    }

    /// Deprecated: Please create `JSClosure` directly and manage its lifetime manually.
    ///
    /// Migrate this usage
    ///
    /// ```swift
    /// button.addEventListener!("click", JSValue.function { _ in
    ///     ...
    ///     return JSValue.undefined
    /// })
    /// ```
    ///
    /// into below code.
    ///
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
    @available(*, deprecated, message: "Please create JSClosure directly and manage its lifetime manually.")
    public static func function(_ body: @escaping ([JSValue]) -> JSValue) -> JSValue {
        .function(JSClosure(body))
    }
}

extension JSValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(JSString(value))
    }
}

extension JSValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int32) {
        self = .number(Double(value))
    }
}

extension JSValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

public func getJSValue(this: JSObject, name: JSString) -> JSValue {
    var rawValue = RawJSValue()
    _get_prop(this.id, name.asInternalJSRef(),
              &rawValue.kind,
              &rawValue.payload1, &rawValue.payload2)
    return rawValue.jsValue()
}

public func setJSValue(this: JSObject, name: JSString, value: JSValue) {
    value.withRawJSValue { rawValue in
        _set_prop(this.id, name.asInternalJSRef(), rawValue.kind, rawValue.payload1, rawValue.payload2)
    }
}

public func getJSValue(this: JSObject, index: Int32) -> JSValue {
    var rawValue = RawJSValue()
    _get_subscript(this.id, index,
                   &rawValue.kind,
                   &rawValue.payload1, &rawValue.payload2)
    return rawValue.jsValue()
}

public func setJSValue(this: JSObject, index: Int32, value: JSValue) {
    value.withRawJSValue { rawValue in
        _set_subscript(this.id, index,
                       rawValue.kind,
                       rawValue.payload1, rawValue.payload2)
    }
}

extension JSValue {
  /// Return `true` if this value is an instance of the passed `constructor` function.
  /// Returns `false` for everything except objects and functions.
  /// - Parameter constructor: The constructor function to check.
  /// - Returns: The result of `instanceof` in the JavaScript environment.
    public func isInstanceOf(_ constructor: JSFunction) -> Bool {
        switch self {
        case .boolean, .string, .number, .null, .undefined:
            return false
        case let .object(ref):
            return ref.isInstanceOf(constructor)
        case let .function(ref):
            return ref.isInstanceOf(constructor)
        }
    }
}

extension JSValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .boolean(boolean):
            return boolean.description
        case .string(let string):
            return string.description
        case .number(let number):
            return number.description
        case .object(let object), .function(let object as JSObject):
            return object.toString!().fromJSValue()!
        case .null:
            return "null"
        case .undefined:
            return "undefined"
        }
    }
}
