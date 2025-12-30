//
//  HealthDataRecord.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Health data record model for CloudKit sharing
//

import Foundation

// MARK: - Health Data Type

/// Types of health data that can be shared
public enum HealthDataType: String, Codable, Sendable, CaseIterable {
    case heartRate = "heart_rate"
    case spo2 = "spo2"
    case temperature = "temperature"
    case activity = "activity"
    case sleep = "sleep"
    case emg = "emg"
    case combined = "combined"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .spo2: return "SpO2"
        case .temperature: return "Temperature"
        case .activity: return "Activity"
        case .sleep: return "Sleep"
        case .emg: return "EMG"
        case .combined: return "Combined Data"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .spo2: return "lungs.fill"
        case .temperature: return "thermometer"
        case .activity: return "figure.walk"
        case .sleep: return "bed.double.fill"
        case .emg: return "bolt.horizontal.fill"
        case .combined: return "chart.bar.fill"
        }
    }

    /// Unit for this data type
    public var unit: String {
        switch self {
        case .heartRate: return "bpm"
        case .spo2: return "%"
        case .temperature: return "°C"
        case .activity: return "steps"
        case .sleep: return "hours"
        case .emg: return "mV"
        case .combined: return ""
        }
    }
}

// MARK: - Health Data Record

/// Represents a health data record from CloudKit
/// Used for sharing health measurements between consumer and professional apps
public struct HealthDataRecord: Codable, Sendable, Equatable, Identifiable {

    /// Unique record identifier (CloudKit record ID)
    public let recordID: String

    /// When the data was recorded
    public let recordingDate: Date

    /// Type of health data
    public let dataType: HealthDataType

    /// Compressed measurement data (LZFSE compressed JSON)
    public let measurements: Data

    /// Session duration in seconds
    public let sessionDuration: TimeInterval

    /// Optional patient/user identifier (for professional app)
    public let patientID: String?

    /// Optional device identifier
    public let deviceID: String?

    /// When the record was created in CloudKit
    public let createdAt: Date

    /// When the record was last modified
    public let modifiedAt: Date

    // MARK: - Identifiable

    public var id: String { recordID }

    // MARK: - Initialization

    public init(
        recordID: String,
        recordingDate: Date,
        dataType: HealthDataType,
        measurements: Data,
        sessionDuration: TimeInterval,
        patientID: String? = nil,
        deviceID: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.recordID = recordID
        self.recordingDate = recordingDate
        self.dataType = dataType
        self.measurements = measurements
        self.sessionDuration = sessionDuration
        self.patientID = patientID
        self.deviceID = deviceID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Initialize from string data type (for CloudKit records)
    public init(
        recordID: String,
        recordingDate: Date,
        dataTypeString: String,
        measurements: Data,
        sessionDuration: TimeInterval,
        patientID: String? = nil,
        deviceID: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.recordID = recordID
        self.recordingDate = recordingDate
        self.dataType = HealthDataType(rawValue: dataTypeString) ?? .combined
        self.measurements = measurements
        self.sessionDuration = sessionDuration
        self.patientID = patientID
        self.deviceID = deviceID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - Computed Properties

    /// Formatted duration string
    public var formattedDuration: String {
        sessionDuration.durationString
    }

    /// Size of measurement data in bytes
    public var measurementDataSize: Int {
        measurements.count
    }

    /// Human-readable size string
    public var formattedDataSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(measurementDataSize))
    }

    /// Whether this record has expired (older than retention period)
    public func hasExpired(retentionDays: Int = 90) -> Bool {
        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: retentionDays,
            to: recordingDate
        ) ?? recordingDate
        return Date() > expirationDate
    }

    // MARK: - Decompression

    /// Decompress and decode measurements to SerializableSensorData array
    /// - Parameter expectedSize: Expected decompressed size (typically 10x compressed size)
    /// - Returns: Array of sensor data, or nil if decompression fails
    public func decompressedSensorData(expectedSize: Int? = nil) -> [SerializableSensorData]? {
        let size = expectedSize ?? measurements.count * 10

        guard let decompressedData = measurements.decompressed(expectedSize: size) else {
            return nil
        }

        do {
            return try JSONDecoder().decode([SerializableSensorData].self, from: decompressedData)
        } catch {
            return nil
        }
    }

    /// Decompress and decode measurements to SharedSessionData
    public func decompressedSessionData(expectedSize: Int? = nil) -> SharedSessionData? {
        let size = expectedSize ?? measurements.count * 10

        guard let decompressedData = measurements.decompressed(expectedSize: size) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SharedSessionData.self, from: decompressedData)
        } catch {
            return nil
        }
    }
}

// MARK: - Array Extensions

public extension Array where Element == HealthDataRecord {

    /// Records of a specific data type
    func ofType(_ type: HealthDataType) -> [HealthDataRecord] {
        filter { $0.dataType == type }
    }

    /// Records within a date range
    func inRange(from startDate: Date, to endDate: Date) -> [HealthDataRecord] {
        filter { $0.recordingDate >= startDate && $0.recordingDate <= endDate }
    }

    /// Records for a specific patient
    func forPatient(_ patientID: String) -> [HealthDataRecord] {
        filter { $0.patientID == patientID }
    }

    /// Records from today
    var today: [HealthDataRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return inRange(from: startOfDay, to: endOfDay)
    }

    /// Most recent record
    var mostRecent: HealthDataRecord? {
        sorted { $0.recordingDate > $1.recordingDate }.first
    }

    /// Total session duration across all records
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.sessionDuration }
    }

    /// Records that haven't expired
    func notExpired(retentionDays: Int = 90) -> [HealthDataRecord] {
        filter { !$0.hasExpired(retentionDays: retentionDays) }
    }
}

// MARK: - Health Data Summary

/// Summary of health data for a time period
public struct HealthDataSummary: Codable, Sendable, Equatable {
    public let period: DateInterval
    public let recordCount: Int
    public let totalDuration: TimeInterval
    public let dataTypes: [HealthDataType]
    public let averageHeartRate: Double?
    public let averageSpO2: Double?

    public init(
        period: DateInterval,
        recordCount: Int,
        totalDuration: TimeInterval,
        dataTypes: [HealthDataType],
        averageHeartRate: Double? = nil,
        averageSpO2: Double? = nil
    ) {
        self.period = period
        self.recordCount = recordCount
        self.totalDuration = totalDuration
        self.dataTypes = dataTypes
        self.averageHeartRate = averageHeartRate
        self.averageSpO2 = averageSpO2
    }

    /// Create summary from array of health records
    public init(from records: [HealthDataRecord], period: DateInterval) {
        self.period = period
        self.recordCount = records.count
        self.totalDuration = records.totalDuration
        self.dataTypes = Array(Set(records.map { $0.dataType }))

        // Calculate averages from decompressed data
        var heartRates: [Double] = []
        var spo2Values: [Double] = []

        for record in records {
            if let sensorData = record.decompressedSensorData() {
                heartRates.append(contentsOf: sensorData.compactMap { $0.heartRateBPM })
                spo2Values.append(contentsOf: sensorData.compactMap { $0.spo2Percentage })
            }
        }

        self.averageHeartRate = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        self.averageSpO2 = spo2Values.isEmpty ? nil : spo2Values.reduce(0, +) / Double(spo2Values.count)
    }
}
