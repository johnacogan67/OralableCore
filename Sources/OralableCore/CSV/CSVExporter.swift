//
//  CSVExporter.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Export sensor data to CSV format
//

import Foundation

/// Exports sensor data to CSV format
public struct CSVExporter: Sendable {
    /// Configuration for export
    public let configuration: CSVExportConfiguration

    // MARK: - Initialization

    public init(configuration: CSVExportConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Export Methods

    /// Generate CSV content from sensor data
    /// - Parameters:
    ///   - sensorData: Array of sensor data points to export
    ///   - logs: Optional array of log messages
    /// - Returns: CSV content as string
    public func generateCSV(from sensorData: [SensorData], logs: [String] = []) -> String {
        var lines: [String] = []

        // Add header if configured
        if configuration.includeHeader {
            let header = configuration.columns.map { $0.rawValue }
            lines.append(header.joined(separator: configuration.separator))
        }

        // Create date formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = configuration.dateFormat

        // Create log lookup by timestamp (approximation)
        // In production, logs would have their own timestamps
        let remainingLogs = logs

        // Export sensor data rows
        for data in sensorData {
            let row = buildRow(for: data, dateFormatter: dateFormatter, log: nil)
            lines.append(row.joined(separator: configuration.separator))
        }

        // Add remaining log-only entries
        for log in remainingLogs {
            let row = buildLogOnlyRow(log: log, dateFormatter: dateFormatter)
            lines.append(row.joined(separator: configuration.separator))
        }

        return lines.joined(separator: configuration.lineEnding)
    }

    /// Generate CSV content from historical data points
    /// - Parameter dataPoints: Array of historical data points
    /// - Returns: CSV content as string
    public func generateCSV(from dataPoints: [HistoricalDataPoint]) -> String {
        var lines: [String] = []

        // Historical data uses a subset of columns
        let historicalColumns: [String] = [
            "Timestamp",
            "Avg_HeartRate", "HeartRate_Quality",
            "Avg_SpO2", "SpO2_Quality",
            "Avg_Temperature", "Avg_Battery",
            "Movement_Intensity", "Movement_Variability",
            "Grinding_Events",
            "Avg_PPG_IR", "Avg_PPG_Red", "Avg_PPG_Green"
        ]

        if configuration.includeHeader {
            lines.append(historicalColumns.joined(separator: configuration.separator))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = configuration.dateFormat

        for point in dataPoints {
            var row: [String] = []

            row.append(dateFormatter.string(from: point.timestamp))
            row.append(formatOptionalDouble(point.averageHeartRate))
            row.append(formatOptionalDouble(point.heartRateQuality))
            row.append(formatOptionalDouble(point.averageSpO2))
            row.append(formatOptionalDouble(point.spo2Quality))
            row.append(formatDouble(point.averageTemperature))
            row.append(String(point.averageBattery))
            row.append(formatDouble(point.movementIntensity))
            row.append(formatDouble(point.movementVariability))
            row.append(point.grindingEvents.map { String($0) } ?? "")
            row.append(formatOptionalDouble(point.averagePPGIR))
            row.append(formatOptionalDouble(point.averagePPGRed))
            row.append(formatOptionalDouble(point.averagePPGGreen))

            lines.append(row.joined(separator: configuration.separator))
        }

        return lines.joined(separator: configuration.lineEnding)
    }

    /// Get export summary for UI display
    /// - Parameters:
    ///   - sensorData: Array of sensor data points
    ///   - logs: Array of log messages
    /// - Returns: Export summary
    public func getExportSummary(sensorData: [SensorData], logs: [String] = []) -> CSVExportSummary {
        let dateRange = getDateRange(from: sensorData)
        let estimatedSize = estimateExportSize(sensorDataCount: sensorData.count, logCount: logs.count)

        return CSVExportSummary(
            sensorDataCount: sensorData.count,
            logCount: logs.count,
            dateRange: dateRange,
            estimatedSize: estimatedSize,
            columns: configuration.columns
        )
    }

    // MARK: - Private Methods

    private func buildRow(for data: SensorData, dateFormatter: DateFormatter, log: String?) -> [String] {
        var row: [String] = []

        for column in configuration.columns {
            let value = getValue(for: column, from: data, dateFormatter: dateFormatter, log: log)
            row.append(value)
        }

        return row
    }

    private func buildLogOnlyRow(log: String, dateFormatter: DateFormatter) -> [String] {
        var row: [String] = []

        for column in configuration.columns {
            if column == .timestamp {
                row.append(dateFormatter.string(from: Date()))
            } else if column == .message {
                row.append(escapeCSVField(log))
            } else {
                row.append("")
            }
        }

        return row
    }

    private func getValue(for column: CSVColumn, from data: SensorData, dateFormatter: DateFormatter, log: String?) -> String {
        switch column {
        case .timestamp:
            return dateFormatter.string(from: data.timestamp)
        case .ppgIR:
            return String(data.ppg.ir)
        case .ppgRed:
            return String(data.ppg.red)
        case .ppgGreen:
            return String(data.ppg.green)
        case .accelX:
            return String(data.accelerometer.x)
        case .accelY:
            return String(data.accelerometer.y)
        case .accelZ:
            return String(data.accelerometer.z)
        case .temperature:
            return formatDouble(data.temperature.celsius)
        case .battery:
            return String(data.battery.percentage)
        case .heartRateBPM:
            return data.heartRate.map { formatDouble($0.bpm) } ?? ""
        case .heartRateQuality:
            return data.heartRate.map { formatDouble($0.quality) } ?? ""
        case .spo2Percentage:
            return data.spo2.map { formatDouble($0.percentage) } ?? ""
        case .spo2Quality:
            return data.spo2.map { formatDouble($0.quality) } ?? ""
        case .message:
            return log.map { escapeCSVField($0) } ?? ""
        }
    }

    private func formatDouble(_ value: Double) -> String {
        return String(format: "%.\(configuration.decimalPrecision)f", value)
    }

    private func formatOptionalDouble(_ value: Double?) -> String {
        guard let value = value else { return "" }
        return formatDouble(value)
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private func getDateRange(from sensorData: [SensorData]) -> String {
        guard !sensorData.isEmpty else { return "No data" }

        let sortedData = sensorData.sorted { $0.timestamp < $1.timestamp }
        let startDate = sortedData.first!.timestamp
        let endDate = sortedData.last!.timestamp

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return dateFormatter.string(from: startDate)
        } else {
            return "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        }
    }

    private func estimateExportSize(sensorDataCount: Int, logCount: Int) -> String {
        // Rough estimation: each sensor data row is about 150 characters
        // Each log entry is about 100 characters on average
        let estimatedBytes = (sensorDataCount * 150) + (logCount * 100) + 200  // 200 for header
        return formatByteCount(Int64(estimatedBytes))
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - Template Generation

extension CSVExporter {
    /// Generate a template CSV file content with sample data
    /// - Returns: Template CSV content
    public static func generateTemplate() -> String {
        var lines: [String] = []

        // Header
        lines.append(CSVColumn.standardOrder.map { $0.rawValue }.joined(separator: ","))

        // Sample data row
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let sampleTimestamp = dateFormatter.string(from: Date())

        let sampleRow = [
            sampleTimestamp,
            "12345",    // PPG_IR
            "67890",    // PPG_Red
            "11111",    // PPG_Green
            "100",      // Accel_X
            "200",      // Accel_Y
            "300",      // Accel_Z
            "36.5",     // Temp_C
            "85",       // Battery_%
            "72.0",     // HeartRate_BPM
            "0.950",    // HeartRate_Quality
            "98.0",     // SpO2_%
            "0.980",    // SpO2_Quality
            "Sample measurement"  // Message
        ]
        lines.append(sampleRow.joined(separator: ","))

        // Log-only row example
        let logOnlyRow = [
            sampleTimestamp,
            "", "", "", "", "", "", "", "", "", "", "", "",
            "Log entry without sensor data"
        ]
        lines.append(logOnlyRow.joined(separator: ","))

        return lines.joined(separator: "\n")
    }
}
