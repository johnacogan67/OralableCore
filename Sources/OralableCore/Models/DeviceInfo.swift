//
//  DeviceInfo.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Device information model for multi-device support
//

import Foundation

// MARK: - Connection Readiness

/// Detailed connection readiness states for BLE devices
public enum ConnectionReadiness: Equatable, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case discoveringServices
    case servicesDiscovered
    case discoveringCharacteristics
    case characteristicsDiscovered
    case enablingNotifications
    case ready
    case failed(String)

    public var isConnected: Bool {
        switch self {
        case .disconnected, .connecting, .failed:
            return false
        case .connected, .discoveringServices, .servicesDiscovered,
             .discoveringCharacteristics, .characteristicsDiscovered,
             .enablingNotifications, .ready:
            return true
        }
    }

    public var isReady: Bool {
        self == .ready
    }

    public var isTransitioning: Bool {
        switch self {
        case .connecting, .discoveringServices, .discoveringCharacteristics,
             .enablingNotifications:
            return true
        default:
            return false
        }
    }

    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .discoveringServices: return "Discovering Services..."
        case .servicesDiscovered: return "Services Discovered"
        case .discoveringCharacteristics: return "Discovering Characteristics..."
        case .characteristicsDiscovered: return "Characteristics Discovered"
        case .enablingNotifications: return "Enabling Notifications..."
        case .ready: return "Ready"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}

// MARK: - Device Info

/// Complete device information
public struct DeviceInfo: Identifiable, Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Unique identifier
    public let id: UUID

    /// Device type
    public let type: DeviceType

    /// Device name
    public let name: String

    /// Bluetooth peripheral identifier
    public let peripheralIdentifier: UUID?

    /// Basic connection state
    public var connectionState: DeviceConnectionState

    /// Detailed connection readiness
    public var connectionReadiness: ConnectionReadiness

    /// Battery level (0-100)
    public var batteryLevel: Int?

    /// Signal strength (RSSI)
    public var signalStrength: Int?

    /// Firmware version
    public var firmwareVersion: String?

    /// Hardware version
    public var hardwareVersion: String?

    /// Last connection timestamp
    public var lastConnected: Date?

    /// Supported sensor types
    public let supportedSensors: [SensorType]

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        type: DeviceType,
        name: String,
        peripheralIdentifier: UUID? = nil,
        connectionState: DeviceConnectionState = .disconnected,
        connectionReadiness: ConnectionReadiness = .disconnected,
        batteryLevel: Int? = nil,
        signalStrength: Int? = nil,
        firmwareVersion: String? = nil,
        hardwareVersion: String? = nil,
        lastConnected: Date? = nil,
        supportedSensors: [SensorType]? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.peripheralIdentifier = peripheralIdentifier
        self.connectionState = connectionState
        self.connectionReadiness = connectionReadiness
        self.batteryLevel = batteryLevel
        self.signalStrength = signalStrength
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.lastConnected = lastConnected
        self.supportedSensors = supportedSensors ?? type.defaultSensors
    }

    // MARK: - Equatable

    public static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Helper Methods

extension DeviceInfo {

    /// Whether the device is currently active
    public var isActive: Bool {
        connectionState == .connected || connectionState == .connecting
    }

    /// Whether the device is fully ready for data streaming
    public var isReady: Bool {
        connectionReadiness.isReady
    }

    /// Create demo device for testing
    public static func demo(type: DeviceType = .oralable) -> DeviceInfo {
        DeviceInfo(
            type: type,
            name: "\(type.displayName) Demo",
            connectionState: .connected,
            connectionReadiness: .ready,
            batteryLevel: 85,
            signalStrength: -45,
            firmwareVersion: "1.0.0",
            hardwareVersion: "Rev A"
        )
    }

    /// Update connection state
    public mutating func updateConnectionState(_ state: DeviceConnectionState) {
        connectionState = state
        if state == .connected {
            lastConnected = Date()
        }
    }

    /// Update connection readiness
    public mutating func updateConnectionReadiness(_ readiness: ConnectionReadiness) {
        connectionReadiness = readiness
        // Sync basic connection state
        if readiness.isConnected {
            connectionState = .connected
        } else if case .failed = readiness {
            connectionState = .failed
        }
    }

    /// Update battery level
    public mutating func updateBatteryLevel(_ level: Int) {
        batteryLevel = max(0, min(100, level))
    }

    /// Update signal strength
    public mutating func updateSignalStrength(_ rssi: Int) {
        signalStrength = rssi
    }
}

// MARK: - Collection Extension

extension Array where Element == DeviceInfo {

    /// Filter connected devices
    public var connected: [DeviceInfo] {
        filter { $0.connectionState == .connected }
    }

    /// Filter ready devices (fully initialized)
    public var ready: [DeviceInfo] {
        filter { $0.connectionReadiness.isReady }
    }

    /// Filter by device type
    public func ofType(_ type: DeviceType) -> [DeviceInfo] {
        filter { $0.type == type }
    }

    /// Find device by peripheral identifier
    public func device(withPeripheralId id: UUID) -> DeviceInfo? {
        first { $0.peripheralIdentifier == id }
    }

    /// Find device by name
    public func device(named name: String) -> DeviceInfo? {
        first { $0.name == name }
    }
}
