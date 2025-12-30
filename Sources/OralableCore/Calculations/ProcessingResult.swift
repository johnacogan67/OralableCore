//
//  ProcessingResult.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Signal processing result types for biometric calculations
//

import Foundation

// MARK: - Processing Result

/// Result of a signal processing frame
/// Contains calculated biometrics from raw sensor data
public struct ProcessingResult: Sendable, Equatable {

    /// Calculated heart rate in beats per minute
    /// Zero indicates insufficient data or motion artifact
    public let heartRate: Int

    /// Calculated blood oxygen saturation percentage (SpO2)
    /// Zero indicates insufficient data or motion artifact
    public let spo2: Int

    /// Detected activity type based on motion analysis
    public let activity: ActivityType

    /// Signal quality indicator (0.0 - 1.0)
    public let signalQuality: Double

    /// Timestamp of the calculation
    public let timestamp: Date

    // MARK: - Initialization

    public init(
        heartRate: Int,
        spo2: Int,
        activity: ActivityType,
        signalQuality: Double = 1.0,
        timestamp: Date = Date()
    ) {
        self.heartRate = heartRate
        self.spo2 = spo2
        self.activity = activity
        self.signalQuality = min(1.0, max(0.0, signalQuality))
        self.timestamp = timestamp
    }

    // MARK: - Factory Methods

    /// Create result indicating motion artifact (unreliable data)
    public static func motionArtifact(activity: ActivityType = .motion) -> ProcessingResult {
        ProcessingResult(
            heartRate: 0,
            spo2: 0,
            activity: activity,
            signalQuality: 0.0
        )
    }

    /// Create result indicating insufficient data
    public static func insufficientData() -> ProcessingResult {
        ProcessingResult(
            heartRate: 0,
            spo2: 0,
            activity: .relaxed,
            signalQuality: 0.0
        )
    }

    // MARK: - Validation

    /// Whether the result contains valid biometric data
    public var isValid: Bool {
        heartRate > 0 && spo2 > 0 && signalQuality > 0.5
    }

    /// Whether the heart rate is within physiological range
    public var hasValidHeartRate: Bool {
        heartRate >= 40 && heartRate <= 200
    }

    /// Whether the SpO2 is within physiological range
    public var hasValidSpO2: Bool {
        spo2 >= 70 && spo2 <= 100
    }

    /// Whether motion is excessive for reliable measurement
    public var hasExcessiveMotion: Bool {
        activity == .motion
    }
}

// MARK: - Extended Processing Result

/// Extended processing result with additional diagnostic information
public struct ExtendedProcessingResult: Sendable {

    /// Basic processing result
    public let result: ProcessingResult

    /// Raw heart rate confidence (0.0 - 1.0)
    public let heartRateConfidence: Double

    /// Raw SpO2 confidence (0.0 - 1.0)
    public let spo2Confidence: Double

    /// Motion magnitude during calculation (in g)
    public let motionMagnitude: Double

    /// Number of samples used in calculation
    public let sampleCount: Int

    /// Processing time in milliseconds
    public let processingTimeMs: Double

    // MARK: - Initialization

    public init(
        result: ProcessingResult,
        heartRateConfidence: Double,
        spo2Confidence: Double,
        motionMagnitude: Double,
        sampleCount: Int,
        processingTimeMs: Double
    ) {
        self.result = result
        self.heartRateConfidence = min(1.0, max(0.0, heartRateConfidence))
        self.spo2Confidence = min(1.0, max(0.0, spo2Confidence))
        self.motionMagnitude = motionMagnitude
        self.sampleCount = sampleCount
        self.processingTimeMs = processingTimeMs
    }

    // MARK: - Convenience Properties

    /// Heart rate from the basic result
    public var heartRate: Int { result.heartRate }

    /// SpO2 from the basic result
    public var spo2: Int { result.spo2 }

    /// Activity from the basic result
    public var activity: ActivityType { result.activity }

    /// Combined confidence score
    public var overallConfidence: Double {
        (heartRateConfidence + spo2Confidence) / 2.0
    }

    /// Whether motion magnitude indicates device is stable
    public var isStable: Bool {
        motionMagnitude < 1.5  // Less than 1.5g total motion
    }
}

// MARK: - Processing State

/// State of the signal processing pipeline
public enum ProcessingState: String, Sendable, CaseIterable {
    /// Pipeline is idle, waiting for data
    case idle = "Idle"

    /// Pipeline is warming up, collecting initial samples
    case warmingUp = "Warming Up"

    /// Pipeline is actively processing data
    case processing = "Processing"

    /// Pipeline has paused due to motion
    case pausedForMotion = "Paused - Motion"

    /// Pipeline has paused due to poor signal quality
    case pausedForSignal = "Paused - Poor Signal"

    /// Pipeline is ready with stable readings
    case ready = "Ready"

    /// Pipeline has encountered an error
    case error = "Error"

    /// Whether the pipeline is actively producing results
    public var isActive: Bool {
        switch self {
        case .processing, .ready:
            return true
        default:
            return false
        }
    }

    /// Whether the pipeline is in a paused state
    public var isPaused: Bool {
        switch self {
        case .pausedForMotion, .pausedForSignal:
            return true
        default:
            return false
        }
    }
}

// MARK: - Quality Metrics

/// Quality metrics for processed biometric data
public struct ProcessingQualityMetrics: Sendable {

    /// Overall quality score (0.0 - 1.0)
    public let overallQuality: Double

    /// PPG signal quality (0.0 - 1.0)
    public let ppgQuality: Double

    /// Motion artifact level (0.0 - 1.0, lower is better)
    public let motionArtifactLevel: Double

    /// Signal-to-noise ratio estimate (dB)
    public let estimatedSNR: Double

    /// Number of valid peaks detected in analysis window
    public let peakCount: Int

    /// Calculated heart rate variability (if available)
    public let hrvMs: Double?

    // MARK: - Initialization

    public init(
        overallQuality: Double,
        ppgQuality: Double,
        motionArtifactLevel: Double,
        estimatedSNR: Double,
        peakCount: Int,
        hrvMs: Double? = nil
    ) {
        self.overallQuality = min(1.0, max(0.0, overallQuality))
        self.ppgQuality = min(1.0, max(0.0, ppgQuality))
        self.motionArtifactLevel = min(1.0, max(0.0, motionArtifactLevel))
        self.estimatedSNR = estimatedSNR
        self.peakCount = peakCount
        self.hrvMs = hrvMs
    }

    // MARK: - Factory Methods

    /// Create default quality metrics (no data)
    public static var empty: ProcessingQualityMetrics {
        ProcessingQualityMetrics(
            overallQuality: 0.0,
            ppgQuality: 0.0,
            motionArtifactLevel: 1.0,
            estimatedSNR: 0.0,
            peakCount: 0
        )
    }

    // MARK: - Quality Assessment

    /// Quality level enumeration
    public var qualityLevel: QualityLevel {
        switch overallQuality {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        case 0.2..<0.4:
            return .acceptable
        default:
            return .poor
        }
    }

    /// Whether quality is sufficient for clinical use
    public var isClinicalQuality: Bool {
        overallQuality >= 0.7 && motionArtifactLevel < 0.3
    }
}

// MARK: - Processing Pipeline Configuration

/// Configuration for signal processing pipeline
public struct ProcessingConfiguration: Sendable {

    /// Buffer size for PPG samples (number of samples)
    public let ppgBufferSize: Int

    /// Buffer size for accelerometer samples
    public let accelerometerBufferSize: Int

    /// Minimum samples required before producing results
    public let minimumSamples: Int

    /// Motion threshold for pausing calculation (in g)
    public let motionThreshold: Double

    /// Signal quality threshold for valid results
    public let qualityThreshold: Double

    /// Update interval for results (in seconds)
    public let updateInterval: TimeInterval

    // MARK: - Initialization

    public init(
        ppgBufferSize: Int = 100,
        accelerometerBufferSize: Int = 50,
        minimumSamples: Int = 50,
        motionThreshold: Double = 1.5,
        qualityThreshold: Double = 0.5,
        updateInterval: TimeInterval = 1.0
    ) {
        self.ppgBufferSize = ppgBufferSize
        self.accelerometerBufferSize = accelerometerBufferSize
        self.minimumSamples = minimumSamples
        self.motionThreshold = motionThreshold
        self.qualityThreshold = qualityThreshold
        self.updateInterval = updateInterval
    }

    // MARK: - Presets

    /// Default configuration for consumer use
    public static let consumer = ProcessingConfiguration()

    /// Configuration for high-accuracy clinical use
    public static let clinical = ProcessingConfiguration(
        ppgBufferSize: 200,
        accelerometerBufferSize: 100,
        minimumSamples: 100,
        motionThreshold: 1.2,
        qualityThreshold: 0.7,
        updateInterval: 2.0
    )

    /// Configuration for fast response (lower accuracy)
    public static let responsive = ProcessingConfiguration(
        ppgBufferSize: 50,
        accelerometerBufferSize: 25,
        minimumSamples: 25,
        motionThreshold: 2.0,
        qualityThreshold: 0.4,
        updateInterval: 0.5
    )

    /// Configuration for demo mode
    public static let demo = ProcessingConfiguration(
        ppgBufferSize: 20,
        accelerometerBufferSize: 10,
        minimumSamples: 10,
        motionThreshold: 3.0,
        qualityThreshold: 0.3,
        updateInterval: 0.25
    )
}
