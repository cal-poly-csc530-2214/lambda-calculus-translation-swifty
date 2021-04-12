//
//  NSString+Extensions.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/6/20.
//

import Foundation

public extension String {

    var fullNSRange : NSRange {
        return NSRange(location: 0, length: self.utf16.count)
    }

    var fullRange : Range<String.Index> {
        return self.startIndex ..< self.endIndex
    }

    subscript(_ range: NSRange) -> SubSequence {
        return self[self.index(self.startIndex, offsetBy: range.location) ... self.index(self.startIndex, offsetBy: range.location + range.length - 1)]
    }

}
