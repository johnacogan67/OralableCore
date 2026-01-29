//
//  StateEventFileManager.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Manages state transition event files with:
//  - Daily file naming (oralable_events_YYYY-MM-DD.csv)
//  - 14-day retention with automatic cleanup
//  - Append to existing file on reconnect
//  - Thread-safe file operations
//

import Foundation

/// Manager for state transition event CSV files
public final class StateEventFileManager: @unchecked Sendable {

    // MARK: - Configuration

    /// Number of days to retain event files
    public static let retentionDays: Int = 14

    /// Directory name for event files
    public static let directoryName = "OralableEvents"

    /// File name prefix
    public static let filePrefix = "oralable_events_"

    /// File extension
    public static let fileExtension = "csv"

    // MARK: - Singleton

    public static let shared = StateEventFileManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let writeQueue = DispatchQueue(label: "com.oralable.stateEventFileManager", qos: .utility)
    private var currentFileURL: URL?
    private var currentFileDate: Date?
    private var hasWrittenHeader: Bool = false

    // MARK: - Initialization

    private init() {
        // Create events directory on init
        _ = try? createEventsDirectory()
    }

    // MARK: - Directory Management

    /// Get the events directory URL
    public var eventsDirectoryURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Create the events directory if it doesn't exist
    @discardableResult
    public func createEventsDirectory() throws -> URL {
        let directoryURL = eventsDirectoryURL

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            Logger.shared.info("[StateEventFileManager] Created events directory at \(directoryURL.path)")
        }

        return directoryURL
    }

    // MARK: - File Naming

    /// Generate filename for a given date
    public func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return "\(Self.filePrefix)\(dateString).\(Self.fileExtension)"
    }

    /// Get file URL for a given date
    public func fileURL(for date: Date) -> URL {
        let directory = eventsDirectoryURL
        return directory.appendingPathComponent(filename(for: date))
    }

    /// Get file URL for today
    public var todayFileURL: URL {
        fileURL(for: Date())
    }

    // MARK: - File Operations

    /// Open or create the file for today
    /// Returns the file URL
    public func openTodayFile() throws -> URL {
        let today = Date()
        let fileURL = self.fileURL(for: today)

        // Check if we need to switch files (new day)
        if let currentDate = currentFileDate,
           !Calendar.current.isDate(currentDate, inSameDayAs: today) {
            Logger.shared.info("[StateEventFileManager] New day detected, switching to new file")
            currentFileURL = nil
            hasWrittenHeader = false
        }

        currentFileURL = fileURL
        currentFileDate = today

        // Check if file exists and has content
        if fileManager.fileExists(atPath: fileURL.path) {
            // Check if file has header
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int,
               fileSize > 0 {
                hasWrittenHeader = true
                Logger.shared.info("[StateEventFileManager] Opened existing file: \(fileURL.lastPathComponent)")
            }
        } else {
            // Create new file with header
            try createEventsDirectory()
            fileManager.createFile(atPath: fileURL.path, contents: nil)
            Logger.shared.info("[StateEventFileManager] Created new file: \(fileURL.lastPathComponent)")
        }

        return fileURL
    }

    /// Append an event to the current day's file
    public func appendEvent(_ event: StateTransitionEvent) throws {
        try writeQueue.sync {
            let fileURL = try openTodayFile()

            // Write header if needed
            if !hasWrittenHeader {
                let header = StateEventCSVExporter.headerLine
                try appendString(header, to: fileURL)
                hasWrittenHeader = true
            }

            // Write event row
            let row = StateEventCSVExporter.buildRow(event: event)
            try appendString(row, to: fileURL)
        }
    }

    /// Append multiple events to the current day's file
    public func appendEvents(_ events: [StateTransitionEvent]) throws {
        guard !events.isEmpty else { return }

        try writeQueue.sync {
            let fileURL = try openTodayFile()

            var content = ""

            // Write header if needed
            if !hasWrittenHeader {
                content += StateEventCSVExporter.headerLine
                hasWrittenHeader = true
            }

            // Write event rows
            for event in events {
                content += StateEventCSVExporter.buildRow(event: event)
            }

            try appendString(content, to: fileURL)
        }
    }

    /// Append string to file
    private func appendString(_ string: String, to fileURL: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw StateEventFileError.encodingFailed
        }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            // File doesn't exist, create it
            try data.write(to: fileURL)
        }
    }

    // MARK: - File Listing

    /// Get all event files in the directory
    public func listEventFiles() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: eventsDirectoryURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == Self.fileExtension }
            .filter { $0.lastPathComponent.hasPrefix(Self.filePrefix) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } // Most recent first
    }

    /// Get events from a specific file
    public func loadEvents(from fileURL: URL) throws -> [StateTransitionEvent] {
        let csvString = try String(contentsOf: fileURL, encoding: .utf8)
        return StateEventCSVExporter.parseCSV(csvString)
    }

    /// Get all events from today's file
    public func loadTodayEvents() throws -> [StateTransitionEvent] {
        let fileURL = todayFileURL

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        return try loadEvents(from: fileURL)
    }

    // MARK: - Retention

    /// Clean up files older than retention period
    public func cleanupOldFiles() {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: Date()
        ) ?? Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let files = listEventFiles()
        var deletedCount = 0

        for fileURL in files {
            // Extract date from filename
            let filename = fileURL.deletingPathExtension().lastPathComponent
            let dateString = String(filename.dropFirst(Self.filePrefix.count))

            guard let fileDate = formatter.date(from: dateString) else {
                continue
            }

            if fileDate < cutoffDate {
                do {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                    Logger.shared.info("[StateEventFileManager] Deleted old file: \(fileURL.lastPathComponent)")
                } catch {
                    Logger.shared.error("[StateEventFileManager] Failed to delete \(fileURL.lastPathComponent): \(error)")
                }
            }
        }

        if deletedCount > 0 {
            Logger.shared.info("[StateEventFileManager] Cleanup complete: deleted \(deletedCount) old file(s)")
        }
    }

    // MARK: - Statistics

    /// Get storage statistics
    public func getStorageStats() -> StateEventStorageStats {
        let files = listEventFiles()
        var totalSize: Int64 = 0
        var totalEvents = 0

        for fileURL in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }

            if let events = try? loadEvents(from: fileURL) {
                totalEvents += events.count
            }
        }

        let oldestFile = files.last
        let newestFile = files.first

        return StateEventStorageStats(
            fileCount: files.count,
            totalSizeBytes: totalSize,
            totalEventCount: totalEvents,
            oldestFile: oldestFile,
            newestFile: newestFile
        )
    }
}

// MARK: - Errors

/// Errors for state event file operations
public enum StateEventFileError: Error, LocalizedError {
    case encodingFailed
    case directoryCreationFailed
    case fileCreationFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode event data"
        case .directoryCreationFailed:
            return "Failed to create events directory"
        case .fileCreationFailed:
            return "Failed to create event file"
        case .writeFailed:
            return "Failed to write to event file"
        }
    }
}

// MARK: - Storage Stats

/// Statistics about event file storage
public struct StateEventStorageStats: Sendable {
    public let fileCount: Int
    public let totalSizeBytes: Int64
    public let totalEventCount: Int
    public let oldestFile: URL?
    public let newestFile: URL?

    /// Formatted total size
    public var formattedSize: String {
        if totalSizeBytes < 1024 {
            return "\(totalSizeBytes) B"
        } else if totalSizeBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalSizeBytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(totalSizeBytes) / (1024.0 * 1024.0))
        }
    }

    /// Date range description
    public var dateRange: String {
        guard let oldest = oldestFile, let newest = newestFile else {
            return "No files"
        }

        let oldestName = oldest.deletingPathExtension().lastPathComponent
        let newestName = newest.deletingPathExtension().lastPathComponent

        let oldestDate = String(oldestName.dropFirst(StateEventFileManager.filePrefix.count))
        let newestDate = String(newestName.dropFirst(StateEventFileManager.filePrefix.count))

        if oldestDate == newestDate {
            return oldestDate
        }

        return "\(oldestDate) to \(newestDate)"
    }
}
