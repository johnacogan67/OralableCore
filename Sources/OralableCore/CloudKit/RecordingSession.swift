//
//  RecordingSession.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Recording session model for tracking data collection periods
//

import Foundation

// MARK: - Recording Status

/// Status of a recording session
public enum RecordingStatus: String, Codable, Sendable, CaseIterable {
    case recording = "Recording"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"

    /// SF Symbol icon for this status
    public var iconName: String {
        switch self {
        case .recording: return "record.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    /// Whether the session is actively recording or paused
    public var isActive: Bool {
        self == .recording || self == .paused
    }

    /// Whether the session has ended (completed or failed)
    public var hasEnded: Bool {
        self == .completed || self == .failed
    }

    /// Display color name for this status
    public var colorName: String {
        switch self {
        case .recording: return "red"
        case .paused: return "orange"
        case .completed: return "green"
        case .failed: return "gray"
        }
    }
}

// MARK: - Recording Session

/// Represents a single data recording session
public struct RecordingSession: Identifiable, Codable, Sendable, Equatable {

    /// Unique session identifier
    public let id: UUID

    /// Session start time
    public let startTime: Date

    /// Session end time (nil if still recording)
    public var endTime: Date?

    /// Current session status
    public var status: RecordingStatus

    /// Device identifier that recorded this session
    public var deviceID: String?

    /// Device name that recorded this session
    public var deviceName: String?

    /// Device type that recorded this session
    public var deviceType: DeviceType?

    // MARK: - Data Counts

    /// Number of sensor data points collected
    public var sensorDataCount: Int

    /// Number of PPG data points collected
    public var ppgDataCount: Int

    /// Number of heart rate calculations
    public var heartRateDataCount: Int

    /// Number of SpO2 calculations
    public var spo2DataCount: Int

    // MARK: - Metadata

    /// Optional user notes about the session
    public var notes: String?

    /// Tags for organizing sessions
    public var tags: [String]

    /// File path where session data is stored (app-specific)
    public var dataFilePath: URL?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        status: RecordingStatus = .recording,
        deviceID: String? = nil,
        deviceName: String? = nil,
        deviceType: DeviceType? = nil,
        sensorDataCount: Int = 0,
        ppgDataCount: Int = 0,
        heartRateDataCount: Int = 0,
        spo2DataCount: Int = 0,
        notes: String? = nil,
        tags: [String] = [],
        dataFilePath: URL? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.sensorDataCount = sensorDataCount
        self.ppgDataCount = ppgDataCount
        self.heartRateDataCount = heartRateDataCount
        self.spo2DataCount = spo2DataCount
        self.notes = notes
        self.tags = tags
        self.dataFilePath = dataFilePath
    }

    // MARK: - Computed Properties

    /// Session duration in seconds
    public var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }

    /// Formatted duration string (HH:MM:SS or MM:SS)
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Display label for the data type (EMG or IR based on device)
    public var dataTypeLabel: String {
        switch deviceType {
        case .anr:
            return "EMG"
        case .oralable:
            return "IR"
        case .demo:
            return "Demo"
        case .none:
            return "Unknown"
        }
    }

    /// SF Symbol icon for the data type
    public var dataTypeIcon: String {
        switch deviceType {
        case .anr:
            return "bolt.horizontal.circle.fill"
        case .oralable:
            return "waveform.path.ecg"
        case .demo:
            return "play.circle.fill"
        case .none:
            return "questionmark.circle"
        }
    }

    /// Color name for the data type
    public var dataTypeColorName: String {
        switch deviceType {
        case .anr:
            return "blue"
        case .oralable:
            return "purple"
        case .demo:
            return "orange"
        case .none:
            return "gray"
        }
    }

    /// Whether this session has accelerometer data
    public var hasAccelerometerData: Bool {
        sensorDataCount > 0
    }

    /// Whether this session has temperature data (Oralable only)
    public var hasTemperatureData: Bool {
        deviceType == .oralable && sensorDataCount > 0
    }

    /// Whether this session has any collected data
    public var hasData: Bool {
        sensorDataCount > 0 || ppgDataCount > 0 || heartRateDataCount > 0 || spo2DataCount > 0
    }

    /// Total number of all data points
    public var totalDataPoints: Int {
        sensorDataCount + ppgDataCount + heartRateDataCount + spo2DataCount
    }

    // MARK: - Mutating Methods

    /// Mark the session as completed
    public mutating func complete() {
        endTime = Date()
        status = .completed
    }

    /// Mark the session as paused
    public mutating func pause() {
        status = .paused
    }

    /// Resume a paused session
    public mutating func resume() {
        status = .recording
    }

    /// Mark the session as failed
    public mutating func fail() {
        endTime = Date()
        status = .failed
    }

    /// Increment sensor data count
    public mutating func incrementSensorData() {
        sensorDataCount += 1
    }

    /// Increment PPG data count
    public mutating func incrementPPGData() {
        ppgDataCount += 1
    }

    /// Increment heart rate data count
    public mutating func incrementHeartRateData() {
        heartRateDataCount += 1
    }

    /// Increment SpO2 data count
    public mutating func incrementSpO2Data() {
        spo2DataCount += 1
    }

    /// Add a tag to the session
    public mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    /// Remove a tag from the session
    public mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Array Extensions

public extension Array where Element == RecordingSession {

    /// Sessions that are currently recording
    var recording: [RecordingSession] {
        filter { $0.status == .recording }
    }

    /// Sessions that are paused
    var paused: [RecordingSession] {
        filter { $0.status == .paused }
    }

    /// Sessions that are completed
    var completed: [RecordingSession] {
        filter { $0.status == .completed }
    }

    /// Sessions that failed
    var failed: [RecordingSession] {
        filter { $0.status == .failed }
    }

    /// Sessions from Oralable device
    var oralableSessions: [RecordingSession] {
        filter { $0.deviceType == .oralable }
    }

    /// Sessions from ANR device
    var anrSessions: [RecordingSession] {
        filter { $0.deviceType == .anr }
    }

    /// Sessions with a specific tag
    func withTag(_ tag: String) -> [RecordingSession] {
        filter { $0.tags.contains(tag) }
    }

    /// Sessions within a date range
    func inRange(from startDate: Date, to endDate: Date) -> [RecordingSession] {
        filter { $0.startTime >= startDate && $0.startTime <= endDate }
    }

    /// Sessions from today
    var today: [RecordingSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return inRange(from: startOfDay, to: endOfDay)
    }

    /// Total duration of all sessions
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }

    /// Total sensor data points across all sessions
    var totalSensorDataCount: Int {
        reduce(0) { $0 + $1.sensorDataCount }
    }
}
