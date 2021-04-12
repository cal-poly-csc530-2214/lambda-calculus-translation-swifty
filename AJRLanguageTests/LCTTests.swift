//
//  LCTTests.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 4/7/21.
//

import XCTest
import AJRLanguage

class LCTTests: XCTestCase {

    func _test(string: String, using lexer: LCTLexer) throws -> Void {
        if let sExpression = try lexer.lexSExpression(string) {
            print("———————————————————————————————————————")
            print("input: \(string)")
            print("result: \(sExpression)")
            let expression = try LCTParse(sExpression)
            print("AST: \(expression)")
            print("swift:\n\(expression.swiftString(in: Environment.root))")
        }
    }

    func testLexer() -> Void {
        do {
            let lexer = LCTLexer()

            let test = """
                {let
                  {f = {fn {x} {+ x 14}}}
                  in
                  {f 2}}
            """

            try _test(string: "10", using: lexer)
            try _test(string: "{+ 1 2}", using: lexer)
            try _test(string: "{+ 1 {- 2 3}}", using: lexer)
            try _test(string: "{fn {x y} {+ x y}}", using: lexer)
            try _test(string: test, using: lexer)
            try _test(string: "{print {* 5 2}}", using: lexer)
            try _test(string: "{begin {+ 1 2} {+ 2 3}}", using: lexer)
            try _test(string: "{if {<= {- 10 5} 0} {+ 10 5} {/ 10 5}}", using: lexer)
            try _test(string: """
                              {let
                                {fact = {fn {n} 0}}
                              in
                              {begin
                                {fact := {fn {n} {if {<= n 0} 1 {* n {fact {- n 1}}}}}}
                                {print "12! =" {fact 12}}
                                {fact 12}}}
                              """, using: lexer)
        } catch {
            XCTAssert(false, "We had an error: \(error)")
        }
    }

    public func testResult() -> Void {

        let left : Any = Int64(1)
        let right : Any = Int64(2)
        print("\(left + right)")

        func main() -> Any {
            var fact = { (n: Any) -> Any in 0 }

            return { () -> Any in
                _ = fact = { (n: Any) -> Any in {() -> Any in
                    if (n <= 0) {
                        return 1
                    } else {
                        return (n * fact((n - 1)))
                    }
                }() }
                _ = print("12! =", fact(12))
                return fact(12)
            }()
        }

        XCTAssert(integer(from: main())! == 479001600)
    }
}

func integer(from value: Any) -> Int64? {
    if let value = value as? Int { return Int64(value) }
    if let value = value as? Int8 { return Int64(value) }
    if let value = value as? Int16 { return Int64(value) }
    if let value = value as? Int32 { return Int64(value) }
    if let value = value as? Int64 { return value }
    if let value = value as? UInt { return Int64(value) }
    if let value = value as? UInt8 { return Int64(value) }
    if let value = value as? UInt16 { return Int64(value) }
    if let value = value as? UInt32 { return Int64(value) }
    if let value = value as? UInt64 { return Int64(value) }
    if let value = value as? String { return Int64(value) }
    if let value = value as? Bool { return value ? 1 : 0 }
    return nil
}

func boolean(from value: Any) -> Bool? {
    if let value = value as? Int { return value != 0 }
    if let value = value as? Int8 { return value != 0 }
    if let value = value as? Int16 { return value != 0 }
    if let value = value as? Int32 { return value != 0 }
    if let value = value as? Int64 { return value != 0 }
    if let value = value as? UInt { return value != 0 }
    if let value = value as? UInt8 { return value != 0 }
    if let value = value as? UInt16 { return value != 0 }
    if let value = value as? UInt32 { return value != 0 }
    if let value = value as? UInt64 { return value != 0 }
    if let value = value as? String { return value != 0 }
    if let value = value as? Bool { return value }
    return nil
}

func string(from value: Any) -> String {
    return String(describing: value)
}

func + (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left + right
    }
    return 0
}

func - (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left - right
    }
    return 0
}

func < (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left < right
    }
    return false
}

func <= (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left <= right
    }
    return false
}

func > (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left > right
    }
    return false
}

func >= (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left >= right
    }
    return false
}

func == (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left == right
    }
    return false
}

func != (left: Any, right: Any) -> Bool {
    if let left = integer(from: left), let right = integer(from: right) {
        return left != right
    }
    return false
}

func * (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left * right
    }
    return 0
}

func / (left: Any, right: Any) -> Any {
    if let left = integer(from: left), let right = integer(from: right) {
        return left / right
    }
    return 0
}

func && (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return left && right
    }
    return false
}

func || (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return left && right
    }
    return false
}

infix operator ^^

func ^^ (left: Any, right: Any) -> Bool {
    if let left = boolean(from: left), let right = boolean(from: right) {
        return (left && !right) || (!left && right)
    }
    return false
}

