//
//  SpO2Data.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Blood oxygen saturation measurement data model
//

import Foundation

/// Blood oxygen saturation measurement with quality assessment
public struct SpO2Data: Codable, Sendable, Equatable {
    /// Blood oxygen saturation percentage (70-100%)
    public let percentage: Double

    /// Signal quality score (0.0 to 1.0)
    public let quality: Double

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(percentage: Double, quality: Double, timestamp: Date = Date()) {
        self.percentage = percentage
        self.quality = max(0.0, min(1.0, quality))
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Whether this measurement is considered valid
    public var isValid: Bool {
        return (70...100).contains(percentage) && quality >= 0.6
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

    /// Health status based on SpO2 value
    public var healthStatus: SpO2HealthStatus {
        switch percentage {
        case 95...100:
            return .normal
        case 90..<95:
            return .borderline
        case 85..<90:
            return .low
        default:
            return .veryLow
        }
    }

    /// Color name for health status (for UI use)
    public var healthStatusColor: String {
        switch percentage {
        case 95...100:
            return "green"
        case 90..<95:
            return "yellow"
        case 85..<90:
            return "orange"
        default:
            return "red"
        }
    }
}

// MARK: - SpO2 Health Status

/// SpO2 health status classification
public enum SpO2HealthStatus: String, Codable, Sendable {
    case normal = "Normal"
    case borderline = "Borderline"
    case low = "Low"
    case veryLow = "Very Low"

    /// Human-readable description
    public var description: String {
        return rawValue
    }
}
