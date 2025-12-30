//
//  AccelerometerConversionTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//

import XCTest
@testable import OralableCore

final class AccelerometerConversionTests: XCTestCase {

    // MARK: - Sensitivity Tests

    func testSensitivityValues() {
        XCTAssertEqual(AccelerometerConversion.sensitivity2g, 0.244, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity4g, 0.488, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity8g, 0.976, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity16g, 1.952, accuracy: 0.001)
    }

    func testSensitivityForFullScale() {
        XCTAssertEqual(AccelerometerConversion.sensitivity(forFullScale: 2), 0.244, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity(forFullScale: 4), 0.488, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity(forFullScale: 8), 0.976, accuracy: 0.001)
        XCTAssertEqual(AccelerometerConversion.sensitivity(forFullScale: 16), 1.952, accuracy: 0.001)

        // Invalid full scale should default to 2g
        XCTAssertEqual(AccelerometerConversion.sensitivity(forFullScale: 32), 0.244, accuracy: 0.001)
    }

    // MARK: - Conversion Tests

    func testToGConversion() {
        // At ±2g, sensitivity is 0.244 mg/digit
        // So 4098 raw units ≈ 1g (4098 * 0.244 / 1000 ≈ 1.0)
        let rawFor1G: Int16 = 4098
        let gValue = AccelerometerConversion.toG(rawValue: rawFor1G)
        XCTAssertEqual(gValue, 1.0, accuracy: 0.01)
    }

    func testToGThreeAxes() {
        let (x, y, z) = AccelerometerConversion.toG(x: 4098, y: 0, z: 0)
        XCTAssertEqual(x, 1.0, accuracy: 0.01)
        XCTAssertEqual(y, 0.0, accuracy: 0.01)
        XCTAssertEqual(z, 0.0, accuracy: 0.01)
    }

    func testMagnitudeCalculation() {
        // Device at rest should have magnitude ~1g
        let rawFor1G: Int16 = 4098
        let mag = AccelerometerConversion.magnitude(x: 0, y: 0, z: rawFor1G)
        XCTAssertEqual(mag, 1.0, accuracy: 0.01)
    }

    // MARK: - Rest Detection Tests

    func testIsAtRest() {
        // Simulate device at rest (Z-axis pointing down with ~1g)
        let rawFor1G: Int16 = 4098
        XCTAssertTrue(AccelerometerConversion.isAtRest(x: 0, y: 0, z: rawFor1G))

        // Simulate movement (much higher magnitude)
        let rawFor2G: Int16 = 8196
        XCTAssertFalse(AccelerometerConversion.isAtRest(x: rawFor2G, y: 0, z: 0))
    }

    func testRestTolerance() {
        XCTAssertEqual(AccelerometerConversion.restTolerance, 0.1, accuracy: 0.001)
    }

    // MARK: - Current Full Scale

    func testCurrentFullScale() {
        XCTAssertEqual(AccelerometerConversion.currentFullScale, 2)
    }
}
