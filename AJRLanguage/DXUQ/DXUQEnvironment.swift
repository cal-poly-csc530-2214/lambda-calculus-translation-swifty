//
//  DXUQEnvironment.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 11/5/20.
//

import Cocoa

public typealias ValueBinding = (name : Symbol, value : Value)

public typealias Location = UInt64

public struct Binding : CustomStringConvertible {
    var name : Symbol
    var location : Location

    static func findBinding(_ name: Symbol, in bindings: [Binding]) -> Binding? {
        return bindings.first(where: { $0.name == name })
    }

    public var description: String {
        return "<Binding: \(name): \(location)>"
    }
}

// Note that this is a clss, so that we can mutate it internally.
public class Storage {

    var storage = [Location:Value]()

    public init() {
    }

    public func nextLocation() -> Location {
        return (storage.keys.max() ?? 0) + 1
    }

    public func add(_ value : Value) -> Location {
        let nextLocation = self.nextLocation()
        storage[nextLocation] = value
        return nextLocation
    }

    public subscript(_ index: Location) -> Value? {
        get {
            return storage[index]
        }
        set (newValue) {
            storage[index] = newValue
        }
    }

}

public enum EnvironmentError : Error {

    case undefinedSymbol(String)

}

public struct Environment : CustomStringConvertible {

    var bindings : [Binding]
    public var storage : Storage
    /// Tracks the indent level during output. Create a new indent level by calling env.indented
    public private(set) var indent : Int = 0

    public init(values : [ValueBinding] = [ValueBinding](), storage : Storage = Storage(), indent : Int = 0) {
        self.storage = storage
        self.bindings = values.map({ (name, value) -> Binding in
            return Binding(name: name, location: storage.add(value))
        })
        self.indent = indent
    }

    internal init(bindings : [Binding], storage: Storage, indent : Int = 0) {
        self.bindings = bindings
        self.storage = storage
        self.indent = indent
    }

    public func contains(_ symbol: Symbol) -> Bool {
        return Binding.findBinding(symbol, in: bindings) != nil
    }

    public func extend(_ values : [ValueBinding]) -> Environment {
        // We could do this in a purely functional manner, but that wouldn't be as efficient for Swift, so instead we're going to build a new list of Bindings and then prepend that to our bindings, and finally return a new Environment with that new list.
        var newBindings = [Binding]()

        // NOTE: It's OK to add directly to storge, because that's shared in all environments derived from an initial environment.
        for value in values {
            let binding = Binding(name: value.name, location: storage.add(value.value))
            newBindings.insert(binding, at: 0)
        }

        newBindings.append(contentsOf: self.bindings)

        return Environment(bindings: newBindings, storage: storage)
    }

    public var valueBindings : [ValueBinding] {
        var valueBindings = [ValueBinding]()

        for binding in bindings {
            if let value = storage[binding.location] {
                valueBindings.append((name: binding.name, value: value))
            }
        }

        return valueBindings
    }

    public subscript(_ name : Symbol) -> Value? {
        get {
            if let binding = Binding.findBinding(name, in: bindings) {
                return storage[binding.location]
            }
            return nil
        }
    }

    public func updateStorage(name : Symbol, value: Value) throws -> Void {
        if let binding = Binding.findBinding(name, in: bindings) {
            storage[binding.location] = value
        } else {
            throw EnvironmentError.undefinedSymbol(name)
        }
    }

    public static var root : Environment {
        var bindings = [ValueBinding(name: "true", value: BoolV(true)),
                        ValueBinding(name: "false", value: BoolV(false)),
                        ValueBinding(name: "void", value: VoidV()),
                        ValueBinding(name: "null", value: NullV()),
                        ValueBinding(name: "π", value: RealV(Double.pi)),
                        ValueBinding(name: "pi", value: RealV(Double.pi))]
        bindings.append(contentsOf: Primitive.primtiveValues)
        return Environment(values: bindings)
    }

    public var description: String {
        return bindings.componentsJoinedByString(separator: ", ", prefix: "<Environment: ", suffix: ">")
    }

    /**
     Returns a copy of the receiver, but with indent incremented.
     */
    public var indented : Environment {
        return Environment(bindings: bindings, storage: storage, indent: indent + 1)
    }

}
