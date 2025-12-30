//
//  DeviceError.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Framework-agnostic device error types
//

import Foundation

// MARK: - Device Error

/// Comprehensive error types for device operations
/// Framework-agnostic version that doesn't depend on CoreBluetooth
public enum DeviceError: Error, LocalizedError, Equatable, Sendable {

    // MARK: - Connection Errors

    /// Device is not connected
    case notConnected(String)

    /// Failed to connect to device
    case connectionFailed(deviceId: UUID?, reason: String?)

    /// Connection timed out before completing
    case connectionTimeout(deviceId: UUID?, timeoutSeconds: TimeInterval)

    /// Device disconnected unexpectedly
    case unexpectedDisconnection(deviceId: UUID?, reason: String?)

    /// Device not found or no longer available
    case deviceNotFound(identifier: String)

    /// Maximum connection attempts exceeded
    case maxReconnectionAttemptsExceeded(attempts: Int)

    // MARK: - Discovery Errors

    /// Required service not found on device
    case serviceNotFound(serviceId: String)

    /// Required characteristic not found
    case characteristicNotFound(characteristicId: String)

    /// Service discovery failed
    case serviceDiscoveryFailed(reason: String?)

    /// Characteristic discovery failed
    case characteristicDiscoveryFailed(reason: String?)

    // MARK: - Data Transfer Errors

    /// Write operation failed
    case writeFailed(reason: String?)

    /// Read operation failed
    case readFailed(reason: String?)

    /// Notification setup failed
    case notificationSetupFailed(reason: String?)

    /// Data received was corrupted or malformed
    case dataCorrupted(description: String)

    /// Data validation failed
    case dataValidationFailed(expected: String, received: String)

    /// Invalid data format
    case invalidDataFormat(description: String)

    // MARK: - Operation Errors

    /// Operation timed out
    case timeout(operation: String, timeoutSeconds: TimeInterval)

    /// Operation was cancelled
    case cancelled(operation: String)

    /// Operation not permitted in current state
    case operationNotPermitted(operation: String, currentState: String)

    /// Device is busy with another operation
    case deviceBusy

    // MARK: - Configuration Errors

    /// Invalid configuration provided
    case invalidConfiguration(description: String)

    /// Sensor not supported by device
    case sensorNotSupported(sensorType: SensorType)

    // MARK: - Internal Errors

    /// Internal error with underlying cause
    case internalError(reason: String)

    /// Unknown error
    case unknown(description: String)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .notConnected(let message):
            return "Device not connected: \(message)"
        case .connectionFailed(_, let reason):
            return "Connection failed: \(reason ?? "Unknown reason")"
        case .connectionTimeout(_, let timeout):
            return "Connection timed out after \(Int(timeout)) seconds"
        case .unexpectedDisconnection(_, let reason):
            return "Device disconnected unexpectedly: \(reason ?? "Unknown reason")"
        case .deviceNotFound(let identifier):
            return "Device not found: \(identifier)"
        case .maxReconnectionAttemptsExceeded(let attempts):
            return "Failed to reconnect after \(attempts) attempts"
        case .serviceNotFound(let serviceId):
            return "Required service not found: \(serviceId)"
        case .characteristicNotFound(let characteristicId):
            return "Required characteristic not found: \(characteristicId)"
        case .serviceDiscoveryFailed(let reason):
            return "Service discovery failed: \(reason ?? "Unknown reason")"
        case .characteristicDiscoveryFailed(let reason):
            return "Characteristic discovery failed: \(reason ?? "Unknown reason")"
        case .writeFailed(let reason):
            return "Write operation failed: \(reason ?? "Unknown reason")"
        case .readFailed(let reason):
            return "Read operation failed: \(reason ?? "Unknown reason")"
        case .notificationSetupFailed(let reason):
            return "Failed to enable notifications: \(reason ?? "Unknown reason")"
        case .dataCorrupted(let description):
            return "Data corrupted: \(description)"
        case .dataValidationFailed(let expected, let received):
            return "Data validation failed. Expected: \(expected), Received: \(received)"
        case .invalidDataFormat(let description):
            return "Invalid data format: \(description)"
        case .timeout(let operation, let timeout):
            return "\(operation) timed out after \(Int(timeout)) seconds"
        case .cancelled(let operation):
            return "\(operation) was cancelled"
        case .operationNotPermitted(let operation, let state):
            return "\(operation) not permitted in \(state) state"
        case .deviceBusy:
            return "Device is busy with another operation"
        case .invalidConfiguration(let description):
            return "Invalid configuration: \(description)"
        case .sensorNotSupported(let sensorType):
            return "Sensor not supported: \(sensorType.displayName)"
        case .internalError(let reason):
            return "Internal error: \(reason)"
        case .unknown(let description):
            return "Unknown error: \(description)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .connectionTimeout:
            return "The device may be out of range or powered off"
        case .dataCorrupted:
            return "The data received from the device was invalid"
        case .deviceNotFound:
            return "The device is not advertising or is out of range"
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .connectionTimeout:
            return "Move closer to the device and try again"
        case .deviceNotFound:
            return "Make sure the device is powered on and in pairing mode"
        case .maxReconnectionAttemptsExceeded:
            return "Try manually reconnecting or restarting the device"
        case .dataCorrupted, .dataValidationFailed:
            return "Try disconnecting and reconnecting to the device"
        default:
            return nil
        }
    }

    // MARK: - Error Classification

    /// Whether this error is recoverable through retry
    public var isRecoverable: Bool {
        switch self {
        case .connectionTimeout, .unexpectedDisconnection, .timeout,
             .dataCorrupted, .deviceBusy:
            return true
        case .maxReconnectionAttemptsExceeded, .cancelled,
             .sensorNotSupported, .invalidConfiguration:
            return false
        default:
            return true
        }
    }

    /// Whether this error should trigger a reconnection attempt
    public var shouldTriggerReconnection: Bool {
        switch self {
        case .unexpectedDisconnection, .connectionTimeout:
            return true
        default:
            return false
        }
    }

    /// Severity level for logging purposes
    public var severity: ErrorSeverity {
        switch self {
        case .cancelled, .deviceBusy:
            return .info
        case .timeout, .connectionTimeout:
            return .warning
        case .notConnected, .connectionFailed, .unexpectedDisconnection,
             .writeFailed, .readFailed, .dataCorrupted:
            return .error
        case .internalError:
            return .critical
        default:
            return .warning
        }
    }

    // MARK: - Equatable Conformance

    public static func == (lhs: DeviceError, rhs: DeviceError) -> Bool {
        switch (lhs, rhs) {
        case (.notConnected(let m1), .notConnected(let m2)):
            return m1 == m2
        case (.connectionFailed(let id1, _), .connectionFailed(let id2, _)):
            return id1 == id2
        case (.connectionTimeout(let id1, _), .connectionTimeout(let id2, _)):
            return id1 == id2
        case (.deviceNotFound(let id1), .deviceNotFound(let id2)):
            return id1 == id2
        case (.deviceBusy, .deviceBusy):
            return true
        case (.timeout(let op1, _), .timeout(let op2, _)):
            return op1 == op2
        case (.cancelled(let op1), .cancelled(let op2)):
            return op1 == op2
        case (.sensorNotSupported(let s1), .sensorNotSupported(let s2)):
            return s1 == s2
        default:
            return false
        }
    }
}

// MARK: - Error Severity

/// Severity levels for errors
public enum ErrorSeverity: Int, Comparable, Codable, Sendable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3

    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
}
