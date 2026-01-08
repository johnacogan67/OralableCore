//
//  EventCSVExporter.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Exports muscle activity events to CSV format
//

import Foundation

/// Exports muscle activity events to CSV format
public struct EventCSVExporter: Sendable {

    // MARK: - Column Configuration

    /// Options for controlling which columns are included in the export
    public struct ExportOptions: Sendable {
        public var includeTemperature: Bool
        public var includeHR: Bool
        public var includeSpO2: Bool
        public var includeSleep: Bool

        public init(
            includeTemperature: Bool = true,
            includeHR: Bool = true,
            includeSpO2: Bool = true,
            includeSleep: Bool = true
        ) {
            self.includeTemperature = includeTemperature
            self.includeHR = includeHR
            self.includeSpO2 = includeSpO2
            self.includeSleep = includeSleep
        }

        /// All metrics included
        public static var all: ExportOptions {
            ExportOptions(includeTemperature: true, includeHR: true, includeSpO2: true, includeSleep: true)
        }

        /// No optional metrics included (only required columns)
        public static var minimal: ExportOptions {
            ExportOptions(includeTemperature: false, includeHR: false, includeSpO2: false, includeSleep: false)
        }
    }

    // MARK: - Export

    /// Export events to CSV string
    /// - Parameters:
    ///   - events: Array of muscle activity events to export
    ///   - options: Export options controlling which columns are included
    /// - Returns: CSV content as string
    public static func exportToCSV(events: [MuscleActivityEvent], options: ExportOptions) -> String {
        var csv = buildHeader(options: options)

        for event in events {
            csv += buildRow(event: event, options: options)
        }

        return csv
    }

    private static func buildHeader(options: ExportOptions) -> String {
        var columns = [
            "Event_ID",
            "Type",
            "Start_Timestamp",
            "End_Timestamp",
            "Duration_ms",
            "Start_IR",
            "End_IR",
            "Average_IR",
            "Accel_X",
            "Accel_Y",
            "Accel_Z"
        ]

        if options.includeTemperature {
            columns.append("Temperature")
        }
        if options.includeHR {
            columns.append("HR")
        }
        if options.includeSpO2 {
            columns.append("SpO2")
        }
        if options.includeSleep {
            columns.append("Sleep")
        }

        return columns.joined(separator: ",") + "\n"
    }

    private static func buildRow(event: MuscleActivityEvent, options: ExportOptions) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var values: [String] = [
            String(event.eventNumber),
            event.eventType.rawValue,
            formatter.string(from: event.startTimestamp),
            formatter.string(from: event.endTimestamp),
            String(event.durationMs),
            String(event.startIR),
            String(event.endIR),
            String(format: "%.0f", event.averageIR),
            String(event.accelX),
            String(event.accelY),
            String(event.accelZ)
        ]

        if options.includeTemperature {
            values.append(String(format: "%.2f", event.temperature))
        }

        if options.includeHR {
            if let hr = event.heartRate {
                values.append(String(format: "%.0f", hr))
            } else {
                values.append("")
            }
        }

        if options.includeSpO2 {
            if let spO2 = event.spO2 {
                values.append(String(format: "%.0f", spO2))
            } else {
                values.append("")
            }
        }

        if options.includeSleep {
            if let sleep = event.sleepState {
                values.append(sleep.rawValue)
            } else {
                values.append("")
            }
        }

        return values.joined(separator: ",") + "\n"
    }

    // MARK: - File Export

    /// Export events to a CSV file
    /// - Parameters:
    ///   - events: Array of muscle activity events to export
    ///   - options: Export options controlling which columns are included
    ///   - filename: Optional custom filename (will be auto-generated if nil)
    /// - Returns: URL of the exported file
    /// - Throws: Error if file write fails
    public static func exportToFile(
        events: [MuscleActivityEvent],
        options: ExportOptions,
        filename: String? = nil
    ) throws -> URL {
        let csv = exportToCSV(events: events, options: options)

        let fileName = filename ?? "oralable_events_\(Int(Date().timeIntervalSince1970)).csv"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)

        try csv.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    /// Export events to a temporary file suitable for sharing
    /// - Parameters:
    ///   - events: Array of muscle activity events to export
    ///   - options: Export options controlling which columns are included
    ///   - userIdentifier: Optional user identifier to include in filename
    /// - Returns: URL of the exported file in the cache directory
    /// - Throws: Error if file write fails
    public static func exportToTempFile(
        events: [MuscleActivityEvent],
        options: ExportOptions,
        userIdentifier: String? = nil
    ) throws -> URL {
        let csv = exportToCSV(events: events, options: options)

        // Create filename with timestamp and optional user identifier
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let userPart = userIdentifier.map { "_\(String($0.prefix(8)))" } ?? ""
        let filename = "oralable_events\(userPart)_\(timestamp).csv"

        // Use cache directory for temporary files
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let exportDirectory = cacheDirectory.appendingPathComponent("EventExports", isDirectory: true)

        // Create exports directory if needed
        if !fileManager.fileExists(atPath: exportDirectory.path) {
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        }

        let fileURL = exportDirectory.appendingPathComponent(filename)

        // Remove existing file if present
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        try csv.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    // MARK: - Summary

    /// Get a summary of the export
    /// - Parameters:
    ///   - events: Events to summarize
    ///   - options: Export options
    /// - Returns: Summary information
    public static func getExportSummary(events: [MuscleActivityEvent], options: ExportOptions) -> EventExportSummary {
        let totalDurationMs = events.reduce(0) { $0 + $1.durationMs }
        let activityCount = events.filter { $0.eventType == .activity }.count
        let restCount = events.filter { $0.eventType == .rest }.count

        var dateRange: String = "No events"
        if let first = events.first, let last = events.last {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            if Calendar.current.isDate(first.startTimestamp, inSameDayAs: last.endTimestamp) {
                dateRange = formatter.string(from: first.startTimestamp)
            } else {
                dateRange = "\(formatter.string(from: first.startTimestamp)) - \(formatter.string(from: last.endTimestamp))"
            }
        }

        // Estimate file size (roughly 130 bytes per row + header)
        let estimatedBytes = (events.count * 130) + 120
        let estimatedSize = formatByteCount(Int64(estimatedBytes))

        return EventExportSummary(
            eventCount: events.count,
            activityCount: activityCount,
            restCount: restCount,
            totalDurationMs: totalDurationMs,
            dateRange: dateRange,
            estimatedSize: estimatedSize,
            includesTemperature: options.includeTemperature,
            includesHR: options.includeHR,
            includesSpO2: options.includeSpO2,
            includesSleep: options.includeSleep
        )
    }

    private static func formatByteCount(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - Export Summary

/// Summary information for an event export
public struct EventExportSummary: Sendable {
    public let eventCount: Int
    public let activityCount: Int
    public let restCount: Int
    public let totalDurationMs: Int
    public let dateRange: String
    public let estimatedSize: String
    public let includesTemperature: Bool
    public let includesHR: Bool
    public let includesSpO2: Bool
    public let includesSleep: Bool

    /// Total duration formatted as string (e.g., "5.2 sec", "2.3 min")
    public var formattedDuration: String {
        let seconds = Double(totalDurationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else {
            return String(format: "%.1f min", seconds / 60.0)
        }
    }
}
