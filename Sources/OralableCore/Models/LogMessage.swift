//
//  LogMessage.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Log message model for device and system logging
//

import Foundation

// MARK: - Log Level

/// Log severity levels
public enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case debug
    case info
    case warning
    case error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    public var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

// MARK: - Log Category

/// Categories for log messages
public enum LogCategory: String, Codable, Sendable, CaseIterable {
    case bluetooth
    case sensor
    case calculation
    case recording
    case export
    case system
    case user

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Log Message

/// A log message for device or system events
public struct LogMessage: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier
    public let id: UUID

    /// The log message content
    public let message: String

    /// Timestamp when the log was created
    public let timestamp: Date

    /// Log severity level
    public let level: LogLevel

    /// Log category
    public let category: LogCategory

    /// Optional device identifier that generated the log
    public let deviceId: String?

    /// Optional additional context data
    public let metadata: [String: String]?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        message: String,
        timestamp: Date = Date(),
        level: LogLevel = .info,
        category: LogCategory = .system,
        deviceId: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.deviceId = deviceId
        self.metadata = metadata
    }

    // MARK: - Convenience Initializers

    /// Create a debug log message
    public static func debug(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil
    ) -> LogMessage {
        LogMessage(
            message: message,
            level: .debug,
            category: category,
            deviceId: deviceId
        )
    }

    /// Create an info log message
    public static func info(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil
    ) -> LogMessage {
        LogMessage(
            message: message,
            level: .info,
            category: category,
            deviceId: deviceId
        )
    }

    /// Create a warning log message
    public static func warning(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil
    ) -> LogMessage {
        LogMessage(
            message: message,
            level: .warning,
            category: category,
            deviceId: deviceId
        )
    }

    /// Create an error log message
    public static func error(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil
    ) -> LogMessage {
        LogMessage(
            message: message,
            level: .error,
            category: category,
            deviceId: deviceId
        )
    }

    // MARK: - Formatting

    /// Formatted timestamp string
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Full formatted log line
    public var formattedLine: String {
        let prefix = "[\(formattedTimestamp)] [\(level.rawValue.uppercased())] [\(category.rawValue)]"
        if let deviceId = deviceId {
            return "\(prefix) [\(deviceId)] \(message)"
        }
        return "\(prefix) \(message)"
    }
}

// MARK: - Array Extension

extension Array where Element == LogMessage {

    /// Filter logs by minimum level
    public func filtered(minLevel: LogLevel) -> [LogMessage] {
        filter { $0.level >= minLevel }
    }

    /// Filter logs by category
    public func filtered(category: LogCategory) -> [LogMessage] {
        filter { $0.category == category }
    }

    /// Filter logs by device
    public func filtered(deviceId: String) -> [LogMessage] {
        filter { $0.deviceId == deviceId }
    }

    /// Filter logs within a time range
    public func filtered(from startDate: Date, to endDate: Date) -> [LogMessage] {
        filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get the most recent N logs
    public func recent(_ count: Int) -> [LogMessage] {
        Array(sorted { $0.timestamp > $1.timestamp }.prefix(count))
    }

    /// Export logs to a formatted string
    public func exportToString() -> String {
        sorted { $0.timestamp < $1.timestamp }
            .map { $0.formattedLine }
            .joined(separator: "\n")
    }
}
