//
//  StateEventCSVExporter.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Exports state transition events to CSV format.
//
//  CSV Format:
//  Timestamp,State,Color,IR_Value,Normalized_IR_%,Heart_Rate,SpO2,
//  Perfusion_Index,Temperature,Accel_X,Accel_Y,Accel_Z,Battery_mV
//

import Foundation

/// CSV exporter for state transition events
public struct StateEventCSVExporter: Sendable {

    // MARK: - CSV Header

    /// CSV column headers
    public static let headers = [
        "Timestamp",
        "State",
        "Color",
        "IR_Value",
        "Normalized_IR_%",
        "Heart_Rate",
        "SpO2",
        "Perfusion_Index",
        "Temperature",
        "Accel_X",
        "Accel_Y",
        "Accel_Z",
        "Battery_mV"
    ]

    /// Header line for CSV
    public static var headerLine: String {
        headers.joined(separator: ",") + "\n"
    }

    // MARK: - Export Methods

    /// Export events to CSV string
    public static func exportToCSV(events: [StateTransitionEvent]) -> String {
        var csv = headerLine

        for event in events {
            csv += buildRow(event: event)
        }

        return csv
    }

    /// Build a single CSV row from an event
    public static func buildRow(event: StateTransitionEvent) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let colorName: String
        switch event.state {
        case .dataStreaming:
            colorName = "Black"
        case .positioned:
            colorName = "Green"
        case .activity:
            colorName = "Red"
        }

        let values: [String] = [
            formatter.string(from: event.timestamp),
            event.state.rawValue,
            colorName,
            String(event.irValue),
            event.normalizedIRPercent.map { String(format: "%.1f", $0) } ?? "",
            event.heartRate.map { String(format: "%.0f", $0) } ?? "",
            event.spO2.map { String(format: "%.0f", $0) } ?? "",
            event.perfusionIndex.map { String(format: "%.4f", $0) } ?? "",
            String(format: "%.2f", event.temperature),
            String(event.accelX),
            String(event.accelY),
            String(event.accelZ),
            event.batteryMV.map { String($0) } ?? ""
        ]

        return values.joined(separator: ",") + "\n"
    }

    /// Append a single event to CSV string
    public static func appendEvent(_ event: StateTransitionEvent, to existingCSV: inout String) {
        existingCSV += buildRow(event: event)
    }

    // MARK: - Parsing

    /// Parse events from CSV string
    public static func parseCSV(_ csvString: String) -> [StateTransitionEvent] {
        var events: [StateTransitionEvent] = []
        let lines = csvString.components(separatedBy: .newlines)

        // Skip header
        let dataLines = lines.dropFirst().filter { !$0.isEmpty }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in dataLines {
            if let event = parseLine(line, formatter: formatter) {
                events.append(event)
            }
        }

        return events
    }

    /// Parse a single CSV line into an event
    private static func parseLine(_ line: String, formatter: ISO8601DateFormatter) -> StateTransitionEvent? {
        let columns = line.components(separatedBy: ",")
        guard columns.count >= 12 else { return nil }

        guard let timestamp = formatter.date(from: columns[0]),
              let state = DeviceRecordingState(rawValue: columns[1]) else {
            return nil
        }

        let irValue = Int(columns[3]) ?? 0
        let normalizedIR = Double(columns[4])
        let heartRate = Double(columns[5])
        let spO2 = Double(columns[6])
        let perfusionIndex = Double(columns[7])
        let temperature = Double(columns[8]) ?? 0
        let accelX = Int(columns[9]) ?? 0
        let accelY = Int(columns[10]) ?? 0
        let accelZ = Int(columns[11]) ?? 0
        let batteryMV = columns.count > 12 ? Int(columns[12]) : nil

        return StateTransitionEvent(
            timestamp: timestamp,
            state: state,
            irValue: irValue,
            normalizedIRPercent: normalizedIR,
            heartRate: heartRate,
            spO2: spO2,
            perfusionIndex: perfusionIndex,
            temperature: temperature,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ,
            batteryMV: batteryMV
        )
    }

    // MARK: - Summary

    /// Generate a summary of exported events
    public static func getSummary(events: [StateTransitionEvent]) -> StateEventExportSummary {
        let stateCounts = events.stateCounts
        let timeInStates = events.timeInStates()

        var dateRange = "No events"
        if let first = events.first, let last = events.last {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium

            if Calendar.current.isDate(first.timestamp, inSameDayAs: last.timestamp) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                dateRange = "\(timeFormatter.string(from: first.timestamp)) - \(timeFormatter.string(from: last.timestamp))"
            } else {
                dateRange = "\(formatter.string(from: first.timestamp)) - \(formatter.string(from: last.timestamp))"
            }
        }

        // Estimate file size (~120 bytes per row + header)
        let estimatedBytes = (events.count * 120) + 100
        let estimatedSize = formatByteCount(Int64(estimatedBytes))

        return StateEventExportSummary(
            eventCount: events.count,
            dataStreamingCount: stateCounts[.dataStreaming] ?? 0,
            positionedCount: stateCounts[.positioned] ?? 0,
            activityCount: stateCounts[.activity] ?? 0,
            dataStreamingDuration: timeInStates[.dataStreaming] ?? 0,
            positionedDuration: timeInStates[.positioned] ?? 0,
            activityDuration: timeInStates[.activity] ?? 0,
            dateRange: dateRange,
            estimatedSize: estimatedSize
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

/// Summary of state event export
public struct StateEventExportSummary: Sendable {
    public let eventCount: Int
    public let dataStreamingCount: Int
    public let positionedCount: Int
    public let activityCount: Int
    public let dataStreamingDuration: TimeInterval
    public let positionedDuration: TimeInterval
    public let activityDuration: TimeInterval
    public let dateRange: String
    public let estimatedSize: String

    /// Total duration of all states
    public var totalDuration: TimeInterval {
        dataStreamingDuration + positionedDuration + activityDuration
    }

    /// Formatted total duration
    public var formattedTotalDuration: String {
        formatDuration(totalDuration)
    }

    /// Percentage of time in positioned state
    public var positionedPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (positionedDuration / totalDuration) * 100
    }

    /// Percentage of time in activity state
    public var activityPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (activityDuration / totalDuration) * 100
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
