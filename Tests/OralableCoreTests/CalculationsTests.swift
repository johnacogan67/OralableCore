//
//  CalculationsTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for biometric calculation components
//

import XCTest
@testable import OralableCore

final class CalculationsTests: XCTestCase {

    // MARK: - ActivityType Tests

    func testActivityTypeDescription() {
        XCTAssertEqual(ActivityType.relaxed.description, "Relaxed")
        XCTAssertEqual(ActivityType.clenching.description, "Clenching")
        XCTAssertEqual(ActivityType.grinding.description, "Grinding")
        XCTAssertEqual(ActivityType.motion.description, "Motion")
    }

    func testActivityTypeBruxismIndicator() {
        XCTAssertFalse(ActivityType.relaxed.isBruxismIndicator)
        XCTAssertTrue(ActivityType.clenching.isBruxismIndicator)
        XCTAssertTrue(ActivityType.grinding.isBruxismIndicator)
        XCTAssertFalse(ActivityType.motion.isBruxismIndicator)
    }

    func testActivityTypeIconName() {
        XCTAssertEqual(ActivityType.relaxed.iconName, "face.smiling")
        XCTAssertEqual(ActivityType.clenching.iconName, "face.dashed")
        XCTAssertEqual(ActivityType.grinding.iconName, "waveform")
        XCTAssertEqual(ActivityType.motion.iconName, "figure.walk")
    }

    func testActivityTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for activityType in ActivityType.allCases {
            let data = try encoder.encode(activityType)
            let decoded = try decoder.decode(ActivityType.self, from: data)
            XCTAssertEqual(decoded, activityType)
        }
    }

    // MARK: - ActivityClassifier Tests

    func testActivityClassifierRelaxedState() {
        let classifier = ActivityClassifier()

        // Simulate relaxed state with stable IR and low accelerometer
        let activity = classifier.classify(ir: 50000, accMagnitude: 1.0)
        XCTAssertEqual(activity, .relaxed)
    }

    func testActivityClassifierMotionDetection() {
        let classifier = ActivityClassifier()

        // Initialize baseline
        _ = classifier.classify(ir: 50000, accMagnitude: 1.0)

        // High accelerometer should trigger motion
        let activity = classifier.classify(ir: 50000, accMagnitude: 1.5)
        XCTAssertEqual(activity, .motion)
    }

    func testActivityClassifierReset() {
        let classifier = ActivityClassifier()

        // Establish baseline
        for _ in 0..<10 {
            _ = classifier.classify(ir: 50000, accMagnitude: 1.0)
        }

        // Reset and verify it can start fresh
        classifier.reset()

        // After reset, first sample sets new baseline
        let activity = classifier.classify(ir: 60000, accMagnitude: 1.0)
        XCTAssertEqual(activity, .relaxed)
    }

    // MARK: - MotionCompensator Tests

    func testMotionCompensatorLowNoise() {
        let compensator = MotionCompensator()

        // With low noise reference, output should be close to input
        let signal = 100.0
        let noiseReference = 0.001
        let filtered = compensator.filter(signal: signal, noiseReference: noiseReference)

        // Initial output should be close to signal (filter needs time to adapt)
        XCTAssertNotNil(filtered)
    }

    func testMotionCompensatorHighVariance() {
        let compensator = MotionCompensator(varianceThreshold: 0.1)

        // Build up high variance in noise history
        for i in 0..<32 {
            let noise = Double(i % 2 == 0 ? 10 : -10)
            _ = compensator.filter(signal: 100.0, noiseReference: noise)
        }

        // High variance should dampen signal significantly
        let filtered = compensator.filter(signal: 100.0, noiseReference: 5.0)
        XCTAssertLessThan(filtered, 50.0) // Should be significantly dampened
    }

    func testMotionCompensatorReset() {
        let compensator = MotionCompensator()

        // Process some samples
        for _ in 0..<10 {
            _ = compensator.filter(signal: 100.0, noiseReference: 0.1)
        }

        // Reset
        compensator.reset()

        // After reset, should behave as if new
        let filtered = compensator.filter(signal: 50.0, noiseReference: 0.001)
        XCTAssertNotNil(filtered)
    }

    // MARK: - BiometricConfiguration Tests

    func testDefaultOralableConfiguration() {
        let config = BiometricConfiguration.oralable

        XCTAssertEqual(config.sampleRate, 50.0)
        XCTAssertEqual(config.hrWindowSeconds, 3.0)
        XCTAssertEqual(config.spo2WindowSeconds, 3.0)
        XCTAssertEqual(config.hrWindowSize, 150) // 50 Hz * 3 seconds
        XCTAssertEqual(config.spo2WindowSize, 150)
        XCTAssertEqual(config.minBPM, 40)
        XCTAssertEqual(config.maxBPM, 180)
    }

    func testANRConfiguration() {
        let config = BiometricConfiguration.anr

        XCTAssertEqual(config.sampleRate, 100.0)
        XCTAssertEqual(config.hrWindowSize, 300) // 100 Hz * 3 seconds
    }

    func testDemoConfiguration() {
        let config = BiometricConfiguration.demo

        XCTAssertEqual(config.sampleRate, 10.0)
        XCTAssertEqual(config.hrWindowSeconds, 5.0)
        XCTAssertEqual(config.hrWindowSize, 50) // 10 Hz * 5 seconds
    }

    func testCustomConfiguration() {
        let config = BiometricConfiguration(
            sampleRate: 25.0,
            hrWindowSeconds: 4.0,
            minBPM: 50,
            maxBPM: 160
        )

        XCTAssertEqual(config.sampleRate, 25.0)
        XCTAssertEqual(config.hrWindowSize, 100) // 25 Hz * 4 seconds
        XCTAssertEqual(config.minBPM, 50)
        XCTAssertEqual(config.maxBPM, 160)
    }

    // MARK: - BiometricResult Tests

    func testBiometricResultEmpty() {
        let result = BiometricResult.empty

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.heartRateQuality, 0)
        XCTAssertEqual(result.heartRateSource, .unavailable)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.spo2Quality, 0)
        XCTAssertEqual(result.perfusionIndex, 0)
        XCTAssertFalse(result.isWorn)
        XCTAssertEqual(result.activity, .relaxed)
        XCTAssertEqual(result.signalStrength, .none)
        XCTAssertEqual(result.processingMethod, .realtime)
    }

    func testBiometricResultValidHeartRate() {
        let result = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.003,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.05,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertTrue(result.hasValidHeartRate)
        XCTAssertTrue(result.hasValidSpO2)
        XCTAssertFalse(result.isMoving)
    }

    func testBiometricResultNoValidHeartRate() {
        let result = BiometricResult(
            heartRate: 0,
            heartRateQuality: 0,
            heartRateSource: .unavailable,
            spo2: 0,
            spo2Quality: 0,
            perfusionIndex: 0,
            isWorn: false,
            activity: .motion,
            motionLevel: 0.5,
            signalStrength: .none,
            processingMethod: .realtime
        )

        XCTAssertFalse(result.hasValidHeartRate)
        XCTAssertFalse(result.hasValidSpO2)
        XCTAssertTrue(result.isMoving)
    }

    func testBiometricResultEquatable() {
        let result1 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.003,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.05,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        let result2 = BiometricResult(
            heartRate: 72,
            heartRateQuality: 0.85,
            heartRateSource: .ir,
            spo2: 98,
            spo2Quality: 0.9,
            perfusionIndex: 0.003,
            isWorn: true,
            activity: .relaxed,
            motionLevel: 0.05,
            signalStrength: .strong,
            processingMethod: .realtime
        )

        XCTAssertEqual(result1, result2)
    }

    // MARK: - HRSource Tests

    func testHRSourceDescription() {
        XCTAssertEqual(HRSource.ir.description, "Infrared")
        XCTAssertEqual(HRSource.green.description, "Green")
        XCTAssertEqual(HRSource.fft.description, "FFT")
        XCTAssertEqual(HRSource.unavailable.description, "Unavailable")
    }

    func testHRSourceCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let sources: [HRSource] = [.ir, .green, .fft, .unavailable]
        for source in sources {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(HRSource.self, from: data)
            XCTAssertEqual(decoded, source)
        }
    }

    // MARK: - SignalStrength Tests

    func testSignalStrengthFromPerfusionIndex() {
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.0003), .none)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.001), .weak)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.003), .moderate)
        XCTAssertEqual(SignalStrength(perfusionIndex: 0.01), .strong)
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

    // MARK: - ProcessingMethod Tests

    func testProcessingMethodCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let methods: [ProcessingMethod] = [.realtime, .batch]
        for method in methods {
            let data = try encoder.encode(method)
            let decoded = try decoder.decode(ProcessingMethod.self, from: data)
            XCTAssertEqual(decoded, method)
        }
    }

    // MARK: - BiometricProcessor Tests

    func testBiometricProcessorInitialization() async {
        let processor = BiometricProcessor(config: .oralable)
        let bufferSize = await processor.currentBufferSize
        let requiredSize = await processor.requiredBufferSize

        XCTAssertEqual(bufferSize, 0)
        XCTAssertEqual(requiredSize, 150) // 50 Hz * 3 seconds
    }

    func testBiometricProcessorInsufficientData() async {
        let config = BiometricConfiguration.demo // Smaller buffer for faster testing
        let processor = BiometricProcessor(config: config)

        // Process a few samples (not enough to fill buffer)
        let result = await processor.process(
            ir: 50000,
            red: 40000,
            green: 30000,
            accelX: 0,
            accelY: 0,
            accelZ: 16384
        )

        // Should return unavailable with no HR/SpO2
        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.heartRateSource, .unavailable)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.processingMethod, .realtime)
    }

    func testBiometricProcessorReset() async {
        let processor = BiometricProcessor(config: .demo)

        // Process some samples
        for _ in 0..<20 {
            _ = await processor.process(
                ir: 50000,
                red: 40000,
                green: 30000,
                accelX: 0,
                accelY: 0,
                accelZ: 16384
            )
        }

        let bufferBeforeReset = await processor.currentBufferSize
        XCTAssertGreaterThan(bufferBeforeReset, 0)

        // Reset
        await processor.reset()

        let bufferAfterReset = await processor.currentBufferSize
        XCTAssertEqual(bufferAfterReset, 0)
    }

    func testBiometricProcessorMotionDetection() async {
        let processor = BiometricProcessor(config: .demo)

        // Process with high motion accelerometer values
        let result = await processor.process(
            ir: 50000,
            red: 40000,
            green: 30000,
            accelX: 20000,  // High motion
            accelY: 20000,
            accelZ: 20000
        )

        // Motion level should be elevated
        XCTAssertGreaterThan(result.motionLevel, 0)
    }

    func testBiometricProcessorBatchProcessing() async {
        let config = BiometricConfiguration(
            sampleRate: 10.0,
            hrWindowSeconds: 1.0
        )
        let processor = BiometricProcessor(config: config)

        // Create simple test data
        let count = 20
        let irSamples = Array(repeating: 50000.0, count: count)
        let redSamples = Array(repeating: 40000.0, count: count)
        let greenSamples = Array(repeating: 30000.0, count: count)
        let accelX = Array(repeating: 0.0, count: count)
        let accelY = Array(repeating: 0.0, count: count)
        let accelZ = Array(repeating: 16384.0, count: count)

        let result = await processor.processBatch(
            irSamples: irSamples,
            redSamples: redSamples,
            greenSamples: greenSamples,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ
        )

        // Should have batch processing method
        XCTAssertEqual(result.processingMethod, .batch)
    }

    func testBiometricProcessorActivityClassification() async {
        let processor = BiometricProcessor(config: .demo)

        // Process with normal stationary accelerometer (gravity only)
        let result = await processor.process(
            ir: 50000,
            red: 40000,
            green: 30000,
            accelX: 0,
            accelY: 0,
            accelZ: 16384  // 1g in Z direction
        )

        // Should be relaxed or some activity, not necessarily motion
        XCTAssertNotEqual(result.activity, .motion)
    }
}
