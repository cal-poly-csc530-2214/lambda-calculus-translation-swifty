//
//  DXUQEnvironmentTests.swift
//  AJRLanguageTests
//
//  Created by AJ Raftis on 11/5/20.
//

import XCTest

import AJRLanguage

class DXUQEnvironmentTests: XCTestCase {

    func testRoot() throws {
        let root1 = Environment.root
        let root2 = Environment.root

        XCTAssert(root1.storage !== root2.storage, "Roots are the same")
    }

}
