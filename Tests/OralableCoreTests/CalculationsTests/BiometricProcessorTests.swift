//
//  BiometricProcessorTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for BiometricProcessor actor
//

import XCTest
@testable import OralableCore

final class BiometricProcessorTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() async {
        let processor = BiometricProcessor()

        let bufferSize = await processor.currentBufferSize
        let requiredSize = await processor.requiredBufferSize

        XCTAssertEqual(bufferSize, 0)
        XCTAssertEqual(requiredSize, 150) // 50 Hz * 3 seconds
    }

    func testCustomConfigInitialization() async {
        let config = BiometricConfiguration(
            sampleRate: 100.0,
            hrWindowSeconds: 2.0
        )
        let processor = BiometricProcessor(config: config)

        let requiredSize = await processor.requiredBufferSize

        XCTAssertEqual(requiredSize, 200) // 100 Hz * 2 seconds
    }

    func testDemoConfigInitialization() async {
        let processor = BiometricProcessor(config: .demo)

        let requiredSize = await processor.requiredBufferSize

        XCTAssertEqual(requiredSize, 50) // 10 Hz * 5 seconds
    }

    // MARK: - Single Frame Processing Tests

    func testProcessSingleFrameInsufficientData() async {
        let processor = BiometricProcessor()

        // Process single frame (not enough for HR calculation)
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0 // 1g in Z (stationary)
        )

        // Should return empty result due to insufficient data
        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.heartRateSource, .unavailable)
        XCTAssertFalse(result.isWorn)
        XCTAssertEqual(result.processingMethod, .realtime)
    }

    func testProcessMultipleFramesBuildBuffer() async {
        let processor = BiometricProcessor(config: .demo) // Use demo for smaller buffer

        // Feed enough samples to build buffer
        for i in 0..<60 {
            let phase = Double(i) * 0.2
            let ir = 100000.0 + sin(phase) * 5000.0 // Simulated PPG wave
            let red = 80000.0 + sin(phase) * 4000.0
            let green = 50000.0 + sin(phase) * 3000.0

            _ = await processor.process(
                ir: ir,
                red: red,
                green: green,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        let bufferSize = await processor.currentBufferSize

        // Buffer should be at window size
        XCTAssertEqual(bufferSize, 50) // demo config window size
    }

    func testProcessWithMotion() async {
        let processor = BiometricProcessor()

        // Process with high motion (high accelerometer values)
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 32768.0, // High motion
            accelY: 32768.0,
            accelZ: 32768.0
        )

        // Motion level should be high
        XCTAssertGreaterThan(result.motionLevel, 0.5)
    }

    func testProcessStationaryLowMotion() async {
        let processor = BiometricProcessor()

        // Process with stationary accelerometer (1g in Z direction)
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0
        )

        // Motion level should be low for stationary
        XCTAssertLessThan(result.motionLevel, 0.2)
    }

    // MARK: - Batch Processing Tests

    func testBatchProcessingEmptyArrays() async {
        let processor = BiometricProcessor()

        let result = await processor.processBatch(
            irSamples: [],
            redSamples: [],
            greenSamples: [],
            accelX: [],
            accelY: [],
            accelZ: []
        )

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.processingMethod, .batch)
    }

    func testBatchProcessingWithSimulatedData() async {
        let processor = BiometricProcessor(config: .demo)

        // Generate simulated PPG data with a heart rate ~72 bpm
        // At 10 Hz demo rate, 72 bpm = 0.833 sec per beat = 8.33 samples per beat
        let sampleCount = 100
        var irSamples: [Double] = []
        var redSamples: [Double] = []
        var greenSamples: [Double] = []
        var accelX: [Double] = []
        var accelY: [Double] = []
        var accelZ: [Double] = []

        for i in 0..<sampleCount {
            // Simulated heart rate ~72 bpm
            let phase = Double(i) / 10.0 * 2.0 * .pi * 1.2 // ~72 bpm
            let ir = 100000.0 + sin(phase) * 10000.0
            let red = 80000.0 + sin(phase) * 8000.0
            let green = 50000.0 + sin(phase) * 5000.0

            irSamples.append(ir)
            redSamples.append(red)
            greenSamples.append(green)
            accelX.append(0.0)
            accelY.append(0.0)
            accelZ.append(16384.0) // Stationary
        }

        let result = await processor.processBatch(
            irSamples: irSamples,
            redSamples: redSamples,
            greenSamples: greenSamples,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ
        )

        XCTAssertEqual(result.processingMethod, .batch)
        // Activity should not be motion
        XCTAssertNotEqual(result.activity, .motion)
    }

    func testBatchProcessingDifferentArrayLengths() async {
        let processor = BiometricProcessor()

        // Arrays of different lengths - should use minimum
        let result = await processor.processBatch(
            irSamples: Array(repeating: 100000.0, count: 100),
            redSamples: Array(repeating: 80000.0, count: 50), // Shorter
            greenSamples: Array(repeating: 50000.0, count: 100),
            accelX: Array(repeating: 0.0, count: 100),
            accelY: Array(repeating: 0.0, count: 100),
            accelZ: Array(repeating: 16384.0, count: 100)
        )

        XCTAssertEqual(result.processingMethod, .batch)
    }

    // MARK: - Reset Tests

    func testReset() async {
        let processor = BiometricProcessor(config: .demo)

        // Build up buffer
        for _ in 0..<60 {
            _ = await processor.process(
                ir: 100000.0,
                red: 80000.0,
                green: 50000.0,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        let bufferBefore = await processor.currentBufferSize
        XCTAssertGreaterThan(bufferBefore, 0)

        // Reset
        await processor.reset()

        let bufferAfter = await processor.currentBufferSize
        XCTAssertEqual(bufferAfter, 0)
    }

    func testResetClearsProcessingState() async {
        let processor = BiometricProcessor(config: .demo)

        // Process some data
        for i in 0..<60 {
            let phase = Double(i) * 0.2
            let ir = 100000.0 + sin(phase) * 5000.0
            _ = await processor.process(
                ir: ir,
                red: 80000.0,
                green: 50000.0,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        // Reset
        await processor.reset()

        // First frame after reset should return empty result
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0
        )

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.heartRateSource, .unavailable)
    }

    // MARK: - Signal Strength Tests

    func testSignalStrengthWithGoodSignal() async {
        let processor = BiometricProcessor(config: .demo)

        // Feed enough samples with varying signal (good perfusion)
        for i in 0..<60 {
            let phase = Double(i) * 0.3
            let ir = 100000.0 + sin(phase) * 20000.0 // Large variation = good PI
            let red = 80000.0 + sin(phase) * 15000.0
            let green = 50000.0 + sin(phase) * 10000.0

            _ = await processor.process(
                ir: ir,
                red: red,
                green: green,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        // Get final result
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0
        )

        // With large AC component, should have strong signal
        XCTAssertTrue(result.signalStrength.isUsable || result.signalStrength == .strong)
    }

    // MARK: - Activity Classification Tests

    func testActivityClassificationRelaxed() async {
        let processor = BiometricProcessor()

        // Stationary with consistent signal
        var lastResult: BiometricResult!
        for _ in 0..<10 {
            lastResult = await processor.process(
                ir: 100000.0,
                red: 80000.0,
                green: 50000.0,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        XCTAssertEqual(lastResult.activity, .relaxed)
    }

    func testActivityClassificationMotion() async {
        let processor = BiometricProcessor()

        // High motion should classify as motion
        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 50000.0, // Very high motion
            accelY: 50000.0,
            accelZ: 50000.0
        )

        // High accelerometer deviation should trigger motion
        XCTAssertGreaterThan(result.motionLevel, 1.0)
    }

    // MARK: - Worn Detection Tests

    func testNotWornInitially() async {
        let processor = BiometricProcessor()

        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0
        )

        // Not worn initially due to insufficient data
        XCTAssertFalse(result.isWorn)
    }

    // MARK: - Perfusion Index Tests

    func testPerfusionIndexWithFlatSignal() async {
        let processor = BiometricProcessor(config: .demo)

        // Feed flat signal (no AC component)
        for _ in 0..<60 {
            _ = await processor.process(
                ir: 100000.0, // Constant
                red: 80000.0,
                green: 50000.0,
                accelX: 0.0,
                accelY: 0.0,
                accelZ: 16384.0
            )
        }

        let result = await processor.process(
            ir: 100000.0,
            red: 80000.0,
            green: 50000.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 16384.0
        )

        // Flat signal should have low perfusion index (some variation from filtering)
        // But still much lower than a pulsating signal
        XCTAssertLessThan(result.perfusionIndex, 0.1)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentProcessing() async {
        let processor = BiometricProcessor(config: .demo)

        await withTaskGroup(of: BiometricResult.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let ir = 100000.0 + Double(i % 10) * 1000
                    return await processor.process(
                        ir: ir,
                        red: 80000.0,
                        green: 50000.0,
                        accelX: 0.0,
                        accelY: 0.0,
                        accelZ: 16384.0
                    )
                }
            }

            var results: [BiometricResult] = []
            for await result in group {
                results.append(result)
            }

            // All 50 results should be valid
            XCTAssertEqual(results.count, 50)
            for result in results {
                XCTAssertTrue(result.motionLevel.isFinite)
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroValues() async {
        let processor = BiometricProcessor()

        let result = await processor.process(
            ir: 0.0,
            red: 0.0,
            green: 0.0,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 0.0
        )

        // Should handle zero values gracefully
        XCTAssertTrue(result.motionLevel.isFinite)
        XCTAssertEqual(result.heartRate, 0)
    }

    func testNegativeValues() async {
        let processor = BiometricProcessor()

        let result = await processor.process(
            ir: -1000.0,
            red: -1000.0,
            green: -1000.0,
            accelX: -16384.0,
            accelY: -16384.0,
            accelZ: -16384.0
        )

        // Should handle negative values gracefully
        XCTAssertTrue(result.motionLevel.isFinite)
    }

    func testVeryLargeValues() async {
        let processor = BiometricProcessor()

        let result = await processor.process(
            ir: 1000000.0,
            red: 1000000.0,
            green: 1000000.0,
            accelX: 100000.0,
            accelY: 100000.0,
            accelZ: 100000.0
        )

        // Should handle large values gracefully
        XCTAssertTrue(result.motionLevel.isFinite)
    }
}
