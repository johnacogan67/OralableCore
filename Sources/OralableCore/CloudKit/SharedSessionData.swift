//
//  SharedSessionData.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared session data models for CloudKit exchange between apps
//

import Foundation

// MARK: - Shared Session Data

/// Serializable container for sensor session data shared via CloudKit
/// Note: Named to maintain backwards compatibility with existing CloudKit records
/// which use "BruxismSessionData" as the record type
public struct SharedSessionData: Codable, Sendable, Equatable, Identifiable {

    public var id: UUID { UUID() }

    /// Array of sensor readings in this session
    public let sensorReadings: [SerializableSensorData]

    /// Number of recordings in this session
    public let recordingCount: Int

    /// Session start timestamp
    public let startDate: Date

    /// Session end timestamp
    public let endDate: Date

    // MARK: - Initialization

    public init(
        sensorReadings: [SerializableSensorData],
        recordingCount: Int? = nil,
        startDate: Date,
        endDate: Date
    ) {
        self.sensorReadings = sensorReadings
        self.recordingCount = recordingCount ?? sensorReadings.count
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Create from an array of SensorData
    public init(from sensorData: [SensorData]) {
        self.sensorReadings = sensorData.map { SerializableSensorData(from: $0) }
        self.recordingCount = sensorData.count
        self.startDate = sensorData.first?.timestamp ?? Date()
        self.endDate = sensorData.last?.timestamp ?? Date()
    }

    // MARK: - Computed Properties

    /// Session duration in seconds
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Formatted duration string (HH:MM:SS)
    public var formattedDuration: String {
        duration.durationString
    }

    /// Whether the session contains any data
    public var isEmpty: Bool {
        sensorReadings.isEmpty
    }

    /// Number of readings with valid heart rate
    public var validHeartRateCount: Int {
        sensorReadings.withValidHeartRate.count
    }

    /// Number of readings with valid SpO2
    public var validSpO2Count: Int {
        sensorReadings.withValidSpO2.count
    }

    /// Average heart rate across the session
    public var averageHeartRate: Double? {
        sensorReadings.averageHeartRate
    }

    /// Average SpO2 across the session
    public var averageSpO2: Double? {
        sensorReadings.averageSpO2
    }

    /// Device types present in this session
    public var deviceTypes: Set<String> {
        Set(sensorReadings.map { $0.inferredDeviceType })
    }

    /// Whether session contains Oralable data
    public var hasOralableData: Bool {
        sensorReadings.contains { $0.isOralableDevice }
    }

    /// Whether session contains ANR data
    public var hasANRData: Bool {
        sensorReadings.contains { $0.isANRDevice }
    }

    // MARK: - Statistics

    /// Calculate session statistics
    public var statistics: SessionStatistics {
        SessionStatistics(from: self)
    }
}

// MARK: - Session Statistics

/// Statistics calculated from a session
public struct SessionStatistics: Codable, Sendable, Equatable {
    public let totalReadings: Int
    public let duration: TimeInterval

    // Heart Rate Statistics
    public let heartRateReadings: Int
    public let averageHeartRate: Double?
    public let minHeartRate: Double?
    public let maxHeartRate: Double?

    // SpO2 Statistics
    public let spo2Readings: Int
    public let averageSpO2: Double?
    public let minSpO2: Double?
    public let maxSpO2: Double?

    // Temperature Statistics
    public let averageTemperature: Double?
    public let minTemperature: Double?
    public let maxTemperature: Double?

    // Device Info
    public let deviceTypes: [String]

    public init(from session: SharedSessionData) {
        self.totalReadings = session.recordingCount
        self.duration = session.duration
        self.deviceTypes = Array(session.deviceTypes)

        // Heart rate
        let hrReadings = session.sensorReadings.withValidHeartRate
        self.heartRateReadings = hrReadings.count
        let hrValues = hrReadings.compactMap { $0.heartRateBPM }
        self.averageHeartRate = hrValues.isEmpty ? nil : hrValues.reduce(0, +) / Double(hrValues.count)
        self.minHeartRate = hrValues.min()
        self.maxHeartRate = hrValues.max()

        // SpO2
        let spo2Readings = session.sensorReadings.withValidSpO2
        self.spo2Readings = spo2Readings.count
        let spo2Values = spo2Readings.compactMap { $0.spo2Percentage }
        self.averageSpO2 = spo2Values.isEmpty ? nil : spo2Values.reduce(0, +) / Double(spo2Values.count)
        self.minSpO2 = spo2Values.min()
        self.maxSpO2 = spo2Values.max()

        // Temperature
        let tempValues = session.sensorReadings.map { $0.temperatureCelsius }.filter { $0 > 0 }
        self.averageTemperature = tempValues.isEmpty ? nil : tempValues.reduce(0, +) / Double(tempValues.count)
        self.minTemperature = tempValues.min()
        self.maxTemperature = tempValues.max()
    }

    public init(
        totalReadings: Int,
        duration: TimeInterval,
        heartRateReadings: Int,
        averageHeartRate: Double?,
        minHeartRate: Double?,
        maxHeartRate: Double?,
        spo2Readings: Int,
        averageSpO2: Double?,
        minSpO2: Double?,
        maxSpO2: Double?,
        averageTemperature: Double?,
        minTemperature: Double?,
        maxTemperature: Double?,
        deviceTypes: [String]
    ) {
        self.totalReadings = totalReadings
        self.duration = duration
        self.heartRateReadings = heartRateReadings
        self.averageHeartRate = averageHeartRate
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.spo2Readings = spo2Readings
        self.averageSpO2 = averageSpO2
        self.minSpO2 = minSpO2
        self.maxSpO2 = maxSpO2
        self.averageTemperature = averageTemperature
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.deviceTypes = deviceTypes
    }
}

// MARK: - Type Alias for Backwards Compatibility

/// Type alias for backwards compatibility with existing CloudKit code
/// CloudKit records may reference "BruxismSessionData"
public typealias BruxismSessionData = SharedSessionData
