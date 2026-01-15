//
//  EventCSVExporter.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 13, 2026 - Added normalized value columns
//
//  Exports muscle activity events to CSV format.
//  Supports both raw IR values and normalized percentages.
//

import Foundation

/// CSV exporter for muscle activity events
public struct EventCSVExporter: Sendable {

    // MARK: - Export Options

    public struct ExportOptions: Sendable {
        public var includeNormalized: Bool
        public var includeTemperature: Bool
        public var includeHR: Bool
        public var includeSpO2: Bool
        public var includeSleep: Bool
        public var includeAccelerometer: Bool

        public init(
            includeNormalized: Bool = true,
            includeTemperature: Bool = true,
            includeHR: Bool = true,
            includeSpO2: Bool = true,
            includeSleep: Bool = true,
            includeAccelerometer: Bool = true
        ) {
            self.includeNormalized = includeNormalized
            self.includeTemperature = includeTemperature
            self.includeHR = includeHR
            self.includeSpO2 = includeSpO2
            self.includeSleep = includeSleep
            self.includeAccelerometer = includeAccelerometer
        }

        /// All metrics included
        public static var all: ExportOptions {
            ExportOptions()
        }

        /// No optional metrics included (only required columns)
        public static var minimal: ExportOptions {
            ExportOptions(
                includeNormalized: false,
                includeTemperature: false,
                includeHR: false,
                includeSpO2: false,
                includeSleep: false,
                includeAccelerometer: false
            )
        }
    }

    // MARK: - Export

    /// Export events to CSV string
    public static func exportToCSV(events: [MuscleActivityEvent], options: ExportOptions = .all) -> String {
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
            "Average_IR"
        ]

        if options.includeNormalized {
            columns.append(contentsOf: [
                "Baseline",
                "Normalized_Start_%",
                "Normalized_End_%",
                "Normalized_Avg_%"
            ])
        }

        if options.includeAccelerometer {
            columns.append(contentsOf: ["Accel_X", "Accel_Y", "Accel_Z"])
        }

        if options.includeTemperature { columns.append("Temperature") }
        if options.includeHR { columns.append("HR") }
        if options.includeSpO2 { columns.append("SpO2") }
        if options.includeSleep { columns.append("Sleep") }

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
            String(format: "%.0f", event.averageIR)
        ]

        if options.includeNormalized {
            values.append(event.baseline.map { String(format: "%.0f", $0) } ?? "")
            values.append(event.normalizedStartIR.map { String(format: "%.1f", $0) } ?? "")
            values.append(event.normalizedEndIR.map { String(format: "%.1f", $0) } ?? "")
            values.append(event.normalizedAverageIR.map { String(format: "%.1f", $0) } ?? "")
        }

        if options.includeAccelerometer {
            values.append(contentsOf: [
                String(event.accelX),
                String(event.accelY),
                String(event.accelZ)
            ])
        }

        if options.includeTemperature {
            values.append(String(format: "%.2f", event.temperature))
        }

        if options.includeHR {
            values.append(event.heartRate.map { String(format: "%.0f", $0) } ?? "")
        }

        if options.includeSpO2 {
            values.append(event.spO2.map { String(format: "%.0f", $0) } ?? "")
        }

        if options.includeSleep {
            values.append(event.sleepState?.rawValue ?? "")
        }

        return values.joined(separator: ",") + "\n"
    }

    // MARK: - File Export

    /// Export events to a CSV file
    public static func exportToFile(
        events: [MuscleActivityEvent],
        options: ExportOptions = .all,
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
    public static func exportToTempFile(
        events: [MuscleActivityEvent],
        options: ExportOptions = .all,
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
    public static func getExportSummary(events: [MuscleActivityEvent], options: ExportOptions = .all) -> EventExportSummary {
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

        // Estimate file size (roughly 150 bytes per row + header for normalized)
        let bytesPerRow = options.includeNormalized ? 180 : 130
        let estimatedBytes = (events.count * bytesPerRow) + 150
        let estimatedSize = formatByteCount(Int64(estimatedBytes))

        return EventExportSummary(
            eventCount: events.count,
            activityCount: activityCount,
            restCount: restCount,
            totalDurationMs: totalDurationMs,
            dateRange: dateRange,
            estimatedSize: estimatedSize,
            includesNormalized: options.includeNormalized,
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
    public let includesNormalized: Bool
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
