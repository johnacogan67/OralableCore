//
//  ExtendedModelTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Comprehensive tests for additional models not covered in SensorDataTests
//

import XCTest
@testable import OralableCore

// MARK: - ConnectionReadiness Tests

final class ConnectionReadinessTests: XCTestCase {

    func testIsConnectedStates() {
        // Disconnected states
        XCTAssertFalse(ConnectionReadiness.disconnected.isConnected)
        XCTAssertFalse(ConnectionReadiness.connecting.isConnected)
        XCTAssertFalse(ConnectionReadiness.failed("error").isConnected)

        // Connected states
        XCTAssertTrue(ConnectionReadiness.connected.isConnected)
        XCTAssertTrue(ConnectionReadiness.discoveringServices.isConnected)
        XCTAssertTrue(ConnectionReadiness.servicesDiscovered.isConnected)
        XCTAssertTrue(ConnectionReadiness.discoveringCharacteristics.isConnected)
        XCTAssertTrue(ConnectionReadiness.characteristicsDiscovered.isConnected)
        XCTAssertTrue(ConnectionReadiness.enablingNotifications.isConnected)
        XCTAssertTrue(ConnectionReadiness.ready.isConnected)
    }

    func testIsReady() {
        XCTAssertFalse(ConnectionReadiness.disconnected.isReady)
        XCTAssertFalse(ConnectionReadiness.connecting.isReady)
        XCTAssertFalse(ConnectionReadiness.connected.isReady)
        XCTAssertFalse(ConnectionReadiness.enablingNotifications.isReady)
        XCTAssertTrue(ConnectionReadiness.ready.isReady)
    }

    func testIsTransitioning() {
        XCTAssertTrue(ConnectionReadiness.connecting.isTransitioning)
        XCTAssertTrue(ConnectionReadiness.discoveringServices.isTransitioning)
        XCTAssertTrue(ConnectionReadiness.discoveringCharacteristics.isTransitioning)
        XCTAssertTrue(ConnectionReadiness.enablingNotifications.isTransitioning)

        XCTAssertFalse(ConnectionReadiness.disconnected.isTransitioning)
        XCTAssertFalse(ConnectionReadiness.ready.isTransitioning)
        XCTAssertFalse(ConnectionReadiness.failed("error").isTransitioning)
    }

    func testDescription() {
        XCTAssertEqual(ConnectionReadiness.disconnected.description, "Disconnected")
        XCTAssertEqual(ConnectionReadiness.connecting.description, "Connecting...")
        XCTAssertEqual(ConnectionReadiness.ready.description, "Ready")
        XCTAssertEqual(ConnectionReadiness.failed("timeout").description, "Failed: timeout")
    }

    func testEquatable() {
        XCTAssertEqual(ConnectionReadiness.disconnected, ConnectionReadiness.disconnected)
        XCTAssertEqual(ConnectionReadiness.ready, ConnectionReadiness.ready)
        XCTAssertNotEqual(ConnectionReadiness.disconnected, ConnectionReadiness.ready)

        // Failed cases with same/different messages
        XCTAssertEqual(ConnectionReadiness.failed("error"), ConnectionReadiness.failed("error"))
        XCTAssertNotEqual(ConnectionReadiness.failed("error1"), ConnectionReadiness.failed("error2"))
    }
}

// MARK: - DeviceInfo Tests

final class DeviceInfoTests: XCTestCase {

    func testBasicInitialization() {
        let device = DeviceInfo(
            type: .oralable,
            name: "Test Device"
        )

        XCTAssertEqual(device.type, .oralable)
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.connectionState, .disconnected)
        XCTAssertEqual(device.connectionReadiness, .disconnected)
        XCTAssertNil(device.batteryLevel)
        XCTAssertNil(device.signalStrength)
    }

    func testFullInitialization() {
        let peripheralId = UUID()
        let device = DeviceInfo(
            type: .anr,
            name: "ANR Device",
            peripheralIdentifier: peripheralId,
            connectionState: .connected,
            connectionReadiness: .ready,
            batteryLevel: 85,
            signalStrength: -45,
            firmwareVersion: "1.2.3",
            hardwareVersion: "Rev B"
        )

        XCTAssertEqual(device.type, .anr)
        XCTAssertEqual(device.peripheralIdentifier, peripheralId)
        XCTAssertEqual(device.batteryLevel, 85)
        XCTAssertEqual(device.signalStrength, -45)
        XCTAssertEqual(device.firmwareVersion, "1.2.3")
    }

    func testIsActive() {
        var device = DeviceInfo(type: .oralable, name: "Test")

        device.connectionState = .disconnected
        XCTAssertFalse(device.isActive)

        device.connectionState = .connecting
        XCTAssertTrue(device.isActive)

        device.connectionState = .connected
        XCTAssertTrue(device.isActive)
    }

    func testIsReady() {
        var device = DeviceInfo(type: .oralable, name: "Test")

        device.connectionReadiness = .connected
        XCTAssertFalse(device.isReady)

        device.connectionReadiness = .ready
        XCTAssertTrue(device.isReady)
    }

    func testDemoDevice() {
        let demo = DeviceInfo.demo(type: .oralable)

        XCTAssertEqual(demo.type, .oralable)
        XCTAssertTrue(demo.name.contains("Demo"))
        XCTAssertEqual(demo.connectionState, .connected)
        XCTAssertEqual(demo.connectionReadiness, .ready)
        XCTAssertEqual(demo.batteryLevel, 85)
        XCTAssertNotNil(demo.firmwareVersion)
    }

    func testUpdateConnectionState() {
        var device = DeviceInfo(type: .oralable, name: "Test")
        XCTAssertNil(device.lastConnected)

        device.updateConnectionState(.connected)
        XCTAssertEqual(device.connectionState, .connected)
        XCTAssertNotNil(device.lastConnected)
    }

    func testUpdateConnectionReadiness() {
        var device = DeviceInfo(type: .oralable, name: "Test")

        device.updateConnectionReadiness(.ready)
        XCTAssertEqual(device.connectionReadiness, .ready)
        XCTAssertEqual(device.connectionState, .connected)

        device.updateConnectionReadiness(.failed("error"))
        XCTAssertEqual(device.connectionState, .failed)
    }

    func testUpdateBatteryLevel() {
        var device = DeviceInfo(type: .oralable, name: "Test")

        device.updateBatteryLevel(50)
        XCTAssertEqual(device.batteryLevel, 50)

        // Clamping tests
        device.updateBatteryLevel(150)
        XCTAssertEqual(device.batteryLevel, 100)

        device.updateBatteryLevel(-10)
        XCTAssertEqual(device.batteryLevel, 0)
    }

    func testDefaultSupportedSensors() {
        let oralable = DeviceInfo(type: .oralable, name: "Test")
        XCTAssertTrue(oralable.supportedSensors.contains(.ppgRed))

        let anr = DeviceInfo(type: .anr, name: "Test")
        XCTAssertTrue(anr.supportedSensors.contains(.emg))
    }
}

// MARK: - DeviceInfo Array Extension Tests

final class DeviceInfoArrayTests: XCTestCase {

    func testConnectedDevices() {
        let devices = [
            DeviceInfo(type: .oralable, name: "D1", connectionState: .connected),
            DeviceInfo(type: .oralable, name: "D2", connectionState: .disconnected),
            DeviceInfo(type: .anr, name: "D3", connectionState: .connected)
        ]

        let connected = devices.connected
        XCTAssertEqual(connected.count, 2)
        XCTAssertTrue(connected.contains { $0.name == "D1" })
        XCTAssertTrue(connected.contains { $0.name == "D3" })
    }

    func testReadyDevices() {
        var d1 = DeviceInfo(type: .oralable, name: "D1")
        d1.connectionReadiness = .ready
        var d2 = DeviceInfo(type: .oralable, name: "D2")
        d2.connectionReadiness = .connected
        var d3 = DeviceInfo(type: .anr, name: "D3")
        d3.connectionReadiness = .ready

        let devices = [d1, d2, d3]
        let ready = devices.ready
        XCTAssertEqual(ready.count, 2)
    }

    func testFilterByType() {
        let devices = [
            DeviceInfo(type: .oralable, name: "O1"),
            DeviceInfo(type: .anr, name: "A1"),
            DeviceInfo(type: .oralable, name: "O2")
        ]

        XCTAssertEqual(devices.ofType(.oralable).count, 2)
        XCTAssertEqual(devices.ofType(.anr).count, 1)
        XCTAssertEqual(devices.ofType(.demo).count, 0)
    }

    func testFindByPeripheralId() {
        let targetId = UUID()
        let devices = [
            DeviceInfo(type: .oralable, name: "D1", peripheralIdentifier: UUID()),
            DeviceInfo(type: .oralable, name: "D2", peripheralIdentifier: targetId),
            DeviceInfo(type: .anr, name: "D3", peripheralIdentifier: UUID())
        ]

        let found = devices.device(withPeripheralId: targetId)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "D2")

        XCTAssertNil(devices.device(withPeripheralId: UUID()))
    }

    func testFindByName() {
        let devices = [
            DeviceInfo(type: .oralable, name: "Device One"),
            DeviceInfo(type: .oralable, name: "Device Two")
        ]

        XCTAssertNotNil(devices.device(named: "Device One"))
        XCTAssertNil(devices.device(named: "Device Three"))
    }
}

// MARK: - DeviceConnectionState Tests

final class DeviceConnectionStateTests: XCTestCase {

    func testDescription() {
        XCTAssertEqual(DeviceConnectionState.disconnected.description, "Disconnected")
        XCTAssertEqual(DeviceConnectionState.connecting.description, "Connecting...")
        XCTAssertEqual(DeviceConnectionState.connected.description, "Connected")
        XCTAssertEqual(DeviceConnectionState.disconnecting.description, "Disconnecting...")
        XCTAssertEqual(DeviceConnectionState.failed.description, "Connection Failed")
    }

    func testIsConnected() {
        XCTAssertFalse(DeviceConnectionState.disconnected.isConnected)
        XCTAssertFalse(DeviceConnectionState.connecting.isConnected)
        XCTAssertTrue(DeviceConnectionState.connected.isConnected)
        XCTAssertFalse(DeviceConnectionState.disconnecting.isConnected)
        XCTAssertFalse(DeviceConnectionState.failed.isConnected)
    }

    func testIsTransitioning() {
        XCTAssertFalse(DeviceConnectionState.disconnected.isTransitioning)
        XCTAssertTrue(DeviceConnectionState.connecting.isTransitioning)
        XCTAssertFalse(DeviceConnectionState.connected.isTransitioning)
        XCTAssertTrue(DeviceConnectionState.disconnecting.isTransitioning)
        XCTAssertFalse(DeviceConnectionState.failed.isTransitioning)
    }

    func testCanConnect() {
        XCTAssertTrue(DeviceConnectionState.disconnected.canConnect)
        XCTAssertFalse(DeviceConnectionState.connecting.canConnect)
        XCTAssertFalse(DeviceConnectionState.connected.canConnect)
        XCTAssertTrue(DeviceConnectionState.failed.canConnect)
    }

    func testCanDisconnect() {
        XCTAssertFalse(DeviceConnectionState.disconnected.canDisconnect)
        XCTAssertTrue(DeviceConnectionState.connecting.canDisconnect)
        XCTAssertTrue(DeviceConnectionState.connected.canDisconnect)
        XCTAssertFalse(DeviceConnectionState.failed.canDisconnect)
    }

    func testIconNames() {
        XCTAssertFalse(DeviceConnectionState.disconnected.iconName.isEmpty)
        XCTAssertFalse(DeviceConnectionState.connected.iconName.isEmpty)
        XCTAssertFalse(DeviceConnectionState.failed.iconName.isEmpty)
    }
}

// MARK: - DeviceStateResult Tests

final class DeviceStateResultTests: XCTestCase {

    func testBasicInitialization() {
        let result = DeviceStateResult(connectionState: .connected)

        XCTAssertEqual(result.connectionState, .connected)
        XCTAssertFalse(result.isWorn)
        XCTAssertFalse(result.isStreaming)
        XCTAssertNil(result.signalStrength)
    }

    func testIsReady() {
        let notWorn = DeviceStateResult(connectionState: .connected, isWorn: false)
        XCTAssertFalse(notWorn.isReady)

        let wornAndConnected = DeviceStateResult(connectionState: .connected, isWorn: true)
        XCTAssertTrue(wornAndConnected.isReady)

        let wornButDisconnected = DeviceStateResult(connectionState: .disconnected, isWorn: true)
        XCTAssertFalse(wornButDisconnected.isReady)
    }

    func testSignalQuality() {
        XCTAssertEqual(DeviceStateResult(connectionState: .connected, signalStrength: -45).signalQuality, .excellent)
        XCTAssertEqual(DeviceStateResult(connectionState: .connected, signalStrength: -55).signalQuality, .good)
        XCTAssertEqual(DeviceStateResult(connectionState: .connected, signalStrength: -65).signalQuality, .fair)
        XCTAssertEqual(DeviceStateResult(connectionState: .connected, signalStrength: -75).signalQuality, .weak)
        XCTAssertEqual(DeviceStateResult(connectionState: .connected, signalStrength: -85).signalQuality, .poor)
        XCTAssertEqual(DeviceStateResult(connectionState: .connected).signalQuality, .unknown)
    }

    func testStaticHelpers() {
        XCTAssertEqual(DeviceStateResult.disconnected.connectionState, .disconnected)

        let connected = DeviceStateResult.connected(isWorn: true, isStreaming: true, batteryLevel: 80)
        XCTAssertTrue(connected.isWorn)
        XCTAssertTrue(connected.isStreaming)
        XCTAssertEqual(connected.batteryLevel, 80)
    }
}

// MARK: - SignalQuality Tests

final class SignalQualityTests: XCTestCase {

    func testFromRSSI() {
        XCTAssertEqual(SignalQuality.from(rssi: -40), .excellent)
        XCTAssertEqual(SignalQuality.from(rssi: -50), .excellent)
        XCTAssertEqual(SignalQuality.from(rssi: -55), .good)
        XCTAssertEqual(SignalQuality.from(rssi: -65), .fair)
        XCTAssertEqual(SignalQuality.from(rssi: -75), .weak)
        XCTAssertEqual(SignalQuality.from(rssi: -90), .poor)
    }

    func testBars() {
        XCTAssertEqual(SignalQuality.excellent.bars, 4)
        XCTAssertEqual(SignalQuality.good.bars, 3)
        XCTAssertEqual(SignalQuality.fair.bars, 2)
        XCTAssertEqual(SignalQuality.weak.bars, 1)
        XCTAssertEqual(SignalQuality.poor.bars, 0)
        XCTAssertEqual(SignalQuality.unknown.bars, 0)
    }

    func testIsAdequate() {
        XCTAssertTrue(SignalQuality.excellent.isAdequate)
        XCTAssertTrue(SignalQuality.good.isAdequate)
        XCTAssertTrue(SignalQuality.fair.isAdequate)
        XCTAssertFalse(SignalQuality.weak.isAdequate)
        XCTAssertFalse(SignalQuality.poor.isAdequate)
        XCTAssertFalse(SignalQuality.unknown.isAdequate)
    }
}

// MARK: - SensorReading Tests

final class SensorReadingTests: XCTestCase {

    func testBasicInitialization() {
        let reading = SensorReading(
            sensorType: .heartRate,
            value: 72.0
        )

        XCTAssertEqual(reading.sensorType, .heartRate)
        XCTAssertEqual(reading.value, 72.0)
        XCTAssertNil(reading.deviceId)
        XCTAssertNil(reading.quality)
    }

    func testFormattedValue() {
        XCTAssertEqual(SensorReading(sensorType: .heartRate, value: 72).formattedValue, "72 bpm")
        XCTAssertEqual(SensorReading(sensorType: .spo2, value: 98).formattedValue, "98 %")
        XCTAssertEqual(SensorReading(sensorType: .temperature, value: 36.5).formattedValue, "36.5 °C")
        XCTAssertEqual(SensorReading(sensorType: .battery, value: 85).formattedValue, "85 %")
        XCTAssertTrue(SensorReading(sensorType: .accelerometerX, value: 0.123).formattedValue.contains("0.123"))
    }

    func testIsValidHeartRate() {
        XCTAssertTrue(SensorReading(sensorType: .heartRate, value: 72).isValid)
        XCTAssertTrue(SensorReading(sensorType: .heartRate, value: 30).isValid)
        XCTAssertTrue(SensorReading(sensorType: .heartRate, value: 250).isValid)
        XCTAssertFalse(SensorReading(sensorType: .heartRate, value: 29).isValid)
        XCTAssertFalse(SensorReading(sensorType: .heartRate, value: 251).isValid)
    }

    func testIsValidSpO2() {
        XCTAssertTrue(SensorReading(sensorType: .spo2, value: 98).isValid)
        XCTAssertTrue(SensorReading(sensorType: .spo2, value: 50).isValid)
        XCTAssertTrue(SensorReading(sensorType: .spo2, value: 100).isValid)
        XCTAssertFalse(SensorReading(sensorType: .spo2, value: 49).isValid)
        XCTAssertFalse(SensorReading(sensorType: .spo2, value: 101).isValid)
    }

    func testIsValidTemperature() {
        XCTAssertTrue(SensorReading(sensorType: .temperature, value: 36.5).isValid)
        XCTAssertTrue(SensorReading(sensorType: .temperature, value: 20).isValid)
        XCTAssertTrue(SensorReading(sensorType: .temperature, value: 45).isValid)
        XCTAssertFalse(SensorReading(sensorType: .temperature, value: 19).isValid)
        XCTAssertFalse(SensorReading(sensorType: .temperature, value: 46).isValid)
    }

    func testIsValidAccelerometer() {
        XCTAssertTrue(SensorReading(sensorType: .accelerometerX, value: 0).isValid)
        XCTAssertTrue(SensorReading(sensorType: .accelerometerY, value: -20).isValid)
        XCTAssertTrue(SensorReading(sensorType: .accelerometerZ, value: 20).isValid)
        XCTAssertFalse(SensorReading(sensorType: .accelerometerX, value: -21).isValid)
        XCTAssertFalse(SensorReading(sensorType: .accelerometerX, value: 21).isValid)
    }

    func testIsValidWithInfinite() {
        XCTAssertFalse(SensorReading(sensorType: .heartRate, value: .infinity).isValid)
        XCTAssertFalse(SensorReading(sensorType: .heartRate, value: .nan).isValid)
    }

    func testMockReading() {
        let mock = SensorReading.mock(sensorType: .heartRate)

        XCTAssertEqual(mock.sensorType, .heartRate)
        XCTAssertEqual(mock.value, SensorType.heartRate.mockValue)
        XCTAssertEqual(mock.deviceId, "mock-device")
        XCTAssertEqual(mock.quality, 0.95)
    }
}

// MARK: - SensorReading Array Extension Tests

final class SensorReadingArrayTests: XCTestCase {

    func testLatest() {
        let now = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70, timestamp: now.addingTimeInterval(-2)),
            SensorReading(sensorType: .heartRate, value: 75, timestamp: now),
            SensorReading(sensorType: .spo2, value: 98, timestamp: now.addingTimeInterval(-1))
        ]

        let latestHR = readings.latest(for: .heartRate)
        XCTAssertEqual(latestHR?.value, 75)

        let latestSpO2 = readings.latest(for: .spo2)
        XCTAssertEqual(latestSpO2?.value, 98)

        XCTAssertNil(readings.latest(for: .temperature))
    }

    func testReadingsInTimeRange() {
        let now = Date()
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70, timestamp: now.addingTimeInterval(-60)),
            SensorReading(sensorType: .heartRate, value: 72, timestamp: now.addingTimeInterval(-30)),
            SensorReading(sensorType: .heartRate, value: 75, timestamp: now)
        ]

        let ranged = readings.readings(
            for: .heartRate,
            from: now.addingTimeInterval(-45),
            to: now.addingTimeInterval(-15)
        )

        XCTAssertEqual(ranged.count, 1)
        XCTAssertEqual(ranged.first?.value, 72)
    }

    func testAverage() {
        let readings = [
            SensorReading(sensorType: .heartRate, value: 70),
            SensorReading(sensorType: .heartRate, value: 80),
            SensorReading(sensorType: .spo2, value: 98)
        ]

        let avgHR = readings.average(for: .heartRate)
        XCTAssertEqual(avgHR, 75)

        XCTAssertNil(readings.average(for: .temperature))
    }

    func testGroupedByFrame() {
        let readings = [
            SensorReading(sensorType: .ppgRed, value: 100, frameNumber: 1),
            SensorReading(sensorType: .ppgInfrared, value: 150, frameNumber: 1),
            SensorReading(sensorType: .ppgRed, value: 105, frameNumber: 2),
            SensorReading(sensorType: .ppgInfrared, value: 155, frameNumber: 2)
        ]

        let grouped = readings.groupedByFrame()
        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[0].count, 2)
        XCTAssertEqual(grouped[0].first?.frameNumber, 1)
    }

    func testReadingsForFrame() {
        let readings = [
            SensorReading(sensorType: .ppgRed, value: 100, frameNumber: 1),
            SensorReading(sensorType: .ppgInfrared, value: 150, frameNumber: 1),
            SensorReading(sensorType: .ppgRed, value: 105, frameNumber: 2)
        ]

        let frame1 = readings.readings(forFrame: 1)
        XCTAssertEqual(frame1.count, 2)

        let frame3 = readings.readings(forFrame: 3)
        XCTAssertEqual(frame3.count, 0)
    }
}

// MARK: - SensorType Tests

final class SensorTypeTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(SensorType.heartRate.displayName, "Heart Rate")
        XCTAssertEqual(SensorType.spo2.displayName, "SpO2")
        XCTAssertEqual(SensorType.ppgRed.displayName, "PPG Red")
        XCTAssertEqual(SensorType.emg.displayName, "EMG")
    }

    func testUnits() {
        XCTAssertEqual(SensorType.heartRate.unit, "bpm")
        XCTAssertEqual(SensorType.spo2.unit, "%")
        XCTAssertEqual(SensorType.temperature.unit, "°C")
        XCTAssertEqual(SensorType.ppgRed.unit, "ADC")
        XCTAssertEqual(SensorType.accelerometerX.unit, "g")
        XCTAssertEqual(SensorType.emg.unit, "µV")
    }

    func testIsOpticalSignal() {
        XCTAssertTrue(SensorType.ppgRed.isOpticalSignal)
        XCTAssertTrue(SensorType.ppgInfrared.isOpticalSignal)
        XCTAssertTrue(SensorType.ppgGreen.isOpticalSignal)
        XCTAssertTrue(SensorType.emg.isOpticalSignal)
        XCTAssertFalse(SensorType.heartRate.isOpticalSignal)
        XCTAssertFalse(SensorType.temperature.isOpticalSignal)
    }

    func testRequiresProcessing() {
        XCTAssertTrue(SensorType.ppgRed.requiresProcessing)
        XCTAssertTrue(SensorType.emg.requiresProcessing)
        XCTAssertFalse(SensorType.heartRate.requiresProcessing)
        XCTAssertFalse(SensorType.battery.requiresProcessing)
    }

    func testIconNames() {
        // Just verify they're not empty
        for sensorType in SensorType.allCases {
            XCTAssertFalse(sensorType.iconName.isEmpty, "\(sensorType) has empty icon")
        }
    }

    func testMockValues() {
        XCTAssertEqual(SensorType.heartRate.mockValue, 72)
        XCTAssertEqual(SensorType.spo2.mockValue, 98)
        XCTAssertEqual(SensorType.battery.mockValue, 85)
    }

    func testSensorGroupings() {
        XCTAssertEqual(SensorType.opticalSensors.count, 4)
        XCTAssertTrue(SensorType.opticalSensors.contains(.ppgRed))
        XCTAssertTrue(SensorType.opticalSensors.contains(.emg))

        XCTAssertEqual(SensorType.motionSensors.count, 3)
        XCTAssertTrue(SensorType.motionSensors.contains(.accelerometerX))

        XCTAssertEqual(SensorType.computedMetrics.count, 3)
        XCTAssertTrue(SensorType.computedMetrics.contains(.heartRate))
        XCTAssertTrue(SensorType.computedMetrics.contains(.spo2))

        XCTAssertTrue(SensorType.rawSensors.count > SensorType.computedMetrics.count)
    }
}

// MARK: - DeviceError Tests

final class DeviceErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertTrue(DeviceError.notConnected("device").errorDescription?.contains("not connected") ?? false)
        XCTAssertTrue(DeviceError.connectionFailed(deviceId: nil, reason: "timeout").errorDescription?.contains("failed") ?? false)
        XCTAssertTrue(DeviceError.deviceNotFound(identifier: "test").errorDescription?.contains("not found") ?? false)
        XCTAssertTrue(DeviceError.deviceBusy.errorDescription?.contains("busy") ?? false)
    }

    func testIsRecoverable() {
        XCTAssertTrue(DeviceError.connectionTimeout(deviceId: nil, timeoutSeconds: 10).isRecoverable)
        XCTAssertTrue(DeviceError.unexpectedDisconnection(deviceId: nil, reason: nil).isRecoverable)
        XCTAssertTrue(DeviceError.deviceBusy.isRecoverable)

        XCTAssertFalse(DeviceError.cancelled(operation: "test").isRecoverable)
        XCTAssertFalse(DeviceError.sensorNotSupported(sensorType: .emg).isRecoverable)
    }

    func testShouldTriggerReconnection() {
        XCTAssertTrue(DeviceError.unexpectedDisconnection(deviceId: nil, reason: nil).shouldTriggerReconnection)
        XCTAssertTrue(DeviceError.connectionTimeout(deviceId: nil, timeoutSeconds: 10).shouldTriggerReconnection)

        XCTAssertFalse(DeviceError.notConnected("test").shouldTriggerReconnection)
        XCTAssertFalse(DeviceError.deviceBusy.shouldTriggerReconnection)
    }

    func testSeverity() {
        XCTAssertEqual(DeviceError.cancelled(operation: "test").severity, .info)
        XCTAssertEqual(DeviceError.timeout(operation: "test", timeoutSeconds: 5).severity, .warning)
        XCTAssertEqual(DeviceError.notConnected("test").severity, .error)
        XCTAssertEqual(DeviceError.internalError(reason: "critical").severity, .critical)
    }

    func testEquatable() {
        XCTAssertEqual(DeviceError.deviceBusy, DeviceError.deviceBusy)
        XCTAssertEqual(
            DeviceError.notConnected("same"),
            DeviceError.notConnected("same")
        )
        XCTAssertNotEqual(
            DeviceError.notConnected("one"),
            DeviceError.notConnected("two")
        )
        XCTAssertEqual(
            DeviceError.sensorNotSupported(sensorType: .emg),
            DeviceError.sensorNotSupported(sensorType: .emg)
        )
        XCTAssertNotEqual(
            DeviceError.sensorNotSupported(sensorType: .emg),
            DeviceError.sensorNotSupported(sensorType: .ppgRed)
        )
    }
}

// MARK: - ErrorSeverity Tests

final class ErrorSeverityTests: XCTestCase {

    func testComparison() {
        XCTAssertLessThan(ErrorSeverity.info, ErrorSeverity.warning)
        XCTAssertLessThan(ErrorSeverity.warning, ErrorSeverity.error)
        XCTAssertLessThan(ErrorSeverity.error, ErrorSeverity.critical)
    }

    func testDescription() {
        XCTAssertEqual(ErrorSeverity.info.description, "Info")
        XCTAssertEqual(ErrorSeverity.warning.description, "Warning")
        XCTAssertEqual(ErrorSeverity.error.description, "Error")
        XCTAssertEqual(ErrorSeverity.critical.description, "Critical")
    }
}

// MARK: - ActivityType Tests

final class ActivityTypeTests: XCTestCase {

    func testDescription() {
        XCTAssertEqual(ActivityType.relaxed.description, "Relaxed")
        XCTAssertEqual(ActivityType.clenching.description, "Clenching")
        XCTAssertEqual(ActivityType.grinding.description, "Grinding")
        XCTAssertEqual(ActivityType.motion.description, "Motion")
    }

    func testIsBruxismIndicator() {
        XCTAssertFalse(ActivityType.relaxed.isBruxismIndicator)
        XCTAssertTrue(ActivityType.clenching.isBruxismIndicator)
        XCTAssertTrue(ActivityType.grinding.isBruxismIndicator)
        XCTAssertFalse(ActivityType.motion.isBruxismIndicator)
    }

    func testIconNames() {
        for activity in ActivityType.allCases {
            XCTAssertFalse(activity.iconName.isEmpty)
        }
    }
}

// MARK: - QualityLevel Tests

final class QualityLevelTests: XCTestCase {

    func testDescription() {
        XCTAssertEqual(QualityLevel.excellent.description, "Excellent")
        XCTAssertEqual(QualityLevel.good.description, "Good")
        XCTAssertEqual(QualityLevel.poor.description, "Poor")
    }

    func testMinimumThreshold() {
        XCTAssertEqual(QualityLevel.excellent.minimumThreshold, 0.9)
        XCTAssertEqual(QualityLevel.good.minimumThreshold, 0.8)
        XCTAssertEqual(QualityLevel.fair.minimumThreshold, 0.7)
        XCTAssertEqual(QualityLevel.acceptable.minimumThreshold, 0.6)
        XCTAssertEqual(QualityLevel.poor.minimumThreshold, 0.0)
    }

    func testColor() {
        XCTAssertEqual(QualityLevel.excellent.color, "green")
        XCTAssertEqual(QualityLevel.good.color, "green")
        XCTAssertEqual(QualityLevel.fair.color, "yellow")
        XCTAssertEqual(QualityLevel.acceptable.color, "orange")
        XCTAssertEqual(QualityLevel.poor.color, "red")
    }
}

// MARK: - LogLevel Tests

final class LogLevelTests: XCTestCase {

    func testComparison() {
        XCTAssertLessThan(LogLevel.debug, LogLevel.info)
        XCTAssertLessThan(LogLevel.info, LogLevel.warning)
        XCTAssertLessThan(LogLevel.warning, LogLevel.error)
    }

    func testIcons() {
        XCTAssertEqual(LogLevel.debug.icon, "ant")
        XCTAssertEqual(LogLevel.info.icon, "info.circle")
        XCTAssertEqual(LogLevel.warning.icon, "exclamationmark.triangle")
        XCTAssertEqual(LogLevel.error.icon, "xmark.circle")
    }
}

// MARK: - LogCategory Tests

final class LogCategoryTests: XCTestCase {

    func testDisplayName() {
        XCTAssertEqual(LogCategory.bluetooth.displayName, "Bluetooth")
        XCTAssertEqual(LogCategory.sensor.displayName, "Sensor")
        XCTAssertEqual(LogCategory.system.displayName, "System")
    }

    func testAllCases() {
        XCTAssertEqual(LogCategory.allCases.count, 7)
    }
}

// MARK: - LogMessage Tests

final class LogMessageTests: XCTestCase {

    func testBasicInitialization() {
        let log = LogMessage(message: "Test message")

        XCTAssertEqual(log.message, "Test message")
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.category, .system)
        XCTAssertNil(log.deviceId)
    }

    func testConvenienceInitializers() {
        let debug = LogMessage.debug("Debug message", category: .bluetooth)
        XCTAssertEqual(debug.level, .debug)
        XCTAssertEqual(debug.category, .bluetooth)

        let info = LogMessage.info("Info message")
        XCTAssertEqual(info.level, .info)

        let warning = LogMessage.warning("Warning message", deviceId: "device-1")
        XCTAssertEqual(warning.level, .warning)
        XCTAssertEqual(warning.deviceId, "device-1")

        let error = LogMessage.error("Error message")
        XCTAssertEqual(error.level, .error)
    }

    func testFormattedTimestamp() {
        let log = LogMessage(message: "Test")
        XCTAssertFalse(log.formattedTimestamp.isEmpty)
        XCTAssertTrue(log.formattedTimestamp.contains(":"))
    }

    func testFormattedLine() {
        let log = LogMessage(
            message: "Test message",
            level: .warning,
            category: .sensor,
            deviceId: "device-1"
        )

        let line = log.formattedLine
        XCTAssertTrue(line.contains("WARNING"))
        XCTAssertTrue(line.contains("sensor"))
        XCTAssertTrue(line.contains("device-1"))
        XCTAssertTrue(line.contains("Test message"))
    }

    func testFormattedLineWithoutDeviceId() {
        let log = LogMessage(message: "Test", level: .info, category: .system)
        let line = log.formattedLine
        XCTAssertTrue(line.contains("INFO"))
        XCTAssertTrue(line.contains("Test"))
    }
}

// MARK: - LogMessage Array Extension Tests

final class LogMessageArrayTests: XCTestCase {

    func testFilteredByMinLevel() {
        let logs = [
            LogMessage(message: "Debug", level: .debug),
            LogMessage(message: "Info", level: .info),
            LogMessage(message: "Warning", level: .warning),
            LogMessage(message: "Error", level: .error)
        ]

        XCTAssertEqual(logs.filtered(minLevel: .warning).count, 2)
        XCTAssertEqual(logs.filtered(minLevel: .debug).count, 4)
        XCTAssertEqual(logs.filtered(minLevel: .error).count, 1)
    }

    func testFilteredByCategory() {
        let logs = [
            LogMessage(message: "BT1", category: .bluetooth),
            LogMessage(message: "Sensor1", category: .sensor),
            LogMessage(message: "BT2", category: .bluetooth)
        ]

        XCTAssertEqual(logs.filtered(category: .bluetooth).count, 2)
        XCTAssertEqual(logs.filtered(category: .sensor).count, 1)
        XCTAssertEqual(logs.filtered(category: .export).count, 0)
    }

    func testFilteredByDevice() {
        let logs = [
            LogMessage(message: "M1", deviceId: "device-1"),
            LogMessage(message: "M2", deviceId: "device-2"),
            LogMessage(message: "M3", deviceId: "device-1")
        ]

        XCTAssertEqual(logs.filtered(deviceId: "device-1").count, 2)
        XCTAssertEqual(logs.filtered(deviceId: "device-3").count, 0)
    }

    func testRecent() {
        let now = Date()
        let logs = [
            LogMessage(message: "Old", timestamp: now.addingTimeInterval(-60)),
            LogMessage(message: "Newer", timestamp: now.addingTimeInterval(-30)),
            LogMessage(message: "Newest", timestamp: now)
        ]

        let recent = logs.recent(2)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first?.message, "Newest")
    }

    func testExportToString() {
        let now = Date()
        let logs = [
            LogMessage(message: "Second", timestamp: now.addingTimeInterval(1)),
            LogMessage(message: "First", timestamp: now)
        ]

        let exported = logs.exportToString()
        let lines = exported.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("First"))
        XCTAssertTrue(lines[1].contains("Second"))
    }
}

// MARK: - HistoricalDataPoint Tests

final class HistoricalDataPointTests: XCTestCase {

    func testBasicInitialization() {
        let point = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 85,
            movementIntensity: 4098  // ~1g at rest
        )

        XCTAssertEqual(point.averageTemperature, 36.5)
        XCTAssertEqual(point.averageBattery, 85)
        XCTAssertNil(point.averageHeartRate)
        XCTAssertNil(point.averageSpO2)
    }

    func testMovementIntensityInG() {
        // 4098 raw ≈ 1g (at 0.244 mg/digit sensitivity)
        let atRest = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 85,
            movementIntensity: 4098
        )

        XCTAssertEqual(atRest.movementIntensityInG, 1.0, accuracy: 0.1)
    }

    func testIsAtRest() {
        let atRest = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 85,
            movementIntensity: 4098  // ~1g
        )
        XCTAssertTrue(atRest.isAtRest)

        let moving = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 85,
            movementIntensity: 8196  // ~2g
        )
        XCTAssertFalse(moving.isAtRest)
    }

    func testTemperatureStatus() {
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 33, averageBattery: 85, movementIntensity: 0).temperatureStatus,
            .low
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 35, averageBattery: 85, movementIntensity: 0).temperatureStatus,
            .belowNormal
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 85, movementIntensity: 0).temperatureStatus,
            .normal
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 38, averageBattery: 85, movementIntensity: 0).temperatureStatus,
            .slightlyElevated
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 39, averageBattery: 85, movementIntensity: 0).temperatureStatus,
            .elevated
        )
    }

    func testBatteryStatus() {
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 5, movementIntensity: 0).batteryStatus,
            .critical
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 15, movementIntensity: 0).batteryStatus,
            .low
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 35, movementIntensity: 0).batteryStatus,
            .medium
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 65, movementIntensity: 0).batteryStatus,
            .good
        )
        XCTAssertEqual(
            HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 95, movementIntensity: 0).batteryStatus,
            .excellent
        )
    }

    func testEquatableAndHashable() {
        let id = UUID()
        let point1 = HistoricalDataPoint(id: id, timestamp: Date(), averageTemperature: 36.5, averageBattery: 85, movementIntensity: 0)
        let point2 = HistoricalDataPoint(id: id, timestamp: Date(), averageTemperature: 37.0, averageBattery: 90, movementIntensity: 100)

        // Same ID = equal
        XCTAssertEqual(point1, point2)

        // Different IDs
        let point3 = HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 85, movementIntensity: 0)
        XCTAssertNotEqual(point1, point3)
    }
}
