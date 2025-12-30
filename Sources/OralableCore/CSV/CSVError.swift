//
//  CSVError.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Error types for CSV operations
//

import Foundation

/// Errors that can occur during CSV operations
public enum CSVError: Error, Sendable {
    // Import errors
    case emptyFile
    case missingRequiredColumns([CSVColumn])
    case invalidFormat(String)
    case invalidTimestamp(row: Int, value: String)
    case invalidValue(row: Int, column: CSVColumn, value: String)
    case tooManyWarnings(count: Int)
    case malformedRow(row: Int, reason: String)

    // Export errors
    case noDataToExport
    case encodingFailed

    // File errors
    case fileNotFound(String)
    case fileReadError(String)
    case fileWriteError(String)
}

// MARK: - LocalizedError

extension CSVError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty"
        case .missingRequiredColumns(let columns):
            let names = columns.map { $0.rawValue }.joined(separator: ", ")
            return "Missing required columns: \(names)"
        case .invalidFormat(let details):
            return "Invalid CSV format: \(details)"
        case .invalidTimestamp(let row, let value):
            return "Invalid timestamp at row \(row): '\(value)'"
        case .invalidValue(let row, let column, let value):
            return "Invalid value for \(column.rawValue) at row \(row): '\(value)'"
        case .tooManyWarnings(let count):
            return "Import stopped after \(count) warnings"
        case .malformedRow(let row, let reason):
            return "Malformed row \(row): \(reason)"
        case .noDataToExport:
            return "No data available to export"
        case .encodingFailed:
            return "Failed to encode CSV content"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let details):
            return "Failed to read file: \(details)"
        case .fileWriteError(let details):
            return "Failed to write file: \(details)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .emptyFile:
            return "Ensure the CSV file contains data rows"
        case .missingRequiredColumns:
            return "Check that the CSV file has the correct header row with required columns"
        case .invalidFormat:
            return "Verify the file is a valid CSV with proper formatting"
        case .invalidTimestamp:
            return "Timestamps should be in format: yyyy-MM-dd HH:mm:ss.SSS"
        case .invalidValue:
            return "Check the data type requirements for this column"
        case .tooManyWarnings:
            return "Review the CSV file for formatting issues or use lenient import mode"
        case .malformedRow:
            return "Check for unbalanced quotes or incorrect number of columns"
        case .noDataToExport:
            return "Collect some sensor data before exporting"
        case .encodingFailed:
            return "Check for special characters that may not encode properly"
        case .fileNotFound:
            return "Verify the file path is correct"
        case .fileReadError, .fileWriteError:
            return "Check file permissions and available disk space"
        }
    }
}

// MARK: - Import Warning

/// Warning encountered during CSV import (non-fatal)
public struct CSVImportWarning: Sendable {
    /// Row number where warning occurred (1-based)
    public let row: Int

    /// Type of warning
    public let type: WarningType

    /// Human-readable warning message
    public let message: String

    /// Raw row data that caused the warning (if available)
    public let rowData: String?

    public init(row: Int, type: WarningType, message: String, rowData: String? = nil) {
        self.row = row
        self.type = type
        self.message = message
        self.rowData = rowData
    }

    /// Types of import warnings
    public enum WarningType: String, Sendable, CaseIterable {
        case invalidSensorType = "invalid_sensor_type"
        case invalidValue = "invalid_value"
        case invalidTimestamp = "invalid_timestamp"
        case invalidQuality = "invalid_quality"
        case malformedRow = "malformed_row"
        case unknownColumn = "unknown_column"
        case missingOptionalValue = "missing_optional_value"

        public var displayName: String {
            switch self {
            case .invalidSensorType:
                return "Invalid Sensor Type"
            case .invalidValue:
                return "Invalid Value"
            case .invalidTimestamp:
                return "Invalid Timestamp"
            case .invalidQuality:
                return "Invalid Quality"
            case .malformedRow:
                return "Malformed Row"
            case .unknownColumn:
                return "Unknown Column"
            case .missingOptionalValue:
                return "Missing Optional Value"
            }
        }
    }
}
