//
//  main.swift
//  DXUQ
//
//  Created by AJ Raftis on 11/7/20.
//

import Foundation

print("Welcome to DXUQ World! (ctrl-D to exit)")

func readline(prompt: String? = nil, addToHistory: Bool = false) -> String? {
    guard let cString = readline(prompt) else {
        return nil
    }
    defer { free(cString) }
    if addToHistory {
        add_history(cString)
    }
    return String(cString: cString)
}

let lexer = DXUQLexer()
var rv : ReturnValue = (value: NullV(), env: Environment.root)
while let line = readline(prompt: "> ", addToHistory: true) {
    do {
        rv = try Interpret(try Parse(line), env: rv.env)
        if !rv.value.equals(VoidV()) {
            print(rv.value.serialize())
        }
    } catch {
        print("Error: \(error)")
    }
}

print("\nGoodbye!")

