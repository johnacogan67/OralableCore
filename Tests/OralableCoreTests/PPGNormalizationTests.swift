//
//  PPGNormalizationTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for PPGNormalizationService
//

import XCTest
@testable import OralableCore

final class PPGNormalizationTests: XCTestCase {

    // MARK: - PPGNormalizationMethod Tests

    func testNormalizationMethodRawValue() {
        XCTAssertEqual(PPGNormalizationMethod.raw.rawValue, "raw")
        XCTAssertEqual(PPGNormalizationMethod.dynamicRange.rawValue, "dynamicRange")
        XCTAssertEqual(PPGNormalizationMethod.adaptiveBaseline.rawValue, "adaptiveBaseline")
        XCTAssertEqual(PPGNormalizationMethod.persistent.rawValue, "persistent")
    }

    func testNormalizationMethodDescription() {
        XCTAssertEqual(PPGNormalizationMethod.raw.description, "Raw (No Processing)")
        XCTAssertEqual(PPGNormalizationMethod.dynamicRange.description, "Dynamic Range Scaling")
        XCTAssertEqual(PPGNormalizationMethod.adaptiveBaseline.description, "Adaptive Baseline")
        XCTAssertEqual(PPGNormalizationMethod.persistent.description, "Persistent Baseline")
    }

    func testNormalizationMethodAllCases() {
        XCTAssertEqual(PPGNormalizationMethod.allCases.count, 4)
        XCTAssertTrue(PPGNormalizationMethod.allCases.contains(.raw))
        XCTAssertTrue(PPGNormalizationMethod.allCases.contains(.dynamicRange))
        XCTAssertTrue(PPGNormalizationMethod.allCases.contains(.adaptiveBaseline))
        XCTAssertTrue(PPGNormalizationMethod.allCases.contains(.persistent))
    }

    // MARK: - NormalizedPPGSample Tests

    func testNormalizedPPGSampleCreation() {
        let timestamp = Date()
        let sample = NormalizedPPGSample(timestamp: timestamp, ir: 0.5, red: 0.3, green: 0.2)

        XCTAssertEqual(sample.timestamp, timestamp)
        XCTAssertEqual(sample.ir, 0.5)
        XCTAssertEqual(sample.red, 0.3)
        XCTAssertEqual(sample.green, 0.2)
    }

    // MARK: - PPGNormalizationService Initialization Tests

    func testServiceDefaultInitialization() async {
        let service = PPGNormalizationService()

        // Default service should not be initialized yet
        let isInitialized = await service.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }

    func testServiceCustomInitialization() async {
        let service = PPGNormalizationService(
            alpha: 0.05,
            saturationThreshold: 100000,
            lowSignalThreshold: 5000
        )

        let isInitialized = await service.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }

    func testServiceOralableFactory() async {
        let service = PPGNormalizationService.oralable()

        let isInitialized = await service.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }

    func testServiceRealtimeFactory() async {
        let service = PPGNormalizationService.realtime()

        let isInitialized = await service.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }

    // MARK: - Single Channel Normalization Tests

    func testNormalizeSingleChannel() async {
        let service = PPGNormalizationService()

        // First sample initializes baseline
        let first = await service.normalize(100000.0)
        XCTAssertEqual(first, 0) // First sample returns 0

        // Subsequent samples subtract baseline
        let second = await service.normalize(100100.0)
        XCTAssertGreaterThan(second, 0) // Signal above baseline
    }

    func testNormalizeBaselineTracking() async {
        let service = PPGNormalizationService(alpha: 0.5) // Fast tracking for test

        _ = await service.normalize(100.0) // Initialize
        _ = await service.normalize(200.0) // Should move baseline towards 200

        let baseline = await service.currentBaseline
        XCTAssertGreaterThan(baseline, 100) // Baseline should have moved up
        XCTAssertLessThan(baseline, 200) // But not all the way
    }

    func testNormalizeRemovesDCComponent() async {
        let service = PPGNormalizationService(alpha: 0.01)

        // Initialize baseline with constant DC
        for _ in 0..<100 {
            _ = await service.normalize(50000.0)
        }

        // Now add AC component
        let acSignal = await service.normalize(50100.0)

        // AC component should be approximately the deviation
        XCTAssertGreaterThan(acSignal, 0)
        XCTAssertLessThan(acSignal, 200) // Should be close to 100
    }

    // MARK: - Multi-Channel Normalization Tests - Raw

    func testNormalizePPGDataRawMethod() async {
        let service = PPGNormalizationService()

        let samples = [
            (timestamp: Date(), ir: 100.0, red: 80.0, green: 60.0),
            (timestamp: Date(), ir: 110.0, red: 85.0, green: 65.0)
        ]

        let normalized = await service.normalizePPGData(samples, method: .raw)

        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(normalized[0].ir, 100.0) // Raw = unchanged
        XCTAssertEqual(normalized[0].red, 80.0)
        XCTAssertEqual(normalized[0].green, 60.0)
        XCTAssertEqual(normalized[1].ir, 110.0)
    }

    func testNormalizePPGDataEmptyInput() async {
        let service = PPGNormalizationService()

        let samples: [(timestamp: Date, ir: Double, red: Double, green: Double)] = []

        let normalized = await service.normalizePPGData(samples, method: .raw)

        XCTAssertTrue(normalized.isEmpty)
    }

    // MARK: - Multi-Channel Normalization Tests - Dynamic Range

    func testNormalizePPGDataDynamicRange() async {
        let service = PPGNormalizationService()

        let samples = [
            (timestamp: Date(), ir: 0.0, red: 0.0, green: 0.0),
            (timestamp: Date(), ir: 50.0, red: 50.0, green: 50.0),
            (timestamp: Date(), ir: 100.0, red: 100.0, green: 100.0)
        ]

        let normalized = await service.normalizePPGData(samples, method: .dynamicRange)

        XCTAssertEqual(normalized.count, 3)

        // Min-max normalization: min=0, max=1, middle=0.5
        XCTAssertEqual(normalized[0].ir, 0.0, accuracy: 0.001)
        XCTAssertEqual(normalized[1].ir, 0.5, accuracy: 0.001)
        XCTAssertEqual(normalized[2].ir, 1.0, accuracy: 0.001)
    }

    func testNormalizePPGDataDynamicRangeConstantSignal() async {
        let service = PPGNormalizationService()

        let samples = [
            (timestamp: Date(), ir: 100.0, red: 100.0, green: 100.0),
            (timestamp: Date(), ir: 100.0, red: 100.0, green: 100.0)
        ]

        let normalized = await service.normalizePPGData(samples, method: .dynamicRange)

        // Constant signal: min=max, so normalized should be 0
        XCTAssertEqual(normalized[0].ir, 0.0)
        XCTAssertEqual(normalized[1].ir, 0.0)
    }

    // MARK: - Multi-Channel Normalization Tests - Adaptive Baseline

    func testNormalizePPGDataAdaptiveBaseline() async {
        let service = PPGNormalizationService()

        let samples = [
            (timestamp: Date(), ir: 50000.0, red: 40000.0, green: 30000.0),
            (timestamp: Date(), ir: 50100.0, red: 40080.0, green: 30060.0),
            (timestamp: Date(), ir: 49900.0, red: 39920.0, green: 29940.0)
        ]

        let normalized = await service.normalizePPGData(samples, method: .adaptiveBaseline)

        XCTAssertEqual(normalized.count, 3)

        // First sample should be 0 (baseline initialized to first value)
        XCTAssertEqual(normalized[0].ir, 0.0, accuracy: 0.001)

        // Subsequent samples are relative to adaptive baseline
        XCTAssertNotEqual(normalized[1].ir, 0)
    }

    // MARK: - Multi-Channel Normalization Tests - Persistent

    func testNormalizePPGDataPersistent() async {
        let service = PPGNormalizationService()

        let samples1 = [
            (timestamp: Date(), ir: 50000.0, red: 40000.0, green: 30000.0)
        ]

        let normalized1 = await service.normalizePPGData(samples1, method: .persistent)

        XCTAssertEqual(normalized1.count, 1)
        XCTAssertEqual(normalized1[0].ir, 0.0) // First sample initializes baseline

        // Second batch should maintain persistent baseline
        let samples2 = [
            (timestamp: Date(), ir: 50100.0, red: 40080.0, green: 30060.0)
        ]

        let normalized2 = await service.normalizePPGData(samples2, method: .persistent)

        XCTAssertGreaterThan(normalized2[0].ir, 0) // Above baseline
    }

    func testNormalizePPGDataPersistentMaintainsStateAcrossCalls() async {
        let service = PPGNormalizationService(alpha: 0.01)

        // First call initializes baseline
        _ = await service.normalizePPGData(
            [(timestamp: Date(), ir: 50000.0, red: 40000.0, green: 30000.0)],
            method: .persistent
        )

        let isInitialized = await service.isBaselineInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - PPGData Array Normalization

    func testNormalizePPGDataFromPPGDataArray() async {
        let service = PPGNormalizationService()

        let ppgData = [
            PPGData(red: 40000, ir: 50000, green: 30000, timestamp: Date()),
            PPGData(red: 40100, ir: 50100, green: 30050, timestamp: Date())
        ]

        let normalized = await service.normalizePPGData(ppgData, method: .raw)

        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(normalized[0].ir, 50000.0)
        XCTAssertEqual(normalized[0].red, 40000.0)
        XCTAssertEqual(normalized[0].green, 30000.0)
    }

    // MARK: - Signal Validation Tests

    func testIsSignalValidNormalSignal() async {
        let service = PPGNormalizationService()

        let isValid = await service.isSignalValid(50000.0)
        XCTAssertTrue(isValid)
    }

    func testIsSignalValidSaturatedSignal() async {
        let service = PPGNormalizationService(saturationThreshold: 65000)

        let isValid = await service.isSignalValid(70000.0)
        XCTAssertFalse(isValid) // Above saturation threshold
    }

    func testIsSignalValidLowSignal() async {
        let service = PPGNormalizationService(lowSignalThreshold: 1000)

        let isValid = await service.isSignalValid(500.0)
        XCTAssertFalse(isValid) // Below low signal threshold
    }

    func testIsSignalValidBoundaryConditions() async {
        let service = PPGNormalizationService(
            saturationThreshold: 65000,
            lowSignalThreshold: 1000
        )

        // Exactly at threshold should be invalid (not >threshold or <threshold)
        let atLow = await service.isSignalValid(1000.0)
        let atHigh = await service.isSignalValid(65000.0)

        XCTAssertFalse(atLow) // Not > 1000
        XCTAssertFalse(atHigh) // Not < 65000
    }

    // MARK: - Worn Status Validation

    func testValidateWornStatusValid() async {
        let service = PPGNormalizationService()

        let isWorn = await service.validateWornStatus(ir: 50000.0)
        XCTAssertTrue(isWorn)
    }

    func testValidateWornStatusLowSignal() async {
        let service = PPGNormalizationService(lowSignalThreshold: 10000)

        let isWorn = await service.validateWornStatus(ir: 5000.0)
        XCTAssertFalse(isWorn)
    }

    func testValidateWornStatusSaturated() async {
        let service = PPGNormalizationService(saturationThreshold: 100000)

        let isWorn = await service.validateWornStatus(ir: 150000.0)
        XCTAssertFalse(isWorn)
    }

    // MARK: - Reset Tests

    func testReset() async {
        let service = PPGNormalizationService()

        // Initialize baselines
        _ = await service.normalizePPGData(
            [(timestamp: Date(), ir: 50000.0, red: 40000.0, green: 30000.0)],
            method: .persistent
        )

        var isInitialized = await service.isBaselineInitialized
        XCTAssertTrue(isInitialized)

        // Reset
        await service.reset()

        isInitialized = await service.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }

    func testResetSingleChannelBaseline() async {
        let service = PPGNormalizationService()

        _ = await service.normalize(50000.0)
        var baseline = await service.currentBaseline
        XCTAssertEqual(baseline, 50000.0)

        await service.reset()

        baseline = await service.currentBaseline
        XCTAssertEqual(baseline, 0.0)
    }

    // MARK: - Perfusion Index Tests

    func testCalculatePerfusionIndex() async {
        let service = PPGNormalizationService()

        // PI = (AC / DC) * 100
        let pi = await service.calculatePerfusionIndex(rawValue: 50000.0, normalizedValue: 500.0)

        XCTAssertEqual(pi, 1.0, accuracy: 0.01) // (500/50000)*100 = 1%
    }

    func testCalculatePerfusionIndexZeroDC() async {
        let service = PPGNormalizationService()

        let pi = await service.calculatePerfusionIndex(rawValue: 0.0, normalizedValue: 100.0)

        XCTAssertEqual(pi, 0.0) // Division by zero protection
    }

    func testCalculatePerfusionIndexNegativeAC() async {
        let service = PPGNormalizationService()

        // Negative AC component (signal below baseline)
        let pi = await service.calculatePerfusionIndex(rawValue: 50000.0, normalizedValue: -500.0)

        XCTAssertEqual(pi, 1.0, accuracy: 0.01) // Uses absolute value
    }

    func testCalculatePerfusionIndexTypicalValues() async {
        let service = PPGNormalizationService()

        // Typical muscle-site PPG: DC ~150000, AC ~2000
        let pi = await service.calculatePerfusionIndex(rawValue: 150000.0, normalizedValue: 2000.0)

        // PI ≈ 1.33%
        XCTAssertEqual(pi, 1.33, accuracy: 0.1)
    }

    // MARK: - R Ratio Tests

    func testCalculateRRatio() async {
        let service = PPGNormalizationService()

        // R = (AC_Red/DC_Red) / (AC_IR/DC_IR)
        let rRatio = await service.calculateRRatio(
            redAC: 1000.0,
            redDC: 40000.0,
            irAC: 1500.0,
            irDC: 50000.0
        )

        // Red ratio = 1000/40000 = 0.025
        // IR ratio = 1500/50000 = 0.03
        // R = 0.025/0.03 = 0.833
        XCTAssertEqual(rRatio, 0.833, accuracy: 0.01)
    }

    func testCalculateRRatioZeroDC() async {
        let service = PPGNormalizationService()

        let rRatio = await service.calculateRRatio(
            redAC: 1000.0,
            redDC: 0.0, // Zero DC
            irAC: 1500.0,
            irDC: 50000.0
        )

        XCTAssertEqual(rRatio, 0.0)
    }

    func testCalculateRRatioZeroIRAC() async {
        let service = PPGNormalizationService()

        let rRatio = await service.calculateRRatio(
            redAC: 1000.0,
            redDC: 40000.0,
            irAC: 0.0, // Zero IR AC
            irDC: 50000.0
        )

        XCTAssertEqual(rRatio, 0.0)
    }

    func testCalculateRRatioNegativeAC() async {
        let service = PPGNormalizationService()

        // Negative AC values (uses absolute value)
        let rRatio = await service.calculateRRatio(
            redAC: -1000.0,
            redDC: 40000.0,
            irAC: -1500.0,
            irDC: 50000.0
        )

        XCTAssertEqual(rRatio, 0.833, accuracy: 0.01)
    }

    // MARK: - SpO2 Estimation Tests

    func testEstimateSpO2TypicalValue() async {
        let service = PPGNormalizationService()

        // R ratio around 0.5 should give ~97-98% SpO2
        let spo2 = await service.estimateSpO2(rRatio: 0.5)

        // SpO2 = 110 - 25 * 0.5 = 97.5
        XCTAssertEqual(spo2, 97.5, accuracy: 0.1)
    }

    func testEstimateSpO2HighOxygen() async {
        let service = PPGNormalizationService()

        // Low R ratio = high SpO2
        let spo2 = await service.estimateSpO2(rRatio: 0.4)

        // SpO2 = 110 - 25 * 0.4 = 100
        XCTAssertEqual(spo2, 100.0) // Clamped to 100
    }

    func testEstimateSpO2LowOxygen() async {
        let service = PPGNormalizationService()

        // High R ratio = low SpO2
        let spo2 = await service.estimateSpO2(rRatio: 2.0)

        // SpO2 = 110 - 25 * 2.0 = 60, clamped to 70
        XCTAssertEqual(spo2, 70.0)
    }

    func testEstimateSpO2ZeroRRatio() async {
        let service = PPGNormalizationService()

        let spo2 = await service.estimateSpO2(rRatio: 0.0)

        XCTAssertEqual(spo2, 0.0) // Zero R ratio returns 0
    }

    func testEstimateSpO2ClampingUpperBound() async {
        let service = PPGNormalizationService()

        // R ratio that would produce >100%
        let spo2 = await service.estimateSpO2(rRatio: 0.2)

        // SpO2 = 110 - 25 * 0.2 = 105, clamped to 100
        XCTAssertEqual(spo2, 100.0)
    }

    func testEstimateSpO2ClampingLowerBound() async {
        let service = PPGNormalizationService()

        // R ratio that would produce <70%
        let spo2 = await service.estimateSpO2(rRatio: 2.5)

        // SpO2 = 110 - 25 * 2.5 = 47.5, clamped to 70
        XCTAssertEqual(spo2, 70.0)
    }

    // MARK: - Integration Tests

    func testFullNormalizationPipeline() async {
        let service = PPGNormalizationService.oralable()

        // Simulate realistic PPG signal
        let samples = (0..<100).map { i -> (timestamp: Date, ir: Double, red: Double, green: Double) in
            let phase = Double(i) * 0.1
            let irBase = 150000.0
            let redBase = 120000.0
            let greenBase = 80000.0

            let pulse = sin(phase) * 3000 // Simulated pulse

            return (
                timestamp: Date().addingTimeInterval(Double(i) * 0.02),
                ir: irBase + pulse,
                red: redBase + pulse * 0.8,
                green: greenBase + pulse * 0.6
            )
        }

        // Test all normalization methods
        let rawResults = await service.normalizePPGData(samples, method: .raw)
        let dynamicResults = await service.normalizePPGData(samples, method: .dynamicRange)
        let adaptiveResults = await service.normalizePPGData(samples, method: .adaptiveBaseline)

        XCTAssertEqual(rawResults.count, 100)
        XCTAssertEqual(dynamicResults.count, 100)
        XCTAssertEqual(adaptiveResults.count, 100)

        // Raw should preserve original values
        XCTAssertEqual(rawResults[0].ir, samples[0].ir)

        // Dynamic range should normalize to 0-1
        XCTAssertGreaterThanOrEqual(dynamicResults.map(\.ir).min() ?? -1, 0.0)
        XCTAssertLessThanOrEqual(dynamicResults.map(\.ir).max() ?? 2, 1.0)
    }

    func testSpO2CalculationPipeline() async {
        let service = PPGNormalizationService()

        // Typical values for healthy individual
        // Using values that produce a lower R ratio for higher SpO2
        let irDC = 150000.0
        let irAC = 2000.0
        let redDC = 120000.0
        let redAC = 1000.0  // Lower red AC relative to IR AC = lower R ratio = higher SpO2

        let rRatio = await service.calculateRRatio(
            redAC: redAC,
            redDC: redDC,
            irAC: irAC,
            irDC: irDC
        )

        let spo2 = await service.estimateSpO2(rRatio: rRatio)

        // Should produce reasonable SpO2 value (within physiological range)
        XCTAssertGreaterThan(spo2, 70.0)  // Above minimum clamp
        XCTAssertLessThanOrEqual(spo2, 100.0)

        // R ratio for these values: (1000/120000) / (2000/150000) = 0.00833 / 0.01333 = 0.625
        // SpO2 = 110 - 25 * 0.625 = 94.375
        XCTAssertEqual(spo2, 94.375, accuracy: 1.0)
    }
}
