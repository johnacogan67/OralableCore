//
//  HeartRateData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Heart rate measurement data model with quality assessment
//

import Foundation

/// Heart rate measurement with quality assessment
public struct HeartRateData: Codable, Sendable, Equatable {
    /// Beats per minute
    public let bpm: Double

    /// Signal quality score (0.0 to 1.0)
    public let quality: Double

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(bpm: Double, quality: Double, timestamp: Date = Date()) {
        self.bpm = bpm
        self.quality = max(0.0, min(1.0, quality))
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Whether this measurement is considered valid
    public var isValid: Bool {
        return (40...200).contains(bpm) && quality >= 0.6
    }

    /// Quality level classification
    public var qualityLevel: QualityLevel {
        switch quality {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.7..<0.8:
            return .fair
        case 0.6..<0.7:
            return .acceptable
        default:
            return .poor
        }
    }

    /// Color name for quality indicator (for UI use)
    public var qualityColor: String {
        switch quality {
        case 0.85...1.0:
            return "green"
        case 0.7..<0.85:
            return "yellow"
        case 0.6..<0.7:
            return "orange"
        default:
            return "red"
        }
    }

    /// Heart rate zone classification
    public var zone: HeartRateZone {
        switch bpm {
        case 40..<60:
            return .resting
        case 60..<100:
            return .normal
        case 100..<120:
            return .elevated
        case 120..<160:
            return .exercise
        default:
            return .highIntensity
        }
    }
}

// MARK: - Heart Rate Zone

/// Heart rate zone classification
public enum HeartRateZone: String, Codable, Sendable {
    case resting = "Resting"
    case normal = "Normal"
    case elevated = "Elevated"
    case exercise = "Exercise"
    case highIntensity = "High Intensity"

    /// Human-readable description
    public var description: String {
        return rawValue
    }
}
