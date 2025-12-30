//
//  BiometricResult.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Result types for biometric processing
//

import Foundation

// MARK: - Heart Rate Source

/// Source of heart rate calculation
public enum HRSource: String, Codable, Sendable {
    /// Primary: Infrared channel peak detection
    case ir

    /// Fallback: Green channel peak detection
    case green

    /// Fallback: FFT frequency analysis
    case fft

    /// No valid signal detected
    case unavailable

    public var description: String {
        switch self {
        case .ir:
            return "Infrared"
        case .green:
            return "Green"
        case .fft:
            return "FFT"
        case .unavailable:
            return "Unavailable"
        }
    }
}

// MARK: - Signal Strength

/// Signal strength classification based on perfusion index
public enum SignalStrength: String, Codable, Sendable {
    /// No signal detected (PI < 0.05%)
    case none

    /// Weak signal (PI 0.05% - 0.2%)
    case weak

    /// Moderate signal (PI 0.2% - 0.5%)
    case moderate

    /// Strong signal (PI > 0.5%)
    case strong

    /// Initialize from perfusion index value
    public init(perfusionIndex: Double) {
        switch perfusionIndex {
        case ..<0.0005:
            self = .none
        case 0.0005..<0.002:
            self = .weak
        case 0.002..<0.005:
            self = .moderate
        default:
            self = .strong
        }
    }

    public var description: String {
        return rawValue.capitalized
    }

    /// Whether the signal is usable for calculations
    public var isUsable: Bool {
        switch self {
        case .moderate, .strong:
            return true
        case .none, .weak:
            return false
        }
    }
}

// MARK: - Processing Method

/// Processing method used
public enum ProcessingMethod: String, Codable, Sendable {
    /// Sample-by-sample real-time processing
    case realtime

    /// Array-based batch processing
    case batch
}

// MARK: - Biometric Result

/// Comprehensive biometric result from unified processor
public struct BiometricResult: Sendable {
    // MARK: - Heart Rate

    /// Heart rate in BPM (0 if unavailable)
    public let heartRate: Int

    /// Heart rate quality score (0.0 to 1.0)
    public let heartRateQuality: Double

    /// Which channel/method produced the heart rate
    public let heartRateSource: HRSource

    // MARK: - SpO2

    /// Blood oxygen saturation percentage (0 if unavailable)
    public let spo2: Double

    /// SpO2 quality score (0.0 to 1.0)
    public let spo2Quality: Double

    // MARK: - Signal Quality

    /// Perfusion index (AC/DC ratio) - higher = better signal
    public let perfusionIndex: Double

    /// Whether device is detected as worn on skin
    public let isWorn: Bool

    // MARK: - Activity

    /// Detected activity type from ActivityClassifier
    public let activity: ActivityType

    /// Motion level (0.0 to 1.0, deviation from stationary)
    public let motionLevel: Double

    // MARK: - Diagnostics

    /// Signal strength derived from perfusion index
    public let signalStrength: SignalStrength

    /// Processing method used
    public let processingMethod: ProcessingMethod

    // MARK: - Initialization

    public init(
        heartRate: Int,
        heartRateQuality: Double,
        heartRateSource: HRSource,
        spo2: Double,
        spo2Quality: Double,
        perfusionIndex: Double,
        isWorn: Bool,
        activity: ActivityType,
        motionLevel: Double,
        signalStrength: SignalStrength,
        processingMethod: ProcessingMethod
    ) {
        self.heartRate = heartRate
        self.heartRateQuality = heartRateQuality
        self.heartRateSource = heartRateSource
        self.spo2 = spo2
        self.spo2Quality = spo2Quality
        self.perfusionIndex = perfusionIndex
        self.isWorn = isWorn
        self.activity = activity
        self.motionLevel = motionLevel
        self.signalStrength = signalStrength
        self.processingMethod = processingMethod
    }

    // MARK: - Convenience Properties

    /// Whether heart rate data is valid and usable
    public var hasValidHeartRate: Bool {
        return heartRate > 0 && heartRateSource != .unavailable
    }

    /// Whether SpO2 data is valid and usable
    public var hasValidSpO2: Bool {
        return spo2 > 0 && spo2Quality > 0
    }

    /// Whether device is experiencing significant motion
    public var isMoving: Bool {
        return activity == .motion
    }

    // MARK: - Empty Result

    /// Empty result for when processing cannot produce valid output
    public static let empty = BiometricResult(
        heartRate: 0,
        heartRateQuality: 0,
        heartRateSource: .unavailable,
        spo2: 0,
        spo2Quality: 0,
        perfusionIndex: 0,
        isWorn: false,
        activity: .relaxed,
        motionLevel: 0,
        signalStrength: .none,
        processingMethod: .realtime
    )
}

// MARK: - Equatable

extension BiometricResult: Equatable {
    public static func == (lhs: BiometricResult, rhs: BiometricResult) -> Bool {
        return lhs.heartRate == rhs.heartRate &&
               lhs.heartRateQuality == rhs.heartRateQuality &&
               lhs.heartRateSource == rhs.heartRateSource &&
               lhs.spo2 == rhs.spo2 &&
               lhs.spo2Quality == rhs.spo2Quality &&
               lhs.perfusionIndex == rhs.perfusionIndex &&
               lhs.isWorn == rhs.isWorn &&
               lhs.activity == rhs.activity &&
               lhs.motionLevel == rhs.motionLevel &&
               lhs.signalStrength == rhs.signalStrength &&
               lhs.processingMethod == rhs.processingMethod
    }
}
