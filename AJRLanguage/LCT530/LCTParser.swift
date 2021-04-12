//
//  LCTParser.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 4/7/21.
//

import Foundation

public enum LCTParseError : Error {
    case invalidInput(String)
}

public func LCTParse(_ string: String) throws -> ExprC {
    return try LCTParser.parse(string)
}

public func LCTParse(_ expression: SExpression) throws -> ExprC {
    return try LCTParser.parse(expression)
}

public func LCTParse(_ expressions: [SExpression]) throws -> [ExprC] {
    return try expressions.map { try LCTParser.parse($0) }
}

open class LCTParser: NSObject {

    open func parse(_ expression: SExpression) throws -> ExprC {
        if let expression = expression as? NumberExpression<Double> {
            return ValueC(RealV(expression.value))
        }
        if let expression = expression as? NumberExpression<Int> {
            return ValueC(IntV(expression.value))
        }
        if let expression = expression as? StringExpression {
            return ValueC(StringV(expression.value))
        }
        if let expression = expression as? SymbolExpression {
            return try IdC(expression.name)
        }
        if let expressions = expression as? ArrayExpression,
           expressions.values.count == 3,
           let variable = expressions.values[0] as? SymbolExpression,
           SymbolExpression.matches(symbol: expressions[1], named: ":=") {
            return SetC(variable: variable.name, argument: try parse(expressions.values[2]))
        }
        if let expressions = expression as? ArrayExpression,
           expressions.count > 0,
           SymbolExpression.matches(symbol: expressions[0], named: "fn"),
           let arguments = ArrayExpression.values(expressions[1], as: SymbolExpression.self) {
            let argumentNames = arguments.map { (exp) -> Symbol in
                return exp.name
            }
            if argumentNames.count != Set(argumentNames).count {
                throw LCTParseError.invalidInput("Duplicate parameter names: \(argumentNames.componentsJoinedByString(separator: " ")).")
            }
            return LambdaC(args: argumentNames, body: try parse(expressions[2]))
        }
        if let expressions = expression as? ArrayExpression,
           expressions.count >= 4,
           SymbolExpression.matches(symbol: expressions[0], named: "let"),
           let inIndex = expressions.values.firstIndex(where: { (expression) -> Bool in
                return SymbolExpression.matches(symbol: expression, named: "in")
           }),
           // Now that we know where inIndex is, make sure we have inIndex + 1 arguments
           expressions.count == inIndex + 2 {
            let declarationExpressions = try buildLetDeclarations(declarations: expressions.values[1..<inIndex])
            let body = try parse(expressions[inIndex + 1])
            //print(declarationExpressions)
            //print(body)
            return LetC(variables: declarationExpressions.map { SetC(variable: $0.symbol, argument: $0.body) }, body: body)
        }
        if let expressions = expression as? ArrayExpression,
           expressions.count > 0 {
            let body = try parse(expressions[0])
            let arguments = try expressions.values[1..<expressions.values.count].map { (subexpression) -> ExprC in
                return try parse(subexpression)
            }
            return AppC(function: body, arguments: arguments)
        }

        throw LCTParseError.invalidInput("Unknown token in input.")
    }

    internal typealias LetTuple = (symbol : Symbol, body : ExprC)

    internal func buildLetDeclarations(declarations : ArraySlice<SExpression>) throws -> [LetTuple] {
        return try declarations.map { (expression) -> LetTuple in
            if let expressions = expression as? ArrayExpression,
               expressions.count == 3,
               let symbol = try parse(expressions[0]) as? IdC,
               SymbolExpression.matches(symbol: expressions[1], named: "=") {
                return (symbol: symbol.name, body: try parse(expressions[2]))
            }
            throw LCTParseError.invalidInput("Bad let syntax")
        }
    }

    open class func parse(_ expression: SExpression) throws -> ExprC {
        return try LCTParser().parse(expression)
    }

    open class func parse(_ string: String) throws -> ExprC {
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ValueC(NullV())
        }
        if let expression = try LCTLexer().lexSExpression(string) {
            return try LCTParser().parse(expression)
        }
        return ValueC(VoidV())
    }

}
