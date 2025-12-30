//
//  TemperatureData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Body temperature measurement data model
//

import Foundation

/// Body temperature measurement
public struct TemperatureData: Codable, Sendable, Equatable {
    /// Temperature in Celsius
    public let celsius: Double

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(celsius: Double, timestamp: Date = Date()) {
        self.celsius = celsius
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Convert to Fahrenheit
    public var fahrenheit: Double {
        return celsius * 9.0 / 5.0 + 32.0
    }

    /// Temperature status indicator
    public var status: TemperatureStatus {
        switch celsius {
        case ..<34.0:
            return .low
        case 34.0..<36.0:
            return .belowNormal
        case 36.0...37.5:
            return .normal
        case 37.5..<38.5:
            return .slightlyElevated
        default:
            return .elevated
        }
    }
}

// MARK: - Temperature Status

/// Temperature status classification
public enum TemperatureStatus: String, Codable, Sendable {
    case low = "Low"
    case belowNormal = "Below Normal"
    case normal = "Normal"
    case slightlyElevated = "Slightly Elevated"
    case elevated = "Elevated"

    /// Human-readable description
    public var description: String {
        return rawValue
    }
}
