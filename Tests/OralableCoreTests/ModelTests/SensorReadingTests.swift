//
//  SensorReadingTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for SensorReading and Array<SensorReading> extensions
//

import XCTest
@testable import OralableCore

final class SensorReadingComprehensiveTests: XCTestCase {

    // MARK: - Creation Tests

    func testSensorReadingCreation() {
        let timestamp = Date()
        let reading = SensorReading(
            sensorType: .heartRate,
            value: 72.0,
            timestamp: timestamp,
            deviceId: "test-device",
            quality: 0.95,
            rawMillivolts: 3800,
            frameNumber: 12345
        )

        XCTAssertNotNil(reading.id)
        XCTAssertEqual(reading.sensorType, .heartRate)
        XCTAssertEqual(reading.value, 72.0)
        XCTAssertEqual(reading.timestamp, timestamp)
        XCTAssertEqual(reading.deviceId, "test-device")
        XCTAssertEqual(reading.quality, 0.95)
        XCTAssertEqual(reading.rawMillivolts, 3800)
        XCTAssertEqual(reading.frameNumber, 12345)
    }

    func testSensorReadingMinimalCreation() {
        let reading = SensorReading(
            sensorType: .temperature,
            value: 36.8
        )

        XCTAssertNotNil(reading.id)
        XCTAssertEqual(reading.sensorType, .temperature)
        XCTAssertEqual(reading.value, 36.8)
        XCTAssertNil(reading.deviceId)
        XCTAssertNil(reading.quality)
        XCTAssertNil(reading.rawMillivolts)
        XCTAssertNil(reading.frameNumber)
    }

    func testSensorReadingCustomId() {
        let customId = UUID()
        let reading = SensorReading(
            id: customId,
            sensorType: .battery,
            value: 85.0
        )

        XCTAssertEqual(reading.id, customId)
    }

    // MARK: - Formatted Value Tests

    func testFormattedValueTemperature() {
        let reading = SensorReading(sensorType: .temperature, value: 36.85)
        XCTAssertEqual(reading.formattedValue, "36.9 °C")
    }

    func testFormattedValueHeartRate() {
        let reading = SensorReading(sensorType: .heartRate, value: 72.4)
        XCTAssertEqual(reading.formattedValue, "72 bpm")
    }

    func testFormattedValueSpO2() {
        let reading = SensorReading(sensorType: .spo2, value: 98.3)
        XCTAssertEqual(reading.formattedValue, "98 %")
    }

    func testFormattedValueBattery() {
        let reading = SensorReading(sensorType: .battery, value: 85.0)
        XCTAssertEqual(reading.formattedValue, "85 %")
    }

    func testFormattedValuePPG() {
        let reading = SensorReading(sensorType: .ppgInfrared, value: 150000.0)
        XCTAssertEqual(reading.formattedValue, "150000 ADC")
    }

    func testFormattedValueAccelerometer() {
        let reading = SensorReading(sensorType: .accelerometerX, value: 0.123456)
        XCTAssertEqual(reading.formattedValue, "0.123 g")
    }

    func testFormattedValueMuscleActivity() {
        let reading = SensorReading(sensorType: .muscleActivity, value: 0.75)
        XCTAssertEqual(reading.formattedValue, "0.8 µV")
    }

    // MARK: - isValid Tests - Heart Rate

    func testIsValidHeartRateTrue() {
        let reading = SensorReading(sensorType: .heartRate, value: 72.0)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidHeartRateLow() {
        let reading = SensorReading(sensorType: .heartRate, value: 25.0)
        XCTAssertFalse(reading.isValid) // Below 30
    }

    func testIsValidHeartRateHigh() {
        let reading = SensorReading(sensorType: .heartRate, value: 260.0)
        XCTAssertFalse(reading.isValid) // Above 250
    }

    func testIsValidHeartRateBoundary() {
        XCTAssertTrue(SensorReading(sensorType: .heartRate, value: 30.0).isValid)
        XCTAssertTrue(SensorReading(sensorType: .heartRate, value: 250.0).isValid)
    }

    // MARK: - isValid Tests - SpO2

    func testIsValidSpO2True() {
        let reading = SensorReading(sensorType: .spo2, value: 98.0)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidSpO2Low() {
        let reading = SensorReading(sensorType: .spo2, value: 45.0)
        XCTAssertFalse(reading.isValid) // Below 50
    }

    func testIsValidSpO2High() {
        let reading = SensorReading(sensorType: .spo2, value: 105.0)
        XCTAssertFalse(reading.isValid) // Above 100
    }

    // MARK: - isValid Tests - Temperature

    func testIsValidTemperatureTrue() {
        let reading = SensorReading(sensorType: .temperature, value: 36.8)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidTemperatureLow() {
        let reading = SensorReading(sensorType: .temperature, value: 15.0)
        XCTAssertFalse(reading.isValid) // Below 20
    }

    func testIsValidTemperatureHigh() {
        let reading = SensorReading(sensorType: .temperature, value: 50.0)
        XCTAssertFalse(reading.isValid) // Above 45
    }

    // MARK: - isValid Tests - Battery

    func testIsValidBatteryTrue() {
        let reading = SensorReading(sensorType: .battery, value: 85.0)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidBatteryNegative() {
        let reading = SensorReading(sensorType: .battery, value: -5.0)
        XCTAssertFalse(reading.isValid)
    }

    func testIsValidBatteryOver100() {
        let reading = SensorReading(sensorType: .battery, value: 105.0)
        XCTAssertFalse(reading.isValid)
    }

    // MARK: - isValid Tests - PPG

    func testIsValidPPGTrue() {
        let reading = SensorReading(sensorType: .ppgInfrared, value: 150000.0)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidPPGZero() {
        let reading = SensorReading(sensorType: .ppgRed, value: 0.0)
        XCTAssertTrue(reading.isValid) // 0 is valid for PPG
    }

    func testIsValidPPGNegative() {
        let reading = SensorReading(sensorType: .ppgGreen, value: -100.0)
        XCTAssertFalse(reading.isValid)
    }

    // MARK: - isValid Tests - Accelerometer

    func testIsValidAccelerometerTrue() {
        let reading = SensorReading(sensorType: .accelerometerX, value: 1.0)
        XCTAssertTrue(reading.isValid)
    }

    func testIsValidAccelerometerExtremePositive() {
        let reading = SensorReading(sensorType: .accelerometerY, value: 25.0)
        XCTAssertFalse(reading.isValid) // Above 20
    }

    func testIsValidAccelerometerExtremeNegative() {
        let reading = SensorReading(sensorType: .accelerometerZ, value: -25.0)
        XCTAssertFalse(reading.isValid) // Below -20
    }

    // MARK: - isValid Tests - Special Values

    func testIsValidNaN() {
        let reading = SensorReading(sensorType: .heartRate, value: Double.nan)
        XCTAssertFalse(reading.isValid)
    }

    func testIsValidInfinity() {
        let reading = SensorReading(sensorType: .temperature, value: Double.infinity)
        XCTAssertFalse(reading.isValid)
    }

    func testIsValidNegativeInfinity() {
        let reading = SensorReading(sensorType: .spo2, value: -Double.infinity)
        XCTAssertFalse(reading.isValid)
    }

    // MARK: - Mock Tests

    func testMockWithDefaultValue() {
        let mock = SensorReading.mock(sensorType: .heartRate)

        XCTAssertEqual(mock.sensorType, .heartRate)
        XCTAssertEqual(mock.deviceId, "mock-device")
        XCTAssertEqual(mock.quality, 0.95)
        XCTAssertTrue(mock.isValid)
    }

    func testMockWithCustomValue() {
        let mock = SensorReading.mock(sensorType: .temperature, value: 38.5, deviceId: "custom-device")

        XCTAssertEqual(mock.sensorType, .temperature)
        XCTAssertEqual(mock.value, 38.5)
        XCTAssertEqual(mock.deviceId, "custom-device")
    }

    func testMockAllSensorTypes() {
        for sensorType in SensorType.allCases {
            let mock = SensorReading.mock(sensorType: sensorType)
            XCTAssertEqual(mock.sensorType, sensorType)
            // Most mock values should be valid
            if sensorType != .emg && sensorType != .muscleActivity {
                XCTAssertTrue(mock.isValid, "Mock for \(sensorType) should be valid")
            }
        }
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let id = UUID()
        let timestamp = Date()
        let reading1 = SensorReading(
            id: id,
            sensorType: .heartRate,
            value: 72.0,
            timestamp: timestamp
        )
        let reading2 = SensorReading(
            id: id,
            sensorType: .heartRate,
            value: 72.0,
            timestamp: timestamp
        )

        XCTAssertEqual(reading1, reading2)
    }

    func testNotEqualDifferentId() {
        let reading1 = SensorReading(sensorType: .heartRate, value: 72.0)
        let reading2 = SensorReading(sensorType: .heartRate, value: 72.0)

        XCTAssertNotEqual(reading1, reading2)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let original = SensorReading(
            sensorType: .heartRate,
            value: 72.0,
            deviceId: "test-device",
            quality: 0.95,
            rawMillivolts: 3800,
            frameNumber: 12345
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SensorReading.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sensorType, original.sensorType)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.quality, original.quality)
        XCTAssertEqual(decoded.rawMillivolts, original.rawMillivolts)
        XCTAssertEqual(decoded.frameNumber, original.frameNumber)
    }

    // MARK: - Array Extension Tests - latest(for:)

    func testLatestForSensorType() {
        let now = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70.0, timestamp: now.addingTimeInterval(-60)),
            SensorReading(sensorType: .heartRate, value: 72.0, timestamp: now.addingTimeInterval(-30)),
            SensorReading(sensorType: .heartRate, value: 75.0, timestamp: now),
            SensorReading(sensorType: .temperature, value: 36.5, timestamp: now)
        ]

        let latest = readings.latest(for: .heartRate)

        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.value, 75.0)
    }

    func testLatestForSensorTypeNotFound() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 72.0)
        ]

        let latest = readings.latest(for: .spo2)

        XCTAssertNil(latest)
    }

    func testLatestForEmptyArray() {
        let readings: [SensorReading] = []

        let latest = readings.latest(for: .heartRate)

        XCTAssertNil(latest)
    }

    // MARK: - Array Extension Tests - readings(for:from:to:)

    func testReadingsInTimeRange() {
        let now = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70.0, timestamp: now.addingTimeInterval(-120)),
            SensorReading(sensorType: .heartRate, value: 72.0, timestamp: now.addingTimeInterval(-60)),
            SensorReading(sensorType: .heartRate, value: 75.0, timestamp: now),
            SensorReading(sensorType: .heartRate, value: 78.0, timestamp: now.addingTimeInterval(60))
        ]

        let result = readings.readings(
            for: .heartRate,
            from: now.addingTimeInterval(-90),
            to: now.addingTimeInterval(30)
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.value == 72.0 })
        XCTAssertTrue(result.contains { $0.value == 75.0 })
    }

    func testReadingsInTimeRangeEmpty() {
        let now = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 72.0, timestamp: now)
        ]

        let result = readings.readings(
            for: .heartRate,
            from: now.addingTimeInterval(-120),
            to: now.addingTimeInterval(-60)
        )

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Array Extension Tests - average(for:)

    func testAverageForSensorType() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70.0),
            SensorReading(sensorType: .heartRate, value: 72.0),
            SensorReading(sensorType: .heartRate, value: 74.0),
            SensorReading(sensorType: .temperature, value: 36.5)
        ]

        let average = readings.average(for: .heartRate)

        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 72.0, accuracy: 0.01)
    }

    func testAverageForSensorTypeWithInvalidReadings() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 72.0),
            SensorReading(sensorType: .heartRate, value: Double.nan), // Invalid
            SensorReading(sensorType: .heartRate, value: 74.0)
        ]

        let average = readings.average(for: .heartRate)

        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 73.0, accuracy: 0.01) // Only valid readings
    }

    func testAverageForSensorTypeNotFound() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 72.0)
        ]

        let average = readings.average(for: .spo2)

        XCTAssertNil(average)
    }

    func testAverageEmptyArray() {
        let readings: [SensorReading] = []

        let average = readings.average(for: .heartRate)

        XCTAssertNil(average)
    }

    // MARK: - Array Extension Tests - groupedByFrame()

    func testGroupedByFrame() {
        let readings = [
            SensorReading(sensorType: .ppgInfrared, value: 150000, frameNumber: 1),
            SensorReading(sensorType: .ppgRed, value: 120000, frameNumber: 1),
            SensorReading(sensorType: .ppgGreen, value: 80000, frameNumber: 1),
            SensorReading(sensorType: .ppgInfrared, value: 151000, frameNumber: 2),
            SensorReading(sensorType: .ppgRed, value: 121000, frameNumber: 2),
            SensorReading(sensorType: .ppgGreen, value: 81000, frameNumber: 2)
        ]

        let grouped = readings.groupedByFrame()

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[0].count, 3)
        XCTAssertEqual(grouped[1].count, 3)
    }

    func testGroupedByFrameWithNilFrameNumbers() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 72.0, frameNumber: nil),
            SensorReading(sensorType: .temperature, value: 36.5, frameNumber: nil),
            SensorReading(sensorType: .ppgInfrared, value: 150000, frameNumber: 1)
        ]

        let grouped = readings.groupedByFrame()

        // Readings with nil frame number grouped together, readings with frame 1 in another group
        XCTAssertEqual(grouped.count, 2)
    }

    func testGroupedByFrameEmpty() {
        let readings: [SensorReading] = []

        let grouped = readings.groupedByFrame()

        XCTAssertTrue(grouped.isEmpty)
    }

    // MARK: - Array Extension Tests - readings(forFrame:)

    func testReadingsForFrame() {
        let readings = [
            SensorReading(sensorType: .ppgInfrared, value: 150000, frameNumber: 1),
            SensorReading(sensorType: .ppgRed, value: 120000, frameNumber: 1),
            SensorReading(sensorType: .ppgGreen, value: 80000, frameNumber: 1),
            SensorReading(sensorType: .ppgInfrared, value: 151000, frameNumber: 2)
        ]

        let frame1Readings = readings.readings(forFrame: 1)

        XCTAssertEqual(frame1Readings.count, 3)
        XCTAssertTrue(frame1Readings.allSatisfy { $0.frameNumber == 1 })
    }

    func testReadingsForFrameNotFound() {
        let readings = [
            SensorReading(sensorType: .ppgInfrared, value: 150000, frameNumber: 1)
        ]

        let result = readings.readings(forFrame: 999)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Identifiable Conformance

    func testIdentifiable() {
        let reading = SensorReading(sensorType: .heartRate, value: 72.0)

        XCTAssertNotNil(reading.id)
        XCTAssertEqual(reading.id, reading.id)
    }
}
