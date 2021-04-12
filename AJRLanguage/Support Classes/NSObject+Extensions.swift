//
//  NSObject+Extensions.swift
//  AJRFoundation
//
//  Created by AJ Raftis on 2/9/19.
//

import Foundation

@objc
public extension NSObject {
    
    var descriptionPrefix : String {
        get {
            return "\(Self.self): 0x\(String(unsafeBitCast(self, to:Int.self), radix:16))"
        }
    }
    
}
