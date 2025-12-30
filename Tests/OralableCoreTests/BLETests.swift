//
//  BLETests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for BLE constants, data parsing, and sensor data buffers
//

import XCTest
import Combine
@testable import OralableCore

// MARK: - BLE Constants Tests

final class BLEConstantsTests: XCTestCase {

    // MARK: - TGM Service UUIDs

    func testTGMServiceUUID() {
        XCTAssertEqual(BLEConstants.TGM.serviceUUID, "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    }

    func testTGMCharacteristicUUIDs() {
        XCTAssertEqual(BLEConstants.TGM.sensorDataCharUUID, "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
        XCTAssertEqual(BLEConstants.TGM.accelerometerCharUUID, "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
        XCTAssertEqual(BLEConstants.TGM.commandCharUUID, "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
        XCTAssertEqual(BLEConstants.TGM.batteryCharUUID, "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
    }

    func testTGMAllCharacteristics() {
        let chars = BLEConstants.TGM.allCharacteristicUUIDs
        XCTAssertEqual(chars.count, 4)
        XCTAssertTrue(chars.contains(BLEConstants.TGM.sensorDataCharUUID))
        XCTAssertTrue(chars.contains(BLEConstants.TGM.accelerometerCharUUID))
        XCTAssertTrue(chars.contains(BLEConstants.TGM.commandCharUUID))
        XCTAssertTrue(chars.contains(BLEConstants.TGM.batteryCharUUID))
    }

    func testTGMPacketSizes() {
        XCTAssertEqual(BLEConstants.TGM.PacketSize.ppgData, 244)
        XCTAssertEqual(BLEConstants.TGM.PacketSize.accelerometer, 154)
        XCTAssertEqual(BLEConstants.TGM.PacketSize.temperature, 8)
        XCTAssertEqual(BLEConstants.TGM.PacketSize.battery, 4)
    }

    func testTGMDataFormat() {
        XCTAssertEqual(BLEConstants.TGM.DataFormat.bytesPerPPGSample, 12)
        XCTAssertEqual(BLEConstants.TGM.DataFormat.bytesPerAccelSample, 6)
        XCTAssertEqual(BLEConstants.TGM.DataFormat.ppgValueSize, 4)
        XCTAssertEqual(BLEConstants.TGM.DataFormat.accelValueSize, 2)
    }

    // MARK: - ANR Service UUIDs

    func testANRServiceUUIDs() {
        XCTAssertEqual(BLEConstants.ANR.automationIOServiceUUID, "1815")
        XCTAssertEqual(BLEConstants.ANR.analogCharUUID, "2A58")
        XCTAssertEqual(BLEConstants.ANR.digitalCharUUID, "2A56")
    }

    func testANRDataFormat() {
        XCTAssertEqual(BLEConstants.ANR.DataFormat.emgMin, 0)
        XCTAssertEqual(BLEConstants.ANR.DataFormat.emgMax, 1023)
        XCTAssertEqual(BLEConstants.ANR.DataFormat.emgNotificationIntervalMs, 100)
        XCTAssertTrue(BLEConstants.ANR.DataFormat.deviceIdRange.contains(1))
        XCTAssertTrue(BLEConstants.ANR.DataFormat.deviceIdRange.contains(24))
        XCTAssertFalse(BLEConstants.ANR.DataFormat.deviceIdRange.contains(0))
        XCTAssertFalse(BLEConstants.ANR.DataFormat.deviceIdRange.contains(25))
    }

    // MARK: - Standard BLE UUIDs

    func testStandardBatteryService() {
        XCTAssertEqual(BLEConstants.StandardBLE.batteryServiceUUID, "180F")
        XCTAssertEqual(BLEConstants.StandardBLE.batteryLevelCharUUID, "2A19")
    }

    func testStandardDeviceInfoService() {
        XCTAssertEqual(BLEConstants.StandardBLE.deviceInfoServiceUUID, "180A")
        XCTAssertEqual(BLEConstants.StandardBLE.modelNumberCharUUID, "2A24")
        XCTAssertEqual(BLEConstants.StandardBLE.serialNumberCharUUID, "2A25")
        XCTAssertEqual(BLEConstants.StandardBLE.firmwareRevisionCharUUID, "2A26")
        XCTAssertEqual(BLEConstants.StandardBLE.manufacturerNameCharUUID, "2A29")
    }

    func testDeviceInfoCharacteristics() {
        let chars = BLEConstants.StandardBLE.deviceInfoCharUUIDs
        XCTAssertGreaterThanOrEqual(chars.count, 5)
        XCTAssertTrue(chars.contains(BLEConstants.StandardBLE.modelNumberCharUUID))
        XCTAssertTrue(chars.contains(BLEConstants.StandardBLE.serialNumberCharUUID))
    }

    // MARK: - Device Detection

    func testDetectOralableDevice() {
        XCTAssertTrue(BLEConstants.Detection.isOralableDevice(serviceUUID: BLEConstants.TGM.serviceUUID))
        XCTAssertTrue(BLEConstants.Detection.isOralableDevice(serviceUUID: BLEConstants.TGM.serviceUUID.lowercased()))
        XCTAssertFalse(BLEConstants.Detection.isOralableDevice(serviceUUID: "1815"))
        XCTAssertFalse(BLEConstants.Detection.isOralableDevice(serviceUUID: "invalid"))
    }

    func testDetectANRDevice() {
        XCTAssertTrue(BLEConstants.Detection.isANRDevice(serviceUUID: "1815"))
        XCTAssertTrue(BLEConstants.Detection.isANRDevice(serviceUUID: "00001815-0000-1000-8000-00805F9B34FB"))
        XCTAssertFalse(BLEConstants.Detection.isANRDevice(serviceUUID: BLEConstants.TGM.serviceUUID))
    }

    func testDetectDeviceType() {
        XCTAssertEqual(BLEConstants.Detection.detectDeviceType(serviceUUIDs: [BLEConstants.TGM.serviceUUID]), .oralable)
        XCTAssertEqual(BLEConstants.Detection.detectDeviceType(serviceUUIDs: ["1815"]), .anr)
        XCTAssertNil(BLEConstants.Detection.detectDeviceType(serviceUUIDs: ["unknown"]))
        XCTAssertNil(BLEConstants.Detection.detectDeviceType(serviceUUIDs: []))
    }

    func testPrimaryServiceUUID() {
        XCTAssertEqual(BLEConstants.Detection.primaryServiceUUID(for: .oralable), BLEConstants.TGM.serviceUUID)
        XCTAssertEqual(BLEConstants.Detection.primaryServiceUUID(for: .anr), BLEConstants.ANR.automationIOServiceUUID)
        XCTAssertEqual(BLEConstants.Detection.primaryServiceUUID(for: .demo), "00000000-0000-0000-0000-000000000000")
    }

    func testServiceUUIDsForDeviceType() {
        let oralableServices = BLEConstants.Detection.serviceUUIDs(for: .oralable)
        XCTAssertTrue(oralableServices.contains(BLEConstants.TGM.serviceUUID))
        XCTAssertTrue(oralableServices.contains(BLEConstants.StandardBLE.batteryServiceUUID))

        let anrServices = BLEConstants.Detection.serviceUUIDs(for: .anr)
        XCTAssertTrue(anrServices.contains(BLEConstants.ANR.automationIOServiceUUID))

        let demoServices = BLEConstants.Detection.serviceUUIDs(for: .demo)
        XCTAssertTrue(demoServices.isEmpty)
    }

    // MARK: - UUID Formatting

    func testExpandShortUUID() {
        XCTAssertEqual(
            BLEConstants.Formatting.expandShortUUID("180F"),
            "0000180F-0000-1000-8000-00805F9B34FB"
        )
        XCTAssertEqual(
            BLEConstants.Formatting.expandShortUUID("2a19"),
            "00002A19-0000-1000-8000-00805F9B34FB"
        )
    }

    func testIsShortUUID() {
        XCTAssertTrue(BLEConstants.Formatting.isShortUUID("180F"))
        XCTAssertTrue(BLEConstants.Formatting.isShortUUID("2A19"))
        XCTAssertFalse(BLEConstants.Formatting.isShortUUID("0000180F-0000-1000-8000-00805F9B34FB"))
        XCTAssertFalse(BLEConstants.Formatting.isShortUUID("invalid"))
        XCTAssertFalse(BLEConstants.Formatting.isShortUUID("180"))
    }

    func testNormalizeUUID() {
        // Short UUID should be expanded
        XCTAssertEqual(
            BLEConstants.Formatting.normalizeUUID("180f"),
            "0000180F-0000-1000-8000-00805F9B34FB"
        )

        // Full UUID should be uppercased
        XCTAssertEqual(
            BLEConstants.Formatting.normalizeUUID("3a0ff000-98c4-46b2-94af-1aee0fd4c48e"),
            "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E"
        )
    }

    // MARK: - RSSI Thresholds

    func testRSSIThresholds() {
        XCTAssertEqual(BLEConstants.RSSIThresholds.excellent, -50)
        XCTAssertEqual(BLEConstants.RSSIThresholds.good, -60)
        XCTAssertEqual(BLEConstants.RSSIThresholds.fair, -70)
        XCTAssertEqual(BLEConstants.RSSIThresholds.weak, -80)
        XCTAssertEqual(BLEConstants.RSSIThresholds.poor, -100)
        XCTAssertEqual(BLEConstants.RSSIThresholds.minimum, -90)
    }
}

// MARK: - BLE Data Parser Tests

final class BLEDataParserTests: XCTestCase {

    // MARK: - PPG Data Parsing

    func testParsePPGDataValidPacket() {
        // Create a 12-byte PPG sample: Red(4) + IR(4) + Green(4)
        var data = Data()

        // Red: 120000
        var red: UInt32 = 120000
        data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })

        // IR: 150000
        var ir: UInt32 = 150000
        data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })

        // Green: 80000
        var green: UInt32 = 80000
        data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })

        let readings = BLEDataParser.parsePPGData(data)

        XCTAssertNotNil(readings)
        XCTAssertEqual(readings?.count, 1)

        if let reading = readings?.first {
            XCTAssertEqual(reading.red, Int32(bitPattern: 120000))
            XCTAssertEqual(reading.ir, Int32(bitPattern: 150000))
            XCTAssertEqual(reading.green, Int32(bitPattern: 80000))
        }
    }

    func testParsePPGDataMultipleSamples() {
        // Create 24 bytes = 2 PPG samples
        var data = Data()

        for i in 0..<2 {
            var red: UInt32 = UInt32(100000 + i * 10000)
            var ir: UInt32 = UInt32(150000 + i * 10000)
            var green: UInt32 = UInt32(80000 + i * 10000)

            data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })
        }

        let readings = BLEDataParser.parsePPGData(data)

        XCTAssertNotNil(readings)
        XCTAssertEqual(readings?.count, 2)
    }

    func testParsePPGDataInvalidSize() {
        // Too small (less than 12 bytes)
        let smallData = Data(repeating: 0, count: 8)
        XCTAssertNil(BLEDataParser.parsePPGData(smallData))

        // Empty data
        let emptyData = Data()
        XCTAssertNil(BLEDataParser.parsePPGData(emptyData))
    }

    func testParseSinglePPG() {
        var data = Data()
        var red: UInt32 = 100000
        var ir: UInt32 = 150000
        var green: UInt32 = 80000

        data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })

        let reading = BLEDataParser.parseSinglePPG(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.red, Int32(bitPattern: 100000))
        XCTAssertEqual(reading?.ir, Int32(bitPattern: 150000))
        XCTAssertEqual(reading?.green, Int32(bitPattern: 80000))
    }

    // MARK: - Accelerometer Data Parsing

    func testParseAccelerometerDataValidPacket() {
        // Create 6-byte accelerometer sample: X(2) + Y(2) + Z(2)
        var data = Data()

        var x: Int16 = 100
        var y: Int16 = -200
        var z: Int16 = 16384  // ~1g

        data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })

        let readings = BLEDataParser.parseAccelerometerData(data)

        XCTAssertNotNil(readings)
        XCTAssertEqual(readings?.count, 1)

        if let reading = readings?.first {
            XCTAssertEqual(reading.x, 100)
            XCTAssertEqual(reading.y, -200)
            XCTAssertEqual(reading.z, 16384)
        }
    }

    func testParseAccelerometerDataMultipleSamples() {
        // Create 12 bytes = 2 accelerometer samples
        var data = Data()

        for i: Int16 in 0..<2 {
            var x: Int16 = 100 + i * 50
            var y: Int16 = -200 - i * 50
            var z: Int16 = 16384

            data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })
        }

        let readings = BLEDataParser.parseAccelerometerData(data)

        XCTAssertNotNil(readings)
        XCTAssertEqual(readings?.count, 2)
    }

    func testParseAccelerometerDataInvalidSize() {
        let smallData = Data(repeating: 0, count: 4)
        XCTAssertNil(BLEDataParser.parseAccelerometerData(smallData))

        let emptyData = Data()
        XCTAssertNil(BLEDataParser.parseAccelerometerData(emptyData))
    }

    func testParseSingleAccelerometer() {
        var data = Data()
        var x: Int16 = 500
        var y: Int16 = -300
        var z: Int16 = 16000

        data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })

        let reading = BLEDataParser.parseSingleAccelerometer(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.x, 500)
        XCTAssertEqual(reading?.y, -300)
        XCTAssertEqual(reading?.z, 16000)
    }

    // MARK: - Temperature Data Parsing

    func testParseTemperatureDataFloat() {
        var data = Data()
        var temp: Float = 36.5
        data.append(contentsOf: withUnsafeBytes(of: &temp) { Array($0) })

        let reading = BLEDataParser.parseTemperatureData(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.celsius ?? 0, 36.5, accuracy: 0.1)
    }

    func testParseTemperatureDataInt16() {
        // 365 tenths of degrees = 36.5°C
        var data = Data()
        var tenths: Int16 = 365
        data.append(contentsOf: withUnsafeBytes(of: &tenths) { Array($0) })

        let reading = BLEDataParser.parseTemperatureData(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.celsius ?? 0, 36.5, accuracy: 0.1)
    }

    func testParseTemperatureDataOutOfRange() {
        // Temperature too low
        var data = Data()
        var temp: Float = 5.0
        data.append(contentsOf: withUnsafeBytes(of: &temp) { Array($0) })

        XCTAssertNil(BLEDataParser.parseTemperatureData(data))

        // Temperature too high
        var data2 = Data()
        var temp2: Float = 60.0
        data2.append(contentsOf: withUnsafeBytes(of: &temp2) { Array($0) })

        XCTAssertNil(BLEDataParser.parseTemperatureData(data2))
    }

    // MARK: - Battery Data Parsing

    func testParseTGMBatteryDataValid() {
        var data = Data()
        var millivolts: Int32 = 3700  // ~50% battery

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        let reading = BLEDataParser.parseTGMBatteryData(data)

        XCTAssertNotNil(reading)
        XCTAssertGreaterThan(reading?.percentage ?? 0, 0)
        XCTAssertLessThanOrEqual(reading?.percentage ?? 100, 100)
    }

    func testParseTGMBatteryDataFullCharge() {
        var data = Data()
        var millivolts: Int32 = 4200  // Full battery

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        let reading = BLEDataParser.parseTGMBatteryData(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.percentage, 100)
    }

    func testParseTGMBatteryDataLowBattery() {
        var data = Data()
        var millivolts: Int32 = 3000  // Low battery

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        let reading = BLEDataParser.parseTGMBatteryData(data)

        XCTAssertNotNil(reading)
        XCTAssertLessThan(reading?.percentage ?? 100, 20)
    }

    func testParseTGMBatteryDataOutOfRange() {
        // Too low
        var data = Data()
        var millivolts: Int32 = 2000

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        XCTAssertNil(BLEDataParser.parseTGMBatteryData(data))

        // Too high
        var data2 = Data()
        var millivolts2: Int32 = 5000

        data2.append(contentsOf: withUnsafeBytes(of: &millivolts2) { Array($0) })

        XCTAssertNil(BLEDataParser.parseTGMBatteryData(data2))
    }

    func testParseStandardBatteryLevel() {
        let data = Data([85])  // 85%
        let reading = BLEDataParser.parseStandardBatteryLevel(data)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.percentage, 85)
    }

    func testParseStandardBatteryLevelBoundary() {
        let zeroData = Data([0])
        let zeroReading = BLEDataParser.parseStandardBatteryLevel(zeroData)
        XCTAssertEqual(zeroReading?.percentage, 0)

        let fullData = Data([100])
        let fullReading = BLEDataParser.parseStandardBatteryLevel(fullData)
        XCTAssertEqual(fullReading?.percentage, 100)
    }

    // MARK: - EMG Data Parsing

    func testParseEMGDataValid() {
        var data = Data()
        var value: UInt16 = 512  // Mid-range

        data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })

        let normalized = BLEDataParser.parseEMGData(data)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized ?? 0, 512.0 / 1023.0, accuracy: 0.01)
    }

    func testParseEMGDataMax() {
        var data = Data()
        var value: UInt16 = 1023

        data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })

        let normalized = BLEDataParser.parseEMGData(data)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized ?? 0, 1.0, accuracy: 0.01)
    }

    func testParseEMGDataOutOfRange() {
        var data = Data()
        var value: UInt16 = 2000  // Above max

        data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })

        XCTAssertNil(BLEDataParser.parseEMGData(data))
    }

    func testParseEMGRaw() {
        var data = Data()
        var value: UInt16 = 750

        data.append(contentsOf: withUnsafeBytes(of: &value) { Array($0) })

        let raw = BLEDataParser.parseEMGRaw(data)

        XCTAssertNotNil(raw)
        XCTAssertEqual(raw, 750)
    }

    // MARK: - Combined Sensor Data Parsing

    func testParseCombinedSensorData() {
        var data = Data()

        // PPG: Red(4) + IR(4) + Green(4)
        var red: UInt32 = 100000
        var ir: UInt32 = 150000
        var green: UInt32 = 80000

        data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })

        // Accelerometer: X(2) + Y(2) + Z(2)
        var x: Int16 = 100
        var y: Int16 = -200
        var z: Int16 = 16384

        data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })

        let result = BLEDataParser.parseCombinedSensorData(data)

        XCTAssertNotNil(result)

        if let (ppg, accel) = result {
            XCTAssertEqual(ppg.red, Int32(bitPattern: 100000))
            XCTAssertEqual(ppg.ir, Int32(bitPattern: 150000))
            XCTAssertEqual(ppg.green, Int32(bitPattern: 80000))

            XCTAssertEqual(accel.x, 100)
            XCTAssertEqual(accel.y, -200)
            XCTAssertEqual(accel.z, 16384)
        }
    }

    func testParseCombinedSensorDataInvalidSize() {
        let smallData = Data(repeating: 0, count: 16)
        XCTAssertNil(BLEDataParser.parseCombinedSensorData(smallData))
    }

    // MARK: - String Parsing

    func testParseStringData() {
        let testString = "Oralable Device"
        let data = testString.data(using: .utf8)!

        let parsed = BLEDataParser.parseStringData(data)

        XCTAssertEqual(parsed, testString)
    }

    func testParseStringDataWithControlChars() {
        let data = "Test\0Device".data(using: .utf8)!
        let parsed = BLEDataParser.parseStringData(data)

        XCTAssertNotNil(parsed)
        // The parser trims control characters from the edges, not the middle
        // So "Test\0Device" becomes "Test\0Device" (null in middle is preserved)
        // This is actually correct behavior for string parsing
        XCTAssertTrue(parsed?.contains("Test") ?? false)
        XCTAssertTrue(parsed?.contains("Device") ?? false)
    }

    // MARK: - ANR Device ID Parsing

    func testParseANRDeviceIDValid() {
        let data = Data([12])  // Device ID 12
        let deviceId = BLEDataParser.parseANRDeviceID(data)

        XCTAssertNotNil(deviceId)
        XCTAssertEqual(deviceId, 12)
    }

    func testParseANRDeviceIDBoundary() {
        let minData = Data([1])
        XCTAssertEqual(BLEDataParser.parseANRDeviceID(minData), 1)

        let maxData = Data([24])
        XCTAssertEqual(BLEDataParser.parseANRDeviceID(maxData), 24)
    }

    func testParseANRDeviceIDOutOfRange() {
        let zeroData = Data([0])
        XCTAssertNil(BLEDataParser.parseANRDeviceID(zeroData))

        let highData = Data([25])
        XCTAssertNil(BLEDataParser.parseANRDeviceID(highData))
    }

    // MARK: - Validated Parsing

    func testParsePPGDataValidated() {
        // Create valid PPG data
        var data = Data()
        var red: UInt32 = 100000
        var ir: UInt32 = 150000
        var green: UInt32 = 80000

        data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })

        let result = BLEDataParser.parsePPGDataValidated(data)

        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertEqual(result.value?.count, 1)
    }

    func testParsePPGDataValidatedInsufficientData() {
        let smallData = Data(repeating: 0, count: 8)
        let result = BLEDataParser.parsePPGDataValidated(smallData)

        XCTAssertFalse(result.isSuccess)

        if case .insufficientData(let expected, let actual) = result {
            XCTAssertEqual(expected, 12)
            XCTAssertEqual(actual, 8)
        } else {
            XCTFail("Expected insufficientData error")
        }
    }

    func testParseAccelerometerDataValidated() {
        var data = Data()
        var x: Int16 = 100
        var y: Int16 = -200
        var z: Int16 = 16384

        data.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })

        let result = BLEDataParser.parseAccelerometerDataValidated(data)

        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
    }

    func testParseTGMBatteryDataValidated() {
        var data = Data()
        var millivolts: Int32 = 3800

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        let result = BLEDataParser.parseTGMBatteryDataValidated(data)

        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
    }

    func testParseTGMBatteryDataValidatedInvalid() {
        var data = Data()
        var millivolts: Int32 = 2000  // Out of range

        data.append(contentsOf: withUnsafeBytes(of: &millivolts) { Array($0) })

        let result = BLEDataParser.parseTGMBatteryDataValidated(data)

        XCTAssertFalse(result.isSuccess)

        if case .invalidData(let reason) = result {
            XCTAssertFalse(reason.isEmpty)
        } else {
            XCTFail("Expected invalidData error")
        }
    }
}

// MARK: - Sensor Data Buffer Tests

final class SensorDataBufferTests: XCTestCase {

    // MARK: - Basic Operations

    func testBufferInitialization() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        let isEmpty = await buffer.isEmpty
        let count = await buffer.count
        let capacity = await buffer.maxCapacity

        XCTAssertTrue(isEmpty)
        XCTAssertEqual(count, 0)
        XCTAssertEqual(capacity, 100)
    }

    func testBufferAppendSingle() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)
        let sensorData = createTestSensorData()

        await buffer.append(sensorData)

        let count = await buffer.count
        let isEmpty = await buffer.isEmpty

        XCTAssertEqual(count, 1)
        XCTAssertFalse(isEmpty)
    }

    func testBufferAppendMultiple() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)
        let dataArray = (0..<10).map { _ in createTestSensorData() }

        await buffer.append(contentsOf: dataArray)

        let count = await buffer.count
        XCTAssertEqual(count, 10)
    }

    func testBufferCapacityLimit() async {
        let buffer = SensorDataBuffer(maxCapacity: 5)

        for _ in 0..<10 {
            await buffer.append(createTestSensorData())
        }

        let count = await buffer.count
        XCTAssertEqual(count, 5)  // Should not exceed capacity
    }

    func testBufferClear() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        for _ in 0..<5 {
            await buffer.append(createTestSensorData())
        }

        await buffer.clear()

        let isEmpty = await buffer.isEmpty
        XCTAssertTrue(isEmpty)
    }

    // MARK: - Data Access

    func testBufferLatest() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        let data1 = createTestSensorData()
        await buffer.append(data1)

        let data2 = createTestSensorData()
        await buffer.append(data2)

        let latest = await buffer.latest

        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.timestamp, data2.timestamp)
    }

    func testBufferOldest() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        let data1 = createTestSensorData()
        await buffer.append(data1)

        // Small delay to ensure different timestamps
        try? await Task.sleep(nanoseconds: 1_000_000)

        await buffer.append(createTestSensorData())

        let oldest = await buffer.oldest

        XCTAssertNotNil(oldest)
        XCTAssertEqual(oldest?.timestamp, data1.timestamp)
    }

    func testBufferLastN() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        for _ in 0..<10 {
            await buffer.append(createTestSensorData())
        }

        let last3 = await buffer.lastN(3)
        XCTAssertEqual(last3.count, 3)

        let last20 = await buffer.lastN(20)
        XCTAssertEqual(last20.count, 10)  // Only 10 items available
    }

    func testBufferAllData() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        for _ in 0..<5 {
            await buffer.append(createTestSensorData())
        }

        let allData = await buffer.allData
        XCTAssertEqual(allData.count, 5)
    }

    // MARK: - Time-based Operations

    func testBufferRemoveDataBefore() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        // Add data with timestamps in the past
        for _ in 0..<5 {
            await buffer.append(createTestSensorData())
        }

        // Remove data before now (should remove everything)
        let removed = await buffer.removeData(before: Date().addingTimeInterval(1))

        XCTAssertEqual(removed, 5)

        let isEmpty = await buffer.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func testBufferRemoveDataOlderThan() async {
        let buffer = SensorDataBuffer(maxCapacity: 100)

        for _ in 0..<5 {
            await buffer.append(createTestSensorData())
        }

        // Remove data older than 1 hour (should keep everything)
        let removed = await buffer.removeData(olderThan: 3600)
        XCTAssertEqual(removed, 0)

        // Remove data older than 0 seconds (should remove everything)
        let removed2 = await buffer.removeData(olderThan: -1)
        XCTAssertEqual(removed2, 5)
    }

    // MARK: - Helper Methods

    private func createTestSensorData() -> SensorData {
        let ppg = PPGData(red: 120000, ir: 150000, green: 80000, timestamp: Date())
        let accel = AccelerometerData(x: 0, y: 0, z: 16384, timestamp: Date())
        let temp = TemperatureData(celsius: 36.5, timestamp: Date())
        let battery = BatteryData(percentage: 85, timestamp: Date())
        let hr = HeartRateData(bpm: 72, quality: 0.9, timestamp: Date())
        let spo2 = SpO2Data(percentage: 98, quality: 0.9, timestamp: Date())

        return SensorData(
            timestamp: Date(),
            ppg: ppg,
            accelerometer: accel,
            temperature: temp,
            battery: battery,
            heartRate: hr,
            spo2: spo2,
            deviceType: .oralable
        )
    }
}

// MARK: - PPG Data Buffer Tests

final class PPGDataBufferTests: XCTestCase {

    func testPPGBufferInitialization() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)

        let count = await buffer.count
        let capacity = await buffer.maxCapacity

        XCTAssertEqual(count, 0)
        XCTAssertEqual(capacity, 500)
    }

    func testPPGBufferAppendSingle() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)
        let sample = PPGData(red: 120000, ir: 150000, green: 80000, timestamp: Date())

        await buffer.append(sample)

        let count = await buffer.count
        let latest = await buffer.latest

        XCTAssertEqual(count, 1)
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.red, 120000)
    }

    func testPPGBufferAppendMultiple() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)
        var samples: [PPGData] = []
        for i in 0..<10 {
            samples.append(PPGData(red: Int32(100000 + i), ir: Int32(150000 + i), green: Int32(80000 + i), timestamp: Date()))
        }

        await buffer.append(contentsOf: samples)

        let count = await buffer.count
        XCTAssertEqual(count, 10)
    }

    func testPPGBufferCapacityLimit() async {
        let buffer = PPGDataBuffer(maxCapacity: 5)

        for i in 0..<10 {
            let sample = PPGData(red: Int32(i), ir: Int32(i), green: Int32(i), timestamp: Date())
            await buffer.append(sample)
        }

        let count = await buffer.count
        XCTAssertEqual(count, 5)
    }

    func testPPGBufferChannelValues() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)

        for i in 0..<5 {
            let sample = PPGData(
                red: Int32(100000 + i * 1000),
                ir: Int32(150000 + i * 1000),
                green: Int32(80000 + i * 1000),
                timestamp: Date()
            )
            await buffer.append(sample)
        }

        let irValues = await buffer.irValues
        let redValues = await buffer.redValues
        let greenValues = await buffer.greenValues

        XCTAssertEqual(irValues.count, 5)
        XCTAssertEqual(redValues.count, 5)
        XCTAssertEqual(greenValues.count, 5)

        XCTAssertEqual(irValues.first, 150000)
        XCTAssertEqual(redValues.first, 100000)
        XCTAssertEqual(greenValues.first, 80000)
    }

    func testPPGBufferClear() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)

        for _ in 0..<5 {
            let sample = PPGData(red: 100000, ir: 150000, green: 80000, timestamp: Date())
            await buffer.append(sample)
        }

        await buffer.clear()

        let count = await buffer.count
        XCTAssertEqual(count, 0)
    }

    func testPPGBufferLastN() async {
        let buffer = PPGDataBuffer(maxCapacity: 500)

        for i in 0..<10 {
            let sample = PPGData(red: Int32(i), ir: Int32(i), green: Int32(i), timestamp: Date())
            await buffer.append(sample)
        }

        let last5 = await buffer.lastN(5)
        XCTAssertEqual(last5.count, 5)
        XCTAssertEqual(last5.first?.red, 5)  // 5th through 9th (0-indexed)
    }
}

// MARK: - Accelerometer Data Buffer Tests

final class AccelerometerDataBufferTests: XCTestCase {

    func testAccelBufferInitialization() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        let count = await buffer.count
        let capacity = await buffer.maxCapacity

        XCTAssertEqual(count, 0)
        XCTAssertEqual(capacity, 250)
    }

    func testAccelBufferAppendSingle() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)
        let sample = AccelerometerData(x: 100, y: -200, z: 16384, timestamp: Date())

        await buffer.append(sample)

        let count = await buffer.count
        let latest = await buffer.latest

        XCTAssertEqual(count, 1)
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.z, 16384)
    }

    func testAccelBufferMagnitudes() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        // At rest, z should be ~1g
        // For LIS2DTW12 at ±2g with 0.244 mg/digit: 1g = 1000/0.244 ≈ 4098 LSB
        let sample = AccelerometerData(x: 0, y: 0, z: 4098, timestamp: Date())
        await buffer.append(sample)

        let magnitudes = await buffer.magnitudes

        XCTAssertEqual(magnitudes.count, 1)
        XCTAssertEqual(magnitudes.first ?? 0, 1.0, accuracy: 0.01)
    }

    func testAccelBufferAverageMagnitude() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        // Add several samples at rest (4098 LSB = 1g for LIS2DTW12 at ±2g)
        for _ in 0..<10 {
            let sample = AccelerometerData(x: 0, y: 0, z: 4098, timestamp: Date())
            await buffer.append(sample)
        }

        let avgMag = await buffer.averageMagnitude(samples: 10)
        XCTAssertEqual(avgMag, 1.0, accuracy: 0.01)
    }

    func testAccelBufferIsAtRest() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        // At rest with gravity in Z (4098 LSB = 1g for LIS2DTW12 at ±2g)
        for _ in 0..<50 {
            let sample = AccelerometerData(x: 0, y: 0, z: 4098, timestamp: Date())
            await buffer.append(sample)
        }

        let isAtRest = await buffer.isAtRest(threshold: 0.1)
        XCTAssertTrue(isAtRest)
    }

    func testAccelBufferIsNotAtRest() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        // High motion values
        for _ in 0..<50 {
            let sample = AccelerometerData(x: 10000, y: 10000, z: 10000, timestamp: Date())
            await buffer.append(sample)
        }

        let isAtRest = await buffer.isAtRest(threshold: 0.1)
        XCTAssertFalse(isAtRest)
    }

    func testAccelBufferCapacityLimit() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 5)

        for i: Int16 in 0..<10 {
            let sample = AccelerometerData(x: i, y: i, z: i, timestamp: Date())
            await buffer.append(sample)
        }

        let count = await buffer.count
        XCTAssertEqual(count, 5)
    }

    func testAccelBufferClear() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        for _ in 0..<5 {
            let sample = AccelerometerData(x: 0, y: 0, z: 16384, timestamp: Date())
            await buffer.append(sample)
        }

        await buffer.clear()

        let count = await buffer.count
        XCTAssertEqual(count, 0)
    }

    func testAccelBufferLastN() async {
        let buffer = AccelerometerDataBuffer(maxCapacity: 250)

        for i: Int16 in 0..<10 {
            let sample = AccelerometerData(x: i, y: i, z: i, timestamp: Date())
            await buffer.append(sample)
        }

        let last3 = await buffer.lastN(3)
        XCTAssertEqual(last3.count, 3)
        XCTAssertEqual(last3.first?.x, 7)
    }
}

// MARK: - Buffer Statistics Tests

final class BufferStatisticsTests: XCTestCase {

    func testBufferStatisticsCreation() {
        let stats = BufferStatistics(
            sensorType: .heartRate,
            sampleCount: 100,
            mean: 72.5,
            min: 65.0,
            max: 85.0,
            standardDeviation: 5.0,
            duration: 60.0
        )

        XCTAssertEqual(stats.sensorType, .heartRate)
        XCTAssertEqual(stats.sampleCount, 100)
        XCTAssertEqual(stats.mean, 72.5)
        XCTAssertEqual(stats.min, 65.0)
        XCTAssertEqual(stats.max, 85.0)
        XCTAssertEqual(stats.standardDeviation, 5.0)
        XCTAssertEqual(stats.duration, 60.0)
    }

    func testCoefficientOfVariation() {
        let stats = BufferStatistics(
            sensorType: .heartRate,
            sampleCount: 100,
            mean: 100.0,
            min: 90.0,
            max: 110.0,
            standardDeviation: 10.0,
            duration: 60.0
        )

        XCTAssertEqual(stats.coefficientOfVariation, 0.1, accuracy: 0.001)
    }

    func testCoefficientOfVariationZeroMean() {
        let stats = BufferStatistics(
            sensorType: .heartRate,
            sampleCount: 100,
            mean: 0.0,
            min: -10.0,
            max: 10.0,
            standardDeviation: 5.0,
            duration: 60.0
        )

        XCTAssertEqual(stats.coefficientOfVariation, 0.0)
    }

    func testSampleRate() {
        let stats = BufferStatistics(
            sensorType: .ppgInfrared,
            sampleCount: 500,
            mean: 150000.0,
            min: 140000.0,
            max: 160000.0,
            standardDeviation: 5000.0,
            duration: 10.0
        )

        XCTAssertEqual(stats.sampleRate, 50.0, accuracy: 0.001)
    }

    func testSampleRateZeroDuration() {
        let stats = BufferStatistics(
            sensorType: .heartRate,
            sampleCount: 100,
            mean: 72.0,
            min: 60.0,
            max: 80.0,
            standardDeviation: 5.0,
            duration: 0.0
        )

        XCTAssertEqual(stats.sampleRate, 0.0)
    }
}
