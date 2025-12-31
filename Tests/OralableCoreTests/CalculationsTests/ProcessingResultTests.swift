//
//  ProcessingResultTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for ProcessingResult and related types
//

import XCTest
@testable import OralableCore

// MARK: - ProcessingResult Tests

final class ProcessingResultTests: XCTestCase {

    // MARK: - Initialization Tests

    func testProcessingResultCreation() {
        let timestamp = Date()
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.85,
            timestamp: timestamp
        )

        XCTAssertEqual(result.heartRate, 72)
        XCTAssertEqual(result.spo2, 98)
        XCTAssertEqual(result.activity, .relaxed)
        XCTAssertEqual(result.signalQuality, 0.85)
        XCTAssertEqual(result.timestamp, timestamp)
    }

    func testProcessingResultDefaultValues() {
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed
        )

        XCTAssertEqual(result.signalQuality, 1.0)
        XCTAssertNotNil(result.timestamp)
    }

    func testSignalQualityClamping() {
        // Over 1.0
        let overResult = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 1.5
        )
        XCTAssertEqual(overResult.signalQuality, 1.0)

        // Under 0.0
        let underResult = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: -0.5
        )
        XCTAssertEqual(underResult.signalQuality, 0.0)
    }

    // MARK: - Factory Method Tests

    func testMotionArtifactFactory() {
        let result = ProcessingResult.motionArtifact()

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.activity, .motion)
        XCTAssertEqual(result.signalQuality, 0.0)
    }

    func testMotionArtifactWithCustomActivity() {
        let result = ProcessingResult.motionArtifact(activity: .grinding)

        XCTAssertEqual(result.activity, .grinding)
    }

    func testInsufficientDataFactory() {
        let result = ProcessingResult.insufficientData()

        XCTAssertEqual(result.heartRate, 0)
        XCTAssertEqual(result.spo2, 0)
        XCTAssertEqual(result.activity, .relaxed)
        XCTAssertEqual(result.signalQuality, 0.0)
    }

    // MARK: - Validation Tests

    func testIsValidTrue() {
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.8
        )

        XCTAssertTrue(result.isValid)
    }

    func testIsValidFalseZeroHR() {
        let result = ProcessingResult(
            heartRate: 0,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.8
        )

        XCTAssertFalse(result.isValid)
    }

    func testIsValidFalseZeroSpO2() {
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 0,
            activity: .relaxed,
            signalQuality: 0.8
        )

        XCTAssertFalse(result.isValid)
    }

    func testIsValidFalseLowQuality() {
        let result = ProcessingResult(
            heartRate: 72,
            spo2: 98,
            activity: .relaxed,
            signalQuality: 0.4
        )

        XCTAssertFalse(result.isValid)
    }

    func testHasValidHeartRate() {
        XCTAssertTrue(ProcessingResult(heartRate: 40, spo2: 98, activity: .relaxed).hasValidHeartRate)
        XCTAssertTrue(ProcessingResult(heartRate: 200, spo2: 98, activity: .relaxed).hasValidHeartRate)
        XCTAssertTrue(ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed).hasValidHeartRate)

        XCTAssertFalse(ProcessingResult(heartRate: 39, spo2: 98, activity: .relaxed).hasValidHeartRate)
        XCTAssertFalse(ProcessingResult(heartRate: 201, spo2: 98, activity: .relaxed).hasValidHeartRate)
    }

    func testHasValidSpO2() {
        XCTAssertTrue(ProcessingResult(heartRate: 72, spo2: 70, activity: .relaxed).hasValidSpO2)
        XCTAssertTrue(ProcessingResult(heartRate: 72, spo2: 100, activity: .relaxed).hasValidSpO2)
        XCTAssertTrue(ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed).hasValidSpO2)

        XCTAssertFalse(ProcessingResult(heartRate: 72, spo2: 69, activity: .relaxed).hasValidSpO2)
        XCTAssertFalse(ProcessingResult(heartRate: 72, spo2: 101, activity: .relaxed).hasValidSpO2)
    }

    func testHasExcessiveMotion() {
        XCTAssertTrue(ProcessingResult(heartRate: 0, spo2: 0, activity: .motion).hasExcessiveMotion)
        XCTAssertFalse(ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed).hasExcessiveMotion)
        XCTAssertFalse(ProcessingResult(heartRate: 72, spo2: 98, activity: .clenching).hasExcessiveMotion)
        XCTAssertFalse(ProcessingResult(heartRate: 72, spo2: 98, activity: .grinding).hasExcessiveMotion)
    }

    // MARK: - Equatable Tests

    func testEquatableSameValues() {
        let timestamp = Date()
        let result1 = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed, signalQuality: 0.8, timestamp: timestamp)
        let result2 = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed, signalQuality: 0.8, timestamp: timestamp)

        XCTAssertEqual(result1, result2)
    }

    func testEquatableDifferentValues() {
        let timestamp = Date()
        let result1 = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed, signalQuality: 0.8, timestamp: timestamp)
        let result2 = ProcessingResult(heartRate: 80, spo2: 98, activity: .relaxed, signalQuality: 0.8, timestamp: timestamp)

        XCTAssertNotEqual(result1, result2)
    }
}

// MARK: - ExtendedProcessingResult Tests

final class ExtendedProcessingResultTests: XCTestCase {

    func testExtendedProcessingResultCreation() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)
        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.85,
            spo2Confidence: 0.9,
            motionMagnitude: 1.05,
            sampleCount: 150,
            processingTimeMs: 12.5
        )

        XCTAssertEqual(extended.result.heartRate, 72)
        XCTAssertEqual(extended.heartRateConfidence, 0.85)
        XCTAssertEqual(extended.spo2Confidence, 0.9)
        XCTAssertEqual(extended.motionMagnitude, 1.05)
        XCTAssertEqual(extended.sampleCount, 150)
        XCTAssertEqual(extended.processingTimeMs, 12.5)
    }

    func testConfidenceClamping() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)

        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 1.5,
            spo2Confidence: -0.5,
            motionMagnitude: 1.0,
            sampleCount: 100,
            processingTimeMs: 10.0
        )

        XCTAssertEqual(extended.heartRateConfidence, 1.0)
        XCTAssertEqual(extended.spo2Confidence, 0.0)
    }

    func testConvenienceProperties() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .grinding)
        let extended = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.8,
            spo2Confidence: 0.9,
            motionMagnitude: 1.0,
            sampleCount: 100,
            processingTimeMs: 10.0
        )

        XCTAssertEqual(extended.heartRate, 72)
        XCTAssertEqual(extended.spo2, 98)
        XCTAssertEqual(extended.activity, .grinding)
    }

    func testOverallConfidence() {
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

    func testIsStable() {
        let baseResult = ProcessingResult(heartRate: 72, spo2: 98, activity: .relaxed)

        let stable = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.8,
            spo2Confidence: 0.9,
            motionMagnitude: 1.2,
            sampleCount: 100,
            processingTimeMs: 10.0
        )
        XCTAssertTrue(stable.isStable)

        let unstable = ExtendedProcessingResult(
            result: baseResult,
            heartRateConfidence: 0.8,
            spo2Confidence: 0.9,
            motionMagnitude: 2.0,
            sampleCount: 100,
            processingTimeMs: 10.0
        )
        XCTAssertFalse(unstable.isStable)
    }
}

// MARK: - ProcessingState Tests

final class ProcessingStateTests: XCTestCase {

    func testProcessingStateRawValues() {
        XCTAssertEqual(ProcessingState.idle.rawValue, "Idle")
        XCTAssertEqual(ProcessingState.warmingUp.rawValue, "Warming Up")
        XCTAssertEqual(ProcessingState.processing.rawValue, "Processing")
        XCTAssertEqual(ProcessingState.pausedForMotion.rawValue, "Paused - Motion")
        XCTAssertEqual(ProcessingState.pausedForSignal.rawValue, "Paused - Poor Signal")
        XCTAssertEqual(ProcessingState.ready.rawValue, "Ready")
        XCTAssertEqual(ProcessingState.error.rawValue, "Error")
    }

    func testProcessingStateAllCases() {
        XCTAssertEqual(ProcessingState.allCases.count, 7)
    }

    func testIsActive() {
        XCTAssertTrue(ProcessingState.processing.isActive)
        XCTAssertTrue(ProcessingState.ready.isActive)

        XCTAssertFalse(ProcessingState.idle.isActive)
        XCTAssertFalse(ProcessingState.warmingUp.isActive)
        XCTAssertFalse(ProcessingState.pausedForMotion.isActive)
        XCTAssertFalse(ProcessingState.pausedForSignal.isActive)
        XCTAssertFalse(ProcessingState.error.isActive)
    }

    func testIsPaused() {
        XCTAssertTrue(ProcessingState.pausedForMotion.isPaused)
        XCTAssertTrue(ProcessingState.pausedForSignal.isPaused)

        XCTAssertFalse(ProcessingState.idle.isPaused)
        XCTAssertFalse(ProcessingState.warmingUp.isPaused)
        XCTAssertFalse(ProcessingState.processing.isPaused)
        XCTAssertFalse(ProcessingState.ready.isPaused)
        XCTAssertFalse(ProcessingState.error.isPaused)
    }
}

// MARK: - ProcessingQualityMetrics Tests

final class ProcessingQualityMetricsTests: XCTestCase {

    func testProcessingQualityMetricsCreation() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.85,
            ppgQuality: 0.9,
            motionArtifactLevel: 0.1,
            estimatedSNR: 25.0,
            peakCount: 12,
            hrvMs: 45.0
        )

        XCTAssertEqual(metrics.overallQuality, 0.85)
        XCTAssertEqual(metrics.ppgQuality, 0.9)
        XCTAssertEqual(metrics.motionArtifactLevel, 0.1)
        XCTAssertEqual(metrics.estimatedSNR, 25.0)
        XCTAssertEqual(metrics.peakCount, 12)
        XCTAssertEqual(metrics.hrvMs, 45.0)
    }

    func testQualityClamping() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 1.5,
            ppgQuality: -0.5,
            motionArtifactLevel: 2.0,
            estimatedSNR: 25.0,
            peakCount: 10
        )

        XCTAssertEqual(metrics.overallQuality, 1.0)
        XCTAssertEqual(metrics.ppgQuality, 0.0)
        XCTAssertEqual(metrics.motionArtifactLevel, 1.0)
    }

    func testEmptyFactory() {
        let empty = ProcessingQualityMetrics.empty

        XCTAssertEqual(empty.overallQuality, 0.0)
        XCTAssertEqual(empty.ppgQuality, 0.0)
        XCTAssertEqual(empty.motionArtifactLevel, 1.0)
        XCTAssertEqual(empty.estimatedSNR, 0.0)
        XCTAssertEqual(empty.peakCount, 0)
        XCTAssertNil(empty.hrvMs)
    }

    func testQualityLevelExcellent() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.9,
            ppgQuality: 0.95,
            motionArtifactLevel: 0.05,
            estimatedSNR: 30.0,
            peakCount: 15
        )

        XCTAssertEqual(metrics.qualityLevel, .excellent)
    }

    func testQualityLevelGood() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.7,
            ppgQuality: 0.75,
            motionArtifactLevel: 0.15,
            estimatedSNR: 20.0,
            peakCount: 10
        )

        XCTAssertEqual(metrics.qualityLevel, .good)
    }

    func testQualityLevelFair() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.5,
            ppgQuality: 0.55,
            motionArtifactLevel: 0.3,
            estimatedSNR: 15.0,
            peakCount: 8
        )

        XCTAssertEqual(metrics.qualityLevel, .fair)
    }

    func testQualityLevelAcceptable() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.3,
            ppgQuality: 0.35,
            motionArtifactLevel: 0.5,
            estimatedSNR: 10.0,
            peakCount: 5
        )

        XCTAssertEqual(metrics.qualityLevel, .acceptable)
    }

    func testQualityLevelPoor() {
        let metrics = ProcessingQualityMetrics(
            overallQuality: 0.1,
            ppgQuality: 0.1,
            motionArtifactLevel: 0.8,
            estimatedSNR: 5.0,
            peakCount: 2
        )

        XCTAssertEqual(metrics.qualityLevel, .poor)
    }

    func testIsClinicalQuality() {
        let clinical = ProcessingQualityMetrics(
            overallQuality: 0.8,
            ppgQuality: 0.85,
            motionArtifactLevel: 0.2,
            estimatedSNR: 25.0,
            peakCount: 12
        )
        XCTAssertTrue(clinical.isClinicalQuality)

        let notClinicalLowQuality = ProcessingQualityMetrics(
            overallQuality: 0.5,
            ppgQuality: 0.6,
            motionArtifactLevel: 0.2,
            estimatedSNR: 15.0,
            peakCount: 8
        )
        XCTAssertFalse(notClinicalLowQuality.isClinicalQuality)

        let notClinicalHighMotion = ProcessingQualityMetrics(
            overallQuality: 0.8,
            ppgQuality: 0.85,
            motionArtifactLevel: 0.5,
            estimatedSNR: 25.0,
            peakCount: 12
        )
        XCTAssertFalse(notClinicalHighMotion.isClinicalQuality)
    }
}

// MARK: - ProcessingConfiguration Tests

final class ProcessingConfigurationTests: XCTestCase {

    func testProcessingConfigurationCreation() {
        let config = ProcessingConfiguration(
            ppgBufferSize: 150,
            accelerometerBufferSize: 75,
            minimumSamples: 60,
            motionThreshold: 1.8,
            qualityThreshold: 0.6,
            updateInterval: 0.75
        )

        XCTAssertEqual(config.ppgBufferSize, 150)
        XCTAssertEqual(config.accelerometerBufferSize, 75)
        XCTAssertEqual(config.minimumSamples, 60)
        XCTAssertEqual(config.motionThreshold, 1.8)
        XCTAssertEqual(config.qualityThreshold, 0.6)
        XCTAssertEqual(config.updateInterval, 0.75)
    }

    func testDefaultValues() {
        let config = ProcessingConfiguration()

        XCTAssertEqual(config.ppgBufferSize, 100)
        XCTAssertEqual(config.accelerometerBufferSize, 50)
        XCTAssertEqual(config.minimumSamples, 50)
        XCTAssertEqual(config.motionThreshold, 1.5)
        XCTAssertEqual(config.qualityThreshold, 0.5)
        XCTAssertEqual(config.updateInterval, 1.0)
    }

    func testConsumerPreset() {
        let config = ProcessingConfiguration.consumer

        XCTAssertEqual(config.ppgBufferSize, 100)
        XCTAssertEqual(config.accelerometerBufferSize, 50)
        XCTAssertEqual(config.minimumSamples, 50)
        XCTAssertEqual(config.motionThreshold, 1.5)
        XCTAssertEqual(config.qualityThreshold, 0.5)
        XCTAssertEqual(config.updateInterval, 1.0)
    }

    func testClinicalPreset() {
        let config = ProcessingConfiguration.clinical

        XCTAssertEqual(config.ppgBufferSize, 200)
        XCTAssertEqual(config.accelerometerBufferSize, 100)
        XCTAssertEqual(config.minimumSamples, 100)
        XCTAssertEqual(config.motionThreshold, 1.2)
        XCTAssertEqual(config.qualityThreshold, 0.7)
        XCTAssertEqual(config.updateInterval, 2.0)
    }

    func testResponsivePreset() {
        let config = ProcessingConfiguration.responsive

        XCTAssertEqual(config.ppgBufferSize, 50)
        XCTAssertEqual(config.accelerometerBufferSize, 25)
        XCTAssertEqual(config.minimumSamples, 25)
        XCTAssertEqual(config.motionThreshold, 2.0)
        XCTAssertEqual(config.qualityThreshold, 0.4)
        XCTAssertEqual(config.updateInterval, 0.5)
    }

    func testDemoPreset() {
        let config = ProcessingConfiguration.demo

        XCTAssertEqual(config.ppgBufferSize, 20)
        XCTAssertEqual(config.accelerometerBufferSize, 10)
        XCTAssertEqual(config.minimumSamples, 10)
        XCTAssertEqual(config.motionThreshold, 3.0)
        XCTAssertEqual(config.qualityThreshold, 0.3)
        XCTAssertEqual(config.updateInterval, 0.25)
    }

    func testClinicalHasStricterThresholds() {
        let clinical = ProcessingConfiguration.clinical
        let consumer = ProcessingConfiguration.consumer

        // Clinical should have stricter motion threshold (lower)
        XCTAssertLessThan(clinical.motionThreshold, consumer.motionThreshold)

        // Clinical should have higher quality threshold
        XCTAssertGreaterThan(clinical.qualityThreshold, consumer.qualityThreshold)

        // Clinical should have larger buffers
        XCTAssertGreaterThan(clinical.ppgBufferSize, consumer.ppgBufferSize)
        XCTAssertGreaterThan(clinical.minimumSamples, consumer.minimumSamples)
    }

    func testResponsiveHasLowestLatency() {
        let responsive = ProcessingConfiguration.responsive
        let consumer = ProcessingConfiguration.consumer
        let clinical = ProcessingConfiguration.clinical

        XCTAssertLessThan(responsive.updateInterval, consumer.updateInterval)
        XCTAssertLessThan(responsive.updateInterval, clinical.updateInterval)
    }
}
