//
//  SensorCorroborationTests.swift
//  OralableCoreTests
//

import XCTest
@testable import OralableCore

final class SensorCorroborationTests: XCTestCase {

    func testOnSkinTemperature() {
        XCTAssertTrue(SensorCorroboration.isLikelyOnSkin(temperatureC: 33.0))
        XCTAssertTrue(SensorCorroboration.isLikelyOnSkin(temperatureC: 32.0))
        XCTAssertTrue(SensorCorroboration.isLikelyOnSkin(temperatureC: 38.0))
    }

    func testAmbientTemperatureOffSkin() {
        XCTAssertFalse(SensorCorroboration.isLikelyOnSkin(temperatureC: 25.0))
        XCTAssertFalse(SensorCorroboration.isLikelyOnSkin(temperatureC: 28.0))
        XCTAssertFalse(SensorCorroboration.isLikelyOnSkin(temperatureC: 40.0))
    }

    func testMissingTemperatureAllows() {
        XCTAssertTrue(SensorCorroboration.isLikelyOnSkin(temperatureC: nil))
        XCTAssertTrue(SensorCorroboration.isLikelyOnSkin(temperatureC: Double.nan))
    }

    func testQualityMultiplierOffSkinIsZero() {
        let m = SensorCorroboration.vitalsQualityMultiplier(
            temperatureC: 25.0,
            motionLevel: 0.01,
            motionThreshold: 0.15
        )
        XCTAssertEqual(m, 0, accuracy: 1e-9)
    }

    func testQualityMultiplierHighMotion() {
        let m = SensorCorroboration.vitalsQualityMultiplier(
            temperatureC: 34.0,
            motionLevel: 0.5,
            motionThreshold: 0.15
        )
        XCTAssertEqual(m, SensorCorroboration.highMotionQualityMultiplier, accuracy: 1e-9)
    }

    func testQualityMultiplierNominal() {
        let m = SensorCorroboration.vitalsQualityMultiplier(
            temperatureC: 34.0,
            motionLevel: 0.05,
            motionThreshold: 0.15
        )
        XCTAssertEqual(m, 1.0, accuracy: 1e-9)
    }

    func testQualityMultiplierMissingTempStillMotionGates() {
        let m = SensorCorroboration.vitalsQualityMultiplier(
            temperatureC: nil,
            motionLevel: 0.5,
            motionThreshold: 0.15
        )
        XCTAssertEqual(m, SensorCorroboration.highMotionQualityMultiplier, accuracy: 1e-9)
    }
}
