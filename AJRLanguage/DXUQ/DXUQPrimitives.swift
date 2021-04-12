//
//  DXUQPrimitives.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 11/5/20.
//

import Foundation

/* A list used to define the various binary operations. This was a hash, but our primitives are fairly
   small, and we'll be interting these into the environment anyways, so no need to the overhead of
 a hash table. */

public typealias PrimitiveValueBody = ([Value], Environment) throws -> Value
public typealias PrimitiveValueModEnvBody = ([Value], Environment) throws -> ReturnValue
public typealias PrimitiveExpressionBody = ([ExprC], Environment) throws -> ReturnValue
public typealias PrimitiveSwiftString = ([ExprC], Environment) throws -> String

public enum PrimitiveBody {
    case valueBody(PrimitiveValueBody)
    case valueModEnvBody(PrimitiveValueModEnvBody)
    case expressionBody(PrimitiveExpressionBody)
}

private func binaryOpToSwift(op: String) -> PrimitiveSwiftString {
    return { (args, env) -> String in
        try checkArgumentCount(op, values: args, count: 2)
        return "(\(args[0].swiftString(in: env)) \(op) \(args[1].swiftString(in: env)))"
    }
}

public struct Primitive {

    var name : Symbol
    var body : PrimitiveBody
    var toSwift : PrimitiveSwiftString?

    static public var primitives : [Primitive] = [
        Primitive(name: "+", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("+", values: values, count: 2)
            return RealV((try values[0].real()) + (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: "+")),
        Primitive(name: "-", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("-", values: values, count: 2)
            return RealV((try values[0].real()) - (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: "-")),
        Primitive(name: "*", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("*", values: values, count: 2)
            return RealV((try values[0].real()) * (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: "*")),
        Primitive(name: "/", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("/", values: values, count: 2)
            let dividend = try values[1].real()
            if dividend == 0 {
                throw PrimitiveError.divideByZero
            }
            return RealV((try values[0].real()) / dividend)
        }), toSwift: binaryOpToSwift(op: "/")),
        Primitive(name: "<=", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("<=", values: values, count: 2)
            return BoolV((try values[0].real()) <= (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: "<=")),
        Primitive(name: "<", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("<", values: values, count: 2)
            return BoolV((try values[0].real()) < (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: "<")),
        Primitive(name: ">=", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount(">=", values: values, count: 2)
            return BoolV((try values[0].real()) >= (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: ">=")),
        Primitive(name: ">", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount(">", values: values, count: 2)
            return BoolV((try values[0].real()) > (try values[1].real()))
        }), toSwift: binaryOpToSwift(op: ">")),
        Primitive(name: "not", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("not", values: values, count: 1)
            return BoolV(!(try values[0].boolean()))
        }), toSwift: nil),
        Primitive(name: "and", body: PrimitiveBody.expressionBody({ (expressions, env) -> ReturnValue in
            try checkArgumentCount("and", values: expressions, count: 2)
            var rv = try Interpret(expressions[0], env: env)
            if try rv.value.boolean() == false {
                return (value: BoolV(false), env: rv.env)
            }
            // This works, because if lhs is false, we short circuited above, thus we know lhs is now true, and therefore we only need to return the value of rhs.
            rv = try Interpret(expressions[1], env: rv.env)
            return (value: BoolV(try rv.value.boolean()), env: rv.env)
        }), toSwift: binaryOpToSwift(op: "&&")),
        Primitive(name: "or", body: PrimitiveBody.expressionBody({ (expressions, env) -> ReturnValue in
            try checkArgumentCount("or", values: expressions, count: 2)
            var rv = try Interpret(expressions[0], env: env)
            if try rv.value.boolean() == true {
                return (value: BoolV(true), env: rv.env)
            }
            // This works, because if lhs is true, we short circuited above, thus we know lhs is now false, and therefore we only need to return the value of rhs.
            rv = try Interpret(expressions[1], env: rv.env)
            return (value: BoolV(try rv.value.boolean()), env: rv.env)
        }), toSwift: binaryOpToSwift(op: "||")),
        Primitive(name: "xor", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            // xor can't short circuit, so we don't need to be the expression version.
            try checkArgumentCount("xor", values: values, count: 2)
            let lhs = try values[0].boolean()
            let rhs = try values[1].boolean()
            return BoolV((!lhs && rhs) || (lhs && !rhs))
        }), toSwift: { (args, env) -> String in
            try checkArgumentCount("xor", values: args, count: 2)
            return "((\(args[0].swiftString(in: env)) && !\(args[1].swiftString(in: env))) || !(\(args[0].swiftString(in: env)) && \(args[1].swiftString(in: env))))"
        }),
        Primitive(name: "print", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            for value in values {
                print(value.printable(env.storage), terminator: "")
            }
            return VoidV()
        }), toSwift: { (args, env) -> String in
            return args.map { $0.swiftString(in: env)}.componentsJoinedByString(separator: ", ", prefix: "print(", suffix: ")")
        }),
        Primitive(name: "begin", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            // Because I also missed this. This works, because all the expression have already been evaluated into their values, so we just need to return the last value.
            return values.count >= 1 ? values.last! : VoidV()
        }), toSwift: { (args, env) -> String in
            // TODO: Deal with indent
            var string = "{ () -> Any in\n"
            for (index, arg) in args.enumerated() {
                if index == args.count - 1 {
                    string += "    return \(arg.swiftString(in: env.indented))\n"
                } else {
                    string += "    _ = \(arg.swiftString(in: env.indented))\n" // Because we're ignoring the return value.
                }
            }
            string += "}()"
            return string
        }),
        Primitive(name: "equal?", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("equal?", values: values, count: 2)
            return BoolV(values[0].equals(values[1]))
        }), toSwift: binaryOpToSwift(op: "==")),
        Primitive(name: "if", body: PrimitiveBody.expressionBody({ (expressions, env) -> ReturnValue in
            try checkArgumentCount("if", values: expressions, count: 3)
            var rv = try Interpret(expressions[0], env: env)
            if try rv.value.boolean() {
                return try Interpret(expressions[1], env: env)
            }
            return try Interpret(expressions[2], env: env)
        }), toSwift: { (args, env) -> String in
            // TODO: Deal with indent
            try checkArgumentCount("if", values: args, count: 3)
            var string = "{() -> Any in\n"
            string += "    if \(args[0].swiftString(in: env.indented)) {\n"
            string += "        return \(args[1].swiftString(in: env.indented))\n"
            string += "    } else {\n"
            string += "        return \(args[2].swiftString(in: env.indented))\n"
            string += "    }\n"
            string += "}()"
            return string
        }),
        Primitive(name: "new-array", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("new-array", values: values, count: 2)
            let count = try values[0].integer()
            if count < 1 {
                throw PrimitiveError.invalidArgumentCount("array: Expects at least 1 value.")
            }
            let repeatedValue = values[1]
            let location = env.storage.add(ArrayStorageV(values: Array(repeating: repeatedValue, count: count)))
            return ArrayV(location: location)
        }), toSwift: nil),
        Primitive(name: "array", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            if values.count < 1 {
                throw PrimitiveError.invalidArgumentCount("array: Expects at least 1 value.")
            }
            let location = env.storage.add(ArrayStorageV(values: values))
            return ArrayV(location: location)
        }), toSwift: nil),
        Primitive(name: "aref", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("aref", values: values, count: 2)
            if let array = values[0] as? ArrayV,
               let arrayValues = (env.storage[array.location] as? ArrayStorageV)?.values {
                let index = try values[1].integer()
                try checkRange("aref", index: index, start: 0, stop: arrayValues.count, indexName: "index")
                return arrayValues[index]
            }
            throw ValueError.notABoolean("Expected an array, got a \(values[0].valueType).")
        }), toSwift: nil),
        Primitive(name: "aset!", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("aset!", values: values, count: 3)
            let storage = env.storage
            if let array = values[0] as? ArrayV {
                if var arrayValues = (env.storage[array.location] as? ArrayStorageV)?.values {
                    let index = try values[1].integer()

                    try checkRange("aset!", index: index, start: 0, stop: arrayValues.count, indexName: "index")
                    // To those not familiar with Swift, doing this assignment will create a local copy of arrayValues, so I'm not mutating the array.
                    arrayValues[index] = values[2]
                    // Now we have to put the new value back into the storage.
                    storage[array.location] = ArrayStorageV(values: arrayValues)
                    return VoidV()
                }
                throw PrimitiveError.internalError("Programmer Error: We got somewhere we shouldn't, which implies that our storage is corrupt.")
            }
            throw ValueError.notABoolean("'aset!': Expected an array, got a \(values[0].valueType).")
        }), toSwift: nil),
        Primitive(name: "substring", body: PrimitiveBody.valueBody({ (values, env) -> Value in
            try checkArgumentCount("substring", values: values, count: 3)
            let string = try values[0].string()
            let startIndex = try values[1].integer()
            let endIndex = try values[2].integer()
            try checkRange("substring", index: startIndex, start: 0, stop: string.utf16.count, indexName: "startIndex")
            try checkRange("substring", index: endIndex, start: startIndex, stop: string.utf16.count + 1, indexName: "endIndex")
            return StringV(String(string.suffix(string.utf16.count - startIndex).prefix(endIndex - startIndex)))
        }), toSwift: nil),
    ]

    static public var primtiveValues : [ValueBinding] {
        return primitives.map({ValueBinding(name:$0.name, PrimitiveV(name: $0.name))})
    }

    public static subscript(_ name: Symbol) -> PrimitiveBody? {
        for primitive in Primitive.primitives {
            if primitive.name == name {
                return primitive.body
            }
        }
        return nil
    }

    public static func primitive(for name: Symbol) -> Primitive? {
        for primitive in Primitive.primitives {
            if primitive.name == name {
                return primitive
            }
        }
        return nil
    }

    public func swiftString(args: [ExprC], in env: Environment) -> String? {
        if let toSwift = toSwift {
            return try? toSwift(args, env)
        }
        return nil
    }

}

public enum PrimitiveError : Error {

    case invalidArgumentCount(String)
    case divideByZero
    case rangeOutOfBounds(String)
    case internalError(String)

}

internal func checkArgumentCount(_ name: String = #function, values: [Any], count: Int) throws -> Void {
    if values.count != count {
        throw PrimitiveError.invalidArgumentCount("\(name): Expected \(count) arguments, got \(values.count).")
    }
}

/// Raises an error if index in range of start and stop. Note that this is index >= start and index &lt: stop.
internal func checkRange(_ name: String = #function, index: Int, start: Int, stop: Int, indexName: String) throws -> Void {
    if index < start || index >= stop {
        throw PrimitiveError.rangeOutOfBounds("\(indexName) must be in the range [\(start)..\(stop - 1)]: got \(index)")
    }
}

/*
(define primitives
  (list
        ;; NOTE: This could potentially also compare strings, but the spec says we only compare numbers so
        ;; that's all we handle for now.
        (Primitive 'not       (primitiveValueBody primitive-not))
        (Primitive 'or        (primitiveExpressionBody primitive-or))
        (Primitive 'and       (primitiveExpressionBody primitive-and))
        (Primitive 'xor       (primitiveExpressionBody primitive-xor))
        (Primitive 'substring (primitiveValueBody primitive-substring))))
*/
