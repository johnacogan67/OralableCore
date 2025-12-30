//
//  Logger.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic logging utility
//

import Foundation
import os.log

// MARK: - Log Handler Protocol

/// Protocol for custom log handlers
/// Apps can implement this to provide their own logging storage/forwarding
public protocol LogHandler: AnyObject, Sendable {
    /// Handle a log message
    func log(_ message: LogMessage)

    /// Flush any buffered logs
    func flush()
}

// MARK: - Logger

/// Thread-safe logging utility for OralableCore
/// Uses os.log for system integration and supports custom handlers
public final class Logger: @unchecked Sendable {

    // MARK: - Shared Instance

    /// Shared logger instance
    public static let shared = Logger()

    // MARK: - Properties

    /// Minimum log level to output (logs below this level are ignored)
    public var minimumLevel: LogLevel = .debug

    /// Whether to output to os.log
    public var osLogEnabled: Bool = true

    /// Custom log handlers
    private var handlers: [LogHandler] = []

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.oralable.core.logger", qos: .utility)

    /// In-memory log buffer for recent logs
    private var recentLogs: [LogMessage] = []

    /// Maximum number of logs to keep in memory
    public var maxRecentLogs: Int = 500

    /// OS log instances by category
    private var osLogs: [LogCategory: OSLog] = [:]

    // MARK: - Initialization

    private init() {
        // Create OS log instances for each category
        for category in LogCategory.allCases {
            osLogs[category] = OSLog(
                subsystem: "com.oralable.core",
                category: category.rawValue
            )
        }
    }

    // MARK: - Handler Management

    /// Add a custom log handler
    public func addHandler(_ handler: LogHandler) {
        queue.sync {
            handlers.append(handler)
        }
    }

    /// Remove all custom handlers
    public func removeAllHandlers() {
        queue.sync {
            handlers.removeAll()
        }
    }

    // MARK: - Logging Methods

    /// Log a message
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .system,
        deviceId: String? = nil,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel else { return }

        let logMessage = LogMessage(
            message: message,
            level: level,
            category: category,
            deviceId: deviceId,
            metadata: metadata
        )

        queue.async { [weak self] in
            self?.processLog(logMessage, file: file, function: function, line: line)
        }
    }

    /// Log a debug message
    public func debug(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log an info message
    public func info(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log a warning message
    public func warning(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log an error message
    public func error(
        _ message: String,
        category: LogCategory = .system,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log an error with Error object
    public func error(
        _ error: Error,
        message: String? = nil,
        category: LogCategory = .system,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = message.map { "\($0): \(error.localizedDescription)" }
            ?? error.localizedDescription

        log(errorMessage, level: .error, category: category, deviceId: deviceId,
            metadata: ["error_type": String(describing: type(of: error))],
            file: file, function: function, line: line)
    }

    // MARK: - Bluetooth-Specific Logging

    /// Log a Bluetooth event
    public func bluetooth(
        _ message: String,
        level: LogLevel = .info,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: .bluetooth, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log a sensor event
    public func sensor(
        _ message: String,
        level: LogLevel = .debug,
        deviceId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: .sensor, deviceId: deviceId,
            file: file, function: function, line: line)
    }

    /// Log a calculation event
    public func calculation(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: .calculation,
            file: file, function: function, line: line)
    }

    // MARK: - Recent Logs Access

    /// Get recent logs (thread-safe copy)
    public func getRecentLogs(minLevel: LogLevel? = nil, category: LogCategory? = nil) -> [LogMessage] {
        queue.sync {
            var logs = recentLogs
            if let minLevel = minLevel {
                logs = logs.filter { $0.level >= minLevel }
            }
            if let category = category {
                logs = logs.filter { $0.category == category }
            }
            return logs
        }
    }

    /// Clear recent logs
    public func clearRecentLogs() {
        queue.sync {
            recentLogs.removeAll()
        }
    }

    /// Flush all handlers
    public func flush() {
        queue.sync {
            for handler in handlers {
                handler.flush()
            }
        }
    }

    // MARK: - Private Methods

    private func processLog(_ logMessage: LogMessage, file: String, function: String, line: Int) {
        // Add to recent logs
        recentLogs.append(logMessage)
        if recentLogs.count > maxRecentLogs {
            recentLogs.removeFirst(recentLogs.count - maxRecentLogs)
        }

        // Output to os.log if enabled
        if osLogEnabled, let osLog = osLogs[logMessage.category] {
            let osLogType: OSLogType
            switch logMessage.level {
            case .debug:
                osLogType = .debug
            case .info:
                osLogType = .info
            case .warning:
                osLogType = .default
            case .error:
                osLogType = .error
            }

            let fileName = (file as NSString).lastPathComponent
            os_log("%{public}@ [%{public}@:%{public}d] %{public}@",
                   log: osLog,
                   type: osLogType,
                   logMessage.level.rawValue.uppercased(),
                   fileName,
                   line,
                   logMessage.message)
        }

        // Forward to custom handlers
        for handler in handlers {
            handler.log(logMessage)
        }
    }
}

// MARK: - Convenience Global Functions

/// Quick debug log
public func logDebug(_ message: String, category: LogCategory = .system) {
    Logger.shared.debug(message, category: category)
}

/// Quick info log
public func logInfo(_ message: String, category: LogCategory = .system) {
    Logger.shared.info(message, category: category)
}

/// Quick warning log
public func logWarning(_ message: String, category: LogCategory = .system) {
    Logger.shared.warning(message, category: category)
}

/// Quick error log
public func logError(_ message: String, category: LogCategory = .system) {
    Logger.shared.error(message, category: category)
}
