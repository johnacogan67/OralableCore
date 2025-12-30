//
//  SensorReading.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Unified sensor reading model for all devices
//

import Foundation

/// Unified sensor reading structure for all devices
public struct SensorReading: Codable, Identifiable, Equatable, Sendable {

    // MARK: - Properties

    /// Unique identifier
    public let id: UUID

    /// Type of sensor that produced this reading
    public let sensorType: SensorType

    /// Raw sensor value
    public let value: Double

    /// Timestamp when reading was captured
    public let timestamp: Date

    /// Optional device identifier
    public let deviceId: String?

    /// Optional quality indicator (0.0 - 1.0)
    public let quality: Double?

    /// Raw battery voltage in millivolts (only for battery readings)
    public let rawMillivolts: Int32?

    /// Hardware frame number for deterministic grouping (PPG/accelerometer readings)
    /// This ensures readings from the same hardware sample are grouped together
    public let frameNumber: UInt32?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        sensorType: SensorType,
        value: Double,
        timestamp: Date = Date(),
        deviceId: String? = nil,
        quality: Double? = nil,
        rawMillivolts: Int32? = nil,
        frameNumber: UInt32? = nil
    ) {
        self.id = id
        self.sensorType = sensorType
        self.value = value
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.quality = quality
        self.rawMillivolts = rawMillivolts
        self.frameNumber = frameNumber
    }

    // MARK: - Computed Properties

    /// Formatted value string with unit
    public var formattedValue: String {
        switch sensorType {
        case .temperature:
            return String(format: "%.1f %@", value, sensorType.unit)
        case .heartRate, .spo2, .battery:
            return String(format: "%.0f %@", value, sensorType.unit)
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return String(format: "%.0f %@", value, sensorType.unit)
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return String(format: "%.3f %@", value, sensorType.unit)
        case .muscleActivity:
            return String(format: "%.1f %@", value, sensorType.unit)
        }
    }

    /// Whether this reading is valid
    public var isValid: Bool {
        // Check if value is finite
        guard value.isFinite else { return false }

        // Check sensor-specific ranges
        switch sensorType {
        case .heartRate:
            return value >= 30 && value <= 250
        case .spo2:
            return value >= 50 && value <= 100
        case .temperature:
            return value >= 20 && value <= 45
        case .battery:
            return value >= 0 && value <= 100
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return value >= 0
        case .emg:
            return value >= 0
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return value >= -20 && value <= 20
        case .muscleActivity:
            return value >= 0
        }
    }

    // MARK: - Static Helpers

    /// Create a mock reading for testing
    public static func mock(
        sensorType: SensorType,
        value: Double? = nil,
        deviceId: String = "mock-device"
    ) -> SensorReading {
        let mockValue = value ?? sensorType.mockValue
        return SensorReading(
            sensorType: sensorType,
            value: mockValue,
            deviceId: deviceId,
            quality: 0.95
        )
    }
}

// MARK: - Array Extension

extension Array where Element == SensorReading {

    /// Get most recent reading for a sensor type
    public func latest(for sensorType: SensorType) -> SensorReading? {
        self
            .filter { $0.sensorType == sensorType }
            .max { $0.timestamp < $1.timestamp }
    }

    /// Get readings within a time range
    public func readings(
        for sensorType: SensorType,
        from startDate: Date,
        to endDate: Date
    ) -> [SensorReading] {
        self.filter {
            $0.sensorType == sensorType &&
            $0.timestamp >= startDate &&
            $0.timestamp <= endDate
        }
    }

    /// Calculate average value for a sensor type
    public func average(for sensorType: SensorType) -> Double? {
        let readings = self.filter { $0.sensorType == sensorType && $0.isValid }
        guard !readings.isEmpty else { return nil }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }

    /// Group readings by frame number
    public func groupedByFrame() -> [[SensorReading]] {
        let grouped = Dictionary(grouping: self) { $0.frameNumber }
        return grouped.values.sorted { first, second in
            guard let f1 = first.first?.frameNumber, let f2 = second.first?.frameNumber else {
                return false
            }
            return f1 < f2
        }
    }

    /// Get readings for a specific frame number
    public func readings(forFrame frameNumber: UInt32) -> [SensorReading] {
        self.filter { $0.frameNumber == frameNumber }
    }
}
