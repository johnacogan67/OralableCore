//
//  HistoricalDataPoint.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Aggregated sensor data for historical analysis
//

import Foundation

/// Aggregated sensor data for historical analysis
public struct HistoricalDataPoint: Codable, Identifiable, Sendable {
    /// Unique identifier
    public let id: UUID

    /// Timestamp for this aggregation period
    public let timestamp: Date

    // MARK: - Aggregated Metrics

    /// Average heart rate during this period
    public let averageHeartRate: Double?

    /// Average heart rate quality during this period
    public let heartRateQuality: Double?

    /// Average SpO2 during this period
    public let averageSpO2: Double?

    /// Average SpO2 quality during this period
    public let spo2Quality: Double?

    /// Average temperature during this period (Celsius)
    public let averageTemperature: Double

    /// Average battery level during this period
    public let averageBattery: Int

    // MARK: - Activity Metrics

    /// Movement intensity (raw accelerometer magnitude)
    public let movementIntensity: Double

    /// Movement variability (standard deviation of accelerometer magnitude)
    public let movementVariability: Double

    /// Number of grinding events detected (if applicable)
    public let grindingEvents: Int?

    // MARK: - PPG Averages

    /// Average PPG infrared value
    public let averagePPGIR: Double?

    /// Average PPG red value
    public let averagePPGRed: Double?

    /// Average PPG green value
    public let averagePPGGreen: Double?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        averageHeartRate: Double? = nil,
        heartRateQuality: Double? = nil,
        averageSpO2: Double? = nil,
        spo2Quality: Double? = nil,
        averageTemperature: Double,
        averageBattery: Int,
        movementIntensity: Double,
        movementVariability: Double = 0,
        grindingEvents: Int? = nil,
        averagePPGIR: Double? = nil,
        averagePPGRed: Double? = nil,
        averagePPGGreen: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.averageHeartRate = averageHeartRate
        self.heartRateQuality = heartRateQuality
        self.averageSpO2 = averageSpO2
        self.spo2Quality = spo2Quality
        self.averageTemperature = averageTemperature
        self.averageBattery = averageBattery
        self.movementIntensity = movementIntensity
        self.movementVariability = movementVariability
        self.grindingEvents = grindingEvents
        self.averagePPGIR = averagePPGIR
        self.averagePPGRed = averagePPGRed
        self.averagePPGGreen = averagePPGGreen
    }

    // MARK: - G-Unit Conversions

    /// Movement intensity converted to g units
    /// Note: movementIntensity is the raw magnitude from accelerometer
    public var movementIntensityInG: Double {
        // The raw magnitude is sqrt(x² + y² + z²) where x, y, z are Int16 values
        // We use the sensitivity conversion: raw * sensitivity(mg/digit) / 1000 = g
        return movementIntensity * AccelerometerConversion.sensitivity2g / 1000.0
    }

    /// Whether this data point represents a rest state (magnitude ~1g)
    public var isAtRest: Bool {
        let mag = movementIntensityInG
        return abs(mag - 1.0) < AccelerometerConversion.restTolerance
    }

    /// Temperature status for this period
    public var temperatureStatus: TemperatureStatus {
        switch averageTemperature {
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

    /// Battery status for this period
    public var batteryStatus: BatteryStatus {
        switch averageBattery {
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
}

// MARK: - Equatable

extension HistoricalDataPoint: Equatable {
    public static func == (lhs: HistoricalDataPoint, rhs: HistoricalDataPoint) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension HistoricalDataPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
