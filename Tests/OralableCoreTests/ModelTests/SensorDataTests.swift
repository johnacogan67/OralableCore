//
//  SensorDataTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//

import XCTest
@testable import OralableCore

final class SensorDataTests: XCTestCase {

    // MARK: - PPGData Tests

    func testPPGDataSignalQuality() {
        // Valid values - should have 100% quality
        let validPPG = PPGData(red: 100000, ir: 150000, green: 120000)
        XCTAssertEqual(validPPG.signalQuality, 1.0)
        XCTAssertTrue(validPPG.isValid)

        // All invalid values - should have 0% quality
        let invalidPPG = PPGData(red: 5000, ir: 5000, green: 5000)
        XCTAssertEqual(invalidPPG.signalQuality, 0.0)
        XCTAssertFalse(invalidPPG.isValid)

        // Mixed - 2 of 3 valid
        let mixedPPG = PPGData(red: 100000, ir: 150000, green: 5000)
        XCTAssertEqual(mixedPPG.signalQuality, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertTrue(mixedPPG.isValid)  // 66% >= 66%
    }

    // MARK: - AccelerometerData Tests

    func testAccelerometerMagnitude() {
        let accel = AccelerometerData(x: 100, y: 0, z: 0)
        XCTAssertEqual(accel.magnitude, 100.0, accuracy: 0.01)

        let accel3D = AccelerometerData(x: 100, y: 100, z: 100)
        let expectedMag = sqrt(3.0) * 100.0
        XCTAssertEqual(accel3D.magnitude, expectedMag, accuracy: 0.01)
    }

    func testAccelerometerMovement() {
        let still = AccelerometerData(x: 50, y: 50, z: 50)
        XCTAssertFalse(still.isMoving)  // magnitude ~86.6 < 100

        let moving = AccelerometerData(x: 100, y: 100, z: 100)
        XCTAssertTrue(moving.isMoving)  // magnitude ~173 > 100
    }

    // MARK: - TemperatureData Tests

    func testTemperatureConversion() {
        let temp = TemperatureData(celsius: 37.0)
        XCTAssertEqual(temp.fahrenheit, 98.6, accuracy: 0.01)
    }

    func testTemperatureStatus() {
        XCTAssertEqual(TemperatureData(celsius: 33.0).status, .low)
        XCTAssertEqual(TemperatureData(celsius: 35.0).status, .belowNormal)
        XCTAssertEqual(TemperatureData(celsius: 37.0).status, .normal)
        XCTAssertEqual(TemperatureData(celsius: 38.0).status, .slightlyElevated)
        XCTAssertEqual(TemperatureData(celsius: 39.0).status, .elevated)
    }

    // MARK: - BatteryData Tests

    func testBatteryStatus() {
        XCTAssertEqual(BatteryData(percentage: 5).status, .critical)
        XCTAssertEqual(BatteryData(percentage: 15).status, .low)
        XCTAssertEqual(BatteryData(percentage: 35).status, .medium)
        XCTAssertEqual(BatteryData(percentage: 65).status, .good)
        XCTAssertEqual(BatteryData(percentage: 95).status, .excellent)
    }

    func testBatteryNeedsCharging() {
        XCTAssertTrue(BatteryData(percentage: 10).needsCharging)
        XCTAssertFalse(BatteryData(percentage: 50).needsCharging)
    }

    func testBatteryClamping() {
        let overMax = BatteryData(percentage: 150)
        XCTAssertEqual(overMax.percentage, 100)

        let underMin = BatteryData(percentage: -10)
        XCTAssertEqual(underMin.percentage, 0)
    }

    // MARK: - HeartRateData Tests

    func testHeartRateValidity() {
        let valid = HeartRateData(bpm: 75.0, quality: 0.85)
        XCTAssertTrue(valid.isValid)

        let lowQuality = HeartRateData(bpm: 75.0, quality: 0.4)
        XCTAssertFalse(lowQuality.isValid)

        let outOfRange = HeartRateData(bpm: 250.0, quality: 0.9)
        XCTAssertFalse(outOfRange.isValid)
    }

    func testHeartRateZone() {
        XCTAssertEqual(HeartRateData(bpm: 55.0, quality: 0.9).zone, .resting)
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.9).zone, .normal)
        XCTAssertEqual(HeartRateData(bpm: 110.0, quality: 0.9).zone, .elevated)
        XCTAssertEqual(HeartRateData(bpm: 140.0, quality: 0.9).zone, .exercise)
        XCTAssertEqual(HeartRateData(bpm: 175.0, quality: 0.9).zone, .highIntensity)
    }

    func testHeartRateQualityLevel() {
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.95).qualityLevel, .excellent)
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.85).qualityLevel, .good)
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.75).qualityLevel, .fair)
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.65).qualityLevel, .acceptable)
        XCTAssertEqual(HeartRateData(bpm: 75.0, quality: 0.45).qualityLevel, .poor)
    }

    // MARK: - SpO2Data Tests

    func testSpO2Validity() {
        let valid = SpO2Data(percentage: 98.0, quality: 0.85)
        XCTAssertTrue(valid.isValid)

        let lowQuality = SpO2Data(percentage: 98.0, quality: 0.4)
        XCTAssertFalse(lowQuality.isValid)

        let outOfRange = SpO2Data(percentage: 65.0, quality: 0.9)
        XCTAssertFalse(outOfRange.isValid)
    }

    func testSpO2HealthStatus() {
        XCTAssertEqual(SpO2Data(percentage: 98.0, quality: 0.9).healthStatus, .normal)
        XCTAssertEqual(SpO2Data(percentage: 92.0, quality: 0.9).healthStatus, .borderline)
        XCTAssertEqual(SpO2Data(percentage: 87.0, quality: 0.9).healthStatus, .low)
        XCTAssertEqual(SpO2Data(percentage: 80.0, quality: 0.9).healthStatus, .veryLow)
    }

    // MARK: - DeviceType Tests

    func testDeviceTypeFromName() {
        XCTAssertEqual(DeviceType.from(deviceName: "Oralable-123"), .oralable)
        XCTAssertEqual(DeviceType.from(deviceName: "ANR Sensor"), .anr)
        XCTAssertEqual(DeviceType.from(deviceName: "Muscle Monitor"), .anr)
        XCTAssertEqual(DeviceType.from(deviceName: "Demo Unit"), .demo)
        XCTAssertEqual(DeviceType.from(deviceName: "Unknown"), .oralable)  // Default
        XCTAssertEqual(DeviceType.from(deviceName: nil), .oralable)  // Default
    }

    func testDeviceTypeSamplingRates() {
        XCTAssertEqual(DeviceType.oralable.samplingRate, 50)
        XCTAssertEqual(DeviceType.anr.samplingRate, 100)
        XCTAssertEqual(DeviceType.demo.samplingRate, 10)
    }

    // MARK: - SensorData Container Tests

    func testSensorDataCreation() {
        let ppg = PPGData(red: 100000, ir: 150000, green: 120000)
        let accel = AccelerometerData(x: 10, y: 20, z: 30)
        let temp = TemperatureData(celsius: 37.0)
        let battery = BatteryData(percentage: 85)
        let hr = HeartRateData(bpm: 75.0, quality: 0.9)
        let spo2 = SpO2Data(percentage: 98.0, quality: 0.85)

        let sensorData = SensorData(
            ppg: ppg,
            accelerometer: accel,
            temperature: temp,
            battery: battery,
            heartRate: hr,
            spo2: spo2
        )

        XCTAssertTrue(sensorData.hasValidHeartRate)
        XCTAssertTrue(sensorData.hasValidSpO2)
        XCTAssertEqual(sensorData.deviceType, .oralable)
    }

    func testSensorDataWithoutOptionalMetrics() {
        let ppg = PPGData(red: 100000, ir: 150000, green: 120000)
        let accel = AccelerometerData(x: 10, y: 20, z: 30)
        let temp = TemperatureData(celsius: 37.0)
        let battery = BatteryData(percentage: 85)

        let sensorData = SensorData(
            ppg: ppg,
            accelerometer: accel,
            temperature: temp,
            battery: battery
        )

        XCTAssertFalse(sensorData.hasValidHeartRate)
        XCTAssertFalse(sensorData.hasValidSpO2)
        XCTAssertNil(sensorData.heartRate)
        XCTAssertNil(sensorData.spo2)
    }
}
