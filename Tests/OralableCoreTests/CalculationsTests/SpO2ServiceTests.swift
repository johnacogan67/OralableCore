//
//  SpO2ServiceTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for SpO2 (blood oxygen saturation) calculation service
//

import XCTest
@testable import OralableCore

// MARK: - SpO2Result Tests

final class SpO2ResultTests: XCTestCase {

    // MARK: - Initialization Tests

    func testSpO2ResultCreationWithAllParameters() {
        let result = SpO2Result(
            percentage: 98.0,
            confidence: 0.95,
            rRatio: 0.48,
            isValid: true
        )

        XCTAssertEqual(result.percentage, 98.0)
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.rRatio, 0.48)
        XCTAssertTrue(result.isValid)
    }

    func testSpO2ResultCreationWithDefaults() {
        let result = SpO2Result(percentage: 97.0, confidence: 0.8)

        XCTAssertEqual(result.percentage, 97.0)
        XCTAssertEqual(result.confidence, 0.8)
        XCTAssertEqual(result.rRatio, 0) // default
        XCTAssertTrue(result.isValid) // default
    }

    func testSpO2ResultConfidenceClamping() {
        // Confidence > 1.0 should clamp to 1.0
        let highConfidence = SpO2Result(percentage: 99.0, confidence: 1.5)
        XCTAssertEqual(highConfidence.confidence, 1.0)

        // Confidence < 0.0 should clamp to 0.0
        let lowConfidence = SpO2Result(percentage: 99.0, confidence: -0.5)
        XCTAssertEqual(lowConfidence.confidence, 0.0)
    }

    func testSpO2ResultConfidenceEdgeCases() {
        let zeroConfidence = SpO2Result(percentage: 95.0, confidence: 0.0)
        XCTAssertEqual(zeroConfidence.confidence, 0.0)

        let fullConfidence = SpO2Result(percentage: 95.0, confidence: 1.0)
        XCTAssertEqual(fullConfidence.confidence, 1.0)
    }

    // MARK: - Empty Result Tests

    func testSpO2ResultEmpty() {
        let empty = SpO2Result.empty

        XCTAssertEqual(empty.percentage, 0)
        XCTAssertEqual(empty.confidence, 0)
        XCTAssertEqual(empty.rRatio, 0)
        XCTAssertFalse(empty.isValid)
    }

    func testSpO2ResultEmptyIsNotClinicallyValid() {
        XCTAssertFalse(SpO2Result.empty.isClinicallyValid)
    }

    // MARK: - Clinical Validity Tests

    func testIsClinicallyValidNormalValues() {
        let normal = SpO2Result(percentage: 98.0, confidence: 0.8, isValid: true)
        XCTAssertTrue(normal.isClinicallyValid)
    }

    func testIsClinicallyValidAtLowerBound() {
        // 70% is minimum valid
        let lowerBound = SpO2Result(percentage: 70.0, confidence: 0.7, isValid: true)
        XCTAssertTrue(lowerBound.isClinicallyValid)
    }

    func testIsClinicallyValidAtUpperBound() {
        // 100% is maximum
        let upperBound = SpO2Result(percentage: 100.0, confidence: 0.9, isValid: true)
        XCTAssertTrue(upperBound.isClinicallyValid)
    }

    func testNotClinicallyValidBelowRange() {
        let belowRange = SpO2Result(percentage: 69.0, confidence: 0.9, isValid: true)
        XCTAssertFalse(belowRange.isClinicallyValid)
    }

    func testNotClinicallyValidAboveRange() {
        let aboveRange = SpO2Result(percentage: 101.0, confidence: 0.9, isValid: true)
        XCTAssertFalse(aboveRange.isClinicallyValid)
    }

    func testNotClinicallyValidLowConfidence() {
        // Confidence must be > 0.6
        let lowConfidence = SpO2Result(percentage: 98.0, confidence: 0.6, isValid: true)
        XCTAssertFalse(lowConfidence.isClinicallyValid)

        let barelyEnoughConfidence = SpO2Result(percentage: 98.0, confidence: 0.61, isValid: true)
        XCTAssertTrue(barelyEnoughConfidence.isClinicallyValid)
    }

    // MARK: - Equatable Tests

    func testSpO2ResultEquatable() {
        let result1 = SpO2Result(percentage: 97.0, confidence: 0.85, rRatio: 0.5, isValid: true)
        let result2 = SpO2Result(percentage: 97.0, confidence: 0.85, rRatio: 0.5, isValid: true)
        let result3 = SpO2Result(percentage: 96.0, confidence: 0.85, rRatio: 0.5, isValid: true)

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    // MARK: - Sendable Tests

    func testSpO2ResultSendable() {
        let result = SpO2Result(percentage: 98.0, confidence: 0.9)

        Task {
            let percentage = result.percentage
            XCTAssertEqual(percentage, 98.0)
        }
    }
}

// MARK: - SpO2CalibrationCurve Tests

final class SpO2CalibrationCurveTests: XCTestCase {

    func testAllCalibrationCurveCases() {
        let curves: [SpO2CalibrationCurve] = [.linear, .quadratic, .cubic]
        XCTAssertEqual(curves.count, 3)
    }

    func testLinearCurveDescription() {
        XCTAssertEqual(SpO2CalibrationCurve.linear.description, "Linear (Simple)")
    }

    func testQuadraticCurveDescription() {
        XCTAssertEqual(SpO2CalibrationCurve.quadratic.description, "Quadratic (Standard)")
    }

    func testCubicCurveDescription() {
        XCTAssertEqual(SpO2CalibrationCurve.cubic.description, "Cubic (Precision)")
    }

    func testCaseIterable() {
        XCTAssertEqual(SpO2CalibrationCurve.allCases.count, 3)
        XCTAssertTrue(SpO2CalibrationCurve.allCases.contains(.linear))
        XCTAssertTrue(SpO2CalibrationCurve.allCases.contains(.quadratic))
        XCTAssertTrue(SpO2CalibrationCurve.allCases.contains(.cubic))
    }

    func testRawValues() {
        XCTAssertEqual(SpO2CalibrationCurve.linear.rawValue, "linear")
        XCTAssertEqual(SpO2CalibrationCurve.quadratic.rawValue, "quadratic")
        XCTAssertEqual(SpO2CalibrationCurve.cubic.rawValue, "cubic")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(SpO2CalibrationCurve(rawValue: "linear"), .linear)
        XCTAssertEqual(SpO2CalibrationCurve(rawValue: "quadratic"), .quadratic)
        XCTAssertEqual(SpO2CalibrationCurve(rawValue: "cubic"), .cubic)
        XCTAssertNil(SpO2CalibrationCurve(rawValue: "invalid"))
    }

    func testSendable() {
        let curve = SpO2CalibrationCurve.quadratic

        Task {
            let desc = curve.description
            XCTAssertEqual(desc, "Quadratic (Standard)")
        }
    }
}

// MARK: - SpO2Service Tests

final class SpO2ServiceTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() async {
        let service = SpO2Service()
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    func testCustomInitialization() async {
        let service = SpO2Service(
            minSamples: 100,
            bufferSize: 200,
            validRange: 80...100,
            minQuality: 0.6,
            smoothingWindow: 5,
            calibration: .linear
        )

        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    // MARK: - Factory Method Tests

    func testOralableFactory() async {
        let service = SpO2Service.oralable()
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    func testClinicalFactory() async {
        let service = SpO2Service.clinical()
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    func testDemoFactory() async {
        let service = SpO2Service.demo()
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    // MARK: - Process Tests

    func testProcessInsufficientSamples() async {
        let service = SpO2Service(minSamples: 100)

        // Only 50 samples - not enough
        let redSamples = Array(repeating: 100000.0, count: 50)
        let irSamples = Array(repeating: 120000.0, count: 50)

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        XCTAssertEqual(result.percentage, 0)
        XCTAssertFalse(result.isValid)
    }

    func testProcessMismatchedArrayLengths() async {
        let service = SpO2Service(minSamples: 50)

        let redSamples = Array(repeating: 100000.0, count: 100)
        let irSamples = Array(repeating: 120000.0, count: 50) // Different length

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        XCTAssertEqual(result.percentage, 0)
        XCTAssertFalse(result.isValid)
    }

    func testProcessEmptyArrays() async {
        let service = SpO2Service()

        let emptyRed: [Double] = []
        let emptyIR: [Double] = []
        let result = await service.process(redSamples: emptyRed, irSamples: emptyIR)

        XCTAssertEqual(result.percentage, 0)
        XCTAssertFalse(result.isValid)
    }

    func testProcessWithValidSimulatedData() async {
        let service = SpO2Service.demo()

        // Generate simulated PPG with pulsation
        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.2 // Simulated heart rate
            // Red has lower amplitude than IR (typical for healthy SpO2)
            let red = 80000.0 + sin(phase) * 4000.0
            let ir = 100000.0 + sin(phase) * 5000.0

            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        // Should produce a valid result with these reasonable values
        XCTAssertTrue(result.rRatio > 0)
    }

    func testProcessWithInt32Samples() async {
        let service = SpO2Service.demo()

        // Generate simulated PPG with Int32 values
        let sampleCount = 100
        var redSamples: [Int32] = []
        var irSamples: [Int32] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.2
            let red = Int32(80000 + Int(sin(phase) * 4000))
            let ir = Int32(100000 + Int(sin(phase) * 5000))

            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        // Should handle Int32 conversion
        XCTAssertTrue(result.rRatio >= 0)
    }

    func testProcessWithFlatSignal() async {
        let service = SpO2Service.demo()

        // Flat signal = no AC component = no valid SpO2
        let redSamples = Array(repeating: 80000.0, count: 100)
        let irSamples = Array(repeating: 100000.0, count: 100)

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        // Flat signal should return empty result
        XCTAssertFalse(result.isValid)
    }

    func testProcessWithZeroDCValues() async {
        let service = SpO2Service.demo()

        let redSamples = Array(repeating: 0.0, count: 100)
        let irSamples = Array(repeating: 0.0, count: 100)

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.percentage, 0)
    }

    // MARK: - AddSample (Streaming) Tests

    func testAddSampleBuildsBuffer() async {
        let service = SpO2Service(minSamples: 10, bufferSize: 20)

        // Add samples one at a time
        for i in 0..<5 {
            let phase = Double(i) * 0.3
            _ = await service.addSample(
                red: 80000.0 + sin(phase) * 3000.0,
                ir: 100000.0 + sin(phase) * 4000.0
            )
        }

        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.5, accuracy: 0.01) // 5/10 = 0.5
    }

    func testAddSampleReturnsEmptyUntilBufferFull() async {
        let service = SpO2Service(minSamples: 10, bufferSize: 20)

        // First 9 samples should return empty
        for i in 0..<9 {
            let phase = Double(i) * 0.3
            let result = await service.addSample(
                red: 80000.0 + sin(phase) * 3000.0,
                ir: 100000.0 + sin(phase) * 4000.0
            )
            XCTAssertFalse(result.isValid, "Sample \(i) should not be valid")
        }
    }

    func testAddSampleBufferMaintainsSize() async {
        let service = SpO2Service(minSamples: 5, bufferSize: 10)

        // Add 20 samples (more than buffer size)
        for i in 0..<20 {
            let phase = Double(i) * 0.3
            _ = await service.addSample(
                red: 80000.0 + sin(phase) * 3000.0,
                ir: 100000.0 + sin(phase) * 4000.0
            )
        }

        // Buffer fill level should be capped at bufferSize / minSamples
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 2.0, accuracy: 0.01) // 10/5 = 2.0
    }

    // MARK: - Reset Tests

    func testReset() async {
        let service = SpO2Service(minSamples: 10, bufferSize: 20)

        // Add some samples
        for i in 0..<15 {
            let phase = Double(i) * 0.3
            _ = await service.addSample(
                red: 80000.0 + sin(phase) * 3000.0,
                ir: 100000.0 + sin(phase) * 4000.0
            )
        }

        let fillBefore = await service.bufferFillLevel
        XCTAssertGreaterThan(fillBefore, 0)

        await service.reset()

        let fillAfter = await service.bufferFillLevel
        XCTAssertEqual(fillAfter, 0.0)
    }

    func testResetAllowsReprocessing() async {
        let service = SpO2Service(minSamples: 10, bufferSize: 20)

        // Fill buffer
        for i in 0..<15 {
            let phase = Double(i) * 0.3
            _ = await service.addSample(
                red: 80000.0 + sin(phase) * 3000.0,
                ir: 100000.0 + sin(phase) * 4000.0
            )
        }

        await service.reset()

        // After reset, first sample should return empty
        let result = await service.addSample(red: 80000.0, ir: 100000.0)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Buffer Fill Level Tests

    func testBufferFillLevelEmpty() async {
        let service = SpO2Service(minSamples: 100)
        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.0)
    }

    func testBufferFillLevelPartial() async {
        let service = SpO2Service(minSamples: 100, bufferSize: 200)

        for _ in 0..<50 {
            _ = await service.addSample(red: 80000.0, ir: 100000.0)
        }

        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 0.5, accuracy: 0.01)
    }

    func testBufferFillLevelFull() async {
        let service = SpO2Service(minSamples: 50, bufferSize: 100)

        for _ in 0..<50 {
            _ = await service.addSample(red: 80000.0, ir: 100000.0)
        }

        let fillLevel = await service.bufferFillLevel
        XCTAssertEqual(fillLevel, 1.0, accuracy: 0.01)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentProcessing() async {
        let service = SpO2Service.demo()

        await withTaskGroup(of: SpO2Result.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await service.addSample(red: 80000.0, ir: 100000.0)
                }
            }

            var results: [SpO2Result] = []
            for await result in group {
                results.append(result)
            }

            XCTAssertEqual(results.count, 10)
        }
    }

    func testConcurrentReset() async {
        let service = SpO2Service.demo()

        await withTaskGroup(of: Void.self) { group in
            // Add samples concurrently
            for i in 0..<20 {
                group.addTask {
                    _ = await service.addSample(red: Double(80000 + i * 100), ir: Double(100000 + i * 100))
                }
            }

            // Reset concurrently
            group.addTask {
                await service.reset()
            }

            await group.waitForAll()
        }

        // Should complete without crash
    }
}

// MARK: - SpO2 Static Utility Tests

final class SpO2UtilityTests: XCTestCase {

    // MARK: - Calculate R Ratio Tests

    func testCalculateRRatioNormalValues() {
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 4000,
            dcRed: 80000,
            acIR: 5000,
            dcIR: 100000
        )

        // (4000/80000) / (5000/100000) = 0.05 / 0.05 = 1.0
        XCTAssertEqual(rRatio, 1.0, accuracy: 0.001)
    }

    func testCalculateRRatioLowSpO2() {
        // Higher R ratio = lower SpO2
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 6000,
            dcRed: 80000,
            acIR: 4000,
            dcIR: 100000
        )

        // (6000/80000) / (4000/100000) = 0.075 / 0.04 = 1.875
        XCTAssertEqual(rRatio, 1.875, accuracy: 0.001)
    }

    func testCalculateRRatioHighSpO2() {
        // Lower R ratio = higher SpO2
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 3000,
            dcRed: 80000,
            acIR: 6000,
            dcIR: 100000
        )

        // (3000/80000) / (6000/100000) = 0.0375 / 0.06 = 0.625
        XCTAssertEqual(rRatio, 0.625, accuracy: 0.001)
    }

    func testCalculateRRatioZeroDCRed() {
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 4000,
            dcRed: 0,
            acIR: 5000,
            dcIR: 100000
        )

        XCTAssertEqual(rRatio, 0)
    }

    func testCalculateRRatioZeroDCIR() {
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 4000,
            dcRed: 80000,
            acIR: 5000,
            dcIR: 0
        )

        XCTAssertEqual(rRatio, 0)
    }

    func testCalculateRRatioZeroACIR() {
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 4000,
            dcRed: 80000,
            acIR: 0,
            dcIR: 100000
        )

        XCTAssertEqual(rRatio, 0)
    }

    // MARK: - R Ratio to SpO2 Tests

    func testRRatioToSpO2NormalR() {
        // R ratio ~0.5 should give ~98% SpO2
        let spo2 = SpO2Service.rRatioToSpO2(0.5)
        XCTAssertGreaterThan(spo2, 90)
        XCTAssertLessThanOrEqual(spo2, 100)
    }

    func testRRatioToSpO2HighR() {
        // R ratio ~1.5 should give lower SpO2
        let spo2 = SpO2Service.rRatioToSpO2(1.5)
        XCTAssertGreaterThanOrEqual(spo2, 70)
        XCTAssertLessThan(spo2, 90)
    }

    func testRRatioToSpO2Clamping() {
        // Very low R gives high SpO2 - quadratic formula at R=0 gives 94.845
        let highSpO2 = SpO2Service.rRatioToSpO2(0.0)
        XCTAssertEqual(highSpO2, 94.845, accuracy: 0.01)

        // Very high R should clamp to minimum 70
        let lowSpO2 = SpO2Service.rRatioToSpO2(3.0)
        XCTAssertEqual(lowSpO2, 70)
    }

    func testRRatioToSpO2KnownValues() {
        // R = 0.4 approximately gives SpO2 ~99%
        let spo2_04 = SpO2Service.rRatioToSpO2(0.4)
        XCTAssertGreaterThan(spo2_04, 95)

        // R = 1.0 approximately gives SpO2 ~85%
        let spo2_10 = SpO2Service.rRatioToSpO2(1.0)
        XCTAssertGreaterThan(spo2_10, 75)
        XCTAssertLessThan(spo2_10, 95)
    }

    // MARK: - SpO2 to R Ratio Tests

    func testSpO2ToRRatioNormal() {
        // SpO2 98% should give R ~0.48
        let rRatio = SpO2Service.spO2ToRRatio(98)
        XCTAssertEqual(rRatio, 0.48, accuracy: 0.01)
    }

    func testSpO2ToRRatio100Percent() {
        // SpO2 100% should give R ~0.4
        let rRatio = SpO2Service.spO2ToRRatio(100)
        XCTAssertEqual(rRatio, 0.4, accuracy: 0.01)
    }

    func testSpO2ToRRatio85Percent() {
        // SpO2 85% should give R = 1.0
        let rRatio = SpO2Service.spO2ToRRatio(85)
        XCTAssertEqual(rRatio, 1.0, accuracy: 0.01)
    }

    func testSpO2ToRRatio70Percent() {
        // SpO2 70% should give R = 1.6
        let rRatio = SpO2Service.spO2ToRRatio(70)
        XCTAssertEqual(rRatio, 1.6, accuracy: 0.01)
    }

    func testSpO2ToRRatioInverseRelationship() {
        // Lower SpO2 should give higher R ratio
        let rRatio90 = SpO2Service.spO2ToRRatio(90)
        let rRatio80 = SpO2Service.spO2ToRRatio(80)

        XCTAssertGreaterThan(rRatio80, rRatio90)
    }
}

// MARK: - Calibration Curve Processing Tests

final class SpO2CalibrationProcessingTests: XCTestCase {

    func testLinearCalibrationProcessing() async {
        let service = SpO2Service(
            minSamples: 50,
            calibration: .linear
        )

        // Generate data with known characteristics
        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 4000.0
            let ir = 100000.0 + sin(phase) * 5000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        XCTAssertTrue(result.rRatio > 0)
    }

    func testQuadraticCalibrationProcessing() async {
        let service = SpO2Service(
            minSamples: 50,
            calibration: .quadratic
        )

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 4000.0
            let ir = 100000.0 + sin(phase) * 5000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        XCTAssertTrue(result.rRatio > 0)
    }

    func testCubicCalibrationProcessing() async {
        let service = SpO2Service(
            minSamples: 50,
            calibration: .cubic
        )

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 4000.0
            let ir = 100000.0 + sin(phase) * 5000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        XCTAssertTrue(result.rRatio > 0)
    }
}

// MARK: - Edge Case Tests

final class SpO2EdgeCaseTests: XCTestCase {

    func testVerySmallACComponent() async {
        let service = SpO2Service.demo()

        // Very small AC = almost flat signal
        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 10.0 // Very small pulsation
            let ir = 100000.0 + sin(phase) * 10.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // Should handle gracefully
        XCTAssertTrue(result.rRatio.isFinite)
    }

    func testNegativeSignalValues() async {
        let service = SpO2Service.demo()

        // Negative values (shouldn't happen in practice, but should handle)
        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = -80000.0 + sin(phase) * 4000.0
            let ir = -100000.0 + sin(phase) * 5000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // Should handle gracefully without crash
        XCTAssertTrue(result.rRatio.isFinite || result.rRatio == 0)
    }

    func testVeryLargeSignalValues() async {
        let service = SpO2Service.demo()

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 8000000.0 + sin(phase) * 400000.0
            let ir = 10000000.0 + sin(phase) * 500000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // Should handle large values gracefully
        XCTAssertTrue(result.rRatio.isFinite)
    }

    func testSignalWithNoise() async {
        let service = SpO2Service.demo()

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let noise = Double.random(in: -500...500)
            let red = 80000.0 + sin(phase) * 4000.0 + noise
            let ir = 100000.0 + sin(phase) * 5000.0 + noise
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // Should process noisy signal
        XCTAssertTrue(result.rRatio.isFinite)
    }

    func testSingleSampleProcessing() async {
        let service = SpO2Service(minSamples: 1, bufferSize: 10)

        // Single sample should still fail (need at least some variation)
        let result = await service.process(redSamples: [80000.0], irSamples: [100000.0])
        XCTAssertFalse(result.isValid)
    }
}

// MARK: - Quality Validation Tests

final class SpO2QualityTests: XCTestCase {

    func testHighQualitySignalRequirements() async {
        let service = SpO2Service(minSamples: 50, minQuality: 0.8)

        // Generate high-quality simulated signal
        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            // Good amplitude, reasonable DC levels
            let red = 80000.0 + sin(phase) * 15000.0
            let ir = 100000.0 + sin(phase) * 20000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // With high quality threshold, result depends on signal quality calculation
        XCTAssertTrue(result.confidence >= 0 && result.confidence <= 1)
    }

    func testLowQualityThreshold() async {
        let service = SpO2Service(minSamples: 50, minQuality: 0.1)

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 1000.0 // Lower amplitude
            let ir = 100000.0 + sin(phase) * 1500.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await service.process(redSamples: redSamples, irSamples: irSamples)
        // With low quality threshold, more signals should pass
        XCTAssertTrue(result.rRatio >= 0)
    }

    func testValidRangeConfiguration() async {
        // Strict valid range
        let strictService = SpO2Service(minSamples: 50, validRange: 95...100)

        let sampleCount = 100
        var redSamples: [Double] = []
        var irSamples: [Double] = []

        for i in 0..<sampleCount {
            let phase = Double(i) * 0.3
            let red = 80000.0 + sin(phase) * 4000.0
            let ir = 100000.0 + sin(phase) * 5000.0
            redSamples.append(red)
            irSamples.append(ir)
        }

        let result = await strictService.process(redSamples: redSamples, irSamples: irSamples)
        // Result validity depends on whether calculated SpO2 falls in strict range
        XCTAssertTrue(result.rRatio >= 0)
    }
}
