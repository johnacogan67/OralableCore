//
//  DeviceType.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Shared device type enumeration for Oralable ecosystem
//

import Foundation

/// Supported device types in the Oralable ecosystem
public enum DeviceType: String, CaseIterable, Codable, Sendable {
    case oralable = "Oralable"
    case anr = "ANR Muscle Sense"
    case demo = "Demo Device"

    // MARK: - Device Properties

    /// Display name for the device type
    public var displayName: String {
        return rawValue
    }

    /// SF Symbol icon name for the device type
    public var icon: String {
        switch self {
        case .oralable:
            return "waveform.path.ecg"
        case .anr:
            return "bolt.horizontal.circle"
        case .demo:
            return "questionmark.circle"
        }
    }

    /// Whether the device supports multiple simultaneous connections
    public var supportsMultipleConnections: Bool {
        switch self {
        case .oralable:
            return false
        case .anr:
            return false
        case .demo:
            return true
        }
    }

    /// Whether the device requires authentication/pairing
    public var requiresAuthentication: Bool {
        switch self {
        case .oralable:
            return false
        case .anr:
            return false
        case .demo:
            return false
        }
    }

    // MARK: - Data Configuration

    /// Sampling rate in Hz
    public var samplingRate: Int {
        switch self {
        case .oralable:
            return 50  // 50 Hz as per firmware
        case .anr:
            return 100
        case .demo:
            return 10
        }
    }

    /// Number of PPG samples per BLE frame
    public var ppgSamplesPerFrame: Int {
        switch self {
        case .oralable:
            return 20  // CONFIG_PPG_SAMPLES_PER_FRAME from firmware
        case .anr:
            return 0  // No PPG
        case .demo:
            return 10
        }
    }

    /// Number of accelerometer samples per BLE frame
    public var accSamplesPerFrame: Int {
        switch self {
        case .oralable:
            return 25  // CONFIG_ACC_SAMPLES_PER_FRAME from firmware
        case .anr:
            return 50
        case .demo:
            return 10
        }
    }

    // MARK: - Default Sensors

    /// Default sensors supported by this device type
    public var defaultSensors: [SensorType] {
        switch self {
        case .oralable:
            return [
                .ppgRed,
                .ppgInfrared,
                .ppgGreen,
                .accelerometerX,
                .accelerometerY,
                .accelerometerZ,
                .temperature,
                .battery,
                .heartRate,
                .spo2
            ]
        case .anr:
            return [
                .emg,
                .accelerometerX,
                .accelerometerY,
                .accelerometerZ,
                .battery,
                .muscleActivity
            ]
        case .demo:
            return SensorType.allCases
        }
    }

    // MARK: - Helper Methods

    /// Determine device type from a device name string
    /// - Parameter name: The device name (e.g., from BLE advertisement)
    /// - Returns: The matched device type, or `.oralable` as default
    public static func from(deviceName name: String?) -> DeviceType {
        guard let name = name else { return .oralable }

        if name.contains("Oralable") {
            return .oralable
        } else if name.contains("ANR") || name.contains("Muscle") {
            return .anr
        } else if name.contains("Demo") {
            return .demo
        }

        return .oralable
    }
}
