//
//  CSVModels.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Supporting models for CSV operations
//

import Foundation

// MARK: - Export Summary

/// Summary of a CSV export operation
public struct CSVExportSummary: Sendable {
    /// Number of sensor data points exported
    public let sensorDataCount: Int

    /// Number of log entries exported
    public let logCount: Int

    /// Date range of exported data
    public let dateRange: String

    /// Estimated file size
    public let estimatedSize: String

    /// Columns included in export
    public let columns: [CSVColumn]

    public init(
        sensorDataCount: Int,
        logCount: Int,
        dateRange: String,
        estimatedSize: String,
        columns: [CSVColumn]
    ) {
        self.sensorDataCount = sensorDataCount
        self.logCount = logCount
        self.dateRange = dateRange
        self.estimatedSize = estimatedSize
        self.columns = columns
    }
}

// MARK: - Validation Result

/// Result of CSV file validation
public struct CSVValidationResult: Sendable {
    /// Whether the file is valid for import
    public let isValid: Bool

    /// Error message if validation failed
    public let errorMessage: String?

    /// Estimated number of data points
    public let estimatedDataPoints: Int

    /// Detected columns in the file
    public let detectedColumns: [String]

    /// Missing required columns
    public let missingColumns: [CSVColumn]

    /// Unknown columns (not in standard set)
    public let unknownColumns: [String]

    /// File size in bytes
    public let fileSize: Int64

    public init(
        isValid: Bool,
        errorMessage: String? = nil,
        estimatedDataPoints: Int = 0,
        detectedColumns: [String] = [],
        missingColumns: [CSVColumn] = [],
        unknownColumns: [String] = [],
        fileSize: Int64 = 0
    ) {
        self.isValid = isValid
        self.errorMessage = errorMessage
        self.estimatedDataPoints = estimatedDataPoints
        self.detectedColumns = detectedColumns
        self.missingColumns = missingColumns
        self.unknownColumns = unknownColumns
        self.fileSize = fileSize
    }
}

// MARK: - Import Result

/// Result of a CSV import operation
public struct CSVImportResult: Sendable {
    /// Successfully imported sensor data
    public let sensorData: [SensorData]

    /// Log messages extracted from import
    public let logs: [String]

    /// Warnings encountered during import
    public let warnings: [CSVImportWarning]

    /// Import statistics
    public let statistics: CSVImportStatistics

    /// Whether import was successful (has some data)
    public var isSuccessful: Bool {
        return !sensorData.isEmpty
    }

    /// Summary text for UI display
    public var summaryText: String {
        if sensorData.isEmpty {
            return "Import failed - no valid readings found"
        } else if warnings.isEmpty {
            return "Imported \(sensorData.count) readings successfully"
        } else {
            return "Imported \(sensorData.count) readings with \(warnings.count) warnings"
        }
    }

    public init(
        sensorData: [SensorData],
        logs: [String],
        warnings: [CSVImportWarning],
        statistics: CSVImportStatistics
    ) {
        self.sensorData = sensorData
        self.logs = logs
        self.warnings = warnings
        self.statistics = statistics
    }
}

// MARK: - Import Statistics

/// Statistics from a CSV import operation
public struct CSVImportStatistics: Sendable {
    /// Total rows in file (excluding header)
    public let totalRows: Int

    /// Successfully imported rows
    public let importedRows: Int

    /// Skipped rows (empty, log-only, etc.)
    public let skippedRows: Int

    /// Failed rows (format errors)
    public let failedRows: Int

    /// Date range of imported data
    public let dateRange: DateInterval?

    /// Success rate as percentage
    public var successRate: Double {
        guard totalRows > 0 else { return 0.0 }
        return Double(importedRows) / Double(totalRows) * 100.0
    }

    public init(
        totalRows: Int,
        importedRows: Int,
        skippedRows: Int,
        failedRows: Int,
        dateRange: DateInterval? = nil
    ) {
        self.totalRows = totalRows
        self.importedRows = importedRows
        self.skippedRows = skippedRows
        self.failedRows = failedRows
        self.dateRange = dateRange
    }
}

// MARK: - Format Documentation

/// Documentation for the expected CSV format
public struct CSVFormatDocumentation {
    /// Get the expected format as a string for display
    public static var expectedFormat: String {
        """
        Expected CSV Format:

        Header Row (required):
        \(CSVColumn.standardOrder.map { $0.rawValue }.joined(separator: ","))

        Timestamp Format:
        yyyy-MM-dd HH:mm:ss.SSS (e.g., 2025-12-30 14:30:45.123)

        Data Types:
        - Timestamp: Date/time string
        - PPG_IR, PPG_Red, PPG_Green: 32-bit integers
        - Accel_X, Accel_Y, Accel_Z: 16-bit integers
        - Temp_C: Decimal number (temperature in Celsius)
        - Battery_%: Integer (0-100)
        - HeartRate_BPM: Decimal number (optional)
        - HeartRate_Quality: Decimal 0.0-1.0 (optional)
        - SpO2_%: Decimal number (optional)
        - SpO2_Quality: Decimal 0.0-1.0 (optional)
        - Message: Text (optional, use quotes if contains commas)

        Notes:
        - Empty sensor fields with a message = log entry only
        - All fields present = sensor data with optional log
        - Use quotes around fields containing commas or newlines
        - Double quotes inside fields should be escaped as ""
        """
    }

    /// Get column documentation
    public static var columnDocumentation: [(column: CSVColumn, type: String, required: Bool)] {
        return CSVColumn.standardOrder.map { column in
            (column: column, type: column.dataType, required: column.isRequired)
        }
    }
}
