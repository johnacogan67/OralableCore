//
//  DeviceProtocol.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic device protocol for all sensor devices
//

import Foundation
import Combine

// MARK: - Device Protocol

/// Protocol that all sensor devices must implement
/// This is a framework-agnostic version that doesn't depend on CoreBluetooth
public protocol DeviceProtocol: AnyObject {

    // MARK: - Device Information

    /// Device information structure
    var deviceInfo: DeviceInfo { get }

    /// Device type
    var deviceType: DeviceType { get }

    /// Device name
    var name: String { get }

    /// Unique device identifier
    var identifier: UUID { get }

    // MARK: - Connection State

    /// Current connection state
    var connectionState: DeviceConnectionState { get }

    /// Detailed connection readiness
    var connectionReadiness: ConnectionReadiness { get }

    /// Whether device is currently connected
    var isConnected: Bool { get }

    /// Signal strength (RSSI) if available
    var signalStrength: Int? { get }

    // MARK: - Battery & System Info

    /// Current battery level (0-100)
    var batteryLevel: Int? { get }

    /// Firmware version
    var firmwareVersion: String? { get }

    /// Hardware version
    var hardwareVersion: String? { get }

    // MARK: - Sensor Data

    /// Publisher for individual sensor readings
    var sensorReadings: AnyPublisher<SensorReading, Never> { get }

    /// Publisher for batched sensor readings (more efficient)
    var sensorReadingsBatch: AnyPublisher<[SensorReading], Never> { get }

    /// Latest readings by sensor type
    var latestReadings: [SensorType: SensorReading] { get }

    /// List of supported sensors
    var supportedSensors: [SensorType] { get }

    // MARK: - Connection Management

    /// Connect to the device
    func connect() async throws

    /// Disconnect from the device
    func disconnect() async

    /// Check if device is available for connection
    func isAvailable() -> Bool

    // MARK: - Data Operations

    /// Start streaming sensor data
    func startDataStream() async throws

    /// Stop streaming sensor data
    func stopDataStream() async

    /// Request current reading for a specific sensor type
    func requestReading(for sensorType: SensorType) async throws -> SensorReading?

    // MARK: - Device Control

    /// Send command to device
    func sendCommand(_ command: DeviceCommand) async throws

    /// Update device configuration
    func updateConfiguration(_ config: DeviceConfiguration) async throws

    /// Request device information update
    func updateDeviceInfo() async throws
}

// MARK: - Protocol Extension (Default Implementations)

extension DeviceProtocol {

    /// Check if specific sensor is supported
    public func supports(sensor: SensorType) -> Bool {
        supportedSensors.contains(sensor)
    }

    /// Get latest reading for sensor type
    public func latestReading(for sensorType: SensorType) -> SensorReading? {
        latestReadings[sensorType]
    }

    /// Check if device is streaming data
    public var isStreaming: Bool {
        isConnected && connectionState == .connected
    }

    /// Whether device is fully ready for data collection
    public var isReady: Bool {
        connectionReadiness.isReady
    }
}

// MARK: - Device Command

/// Commands that can be sent to devices
public enum DeviceCommand: Sendable {
    case startSensors
    case stopSensors
    case reset
    case calibrate
    case setSamplingRate(hz: Int)
    case enableSensor(SensorType)
    case disableSensor(SensorType)
    case requestBatteryLevel
    case requestFirmwareVersion
    case custom(String)

    public var rawValue: String {
        switch self {
        case .startSensors:
            return "START"
        case .stopSensors:
            return "STOP"
        case .reset:
            return "RESET"
        case .calibrate:
            return "CALIBRATE"
        case .setSamplingRate(let hz):
            return "RATE:\(hz)"
        case .enableSensor(let type):
            return "ENABLE:\(type.rawValue)"
        case .disableSensor(let type):
            return "DISABLE:\(type.rawValue)"
        case .requestBatteryLevel:
            return "BATTERY?"
        case .requestFirmwareVersion:
            return "VERSION?"
        case .custom(let command):
            return command
        }
    }
}

// MARK: - Device Configuration

/// Configuration settings for devices
public struct DeviceConfiguration: Sendable, Codable, Equatable {

    /// Sampling rate in Hz
    public var samplingRate: Int

    /// Enabled sensors
    public var enabledSensors: Set<SensorType>

    /// Auto-reconnect on disconnect
    public var autoReconnect: Bool

    /// Notification preferences
    public var notificationsEnabled: Bool

    /// Data buffer size
    public var bufferSize: Int

    // MARK: - Initialization

    public init(
        samplingRate: Int,
        enabledSensors: Set<SensorType>,
        autoReconnect: Bool = true,
        notificationsEnabled: Bool = true,
        bufferSize: Int = 100
    ) {
        self.samplingRate = samplingRate
        self.enabledSensors = enabledSensors
        self.autoReconnect = autoReconnect
        self.notificationsEnabled = notificationsEnabled
        self.bufferSize = bufferSize
    }

    // MARK: - Default Configurations

    /// Default configuration for Oralable device
    public static let oralable = DeviceConfiguration(
        samplingRate: 50,
        enabledSensors: [
            .ppgRed,
            .ppgInfrared,
            .ppgGreen,
            .accelerometerX,
            .accelerometerY,
            .accelerometerZ,
            .temperature,
            .battery
        ],
        autoReconnect: true,
        notificationsEnabled: true,
        bufferSize: 100
    )

    /// Default configuration for ANR device
    public static let anr = DeviceConfiguration(
        samplingRate: 100,
        enabledSensors: [
            .emg,
            .battery
        ],
        autoReconnect: true,
        notificationsEnabled: true,
        bufferSize: 200
    )

    /// Demo configuration
    public static let demo = DeviceConfiguration(
        samplingRate: 10,
        enabledSensors: Set(SensorType.allCases),
        autoReconnect: false,
        notificationsEnabled: true,
        bufferSize: 50
    )

    /// Create configuration for a specific device type
    public static func forDevice(_ type: DeviceType) -> DeviceConfiguration {
        switch type {
        case .oralable:
            return .oralable
        case .anr:
            return .anr
        case .demo:
            return .demo
        }
    }
}

// MARK: - Sensor Snapshot Types

/// Snapshot of real-time sensor values (for throttled updates)
public struct RealtimeSensorSnapshot: Sendable {
    public let accelX: Double
    public let accelY: Double
    public let accelZ: Double
    public let temperature: Double
    public let timestamp: Date

    public init(
        accelX: Double,
        accelY: Double,
        accelZ: Double,
        temperature: Double,
        timestamp: Date = Date()
    ) {
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.temperature = temperature
        self.timestamp = timestamp
    }
}

/// Snapshot of PPG sensor values
public struct PPGSnapshot: Sendable {
    public let red: Double
    public let infrared: Double
    public let green: Double
    public let timestamp: Date

    public init(
        red: Double,
        infrared: Double,
        green: Double,
        timestamp: Date = Date()
    ) {
        self.red = red
        self.infrared = infrared
        self.green = green
        self.timestamp = timestamp
    }
}
