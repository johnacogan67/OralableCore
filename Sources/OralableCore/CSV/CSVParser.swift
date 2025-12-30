//
//  CSVParser.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Parse CSV content into sensor data
//

import Foundation

/// Parses CSV content into sensor data
public struct CSVParser: Sendable {
    /// Configuration for parsing
    public let configuration: CSVImportConfiguration

    // MARK: - Initialization

    public init(configuration: CSVImportConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Parse Methods

    /// Parse CSV content string into sensor data
    /// - Parameter content: CSV content string
    /// - Returns: Import result with sensor data and statistics
    /// - Throws: CSVError if parsing fails
    public func parse(_ content: String) throws -> CSVImportResult {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            throw CSVError.emptyFile
        }

        // Parse header
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)
        let columnMap = buildColumnMap(from: headers)

        // Validate required columns
        let missingColumns = findMissingRequiredColumns(columnMap: columnMap)
        if !missingColumns.isEmpty && !configuration.skipInvalidRows {
            throw CSVError.missingRequiredColumns(missingColumns)
        }

        // Parse data rows
        var sensorData: [SensorData] = []
        var logs: [String] = []
        var warnings: [CSVImportWarning] = []
        var skippedRows = 0
        var failedRows = 0
        var timestamps: [Date] = []

        let dataLines = Array(lines.dropFirst())

        for (index, line) in dataLines.enumerated() {
            let rowNumber = index + 2  // 1-based, accounting for header

            do {
                let fields = parseCSVLine(line)

                // Check if this is a log-only entry
                let isLogOnly = isLogOnlyRow(fields: fields, columnMap: columnMap)

                if isLogOnly {
                    if let message = extractMessage(from: fields, columnMap: columnMap), !message.isEmpty {
                        logs.append(message)
                    }
                    skippedRows += 1
                } else {
                    // Parse sensor data
                    let data = try parseSensorData(from: fields, columnMap: columnMap, rowNumber: rowNumber)
                    sensorData.append(data)
                    timestamps.append(data.timestamp)

                    // Extract any associated log message
                    if let message = extractMessage(from: fields, columnMap: columnMap), !message.isEmpty {
                        logs.append(message)
                    }
                }
            } catch let error as CSVError {
                if configuration.skipInvalidRows {
                    warnings.append(CSVImportWarning(
                        row: rowNumber,
                        type: .malformedRow,
                        message: error.localizedDescription,
                        rowData: line
                    ))
                    failedRows += 1

                    if warnings.count >= configuration.maxWarnings {
                        throw CSVError.tooManyWarnings(count: warnings.count)
                    }
                } else {
                    throw error
                }
            }
        }

        // Calculate date range
        let dateRange: DateInterval? = {
            guard !timestamps.isEmpty else { return nil }
            let earliest = timestamps.min()!
            let latest = timestamps.max()!
            return DateInterval(start: earliest, end: latest)
        }()

        let statistics = CSVImportStatistics(
            totalRows: dataLines.count,
            importedRows: sensorData.count,
            skippedRows: skippedRows,
            failedRows: failedRows,
            dateRange: dateRange
        )

        return CSVImportResult(
            sensorData: sensorData,
            logs: logs,
            warnings: warnings,
            statistics: statistics
        )
    }

    /// Validate CSV content without fully parsing
    /// - Parameter content: CSV content string
    /// - Returns: Validation result
    public func validate(_ content: String) -> CSVValidationResult {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            return CSVValidationResult(
                isValid: false,
                errorMessage: "CSV file is empty",
                estimatedDataPoints: 0
            )
        }

        let headers = parseCSVLine(lines[0])
        let columnMap = buildColumnMap(from: headers)
        let missingColumns = findMissingRequiredColumns(columnMap: columnMap)

        // Find unknown columns
        let knownColumnNames = Set(CSVColumn.allCases.map { $0.rawValue })
        let unknownColumns = headers.filter { !knownColumnNames.contains($0) }

        let isValid = missingColumns.isEmpty
        let errorMessage = isValid ? nil : "Missing required columns: \(missingColumns.map { $0.rawValue }.joined(separator: ", "))"

        return CSVValidationResult(
            isValid: isValid,
            errorMessage: errorMessage,
            estimatedDataPoints: max(0, lines.count - 1),
            detectedColumns: headers,
            missingColumns: missingColumns,
            unknownColumns: unknownColumns,
            fileSize: Int64(content.utf8.count)
        )
    }

    // MARK: - Private Parsing Methods

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                if insideQuotes {
                    // Check for escaped quote
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField.append("\"")
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            } else if char == Character(String(configuration.separator)) && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }

            i = line.index(after: i)
        }

        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private func buildColumnMap(from headers: [String]) -> [CSVColumn: Int] {
        var map: [CSVColumn: Int] = [:]
        for (index, header) in headers.enumerated() {
            let trimmed = header.trimmingCharacters(in: .whitespaces)
            if let column = CSVColumn(rawValue: trimmed) {
                map[column] = index
            }
        }
        return map
    }

    private func findMissingRequiredColumns(columnMap: [CSVColumn: Int]) -> [CSVColumn] {
        return CSVColumn.requiredColumns.filter { columnMap[$0] == nil }
    }

    private func isLogOnlyRow(fields: [String], columnMap: [CSVColumn: Int]) -> Bool {
        // Check if all sensor data columns are empty
        let sensorColumns: [CSVColumn] = [.ppgIR, .ppgRed, .ppgGreen, .accelX, .accelY, .accelZ, .temperature, .battery]

        for column in sensorColumns {
            if let index = columnMap[column], index < fields.count {
                if !fields[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    return false
                }
            }
        }
        return true
    }

    private func extractMessage(from fields: [String], columnMap: [CSVColumn: Int]) -> String? {
        guard let index = columnMap[.message], index < fields.count else { return nil }
        let message = fields[index].trimmingCharacters(in: .whitespaces)
        return unescapeCSVField(message)
    }

    private func unescapeCSVField(_ field: String) -> String {
        var result = field

        // Remove outer quotes if present
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
        }

        // Convert double quotes to single quotes
        result = result.replacingOccurrences(of: "\"\"", with: "\"")

        return result
    }

    private func parseSensorData(from fields: [String], columnMap: [CSVColumn: Int], rowNumber: Int) throws -> SensorData {
        // Parse timestamp
        let timestamp = try parseTimestamp(from: fields, columnMap: columnMap, rowNumber: rowNumber)

        // Parse PPG data
        let ppgIR = try parseInt32(fields, columnMap, .ppgIR, rowNumber: rowNumber)
        let ppgRed = try parseInt32(fields, columnMap, .ppgRed, rowNumber: rowNumber)
        let ppgGreen = try parseInt32(fields, columnMap, .ppgGreen, rowNumber: rowNumber)

        // Parse accelerometer data
        let accelX = try parseInt16(fields, columnMap, .accelX, rowNumber: rowNumber)
        let accelY = try parseInt16(fields, columnMap, .accelY, rowNumber: rowNumber)
        let accelZ = try parseInt16(fields, columnMap, .accelZ, rowNumber: rowNumber)

        // Parse temperature
        let tempCelsius = try parseDouble(fields, columnMap, .temperature, rowNumber: rowNumber)

        // Parse battery
        let batteryPercentage = try parseInt(fields, columnMap, .battery, rowNumber: rowNumber)

        // Parse optional heart rate
        var heartRate: HeartRateData?
        if let bpm = parseOptionalDouble(fields, columnMap, .heartRateBPM),
           let quality = parseOptionalDouble(fields, columnMap, .heartRateQuality) {
            heartRate = HeartRateData(bpm: bpm, quality: quality, timestamp: timestamp)
        }

        // Parse optional SpO2
        var spo2: SpO2Data?
        if let percentage = parseOptionalDouble(fields, columnMap, .spo2Percentage),
           let quality = parseOptionalDouble(fields, columnMap, .spo2Quality) {
            spo2 = SpO2Data(percentage: percentage, quality: quality, timestamp: timestamp)
        }

        return SensorData(
            timestamp: timestamp,
            ppg: PPGData(red: ppgRed, ir: ppgIR, green: ppgGreen, timestamp: timestamp),
            accelerometer: AccelerometerData(x: accelX, y: accelY, z: accelZ, timestamp: timestamp),
            temperature: TemperatureData(celsius: tempCelsius, timestamp: timestamp),
            battery: BatteryData(percentage: batteryPercentage, timestamp: timestamp),
            heartRate: heartRate,
            spo2: spo2
        )
    }

    private func parseTimestamp(from fields: [String], columnMap: [CSVColumn: Int], rowNumber: Int) throws -> Date {
        guard let index = columnMap[.timestamp], index < fields.count else {
            throw CSVError.invalidTimestamp(row: rowNumber, value: "")
        }

        let timestampString = fields[index].trimmingCharacters(in: .whitespaces)

        // Try primary format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = configuration.dateFormat
        if let date = dateFormatter.date(from: timestampString) {
            return date
        }

        // Try alternate formats
        for format in configuration.alternateDateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: timestampString) {
                return date
            }
        }

        // Try ISO8601
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: timestampString) {
            return date
        }

        throw CSVError.invalidTimestamp(row: rowNumber, value: timestampString)
    }

    private func parseInt32(_ fields: [String], _ columnMap: [CSVColumn: Int], _ column: CSVColumn, rowNumber: Int) throws -> Int32 {
        guard let index = columnMap[column], index < fields.count else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: "")
        }
        let value = fields[index].trimmingCharacters(in: .whitespaces)
        guard let result = Int32(value) else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: value)
        }
        return result
    }

    private func parseInt16(_ fields: [String], _ columnMap: [CSVColumn: Int], _ column: CSVColumn, rowNumber: Int) throws -> Int16 {
        guard let index = columnMap[column], index < fields.count else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: "")
        }
        let value = fields[index].trimmingCharacters(in: .whitespaces)
        guard let result = Int16(value) else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: value)
        }
        return result
    }

    private func parseInt(_ fields: [String], _ columnMap: [CSVColumn: Int], _ column: CSVColumn, rowNumber: Int) throws -> Int {
        guard let index = columnMap[column], index < fields.count else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: "")
        }
        let value = fields[index].trimmingCharacters(in: .whitespaces)
        guard let result = Int(value) else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: value)
        }
        return result
    }

    private func parseDouble(_ fields: [String], _ columnMap: [CSVColumn: Int], _ column: CSVColumn, rowNumber: Int) throws -> Double {
        guard let index = columnMap[column], index < fields.count else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: "")
        }
        let value = fields[index].trimmingCharacters(in: .whitespaces)
        guard let result = Double(value) else {
            throw CSVError.invalidValue(row: rowNumber, column: column, value: value)
        }
        return result
    }

    private func parseOptionalDouble(_ fields: [String], _ columnMap: [CSVColumn: Int], _ column: CSVColumn) -> Double? {
        guard let index = columnMap[column], index < fields.count else { return nil }
        let value = fields[index].trimmingCharacters(in: .whitespaces)
        return Double(value)
    }
}
