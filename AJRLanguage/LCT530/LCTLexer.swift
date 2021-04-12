//
//  LCTLexer.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 4/6/21.
//

public class LCTLexer: AJRLexer {

    var stack = [SExpression]()

    public override init() {
        super.init()

        do {
            try setupPatterns()
        } catch {
            print("Something went heinously wrong: \(error)")
        }
    }

    // MARK: - Setup

    internal func setupPatterns() throws -> Void {
        // Parentheses
        try self.addPattern("[\\({\\[]", named: "open_paren")
        try self.addPattern("[\\)}\\]]", named: "close_paren")

        // Symbols / Identifiers
        try self.addPattern("[A-Za-z_" +
                                "\\u00A8" +
                                "\\u00AA" +
                                "\\u00AD" +
                                "\\u00AF" +
                                "\\u00B2-\\u00B5" +
                                "\\u00B7-\\u00BA" +
                                "\\u00BC-\\u00BE" +
                                "\\u00C0-\\u00D6" +
                                "\\u00D8-\\u00F6" +
                                "\\u00F8-\\u00FF" +
                                "\\u0100-\\u02FF" +
                                "\\u0370-\\u167F" +
                                "\\u1681-\\u180D" +
                                "\\u180F-\\u1DBF" +
                                "\\u1E00-\\u1FFF" +
                                "\\u200B-\\u200D" +
                                "\\u202A-\\u202E" +
                                "\\u203F-\\u2040" +
                                "\\u2054" +
                                "\\u2060-\\u206F" +
                                "\\u2070-\\u20CF" +
                                "\\u2100-\\u218F" +
                                "\\u2460-\\u24FF" +
                                "\\u2776-\\u2793" +
                                "\\u2C00-\\u2DFF" +
                                "\\u2E80-\\u2FFF" +
                                "\\u3004-\\u3007" +
                                "\\u3021-\\u302F" +
                                "\\u3031-\\u303F" +
                                "\\u3040-\\uD7FF" +
                                "\\uF900-\\uFD3D" +
                                "\\uFD40-\\uFDCF" +
                                "\\uFDF0-\\uFE1F" +
                                "\\uFE30-\\uFE44" +
                                "\\uFE47-\\uFFFD" +
                                "\\U00010000-\\U0001FFFD" +
                                "\\U00020000-\\U0002FFFD" +
                                "\\U00030000-\\U0003FFFD" +
                                "\\U00040000-\\U0004FFFD" +
                                "\\U00050000-\\U0005FFFD" +
                                "\\U00060000-\\U0006FFFD" +
                                "\\U00070000-\\U0007FFFD" +
                                "\\U00080000-\\U0008FFFD" +
                                "\\U00090000-\\U0009FFFD" +
                                "\\U000A0000-\\U000AFFFD" +
                                "\\U000B0000-\\U000BFFFD" +
                                "\\U000C0000-\\U000CFFFD" +
                                "\\U000D0000-\\U000DFFFD" +
                                "\\U000E0000-\\U000EFFFD" +
                                "]", named: "id_head")
        try self.addPattern("({id_head})|([0-9\\u002D\\u003F\\u0021" +
                                "\\u0300–\\u036F" +
                                "\\u1DC0–\\u1DFF" +
                                "\\u20D0–\\u20FF" +
                                "\\uFE20–\\uFE2F" +
                                "])", named: "id_character")
        try self.addPattern("{id_head}{id_character}*", named: "id")
        try self.addPattern("[-]?", named: "possible_negative")

        // Literals
        try self.addPattern("(-?{floating-point-literal})|(-?{integer-literal})", named: "numeric-literal")

        // Decimal Numbers
        try self.addPattern("[0-9]", named: "decimal-digit")
        try self.addPattern("[0-9]+", named: "decimal-digits")
        try self.addPattern("({decimal-digit})|_", named: "decimal-literal-character")
        try self.addPattern("{decimal-digit}{decimal-literal-character}*", named: "decimal-literal")

        // Hexidecimal Numbers
        try self.addPattern("[0-9A-Fa-f]", named: "hexadecimal-digit")
        try self.addPattern("({hexadecimal-digit})|_", named: "hexadecimal-literal-character")
        try self.addPattern("0x{hexadecimal-digit}{hexadecimal-literal-character}*", named: "hexadecimal-literal")

        // Octal Numbers
        try self.addPattern("[0-7]", named: "octal-digit")
        try self.addPattern("({octal-digit})|_", named: "octal-literal-character")
        try self.addPattern("0o{octal-digit}{octal-literal-character}*", named: "octal-literal")

        // Binary Numbers
        try self.addPattern("[0-1]", named: "binary-digit")
        try self.addPattern("({binary-digit})|_", named: "binary-literal-character")
        try self.addPattern("0b{binary-digit}{binary-literal-character}*", named: "binary-literal")

        // Integer Numbers
        try self.addPattern("({decimal-literal}|{hexadecimal-literal}|{octal-literal}|{binary-literal})", named: "integer-literal")

        // Floating Point Numbers
        try self.addPattern("[eE]", named: "floating-point-e")
        try self.addPattern("[pP]", named: "floating-point-p")
        try self.addPattern("\\.{decimal-literal}", named: "decimal-fraction")
        try self.addPattern("{floating-point-e}{sign}?{decimal-literal}", named: "decimal-exponent")
        try self.addPattern("[eE]", named: "floating-point-e")
        try self.addPattern("[pP]", named: "floating-point-p")
        try self.addPattern("\\.{hexadecimal-digit}{hexadecimal-literal-character}*", named: "hexadecimal-fraction")
        try self.addPattern("{floating-point-p}{sign}?{decimal-literal}", named: "hexadecimal-exponent")
        try self.addPattern("({decimal-literal}{decimal-fraction}?{decimal-exponent}?)" +
                                "|{hexadecimal-literal}{hexadecimal-fraction}?{hexadecimal-exponent}", named: "floating-point-literal")
        try self.addPattern("[-+]", named: "sign")

        // Strings
        try self.addPattern("{static-string-literal}", named: "string-literal")
        try self.addPattern("\"", named: "string-literal-opening-delimiter")
        try self.addPattern("\"", named: "string-literal-closing-delimiter")
        try self.addPattern("{string-literal-opening-delimiter}{quoted-text}?{string-literal-closing-delimiter}", named: "static-string-literal")
        try self.addPattern("{quoted-text-item}+", named: "quoted-text")
        try self.addPattern("({escaped-character})|[^\\\"\\\\\\u000A\\u000D]", named: "quoted-text-item")
        try self.addPattern("\\\\", named: "escape-sequence")
        // TODO: Get unicode escapes working. We need the {1-8} pattern working in AJRself.swift.
        try self.addPattern("({escape-sequence}0)" +
                                "|({escape-sequence}\\\\)" +
                                "|({escape-sequence}t)" +
                                "|({escape-sequence}n)" +
                                "|({escape-sequence}r)" +
                                "|({escape-sequence}\")" +
                                "|({escape-sequence}\')", named: "escaped-character")

        // Operators
        try self.addPattern("[:\\/=\\-\\+!\\*%<>&\\|\\^~\\?" +
                                "\\u00A1-\\u00A7" +
                                "\\u00A9-\\u00AB" +
                                "\\u00AC-\\u00AE" +
                                "\\u00B0-\\u00B1" +
                                "\\u00B6" +
                                "\\u00BB" +
                                "\\u00BF" +
                                "\\u00D7" +
                                "\\u00F7" +
                                "\\u2016-\\u2017" +
                                "\\u2020-\\u2027" +
                                "\\u2030-\\u203E" +
                                "\\u2041-\\u2053" +
                                "\\u2055-\\u205E" +
                                "\\u2119-\\u23FF" +
                                "\\u2500-\\u2775" +
                                "\\u2794-\\u2BFF" +
                                "\\u2E00-\\u2E7F" +
                                "\\u3001-\\u3003" +
                                "\\u3008-\\u3020" +
                                "\\u3030]", named: "operator_head")
        try self.addPattern("({operator_head})|[\\u0300-\\u036F" +
                                "\\u1DC0-\\u1DFF" +
                                "\\u20D0-\\u20FF" +
                                "\\uFE00-\\uFE0F" +
                                "\\uFE20-\\uFE2F" +
                                "\\u00E0100-\\u00E01EF]", named: "operator_body")
        try self.addPattern("{operator_head}{operator_body}*", named: "operator")

        // Top level expressions, which indicate we do something.
        self.associate(name: "open_paren") { (value) in
            if debug {
                print("open paren: \(value)")
            }
            self.addExpression(ArrayExpression(openParen: value))
        }
        self.associate(name: "close_paren") { (value) in
            if debug {
                print("close paren")
            }
            if self.stack.count == 1 {
                throw AJRLexerError.unmatchedParentheses("")
            }
            self.stack.removeLast()
        }
        self.associate(name: "numeric-literal") { (value) in
            let set : CharacterSet
            if value.hasPrefix("0x") {
                set = CharacterSet(charactersIn: ".pP")
            } else {
                set = CharacterSet(charactersIn: ".eE")
            }
            if value.rangeOfCharacter(from: set) == nil {
                // We have an integer
                if debug {
                    print("integer: \(value)")
                }
                self.addExpression(NumberExpression(Int(atol(value))))
            } else {
                // We have a real
                if debug {
                    print("real: \(value)")
                }
                self.addExpression(NumberExpression(Double(atof(value))))
            }
        }
        self.associate(name: "string-literal") { (value) in
            let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if debug {
                print("string: \(trimmed)")
            }
            let regex = try! NSRegularExpression(pattern: #"\\n"#, options: [])

            var lastRange : NSRange? = nil
            var newString = ""
            var error : Error? = nil
            regex.enumerateMatches(in: trimmed, options: [], range: trimmed.fullNSRange) { (result, flags, stop) in
                var matchRange : NSRange? = nil
                for x in 0...regex.numberOfCaptureGroups {
                    let range = result!.range(at: x)
                    if range.location != NSNotFound {
                        matchRange = result!.range(at: x)
                    }
                }
                if let lastRange = lastRange, let matchRange = matchRange {
                    let subrange = NSRange(location: lastRange.upperBound, length: matchRange.lowerBound - lastRange.upperBound)
                    if subrange.length > 0 {
                        let otherText = trimmed[subrange].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !otherText.isEmpty {
                            newString += otherText
                        }
                    }
                } else if let matchRange = matchRange {
                    let otherText = trimmed.prefix(matchRange.lowerBound)
                    if !otherText.isEmpty {
                        newString += otherText
                    }
                }
                if let matchRange = matchRange {
                    var substring = trimmed[matchRange]
                    switch substring {
                    case "\\n":
                        substring = "\n"
                    case "\\0":
                        substring = "\0"
                    case "\\\\":
                        substring = "\\"
                    case "\\t":
                        substring = "\t"
                    case "\\r":
                        substring = "\r"
                    case "\\\"":
                        substring = "\""
                    case "\\'":
                        substring = "\'"
                    default:
                        error = AJRLexerError.invalidInput("Unknown escape in string: \(substring)")
                    }
                    newString += substring
                }
                lastRange = matchRange

                if error != nil {
                    stop.pointee = true
                }
            }

            if let error = error {
                throw error
            } else {
                if let lastRange = lastRange {
                    let otherText = trimmed.suffix(trimmed.utf16.count - lastRange.upperBound)
                    newString += otherText
                } else {
                    newString = trimmed
                }
                self.addExpression(StringExpression(newString))
            }
        }
        self.associate(name: "id") { (value) in
            if debug {
                print("id: \(value)")
            }
            self.addExpression(SymbolExpression(value))
        }
        self.associate(name: "operator") { (value) in
            if debug {
                print("operator: \(value)")
            }
            // LCT530 doesn't distinguish operators from symbols.
            self.addExpression(SymbolExpression(value))
        }
    }

    public func lexSExpression(_ string: String) throws -> SExpression? {
        let expressions = try lexSExpressions(string)
        if expressions.count == 0 {
            return nil
        } else if expressions.count == 1 {
            return expressions[0]
        }
        throw AJRLexerError.invalidInput("Expected only one top level expression.")
    }

    public func lexSExpressions(_ string: String) throws -> [SExpression] {
        stack.removeAll()
        stack.append(ArrayExpression(openParen: ""))
        try lex(string: string)
        if stack.count > 1 {
            throw AJRLexerError.unmatchedParentheses("")
        }
//        if sExpression == nil {
//            throw AJRLexerError.invalidInput
//        }
        if let array = stack[0] as? ArrayExpression, array.count >= 1 {
            return array.values
        }
        throw AJRLexerError.invalidInput("Corrupted input")
    }

    // MARK: - Utilities

    open func addExpression(_ expression : SExpression) -> Void {
        if let last = self.stack.last as? ArrayExpression {
            last.addValue(expression)
            if expression is ArrayExpression {
                self.stack.append(expression)
            }
        }
    }

}
