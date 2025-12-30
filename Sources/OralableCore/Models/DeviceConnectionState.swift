//
//  DeviceConnectionState.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Connection state for BLE devices
//

import Foundation

/// Represents the connection state of a device
public enum DeviceConnectionState: String, Codable, Sendable, Equatable {
    /// Device is not connected
    case disconnected

    /// Device is in the process of connecting
    case connecting

    /// Device is fully connected and ready
    case connected

    /// Device is in the process of disconnecting
    case disconnecting

    /// Device connection failed
    case failed

    /// Human-readable description
    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .failed:
            return "Connection Failed"
        }
    }

    /// Whether the device is in a connected state
    public var isConnected: Bool {
        self == .connected
    }

    /// Whether the device is in a transitional state
    public var isTransitioning: Bool {
        self == .connecting || self == .disconnecting
    }

    /// Whether the device can accept a connect command
    public var canConnect: Bool {
        self == .disconnected || self == .failed
    }

    /// Whether the device can accept a disconnect command
    public var canDisconnect: Bool {
        self == .connected || self == .connecting
    }

    /// SF Symbol icon name for this state
    public var iconName: String {
        switch self {
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .connected:
            return "checkmark.circle.fill"
        case .disconnecting:
            return "antenna.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Device State Result

/// Comprehensive device state information
public struct DeviceStateResult: Codable, Sendable, Equatable {
    /// Connection state
    public let connectionState: DeviceConnectionState

    /// Whether the device is worn (on skin)
    public let isWorn: Bool

    /// Whether data is currently streaming
    public let isStreaming: Bool

    /// Signal strength (RSSI) if available
    public let signalStrength: Int?

    /// Battery level percentage (0-100) if available
    public let batteryLevel: Int?

    /// Last error message if any
    public let lastError: String?

    /// Timestamp of this state
    public let timestamp: Date

    public init(
        connectionState: DeviceConnectionState,
        isWorn: Bool = false,
        isStreaming: Bool = false,
        signalStrength: Int? = nil,
        batteryLevel: Int? = nil,
        lastError: String? = nil,
        timestamp: Date = Date()
    ) {
        self.connectionState = connectionState
        self.isWorn = isWorn
        self.isStreaming = isStreaming
        self.signalStrength = signalStrength
        self.batteryLevel = batteryLevel
        self.lastError = lastError
        self.timestamp = timestamp
    }

    // MARK: - Convenience Properties

    /// Whether the device is ready for data collection
    public var isReady: Bool {
        connectionState.isConnected && isWorn
    }

    /// Signal strength classification
    public var signalQuality: SignalQuality {
        guard let rssi = signalStrength else { return .unknown }
        if rssi >= -50 {
            return .excellent
        } else if rssi >= -60 {
            return .good
        } else if rssi >= -70 {
            return .fair
        } else if rssi >= -80 {
            return .weak
        } else {
            return .poor
        }
    }

    // MARK: - Static Helpers

    /// Default disconnected state
    public static let disconnected = DeviceStateResult(
        connectionState: .disconnected
    )

    /// Create a connected state with optional details
    public static func connected(
        isWorn: Bool = false,
        isStreaming: Bool = false,
        signalStrength: Int? = nil,
        batteryLevel: Int? = nil
    ) -> DeviceStateResult {
        DeviceStateResult(
            connectionState: .connected,
            isWorn: isWorn,
            isStreaming: isStreaming,
            signalStrength: signalStrength,
            batteryLevel: batteryLevel
        )
    }
}

// MARK: - Signal Quality

/// Classification of signal strength
public enum SignalQuality: String, Codable, Sendable {
    case excellent
    case good
    case fair
    case weak
    case poor
    case unknown

    public var description: String {
        rawValue.capitalized
    }

    /// Number of signal bars to display (0-4)
    public var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak: return 1
        case .poor: return 0
        case .unknown: return 0
        }
    }

    /// Whether signal is adequate for reliable data
    public var isAdequate: Bool {
        switch self {
        case .excellent, .good, .fair:
            return true
        case .weak, .poor, .unknown:
            return false
        }
    }
}
