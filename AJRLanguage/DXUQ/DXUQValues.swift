//
//  DXUQValues.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/6/20.
//

import Foundation

// ═════════════════════════
// Define our values
// ═════════════════════════

public protocol Value : CustomStringConvertible {

    func serialize() -> String
    func printable(_ storage: Storage) -> String
    var valueType : String { get }

    func real() throws -> Double
    func integer() throws -> Int
    func boolean() throws -> Bool
    func string() throws -> String

    func equals(_ other: Value) -> Bool

}

public enum ValueError : Error {

    case notANumber(String)
    case notAnInteger(String)
    case notABoolean(String)
    case notAnArray(String)
    case notAString(String)

}

public extension Value {

    func printable(_ storage: Storage) -> String {
        return serialize()
    }

    func real() throws -> Double {
        throw ValueError.notANumber("Expected a Real, got a \(self.valueType).")
    }

    func integer() throws -> Int {
        throw ValueError.notAnInteger("Expected an Int, got a \(self.valueType).")
    }

    func boolean() throws -> Bool {
        throw ValueError.notABoolean("Expected a Bool, got a \(self.valueType).")
    }

    func string() throws -> String {
        throw ValueError.notAString("Expected a String, got a \(self.valueType).")
    }

    static func == (lhs: Value, rhs: Value) -> Bool {
        if type(of: lhs) == type(of: rhs) {
            return lhs.equals(rhs)
        }
        return false
    }

}

// Real values
public struct RealV : Value {

    public var value : Double

    public init(_ value : Double) {
        self.value = value
    }

    public var description: String {
        return "(realV \(value))"
    }

    public func serialize() -> String {
        if value == floor(value) {
            return "\(Int(floor(value)))"
        }
        return "\(value)"
    }

    public var valueType : String { return "Real" }

    public func real() throws -> Double {
        return value
    }

    public func integer() throws -> Int {
        if value == floor(value) {
            return Int(value)
        }
        throw ValueError.notAnInteger("Value isn't an integer: \(value)")
    }

    public func equals(_ other: Value) -> Bool {
        if let other = other as? RealV {
            return value == other.value
        }
        if let other = other as? IntV {
            return value == Double(other.value)
        }
        return false
    }

}

// Int values
public struct IntV : Value {

    public var value : Int

    public init(_ value : Int) {
        self.value = value
    }

    public var description: String {
        return "(realV \(value))" // Because we're staying compatible with the output of our DXUQ in Racket.
    }

    public func serialize() -> String {
        return "\(value)"
    }

    public var valueType : String { return "Int" }

    public func real() throws -> Double {
        return Double(value)
    }

    public func integer() throws -> Int {
        return value
    }

    public func equals(_ other: Value) -> Bool {
        if let other = other as? RealV {
            return other.value == floor(other.value) && value == Int(floor(other.value))
        }
        if let other = other as? IntV {
            return value == other.value
        }
        return false
    }


}

// Boolean values
public struct BoolV : Value {

    public var value : Bool

    public init(_ value : Bool) {
        self.value = value
    }

    public var description: String {
        return "(boolV \(value ? "true" : "false"))"
    }

    public func serialize() -> String {
        return value ? "true" : "false"
    }

    public var valueType : String { return "Bool" }

    public func boolean() throws -> Bool {
        return value
    }

    public func equals(_ other: Value) -> Bool {
        if let other = other as? BoolV {
            return value == other.value
        }
        return false
    }

}

// String Values
public struct StringV : Value {

    public var value : String

    public init(_ value : String) {
        self.value = value
    }

    public func string() throws -> String {
        return value
    }

    public var description: String {
        // TODO: We should re-escape escapped characters
        return "(stringV \"\(value)\")"
    }

    public func serialize() -> String {
        return "\"\(value)\""
    }

    public var valueType : String { return "String" }

    public func printable(_ storage: Storage) -> String {
        return value
    }

    public func equals(_ other: Value) -> Bool {
        if let other = other as? StringV {
            return value == other.value
        }
        return false
    }

}

// Closure value
public struct ClosureV : Value {

    public var args : [Symbol]             // The arguments to our closure. Zero or more
    public var body : ExprC                // The body of the arguments, as an interpretable expression.
    public var env : Environment           // The environment at the moment of creation.

    public init(args: [Symbol], body: ExprC, env: Environment) {
        self.args = args
        self.body = body
        self.env = env
    }

    public var description: String {
        return "(closureV (list \(args.componentsJoinedByString(separator: " "))) \(body) \(env))"
    }

    public func serialize() -> String {
        return "#<procedure>"
    }

    public var valueType : String { return "Closure" }

    public func printable(_ storage: Storage) -> String {
        return "{fn {\(args.componentsJoinedByString(separator: " "))} \(body.unparse())}"
    }

    public func equals(_ other: Value) -> Bool {
        return false
    }

}

public struct PrimitiveV : Value {

    public var name : Symbol               // Name of the primitive. Note we don't need to store its Implementation or anything, because we can look it up.

    public init(name: Symbol) {
        self.name = name
    }

    public var description: String {
        return "(primitiveV \(name))"
    }

    public func serialize() -> String {
        return "#<primop>"
    }

    public var valueType : String { return "Primitive" }

    public func printable(_ storage: Storage) -> String {
        return "{\(name) ...}"
    }

    public func equals(_ other: Value) -> Bool {
        if let other = other as? PrimitiveV {
            return name == other.name
        }
        return false
    }

    public var primitive : Primitive {
        return Primitive.primitive(for: name)!
    }

}

// Allows a "void" return. Only used by print, since the specs call for set! and aset! to return null.
public struct VoidV : Value {

    public init() {
    }

    public var description: String {
        return "(voidV)"
    }

    public func serialize() -> String {
        return "void"
    }

    public func equals(_ other: Value) -> Bool {
        return type(of: self) == type(of: other)
    }

    public var valueType : String { return "Void" }

}

// Implements a "null" value.
public struct NullV : Value {

    public init() {
    }

    public var description: String {
        return "(nullV)"
    }

    public func serialize() -> String {
        return "null"
    }

    public func equals(_ other: Value) -> Bool {
        return type(of: self) == type(of: other)
    }

    public var valueType : String { return "Null" }

}

// Represents the actual value of the array, as saved in the storage. This is basically working like a box.
public struct ArrayStorageV : Value {

    public var values : [Value]            // The actual values of our array.

    public init(values: [Value]) {
        self.values = values
    }

    public var description: String {
        return "(arrayStorageV (list \(values.componentsJoinedByString(separator: " "))))"
    }

    public func serialize() -> String {
        return "#<array>"
    }

    public var valueType : String { return "Array" }

    public func printable(_ storage: Storage) -> String {
        let strings = values.map { $0.printable(storage) }
        return "{array \(strings.componentsJoinedByString(separator: " "))}"
    }

    // TODO: Make work!
    public func equals(_ other: Value) -> Bool {
        return type(of: self) == type(of: other)
    }

}

// The array that's passed around. Must be dereferenced to it's values.
public struct ArrayV : Value {

    public var location : Location         // Location in the storage.

    public var description: String {
        return "(arrayV \(location))"
    }

    public func serialize() -> String {
        return "#<array>"
    }

    public func printable(_ storage: Storage) -> String {
        if let arrayStorage = storage[location] as? ArrayStorageV {
            return arrayStorage.printable(storage)
        }
        return "#ERROR"
    }

    // TODO: Make work!
    public func equals(_ other: Value) -> Bool {
        if let other = other as? ArrayV {
            return location == other.location
        }
        return false
    }

    public var valueType : String { return "Array" }
}

