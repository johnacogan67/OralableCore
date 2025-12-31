//
//  BiometricResultTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for BiometricResult and related types
//

import XCTest
@testable import OralableCore

// MARK: - HRSource Tests

final class HRSourceTests: XCTestCase {

    func testHRSourceRawValues() {
        XCTAssertEqual(HRSource.ir.rawValue, "ir")
        XCTAssertEqual(HRSource.green.rawValue, "green")
        XCTAssertEqual(HRSource.fft.rawValue, "fft")
        XCTAssertEqual(HRSource.unavailable.rawValue, "unavailable")
    }

    func testHRSourceDescriptions() {
        XCTAssertEqual(HRSource.ir.description, "Infrared")
        XCTAssertEqual(HRSource.green.description, "Green")
        XCTAssertEqual(HRSource.fft.description, "FFT")
        XCTAssertEqual(HRSource.unavailable.description, "Unavailable")
    }

    func testHRSourceCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for source in [HRSource.ir, .green, .fft, .unavailable] {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(HRSource.self, from: data)
            XCTAssertEqual(source, decoded)
        }
    }
}

// MARK: - SignalStrength Tests

final class SignalStrengthTests: XCTestCase {

    func testSignalStrengthRawValues() {
        XCTAssertEqual(SignalStrength.none.rawValue, "none")
        XCTAssertEqual(SignalStrength.weak.rawValue, "weak")
        XCTAssertEqual(SignalStrength.moderate.rawValue, "moderate")
        XCTAssertEqual(SignalStrength.strong.rawValue, "strong")
    }

    func testSignalStrengthFromPerfusionIndexNone() {
        // PI < 0.0005 = none
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.0), .none)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.0001), .none)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.00049), .none)
    }

    func testSignalStrengthFromPerfusionIndexWeak() {
        // PI 0.0005 - 0.002 = weak
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.0005), .weak)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.001), .weak)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.00199), .weak)
    }

    func testSignalStrengthFromPerfusionIndexModerate() {
        // PI 0.002 - 0.005 = moderate
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.002), .moderate)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.003), .moderate)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.00499), .moderate)
    }

    func testSignalStrengthFromPerfusionIndexStrong() {
        // PI >= 0.005 = strong
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.005), .strong)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.01), .strong)
        XCTAssertEqual(SignalStrength(perfusionIndex: 1.0), .strong)
    }

    func testSignalStrengthDescription() {
        XCTAssertEqual(SignalStrength.none.description, "None")
        XCTAssertEqual(SignalStrength.weak.description, "Weak")
        XCTAssertEqual(SignalStrength.moderate.description, "Moderate")
        XCTAssertEqual(SignalStrength.strong.description, "Strong")
    }

    func testSignalStrengthIsUsable() {
        XCTAssertFalse(SignalStrength.none.isUsable)
        XCTAssertFalse(SignalStrength.weak.isUsable)
        XCTAssertTrue(SignalStrength.moderate.isUsable)
        XCTAssertTrue(SignalStrength.strong.isUsable)
    }

    func testSignalStrengthCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for strength in [SignalStrength.none, .weak, .moderate, .strong] {
            let data = try encoder.encode(strength)
            let decoded = try decoder.decode(SignalStrength.self, from: data)
            XCTAssertEqual(strength, decoded)
        }
    }
}

// MARK: - ProcessingMethod Tests

final class ProcessingMethodTests: XCTestCase {

    func testProcessingMethodRawValues() {
        XCTAssertEqual(ProcessingMethod.realtime.rawValue, "realtime")
        XCTAssertEqual(ProcessingMethod.batch.rawValue, "batch")
    }

    func testProcessingMethodCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for method in [ProcessingMethod.realtime, .batch] {
            let data = try encoder.encode(method)
            let decoded = try decoder.decode(ProcessingMethod.self, from: data)
            XCTAssertEqual(method, decoded)
        }
    }
}

// MARK: - BiometricResult Tests

final class BiometricResultTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBiometricResultCreation() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertEqual(result.heartRate, 72)
        XCTAssertEqual(result.heartRateQuality, 0.85)
        XCTAssertEqual(result.heartRateSource, .ir)
        XCTAssertEqual(result.spo2, 98.5)
        XCTAssertEqual(result.spo2Quality, 0.9)
        XCTAssertEqual(result.perfusionIndex, 0.005)
        XCTAssertTrue(result.isWorn)
        XCTAssertEqual(result.activity, .relaxed)
        XCTAssertEqual(result.motionLevel, 0.02)
        XCTAssertEqual(result.signalStrength, .strong)
        XCTAssertEqual(result.processingMethod, .realtime)
    }

    // MARK: - Empty Result Tests

    func testEmptyResult() {
        let empty = BiometricResult.empty

        XCTAssertEqual(empty.heartRate, 0)
        XCTAssertEqual(empty.heartRateQuality, 0)
        XCTAssertEqual(empty.heartRateSource, .unavailable)
        XCTAssertEqual(empty.spo2, 0)
        XCTAssertEqual(empty.spo2Quality, 0)
        XCTAssertEqual(empty.perfusionIndex, 0)
        XCTAssertFalse(empty.isWorn)
        XCTAssertEqual(empty.activity, .relaxed)
        XCTAssertEqual(empty.motionLevel, 0)
        XCTAssertEqual(empty.signalStrength, .none)
        XCTAssertEqual(empty.processingMethod, .realtime)
    }

    // MARK: - Convenience Property Tests

    func testHasValidHeartRateTrue() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertTrue(result.hasValidHeartRate)
    }

    func testHasValidHeartRateFalseZeroHR() {
        let result = BiometricResult(
            heartRate: 0,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.hasValidHeartRate)
    }

    func testHasValidHeartRateFalseUnavailableSource() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .unavailable,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.hasValidHeartRate)
    }

    func testHasValidSpO2True() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertTrue(result.hasValidSpO2)
    }

    func testHasValidSpO2FalseZeroValue() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 0,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.hasValidSpO2)
    }

    func testHasValidSpO2FalseZeroQuality() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.hasValidSpO2)
    }

    func testIsMovingTrue() {
        let result = BiometricResult(
            heartRate: 0,
            heartRateQuality: 0,
            heartRateSource: .unavailable,
            spo2: 0,
            spo2Quality: 0,
            perfusionIndex: 0.001,
            isWorn: true,
            activity: .motion,
            motionLevel: 0.5,
            signalStrength: .weak,
            processingMethod: .realtime
        )

        XCTAssertTrue(result.isMoving)
    }

    func testIsMovingFalse() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.8,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.isMoving)
    }

    // MARK: - Equatable Tests

    func testEquatableSameValues() {
        let result1 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        let result2 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertEqual(result1, result2)
    }

    func testEquatableDifferentHeartRate() {
        let result1 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        let result2 = BiometricResult(
            heartRate: 80,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertNotEqual(result1, result2)
    }

    func testEquatableDifferentActivity() {
        let result1 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        let result2 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98.5,
            spo2Quality: 0.9,
            perfusionIndex: 0.005,
            isWorn: true,
            activity: .grinding,
            motionLevel: 0.02,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertNotEqual(result1, result2)
    }

    // MARK: - Sendable Tests

    func testSendableConformance() {
        let result = BiometricResult.empty

        Task {
            let hr = result.heartRate
            XCTAssertEqual(hr, 0)
        }
    }
}
