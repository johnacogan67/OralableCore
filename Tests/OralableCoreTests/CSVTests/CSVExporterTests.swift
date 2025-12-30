//
//  CSVExporterTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//

import XCTest
@testable import OralableCore

final class CSVExporterTests: XCTestCase {

    // MARK: - Test Data

    func createSampleSensorData() -> SensorData {
        return SensorData(
            timestamp: Date(timeIntervalSince1970: 1735500000),  // Fixed timestamp for testing
            ppg: PPGData(red: 100000, ir: 150000, green: 120000),
            accelerometer: AccelerometerData(x: 100, y: 200, z: 300),
            temperature: TemperatureData(celsius: 36.5),
            battery: BatteryData(percentage: 85),
            heartRate: HeartRateData(bpm: 72.0, quality: 0.95),
            spo2: SpO2Data(percentage: 98.0, quality: 0.92)
        )
    }

    // MARK: - Export Tests

    func testExportWithDefaultConfiguration() {
        let exporter = CSVExporter()
        let data = [createSampleSensorData()]

        let csv = exporter.generateCSV(from: data)

        // Check header is present
        XCTAssertTrue(csv.hasPrefix("Timestamp,"))
        XCTAssertTrue(csv.contains("PPG_IR"))
        XCTAssertTrue(csv.contains("HeartRate_BPM"))

        // Check data row is present
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)  // Header + 1 data row
    }

    func testExportWithoutHeader() {
        let config = CSVExportConfiguration(includeHeader: false)
        let exporter = CSVExporter(configuration: config)
        let data = [createSampleSensorData()]

        let csv = exporter.generateCSV(from: data)

        // Should not start with header
        XCTAssertFalse(csv.hasPrefix("Timestamp,"))

        // Should have only 1 line
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1)
    }

    func testExportWithMinimalColumns() {
        let config = CSVExportConfiguration.minimal
        let exporter = CSVExporter(configuration: config)
        let data = [createSampleSensorData()]

        let csv = exporter.generateCSV(from: data)

        // Check minimal columns are present
        XCTAssertTrue(csv.contains("Timestamp"))
        XCTAssertTrue(csv.contains("PPG_IR"))
        XCTAssertTrue(csv.contains("Temp_C"))

        // Check non-minimal columns are absent
        XCTAssertFalse(csv.contains("Accel_X"))
        XCTAssertFalse(csv.contains("HeartRate_BPM"))
    }

    func testExportMultipleRows() {
        let exporter = CSVExporter()
        let data = [
            createSampleSensorData(),
            createSampleSensorData(),
            createSampleSensorData()
        ]

        let csv = exporter.generateCSV(from: data)
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 4)  // Header + 3 data rows
    }

    func testExportWithLogs() {
        let exporter = CSVExporter()
        let data = [createSampleSensorData()]
        let logs = ["Test log message"]

        let csv = exporter.generateCSV(from: data, logs: logs)
        let lines = csv.components(separatedBy: "\n")

        // Should have header + data row + log row
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(csv.contains("Test log message"))
    }

    func testExportEscapesSpecialCharacters() {
        let exporter = CSVExporter()
        let data = [createSampleSensorData()]
        let logs = ["Message with, comma", "Message with \"quotes\""]

        let csv = exporter.generateCSV(from: data, logs: logs)

        // Commas should be escaped with quotes
        XCTAssertTrue(csv.contains("\"Message with, comma\""))

        // Quotes should be doubled
        XCTAssertTrue(csv.contains("\"Message with \"\"quotes\"\"\""))
    }

    func testExportEmptyData() {
        let exporter = CSVExporter()
        let data: [SensorData] = []

        let csv = exporter.generateCSV(from: data)

        // Should only have header
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1)
    }

    // MARK: - Export Summary Tests

    func testExportSummary() {
        let exporter = CSVExporter()
        let data = [createSampleSensorData(), createSampleSensorData()]
        let logs = ["Log 1", "Log 2", "Log 3"]

        let summary = exporter.getExportSummary(sensorData: data, logs: logs)

        XCTAssertEqual(summary.sensorDataCount, 2)
        XCTAssertEqual(summary.logCount, 3)
        XCTAssertFalse(summary.estimatedSize.isEmpty)
        XCTAssertEqual(summary.columns.count, CSVColumn.standardOrder.count)
    }

    // MARK: - Template Tests

    func testGenerateTemplate() {
        let template = CSVExporter.generateTemplate()

        XCTAssertTrue(template.contains("Timestamp"))
        XCTAssertTrue(template.contains("Sample measurement"))
        XCTAssertTrue(template.contains("Log entry without sensor data"))

        let lines = template.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)  // Header + sample + log-only
    }

    // MARK: - Historical Data Tests

    func testExportHistoricalData() {
        let exporter = CSVExporter()
        let dataPoints = [
            HistoricalDataPoint(
                timestamp: Date(),
                averageHeartRate: 72.0,
                heartRateQuality: 0.9,
                averageSpO2: 98.0,
                spo2Quality: 0.85,
                averageTemperature: 36.5,
                averageBattery: 80,
                movementIntensity: 100.0,
                movementVariability: 10.0
            )
        ]

        let csv = exporter.generateCSV(from: dataPoints)

        XCTAssertTrue(csv.contains("Avg_HeartRate"))
        XCTAssertTrue(csv.contains("Movement_Intensity"))

        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)  // Header + 1 data row
    }
}
