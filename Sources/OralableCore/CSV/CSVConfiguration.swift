//
//  CSVConfiguration.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Configuration options for CSV export/import
//

import Foundation

/// Configuration for CSV export operations
public struct CSVExportConfiguration: Sendable {
    /// Columns to include in export
    public let columns: [CSVColumn]

    /// Date format for timestamp column
    public let dateFormat: String

    /// Whether to include header row
    public let includeHeader: Bool

    /// Field separator (default: comma)
    public let separator: String

    /// Line ending style
    public let lineEnding: String

    /// Decimal precision for floating point values
    public let decimalPrecision: Int

    // MARK: - Initialization

    public init(
        columns: [CSVColumn] = CSVColumn.standardOrder,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS",
        includeHeader: Bool = true,
        separator: String = ",",
        lineEnding: String = "\n",
        decimalPrecision: Int = 3
    ) {
        self.columns = columns
        self.dateFormat = dateFormat
        self.includeHeader = includeHeader
        self.separator = separator
        self.lineEnding = lineEnding
        self.decimalPrecision = decimalPrecision
    }

    // MARK: - Presets

    /// Default configuration with all columns
    public static let `default` = CSVExportConfiguration()

    /// Minimal configuration with only essential data
    public static let minimal = CSVExportConfiguration(
        columns: [.timestamp, .ppgIR, .ppgRed, .ppgGreen, .temperature, .battery]
    )

    /// Full configuration with all sensor data
    public static let full = CSVExportConfiguration(
        columns: CSVColumn.standardOrder
    )

    /// Configuration excluding movement data
    public static func withoutMovement() -> CSVExportConfiguration {
        let columns = CSVColumn.standardOrder.filter { !$0.group.columns.contains($0) || $0.group != .accelerometer }
        return CSVExportConfiguration(columns: columns)
    }

    /// Configuration with only specific column groups
    public static func with(groups: [CSVColumnGroup]) -> CSVExportConfiguration {
        var columns: [CSVColumn] = [.timestamp]  // Always include timestamp
        for group in groups {
            columns.append(contentsOf: group.columns)
        }
        return CSVExportConfiguration(columns: columns)
    }
}

// MARK: - Import Configuration

/// Configuration for CSV import operations
public struct CSVImportConfiguration: Sendable {
    /// Expected date format for timestamp column
    public let dateFormat: String

    /// Alternative date formats to try
    public let alternateDateFormats: [String]

    /// Field separator (default: comma)
    public let separator: Character

    /// Whether first row is header
    public let hasHeader: Bool

    /// Whether to skip invalid rows or fail
    public let skipInvalidRows: Bool

    /// Maximum number of warnings before failing
    public let maxWarnings: Int

    // MARK: - Initialization

    public init(
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS",
        alternateDateFormats: [String] = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "HH:mm:ss"
        ],
        separator: Character = ",",
        hasHeader: Bool = true,
        skipInvalidRows: Bool = true,
        maxWarnings: Int = 100
    ) {
        self.dateFormat = dateFormat
        self.alternateDateFormats = alternateDateFormats
        self.separator = separator
        self.hasHeader = hasHeader
        self.skipInvalidRows = skipInvalidRows
        self.maxWarnings = maxWarnings
    }

    // MARK: - Presets

    /// Default configuration
    public static let `default` = CSVImportConfiguration()

    /// Strict configuration that fails on any error
    public static let strict = CSVImportConfiguration(
        skipInvalidRows: false,
        maxWarnings: 0
    )

    /// Lenient configuration that tries to import as much as possible
    public static let lenient = CSVImportConfiguration(
        skipInvalidRows: true,
        maxWarnings: 1000
    )
}
