//
//  ProtocolTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for protocol models and types
//

import XCTest
@testable import OralableCore

final class ProtocolTests: XCTestCase {

    // MARK: - SensorType Tests

    func testSensorTypeDisplayName() {
        XCTAssertEqual(SensorType.heartRate.displayName, "Heart Rate")
        XCTAssertEqual(SensorType.ppgRed.displayName, "PPG Red")
        XCTAssertEqual(SensorType.accelerometerX.displayName, "Accel X")
        XCTAssertEqual(SensorType.temperature.displayName, "Temperature")
    }

    func testSensorTypeUnit() {
        XCTAssertEqual(SensorType.heartRate.unit, "bpm")
        XCTAssertEqual(SensorType.spo2.unit, "%")
        XCTAssertEqual(SensorType.temperature.unit, "°C")
        XCTAssertEqual(SensorType.accelerometerX.unit, "g")
    }

    func testSensorTypeGroups() {
        XCTAssertEqual(SensorType.opticalSensors.count, 4)
        XCTAssertEqual(SensorType.motionSensors.count, 3)
        XCTAssertEqual(SensorType.computedMetrics.count, 3)
        XCTAssertTrue(SensorType.opticalSensors.contains(.ppgRed))
        XCTAssertTrue(SensorType.motionSensors.contains(.accelerometerX))
    }

    func testSensorTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for sensorType in SensorType.allCases {
            let data = try encoder.encode(sensorType)
            let decoded = try decoder.decode(SensorType.self, from: data)
            XCTAssertEqual(decoded, sensorType)
        }
    }

    // MARK: - SensorReading Tests

    func testSensorReadingCreation() {
        let reading = SensorReading(
            sensorType: .heartRate,
            value: 72,
            deviceId: "test-device"
        )

        XCTAssertEqual(reading.sensorType, .heartRate)
        XCTAssertEqual(reading.value, 72)
        XCTAssertEqual(reading.deviceId, "test-device")
        XCTAssertTrue(reading.isValid)
    }

    func testSensorReadingValidation() {
        // Valid heart rate
        let validHR = SensorReading(sensorType: .heartRate, value: 72)
        XCTAssertTrue(validHR.isValid)

        // Invalid heart rate (too low)
        let lowHR = SensorReading(sensorType: .heartRate, value: 20)
        XCTAssertFalse(lowHR.isValid)

        // Invalid heart rate (too high)
        let highHR = SensorReading(sensorType: .heartRate, value: 300)
        XCTAssertFalse(highHR.isValid)

        // Valid SpO2
        let validSpO2 = SensorReading(sensorType: .spo2, value: 98)
        XCTAssertTrue(validSpO2.isValid)

        // Invalid SpO2
        let lowSpO2 = SensorReading(sensorType: .spo2, value: 40)
        XCTAssertFalse(lowSpO2.isValid)
    }

    func testSensorReadingMock() {
        let mockHR = SensorReading.mock(sensorType: .heartRate)
        XCTAssertEqual(mockHR.sensorType, .heartRate)
        XCTAssertEqual(mockHR.value, 72)  // Default mock value
        XCTAssertEqual(mockHR.quality, 0.95)
    }

    func testSensorReadingArrayExtensions() {
        let baseDate = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70, timestamp: baseDate),
            SensorReading(sensorType: .heartRate, value: 72, timestamp: baseDate.addingTimeInterval(1)),
            SensorReading(sensorType: .heartRate, value: 74, timestamp: baseDate.addingTimeInterval(2)),
            SensorReading(sensorType: .spo2, value: 98, timestamp: baseDate.addingTimeInterval(3))
        ]

        // Test latest (by timestamp)
        let latestHR = readings.latest(for: .heartRate)
        XCTAssertNotNil(latestHR)
        XCTAssertEqual(latestHR?.value, 74)

        // Test average
        let avgHR = readings.average(for: .heartRate)
        XCTAssertNotNil(avgHR)
        XCTAssertEqual(avgHR!, 72.0, accuracy: 0.01)
    }

    // MARK: - DeviceConnectionState Tests

    func testDeviceConnectionStateProperties() {
        XCTAssertTrue(DeviceConnectionState.connected.isConnected)
        XCTAssertFalse(DeviceConnectionState.disconnected.isConnected)
        XCTAssertTrue(DeviceConnectionState.connecting.isTransitioning)
        XCTAssertTrue(DeviceConnectionState.disconnecting.isTransitioning)
        XCTAssertFalse(DeviceConnectionState.connected.isTransitioning)
    }

    func testDeviceConnectionStateCanConnect() {
        XCTAssertTrue(DeviceConnectionState.disconnected.canConnect)
        XCTAssertTrue(DeviceConnectionState.failed.canConnect)
        XCTAssertFalse(DeviceConnectionState.connected.canConnect)
        XCTAssertFalse(DeviceConnectionState.connecting.canConnect)
    }

    func testDeviceConnectionStateCanDisconnect() {
        XCTAssertTrue(DeviceConnectionState.connected.canDisconnect)
        XCTAssertTrue(DeviceConnectionState.connecting.canDisconnect)
        XCTAssertFalse(DeviceConnectionState.disconnected.canDisconnect)
    }

    // MARK: - ConnectionReadiness Tests

    func testConnectionReadinessIsConnected() {
        XCTAssertFalse(ConnectionReadiness.disconnected.isConnected)
        XCTAssertFalse(ConnectionReadiness.connecting.isConnected)
        XCTAssertTrue(ConnectionReadiness.connected.isConnected)
        XCTAssertTrue(ConnectionReadiness.ready.isConnected)
        XCTAssertFalse(ConnectionReadiness.failed("test").isConnected)
    }

    func testConnectionReadinessIsReady() {
        XCTAssertFalse(ConnectionReadiness.connected.isReady)
        XCTAssertTrue(ConnectionReadiness.ready.isReady)
    }

    // MARK: - DeviceStateResult Tests

    func testDeviceStateResultCreation() {
        let state = DeviceStateResult.connected(
            isWorn: true,
            isStreaming: true,
            signalStrength: -45,
            batteryLevel: 85
        )

        XCTAssertEqual(state.connectionState, .connected)
        XCTAssertTrue(state.isWorn)
        XCTAssertTrue(state.isStreaming)
        XCTAssertEqual(state.signalStrength, -45)
        XCTAssertEqual(state.batteryLevel, 85)
        XCTAssertTrue(state.isReady)
    }

    func testDeviceStateResultSignalQuality() {
        let excellent = DeviceStateResult(connectionState: .connected, signalStrength: -45)
        XCTAssertEqual(excellent.signalQuality, .excellent)

        let good = DeviceStateResult(connectionState: .connected, signalStrength: -55)
        XCTAssertEqual(good.signalQuality, .good)

        let fair = DeviceStateResult(connectionState: .connected, signalStrength: -65)
        XCTAssertEqual(fair.signalQuality, .fair)

        let weak = DeviceStateResult(connectionState: .connected, signalStrength: -75)
        XCTAssertEqual(weak.signalQuality, .weak)

        let poor = DeviceStateResult(connectionState: .connected, signalStrength: -85)
        XCTAssertEqual(poor.signalQuality, .poor)
    }

    // MARK: - SignalQuality Tests

    func testSignalQualityBars() {
        XCTAssertEqual(SignalQuality.excellent.bars, 4)
        XCTAssertEqual(SignalQuality.good.bars, 3)
        XCTAssertEqual(SignalQuality.fair.bars, 2)
        XCTAssertEqual(SignalQuality.weak.bars, 1)
        XCTAssertEqual(SignalQuality.poor.bars, 0)
    }

    func testSignalQualityIsAdequate() {
        XCTAssertTrue(SignalQuality.excellent.isAdequate)
        XCTAssertTrue(SignalQuality.good.isAdequate)
        XCTAssertTrue(SignalQuality.fair.isAdequate)
        XCTAssertFalse(SignalQuality.weak.isAdequate)
        XCTAssertFalse(SignalQuality.poor.isAdequate)
    }

    // MARK: - DeviceInfo Tests

    func testDeviceInfoCreation() {
        let info = DeviceInfo(
            type: .oralable,
            name: "Test Oralable",
            batteryLevel: 80
        )

        XCTAssertEqual(info.type, .oralable)
        XCTAssertEqual(info.name, "Test Oralable")
        XCTAssertEqual(info.batteryLevel, 80)
        XCTAssertEqual(info.connectionState, .disconnected)
        XCTAssertFalse(info.supportedSensors.isEmpty)
    }

    func testDeviceInfoDemo() {
        let demo = DeviceInfo.demo(type: .oralable)

        XCTAssertEqual(demo.type, .oralable)
        XCTAssertEqual(demo.connectionState, .connected)
        XCTAssertEqual(demo.batteryLevel, 85)
        XCTAssertEqual(demo.firmwareVersion, "1.0.0")
    }

    func testDeviceInfoUpdate() {
        var info = DeviceInfo(type: .oralable, name: "Test")

        info.updateConnectionState(.connected)
        XCTAssertEqual(info.connectionState, .connected)
        XCTAssertNotNil(info.lastConnected)

        info.updateBatteryLevel(50)
        XCTAssertEqual(info.batteryLevel, 50)

        info.updateBatteryLevel(150)  // Should clamp
        XCTAssertEqual(info.batteryLevel, 100)
    }

    func testDeviceInfoArrayExtensions() {
        let devices = [
            DeviceInfo(type: .oralable, name: "Oralable 1", connectionState: .connected),
            DeviceInfo(type: .oralable, name: "Oralable 2", connectionState: .disconnected),
            DeviceInfo(type: .anr, name: "ANR 1", connectionState: .connected)
        ]

        XCTAssertEqual(devices.connected.count, 2)
        XCTAssertEqual(devices.ofType(.oralable).count, 2)
        XCTAssertEqual(devices.ofType(.anr).count, 1)
    }

    // MARK: - DeviceError Tests

    func testDeviceErrorDescription() {
        let notConnected = DeviceError.notConnected("Device offline")
        XCTAssertTrue(notConnected.errorDescription?.contains("not connected") ?? false)

        let timeout = DeviceError.connectionTimeout(deviceId: nil, timeoutSeconds: 30)
        XCTAssertTrue(timeout.errorDescription?.contains("timed out") ?? false)
    }

    func testDeviceErrorRecoverable() {
        XCTAssertTrue(DeviceError.connectionTimeout(deviceId: nil, timeoutSeconds: 30).isRecoverable)
        XCTAssertTrue(DeviceError.unexpectedDisconnection(deviceId: nil, reason: nil).isRecoverable)
        XCTAssertFalse(DeviceError.cancelled(operation: "test").isRecoverable)
        XCTAssertFalse(DeviceError.sensorNotSupported(sensorType: .emg).isRecoverable)
    }

    func testDeviceErrorShouldReconnect() {
        XCTAssertTrue(DeviceError.unexpectedDisconnection(deviceId: nil, reason: nil).shouldTriggerReconnection)
        XCTAssertTrue(DeviceError.connectionTimeout(deviceId: nil, timeoutSeconds: 30).shouldTriggerReconnection)
        XCTAssertFalse(DeviceError.notConnected("test").shouldTriggerReconnection)
    }

    // MARK: - LogMessage Tests

    func testLogMessageCreation() {
        let log = LogMessage(
            message: "Test message",
            level: .info,
            category: .bluetooth
        )

        XCTAssertEqual(log.message, "Test message")
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.category, .bluetooth)
    }

    func testLogMessageConvenienceInitializers() {
        let debug = LogMessage.debug("Debug message")
        XCTAssertEqual(debug.level, .debug)

        let info = LogMessage.info("Info message")
        XCTAssertEqual(info.level, .info)

        let warning = LogMessage.warning("Warning message")
        XCTAssertEqual(warning.level, .warning)

        let error = LogMessage.error("Error message")
        XCTAssertEqual(error.level, .error)
    }

    func testLogMessageArrayFiltering() {
        let logs = [
            LogMessage.debug("Debug 1"),
            LogMessage.info("Info 1"),
            LogMessage.warning("Warning 1"),
            LogMessage.error("Error 1")
        ]

        XCTAssertEqual(logs.filtered(minLevel: .warning).count, 2)
        XCTAssertEqual(logs.filtered(minLevel: .error).count, 1)
    }

    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    // MARK: - DeviceCommand Tests

    func testDeviceCommandRawValue() {
        XCTAssertEqual(DeviceCommand.startSensors.rawValue, "START")
        XCTAssertEqual(DeviceCommand.stopSensors.rawValue, "STOP")
        XCTAssertEqual(DeviceCommand.setSamplingRate(hz: 50).rawValue, "RATE:50")
        XCTAssertEqual(DeviceCommand.enableSensor(.heartRate).rawValue, "ENABLE:heart_rate")
    }

    // MARK: - DeviceConfiguration Tests

    func testDeviceConfigurationPresets() {
        let oralable = DeviceConfiguration.oralable
        XCTAssertEqual(oralable.samplingRate, 50)
        XCTAssertTrue(oralable.enabledSensors.contains(.ppgRed))

        let anr = DeviceConfiguration.anr
        XCTAssertEqual(anr.samplingRate, 100)
        XCTAssertTrue(anr.enabledSensors.contains(.emg))
    }

    func testDeviceConfigurationForDeviceType() {
        let oralableConfig = DeviceConfiguration.forDevice(.oralable)
        XCTAssertEqual(oralableConfig.samplingRate, 50)

        let anrConfig = DeviceConfiguration.forDevice(.anr)
        XCTAssertEqual(anrConfig.samplingRate, 100)
    }

    // MARK: - DeviceType Tests

    func testDeviceTypeDefaultSensors() {
        let oralableSensors = DeviceType.oralable.defaultSensors
        XCTAssertTrue(oralableSensors.contains(.ppgRed))
        XCTAssertTrue(oralableSensors.contains(.heartRate))

        let anrSensors = DeviceType.anr.defaultSensors
        XCTAssertTrue(anrSensors.contains(.emg))
        XCTAssertFalse(anrSensors.contains(.ppgRed))
    }

    func testDeviceTypeFromName() {
        XCTAssertEqual(DeviceType.from(deviceName: "Oralable Device"), .oralable)
        XCTAssertEqual(DeviceType.from(deviceName: "ANR Muscle Sense"), .anr)
        XCTAssertEqual(DeviceType.from(deviceName: "Demo Device"), .demo)
        XCTAssertEqual(DeviceType.from(deviceName: "Unknown"), .oralable)  // Default
    }

    // MARK: - SensorStatistics Tests

    func testSensorStatisticsCalculation() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70),
            SensorReading(sensorType: .heartRate, value: 72),
            SensorReading(sensorType: .heartRate, value: 74),
            SensorReading(sensorType: .heartRate, value: 76),
            SensorReading(sensorType: .heartRate, value: 78)
        ]

        let stats = SensorStatistics.calculate(from: readings)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats!.count, 5)
        XCTAssertEqual(stats!.min, 70)
        XCTAssertEqual(stats!.max, 78)
        XCTAssertEqual(stats!.average, 74.0, accuracy: 0.01)
    }

    // MARK: - DailySummary Tests

    func testDailySummaryCreation() {
        let summary = DailySummary(
            date: Date(),
            averageHeartRate: 72,
            maxHeartRate: 95,
            minHeartRate: 55,
            averageSpO2: 98,
            recordingDuration: 3600
        )

        XCTAssertEqual(summary.averageHeartRate, 72)
        XCTAssertEqual(summary.recordingDuration, 3600)
    }
}
