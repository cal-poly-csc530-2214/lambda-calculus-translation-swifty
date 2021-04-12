//
//  DXUQSymbol.swift
//  AJRLanguage
//
//  Created by AJ Raftis on 11/6/20.
//

import Foundation

public typealias Symbol = String

public extension Symbol {

    static func isProtected(_ symbol : Symbol) -> Bool {
        return protectedSymbols.contains(symbol)
    }

    static func isValidName(_ symbol : Symbol) -> Bool {
        return !isProtected(symbol) && Primitive[symbol] == nil
    }

}

internal var protectedSymbols : Set<Symbol> = ["fn", "let", "in", "var", ":="]
