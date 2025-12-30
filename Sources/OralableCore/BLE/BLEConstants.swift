//
//  BLEConstants.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Centralized BLE service and characteristic UUIDs for Oralable devices
//  Framework-agnostic implementation using String UUIDs
//

import Foundation

// MARK: - BLE Constants

/// Centralized BLE service and characteristic UUID constants
/// Use these constants when working with CoreBluetooth
public enum BLEConstants {

    // MARK: - TGM (Oralable) Device UUIDs

    /// TGM Service and Characteristic UUIDs for Oralable oral sensor device
    public enum TGM {

        /// Primary TGM service UUID
        /// Contains PPG, accelerometer, temperature, and battery characteristics
        public static let serviceUUID = "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E"

        /// PPG sensor data characteristic (244 bytes typically)
        /// Format: Red(4) + IR(4) + Green(4) per sample, multiple samples per packet
        public static let sensorDataCharUUID = "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E"

        /// Accelerometer data characteristic (154 bytes typically)
        /// Format: X(2) + Y(2) + Z(2) per sample as Int16, multiple samples per packet
        public static let accelerometerCharUUID = "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E"

        /// Temperature/command characteristic (8 bytes typically)
        /// Also used for device commands
        public static let commandCharUUID = "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E"

        /// TGM Battery characteristic (4 bytes - millivolts as Int32)
        /// Reports battery voltage in millivolts for accurate percentage calculation
        public static let batteryCharUUID = "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E"

        /// All TGM characteristic UUIDs
        public static let allCharacteristicUUIDs: [String] = [
            sensorDataCharUUID,
            accelerometerCharUUID,
            commandCharUUID,
            batteryCharUUID
        ]

        /// Expected packet sizes
        public enum PacketSize {
            /// PPG data packet size (244 bytes = 20 samples × 12 bytes + 4 bytes header)
            public static let ppgData = 244

            /// Accelerometer packet size (154 bytes = 25 samples × 6 bytes + 4 bytes header)
            public static let accelerometer = 154

            /// Temperature packet size
            public static let temperature = 8

            /// Battery packet size (4 bytes = Int32 millivolts)
            public static let battery = 4
        }

        /// Data format constants
        public enum DataFormat {
            /// Bytes per PPG sample (Red + IR + Green as UInt32)
            public static let bytesPerPPGSample = 12

            /// Bytes per accelerometer sample (X + Y + Z as Int16)
            public static let bytesPerAccelSample = 6

            /// PPG values are UInt32
            public static let ppgValueSize = 4

            /// Accelerometer values are Int16
            public static let accelValueSize = 2
        }
    }

    // MARK: - ANR (Muscle Sense) Device UUIDs

    /// ANR MuscleSense device UUIDs for EMG monitoring
    public enum ANR {

        /// Automation I/O Service UUID (standard Bluetooth SIG service)
        /// Used for EMG data transmission
        public static let automationIOServiceUUID = "1815"

        /// Analog characteristic UUID - EMG data
        /// Format: 16-bit value, 0-1023 range, 100ms notification interval
        public static let analogCharUUID = "2A58"

        /// Digital characteristic UUID - Device ID
        /// Format: 8-bit value, 1-24 range
        public static let digitalCharUUID = "2A56"

        /// All ANR service UUIDs
        public static let allServiceUUIDs: [String] = [
            automationIOServiceUUID,
            StandardBLE.batteryServiceUUID,
            StandardBLE.deviceInfoServiceUUID
        ]

        /// Data format constants
        public enum DataFormat {
            /// EMG value range minimum
            public static let emgMin: UInt16 = 0

            /// EMG value range maximum
            public static let emgMax: UInt16 = 1023

            /// EMG notification interval in milliseconds
            public static let emgNotificationIntervalMs = 100

            /// Device ID range
            public static let deviceIdRange = 1...24
        }
    }

    // MARK: - Standard Bluetooth SIG Service UUIDs

    /// Standard Bluetooth SIG service and characteristic UUIDs
    public enum StandardBLE {

        // MARK: - Battery Service (0x180F)

        /// Battery Service UUID
        public static let batteryServiceUUID = "180F"

        /// Battery Level characteristic UUID (1 byte, 0-100%)
        public static let batteryLevelCharUUID = "2A19"

        // MARK: - Device Information Service (0x180A)

        /// Device Information Service UUID
        public static let deviceInfoServiceUUID = "180A"

        /// Model Number String characteristic
        public static let modelNumberCharUUID = "2A24"

        /// Serial Number String characteristic
        public static let serialNumberCharUUID = "2A25"

        /// Firmware Revision String characteristic
        public static let firmwareRevisionCharUUID = "2A26"

        /// Hardware Revision String characteristic
        public static let hardwareRevisionCharUUID = "2A27"

        /// Software Revision String characteristic
        public static let softwareRevisionCharUUID = "2A28"

        /// Manufacturer Name String characteristic
        public static let manufacturerNameCharUUID = "2A29"

        /// All Device Information characteristic UUIDs
        public static let deviceInfoCharUUIDs: [String] = [
            modelNumberCharUUID,
            serialNumberCharUUID,
            firmwareRevisionCharUUID,
            hardwareRevisionCharUUID,
            softwareRevisionCharUUID,
            manufacturerNameCharUUID
        ]

        // MARK: - Heart Rate Service (0x180D) - Future use

        /// Heart Rate Service UUID
        public static let heartRateServiceUUID = "180D"

        /// Heart Rate Measurement characteristic
        public static let heartRateMeasurementCharUUID = "2A37"

        // MARK: - Pulse Oximeter Service (0x1822) - Future use

        /// Pulse Oximeter Service UUID
        public static let pulseOximeterServiceUUID = "1822"

        /// PLX Continuous Measurement characteristic
        public static let plxContinuousMeasurementCharUUID = "2A5F"
    }

    // MARK: - Device Detection

    /// Helper functions for device type detection
    public enum Detection {

        /// Check if a service UUID indicates an Oralable device
        /// - Parameter serviceUUID: The service UUID string to check
        /// - Returns: True if the UUID matches TGM service
        public static func isOralableDevice(serviceUUID: String) -> Bool {
            return serviceUUID.uppercased() == TGM.serviceUUID.uppercased()
        }

        /// Check if a service UUID indicates an ANR device
        /// - Parameter serviceUUID: The service UUID string to check
        /// - Returns: True if the UUID matches ANR Automation I/O service
        public static func isANRDevice(serviceUUID: String) -> Bool {
            let normalized = serviceUUID.uppercased()
            return normalized == ANR.automationIOServiceUUID.uppercased() ||
                   normalized == "00001815-0000-1000-8000-00805F9B34FB"
        }

        /// Determine device type from advertised service UUIDs
        /// - Parameter serviceUUIDs: Array of service UUID strings
        /// - Returns: Detected DeviceType or nil if unknown
        public static func detectDeviceType(serviceUUIDs: [String]) -> DeviceType? {
            for uuid in serviceUUIDs {
                if isOralableDevice(serviceUUID: uuid) {
                    return .oralable
                }
                if isANRDevice(serviceUUID: uuid) {
                    return .anr
                }
            }
            return nil
        }

        /// Get the primary service UUID for a device type
        /// - Parameter deviceType: The device type
        /// - Returns: Primary service UUID string
        public static func primaryServiceUUID(for deviceType: DeviceType) -> String {
            switch deviceType {
            case .oralable:
                return TGM.serviceUUID
            case .anr:
                return ANR.automationIOServiceUUID
            case .demo:
                return "00000000-0000-0000-0000-000000000000"
            }
        }

        /// Get all service UUIDs to discover for a device type
        /// - Parameter deviceType: The device type
        /// - Returns: Array of service UUID strings
        public static func serviceUUIDs(for deviceType: DeviceType) -> [String] {
            switch deviceType {
            case .oralable:
                return [TGM.serviceUUID, StandardBLE.batteryServiceUUID]
            case .anr:
                return ANR.allServiceUUIDs
            case .demo:
                return []
            }
        }
    }

    // MARK: - UUID Formatting

    /// UUID formatting utilities
    public enum Formatting {

        /// Convert a short UUID (4 hex chars) to full 128-bit format
        /// - Parameter shortUUID: Short UUID like "180F"
        /// - Returns: Full UUID string like "0000180F-0000-1000-8000-00805F9B34FB"
        public static func expandShortUUID(_ shortUUID: String) -> String {
            let normalized = shortUUID.uppercased().trimmingCharacters(in: .whitespaces)
            if normalized.count == 4 {
                return "0000\(normalized)-0000-1000-8000-00805F9B34FB"
            }
            return normalized
        }

        /// Check if a UUID is in short format (4 hex characters)
        /// - Parameter uuid: UUID string to check
        /// - Returns: True if short format
        public static func isShortUUID(_ uuid: String) -> Bool {
            let trimmed = uuid.trimmingCharacters(in: .whitespaces)
            return trimmed.count == 4 && trimmed.allSatisfy { $0.isHexDigit }
        }

        /// Normalize a UUID string for comparison (uppercase, full format)
        /// - Parameter uuid: UUID string to normalize
        /// - Returns: Normalized UUID string
        public static func normalizeUUID(_ uuid: String) -> String {
            let trimmed = uuid.trimmingCharacters(in: .whitespaces).uppercased()
            if isShortUUID(trimmed) {
                return expandShortUUID(trimmed)
            }
            return trimmed
        }
    }
}

// MARK: - RSSI Signal Quality

/// Extension to BLEConstants for signal quality assessment
extension BLEConstants {

    /// RSSI thresholds for signal quality assessment
    public enum RSSIThresholds {
        /// Excellent signal (>= -50 dBm)
        public static let excellent = -50

        /// Good signal (>= -60 dBm)
        public static let good = -60

        /// Fair signal (>= -70 dBm)
        public static let fair = -70

        /// Weak signal (>= -80 dBm)
        public static let weak = -80

        /// Poor signal (< -80 dBm)
        /// Below this, connection may be unreliable
        public static let poor = -100

        /// Minimum usable RSSI
        /// Below this value, connection is very likely to fail
        public static let minimum = -90
    }
}
