//
//  AJRLexer.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/3/20.
//

import Foundation

public enum AJRLexerError : Error {
    case noRegisteredActions
    case unknownText(String)
    case invalidPattern(String)
    case invalidInput(String)
    case unmatchedParentheses(String)
}

public typealias AJRLexerAction = (String) throws -> Void

open class AJRLexer: NSObject {

    open var patterns = Dictionary<String,AJRPattern>()
    open var actions = OrderedDictionary<String,AJRLexerAction>()

    public override init() {
    }

    // MARK: - Patterns

    open func addPattern(_ pattern : AJRPattern) -> Void {
        patterns[pattern.identifier] = pattern
    }

    @discardableResult open func addPattern(_ rawPattern : String, named name: String) throws -> AJRPattern {
        let pattern = AJRPattern(identifier: name, pattern: rawPattern, lexer: self)
        addPattern(pattern)
        return pattern
    }

    open func pattern(named name: String) -> AJRPattern? {
        return patterns[name]
    }

    open func associate(pattern: AJRPattern, to action: @escaping AJRLexerAction) -> Void {
        actions[pattern.identifier] = action
    }

    open func associate(name: String, to action: @escaping AJRLexerAction) -> Void {
        if let pattern = patterns[name] {
            associate(pattern: pattern, to: action)
        }
    }

    // MARK: - Lexing

    internal func buildInclusiveRegularExpression() throws -> NSRegularExpression {
        var fullExpression = ""

        if actions.count == 0 {
            throw AJRLexerError.noRegisteredActions
        }

        for (key, _) in actions {
            if let pattern = patterns[key]?.pattern {
                //print("Adding: \(key): \(pattern)")
                // Doing this in the subpattern tells the regex the subexpression that all of it's subexpressions are not to be counting the the numberOfCaptures.
                var subpattern = pattern.replacingOccurrences(of: "(", with: "(?:")
                // Basically \( gets replaced, so if we wind up with \(?:, then replace back to \(.
                subpattern = subpattern.replacingOccurrences(of: "\\(?:", with: "\\(")
                //print("\(key) = r\"\(subpattern)\"")
                if fullExpression.isEmpty {
                    fullExpression = "(\(subpattern))"
                } else {
                    fullExpression += "|(\(subpattern))"
                }
            } else {
                throw AJRLexerError.invalidPattern("Pattern failed to produce a regular expression: \(key)")
            }
        }

        //print("Matching against: \(fullExpression)")
        return try NSRegularExpression(pattern: fullExpression, options: [])
    }

    open func lex(string: String) throws -> Void {
        let regularExpression = try buildInclusiveRegularExpression()

        //print(regularExpression)

        var lastRange : NSRange? = nil
        var foundError : Error? = nil
        regularExpression.enumerateMatches(in: string, options: [], range: string.fullNSRange) { (result, flags, stop) in
            var matchIndex : Int? = nil
            var matchRange : NSRange? = nil
            for x in 0...regularExpression.numberOfCaptureGroups {
                let range = result!.range(at: x)
                if range.location != NSNotFound {
                    matchIndex = x - 1
                    matchRange = result!.range(at: x)
                }
            }
            if let lastRange = lastRange, let matchRange = matchRange {
                let subrange = NSRange(location: lastRange.upperBound, length: matchRange.lowerBound - lastRange.upperBound)
                if subrange.length > 0 {
                    let otherText = string[subrange].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !otherText.isEmpty {
                        foundError = AJRLexerError.unknownText("Unknown text in input: \"\(otherText)\"")
                        stop.pointee = true
                    }
                }
            }
            if foundError == nil {
                if let matchIndex = matchIndex, let matchRange = matchRange {
                    let key = actions[matchIndex].key
                    let callback = actions[key]
                    let substring = string[matchRange]
                    //print("found: \(substring), matched by: \(key)")
                    if let callback = callback {
                        // Should never be null, but let's be safe and not force unwrap.
                        do {
                            try callback(String(substring))
                        } catch {
                            foundError = error
                            stop.pointee = true
                        }
                    }
                }
                lastRange = matchRange
            }
        }
        if foundError == nil, let lastRange = lastRange {
            let otherText = string.suffix(string.utf16.count - lastRange.upperBound)
            if otherText.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) != nil {
                foundError = AJRLexerError.unknownText("Unknown text in input: \"\(otherText)\"")
            }
        }
        if let error = foundError {
            throw error
        }
    }

}
