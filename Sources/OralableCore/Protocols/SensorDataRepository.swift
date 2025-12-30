//
//  SensorDataRepository.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Protocol for sensor data storage and retrieval
//

import Foundation
import Combine

// MARK: - Sensor Data Repository Protocol

/// Protocol for storing and retrieving sensor data
/// Apps implement this to provide their specific storage mechanism (Core Data, UserDefaults, etc.)
public protocol SensorDataRepository: AnyObject {

    // MARK: - Save Operations

    /// Save a single sensor reading
    func save(_ reading: SensorReading) async throws

    /// Save multiple sensor readings (batch operation)
    func save(_ readings: [SensorReading]) async throws

    /// Save sensor data (composite)
    func save(_ sensorData: SensorData) async throws

    // MARK: - Fetch Operations

    /// Fetch all readings for a sensor type
    func fetchReadings(for sensorType: SensorType) async throws -> [SensorReading]

    /// Fetch readings for a sensor type within a date range
    func fetchReadings(
        for sensorType: SensorType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SensorReading]

    /// Fetch the most recent reading for a sensor type
    func fetchLatestReading(for sensorType: SensorType) async throws -> SensorReading?

    /// Fetch sensor data for a date range
    func fetchSensorData(from startDate: Date, to endDate: Date) async throws -> [SensorData]

    // MARK: - Delete Operations

    /// Delete readings older than a specific date
    func deleteReadings(olderThan date: Date) async throws

    /// Delete all readings for a sensor type
    func deleteReadings(for sensorType: SensorType) async throws

    /// Delete all stored data
    func deleteAll() async throws

    // MARK: - Query Operations

    /// Count readings for a sensor type
    func countReadings(for sensorType: SensorType) async throws -> Int

    /// Get date range of stored data
    func getDateRange() async throws -> (earliest: Date, latest: Date)?

    // MARK: - Export Operations

    /// Export all data within a date range
    func exportData(from startDate: Date, to endDate: Date) async throws -> [SensorData]
}

// MARK: - Default Implementations

extension SensorDataRepository {

    /// Default implementation for saving single reading
    public func save(_ reading: SensorReading) async throws {
        try await save([reading])
    }

    /// Convenience method to fetch recent readings
    public func fetchRecentReadings(
        for sensorType: SensorType,
        limit: Int
    ) async throws -> [SensorReading] {
        let allReadings = try await fetchReadings(for: sensorType)
        return Array(allReadings.suffix(limit))
    }

    /// Convenience method to fetch today's readings
    public func fetchTodaysReadings(for sensorType: SensorType) async throws -> [SensorReading] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return try await fetchReadings(for: sensorType, from: startOfDay, to: endOfDay)
    }
}

// MARK: - Recording Session Repository Protocol

/// Protocol for storing recording session data
public protocol RecordingSessionRepository: AnyObject {

    /// Recording session data structure
    associatedtype Session

    /// Save a recording session
    func saveSession(_ session: Session) async throws

    /// Fetch all sessions
    func fetchAllSessions() async throws -> [Session]

    /// Fetch sessions within a date range
    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [Session]

    /// Delete a specific session
    func deleteSession(_ sessionId: UUID) async throws

    /// Delete all sessions
    func deleteAllSessions() async throws
}

// MARK: - Historical Data Provider Protocol

/// Protocol for providing historical/aggregated data
public protocol HistoricalDataProvider: AnyObject {

    /// Fetch historical data points (aggregated)
    func fetchHistoricalData(
        from startDate: Date,
        to endDate: Date,
        aggregationInterval: TimeInterval
    ) async throws -> [HistoricalDataPoint]

    /// Fetch daily summaries
    func fetchDailySummaries(for numberOfDays: Int) async throws -> [DailySummary]

    /// Calculate statistics for a date range
    func calculateStatistics(
        for sensorType: SensorType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> SensorStatistics
}

// MARK: - Supporting Types

/// Daily summary of sensor data
public struct DailySummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let minHeartRate: Double?
    public let averageSpO2: Double?
    public let recordingDuration: TimeInterval
    public let activityBreakdown: [ActivityType: TimeInterval]

    public init(
        id: UUID = UUID(),
        date: Date,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        minHeartRate: Double? = nil,
        averageSpO2: Double? = nil,
        recordingDuration: TimeInterval = 0,
        activityBreakdown: [ActivityType: TimeInterval] = [:]
    ) {
        self.id = id
        self.date = date
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.averageSpO2 = averageSpO2
        self.recordingDuration = recordingDuration
        self.activityBreakdown = activityBreakdown
    }
}

/// Statistics for a sensor type
public struct SensorStatistics: Codable, Sendable {
    public let sensorType: SensorType
    public let count: Int
    public let min: Double
    public let max: Double
    public let average: Double
    public let standardDeviation: Double
    public let startDate: Date
    public let endDate: Date

    public init(
        sensorType: SensorType,
        count: Int,
        min: Double,
        max: Double,
        average: Double,
        standardDeviation: Double,
        startDate: Date,
        endDate: Date
    ) {
        self.sensorType = sensorType
        self.count = count
        self.min = min
        self.max = max
        self.average = average
        self.standardDeviation = standardDeviation
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Calculate statistics from an array of readings
    public static func calculate(from readings: [SensorReading]) -> SensorStatistics? {
        guard let first = readings.first else { return nil }

        let validReadings = readings.filter { $0.isValid }
        guard !validReadings.isEmpty else { return nil }

        let values = validReadings.map { $0.value }
        let count = values.count
        let sum = values.reduce(0, +)
        let average = sum / Double(count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0

        // Calculate standard deviation
        let squaredDiffs = values.map { pow($0 - average, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(count)
        let stdDev = sqrt(variance)

        let sortedByDate = validReadings.sorted { $0.timestamp < $1.timestamp }
        let startDate = sortedByDate.first?.timestamp ?? Date()
        let endDate = sortedByDate.last?.timestamp ?? Date()

        return SensorStatistics(
            sensorType: first.sensorType,
            count: count,
            min: min,
            max: max,
            average: average,
            standardDeviation: stdDev,
            startDate: startDate,
            endDate: endDate
        )
    }
}
