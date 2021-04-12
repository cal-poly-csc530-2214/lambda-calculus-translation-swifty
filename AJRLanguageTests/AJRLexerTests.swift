//
//  AJRLexerTests.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 11/3/20.
//

import XCTest

import AJRLanguage

class AJRLexerTests: XCTestCase {

    func testSimpleLexerErrors() throws -> Void {
        XCTAssertThrowsError(try Interpret("{+ 1 1}}"))
        XCTAssertThrowsError(try Interpret("{{+ 1 1}"))
        XCTAssert(try Interpret("") == "null")
    }

    func testSimpleLexerExpressions() throws -> Void {
        let lexer = DXUQLexer()

        XCTAssertThrowsError(try lexer.lexSExpression("10 { 10 }"))
        XCTAssert(try lexer.lexSExpressions("10 { 10 }").count == 2)

        let expression = try lexer.lexSExpression(#"{ "a" "\n" "b" "\n" "test\nme" }"#)
        XCTAssert(expression is ArrayExpression)
        XCTAssert((expression as! ArrayExpression).count == 5)
    }

    func testSimpleTokens() throws {
        let lexer = AJRLexer()
        do {
            try lexer.addPattern("[0-9]", named: "hdexdigit")
            try lexer.addPattern("[a-fA-F]", named: "hexalpha")
            try lexer.addPattern("({hdexdigit}|{hexalpha})+", named: "hextail")
            let hexPattern = try lexer.addPattern("0[xX]{hextail}", named: "hex")
            try lexer.addPattern("[a-zA-Z]", named: "alpha")
            let keywordPattern = try lexer.addPattern("{alpha}+", named: "keyword")

            var foundHex = false
            var foundKeyword = false

            lexer.associate(pattern: hexPattern) { (value) in
                print("hex: \(value)")
                foundHex = true
            }
            lexer.associate(pattern: keywordPattern) { (value) in
                print("keyword: \(value)")
                foundKeyword = true
            }

            try lexer.lex(string: "value 0xDEADBEEF")

            XCTAssertTrue(foundHex, "We didn't find our hex digit.")
            XCTAssertTrue(foundKeyword, "We didn't find our keyword.")

            do {
                try lexer.lex(string: "value _ 0xDEADBEEF")
            } catch AJRLexerError.unknownText(let message) {
                XCTAssert(message == "Unknown text in input: \"_\"")
            }
        } catch {
            XCTAssert(false, "We had an error: \(error)")
        }
    }

    func testComplexLanguage() -> Void {
        do {
            let lexer = DXUQLexer()

            let test = """
                {let
                  {f = {fn {x} {+ x 14}}}
                  in
                  {f 2}}
            """

            if let expression = try lexer.lexSExpression("10") {
                print("result: \(expression)")
                print("parse result: \(try Parse(expression))")
            }

            if let expression = try lexer.lexSExpression("{+ 1 2}") {
                print("result: \(expression)")
                print("parse result: \(try Parse(expression))")
            }

            if let expression = try lexer.lexSExpression(test) {
                print("result: \(expression)")
                print("parse result: \(try Parse(expression))")
            }
        } catch {
            XCTAssert(false, "We had an error: \(error)")
        }
    }

    func testEnvironmentAndStorage() -> Void {
        XCTAssertFalse(Environment().contains("a"))
        let e1 = Environment().extend([(name: "a", value: RealV(1.0))])
        XCTAssertTrue(e1.contains("a"))
        XCTAssertFalse(Environment().contains("b"))
        XCTAssert(e1["a"]!.equals(RealV(1.0)))
        XCTAssert(e1.valueBindings.count > 0)
        XCTAssert(e1.description == "<Environment: <Binding: a: 1>>")
        XCTAssertThrowsError(try e1.updateStorage(name: "undefined", value: VoidV()))
    }

    internal func checkParse(_ string: String) -> Void {
        XCTAssert(try Parse(string).unparse() == string)
    }

    func testParse() throws -> Void {
        XCTAssert(try Parse("10").equals(ValueC((RealV(10)))))
        XCTAssert(try Parse("-10").equals(ValueC((RealV(-10)))))
        checkParse("{+ 10 5}")
        checkParse("{+ 10 {+ 2 3}}")
        checkParse("{* 10 5}")
        checkParse("{* 10 {+ 2 3}}")
        checkParse("{- 10 5}")
        checkParse("{/ 10 5}")
        checkParse("{if {<= {- 10 5} 0} {+ 10 5} {/ 10 5}}")
        checkParse("{if {<= {- 10 15} 0} {+ 10 5} {/ 10 5}}")
        checkParse("{if {<= {- 10 5} 0} 5 2}")
        checkParse("{addone x}")
        checkParse("{fn {x y z} {+ x {+ y z}}}")
        checkParse("{fn {x} {+ x 1}}")
        checkParse("{x := 1}")
    }

    func checkInterpError(_ string: String) -> Void {
        var hadError = false
        do {
            _ = try Interpret(string)
        } catch {
            hadError = true
        }
        XCTAssertTrue(hadError, "Expected an error with input: \(string)")
    }

    func testInterp() throws -> Void {
        XCTAssert(try Interpret("{+ 1 1}") == "2")

        let simpleProg1 =   """
                            {let
                               {f = {fn {x} {+ x 14}}}
                               in
                               {f 2}}
                            """
        let simpleProg2 =   """
                            {let
                               {f = {fn {x} {+ x 14}}}
                               {my-add = {fn {x y} {+ x y}}}
                               in
                               {f 2}}
                            """
        let simpleProg3 =   """
                            {let
                               {f = {fn {x} {+ x 14}}}
                               {my-add = {fn {x y} {+ x y}}}
                               in
                               {my-add 2 3}}
                            """
        let simpleProg4 =   """
                            {let
                               {f = {fn {x} {+ x 14}}}
                               {my-add = {fn {x y} {+ x y}}}
                               {my-const = -1}
                               in
                               my-const}
                            """
        let badSymbolProg = """
                            {let
                               {f = {fn {x} {+ x 14}}}
                               {my-add = {fn {x y} {+ x y}}}
                               {my-const = -1}
                               in
                               let}
                            """
        // NOTE: Program should fail, as it relies on dynamic scope.
        let midTermProg =   """
                            {let
                               {f = {fn {x y} {+ {g x} y}}}
                               {g = {fn {n} {+ n 1}}}
                               in
                               {f 1 {g 2}}}
                            """
        let badProg1 =      """
                            {let
                                {f = {fn {x x} {+ x x}}}
                                in
                                {f 2 3}}
                            """
        let badProg2 =      """
                            {let
                                {in = {fn {x y} {- x y}}}
                                in
                                {+ 2 3}}
                            """

        var gotError = false

        XCTAssert(try Interpret(simpleProg1) == "16")
        XCTAssert(try Interpret(simpleProg2) == "16")
        XCTAssert(try Interpret(simpleProg3) == "5")
        XCTAssert(try Interpret(simpleProg4) == "-1")

        gotError = false
        do {
            _ = try Interpret(badSymbolProg)
        } catch {
            gotError = true
        }
        XCTAssertTrue(gotError)

        gotError = false
        do {
            _ = try Interpret(badProg1)
        } catch {
            gotError = true
        }
        XCTAssertTrue(gotError)

        gotError = false
        do {
            _ = try Interpret(badProg2)
        } catch {
            gotError = true
        }
        XCTAssertTrue(gotError)

        gotError = false
        do {
            _ = try Interpret(midTermProg)
        } catch {
            gotError = true
        }
        XCTAssertTrue(gotError)

        //XCTAssert(try Interpret(Parse(""), env: Environment.root)
        XCTAssert(try Interpret(Parse("10"), env: Environment.root).value.equals(RealV(10)))
        XCTAssert(try Interpret(Parse("-10"), env: Environment.root).value.equals(RealV(-10)))
        XCTAssert(try Interpret(Parse("{+ 10 5}"), env: Environment.root).value.equals(RealV(15)))
        XCTAssert(try Interpret(Parse("{+ 10 {+ 2 3}}"), env: Environment.root).value.equals(RealV(15)))
        XCTAssert(try Interpret(Parse("{* 10 5}"), env: Environment.root).value.equals(RealV(50)))
        XCTAssert(try Interpret(Parse("{* 10 {+ 2 3}}"), env: Environment.root).value.equals(RealV(50)))
        XCTAssert(try Interpret(Parse("{- 10 5}"), env: Environment.root).value.equals(RealV(5)))
        XCTAssert(try Interpret(Parse("{/ 10 5}"), env: Environment.root).value.equals(RealV(2)))

        XCTAssert(try Interpret("{if {<= {- 10 5} 0} {+ 10 5} {/ 10 5}}") == "2")
        XCTAssert(try Interpret("{if {<= {- 10 10} 0} {+ 10 5} {/ 10 5}}") == "15")
        XCTAssert(try Interpret("{if {<= {- 10 5} 0} 5 2}") == "2")
        XCTAssert(try Interpret("{if {< {- 10 5} 0} {+ 10 5} {/ 10 5}}") == "2")
        XCTAssert(try Interpret("{if {< {- 10 10} 0} {+ 10 5} {/ 10 5}}") == "2")
        XCTAssert(try Interpret("{if {< {- 10 15} 0} 5 2}") == "5")
        XCTAssert(try Interpret("{if {>= {- 10 5} 0} {+ 10 5} {/ 10 5}}") == "15")
        XCTAssert(try Interpret("{if {>= {- 10 10} 0} {+ 10 5} {/ 10 5}}") == "15")
        XCTAssert(try Interpret("{if {>= {- 10 15} 0} 5 2}") == "2")
        XCTAssert(try Interpret("{if {> {- 10 5} 0} {+ 10 5} {/ 10 5}}") == "15")
        XCTAssert(try Interpret("{if {> {- 10 10} 0} {+ 10 5} {/ 10 5}}") == "2")
        XCTAssert(try Interpret("{if {> {- 10 15} 0} 5 2}") == "2")

        checkInterpError("{if \"mom\" {+ 10 5} {/ 10 5}}")
        checkInterpError("{if {<= {- 10 5} 0} {+ 10 5} {/ 10 5} 0}")
        checkInterpError("{if {<= {- 10 5} 0} {+ 10 5}}")
        checkInterpError("{if {<= {- 10 5} 0}}")
        checkInterpError("{if}")
        checkInterpError("{{fn {x} {+ x x}} 10 10}")

        let simpleEnv = Environment.root.extend([(name: "x", value: RealV(5.0)),
                                                 (name: "y", value: RealV(7.0))])
        XCTAssert(try Interpret("{+ x y}", env: simpleEnv) == "12")

        checkInterpError("{+ 10 false}")
        checkInterpError("{{fn {x x} {+ x x}} 1 2}")
        checkInterpError("{+ if var}")

        XCTAssert(try Interpret("{{fn {x y} {+ x y}} 1 2}") == "3")
        XCTAssert(try Interpret("{<= 1 0}") == "false")
        XCTAssert(try Interpret("{<= 1 2}") == "true")
        XCTAssert(try Interpret("{equal? \"hi\" \"hi\"}") == "true")
        XCTAssert(try Interpret("{equal? \"hi\" \"mom\"}") == "false")
        XCTAssert(try Interpret("{equal? void null}") == "false")
        XCTAssert(try Interpret("{equal? void void}") == "true")
        XCTAssert(try Interpret("{equal? null null}") == "true")
        XCTAssert(try Interpret("{begin}") == "void")
        XCTAssertThrowsError(try Interpret("{/ 1 0}"))

        XCTAssertThrowsError(try Interpret("{{}}"))

        XCTAssert(try Interpret(#"""
                                {print "hi" "\n"
                                       1.0 "\n"
                                       true "\n"
                                       false "\n"
                                       void "\n"
                                       + "\n"
                                       {fn (x) {+ x x}} "\n"
                                       null "\n"
                                       (new-array 5 0) "\n"}
                                """#) == "void")

        XCTAssert(try Interpret("{if true \"a\" \"b\"}") == "\"a\"")
        XCTAssert(try Interpret("{if false \"a\" \"b\"}") == "\"b\"")
        XCTAssert(try Interpret("{if {and true true} \"a\" \"b\"}") == "\"a\"")
        XCTAssert(try Interpret("{if {and true false} \"a\" \"b\"}") == "\"b\"")
        XCTAssert(try Interpret("{if {and false true} \"a\" \"b\"}") == "\"b\"")
        XCTAssert(try Interpret("{if {or true false} \"a\" \"b\"}") == "\"a\"")
        XCTAssert(try Interpret("{if {or false false} \"a\" \"b\"}") == "\"b\"")
        XCTAssert(try Interpret("{if {not false} \"a\" \"b\"}") == "\"a\"")
        XCTAssert(try Interpret("{xor false false}") == "false")
        XCTAssert(try Interpret("{xor false true}") == "true")
        XCTAssert(try Interpret("{xor true false}") == "true")
        XCTAssert(try Interpret("{xor true true}") == "false")
        XCTAssert(try Interpret("{begin {+ 1 2} {+ 2 3}}") == "5")
        XCTAssert(try Interpret("{let {x = 1} in {begin {x := {+ x x}} x}}") == "2")
        // This is no longer invalid
        //XCTAssertThrowsError(try Interpret("{let {x = 1} in {begin {y := {+ x x}} x}}"))
    }

    func testPrimitives() -> Void {
        XCTAssert(Primitive["+"] != nil)
        XCTAssert(Primitive["-"] != nil)
        XCTAssert(Primitive["*"] != nil)
        XCTAssert(Primitive["/"] != nil)
        XCTAssert(Primitive["✕"] == nil)
    }

    func testSerialize() -> Void {
        XCTAssert(RealV(1.1).serialize() ==  "1.1")
        XCTAssert(BoolV(true).serialize() == "true")
        XCTAssert(BoolV(false).serialize() == "false")
        XCTAssert(StringV("hi").serialize() == "\"hi\"")
        XCTAssert(ClosureV(args: ["x", "y"], body: ValueC(RealV(10)), env: Environment()).serialize() == "#<procedure>")
        XCTAssert(PrimitiveV(name: "+").serialize() == "#<primop>")
        XCTAssert(VoidV().serialize() == "void")
        XCTAssert(NullV().serialize() == "null")
        XCTAssert(ArrayStorageV(values: [RealV(0), RealV(0), RealV(0)]).serialize() == "#<array>")
    }

    func testValuePrintable() -> Void {
        let storage = Storage()

        XCTAssert(RealV(1.0).printable(storage) == "1")
        XCTAssert(BoolV(true).printable(storage) == "true")
        XCTAssert(BoolV(false).printable(storage) == "false")
        XCTAssert(StringV("hi").printable(storage) == "hi")
        XCTAssert(ClosureV(args: ["x", "y", "z"], body: ValueC(RealV(10)), env: Environment(storage: storage)).printable(storage) == "{fn {x y z} 10}")
        XCTAssert(PrimitiveV(name: "+").printable(storage) == "{+ ...}")
        XCTAssert(VoidV().printable(storage) == "void")
        XCTAssert(NullV().printable(storage) == "null")
        XCTAssert(ArrayStorageV(values: [RealV(0), RealV(0), RealV(0), RealV(0), RealV(0)]).printable(storage) == "{array 0 0 0 0 0}")
    }

    func testValueType() -> Void {
        XCTAssert(RealV(1.0).valueType == "Real")
        XCTAssert(BoolV(true).valueType == "Bool")
        XCTAssert(BoolV(false).valueType == "Bool")
        XCTAssert(StringV("hi").valueType == "String")
        XCTAssert(ClosureV(args: ["x", "y", "z"], body: ValueC(RealV(10)), env: Environment(storage: Storage())).valueType == "Closure")
        XCTAssert(PrimitiveV(name: "+").valueType == "Primitive")
        XCTAssert(VoidV().valueType == "Void")
        XCTAssert(NullV().valueType == "Null")
        XCTAssert(ArrayStorageV(values: [RealV(0), RealV(0), RealV(0), RealV(0), RealV(0)]).valueType == "Array")
    }

    func testArrays() -> Void {
        XCTAssert(try Interpret("{equal? {new-array 5 0} {new-array 5 0}}") == "false")
        XCTAssert(try Interpret("{let {a = {array 1 2 3}} in {equal? a a}}") == "true")
        XCTAssert(ArrayStorageV(values: Array(repeating: RealV(0), count: 5)).valueType == "Array")
        XCTAssertThrowsError(try Interpret("{new-array 0 0}"))
        XCTAssert(try Interpret("{array 1 2 3}") == "#<array>")
        XCTAssertThrowsError(try Interpret("{array}"))
        XCTAssertThrowsError(try Interpret("{aref {array 1 2 3} -1}"))
        XCTAssert(try Interpret("{aref {array 1 2 3} 0}") == "1")
        XCTAssert(try Interpret("{aref {array 1 2 3} 1}") == "2")
        XCTAssert(try Interpret("{aref {array 1 2 3} 2}") == "3")
        XCTAssertThrowsError(try Interpret("{aref {array 1 2 3} 3}"))
        XCTAssertThrowsError(try Interpret("{aref true 3}"))
        XCTAssert(try Interpret("{let {a = {array 1 2 3}} in {begin {aset! a 1 4} {aref a 1}}}") == "4")
        XCTAssertThrowsError(try Interpret("{let {l = \"not an array\"} in {aset! l 2 \"mom\"}}"))
        XCTAssertThrowsError(try Interpret("{aset! {+ 1 1} 2 \"mom\"}"))
    }

    func testStrings() -> Void {
        XCTAssert(try Interpret("{equal? {substring \"hi mom\" 0 2} \"hi\"}") == "true")
        XCTAssertThrowsError(try Interpret("{substring \"hi mom\" -1 2}"))
        XCTAssertThrowsError(try Interpret("{substring \"hi mom\" 10 2}"))
        XCTAssertThrowsError(try Interpret("{substring \"hi mom\" 0 -1}"))
        XCTAssertThrowsError(try Interpret("{substring \"hi mom\" 0 10}"))
        XCTAssertThrowsError(try Interpret("{substring \"hi mom\" 2 0}"))
        XCTAssertThrowsError(try Interpret("{substring true 0 2}"))
        XCTAssertThrowsError(try Interpret("{substring \"abcd\" 0 0.23}"))
    }

    func testUnparse() throws -> Void {
        XCTAssert(try Parse("{+ 1 1}").unparse() == "{+ 1 1}")
        XCTAssert(try Parse("{{fn {a} {+ a a}} 5}").unparse() == "{{fn {a} {+ a a}} 5}")
        XCTAssert(try Parse("{{fn {} {+ 1 1}}}").unparse() == "{{fn {} {+ 1 1}}}")
        XCTAssert(try Parse("{x := 1}").unparse() == "{x := 1}")
//        (check-equal? (unparse (parse '{+ 1 1})) "{+ 1 1}")
//        (check-equal? (unparse (parse '{{fn (a) {+ a a}} 5})) "{{fn (a) {+ a a}} 5}")
//        (check-equal? (unparse (parse '{{fn () {+ 1 1}}})) "{{fn () {+ 1 1}}}")
//        ;; We have to specially test this because, for formatting reasons, we won't pass in an empty list.
//        (check-equal? (unparse-list '()) "")
    }

    func testEqual() -> Void {
        let env = Environment.root.extend([(name: "s1", value: StringV("a")),
                                           (name: "s2", value: StringV("b")),
                                           (name: "s3", value: StringV("a")),
                                           (name: "b1", value: BoolV(true)),
                                           (name: "b2", value: BoolV(false)),
                                           (name: "r1", value: RealV(1.0)),
                                           (name: "r2", value: RealV(2.0)),
                                           (name: "r3", value: RealV(1.0)),
                                           (name: "p1", value: PrimitiveV(name: "+")),
                                           (name: "p2", value: PrimitiveV(name: "-")),
                                           (name: "p3", value: PrimitiveV(name: "+"))])
        XCTAssert(try Interpret("{equal? s1 s2}", env: env) == "false")
        XCTAssert(try Interpret("{equal? s1 s3}", env: env) == "true")
        XCTAssert(try Interpret("{equal? r1 r2}", env: env) == "false")
        XCTAssert(try Interpret("{equal? r1 r3}", env: env) == "true")
        XCTAssert(try Interpret("{equal? b1 b2}", env: env) == "false")
        XCTAssert(try Interpret("{equal? b1 b1}", env: env) == "true")
        XCTAssert(try Interpret("{equal? s1 b1}", env: env) == "false")
        XCTAssert(try Interpret("{equal? p1 p2}", env: env) == "false")
        XCTAssert(try Interpret("{equal? p1 p3}", env: env) == "true")
    }

    func testSymbolIsProtected() -> Void {
        XCTAssertFalse(Symbol.isValidName("+"))
        XCTAssertFalse(Symbol.isValidName("if"))
        XCTAssertTrue(Symbol.isValidName("%"))
        XCTAssertFalse(Symbol.isProtected("+"))
        XCTAssertTrue(Symbol.isProtected("fn"))
    }

    func testMiscAdvanced() -> Void {
        XCTAssert(try Interpret("""
                                {let {fact = "bogus"}
                                in
                                {begin
                                    {fact := {fn {n} {if {<= n 0} 1 {* n {fact {- n 1}}}}}}
                                    {fact 12}}}
                                """) == "479001600")
        XCTAssert(try Interpret("""
                                {let {a = 9}
                                    {b = {array 3 false true 19}}
                                    {d = {array "otter"}}
                                    in
                                    {let {c = {fn {}
                                                  {begin
                                                    {aset! d 0 b}
                                                    {aset! b 3 333}
                                                    {+ {aref {aref d 0} 3} a}}}}
                                      in
                                      {c}}}
                                """) == "342")
        XCTAssert(try Interpret("""
                                {let {a = {array 0}}
                                    in {let {a! = {fn {expected}
                                                      {if {equal? {aref a 0} expected}
                                                          {begin
                                                            {aset! a 0 {+ 1 {aref a 0}}}
                                                            273}
                                                          {/ 1 0}}}}
                                         in
                                         {begin
                                           {+ {a! 0} {a! 1}}
                                           {+ {a! 2} {a! 3}}}}}
                                """) == "546")
    }

    func testExpressionChaining() throws -> Void {
        var expressions = try DXUQLexer().lexSExpressions("{+ 1 1} {+ 2 2} {+ 3 3}")

        XCTAssert(expressions.count == 3)
        var returnValue : ReturnValue = (value: NullV(), env: Environment.root)
        for expression in try Parse(expressions) {
            returnValue = try Interpret(expression, env: returnValue.env)
            print("result: \(returnValue.value.serialize())")
        }

        expressions = try DXUQLexer().lexSExpressions("{x := 10} {begin {x := {+ x 5}} x} {+ x 5}")
        XCTAssert(expressions.count == 3)
        returnValue = (value: NullV(), env: Environment.root)
        let expectedResults : [Value] = [VoidV(), IntV(15), IntV(20)]
        for (index, expression) in try Parse(expressions).enumerated() {
            returnValue = try Interpret(expression, env: returnValue.env)
            print("\(index + 1): result: \(returnValue.value.serialize())")
            XCTAssert(returnValue.value.equals(expectedResults[index]))
        }
    }

    func testValues() throws -> Void {
        XCTAssertFalse(ValueC(VoidV()).equals(SetC(variable: "x", argument: ValueC(NullV()))))
        XCTAssertTrue(try IdC("a").equals(IdC("a")))
        XCTAssertFalse(try IdC("a").equals(IdC("b")))
        XCTAssertFalse(try IdC("a").equals(ValueC(VoidV())))

        let e1 = try Parse("{+ 1 1}")
        let e2 = try Parse("{+ 1 2}")
        let e3 = try Parse("{+ 1 1}")
        let e4 = try Parse("{+ 1 1 1}")
        XCTAssertTrue(e1.equals(e3))
        XCTAssertTrue(e1.equals(e1))
        XCTAssertFalse(e1.equals(e2))
        XCTAssertFalse(e1.equals(ValueC(VoidV())))
        XCTAssertFalse(e1.equals(e4))

        XCTAssertTrue(try Parse("{fn {} {+ 1 1}}").equals(try Parse("{fn {} {+ 1 1}}")))
        XCTAssertFalse(try Parse("{fn {} {+ 1 1}}").equals(ValueC(VoidV())))

        XCTAssert(try Parse("{x := 20}").description == "(setC x (valueC (realV 20)))")

        XCTAssertTrue(try Parse("{x := 10}").equals(try Parse("{x := 10}")))
        XCTAssertFalse(try Parse("{x := 10}").equals(try Parse("{x := 20}")))
        XCTAssertFalse(try Parse("{x := 10}").equals(ValueC(VoidV())))
    }

}
