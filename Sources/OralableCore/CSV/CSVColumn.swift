//
//  CSVColumn.swift
//  OralableCore
//
//  Created: December 30, 2025
//  CSV column definitions for sensor data export/import
//

import Foundation

/// Available columns for CSV export/import
public enum CSVColumn: String, CaseIterable, Sendable {
    // Core columns (always included)
    case timestamp = "Timestamp"

    // PPG columns
    case ppgIR = "PPG_IR"
    case ppgRed = "PPG_Red"
    case ppgGreen = "PPG_Green"

    // Accelerometer columns
    case accelX = "Accel_X"
    case accelY = "Accel_Y"
    case accelZ = "Accel_Z"

    // Environmental columns
    case temperature = "Temp_C"
    case battery = "Battery_%"

    // Computed metrics columns
    case heartRateBPM = "HeartRate_BPM"
    case heartRateQuality = "HeartRate_Quality"
    case spo2Percentage = "SpO2_%"
    case spo2Quality = "SpO2_Quality"

    // Log/message column
    case message = "Message"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .timestamp:
            return "Timestamp"
        case .ppgIR:
            return "PPG Infrared"
        case .ppgRed:
            return "PPG Red"
        case .ppgGreen:
            return "PPG Green"
        case .accelX:
            return "Accelerometer X"
        case .accelY:
            return "Accelerometer Y"
        case .accelZ:
            return "Accelerometer Z"
        case .temperature:
            return "Temperature (°C)"
        case .battery:
            return "Battery (%)"
        case .heartRateBPM:
            return "Heart Rate (BPM)"
        case .heartRateQuality:
            return "Heart Rate Quality"
        case .spo2Percentage:
            return "SpO2 (%)"
        case .spo2Quality:
            return "SpO2 Quality"
        case .message:
            return "Message"
        }
    }

    /// Data type description for documentation
    public var dataType: String {
        switch self {
        case .timestamp:
            return "Date/Time (yyyy-MM-dd HH:mm:ss.SSS)"
        case .ppgIR, .ppgRed, .ppgGreen:
            return "Int32"
        case .accelX, .accelY, .accelZ:
            return "Int16"
        case .temperature:
            return "Double"
        case .battery:
            return "Int (0-100)"
        case .heartRateBPM, .spo2Percentage:
            return "Double (optional)"
        case .heartRateQuality, .spo2Quality:
            return "Double 0.0-1.0 (optional)"
        case .message:
            return "String (optional)"
        }
    }

    /// Whether this column is always required
    public var isRequired: Bool {
        switch self {
        case .timestamp, .ppgIR, .ppgRed, .ppgGreen,
             .accelX, .accelY, .accelZ, .temperature, .battery:
            return true
        case .heartRateBPM, .heartRateQuality, .spo2Percentage, .spo2Quality, .message:
            return false
        }
    }

    /// Column group for organization
    public var group: CSVColumnGroup {
        switch self {
        case .timestamp:
            return .core
        case .ppgIR, .ppgRed, .ppgGreen:
            return .ppg
        case .accelX, .accelY, .accelZ:
            return .accelerometer
        case .temperature:
            return .temperature
        case .battery:
            return .battery
        case .heartRateBPM, .heartRateQuality:
            return .heartRate
        case .spo2Percentage, .spo2Quality:
            return .spo2
        case .message:
            return .log
        }
    }

    /// All columns in standard export order
    public static var standardOrder: [CSVColumn] {
        return [
            .timestamp,
            .ppgIR, .ppgRed, .ppgGreen,
            .accelX, .accelY, .accelZ,
            .temperature, .battery,
            .heartRateBPM, .heartRateQuality,
            .spo2Percentage, .spo2Quality,
            .message
        ]
    }

    /// Required columns only
    public static var requiredColumns: [CSVColumn] {
        return allCases.filter { $0.isRequired }
    }
}

// MARK: - Column Group

/// Groups of related CSV columns
public enum CSVColumnGroup: String, CaseIterable, Sendable {
    case core = "Core"
    case ppg = "PPG"
    case accelerometer = "Accelerometer"
    case temperature = "Temperature"
    case battery = "Battery"
    case heartRate = "Heart Rate"
    case spo2 = "SpO2"
    case log = "Log"

    /// Columns in this group
    public var columns: [CSVColumn] {
        return CSVColumn.allCases.filter { $0.group == self }
    }
}
