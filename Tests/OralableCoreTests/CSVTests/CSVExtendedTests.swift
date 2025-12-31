//
//  CSVExtendedTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for CSV types: CSVColumn, CSVConfiguration, CSVError, CSVModels
//

import XCTest
@testable import OralableCore

final class CSVExtendedTests: XCTestCase {

    // MARK: - CSVColumn Tests

    func testCSVColumnRawValues() {
        XCTAssertEqual(CSVColumn.timestamp.rawValue, "Timestamp")
        XCTAssertEqual(CSVColumn.ppgIR.rawValue, "PPG_IR")
        XCTAssertEqual(CSVColumn.ppgRed.rawValue, "PPG_Red")
        XCTAssertEqual(CSVColumn.ppgGreen.rawValue, "PPG_Green")
        XCTAssertEqual(CSVColumn.accelX.rawValue, "Accel_X")
        XCTAssertEqual(CSVColumn.accelY.rawValue, "Accel_Y")
        XCTAssertEqual(CSVColumn.accelZ.rawValue, "Accel_Z")
        XCTAssertEqual(CSVColumn.temperature.rawValue, "Temp_C")
        XCTAssertEqual(CSVColumn.battery.rawValue, "Battery_%")
        XCTAssertEqual(CSVColumn.heartRateBPM.rawValue, "HeartRate_BPM")
        XCTAssertEqual(CSVColumn.heartRateQuality.rawValue, "HeartRate_Quality")
        XCTAssertEqual(CSVColumn.spo2Percentage.rawValue, "SpO2_%")
        XCTAssertEqual(CSVColumn.spo2Quality.rawValue, "SpO2_Quality")
        XCTAssertEqual(CSVColumn.message.rawValue, "Message")
    }

    func testCSVColumnDisplayNames() {
        XCTAssertEqual(CSVColumn.timestamp.displayName, "Timestamp")
        XCTAssertEqual(CSVColumn.ppgIR.displayName, "PPG Infrared")
        XCTAssertEqual(CSVColumn.ppgRed.displayName, "PPG Red")
        XCTAssertEqual(CSVColumn.ppgGreen.displayName, "PPG Green")
        XCTAssertEqual(CSVColumn.accelX.displayName, "Accelerometer X")
        XCTAssertEqual(CSVColumn.temperature.displayName, "Temperature (°C)")
        XCTAssertEqual(CSVColumn.battery.displayName, "Battery (%)")
        XCTAssertEqual(CSVColumn.heartRateBPM.displayName, "Heart Rate (BPM)")
        XCTAssertEqual(CSVColumn.spo2Percentage.displayName, "SpO2 (%)")
    }

    func testCSVColumnDataTypes() {
        XCTAssertEqual(CSVColumn.timestamp.dataType, "Date/Time (yyyy-MM-dd HH:mm:ss.SSS)")
        XCTAssertEqual(CSVColumn.ppgIR.dataType, "Int32")
        XCTAssertEqual(CSVColumn.accelX.dataType, "Int16")
        XCTAssertEqual(CSVColumn.temperature.dataType, "Double")
        XCTAssertEqual(CSVColumn.battery.dataType, "Int (0-100)")
        XCTAssertEqual(CSVColumn.heartRateBPM.dataType, "Double (optional)")
        XCTAssertEqual(CSVColumn.heartRateQuality.dataType, "Double 0.0-1.0 (optional)")
        XCTAssertEqual(CSVColumn.message.dataType, "String (optional)")
    }

    func testCSVColumnIsRequired() {
        // Required columns
        XCTAssertTrue(CSVColumn.timestamp.isRequired)
        XCTAssertTrue(CSVColumn.ppgIR.isRequired)
        XCTAssertTrue(CSVColumn.ppgRed.isRequired)
        XCTAssertTrue(CSVColumn.ppgGreen.isRequired)
        XCTAssertTrue(CSVColumn.accelX.isRequired)
        XCTAssertTrue(CSVColumn.accelY.isRequired)
        XCTAssertTrue(CSVColumn.accelZ.isRequired)
        XCTAssertTrue(CSVColumn.temperature.isRequired)
        XCTAssertTrue(CSVColumn.battery.isRequired)

        // Optional columns
        XCTAssertFalse(CSVColumn.heartRateBPM.isRequired)
        XCTAssertFalse(CSVColumn.heartRateQuality.isRequired)
        XCTAssertFalse(CSVColumn.spo2Percentage.isRequired)
        XCTAssertFalse(CSVColumn.spo2Quality.isRequired)
        XCTAssertFalse(CSVColumn.message.isRequired)
    }

    func testCSVColumnGroups() {
        XCTAssertEqual(CSVColumn.timestamp.group, .core)
        XCTAssertEqual(CSVColumn.ppgIR.group, .ppg)
        XCTAssertEqual(CSVColumn.ppgRed.group, .ppg)
        XCTAssertEqual(CSVColumn.ppgGreen.group, .ppg)
        XCTAssertEqual(CSVColumn.accelX.group, .accelerometer)
        XCTAssertEqual(CSVColumn.accelY.group, .accelerometer)
        XCTAssertEqual(CSVColumn.accelZ.group, .accelerometer)
        XCTAssertEqual(CSVColumn.temperature.group, .temperature)
        XCTAssertEqual(CSVColumn.battery.group, .battery)
        XCTAssertEqual(CSVColumn.heartRateBPM.group, .heartRate)
        XCTAssertEqual(CSVColumn.heartRateQuality.group, .heartRate)
        XCTAssertEqual(CSVColumn.spo2Percentage.group, .spo2)
        XCTAssertEqual(CSVColumn.spo2Quality.group, .spo2)
        XCTAssertEqual(CSVColumn.message.group, .log)
    }

    func testCSVColumnStandardOrder() {
        let order = CSVColumn.standardOrder

        XCTAssertEqual(order.count, 14)
        XCTAssertEqual(order.first, .timestamp)
        XCTAssertEqual(order.last, .message)

        // Verify order includes all expected columns
        XCTAssertTrue(order.contains(.ppgIR))
        XCTAssertTrue(order.contains(.heartRateBPM))
        XCTAssertTrue(order.contains(.spo2Percentage))
    }

    func testCSVColumnRequiredColumns() {
        let required = CSVColumn.requiredColumns

        XCTAssertEqual(required.count, 9)
        XCTAssertTrue(required.allSatisfy { $0.isRequired })
        XCTAssertTrue(required.contains(.timestamp))
        XCTAssertFalse(required.contains(.heartRateBPM))
    }

    func testCSVColumnAllCases() {
        XCTAssertEqual(CSVColumn.allCases.count, 14)
    }

    // MARK: - CSVColumnGroup Tests

    func testCSVColumnGroupRawValues() {
        XCTAssertEqual(CSVColumnGroup.core.rawValue, "Core")
        XCTAssertEqual(CSVColumnGroup.ppg.rawValue, "PPG")
        XCTAssertEqual(CSVColumnGroup.accelerometer.rawValue, "Accelerometer")
        XCTAssertEqual(CSVColumnGroup.temperature.rawValue, "Temperature")
        XCTAssertEqual(CSVColumnGroup.battery.rawValue, "Battery")
        XCTAssertEqual(CSVColumnGroup.heartRate.rawValue, "Heart Rate")
        XCTAssertEqual(CSVColumnGroup.spo2.rawValue, "SpO2")
        XCTAssertEqual(CSVColumnGroup.log.rawValue, "Log")
    }

    func testCSVColumnGroupColumns() {
        XCTAssertEqual(CSVColumnGroup.core.columns, [.timestamp])
        XCTAssertEqual(CSVColumnGroup.ppg.columns, [.ppgIR, .ppgRed, .ppgGreen])
        XCTAssertEqual(CSVColumnGroup.accelerometer.columns, [.accelX, .accelY, .accelZ])
        XCTAssertEqual(CSVColumnGroup.temperature.columns, [.temperature])
        XCTAssertEqual(CSVColumnGroup.battery.columns, [.battery])
        XCTAssertEqual(CSVColumnGroup.heartRate.columns, [.heartRateBPM, .heartRateQuality])
        XCTAssertEqual(CSVColumnGroup.spo2.columns, [.spo2Percentage, .spo2Quality])
        XCTAssertEqual(CSVColumnGroup.log.columns, [.message])
    }

    func testCSVColumnGroupAllCases() {
        XCTAssertEqual(CSVColumnGroup.allCases.count, 8)
    }

    // MARK: - CSVExportConfiguration Tests

    func testCSVExportConfigurationDefault() {
        let config = CSVExportConfiguration.default

        XCTAssertEqual(config.columns, CSVColumn.standardOrder)
        XCTAssertEqual(config.dateFormat, "yyyy-MM-dd HH:mm:ss.SSS")
        XCTAssertTrue(config.includeHeader)
        XCTAssertEqual(config.separator, ",")
        XCTAssertEqual(config.lineEnding, "\n")
        XCTAssertEqual(config.decimalPrecision, 3)
    }

    func testCSVExportConfigurationMinimal() {
        let config = CSVExportConfiguration.minimal

        XCTAssertEqual(config.columns.count, 6)
        XCTAssertTrue(config.columns.contains(.timestamp))
        XCTAssertTrue(config.columns.contains(.ppgIR))
        XCTAssertTrue(config.columns.contains(.ppgRed))
        XCTAssertTrue(config.columns.contains(.ppgGreen))
        XCTAssertTrue(config.columns.contains(.temperature))
        XCTAssertTrue(config.columns.contains(.battery))
        XCTAssertFalse(config.columns.contains(.heartRateBPM))
    }

    func testCSVExportConfigurationFull() {
        let config = CSVExportConfiguration.full

        XCTAssertEqual(config.columns, CSVColumn.standardOrder)
    }

    func testCSVExportConfigurationCustom() {
        let config = CSVExportConfiguration(
            columns: [.timestamp, .heartRateBPM],
            dateFormat: "yyyy-MM-dd",
            includeHeader: false,
            separator: ";",
            lineEnding: "\r\n",
            decimalPrecision: 2
        )

        XCTAssertEqual(config.columns, [.timestamp, .heartRateBPM])
        XCTAssertEqual(config.dateFormat, "yyyy-MM-dd")
        XCTAssertFalse(config.includeHeader)
        XCTAssertEqual(config.separator, ";")
        XCTAssertEqual(config.lineEnding, "\r\n")
        XCTAssertEqual(config.decimalPrecision, 2)
    }

    func testCSVExportConfigurationWithGroups() {
        let config = CSVExportConfiguration.with(groups: [.ppg, .heartRate])

        XCTAssertTrue(config.columns.contains(.timestamp)) // Always included
        XCTAssertTrue(config.columns.contains(.ppgIR))
        XCTAssertTrue(config.columns.contains(.ppgRed))
        XCTAssertTrue(config.columns.contains(.ppgGreen))
        XCTAssertTrue(config.columns.contains(.heartRateBPM))
        XCTAssertTrue(config.columns.contains(.heartRateQuality))
        XCTAssertFalse(config.columns.contains(.accelX))
        XCTAssertFalse(config.columns.contains(.temperature))
    }

    func testCSVExportConfigurationWithoutMovement() {
        let config = CSVExportConfiguration.withoutMovement()

        XCTAssertFalse(config.columns.contains(.accelX))
        XCTAssertFalse(config.columns.contains(.accelY))
        XCTAssertFalse(config.columns.contains(.accelZ))
    }

    // MARK: - CSVImportConfiguration Tests

    func testCSVImportConfigurationDefault() {
        let config = CSVImportConfiguration.default

        XCTAssertEqual(config.dateFormat, "yyyy-MM-dd HH:mm:ss.SSS")
        XCTAssertEqual(config.alternateDateFormats.count, 4)
        XCTAssertEqual(config.separator, ",")
        XCTAssertTrue(config.hasHeader)
        XCTAssertTrue(config.skipInvalidRows)
        XCTAssertEqual(config.maxWarnings, 100)
    }

    func testCSVImportConfigurationStrict() {
        let config = CSVImportConfiguration.strict

        XCTAssertFalse(config.skipInvalidRows)
        XCTAssertEqual(config.maxWarnings, 0)
    }

    func testCSVImportConfigurationLenient() {
        let config = CSVImportConfiguration.lenient

        XCTAssertTrue(config.skipInvalidRows)
        XCTAssertEqual(config.maxWarnings, 1000)
    }

    func testCSVImportConfigurationCustom() {
        let config = CSVImportConfiguration(
            dateFormat: "dd/MM/yyyy",
            alternateDateFormats: ["MM-dd-yyyy"],
            separator: ";",
            hasHeader: false,
            skipInvalidRows: false,
            maxWarnings: 50
        )

        XCTAssertEqual(config.dateFormat, "dd/MM/yyyy")
        XCTAssertEqual(config.alternateDateFormats, ["MM-dd-yyyy"])
        XCTAssertEqual(config.separator, ";")
        XCTAssertFalse(config.hasHeader)
        XCTAssertFalse(config.skipInvalidRows)
        XCTAssertEqual(config.maxWarnings, 50)
    }

    // MARK: - CSVError Tests

    func testCSVErrorEmptyFile() {
        let error = CSVError.emptyFile

        XCTAssertEqual(error.errorDescription, "The CSV file is empty")
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testCSVErrorMissingRequiredColumns() {
        let error = CSVError.missingRequiredColumns([.timestamp, .ppgIR])

        XCTAssertTrue(error.errorDescription!.contains("Missing required columns"))
        XCTAssertTrue(error.errorDescription!.contains("Timestamp"))
        XCTAssertTrue(error.errorDescription!.contains("PPG_IR"))
    }

    func testCSVErrorInvalidFormat() {
        let error = CSVError.invalidFormat("Missing header row")

        XCTAssertTrue(error.errorDescription!.contains("Invalid CSV format"))
        XCTAssertTrue(error.errorDescription!.contains("Missing header row"))
    }

    func testCSVErrorInvalidTimestamp() {
        let error = CSVError.invalidTimestamp(row: 5, value: "not-a-date")

        XCTAssertTrue(error.errorDescription!.contains("row 5"))
        XCTAssertTrue(error.errorDescription!.contains("not-a-date"))
    }

    func testCSVErrorInvalidValue() {
        let error = CSVError.invalidValue(row: 10, column: .heartRateBPM, value: "abc")

        XCTAssertTrue(error.errorDescription!.contains("row 10"))
        XCTAssertTrue(error.errorDescription!.contains("HeartRate_BPM"))
        XCTAssertTrue(error.errorDescription!.contains("abc"))
    }

    func testCSVErrorTooManyWarnings() {
        let error = CSVError.tooManyWarnings(count: 100)

        XCTAssertTrue(error.errorDescription!.contains("100"))
    }

    func testCSVErrorMalformedRow() {
        let error = CSVError.malformedRow(row: 3, reason: "Unbalanced quotes")

        XCTAssertTrue(error.errorDescription!.contains("row 3"))
        XCTAssertTrue(error.errorDescription!.contains("Unbalanced quotes"))
    }

    func testCSVErrorNoDataToExport() {
        let error = CSVError.noDataToExport

        XCTAssertEqual(error.errorDescription, "No data available to export")
    }

    func testCSVErrorEncodingFailed() {
        let error = CSVError.encodingFailed

        XCTAssertEqual(error.errorDescription, "Failed to encode CSV content")
    }

    func testCSVErrorFileNotFound() {
        let error = CSVError.fileNotFound("/path/to/file.csv")

        XCTAssertTrue(error.errorDescription!.contains("/path/to/file.csv"))
    }

    func testCSVErrorFileReadError() {
        let error = CSVError.fileReadError("Permission denied")

        XCTAssertTrue(error.errorDescription!.contains("Permission denied"))
    }

    func testCSVErrorFileWriteError() {
        let error = CSVError.fileWriteError("Disk full")

        XCTAssertTrue(error.errorDescription!.contains("Disk full"))
    }

    func testCSVErrorRecoverySuggestions() {
        // Verify all errors have recovery suggestions
        let errors: [CSVError] = [
            .emptyFile,
            .missingRequiredColumns([.timestamp]),
            .invalidFormat("test"),
            .invalidTimestamp(row: 1, value: "test"),
            .invalidValue(row: 1, column: .battery, value: "test"),
            .tooManyWarnings(count: 10),
            .malformedRow(row: 1, reason: "test"),
            .noDataToExport,
            .encodingFailed,
            .fileNotFound("test"),
            .fileReadError("test"),
            .fileWriteError("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.recoverySuggestion, "Missing recovery suggestion for \(error)")
        }
    }

    // MARK: - CSVImportWarning Tests

    func testCSVImportWarningCreation() {
        let warning = CSVImportWarning(
            row: 5,
            type: .invalidValue,
            message: "Invalid heart rate value",
            rowData: "2025-01-01,abc,..."
        )

        XCTAssertEqual(warning.row, 5)
        XCTAssertEqual(warning.type, .invalidValue)
        XCTAssertEqual(warning.message, "Invalid heart rate value")
        XCTAssertEqual(warning.rowData, "2025-01-01,abc,...")
    }

    func testCSVImportWarningWithoutRowData() {
        let warning = CSVImportWarning(
            row: 3,
            type: .unknownColumn,
            message: "Unknown column: Extra"
        )

        XCTAssertNil(warning.rowData)
    }

    func testCSVImportWarningTypeDisplayNames() {
        XCTAssertEqual(CSVImportWarning.WarningType.invalidSensorType.displayName, "Invalid Sensor Type")
        XCTAssertEqual(CSVImportWarning.WarningType.invalidValue.displayName, "Invalid Value")
        XCTAssertEqual(CSVImportWarning.WarningType.invalidTimestamp.displayName, "Invalid Timestamp")
        XCTAssertEqual(CSVImportWarning.WarningType.invalidQuality.displayName, "Invalid Quality")
        XCTAssertEqual(CSVImportWarning.WarningType.malformedRow.displayName, "Malformed Row")
        XCTAssertEqual(CSVImportWarning.WarningType.unknownColumn.displayName, "Unknown Column")
        XCTAssertEqual(CSVImportWarning.WarningType.missingOptionalValue.displayName, "Missing Optional Value")
    }

    func testCSVImportWarningTypeAllCases() {
        XCTAssertEqual(CSVImportWarning.WarningType.allCases.count, 7)
    }

    // MARK: - CSVExportSummary Tests

    func testCSVExportSummaryCreation() {
        let summary = CSVExportSummary(
            sensorDataCount: 1000,
            logCount: 50,
            dateRange: "2025-01-01 to 2025-01-02",
            estimatedSize: "256 KB",
            columns: [.timestamp, .heartRateBPM]
        )

        XCTAssertEqual(summary.sensorDataCount, 1000)
        XCTAssertEqual(summary.logCount, 50)
        XCTAssertEqual(summary.dateRange, "2025-01-01 to 2025-01-02")
        XCTAssertEqual(summary.estimatedSize, "256 KB")
        XCTAssertEqual(summary.columns, [.timestamp, .heartRateBPM])
    }

    // MARK: - CSVValidationResult Tests

    func testCSVValidationResultValid() {
        let result = CSVValidationResult(
            isValid: true,
            estimatedDataPoints: 500,
            detectedColumns: ["Timestamp", "PPG_IR", "PPG_Red"],
            fileSize: 102400
        )

        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.estimatedDataPoints, 500)
        XCTAssertEqual(result.detectedColumns.count, 3)
        XCTAssertTrue(result.missingColumns.isEmpty)
        XCTAssertTrue(result.unknownColumns.isEmpty)
        XCTAssertEqual(result.fileSize, 102400)
    }

    func testCSVValidationResultInvalid() {
        let result = CSVValidationResult(
            isValid: false,
            errorMessage: "Missing required columns",
            missingColumns: [.timestamp, .ppgIR],
            unknownColumns: ["ExtraColumn"]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Missing required columns")
        XCTAssertEqual(result.missingColumns, [.timestamp, .ppgIR])
        XCTAssertEqual(result.unknownColumns, ["ExtraColumn"])
    }

    // MARK: - CSVImportStatistics Tests

    func testCSVImportStatisticsSuccessRate() {
        let stats = CSVImportStatistics(
            totalRows: 100,
            importedRows: 95,
            skippedRows: 3,
            failedRows: 2
        )

        XCTAssertEqual(stats.successRate, 95.0, accuracy: 0.01)
    }

    func testCSVImportStatisticsZeroRows() {
        let stats = CSVImportStatistics(
            totalRows: 0,
            importedRows: 0,
            skippedRows: 0,
            failedRows: 0
        )

        XCTAssertEqual(stats.successRate, 0.0)
    }

    func testCSVImportStatisticsWithDateRange() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour later
        let dateRange = DateInterval(start: start, end: end)

        let stats = CSVImportStatistics(
            totalRows: 50,
            importedRows: 50,
            skippedRows: 0,
            failedRows: 0,
            dateRange: dateRange
        )

        XCTAssertNotNil(stats.dateRange)
        XCTAssertEqual(stats.dateRange!.duration, 3600, accuracy: 1.0)
    }

    // MARK: - CSVImportResult Tests

    func testCSVImportResultSuccessful() {
        let sensorData = [createMockSensorData()]
        let stats = CSVImportStatistics(
            totalRows: 1,
            importedRows: 1,
            skippedRows: 0,
            failedRows: 0
        )

        let result = CSVImportResult(
            sensorData: sensorData,
            logs: [],
            warnings: [],
            statistics: stats
        )

        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.summaryText, "Imported 1 readings successfully")
    }

    func testCSVImportResultWithWarnings() {
        let sensorData = [createMockSensorData(), createMockSensorData()]
        let warnings = [
            CSVImportWarning(row: 3, type: .invalidValue, message: "Bad value")
        ]
        let stats = CSVImportStatistics(
            totalRows: 3,
            importedRows: 2,
            skippedRows: 0,
            failedRows: 1
        )

        let result = CSVImportResult(
            sensorData: sensorData,
            logs: ["Log entry 1"],
            warnings: warnings,
            statistics: stats
        )

        XCTAssertTrue(result.isSuccessful)
        XCTAssertTrue(result.summaryText.contains("2 readings"))
        XCTAssertTrue(result.summaryText.contains("1 warnings"))
    }

    func testCSVImportResultFailed() {
        let stats = CSVImportStatistics(
            totalRows: 10,
            importedRows: 0,
            skippedRows: 0,
            failedRows: 10
        )

        let result = CSVImportResult(
            sensorData: [],
            logs: [],
            warnings: [],
            statistics: stats
        )

        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.summaryText.contains("failed"))
    }

    // MARK: - CSVFormatDocumentation Tests

    func testCSVFormatDocumentationExpectedFormat() {
        let format = CSVFormatDocumentation.expectedFormat

        XCTAssertTrue(format.contains("Expected CSV Format"))
        XCTAssertTrue(format.contains("Header Row"))
        XCTAssertTrue(format.contains("Timestamp"))
        XCTAssertTrue(format.contains("PPG_IR"))
        XCTAssertTrue(format.contains("yyyy-MM-dd HH:mm:ss.SSS"))
    }

    func testCSVFormatDocumentationColumnDocumentation() {
        let docs = CSVFormatDocumentation.columnDocumentation

        XCTAssertEqual(docs.count, CSVColumn.standardOrder.count)

        // Check first column
        let firstDoc = docs[0]
        XCTAssertEqual(firstDoc.column, .timestamp)
        XCTAssertEqual(firstDoc.type, "Date/Time (yyyy-MM-dd HH:mm:ss.SSS)")
        XCTAssertTrue(firstDoc.required)

        // Find optional column
        let heartRateDoc = docs.first { $0.column == .heartRateBPM }
        XCTAssertNotNil(heartRateDoc)
        XCTAssertFalse(heartRateDoc!.required)
    }

    // MARK: - Helper Methods

    private func createMockSensorData() -> SensorData {
        SensorData(
            ppg: PPGData(red: 40000, ir: 50000, green: 30000, timestamp: Date()),
            accelerometer: AccelerometerData(x: 0, y: 0, z: 16384, timestamp: Date()),
            temperature: TemperatureData(celsius: 36.5, timestamp: Date()),
            battery: BatteryData(percentage: 85, timestamp: Date()),
            heartRate: HeartRateData(bpm: 72, quality: 0.9, timestamp: Date()),
            spo2: SpO2Data(percentage: 98, quality: 0.85, timestamp: Date()),
            deviceType: .oralable
        )
    }
}
