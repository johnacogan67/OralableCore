//
//  BatteryData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Device battery level data model
//

import Foundation

/// Device battery level measurement
public struct BatteryData: Codable, Sendable, Equatable {
    /// Battery percentage (0-100)
    public let percentage: Int

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(percentage: Int, timestamp: Date = Date()) {
        self.percentage = max(0, min(100, percentage))
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Battery status indicator
    public var status: BatteryStatus {
        switch percentage {
        case 0..<10:
            return .critical
        case 10..<20:
            return .low
        case 20..<50:
            return .medium
        case 50..<80:
            return .good
        default:
            return .excellent
        }
    }

    /// Whether battery needs charging soon
    public var needsCharging: Bool {
        return percentage < 20
    }
}

// MARK: - Battery Status

/// Battery status classification
public enum BatteryStatus: String, Codable, Sendable {
    case critical = "Critical"
    case low = "Low"
    case medium = "Medium"
    case good = "Good"
    case excellent = "Excellent"

    /// Human-readable description
    public var description: String {
        return rawValue
    }
}
