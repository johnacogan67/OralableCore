//
//  BLEDataParser.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Updated: January 29, 2026 - Added frame counter handling per firmware spec
//
//  Location: Sources/OralableCore/BLE/BLEDataParser.swift
//
//  Framework-agnostic BLE data parsing utilities
//  Parses raw BLE packet data into OralableCore model types
//
//  Packet Format (from oralable_nrf tgm_service.h):
//  - PPG (3A0FF001): 4-byte frame_counter + N×12 bytes (Red, IR, Green per sample)
//  - Accel (3A0FF002): 4-byte frame_counter + N×6 bytes (X, Y, Z per sample)
//  - Temp (3A0FF003): 4-byte frame_counter + 2-byte centidegrees
//  - Battery (3A0FF004): 4-byte millivolts
//

import Foundation

// MARK: - PPG Packet Result

/// Result of parsing a PPG packet
public struct PPGPacketResult: Sendable {
    /// Frame counter from packet header
    public let frameCounter: UInt32
    
    /// Parsed PPG samples with timestamps
    public let samples: [PPGData]
    
    /// Number of samples in packet
    public var sampleCount: Int { samples.count }
    
    public init(frameCounter: UInt32, samples: [PPGData]) {
        self.frameCounter = frameCounter
        self.samples = samples
    }
}

// MARK: - Accelerometer Packet Result

/// Result of parsing an accelerometer packet
public struct AccelerometerPacketResult: Sendable {
    /// Frame counter from packet header
    public let frameCounter: UInt32
    
    /// Parsed accelerometer samples with timestamps
    public let samples: [AccelerometerData]
    
    /// Number of samples in packet
    public var sampleCount: Int { samples.count }
    
    public init(frameCounter: UInt32, samples: [AccelerometerData]) {
        self.frameCounter = frameCounter
        self.samples = samples
    }
}

// MARK: - Temperature Packet Result

/// Result of parsing a temperature packet
public struct TemperaturePacketResult: Sendable {
    /// Frame counter from packet header
    public let frameCounter: UInt32
    
    /// Temperature in Celsius
    public let temperatureCelsius: Double
    
    /// Raw temperature value (centidegrees)
    public let rawValue: Int16
    
    public init(frameCounter: UInt32, temperatureCelsius: Double, rawValue: Int16) {
        self.frameCounter = frameCounter
        self.temperatureCelsius = temperatureCelsius
        self.rawValue = rawValue
    }
}

// MARK: - BLE Data Parser

/// Framework-agnostic utilities for parsing raw BLE data packets
/// Converts raw byte data from Oralable devices into typed model objects
public struct BLEDataParser: Sendable {
    
    // MARK: - Packet Format Constants
    
    /// Frame counter size in bytes
    public static let frameCounterBytes: Int = 4
    
    /// Bytes per PPG sample (Red + IR + Green, each UInt32)
    public static let bytesPerPPGSample: Int = 12
    
    /// Bytes per accelerometer sample (X + Y + Z, each Int16)
    public static let bytesPerAccelSample: Int = 6
    
    /// PPG sample rate in Hz
    public static let ppgSampleRate: Double = 50.0
    
    /// Accelerometer sample rate in Hz
    public static let accelSampleRate: Double = 100.0
    
    /// Sample interval for PPG in seconds (20ms)
    public static let ppgSampleInterval: Double = 1.0 / ppgSampleRate
    
    /// Sample interval for accelerometer in seconds (10ms)
    public static let accelSampleInterval: Double = 1.0 / accelSampleRate
    
    // MARK: - Frame Counter
    
    /// Extract frame counter from packet (first 4 bytes)
    /// - Parameter data: Raw packet data
    /// - Returns: Frame counter value, or nil if insufficient data
    public static func extractFrameCounter(_ data: Data) -> UInt32? {
        guard data.count >= frameCounterBytes else { return nil }
        return data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: UInt32.self)
        }
    }

    // MARK: - PPG Data Parsing

    /// Parse PPG sensor data from raw BLE packet
    /// Handles the 4-byte frame counter prefix per firmware spec
    /// - Parameters:
    ///   - data: Raw data packet (4-byte header + N×12 bytes)
    ///   - notificationTime: Time the BLE notification was received
    /// - Returns: PPGPacketResult containing frame counter and samples, or nil if invalid
    public static func parsePPGPacket(_ data: Data, notificationTime: Date = Date()) -> PPGPacketResult? {
        let headerSize = frameCounterBytes
        let bytesPerSample = bytesPerPPGSample
        
        // Need header + at least one sample
        guard data.count >= headerSize + bytesPerSample else { return nil }
        
        // Extract frame counter
        guard let frameCounter = extractFrameCounter(data) else { return nil }
        
        // Calculate number of samples
        let payloadSize = data.count - headerSize
        let sampleCount = payloadSize / bytesPerSample
        
        guard sampleCount > 0 else { return nil }
        
        // Parse samples
        var samples: [PPGData] = []
        samples.reserveCapacity(sampleCount)
        
        let sampleInterval = ppgSampleInterval
        
        for i in 0..<sampleCount {
            let offset = headerSize + (i * bytesPerSample)
            
            guard offset + bytesPerSample <= data.count else { break }
            
            // Channel order per firmware: Red @ offset 0, IR @ offset 4, Green @ offset 8
            let values = data.withUnsafeBytes { ptr -> (red: UInt32, ir: UInt32, green: UInt32) in
                let red = ptr.load(fromByteOffset: offset + 0, as: UInt32.self)
                let ir = ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
                let green = ptr.load(fromByteOffset: offset + 8, as: UInt32.self)
                return (red, ir, green)
            }
            
            // Calculate per-sample timestamp
            // Samples are ordered oldest-first, so sample[0] is furthest back in time
            let sampleOffset = Double(sampleCount - 1 - i) * sampleInterval
            let sampleTimestamp = notificationTime.addingTimeInterval(-sampleOffset)
            
            let sample = PPGData(
                red: Int32(bitPattern: values.red),
                ir: Int32(bitPattern: values.ir),
                green: Int32(bitPattern: values.green),
                timestamp: sampleTimestamp
            )
            
            samples.append(sample)
        }
        
        return PPGPacketResult(frameCounter: frameCounter, samples: samples)
    }
    
    /// Parse PPG samples from payload data (without frame counter)
    /// Use when frame counter has already been stripped
    /// - Parameters:
    ///   - data: Payload data containing N×12 bytes of samples
    ///   - notificationTime: Time the BLE notification was received
    /// - Returns: Array of PPGData readings
    public static func parsePPGSamples(_ data: Data, notificationTime: Date = Date()) -> [PPGData]? {
        let bytesPerSample = bytesPerPPGSample
        
        guard data.count >= bytesPerSample else { return nil }
        
        let sampleCount = data.count / bytesPerSample
        var samples: [PPGData] = []
        samples.reserveCapacity(sampleCount)
        
        let sampleInterval = ppgSampleInterval
        
        for i in 0..<sampleCount {
            let offset = i * bytesPerSample
            
            guard offset + bytesPerSample <= data.count else { break }
            
            let values = data.withUnsafeBytes { ptr -> (red: UInt32, ir: UInt32, green: UInt32) in
                let red = ptr.load(fromByteOffset: offset + 0, as: UInt32.self)
                let ir = ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
                let green = ptr.load(fromByteOffset: offset + 8, as: UInt32.self)
                return (red, ir, green)
            }
            
            let sampleOffset = Double(sampleCount - 1 - i) * sampleInterval
            let sampleTimestamp = notificationTime.addingTimeInterval(-sampleOffset)
            
            let sample = PPGData(
                red: Int32(bitPattern: values.red),
                ir: Int32(bitPattern: values.ir),
                green: Int32(bitPattern: values.green),
                timestamp: sampleTimestamp
            )
            
            samples.append(sample)
        }
        
        return samples.isEmpty ? nil : samples
    }
    
    /// Legacy method - parses without frame counter handling
    /// - Parameter data: Raw data (assumes no frame counter)
    /// - Returns: Array of PPGData readings
    @available(*, deprecated, message: "Use parsePPGPacket() for packets with frame counter")
    public static func parsePPGData(_ data: Data) -> [PPGData]? {
        return parsePPGSamples(data)
    }

    // MARK: - Accelerometer Data Parsing

    /// Parse accelerometer data from raw BLE packet
    /// Handles the 4-byte frame counter prefix per firmware spec
    /// - Parameters:
    ///   - data: Raw data packet (4-byte header + N×6 bytes)
    ///   - notificationTime: Time the BLE notification was received
    /// - Returns: AccelerometerPacketResult containing frame counter and samples, or nil if invalid
    public static func parseAccelerometerPacket(_ data: Data, notificationTime: Date = Date()) -> AccelerometerPacketResult? {
        let headerSize = frameCounterBytes
        let bytesPerSample = bytesPerAccelSample
        
        // Need header + at least one sample
        guard data.count >= headerSize + bytesPerSample else { return nil }
        
        // Extract frame counter
        guard let frameCounter = extractFrameCounter(data) else { return nil }
        
        // Calculate number of samples
        let payloadSize = data.count - headerSize
        let sampleCount = payloadSize / bytesPerSample
        
        guard sampleCount > 0 else { return nil }
        
        // Parse samples
        var samples: [AccelerometerData] = []
        samples.reserveCapacity(sampleCount)
        
        let sampleInterval = accelSampleInterval
        
        for i in 0..<sampleCount {
            let offset = headerSize + (i * bytesPerSample)
            
            guard offset + bytesPerSample <= data.count else { break }
            
            let values = data.withUnsafeBytes { ptr -> (x: Int16, y: Int16, z: Int16) in
                let x = ptr.load(fromByteOffset: offset + 0, as: Int16.self)
                let y = ptr.load(fromByteOffset: offset + 2, as: Int16.self)
                let z = ptr.load(fromByteOffset: offset + 4, as: Int16.self)
                return (x, y, z)
            }
            
            let sampleOffset = Double(sampleCount - 1 - i) * sampleInterval
            let sampleTimestamp = notificationTime.addingTimeInterval(-sampleOffset)
            
            let sample = AccelerometerData(
                x: values.x,
                y: values.y,
                z: values.z,
                timestamp: sampleTimestamp
            )
            
            samples.append(sample)
        }
        
        return AccelerometerPacketResult(frameCounter: frameCounter, samples: samples)
    }
    
    /// Parse accelerometer samples from payload data (without frame counter)
    /// - Parameters:
    ///   - data: Payload data containing N×6 bytes of samples
    ///   - notificationTime: Time the BLE notification was received
    /// - Returns: Array of AccelerometerData readings
    public static func parseAccelerometerSamples(_ data: Data, notificationTime: Date = Date()) -> [AccelerometerData]? {
        let bytesPerSample = bytesPerAccelSample
        
        guard data.count >= bytesPerSample else { return nil }
        
        let sampleCount = data.count / bytesPerSample
        var samples: [AccelerometerData] = []
        samples.reserveCapacity(sampleCount)
        
        let sampleInterval = accelSampleInterval
        
        for i in 0..<sampleCount {
            let offset = i * bytesPerSample
            
            guard offset + bytesPerSample <= data.count else { break }
            
            let values = data.withUnsafeBytes { ptr -> (x: Int16, y: Int16, z: Int16) in
                let x = ptr.load(fromByteOffset: offset + 0, as: Int16.self)
                let y = ptr.load(fromByteOffset: offset + 2, as: Int16.self)
                let z = ptr.load(fromByteOffset: offset + 4, as: Int16.self)
                return (x, y, z)
            }
            
            let sampleOffset = Double(sampleCount - 1 - i) * sampleInterval
            let sampleTimestamp = notificationTime.addingTimeInterval(-sampleOffset)
            
            let sample = AccelerometerData(
                x: values.x,
                y: values.y,
                z: values.z,
                timestamp: sampleTimestamp
            )
            
            samples.append(sample)
        }
        
        return samples.isEmpty ? nil : samples
    }
    
    /// Legacy method - parses without frame counter handling
    @available(*, deprecated, message: "Use parseAccelerometerPacket() for packets with frame counter")
    public static func parseAccelerometerData(_ data: Data) -> [AccelerometerData]? {
        return parseAccelerometerSamples(data)
    }

    // MARK: - Temperature Data Parsing

    /// Parse temperature data from raw BLE packet
    /// Format: 4-byte frame counter + 2-byte centidegrees (Int16)
    /// - Parameter data: Raw data packet
    /// - Returns: TemperaturePacketResult, or nil if invalid
    public static func parseTemperaturePacket(_ data: Data) -> TemperaturePacketResult? {
        let headerSize = frameCounterBytes
        let tempSize = 2  // Int16
        
        guard data.count >= headerSize + tempSize else { return nil }
        
        guard let frameCounter = extractFrameCounter(data) else { return nil }
        
        // Temperature is centidegrees Celsius (Int16)
        let tempRaw = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: headerSize, as: Int16.self)
        }
        
        let tempCelsius = Double(tempRaw) / 100.0
        
        return TemperaturePacketResult(
            frameCounter: frameCounter,
            temperatureCelsius: tempCelsius,
            rawValue: tempRaw
        )
    }
    
    /// Parse temperature value only (returns Celsius)
    /// - Parameter data: Raw data packet
    /// - Returns: Temperature in Celsius, or nil if invalid
    public static func parseTemperature(_ data: Data) -> Double? {
        return parseTemperaturePacket(data)?.temperatureCelsius
    }

    // MARK: - Battery Data Parsing

    /// Parse TGM battery data (4 bytes millivolts)
    /// Note: No frame counter for battery characteristic
    /// - Parameter data: Raw data packet (4 bytes)
    /// - Returns: Battery voltage in millivolts, or nil if invalid
    public static func parseBatteryMillivolts(_ data: Data) -> Int32? {
        guard data.count >= 4 else { return nil }
        
        let millivolts = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 0, as: Int32.self)
        }
        
        // Validate range (2500-4500 mV typical for LiPo)
        guard millivolts >= 2500 && millivolts <= 4500 else { return nil }
        
        return millivolts
    }
    
    /// Parse TGM battery data and convert to BatteryData
    /// - Parameter data: Raw data packet
    /// - Returns: BatteryData with percentage, or nil if invalid
    public static func parseTGMBatteryData(_ data: Data) -> BatteryData? {
        guard let millivolts = parseBatteryMillivolts(data) else { return nil }
        
        // Convert to percentage (simple linear mapping)
        // 3.0V = 0%, 4.2V = 100%
        let percentage = Int(min(100, max(0, (millivolts - 3000) * 100 / 1200)))
        
        return BatteryData(
            percentage: percentage,
            timestamp: Date()
        )
    }
    
    /// Parse standard battery level (1 byte, 0-100%)
    /// - Parameter data: Raw data packet
    /// - Returns: Battery percentage, or nil if invalid
    public static func parseStandardBatteryLevel(_ data: Data) -> Int? {
        guard data.count >= 1 else { return nil }
        let level = Int(data[0])
        guard level >= 0 && level <= 100 else { return nil }
        return level
    }

    // MARK: - Device Information Parsing

    /// Parse device information string from raw BLE data
    /// - Parameter data: Raw string data (UTF-8 encoded)
    /// - Returns: Decoded string, or nil if invalid
    public static func parseStringData(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
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
    
    public var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .insufficientData(let expected, let actual):
            return "Insufficient data: expected \(expected) bytes, got \(actual)"
        }
    }
}

// MARK: - Validated Parsing

extension BLEDataParser {

    /// Parse PPG packet with detailed error information
    public static func parsePPGPacketValidated(_ data: Data, notificationTime: Date = Date()) -> BLEParseResult<PPGPacketResult> {
        let minSize = frameCounterBytes + bytesPerPPGSample

        if data.count < minSize {
            return .insufficientData(expected: minSize, actual: data.count)
        }

        if let result = parsePPGPacket(data, notificationTime: notificationTime) {
            return .success(result)
        }

        return .invalidData(reason: "Failed to parse PPG packet structure")
    }

    /// Parse accelerometer packet with detailed error information
    public static func parseAccelerometerPacketValidated(_ data: Data, notificationTime: Date = Date()) -> BLEParseResult<AccelerometerPacketResult> {
        let minSize = frameCounterBytes + bytesPerAccelSample

        if data.count < minSize {
            return .insufficientData(expected: minSize, actual: data.count)
        }

        if let result = parseAccelerometerPacket(data, notificationTime: notificationTime) {
            return .success(result)
        }

        return .invalidData(reason: "Failed to parse accelerometer packet structure")
    }

    /// Parse temperature packet with detailed error information
    public static func parseTemperaturePacketValidated(_ data: Data) -> BLEParseResult<TemperaturePacketResult> {
        let minSize = frameCounterBytes + 2

        if data.count < minSize {
            return .insufficientData(expected: minSize, actual: data.count)
        }

        if let result = parseTemperaturePacket(data) {
            return .success(result)
        }

        return .invalidData(reason: "Failed to parse temperature packet structure")
    }

    /// Parse battery data with detailed error information
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
