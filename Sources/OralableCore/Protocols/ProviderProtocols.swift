//
//  ProviderProtocols.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic provider protocols for dependency injection
//

import Foundation
import Combine

// MARK: - Biometric Data Provider Protocol

/// Protocol for providing calculated biometric data
/// Framework-agnostic version that doesn't depend on specific UI frameworks
public protocol BiometricDataProviderProtocol: AnyObject {

    // MARK: - Calculated Biometrics

    /// Current heart rate in beats per minute
    var heartRate: Int { get }

    /// Current blood oxygen saturation percentage (SpO2)
    var spo2: Int { get }

    /// Quality indicator for heart rate calculation (0.0 - 1.0)
    var heartRateQuality: Double { get }

    // MARK: - Publishers

    /// Publisher for heart rate changes
    var heartRatePublisher: AnyPublisher<Int, Never> { get }

    /// Publisher for SpO2 changes
    var spo2Publisher: AnyPublisher<Int, Never> { get }

    /// Publisher for heart rate quality changes
    var heartRateQualityPublisher: AnyPublisher<Double, Never> { get }
}

// MARK: - Biometric Data Provider Defaults

public extension BiometricDataProviderProtocol {

    /// Default heart rate when no data available
    static var defaultHeartRate: Int { 0 }

    /// Default SpO2 when no data available
    static var defaultSpO2: Int { 0 }

    /// Default quality when no data available
    static var defaultQuality: Double { 0.0 }

    /// Check if heart rate is valid
    var hasValidHeartRate: Bool {
        heartRate > 30 && heartRate < 250
    }

    /// Check if SpO2 is valid
    var hasValidSpO2: Bool {
        spo2 >= 70 && spo2 <= 100
    }
}

// MARK: - Connection State Provider Protocol

/// Protocol for providing connection state information
/// Framework-agnostic version without CoreBluetooth dependencies
public protocol ConnectionStateProviderProtocol: AnyObject {

    // MARK: - Connection State

    /// Whether a device is currently connected
    var isConnected: Bool { get }

    /// Whether the manager is currently scanning for devices
    var isScanning: Bool { get }

    /// Name of the connected device
    var deviceName: String { get }

    /// UUID of the connected device
    var deviceUUID: UUID? { get }

    /// Human-readable connection state description
    var connectionStateDescription: String { get }

    /// Signal strength (RSSI) of connected device
    var rssi: Int { get }

    // MARK: - Publishers

    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    var isScanningPublisher: AnyPublisher<Bool, Never> { get }
    var deviceNamePublisher: AnyPublisher<String, Never> { get }
    var deviceUUIDPublisher: AnyPublisher<UUID?, Never> { get }
    var rssiPublisher: AnyPublisher<Int, Never> { get }

    // MARK: - Connection Management

    /// Start scanning for devices
    func startScanning()

    /// Stop scanning for devices
    func stopScanning()

    /// Disconnect from current device
    func disconnect()
}

// MARK: - Connection State Provider Defaults

public extension ConnectionStateProviderProtocol {

    /// Signal quality based on RSSI
    var signalQuality: SignalQuality {
        SignalQuality.from(rssi: rssi)
    }

    /// Check if connection is stable
    var hasStableConnection: Bool {
        isConnected && signalQuality.isAdequate
    }
}

// MARK: - Realtime Sensor Provider Protocol

/// Protocol for providing real-time sensor readings
/// Framework-agnostic version for high-frequency sensor data
public protocol RealtimeSensorProviderProtocol: AnyObject {

    // MARK: - Accelerometer

    /// X-axis acceleration in g
    var accelX: Double { get }

    /// Y-axis acceleration in g
    var accelY: Double { get }

    /// Z-axis acceleration in g
    var accelZ: Double { get }

    // MARK: - PPG Sensors

    /// Red LED PPG value
    var ppgRed: Double { get }

    /// Infrared LED PPG value
    var ppgInfrared: Double { get }

    /// Green LED PPG value
    var ppgGreen: Double { get }

    // MARK: - Environmental Sensors

    /// Temperature in Celsius
    var temperature: Double { get }

    /// Battery level percentage (0-100)
    var batteryLevel: Double { get }

    // MARK: - Publishers

    var accelXPublisher: AnyPublisher<Double, Never> { get }
    var accelYPublisher: AnyPublisher<Double, Never> { get }
    var accelZPublisher: AnyPublisher<Double, Never> { get }
    var ppgRedPublisher: AnyPublisher<Double, Never> { get }
    var ppgInfraredPublisher: AnyPublisher<Double, Never> { get }
    var ppgGreenPublisher: AnyPublisher<Double, Never> { get }
    var temperaturePublisher: AnyPublisher<Double, Never> { get }
    var batteryLevelPublisher: AnyPublisher<Double, Never> { get }
}

// MARK: - Realtime Sensor Provider Extensions

public extension RealtimeSensorProviderProtocol {

    /// Current accelerometer magnitude
    var accelerometerMagnitude: Double {
        sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
    }

    /// Current sensor snapshot
    var currentSnapshot: RealtimeSensorSnapshot {
        RealtimeSensorSnapshot(
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ,
            temperature: temperature
        )
    }

    /// Current PPG snapshot
    var currentPPGSnapshot: PPGSnapshot {
        PPGSnapshot(
            red: ppgRed,
            infrared: ppgInfrared,
            green: ppgGreen
        )
    }

    /// Creates a throttled publisher for high-frequency sensor data
    /// - Parameter interval: Throttling interval in seconds (default: 0.1s = 10Hz)
    func throttledSensorPublisher(interval: TimeInterval = 0.1) -> AnyPublisher<RealtimeSensorSnapshot, Never> {
        Publishers.CombineLatest4(
            accelXPublisher,
            accelYPublisher,
            accelZPublisher,
            temperaturePublisher
        )
        .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
        .map { accelX, accelY, accelZ, temperature in
            RealtimeSensorSnapshot(
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                temperature: temperature
            )
        }
        .eraseToAnyPublisher()
    }

    /// Creates a throttled publisher for PPG data
    /// - Parameter interval: Throttling interval in seconds (default: 0.05s = 20Hz)
    func throttledPPGPublisher(interval: TimeInterval = 0.05) -> AnyPublisher<PPGSnapshot, Never> {
        Publishers.CombineLatest3(
            ppgRedPublisher,
            ppgInfraredPublisher,
            ppgGreenPublisher
        )
        .throttle(for: .seconds(interval), scheduler: RunLoop.main, latest: true)
        .map { red, ir, green in
            PPGSnapshot(red: red, infrared: ir, green: green)
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Device Status Provider Protocol

/// Protocol for providing device status and diagnostic information
/// Framework-agnostic version for status monitoring
public protocol DeviceStatusProviderProtocol: AnyObject {

    // MARK: - Device State

    /// Current device operational state
    var deviceState: DeviceStateResult? { get }

    /// List of discovered service identifiers
    var discoveredServices: [String] { get }

    // MARK: - Recording Status

    /// Whether device is currently recording data
    var isRecording: Bool { get }

    /// Number of data packets received in current session
    var packetsReceived: Int { get }

    // MARK: - Diagnostics

    /// Log messages from device operations
    var logMessages: [LogMessage] { get }

    /// Last error message, if any
    var lastError: String? { get }

    // MARK: - Publishers

    var deviceStatePublisher: AnyPublisher<DeviceStateResult?, Never> { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var packetsReceivedPublisher: AnyPublisher<Int, Never> { get }
    var logMessagesPublisher: AnyPublisher<[LogMessage], Never> { get }
}

// MARK: - Device Status Provider Extensions

public extension DeviceStatusProviderProtocol {

    /// Check if device is ready for data collection
    var isReady: Bool {
        deviceState?.isReady ?? false
    }

    /// Check if device is worn
    var isWorn: Bool {
        deviceState?.isWorn ?? false
    }

    /// Check if device is streaming data
    var isStreaming: Bool {
        deviceState?.isStreaming ?? false
    }

    /// Get recent log messages
    func recentLogs(limit: Int = 20) -> [LogMessage] {
        Array(logMessages.suffix(limit))
    }

    /// Get error logs only
    var errorLogs: [LogMessage] {
        logMessages.filter { $0.level == .error }
    }
}

// MARK: - Combined Device Provider Protocol

/// Combined protocol for full device access
/// Use this when you need access to all device capabilities
public protocol FullDeviceProviderProtocol:
    BiometricDataProviderProtocol,
    ConnectionStateProviderProtocol,
    RealtimeSensorProviderProtocol,
    DeviceStatusProviderProtocol {}

// MARK: - Mock Providers for Testing

#if DEBUG

/// Mock implementation of BiometricDataProviderProtocol for testing
public final class MockBiometricDataProvider: BiometricDataProviderProtocol {
    public var heartRate: Int = 72
    public var spo2: Int = 98
    public var heartRateQuality: Double = 0.95

    private let heartRateSubject = CurrentValueSubject<Int, Never>(72)
    private let spo2Subject = CurrentValueSubject<Int, Never>(98)
    private let qualitySubject = CurrentValueSubject<Double, Never>(0.95)

    public var heartRatePublisher: AnyPublisher<Int, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    public var spo2Publisher: AnyPublisher<Int, Never> {
        spo2Subject.eraseToAnyPublisher()
    }

    public var heartRateQualityPublisher: AnyPublisher<Double, Never> {
        qualitySubject.eraseToAnyPublisher()
    }

    public init() {}

    public func updateHeartRate(_ value: Int) {
        heartRate = value
        heartRateSubject.send(value)
    }

    public func updateSpO2(_ value: Int) {
        spo2 = value
        spo2Subject.send(value)
    }
}

#endif
