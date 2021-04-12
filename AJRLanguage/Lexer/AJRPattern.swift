//
//  AJRPattern.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/3/20.
//

import Foundation

public enum AJRPatternError : Error {
    case undefinedSubpattern(String)
    case invalidRegularExpression(String)
    case invalidPattern(String)
}

open class AJRPattern: NSObject {

    // MARK: - Properties

    public var identifier : String                  // A unique identifier or the pattern.
    public var basePattern : String                 // The pattern before subpattern expansion
    private var _pattern : String?                  // The expanded pattern
    public var pattern : String? {
        if _pattern == nil {
            do {
                if let lexer = lexer {
                    _pattern = try AJRPattern.replaceSubpatterns(in: basePattern, with: lexer.patterns)
                }
            } catch {
                self.error = error
            }
        }
        return _pattern
    }
    private var _expression : NSRegularExpression?  // The compiled expression.
    public var expression : NSRegularExpression? {
        if _expression == nil {
            if let pattern = self.pattern {
                do {
                    _expression = try NSRegularExpression(pattern: pattern,
                                                          options: [.dotMatchesLineSeparators,
                                                                    .useUnixLineSeparators,
                                                                    .allowCommentsAndWhitespace])
                } catch {
                    self.error = error
                }
            } else {
                self.error = AJRPatternError.invalidPattern(basePattern)
            }
        }
        return _expression
    }
    public weak var lexer : AJRLexer?               // The lexer that contains this pattern.
    public var error : Error?                       // An error, if one occurs.

    // MARK: - Initialization

    public init(identifier: String, pattern: String, lexer: AJRLexer) {
        self.identifier = identifier
        self.basePattern = pattern
        self.lexer = lexer
        
        super.init()
    }

    // MARK: - Matching

    public func matches(_ string : String) -> Bool {
        if let expression = expression {
            return expression.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))?.range.location == 0
        }
        return false
    }

    // MARK: - Helpers

    open class func replaceSubpatterns(in string : String, with patterns: [String:AJRPattern]) throws -> String {
        let patternExpression = try! NSRegularExpression(pattern: "\\{[A-Za-z_-][A-Za-z0-9_-]*\\}", options: [])

        var output : String? = nil
        var lastRange : NSRange? = nil
        var error : Error? = nil
        patternExpression.enumerateMatches(in: string, options: [], range: string.fullNSRange) { (result, flags, stop) in
            if let result = result {
                let range = result.range
                if let lastRange = lastRange {
                    let subrange = NSRange(location: lastRange.upperBound, length: range.lowerBound - lastRange.upperBound)
                    if subrange.length > 0 {
                        output! += string[subrange]
                    }
                } else {
                    // No string yet, so start is 0.
                    output = String(string.prefix(range.location))
                }
                let foundKey = string[range]
                let key = foundKey[foundKey.index(foundKey.startIndex, offsetBy: 1) ...
                                    foundKey.index(foundKey.endIndex, offsetBy: -2)]
                if let subpattern = patterns[String(key)],
                   let pattern = subpattern.pattern {
                    if output == nil {
                        output = "(" + pattern + ")"
                    } else {
                        output! += "(" + pattern + ")"
                    }
                } else {
                    error = AJRPatternError.undefinedSubpattern("Unknown subpattern: \(key)")
                }
                lastRange = range
            }
        }
        if let error = error {
            throw error
        } else {
            if let lastRange = lastRange {
                output! += string.suffix(string.utf16.count - lastRange.upperBound)
            } else {
                // This means no patterns were found, so just return input.
                output = string
            }
        }

        return output!
    }

    // MARK: - CustomStringConvertable

    open override var description: String {
        return "<\(descriptionPrefix): \(identifier): \"\(basePattern)\">"
    }

}
