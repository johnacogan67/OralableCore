//
//  OralableCoreTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//

import XCTest
@testable import OralableCore

final class OralableCoreTests: XCTestCase {

    func testVersion() {
        XCTAssertEqual(CoreVersion.version, "1.0.0")
    }

    func testBuildDate() {
        XCTAssertFalse(CoreVersion.buildDate.isEmpty)
    }
}
