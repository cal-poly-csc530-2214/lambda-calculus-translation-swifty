//
//  DXUQInterpreter.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 11/5/20.
//

import Foundation

enum DXUQInterpreterError : Error {
    case invalidSyntax(String)
}

public typealias ReturnValue = (value: Value, env: Environment)

public func Interpret(_ string: String, env : Environment = Environment.root) throws -> String {
    return try DXUQInterpreter.interpret(string, env: env)
}

public func Interpret(_ expression: ExprC, env : Environment = Environment.root) throws -> ReturnValue {
    return try DXUQInterpreter.interpret(expression, env: env)
}

public class DXUQInterpreter {

    public class func interpret(_ string: String, env : Environment = Environment.root) throws -> String {
        return try interpret(try DXUQParser.parse(string), env: env).value.serialize()
    }

    // Interpret a ExprC returning the result of the expression.
    public class func interpret(_ expression: ExprC, env : Environment = Environment.root) throws -> ReturnValue {
        if let value = expression as? ValueC {
            return (value: value.value, env: env)
        }
        if let lambda = expression as? LambdaC {
            return (value: ClosureV(args: lambda.args, body: lambda.body, env: env), env: env)
        }
        if let app = expression as? AppC {
            return try interpretFunction(app.function, arguments: app.arguments, env: env)
        }
        if let id = expression as? IdC {
            if let value = env[id.name] {
                return (value: value, env: env)
            }
            throw EnvironmentError.undefinedSymbol(id.name)
        }
        if let set = expression as? SetC {
            var returnValue = try interpret(set.argument, env: env)
            if returnValue.env[set.variable] == nil {
                returnValue.env = env.extend([(name: set.variable, value: returnValue.value)])
            } else {
                try env.updateStorage(name: set.variable, value: returnValue.value)
            }
            return (value: VoidV(), env: returnValue.env)
        }
        preconditionFailure("Programmer Error: Unknown expression")
    }

    internal class func interpretFunction(_ function : ExprC, arguments: [ExprC], env envIn : Environment) throws -> ReturnValue {
        var rv : ReturnValue
        rv = try interpret(function, env: envIn)
        let possibleFunction = rv.value
        if let closure = possibleFunction as? ClosureV {
            let args = closure.args
            if args.count == arguments.count {
                let body = closure.body
                let argResults : [Value] = try arguments.map {
                    rv = try interpret($0, env: rv.env)
                    return rv.value
                }
                let closureEnv = closure.env
                var argumentValues = [ValueBinding]()
                for x in 0 ..< args.count {
                    let binding = ValueBinding(name: args[x], value: argResults[x])
                    argumentValues.append(binding)
                }
                let nv = try interpret(body, env: closureEnv.extend(argumentValues))
                // This may seem a bit odd, but the closure's env is it's own world, so anything set in it that's local is lost when the closure exits.
                return (value: nv.value, env: rv.env)
            }
            throw DXUQInterpreterError.invalidSyntax("Incorrect number of arguments: \(arguments.count), expected \(args.count).")
        }
        if let primitive = possibleFunction as? PrimitiveV {
            let name = primitive.name
            if let body = Primitive[name] {
                switch body {
                case .valueBody(let function):
                    let argResults : [Value] = try arguments.map {
                        rv = try interpret($0, env: rv.env)
                        return rv.value
                    }
                    return (value: try function(argResults, rv.env), env: rv.env)
                case .valueModEnvBody(let function):
                    let argResults : [Value] = try arguments.map {
                        rv = try interpret($0, env: rv.env)
                        return rv.value
                    }
                    return try function(argResults, rv.env)
                case .expressionBody(let function):
                    return try function(arguments, rv.env)
                }
            }
            throw DXUQInterpreterError.invalidSyntax("Unknown primitive: \(name)")
        }
        throw DXUQInterpreterError.invalidSyntax("Receiver isn't a function.")
    }

}
