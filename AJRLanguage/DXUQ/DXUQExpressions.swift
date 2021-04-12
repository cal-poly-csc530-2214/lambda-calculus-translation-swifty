//
//  DXUQExpressions.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/6/20.
//

import Foundation

public extension String {

    static func indent(by indent: Int) -> String {
        return String(repeating: " ", count: indent * 4)
    }

}

public protocol ExprC : CustomStringConvertible {

    func unparse() -> String

    func equals(_ other: ExprC) -> Bool

    func swiftString(in env: Environment) -> String

    func mutates(symbol: Symbol) -> Bool

}

public struct ValueC : ExprC {

    public var value : Value // A value. Can now be any valid number type, so no more numC.

    public init(_ value : Value) {
        self.value = value
    }

    public var description: String {
        return "(valueC \(value.description))"
    }

    public func unparse() -> String {
        return value.serialize()
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? ValueC {
            return value.equals(other.value)
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        return value.serialize()
    }

    public func mutates(symbol: Symbol) -> Bool {
        // We can never mutate.
        return false
    }

}

public struct IdC : ExprC {

    public var name : Symbol               // Its name
    // TODO: Protect against protected symbols.

    public init(_ name: Symbol) throws {
        if Symbol.isProtected(name) {
            throw DXUQParseError.invalidInput("Symbol \(name) is protected.")
        }
        self.name = name
    }

    public var description: String {
        return "(idC '\(name))"
    }

    public func unparse() -> String {
        return name
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? IdC {
            return name == other.name
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        return name
    }

    public func mutates(symbol: Symbol) -> Bool {
        return false
    }

}

internal func equalExpressions(_ lhs: [ExprC], rhs: [ExprC]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for index in 0 ..< lhs.count {
        if !lhs[index].equals(rhs[index]) {
            return false
        }
    }
    return true
}

public struct AppC : ExprC {

    public var function : ExprC            // The function to evaluate
    public var arguments : [ExprC]         // The list of arguments bound to the function

    public var description: String {
        return arguments.componentsJoinedByString(separator: " ", prefix: "(appC \(function) (list ", suffix: "))")
    }

    public func unparse() -> String {
        if arguments.count == 0 {
            return "{\(function.unparse())}"
        }
        return "{\(function.unparse()) \(arguments.map {return $0.unparse()}.componentsJoinedByString(separator: " "))}"
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? AppC {
            return function.equals(other.function) && equalExpressions(arguments, rhs: other.arguments)
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        if let function = function as? IdC,
           let value = env[function.name],
           let primitive = (value as? PrimitiveV)?.primitive,
           let swift = primitive.swiftString(args: arguments, in: env) {
            return swift
        } else {
            var result = function.swiftString(in: env)
            result += "("
            for (index, argument) in arguments.enumerated() {
                if index > 0 {
                    result += ", "
                }
                result += argument.swiftString(in: env)
            }
            result += ")"
            return result
        }
    }

    public func mutates(symbol: Symbol) -> Bool {
        return function.mutates(symbol: symbol) || arguments.first { $0.mutates(symbol: symbol) } != nil
    }

}

public struct LambdaC : ExprC {

    public var args : [Symbol]             // Named parameters of the lambda
    public var body : ExprC                // The body to be evaluated.
    // TODO: Check against duplicate args.

    public var description: String {
        return "(lambdaC '(\(args.componentsJoinedByString(separator: " "))) \(body))"
    }

    public func unparse() -> String {
        return "{fn {\(args.componentsJoinedByString(separator: " "))} \(body.unparse())}"
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? LambdaC {
            return args == other.args && body.equals(other.body)
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        var string = "{"

        string += " ("
        for (index, arg) in args.enumerated() {
            if index > 0 {
                string += ", "
            }
            string += arg + ": Any"
        }
        string += ")"

        string += " -> Any in "
        string += body.swiftString(in: env.indented)

        string += " }"
        return string
    }

    public func mutates(symbol: Symbol) -> Bool {
        return body.mutates(symbol: symbol)
    }

}

// Defines a let block. We initially did this by translating to a Lambda, but since I'm not trying
// to translate this to Swift, it'll be easier if the let is an actual let.
public struct LetC : ExprC {

    public var variables : [SetC]
    public var body : ExprC

    public var description: String {
        return variables.componentsJoinedByString(separator: " ", prefix: "(letC (list ", suffix: ") \(body))")
    }

    public func unparse() -> String {
        return "{let \(variables.map {return $0.unparse()}.componentsJoinedByString(separator: " ")) \(body.unparse()) }"
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? LetC {
            return body.equals(other.body) && equalExpressions(variables, rhs: other.variables)
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        var string = ""

        if env.indent == 0 {
            // At the top level, we need to define a "main". Note: I'm not sure this is 100% effective. We'll likely be changing this.
            // TODO: We're assuming everything's an Int right now, because this is based on the "typeless" versino of DXUQ.
            string += "func main() -> Any {\n"
        } else {
            string += "{\n"
        }
        for variable in variables {
            // TODO: We should really check and see if there's an assignment to the variable, if there is, then we should declare it as var rather than let.
            // Thankfully, Swift will infer the type.
            string += "\(String.indent(by:env.indent + 1))\(body.mutates(symbol: variable.variable) ? "var" : "let") \(variable.variable) = \(variable.argument.swiftString(in: env))\n"
            string += "\n"
            string += "\(String.indent(by:env.indent + 1))return \(body.swiftString(in: env.indented))\n"
        }
        string += "\(String.indent(by:env.indent))}\n"
        return string
    }

    public func mutates(symbol: Symbol) -> Bool {
        return body.mutates(symbol: symbol)
    }

}

// Defines an assignment to a variable.
public struct SetC : ExprC {

    public var variable : Symbol           // The variable being assigned.
    public var argument : ExprC            // The expression to be evaluated and then assigned.

    public init(variable : Symbol, argument : ExprC) {
        self.variable = variable
        self.argument = argument
    }

    public var description: String {
        return "(setC \(variable) \(argument))"
    }

    public func unparse() -> String {
        return "{\(variable) := \(argument.unparse())}"
    }

    public func equals(_ other: ExprC) -> Bool {
        if let other = other as? SetC {
            return variable == other.variable && argument.equals(other.argument)
        }
        return false
    }

    public func swiftString(in env: Environment) -> String {
        return "\(variable) = \(argument.swiftString(in: env))"
    }

    public func mutates(symbol: Symbol) -> Bool {
        return variable == symbol
    }

}

