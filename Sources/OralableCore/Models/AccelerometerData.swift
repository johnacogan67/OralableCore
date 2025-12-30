//
//  AccelerometerData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  3-axis accelerometer data model
//

import Foundation

/// 3-axis accelerometer data
public struct AccelerometerData: Codable, Sendable, Equatable {
    /// X-axis acceleration (raw Int16 value)
    public let x: Int16

    /// Y-axis acceleration (raw Int16 value)
    public let y: Int16

    /// Z-axis acceleration (raw Int16 value)
    public let z: Int16

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(x: Int16, y: Int16, z: Int16, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Calculate magnitude of acceleration vector (raw units)
    public var magnitude: Double {
        let xD = Double(x)
        let yD = Double(y)
        let zD = Double(z)
        return sqrt(xD * xD + yD * yD + zD * zD)
    }

    /// Magnitude converted to g units (assuming ±2g full scale)
    public var magnitudeInG: Double {
        return magnitude * AccelerometerConversion.sensitivity2g / 1000.0
    }

    /// Simple movement detection based on magnitude threshold
    public var isMoving: Bool {
        return magnitude > 100
    }

    /// Whether the device is approximately at rest (magnitude ~1g)
    public var isAtRest: Bool {
        let mag = magnitudeInG
        return abs(mag - 1.0) < AccelerometerConversion.restTolerance
    }
}
