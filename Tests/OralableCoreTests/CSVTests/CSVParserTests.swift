//
//  CSVParserTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//

import XCTest
@testable import OralableCore

final class CSVParserTests: XCTestCase {

    // MARK: - Valid CSV Content

    let validCSV = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,Test message
2025-12-30 10:00:01.000,150100,100100,120100,101,201,301,36.6,84,73.0,0.94,97.5,0.91,
"""

    let csvWithLogOnly = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,
2025-12-30 10:00:01.000,,,,,,,,,,,,,Log only entry
"""

    // MARK: - Parse Tests

    func testParseValidCSV() throws {
        let parser = CSVParser()
        let result = try parser.parse(validCSV)

        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.sensorData.count, 2)
        XCTAssertEqual(result.warnings.count, 0)
    }

    func testParseSensorDataValues() throws {
        let parser = CSVParser()
        let result = try parser.parse(validCSV)

        let firstData = result.sensorData[0]

        XCTAssertEqual(firstData.ppg.ir, 150000)
        XCTAssertEqual(firstData.ppg.red, 100000)
        XCTAssertEqual(firstData.ppg.green, 120000)
        XCTAssertEqual(firstData.accelerometer.x, 100)
        XCTAssertEqual(firstData.accelerometer.y, 200)
        XCTAssertEqual(firstData.accelerometer.z, 300)
        XCTAssertEqual(firstData.temperature.celsius, 36.5, accuracy: 0.01)
        XCTAssertEqual(firstData.battery.percentage, 85)
        XCTAssertEqual(firstData.heartRate?.bpm, 72.0)
        XCTAssertEqual(firstData.heartRate!.quality, 0.95, accuracy: 0.01)
        XCTAssertEqual(firstData.spo2!.percentage, 98.0, accuracy: 0.01)
    }

    func testParseLogOnlyRows() throws {
        let parser = CSVParser()
        let result = try parser.parse(csvWithLogOnly)

        XCTAssertEqual(result.sensorData.count, 1)
        XCTAssertEqual(result.logs.count, 1)
        XCTAssertEqual(result.logs.first, "Log only entry")
        XCTAssertEqual(result.statistics.skippedRows, 1)
    }

    func testParseWithMessages() throws {
        let parser = CSVParser()
        let result = try parser.parse(validCSV)

        XCTAssertEqual(result.logs.count, 1)
        XCTAssertEqual(result.logs.first, "Test message")
    }

    func testParseEmptyFile() {
        let parser = CSVParser()

        XCTAssertThrowsError(try parser.parse("")) { error in
            guard case CSVError.emptyFile = error else {
                XCTFail("Expected emptyFile error")
                return
            }
        }
    }

    func testParseMissingRequiredColumns() {
        let parser = CSVParser(configuration: .strict)
        let invalidCSV = "Timestamp,PPG_IR\n2025-12-30 10:00:00.000,150000"

        XCTAssertThrowsError(try parser.parse(invalidCSV)) { error in
            if case CSVError.missingRequiredColumns(let columns) = error {
                XCTAssertTrue(columns.contains(.ppgRed))
                XCTAssertTrue(columns.contains(.ppgGreen))
            } else {
                XCTFail("Expected missingRequiredColumns error")
            }
        }
    }

    func testParseWithQuotedFields() throws {
        let csvWithQuotes = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,"Message with, comma"
"""

        let parser = CSVParser()
        let result = try parser.parse(csvWithQuotes)

        XCTAssertEqual(result.logs.first, "Message with, comma")
    }

    func testParseWithEscapedQuotes() throws {
        let csvWithEscapedQuotes = "Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message\n2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,\"He said \"\"hello\"\"\""

        let parser = CSVParser()
        let result = try parser.parse(csvWithEscapedQuotes)

        XCTAssertEqual(result.logs.first, "He said \"hello\"")
    }

    func testParseWithOptionalFieldsMissing() throws {
        let csvNoOptionals = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,,,,
"""

        let parser = CSVParser()
        let result = try parser.parse(csvNoOptionals)

        XCTAssertEqual(result.sensorData.count, 1)
        XCTAssertNil(result.sensorData.first?.heartRate)
        XCTAssertNil(result.sensorData.first?.spo2)
    }

    // MARK: - Validation Tests

    func testValidateValidCSV() {
        let parser = CSVParser()
        let result = parser.validate(validCSV)

        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.estimatedDataPoints, 2)
        XCTAssertTrue(result.missingColumns.isEmpty)
    }

    func testValidateMissingColumns() {
        let parser = CSVParser()
        let invalidCSV = "Timestamp,PPG_IR,SomeOtherColumn\n2025-12-30 10:00:00.000,150000,value"

        let result = parser.validate(invalidCSV)

        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.missingColumns.isEmpty)
        XCTAssertTrue(result.unknownColumns.contains("SomeOtherColumn"))
    }

    func testValidateEmptyFile() {
        let parser = CSVParser()
        let result = parser.validate("")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.estimatedDataPoints, 0)
    }

    // MARK: - Statistics Tests

    func testImportStatistics() throws {
        let parser = CSVParser()
        let result = try parser.parse(csvWithLogOnly)

        XCTAssertEqual(result.statistics.totalRows, 2)
        XCTAssertEqual(result.statistics.importedRows, 1)
        XCTAssertEqual(result.statistics.skippedRows, 1)
        XCTAssertEqual(result.statistics.failedRows, 0)
        XCTAssertNotNil(result.statistics.dateRange)
    }

    func testSuccessRate() throws {
        let parser = CSVParser()
        let result = try parser.parse(validCSV)

        XCTAssertEqual(result.statistics.successRate, 100.0, accuracy: 0.01)
    }

    // MARK: - Lenient Mode Tests

    func testLenientModeSkipsInvalidRows() throws {
        let csvWithInvalidRow = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,
invalid,not,a,valid,row
2025-12-30 10:00:02.000,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,
"""

        let parser = CSVParser(configuration: .lenient)
        let result = try parser.parse(csvWithInvalidRow)

        XCTAssertEqual(result.sensorData.count, 2)  // 2 valid rows
        XCTAssertEqual(result.warnings.count, 1)    // 1 invalid row warning
        XCTAssertEqual(result.statistics.failedRows, 1)
    }

    // MARK: - Date Format Tests

    func testParseMultipleDateFormats() throws {
        let csvWithDifferentDates = """
Timestamp,PPG_IR,PPG_Red,PPG_Green,Accel_X,Accel_Y,Accel_Z,Temp_C,Battery_%,HeartRate_BPM,HeartRate_Quality,SpO2_%,SpO2_Quality,Message
2025-12-30 10:00:00,150000,100000,120000,100,200,300,36.5,85,72.0,0.95,98.0,0.92,
"""

        let parser = CSVParser()
        let result = try parser.parse(csvWithDifferentDates)

        XCTAssertEqual(result.sensorData.count, 1)
    }
}
