//
//  BiometricConfigurationTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for BiometricConfiguration struct and presets
//

import XCTest
@testable import OralableCore

final class BiometricConfigurationTests: XCTestCase {

    // MARK: - Default Initialization Tests

    func testCustomInitialization() {
        let config = BiometricConfiguration(
            sampleRate: 100.0,
            hrWindowSeconds: 5.0,
            spo2WindowSeconds: 4.0,
            minPerfusionIndex: 0.002,
            minHRQuality: 0.6,
            minSpO2Quality: 0.7,
            motionThresholdG: 0.2,
            minBPM: 45,
            maxBPM: 200,
            minSpO2: 75,
            maxSpO2: 100,
            alphaLP: 0.2,
            alphaHP: 0.1
        )

        XCTAssertEqual(config.sampleRate, 100.0)
        XCTAssertEqual(config.hrWindowSeconds, 5.0)
        XCTAssertEqual(config.spo2WindowSeconds, 4.0)
        XCTAssertEqual(config.minPerfusionIndex, 0.002)
        XCTAssertEqual(config.minHRQuality, 0.6)
        XCTAssertEqual(config.minSpO2Quality, 0.7)
        XCTAssertEqual(config.motionThresholdG, 0.2)
        XCTAssertEqual(config.minBPM, 45)
        XCTAssertEqual(config.maxBPM, 200)
        XCTAssertEqual(config.minSpO2, 75)
        XCTAssertEqual(config.maxSpO2, 100)
        XCTAssertEqual(config.alphaLP, 0.2)
        XCTAssertEqual(config.alphaHP, 0.1)
    }

    func testDefaultParameterValues() {
        let config = BiometricConfiguration(sampleRate: 50.0)

        XCTAssertEqual(config.hrWindowSeconds, 3.0)
        XCTAssertEqual(config.spo2WindowSeconds, 3.0)
        XCTAssertEqual(config.minPerfusionIndex, 0.001)
        XCTAssertEqual(config.minHRQuality, 0.5)
        XCTAssertEqual(config.minSpO2Quality, 0.6)
        XCTAssertEqual(config.motionThresholdG, 0.15)
        XCTAssertEqual(config.minBPM, 40)
        XCTAssertEqual(config.maxBPM, 180)
        XCTAssertEqual(config.minSpO2, 70)
        XCTAssertEqual(config.maxSpO2, 100)
        XCTAssertEqual(config.alphaLP, 0.15)
        XCTAssertEqual(config.alphaHP, 0.05)
    }

    // MARK: - Computed Properties Tests

    func testHRWindowSize() {
        let config = BiometricConfiguration(
            sampleRate: 50.0,
            hrWindowSeconds: 3.0
        )

        // 50 Hz * 3 seconds = 150 samples
        XCTAssertEqual(config.hrWindowSize, 150)
    }

    func testSpo2WindowSize() {
        let config = BiometricConfiguration(
            sampleRate: 100.0,
            spo2WindowSeconds: 2.5
        )

        // 100 Hz * 2.5 seconds = 250 samples
        XCTAssertEqual(config.spo2WindowSize, 250)
    }

    func testWindowSizeWithHighSampleRate() {
        let config = BiometricConfiguration(
            sampleRate: 500.0,
            hrWindowSeconds: 5.0,
            spo2WindowSeconds: 4.0
        )

        XCTAssertEqual(config.hrWindowSize, 2500)
        XCTAssertEqual(config.spo2WindowSize, 2000)
    }

    func testWindowSizeWithLowSampleRate() {
        let config = BiometricConfiguration(
            sampleRate: 10.0,
            hrWindowSeconds: 3.0,
            spo2WindowSeconds: 3.0
        )

        XCTAssertEqual(config.hrWindowSize, 30)
        XCTAssertEqual(config.spo2WindowSize, 30)
    }

    // MARK: - Preset Tests

    func testOralablePreset() {
        let config = BiometricConfiguration.oralable

        XCTAssertEqual(config.sampleRate, 50.0)
        XCTAssertEqual(config.hrWindowSeconds, 3.0)
        XCTAssertEqual(config.spo2WindowSeconds, 3.0)
        XCTAssertEqual(config.minPerfusionIndex, 0.001)
        XCTAssertEqual(config.minHRQuality, 0.5)
        XCTAssertEqual(config.minSpO2Quality, 0.6)
        XCTAssertEqual(config.motionThresholdG, 0.15)
        XCTAssertEqual(config.minBPM, 40)
        XCTAssertEqual(config.maxBPM, 180)
        XCTAssertEqual(config.minSpO2, 70)
        XCTAssertEqual(config.maxSpO2, 100)
        XCTAssertEqual(config.alphaLP, 0.15)
        XCTAssertEqual(config.alphaHP, 0.05)

        // Window sizes
        XCTAssertEqual(config.hrWindowSize, 150)
        XCTAssertEqual(config.spo2WindowSize, 150)
    }

    func testANRPreset() {
        let config = BiometricConfiguration.anr

        XCTAssertEqual(config.sampleRate, 100.0)
        XCTAssertEqual(config.hrWindowSeconds, 3.0)
        XCTAssertEqual(config.spo2WindowSeconds, 3.0)

        // Window sizes (100 Hz * 3s = 300 samples)
        XCTAssertEqual(config.hrWindowSize, 300)
        XCTAssertEqual(config.spo2WindowSize, 300)
    }

    func testDemoPreset() {
        let config = BiometricConfiguration.demo

        XCTAssertEqual(config.sampleRate, 10.0)
        XCTAssertEqual(config.hrWindowSeconds, 5.0)
        XCTAssertEqual(config.spo2WindowSeconds, 5.0)
        XCTAssertEqual(config.minPerfusionIndex, 0.0005)
        XCTAssertEqual(config.minHRQuality, 0.3)
        XCTAssertEqual(config.minSpO2Quality, 0.3)
        XCTAssertEqual(config.motionThresholdG, 0.2)
        XCTAssertEqual(config.alphaLP, 0.2)
        XCTAssertEqual(config.alphaHP, 0.1)

        // Window sizes (10 Hz * 5s = 50 samples)
        XCTAssertEqual(config.hrWindowSize, 50)
        XCTAssertEqual(config.spo2WindowSize, 50)
    }

    // MARK: - Preset Differences Tests

    func testPresetsHaveDifferentSampleRates() {
        let oralable = BiometricConfiguration.oralable
        let anr = BiometricConfiguration.anr
        let demo = BiometricConfiguration.demo

        XCTAssertNotEqual(oralable.sampleRate, anr.sampleRate)
        XCTAssertNotEqual(oralable.sampleRate, demo.sampleRate)
        XCTAssertNotEqual(anr.sampleRate, demo.sampleRate)
    }

    func testDemoHasLoosestThresholds() {
        let oralable = BiometricConfiguration.oralable
        let demo = BiometricConfiguration.demo

        // Demo should have lower quality thresholds (more lenient)
        XCTAssertLessThan(demo.minHRQuality, oralable.minHRQuality)
        XCTAssertLessThan(demo.minSpO2Quality, oralable.minSpO2Quality)
        XCTAssertLessThan(demo.minPerfusionIndex, oralable.minPerfusionIndex)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() {
        let config = BiometricConfiguration.oralable

        // Test that config can be used in a sendable context
        Task {
            let sampleRate = config.sampleRate
            XCTAssertEqual(sampleRate, 50.0)
        }
    }
}
