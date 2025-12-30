//
//  BLEDataParser.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic BLE data parsing utilities
//  Parses raw BLE packet data into OralableCore model types
//

import Foundation

// MARK: - BLE Data Parser

/// Framework-agnostic utilities for parsing raw BLE data packets
/// Converts raw byte data from Oralable devices into typed model objects
public struct BLEDataParser: Sendable {

    // MARK: - PPG Data Parsing

    /// Parse PPG sensor data from raw BLE packet
    /// - Parameter data: Raw data packet (typically 244 bytes for TGM device)
    /// - Returns: Array of PPGData readings, or nil if data is invalid
    public static func parsePPGData(_ data: Data) -> [PPGData]? {
        let bytesPerSample = BLEConstants.TGM.DataFormat.bytesPerPPGSample // 12 bytes

        // Need at least one complete sample
        guard data.count >= bytesPerSample else { return nil }

        let sampleCount = data.count / bytesPerSample
        var readings: [PPGData] = []
        readings.reserveCapacity(sampleCount)

        let timestamp = Date()

        for i in 0..<sampleCount {
            let offset = i * bytesPerSample

            guard offset + bytesPerSample <= data.count else { break }

            let values = data.withUnsafeBytes { ptr -> (red: UInt32, ir: UInt32, green: UInt32) in
                let red = ptr.load(fromByteOffset: offset, as: UInt32.self)
                let ir = ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
                let green = ptr.load(fromByteOffset: offset + 8, as: UInt32.self)
                return (red, ir, green)
            }

            let reading = PPGData(
                red: Int32(bitPattern: values.red),
                ir: Int32(bitPattern: values.ir),
                green: Int32(bitPattern: values.green),
                timestamp: timestamp
            )

            readings.append(reading)
        }

        return readings.isEmpty ? nil : readings
    }

    /// Parse a single PPG sample (12 bytes) for simple data handling
    /// - Parameter data: Raw data (minimum 12 bytes)
    /// - Returns: Single PPGData reading, or nil if invalid
    public static func parseSinglePPG(_ data: Data) -> PPGData? {
        guard data.count >= 12 else { return nil }

        let values = data.withUnsafeBytes { ptr -> (red: UInt32, ir: UInt32, green: UInt32) in
            let red = ptr.load(fromByteOffset: 0, as: UInt32.self)
            let ir = ptr.load(fromByteOffset: 4, as: UInt32.self)
            let green = ptr.load(fromByteOffset: 8, as: UInt32.self)
            return (red, ir, green)
        }

        return PPGData(
            red: Int32(bitPattern: values.red),
            ir: Int32(bitPattern: values.ir),
            green: Int32(bitPattern: values.green),
            timestamp: Date()
        )
    }

    // MARK: - Accelerometer Data Parsing

    /// Parse accelerometer data from raw BLE packet
    /// - Parameter data: Raw data packet (typically 154 bytes for TGM device)
    /// - Returns: Array of AccelerometerData readings, or nil if data is invalid
    public static func parseAccelerometerData(_ data: Data) -> [AccelerometerData]? {
        let bytesPerSample = BLEConstants.TGM.DataFormat.bytesPerAccelSample // 6 bytes

        // Need at least one complete sample
        guard data.count >= bytesPerSample else { return nil }

        let sampleCount = data.count / bytesPerSample
        var readings: [AccelerometerData] = []
        readings.reserveCapacity(sampleCount)

        let timestamp = Date()

        for i in 0..<sampleCount {
            let offset = i * bytesPerSample

            guard offset + bytesPerSample <= data.count else { break }

            let values = data.withUnsafeBytes { ptr -> (x: Int16, y: Int16, z: Int16) in
                let x = ptr.load(fromByteOffset: offset, as: Int16.self)
                let y = ptr.load(fromByteOffset: offset + 2, as: Int16.self)
                let z = ptr.load(fromByteOffset: offset + 4, as: Int16.self)
                return (x, y, z)
            }

            let reading = AccelerometerData(
                x: values.x,
                y: values.y,
                z: values.z,
                timestamp: timestamp
            )

            readings.append(reading)
        }

        return readings.isEmpty ? nil : readings
    }

    /// Parse a single accelerometer sample (6 bytes)
    /// - Parameter data: Raw data (minimum 6 bytes)
    /// - Returns: Single AccelerometerData reading, or nil if invalid
    public static func parseSingleAccelerometer(_ data: Data) -> AccelerometerData? {
        guard data.count >= 6 else { return nil }

        let values = data.withUnsafeBytes { ptr -> (x: Int16, y: Int16, z: Int16) in
            let x = ptr.load(fromByteOffset: 0, as: Int16.self)
            let y = ptr.load(fromByteOffset: 2, as: Int16.self)
            let z = ptr.load(fromByteOffset: 4, as: Int16.self)
            return (x, y, z)
        }

        return AccelerometerData(
            x: values.x,
            y: values.y,
            z: values.z,
            timestamp: Date()
        )
    }

    // MARK: - Temperature Data Parsing

    /// Parse temperature data from raw BLE packet
    /// - Parameter data: Raw data packet (typically 8 bytes)
    /// - Returns: TemperatureData reading, or nil if data is invalid
    public static func parseTemperatureData(_ data: Data) -> TemperatureData? {
        // Temperature can be encoded as:
        // - 4 bytes: Float (Celsius)
        // - 4 bytes: Int32 (millidegrees Celsius)
        // - 2 bytes: Int16 (10ths of degrees)

        if data.count >= 4 {
            // Try parsing as Float first
            let floatValue = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: 0, as: Float.self)
            }

            // Validate range (plausible body/ambient temperature)
            if floatValue > 10.0 && floatValue < 50.0 {
                return TemperatureData(celsius: Double(floatValue), timestamp: Date())
            }

            // Try as Int32 millidegrees
            let milliDegrees = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: 0, as: Int32.self)
            }

            let celsius = Double(milliDegrees) / 1000.0
            if celsius > 10.0 && celsius < 50.0 {
                return TemperatureData(celsius: celsius, timestamp: Date())
            }
        }

        if data.count >= 2 {
            // Try as Int16 (tenths of degrees)
            let tenths = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: 0, as: Int16.self)
            }

            let celsius = Double(tenths) / 10.0
            if celsius > 10.0 && celsius < 50.0 {
                return TemperatureData(celsius: celsius, timestamp: Date())
            }
        }

        return nil
    }

    // MARK: - Battery Data Parsing

    /// Parse TGM battery data (millivolts) from raw BLE packet
    /// - Parameter data: Raw data packet (4 bytes - Int32 millivolts)
    /// - Returns: BatteryData with percentage calculated from voltage, or nil if invalid
    public static func parseTGMBatteryData(_ data: Data) -> BatteryData? {
        guard data.count >= 4 else { return nil }

        let millivolts = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: Int32.self)
        }

        // Validate voltage range (typical LiPo range)
        guard millivolts >= 2500 && millivolts <= 4500 else { return nil }

        let percentage = BatteryConversion.voltageToPercentage(millivolts: millivolts)

        return BatteryData(
            percentage: Int(percentage.rounded()),
            timestamp: Date()
        )
    }

    /// Parse standard Bluetooth battery level (0-100%)
    /// - Parameter data: Raw data packet (1 byte - percentage)
    /// - Returns: BatteryData, or nil if invalid
    public static func parseStandardBatteryLevel(_ data: Data) -> BatteryData? {
        guard data.count >= 1 else { return nil }

        let percentage = Int(data[0])

        // Validate percentage range
        guard percentage >= 0 && percentage <= 100 else { return nil }

        return BatteryData(
            percentage: percentage,
            timestamp: Date()
        )
    }

    // MARK: - EMG Data Parsing (ANR Device)

    /// Parse EMG data from ANR MuscleSense device
    /// - Parameter data: Raw data packet (2 bytes - UInt16, 0-1023 range)
    /// - Returns: EMG value as Double (normalized 0.0-1.0), or nil if invalid
    public static func parseEMGData(_ data: Data) -> Double? {
        guard data.count >= 2 else { return nil }

        let rawValue = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: UInt16.self)
        }

        // Validate range
        guard rawValue <= BLEConstants.ANR.DataFormat.emgMax else { return nil }

        // Normalize to 0.0-1.0 range
        return Double(rawValue) / Double(BLEConstants.ANR.DataFormat.emgMax)
    }

    /// Parse EMG data and return raw value
    /// - Parameter data: Raw data packet (2 bytes)
    /// - Returns: Raw EMG value (0-1023), or nil if invalid
    public static func parseEMGRaw(_ data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }

        let rawValue = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: UInt16.self)
        }

        guard rawValue <= BLEConstants.ANR.DataFormat.emgMax else { return nil }

        return rawValue
    }

    // MARK: - Combined Sensor Data Parsing

    /// Parse a combined sensor data packet (18 bytes)
    /// Format: Red(4) + IR(4) + Green(4) + AccX(2) + AccY(2) + AccZ(2)
    /// - Parameter data: Raw data packet (minimum 18 bytes)
    /// - Returns: Tuple of (PPGData, AccelerometerData), or nil if invalid
    public static func parseCombinedSensorData(_ data: Data) -> (ppg: PPGData, accelerometer: AccelerometerData)? {
        guard data.count >= 18 else { return nil }

        let values = data.withUnsafeBytes { ptr -> (red: UInt32, ir: UInt32, green: UInt32, x: Int16, y: Int16, z: Int16) in
            let red = ptr.load(fromByteOffset: 0, as: UInt32.self)
            let ir = ptr.load(fromByteOffset: 4, as: UInt32.self)
            let green = ptr.load(fromByteOffset: 8, as: UInt32.self)
            let x = ptr.load(fromByteOffset: 12, as: Int16.self)
            let y = ptr.load(fromByteOffset: 14, as: Int16.self)
            let z = ptr.load(fromByteOffset: 16, as: Int16.self)
            return (red, ir, green, x, y, z)
        }

        let timestamp = Date()

        let ppg = PPGData(
            red: Int32(bitPattern: values.red),
            ir: Int32(bitPattern: values.ir),
            green: Int32(bitPattern: values.green),
            timestamp: timestamp
        )

        let accelerometer = AccelerometerData(
            x: values.x,
            y: values.y,
            z: values.z,
            timestamp: timestamp
        )

        return (ppg, accelerometer)
    }

    // MARK: - Device Information Parsing

    /// Parse device information string from raw BLE data
    /// - Parameter data: Raw string data (UTF-8 encoded)
    /// - Returns: Decoded string, or nil if invalid
    public static func parseStringData(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    /// Parse device ID from ANR digital characteristic
    /// - Parameter data: Raw data (1 byte - device ID 1-24)
    /// - Returns: Device ID, or nil if invalid
    public static func parseANRDeviceID(_ data: Data) -> Int? {
        guard data.count >= 1 else { return nil }

        let deviceId = Int(data[0])

        // Validate range
        guard BLEConstants.ANR.DataFormat.deviceIdRange.contains(deviceId) else { return nil }

        return deviceId
    }
}

// MARK: - Parsing Result Types

/// Result of parsing a BLE data packet
public enum BLEParseResult<T>: Sendable where T: Sendable {
    case success(T)
    case invalidData(reason: String)
    case insufficientData(expected: Int, actual: Int)

    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

// MARK: - Validated Parsing

extension BLEDataParser {

    /// Parse PPG data with detailed error information
    /// - Parameter data: Raw data packet
    /// - Returns: BLEParseResult containing PPGData array or error details
    public static func parsePPGDataValidated(_ data: Data) -> BLEParseResult<[PPGData]> {
        let minSize = BLEConstants.TGM.DataFormat.bytesPerPPGSample

        if data.count < minSize {
            return .insufficientData(expected: minSize, actual: data.count)
        }

        if let readings = parsePPGData(data) {
            return .success(readings)
        }

        return .invalidData(reason: "Failed to parse PPG data structure")
    }

    /// Parse accelerometer data with detailed error information
    /// - Parameter data: Raw data packet
    /// - Returns: BLEParseResult containing AccelerometerData array or error details
    public static func parseAccelerometerDataValidated(_ data: Data) -> BLEParseResult<[AccelerometerData]> {
        let minSize = BLEConstants.TGM.DataFormat.bytesPerAccelSample

        if data.count < minSize {
            return .insufficientData(expected: minSize, actual: data.count)
        }

        if let readings = parseAccelerometerData(data) {
            return .success(readings)
        }

        return .invalidData(reason: "Failed to parse accelerometer data structure")
    }

    /// Parse battery data with detailed error information
    /// - Parameter data: Raw data packet
    /// - Returns: BLEParseResult containing BatteryData or error details
    public static func parseTGMBatteryDataValidated(_ data: Data) -> BLEParseResult<BatteryData> {
        if data.count < 4 {
            return .insufficientData(expected: 4, actual: data.count)
        }

        if let battery = parseTGMBatteryData(data) {
            return .success(battery)
        }

        return .invalidData(reason: "Battery voltage out of valid range (2500-4500 mV)")
    }
}
