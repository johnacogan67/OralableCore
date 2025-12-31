//
//  DeviceProtocolTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for DeviceCommand, DeviceConfiguration, and snapshot types
//

import XCTest
@testable import OralableCore

// MARK: - DeviceCommand Tests

final class DeviceCommandTests: XCTestCase {

    // MARK: - Basic Command Tests

    func testStartSensorsCommand() {
        let command = DeviceCommand.startSensors
        XCTAssertEqual(command.rawValue, "START")
    }

    func testStopSensorsCommand() {
        let command = DeviceCommand.stopSensors
        XCTAssertEqual(command.rawValue, "STOP")
    }

    func testResetCommand() {
        let command = DeviceCommand.reset
        XCTAssertEqual(command.rawValue, "RESET")
    }

    func testCalibrateCommand() {
        let command = DeviceCommand.calibrate
        XCTAssertEqual(command.rawValue, "CALIBRATE")
    }

    func testRequestBatteryLevelCommand() {
        let command = DeviceCommand.requestBatteryLevel
        XCTAssertEqual(command.rawValue, "BATTERY?")
    }

    func testRequestFirmwareVersionCommand() {
        let command = DeviceCommand.requestFirmwareVersion
        XCTAssertEqual(command.rawValue, "VERSION?")
    }

    // MARK: - Parameterized Command Tests

    func testSetSamplingRateCommand() {
        let command50 = DeviceCommand.setSamplingRate(hz: 50)
        XCTAssertEqual(command50.rawValue, "RATE:50")

        let command100 = DeviceCommand.setSamplingRate(hz: 100)
        XCTAssertEqual(command100.rawValue, "RATE:100")

        let command1 = DeviceCommand.setSamplingRate(hz: 1)
        XCTAssertEqual(command1.rawValue, "RATE:1")
    }

    func testEnableSensorCommand() {
        let enableHR = DeviceCommand.enableSensor(.heartRate)
        XCTAssertEqual(enableHR.rawValue, "ENABLE:heart_rate")

        let enablePPG = DeviceCommand.enableSensor(.ppgRed)
        XCTAssertEqual(enablePPG.rawValue, "ENABLE:ppg_red")

        let enableEMG = DeviceCommand.enableSensor(.emg)
        XCTAssertEqual(enableEMG.rawValue, "ENABLE:emg")
    }

    func testDisableSensorCommand() {
        let disableHR = DeviceCommand.disableSensor(.heartRate)
        XCTAssertEqual(disableHR.rawValue, "DISABLE:heart_rate")

        let disableTemp = DeviceCommand.disableSensor(.temperature)
        XCTAssertEqual(disableTemp.rawValue, "DISABLE:temperature")

        let disableAccel = DeviceCommand.disableSensor(.accelerometerX)
        XCTAssertEqual(disableAccel.rawValue, "DISABLE:accel_x")
    }

    func testCustomCommand() {
        let custom1 = DeviceCommand.custom("CUSTOM_CMD")
        XCTAssertEqual(custom1.rawValue, "CUSTOM_CMD")

        let custom2 = DeviceCommand.custom("DEBUG:ENABLE")
        XCTAssertEqual(custom2.rawValue, "DEBUG:ENABLE")

        let emptyCustom = DeviceCommand.custom("")
        XCTAssertEqual(emptyCustom.rawValue, "")
    }

    // MARK: - All Sensor Types Enable/Disable

    func testEnableAllSensorTypes() {
        for sensorType in SensorType.allCases {
            let command = DeviceCommand.enableSensor(sensorType)
            XCTAssertTrue(command.rawValue.hasPrefix("ENABLE:"))
            XCTAssertTrue(command.rawValue.contains(sensorType.rawValue))
        }
    }

    func testDisableAllSensorTypes() {
        for sensorType in SensorType.allCases {
            let command = DeviceCommand.disableSensor(sensorType)
            XCTAssertTrue(command.rawValue.hasPrefix("DISABLE:"))
            XCTAssertTrue(command.rawValue.contains(sensorType.rawValue))
        }
    }

    // MARK: - Sendable Conformance

    func testDeviceCommandSendable() {
        let command = DeviceCommand.startSensors

        Task {
            let raw = command.rawValue
            XCTAssertEqual(raw, "START")
        }
    }

    func testParameterizedCommandSendable() {
        let command = DeviceCommand.setSamplingRate(hz: 50)

        Task {
            let raw = command.rawValue
            XCTAssertEqual(raw, "RATE:50")
        }
    }
}

// MARK: - DeviceConfiguration Tests

final class DeviceConfigurationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testFullInitialization() {
        let config = DeviceConfiguration(
            samplingRate: 75,
            enabledSensors: [.heartRate, .spo2],
            autoReconnect: false,
            notificationsEnabled: false,
            bufferSize: 200
        )

        XCTAssertEqual(config.samplingRate, 75)
        XCTAssertEqual(config.enabledSensors.count, 2)
        XCTAssertTrue(config.enabledSensors.contains(.heartRate))
        XCTAssertTrue(config.enabledSensors.contains(.spo2))
        XCTAssertFalse(config.autoReconnect)
        XCTAssertFalse(config.notificationsEnabled)
        XCTAssertEqual(config.bufferSize, 200)
    }

    func testDefaultParameterValues() {
        let config = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: [.heartRate]
        )

        XCTAssertEqual(config.samplingRate, 50)
        XCTAssertTrue(config.autoReconnect)  // Default
        XCTAssertTrue(config.notificationsEnabled)  // Default
        XCTAssertEqual(config.bufferSize, 100)  // Default
    }

    func testEmptySensors() {
        let config = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: []
        )

        XCTAssertTrue(config.enabledSensors.isEmpty)
    }

    // MARK: - Preset Tests

    func testOralablePreset() {
        let config = DeviceConfiguration.oralable

        XCTAssertEqual(config.samplingRate, 50)
        XCTAssertTrue(config.enabledSensors.contains(.ppgRed))
        XCTAssertTrue(config.enabledSensors.contains(.ppgInfrared))
        XCTAssertTrue(config.enabledSensors.contains(.ppgGreen))
        XCTAssertTrue(config.enabledSensors.contains(.accelerometerX))
        XCTAssertTrue(config.enabledSensors.contains(.accelerometerY))
        XCTAssertTrue(config.enabledSensors.contains(.accelerometerZ))
        XCTAssertTrue(config.enabledSensors.contains(.temperature))
        XCTAssertTrue(config.enabledSensors.contains(.battery))
        XCTAssertTrue(config.autoReconnect)
        XCTAssertTrue(config.notificationsEnabled)
        XCTAssertEqual(config.bufferSize, 100)
    }

    func testANRPreset() {
        let config = DeviceConfiguration.anr

        XCTAssertEqual(config.samplingRate, 100)
        XCTAssertTrue(config.enabledSensors.contains(.emg))
        XCTAssertTrue(config.enabledSensors.contains(.battery))
        XCTAssertEqual(config.enabledSensors.count, 2)
        XCTAssertTrue(config.autoReconnect)
        XCTAssertEqual(config.bufferSize, 200)
    }

    func testDemoPreset() {
        let config = DeviceConfiguration.demo

        XCTAssertEqual(config.samplingRate, 10)
        XCTAssertFalse(config.autoReconnect)  // Demo doesn't auto-reconnect
        XCTAssertTrue(config.notificationsEnabled)
        XCTAssertEqual(config.bufferSize, 50)
        // Demo includes all sensor types
        XCTAssertEqual(config.enabledSensors.count, SensorType.allCases.count)
    }

    // MARK: - Factory Method Tests

    func testForDeviceOralable() {
        let config = DeviceConfiguration.forDevice(.oralable)
        XCTAssertEqual(config, DeviceConfiguration.oralable)
    }

    func testForDeviceANR() {
        let config = DeviceConfiguration.forDevice(.anr)
        XCTAssertEqual(config, DeviceConfiguration.anr)
    }

    func testForDeviceDemo() {
        let config = DeviceConfiguration.forDevice(.demo)
        XCTAssertEqual(config, DeviceConfiguration.demo)
    }

    // MARK: - Equatable Tests

    func testEquatableIdentical() {
        let config1 = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: [.heartRate, .spo2],
            autoReconnect: true,
            notificationsEnabled: true,
            bufferSize: 100
        )
        let config2 = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: [.heartRate, .spo2],
            autoReconnect: true,
            notificationsEnabled: true,
            bufferSize: 100
        )

        XCTAssertEqual(config1, config2)
    }

    func testEquatableDifferentSamplingRate() {
        let config1 = DeviceConfiguration(samplingRate: 50, enabledSensors: [.heartRate])
        let config2 = DeviceConfiguration(samplingRate: 100, enabledSensors: [.heartRate])

        XCTAssertNotEqual(config1, config2)
    }

    func testEquatableDifferentSensors() {
        let config1 = DeviceConfiguration(samplingRate: 50, enabledSensors: [.heartRate])
        let config2 = DeviceConfiguration(samplingRate: 50, enabledSensors: [.spo2])

        XCTAssertNotEqual(config1, config2)
    }

    func testEquatableDifferentAutoReconnect() {
        let config1 = DeviceConfiguration(samplingRate: 50, enabledSensors: [], autoReconnect: true)
        let config2 = DeviceConfiguration(samplingRate: 50, enabledSensors: [], autoReconnect: false)

        XCTAssertNotEqual(config1, config2)
    }

    func testEquatableDifferentBufferSize() {
        let config1 = DeviceConfiguration(samplingRate: 50, enabledSensors: [], bufferSize: 100)
        let config2 = DeviceConfiguration(samplingRate: 50, enabledSensors: [], bufferSize: 200)

        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = DeviceConfiguration(
            samplingRate: 75,
            enabledSensors: [.heartRate, .spo2, .temperature],
            autoReconnect: false,
            notificationsEnabled: true,
            bufferSize: 150
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeviceConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableOralablePreset() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = DeviceConfiguration.oralable
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeviceConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableANRPreset() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = DeviceConfiguration.anr
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeviceConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableEmptySensors() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let original = DeviceConfiguration(samplingRate: 50, enabledSensors: [])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DeviceConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.enabledSensors.isEmpty)
    }

    // MARK: - Sendable Tests

    func testSendable() {
        let config = DeviceConfiguration.oralable

        Task {
            let rate = config.samplingRate
            XCTAssertEqual(rate, 50)
        }
    }

    // MARK: - Mutability Tests

    func testMutability() {
        var config = DeviceConfiguration(samplingRate: 50, enabledSensors: [.heartRate])

        config.samplingRate = 100
        XCTAssertEqual(config.samplingRate, 100)

        config.enabledSensors.insert(.spo2)
        XCTAssertTrue(config.enabledSensors.contains(.spo2))

        config.autoReconnect = false
        XCTAssertFalse(config.autoReconnect)

        config.bufferSize = 300
        XCTAssertEqual(config.bufferSize, 300)
    }
}

// MARK: - RealtimeSensorSnapshot Tests

final class RealtimeSensorSnapshotTests: XCTestCase {

    func testFullInitialization() {
        let timestamp = Date()
        let snapshot = RealtimeSensorSnapshot(
            accelX: 0.1,
            accelY: -0.2,
            accelZ: 9.8,
            temperature: 36.5,
            timestamp: timestamp
        )

        XCTAssertEqual(snapshot.accelX, 0.1)
        XCTAssertEqual(snapshot.accelY, -0.2)
        XCTAssertEqual(snapshot.accelZ, 9.8)
        XCTAssertEqual(snapshot.temperature, 36.5)
        XCTAssertEqual(snapshot.timestamp, timestamp)
    }

    func testDefaultTimestamp() {
        let beforeCreation = Date()
        let snapshot = RealtimeSensorSnapshot(
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 0.0,
            temperature: 0.0
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(snapshot.timestamp, beforeCreation)
        XCTAssertLessThanOrEqual(snapshot.timestamp, afterCreation)
    }

    func testZeroValues() {
        let snapshot = RealtimeSensorSnapshot(
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 0.0,
            temperature: 0.0
        )

        XCTAssertEqual(snapshot.accelX, 0.0)
        XCTAssertEqual(snapshot.accelY, 0.0)
        XCTAssertEqual(snapshot.accelZ, 0.0)
        XCTAssertEqual(snapshot.temperature, 0.0)
    }

    func testNegativeValues() {
        let snapshot = RealtimeSensorSnapshot(
            accelX: -10.0,
            accelY: -20.0,
            accelZ: -30.0,
            temperature: -5.0
        )

        XCTAssertEqual(snapshot.accelX, -10.0)
        XCTAssertEqual(snapshot.accelY, -20.0)
        XCTAssertEqual(snapshot.accelZ, -30.0)
        XCTAssertEqual(snapshot.temperature, -5.0)
    }

    func testLargeValues() {
        let snapshot = RealtimeSensorSnapshot(
            accelX: 1000.0,
            accelY: 2000.0,
            accelZ: 3000.0,
            temperature: 100.0
        )

        XCTAssertEqual(snapshot.accelX, 1000.0)
        XCTAssertEqual(snapshot.accelY, 2000.0)
        XCTAssertEqual(snapshot.accelZ, 3000.0)
        XCTAssertEqual(snapshot.temperature, 100.0)
    }

    func testSendable() {
        let snapshot = RealtimeSensorSnapshot(
            accelX: 1.0,
            accelY: 2.0,
            accelZ: 3.0,
            temperature: 37.0
        )

        Task {
            let x = snapshot.accelX
            XCTAssertEqual(x, 1.0)
        }
    }
}

// MARK: - PPGSnapshot Tests

final class PPGSnapshotTests: XCTestCase {

    func testFullInitialization() {
        let timestamp = Date()
        let snapshot = PPGSnapshot(
            red: 80000.0,
            infrared: 100000.0,
            green: 50000.0,
            timestamp: timestamp
        )

        XCTAssertEqual(snapshot.red, 80000.0)
        XCTAssertEqual(snapshot.infrared, 100000.0)
        XCTAssertEqual(snapshot.green, 50000.0)
        XCTAssertEqual(snapshot.timestamp, timestamp)
    }

    func testDefaultTimestamp() {
        let beforeCreation = Date()
        let snapshot = PPGSnapshot(
            red: 0.0,
            infrared: 0.0,
            green: 0.0
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(snapshot.timestamp, beforeCreation)
        XCTAssertLessThanOrEqual(snapshot.timestamp, afterCreation)
    }

    func testZeroValues() {
        let snapshot = PPGSnapshot(
            red: 0.0,
            infrared: 0.0,
            green: 0.0
        )

        XCTAssertEqual(snapshot.red, 0.0)
        XCTAssertEqual(snapshot.infrared, 0.0)
        XCTAssertEqual(snapshot.green, 0.0)
    }

    func testTypicalPPGValues() {
        // Typical raw PPG values from sensor
        let snapshot = PPGSnapshot(
            red: 85000.0,
            infrared: 105000.0,
            green: 45000.0
        )

        XCTAssertEqual(snapshot.red, 85000.0)
        XCTAssertEqual(snapshot.infrared, 105000.0)
        XCTAssertEqual(snapshot.green, 45000.0)
    }

    func testNegativeValues() {
        // Shouldn't happen but should handle gracefully
        let snapshot = PPGSnapshot(
            red: -1000.0,
            infrared: -2000.0,
            green: -3000.0
        )

        XCTAssertEqual(snapshot.red, -1000.0)
        XCTAssertEqual(snapshot.infrared, -2000.0)
        XCTAssertEqual(snapshot.green, -3000.0)
    }

    func testVeryLargeValues() {
        let snapshot = PPGSnapshot(
            red: 1000000.0,
            infrared: 2000000.0,
            green: 3000000.0
        )

        XCTAssertEqual(snapshot.red, 1000000.0)
        XCTAssertEqual(snapshot.infrared, 2000000.0)
        XCTAssertEqual(snapshot.green, 3000000.0)
    }

    func testSendable() {
        let snapshot = PPGSnapshot(
            red: 80000.0,
            infrared: 100000.0,
            green: 50000.0
        )

        Task {
            let red = snapshot.red
            XCTAssertEqual(red, 80000.0)
        }
    }
}

// MARK: - DeviceConfiguration Preset Comparison Tests

final class DeviceConfigurationComparisonTests: XCTestCase {

    func testPresetsAreDifferent() {
        XCTAssertNotEqual(DeviceConfiguration.oralable, DeviceConfiguration.anr)
        XCTAssertNotEqual(DeviceConfiguration.oralable, DeviceConfiguration.demo)
        XCTAssertNotEqual(DeviceConfiguration.anr, DeviceConfiguration.demo)
    }

    func testOralableHasMoreSensorsThanANR() {
        let oralable = DeviceConfiguration.oralable
        let anr = DeviceConfiguration.anr

        XCTAssertGreaterThan(oralable.enabledSensors.count, anr.enabledSensors.count)
    }

    func testDemoHasLowestSamplingRate() {
        let oralable = DeviceConfiguration.oralable
        let anr = DeviceConfiguration.anr
        let demo = DeviceConfiguration.demo

        XCTAssertLessThan(demo.samplingRate, oralable.samplingRate)
        XCTAssertLessThan(demo.samplingRate, anr.samplingRate)
    }

    func testANRHasHighestSamplingRate() {
        let oralable = DeviceConfiguration.oralable
        let anr = DeviceConfiguration.anr
        let demo = DeviceConfiguration.demo

        XCTAssertGreaterThan(anr.samplingRate, oralable.samplingRate)
        XCTAssertGreaterThan(anr.samplingRate, demo.samplingRate)
    }

    func testOnlyDemoDisablesAutoReconnect() {
        XCTAssertTrue(DeviceConfiguration.oralable.autoReconnect)
        XCTAssertTrue(DeviceConfiguration.anr.autoReconnect)
        XCTAssertFalse(DeviceConfiguration.demo.autoReconnect)
    }
}

// MARK: - Edge Case Tests

final class DeviceProtocolEdgeCaseTests: XCTestCase {

    func testDeviceCommandWithVeryHighSamplingRate() {
        let command = DeviceCommand.setSamplingRate(hz: 10000)
        XCTAssertEqual(command.rawValue, "RATE:10000")
    }

    func testDeviceCommandWithZeroSamplingRate() {
        let command = DeviceCommand.setSamplingRate(hz: 0)
        XCTAssertEqual(command.rawValue, "RATE:0")
    }

    func testDeviceCommandWithNegativeSamplingRate() {
        let command = DeviceCommand.setSamplingRate(hz: -1)
        XCTAssertEqual(command.rawValue, "RATE:-1")
    }

    func testCustomCommandWithSpecialCharacters() {
        let command = DeviceCommand.custom("CMD:DATA={\"key\":\"value\"}")
        XCTAssertEqual(command.rawValue, "CMD:DATA={\"key\":\"value\"}")
    }

    func testCustomCommandWithUnicode() {
        let command = DeviceCommand.custom("TEST:✓")
        XCTAssertEqual(command.rawValue, "TEST:✓")
    }

    func testConfigurationWithMaxSensors() {
        let config = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: Set(SensorType.allCases)
        )

        XCTAssertEqual(config.enabledSensors.count, SensorType.allCases.count)
    }

    func testConfigurationWithVeryLargeBufferSize() {
        let config = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: [],
            bufferSize: 1000000
        )

        XCTAssertEqual(config.bufferSize, 1000000)
    }

    func testConfigurationWithZeroBufferSize() {
        let config = DeviceConfiguration(
            samplingRate: 50,
            enabledSensors: [],
            bufferSize: 0
        )

        XCTAssertEqual(config.bufferSize, 0)
    }
}
