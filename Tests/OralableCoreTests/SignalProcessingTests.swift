//
//  SignalProcessingTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for signal processing services
//

import XCTest
@testable import OralableCore

final class SignalProcessingTests: XCTestCase {

    // MARK: - HeartRateService Tests

    func testHeartRateServiceInitialization() async {
        let service = HeartRateService.oralable()
        let fillLevel = await service.bufferFillLevel

        XCTAssertEqual(fillLevel, 0)
    }

    func testHRResultEmpty() {
        let result = HRResult.empty

        XCTAssertEqual(result.bpm, 0)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertFalse(result.isWorn)
        XCTAssertEqual(result.peakCount, 0)
        XCTAssertNil(result.hrvMs)
        XCTAssertFalse(result.isValid)
    }

    func testHRResultValidRange() {
        let validResult = HRResult(bpm: 72, confidence: 0.8, isWorn: true, peakCount: 5)
        XCTAssertTrue(validResult.isValid)

        let lowBPM = HRResult(bpm: 30, confidence: 0.8, isWorn: true)
        XCTAssertFalse(lowBPM.isValid)

        let highBPM = HRResult(bpm: 220, confidence: 0.8, isWorn: true)
        XCTAssertFalse(highBPM.isValid)

        let lowConfidence = HRResult(bpm: 72, confidence: 0.3, isWorn: true)
        XCTAssertFalse(lowConfidence.isValid)
    }

    func testHeartRateServiceInsufficientData() async {
        let service = HeartRateService(
            sampleRate: 50.0,
            windowSeconds: 5.0
        )

        // Process fewer samples than window size
        let samples = Array(repeating: 100.0, count: 50)
        let result = await service.process(samples: samples)

        XCTAssertEqual(result.bpm, 0)
        XCTAssertFalse(result.isWorn)
    }

    func testHeartRateServiceReset() async {
        let service = HeartRateService.demo()

        // Process some samples
        let samples = Array(repeating: 100.0, count: 50)
        _ = await service.process(samples: samples)

        let beforeReset = await service.bufferFillLevel
        XCTAssertGreaterThan(beforeReset, 0)

        // Reset
        await service.reset()

        let afterReset = await service.bufferFillLevel
        XCTAssertEqual(afterReset, 0)
    }

    func testHeartRateServiceFactoryMethods() async {
        let oralable = HeartRateService.oralable()
        let anr = HeartRateService.anr()
        let demo = HeartRateService.demo()

        // Verify different configurations by checking buffer fill with same data
        let samples = Array(repeating: 100.0, count: 100)

        _ = await oralable.process(samples: samples)
        _ = await anr.process(samples: samples)
        _ = await demo.process(samples: samples)

        // All should have processed without crashing
        XCTAssertTrue(true)
    }

    // MARK: - PPGNormalizationService Tests

    func testPPGNormalizationMethodDescription() {
        XCTAssertEqual(PPGNormalizationMethod.raw.description, "Raw (No Processing)")
        XCTAssertEqual(PPGNormalizationMethod.dynamicRange.description, "Dynamic Range Scaling")
        XCTAssertEqual(PPGNormalizationMethod.adaptiveBaseline.description, "Adaptive Baseline")
        XCTAssertEqual(PPGNormalizationMethod.persistent.description, "Persistent Baseline")
    }

    func testNormalizedPPGSampleCreation() {
        let sample = NormalizedPPGSample(
            timestamp: Date(),
            ir: 0.5,
            red: 0.3,
            green: 0.2
        )

        XCTAssertEqual(sample.ir, 0.5)
        XCTAssertEqual(sample.red, 0.3)
        XCTAssertEqual(sample.green, 0.2)
    }

    func testPPGNormalizationServiceSingleChannel() async {
        let service = PPGNormalizationService()

        // First sample sets baseline
        let first = await service.normalize(50000)
        XCTAssertEqual(first, 0) // First sample returns 0

        // Second sample should return AC component
        let second = await service.normalize(50100)
        XCTAssertNotEqual(second, 0)
    }

    func testPPGNormalizationServiceReset() async {
        let service = PPGNormalizationService()

        // Normalize some values
        _ = await service.normalize(50000)
        _ = await service.normalize(50100)

        let baselineBefore = await service.currentBaseline
        XCTAssertGreaterThan(baselineBefore, 0)

        // Reset
        await service.reset()

        let baselineAfter = await service.currentBaseline
        XCTAssertEqual(baselineAfter, 0)
    }

    func testPPGNormalizationRawMethod() async {
        let service = PPGNormalizationService()

        let samples: [(timestamp: Date, ir: Double, red: Double, green: Double)] = [
            (Date(), 50000, 40000, 30000),
            (Date(), 50100, 40100, 30100)
        ]

        let normalized = await service.normalizePPGData(samples, method: .raw)

        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(normalized[0].ir, 50000)
        XCTAssertEqual(normalized[0].red, 40000)
        XCTAssertEqual(normalized[0].green, 30000)
    }

    func testPPGNormalizationDynamicRangeMethod() async {
        let service = PPGNormalizationService()

        let samples: [(timestamp: Date, ir: Double, red: Double, green: Double)] = [
            (Date(), 0, 0, 0),
            (Date(), 100, 100, 100)
        ]

        let normalized = await service.normalizePPGData(samples, method: .dynamicRange)

        XCTAssertEqual(normalized.count, 2)
        // Dynamic range should normalize to 0-1 range
        XCTAssertEqual(normalized[0].ir, 0)
        XCTAssertEqual(normalized[1].ir, 1)
    }

    func testPPGNormalizationSignalValidation() async {
        let service = PPGNormalizationService.oralable()

        // Valid signal (within thresholds)
        let valid = await service.isSignalValid(50000)
        XCTAssertTrue(valid)

        // Saturated signal (above threshold)
        let saturated = await service.isSignalValid(600000)
        XCTAssertFalse(saturated)

        // Low signal (below threshold)
        let low = await service.isSignalValid(500)
        XCTAssertFalse(low)
    }

    func testPerfusionIndexCalculation() async {
        let service = PPGNormalizationService()

        let pi = await service.calculatePerfusionIndex(rawValue: 50000, normalizedValue: 500)

        // PI = (|AC| / DC) * 100 = (500 / 50000) * 100 = 1.0
        XCTAssertEqual(pi, 1.0, accuracy: 0.001)
    }

    func testRRatioCalculation() async {
        let service = PPGNormalizationService()

        let rRatio = await service.calculateRRatio(
            redAC: 100,
            redDC: 10000,
            irAC: 200,
            irDC: 20000
        )

        // R = (AC_Red/DC_Red) / (AC_IR/DC_IR) = (0.01) / (0.01) = 1.0
        XCTAssertEqual(rRatio, 1.0, accuracy: 0.001)
    }

    func testSpO2Estimation() async {
        let service = PPGNormalizationService()

        // R = 1.0 should give SpO2 around 85%
        let spo2_r1 = await service.estimateSpO2(rRatio: 1.0)
        XCTAssertEqual(spo2_r1, 85.0, accuracy: 1.0)

        // R = 0.5 should give higher SpO2
        let spo2_r05 = await service.estimateSpO2(rRatio: 0.5)
        XCTAssertGreaterThan(spo2_r05, 90)

        // Invalid R = 0 should return 0
        let spo2_invalid = await service.estimateSpO2(rRatio: 0)
        XCTAssertEqual(spo2_invalid, 0)
    }

    // MARK: - SpO2Service Tests

    func testSpO2ResultEmpty() {
        let result = SpO2Result.empty

        XCTAssertEqual(result.percentage, 0)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.rRatio, 0)
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.isClinicallyValid)
    }

    func testSpO2ResultClinicalValidity() {
        let valid = SpO2Result(percentage: 98, confidence: 0.8, rRatio: 0.5, isValid: true)
        XCTAssertTrue(valid.isClinicallyValid)

        let lowSpO2 = SpO2Result(percentage: 65, confidence: 0.8, rRatio: 1.5, isValid: true)
        XCTAssertFalse(lowSpO2.isClinicallyValid)

        let lowConfidence = SpO2Result(percentage: 98, confidence: 0.5, rRatio: 0.5, isValid: true)
        XCTAssertFalse(lowConfidence.isClinicallyValid)
    }

    func testSpO2CalibrationCurveDescription() {
        XCTAssertEqual(SpO2CalibrationCurve.linear.description, "Linear (Simple)")
        XCTAssertEqual(SpO2CalibrationCurve.quadratic.description, "Quadratic (Standard)")
        XCTAssertEqual(SpO2CalibrationCurve.cubic.description, "Cubic (Precision)")
    }

    func testSpO2ServiceInsufficientData() async {
        let service = SpO2Service.oralable()

        // Process fewer samples than required
        let red = Array(repeating: 50000.0, count: 50)
        let ir = Array(repeating: 60000.0, count: 50)

        let result = await service.process(redSamples: red, irSamples: ir)

        XCTAssertFalse(result.isValid)
    }

    func testSpO2ServiceReset() async {
        let service = SpO2Service.demo()

        // Add some samples
        for _ in 0..<30 {
            _ = await service.addSample(red: 50000, ir: 60000)
        }

        let beforeReset = await service.bufferFillLevel
        XCTAssertGreaterThan(beforeReset, 0)

        await service.reset()

        let afterReset = await service.bufferFillLevel
        XCTAssertEqual(afterReset, 0)
    }

    func testSpO2ServiceFactoryMethods() async {
        let oralable = SpO2Service.oralable()
        let clinical = SpO2Service.clinical()
        let demo = SpO2Service.demo()

        // All should initialize without crashing
        _ = await oralable.bufferFillLevel
        _ = await clinical.bufferFillLevel
        _ = await demo.bufferFillLevel

        XCTAssertTrue(true)
    }

    func testSpO2UtilityRRatioCalculation() {
        let rRatio = SpO2Service.calculateRRatio(
            acRed: 100,
            dcRed: 10000,
            acIR: 200,
            dcIR: 20000
        )

        XCTAssertEqual(rRatio, 1.0, accuracy: 0.001)

        // Invalid inputs should return 0
        let invalid = SpO2Service.calculateRRatio(acRed: 100, dcRed: 0, acIR: 200, dcIR: 20000)
        XCTAssertEqual(invalid, 0)
    }

    func testSpO2UtilityConversion() {
        // R = 1.0 should give SpO2 around 80-85%
        let spo2 = SpO2Service.rRatioToSpO2(1.0)
        XCTAssertGreaterThan(spo2, 70)
        XCTAssertLessThan(spo2, 100)

        // SpO2 = 98% should give R around 0.5
        let rRatio = SpO2Service.spO2ToRRatio(98)
        XCTAssertEqual(rRatio, 0.48, accuracy: 0.1)
    }

    // MARK: - DemoDataGenerator Tests

    func testDemoDataConfigurationPresets() {
        let standard = DemoDataConfiguration.standard
        XCTAssertEqual(standard.heartRateRange, 60...100)
        XCTAssertEqual(standard.spo2Range, 95...100)

        let exercise = DemoDataConfiguration.exercise
        XCTAssertEqual(exercise.heartRateRange, 90...150)

        let resting = DemoDataConfiguration.resting
        XCTAssertEqual(resting.heartRateRange, 50...70)

        let clinical = DemoDataConfiguration.clinical
        XCTAssertEqual(clinical.ppgSamplingRate, 100.0)
    }

    func testDemoDataGeneratorInitialization() async {
        let generator = DemoDataGenerator()

        let index = await generator.currentSampleIndex
        let battery = await generator.batteryLevel

        XCTAssertEqual(index, 0)
        XCTAssertEqual(battery, 85)
    }

    func testDemoDataGeneratorPPGSample() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generatePPGSample()

        // PPG values should be in reasonable range
        XCTAssertGreaterThan(sample.ir, 100000)
        XCTAssertGreaterThan(sample.red, 100000)
        XCTAssertGreaterThan(sample.green, 50000)
    }

    func testDemoDataGeneratorPPGSequence() async {
        let generator = DemoDataGenerator()

        let sequence = await generator.generatePPGSequence(duration: 1.0)

        // At 50Hz, 1 second should produce 50 samples
        XCTAssertEqual(sequence.count, 50)
    }

    func testDemoDataGeneratorAccelerometerRelaxed() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .relaxed)

        // Z should be close to 1g (16384), X and Y close to 0
        XCTAssertLessThan(abs(Int32(sample.x)), 100)
        XCTAssertLessThan(abs(Int32(sample.y)), 100)
        XCTAssertGreaterThan(Int32(sample.z), 16000)
    }

    func testDemoDataGeneratorAccelerometerMotion() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .motion)

        // Motion should produce non-trivial accelerometer readings
        XCTAssertNotEqual(sample.x, 0)
    }

    func testDemoDataGeneratorHeartRate() async {
        let config = DemoDataConfiguration(heartRateRange: 60...100)
        let generator = DemoDataGenerator(configuration: config)

        let hr = await generator.generateHeartRate()

        XCTAssertGreaterThanOrEqual(hr, 60)
        XCTAssertLessThanOrEqual(hr, 100)
    }

    func testDemoDataGeneratorSpO2() async {
        let config = DemoDataConfiguration(spo2Range: 95...100)
        let generator = DemoDataGenerator(configuration: config)

        let spo2 = await generator.generateSpO2()

        XCTAssertGreaterThanOrEqual(spo2, 95)
        XCTAssertLessThanOrEqual(spo2, 100)
    }

    func testDemoDataGeneratorTemperature() async {
        let config = DemoDataConfiguration(temperatureRange: 36.0...38.0)
        let generator = DemoDataGenerator(configuration: config)

        let temp = await generator.generateTemperature()

        XCTAssertGreaterThanOrEqual(temp, 36.0)
        XCTAssertLessThanOrEqual(temp, 38.0)
    }

    func testDemoDataGeneratorBatteryDrain() async {
        let generator = DemoDataGenerator(configuration: .init(initialBattery: 100))

        let initial = await generator.batteryLevel
        XCTAssertEqual(initial, 100)

        // Generate with 1% drain
        _ = await generator.generateBatteryLevel(drain: 1)
        let after = await generator.batteryLevel
        XCTAssertEqual(after, 99)
    }

    func testDemoDataGeneratorSensorData() async {
        let generator = DemoDataGenerator()

        let sensorData = await generator.generateSensorData()

        XCTAssertNotNil(sensorData.heartRate)
        XCTAssertNotNil(sensorData.spo2)
        XCTAssertGreaterThan(sensorData.ppg.ir, 0)
        XCTAssertGreaterThan(sensorData.temperature.celsius, 35)
    }

    func testDemoDataGeneratorSensorDataSequence() async {
        let generator = DemoDataGenerator()

        let sequence = await generator.generateSensorDataSequence(count: 10, interval: 1.0)

        XCTAssertEqual(sequence.count, 10)

        // Verify timestamps are sequential
        for i in 1..<sequence.count {
            XCTAssertGreaterThan(sequence[i].timestamp, sequence[i-1].timestamp)
        }
    }

    func testDemoDataGeneratorReset() async {
        let generator = DemoDataGenerator(configuration: .init(initialBattery: 100))

        // Use some resources
        _ = await generator.generatePPGSample()
        _ = await generator.generateBatteryLevel(drain: 10)

        let indexBefore = await generator.currentSampleIndex
        let batteryBefore = await generator.batteryLevel

        XCTAssertGreaterThan(indexBefore, 0)
        XCTAssertLessThan(batteryBefore, 100)

        // Reset
        await generator.reset()

        let indexAfter = await generator.currentSampleIndex
        let batteryAfter = await generator.batteryLevel

        XCTAssertEqual(indexAfter, 0)
        XCTAssertEqual(batteryAfter, 100)
    }

    func testDemoDataGeneratorSyncVersion() {
        let generator = DemoDataGeneratorSync()

        let ppg = generator.generatePPGSample(at: 0)
        XCTAssertGreaterThan(ppg.ir, 0)

        let accel = generator.generateAccelerometerAtRest()
        XCTAssertGreaterThan(accel.z, 16000)

        let sensorData = generator.generateDefaultSensorData()
        XCTAssertNotNil(sensorData.heartRate)
    }

    // MARK: - ProcessingResult Tests

    func testProcessingResultCreation() {
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.9
        )

        XCTAssertEqual(result.heartRate, 72)
        XCTAssertEqual(result.spo2, 98)
        XCTAssertEqual(result.activity, .relaxed)
        XCTAssertEqual(result.signalQuality, 0.9)
        XCTAssertTrue(result.isValid)
    }

    func testProcessingResultMotionArtifact() {
        let result = ProcessingResult.motionArtifact()

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.signalQuality, 0)
        XCTAssertFalse(result.isValid)
    }

    func testProcessingResultInsufficientData() {
        let result = ProcessingResult.insufficientData()

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertFalse(result.isValid)
    }

    func testProcessingResultValidation() {
        let valid = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed, signalQuality: 0.8)
        XCTAssertTrue(valid.hasValidHeartRate)
        XCTAssertTrue(valid.hasValidSpO2)

        let invalidHR = ProcessingResult(heartRate: 30, spo2: 98, activity: .relaxed, signalQuality: 0.8)
        XCTAssertFalse(invalidHR.hasValidHeartRate)

        let invalidSpO2 = ProcessingResult(heartRate: 72, spo2: 60, activity: .relaxed, signalQuality: 0.8)
        XCTAssertFalse(invalidSpO2.hasValidSpO2)

        let motion = ProcessingResult(heartRate: 72, spo2: 98, activity: .motion, signalQuality: 0.8)
        XCTAssertTrue(motion.hasExcessiveMotion)
    }

    func testProcessingState() {
        XCTAssertFalse(ProcessingState.idle.isActive)
        XCTAssertFalse(ProcessingState.warmingUp.isActive)
        XCTAssertTrue(ProcessingState.processing.isActive)
        XCTAssertTrue(ProcessingState.ready.isActive)

        XCTAssertTrue(ProcessingState.pausedForMotion.isPaused)
        XCTAssertTrue(ProcessingState.pausedForSignal.isPaused)
        XCTAssertFalse(ProcessingState.processing.isPaused)
    }

    func testProcessingQualityMetrics() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.85,
            ppgQuality: 0.9,
            motionArtifactLevel: 0.1,
            estimatedSNR: 20.0,
            peakCount: 5,
            hrvMs: 45.0
        )

        XCTAssertEqual(metrics.qualityLevel, .excellent)
        XCTAssertTrue(metrics.isClinicalQuality)

        let empty = ProcessingQualityMetrics.empty
        XCTAssertEqual(empty.qualityLevel, .poor)
        XCTAssertFalse(empty.isClinicalQuality)
    }

    func testProcessingConfiguration() {
        let consumer = ProcessingConfiguration.consumer
        XCTAssertEqual(consumer.ppgBufferSize, 100)

        let clinical = ProcessingConfiguration.clinical
        XCTAssertEqual(clinical.ppgBufferSize, 200)
        XCTAssertEqual(clinical.qualityThreshold, 0.7)

        let responsive = ProcessingConfiguration.responsive
        XCTAssertEqual(responsive.ppgBufferSize, 50)

        let demo = ProcessingConfiguration.demo
        XCTAssertEqual(demo.ppgBufferSize, 20)
    }

    // MARK: - ExtendedProcessingResult Tests

    func testExtendedProcessingResultCreation() {
        let baseResult = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.85
        )

        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.9,
            spo2Confidence: 0.85,
            motionMagnitude: 1.1,
            sampleCount: 250,
            processingTimeMs: 15.5
        )

        XCTAssertEqual(extended.heartRate, 72)
        XCTAssertEqual(extended.spo2, 98)
        XCTAssertEqual(extended.activity, .relaxed)
        XCTAssertEqual(extended.heartRateConfidence, 0.9)
        XCTAssertEqual(extended.spo2Confidence, 0.85)
        XCTAssertEqual(extended.motionMagnitude, 1.1)
        XCTAssertEqual(extended.sampleCount, 250)
        XCTAssertEqual(extended.processingTimeMs, 15.5)
    }

    func testExtendedProcessingResultOverallConfidence() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)

        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.8,
            spo2Confidence: 0.6,
            motionMagnitude: 1.0,
            sampleCount: 100,
            processingTimeMs: 10.0
        )

        XCTAssertEqual(extended.overallConfidence, 0.7, accuracy: 0.01)
    }

    func testExtendedProcessingResultIsStable() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)

        let stable = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.9,
            spo2Confidence: 0.9,
            motionMagnitude: 1.2,  // Below 1.5g threshold
            sampleCount: 100,
            processingTimeMs: 10.0
        )
        XCTAssertTrue(stable.isStable)

        let unstable = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.9,
            spo2Confidence: 0.9,
            motionMagnitude: 2.0,  // Above 1.5g threshold
            sampleCount: 100,
            processingTimeMs: 10.0
        )
        XCTAssertFalse(unstable.isStable)
    }

    func testExtendedProcessingResultConfidenceClamping() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)

        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 1.5,  // Should clamp to 1.0
            spo2Confidence: -0.5,      // Should clamp to 0.0
            motionMagnitude: 1.0,
            sampleCount: 100,
            processingTimeMs: 10.0
        )

        XCTAssertEqual(extended.heartRateConfidence, 1.0)
        XCTAssertEqual(extended.spo2Confidence, 0.0)
    }

    // MARK: - ProcessingQualityMetrics Extended Tests

    func testProcessingQualityMetricsQualityLevels() {
        // Excellent
        let excellent = ProcessingQualityMetrics(
            overallQuality: 0.85,
            ppgQuality: 0.9,
            motionArtifactLevel: 0.1,
            estimatedSNR: 25.0,
            peakCount: 5
        )
        XCTAssertEqual(excellent.qualityLevel, .excellent)

        // Good
        let good = ProcessingQualityMetrics(
            overallQuality: 0.65,
            ppgQuality: 0.7,
            motionArtifactLevel: 0.2,
            estimatedSNR: 18.0,
            peakCount: 4
        )
        XCTAssertEqual(good.qualityLevel, .good)

        // Fair
        let fair = ProcessingQualityMetrics(
            overallQuality: 0.45,
            ppgQuality: 0.5,
            motionArtifactLevel: 0.4,
            estimatedSNR: 12.0,
            peakCount: 3
        )
        XCTAssertEqual(fair.qualityLevel, .fair)

        // Acceptable
        let acceptable = ProcessingQualityMetrics(
            overallQuality: 0.25,
            ppgQuality: 0.3,
            motionArtifactLevel: 0.6,
            estimatedSNR: 8.0,
            peakCount: 2
        )
        XCTAssertEqual(acceptable.qualityLevel, .acceptable)

        // Poor
        let poor = ProcessingQualityMetrics(
            overallQuality: 0.1,
            ppgQuality: 0.1,
            motionArtifactLevel: 0.9,
            estimatedSNR: 3.0,
            peakCount: 1
        )
        XCTAssertEqual(poor.qualityLevel, .poor)
    }

    func testProcessingQualityMetricsClinicalQuality() {
        // Clinical quality requires overallQuality >= 0.7 AND motionArtifactLevel < 0.3
        let clinical = ProcessingQualityMetrics(
            overallQuality: 0.75,
            ppgQuality: 0.8,
            motionArtifactLevel: 0.2,
            estimatedSNR: 20.0,
            peakCount: 5
        )
        XCTAssertTrue(clinical.isClinicalQuality)

        // High quality but too much motion
        let tooMuchMotion = ProcessingQualityMetrics(
            overallQuality: 0.8,
            ppgQuality: 0.85,
            motionArtifactLevel: 0.4,  // Too high
            estimatedSNR: 22.0,
            peakCount: 5
        )
        XCTAssertFalse(tooMuchMotion.isClinicalQuality)

        // Low motion but low quality
        let lowQuality = ProcessingQualityMetrics(
            overallQuality: 0.5,  // Too low
            ppgQuality: 0.6,
            motionArtifactLevel: 0.1,
            estimatedSNR: 15.0,
            peakCount: 3
        )
        XCTAssertFalse(lowQuality.isClinicalQuality)
    }

    func testProcessingQualityMetricsValueClamping() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 1.5,       // Should clamp to 1.0
            ppgQuality: -0.5,          // Should clamp to 0.0
            motionArtifactLevel: 2.0,  // Should clamp to 1.0
            estimatedSNR: 25.0,
            peakCount: 5
        )

        XCTAssertEqual(metrics.overallQuality, 1.0)
        XCTAssertEqual(metrics.ppgQuality, 0.0)
        XCTAssertEqual(metrics.motionArtifactLevel, 1.0)
    }

    func testProcessingQualityMetricsWithHRV() {
        let withHRV = ProcessingQualityMetrics(
            overallQuality: 0.85,
            ppgQuality: 0.9,
            motionArtifactLevel: 0.1,
            estimatedSNR: 25.0,
            peakCount: 8,
            hrvMs: 45.0
        )
        XCTAssertEqual(withHRV.hrvMs, 45.0)

        let withoutHRV = ProcessingQualityMetrics.empty
        XCTAssertNil(withoutHRV.hrvMs)
    }

    // MARK: - ProcessingState Extended Tests

    func testProcessingStateAllCases() {
        for state in ProcessingState.allCases {
            XCTAssertFalse(state.rawValue.isEmpty)
        }
    }

    func testProcessingStateRawValues() {
        XCTAssertEqual(ProcessingState.idle.rawValue, "Idle")
        XCTAssertEqual(ProcessingState.warmingUp.rawValue, "Warming Up")
        XCTAssertEqual(ProcessingState.processing.rawValue, "Processing")
        XCTAssertEqual(ProcessingState.pausedForMotion.rawValue, "Paused - Motion")
        XCTAssertEqual(ProcessingState.pausedForSignal.rawValue, "Paused - Poor Signal")
        XCTAssertEqual(ProcessingState.ready.rawValue, "Ready")
        XCTAssertEqual(ProcessingState.error.rawValue, "Error")
    }

    // MARK: - ProcessingConfiguration Extended Tests

    func testProcessingConfigurationCustom() {
        let custom = ProcessingConfiguration(
            ppgBufferSize: 150,
            accelerometerBufferSize: 75,
            minimumSamples: 75,
            motionThreshold: 1.8,
            qualityThreshold: 0.6,
            updateInterval: 1.5
        )

        XCTAssertEqual(custom.ppgBufferSize, 150)
        XCTAssertEqual(custom.accelerometerBufferSize, 75)
        XCTAssertEqual(custom.minimumSamples, 75)
        XCTAssertEqual(custom.motionThreshold, 1.8)
        XCTAssertEqual(custom.qualityThreshold, 0.6)
        XCTAssertEqual(custom.updateInterval, 1.5)
    }

    func testProcessingConfigurationPresetDifferences() {
        let consumer = ProcessingConfiguration.consumer
        let clinical = ProcessingConfiguration.clinical
        let responsive = ProcessingConfiguration.responsive
        let demo = ProcessingConfiguration.demo

        // Clinical should have stricter thresholds
        XCTAssertGreaterThan(clinical.qualityThreshold, consumer.qualityThreshold)
        XCTAssertLessThan(clinical.motionThreshold, consumer.motionThreshold)

        // Responsive should be faster
        XCTAssertLessThan(responsive.updateInterval, consumer.updateInterval)
        XCTAssertLessThan(responsive.minimumSamples, consumer.minimumSamples)

        // Demo should be fastest with lowest thresholds
        XCTAssertLessThan(demo.qualityThreshold, responsive.qualityThreshold)
        XCTAssertGreaterThan(demo.motionThreshold, responsive.motionThreshold)
    }
}
