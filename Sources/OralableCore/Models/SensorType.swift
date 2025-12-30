//
//  SensorType.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Defines all sensor types across multiple devices
//

import Foundation

/// Enumeration of all supported sensor types
public enum SensorType: String, Codable, CaseIterable, Sendable {

    // MARK: - Optical Sensors

    /// Photoplethysmography Red channel (Oralable)
    case ppgRed = "ppg_red"

    /// Photoplethysmography Infrared channel (Oralable)
    case ppgInfrared = "ppg_infrared"

    /// Photoplethysmography Green channel (Oralable)
    case ppgGreen = "ppg_green"

    /// Electromyography (ANR Muscle Sense)
    case emg = "emg"

    // MARK: - Motion Sensors

    /// Accelerometer X-axis
    case accelerometerX = "accel_x"

    /// Accelerometer Y-axis
    case accelerometerY = "accel_y"

    /// Accelerometer Z-axis
    case accelerometerZ = "accel_z"

    // MARK: - Environmental Sensors

    /// Temperature in Celsius
    case temperature = "temperature"

    // MARK: - System Sensors

    /// Battery level percentage (0-100)
    case battery = "battery"

    // MARK: - Computed Metrics

    /// Heart rate in beats per minute
    case heartRate = "heart_rate"

    /// Blood oxygen saturation percentage
    case spo2 = "spo2"

    /// Muscle activity level (computed from EMG)
    case muscleActivity = "muscle_activity"

    // MARK: - Properties

    /// Human-readable name
    public var displayName: String {
        switch self {
        case .ppgRed: return "PPG Red"
        case .ppgInfrared: return "PPG Infrared"
        case .ppgGreen: return "PPG Green"
        case .emg: return "EMG"
        case .accelerometerX: return "Accel X"
        case .accelerometerY: return "Accel Y"
        case .accelerometerZ: return "Accel Z"
        case .temperature: return "Temperature"
        case .battery: return "Battery"
        case .heartRate: return "Heart Rate"
        case .spo2: return "SpO2"
        case .muscleActivity: return "Muscle Activity"
        }
    }

    /// Unit of measurement
    public var unit: String {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return "ADC"
        case .emg:
            return "µV"
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return "g"
        case .temperature:
            return "°C"
        case .battery:
            return "%"
        case .heartRate:
            return "bpm"
        case .spo2:
            return "%"
        case .muscleActivity:
            return "µV"
        }
    }

    /// Whether this is an optical signal (PPG or EMG)
    public var isOpticalSignal: Bool {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return true
        default:
            return false
        }
    }

    /// Whether this sensor type requires special processing
    public var requiresProcessing: Bool {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return true
        default:
            return false
        }
    }

    /// Icon name for UI display (SF Symbol name)
    public var iconName: String {
        switch self {
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return "waveform.path.ecg"
        case .emg:
            return "waveform.path.ecg"
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return "gyroscope"
        case .temperature:
            return "thermometer"
        case .battery:
            return "battery.100"
        case .heartRate:
            return "heart.fill"
        case .spo2:
            return "lungs.fill"
        case .muscleActivity:
            return "bolt.fill"
        }
    }

    /// Default mock value for testing
    public var mockValue: Double {
        switch self {
        case .heartRate: return 72
        case .spo2: return 98
        case .temperature: return 36.5
        case .battery: return 85
        case .ppgRed: return 2048
        case .ppgInfrared: return 1856
        case .ppgGreen: return 2240
        case .emg: return 450
        case .accelerometerX: return 0.05
        case .accelerometerY: return -0.12
        case .accelerometerZ: return 9.81
        case .muscleActivity: return 520
        }
    }
}

// MARK: - Sensor Grouping

extension SensorType {

    /// Optical sensors (PPG channels and EMG)
    public static var opticalSensors: [SensorType] {
        [.ppgRed, .ppgInfrared, .ppgGreen, .emg]
    }

    /// Motion sensors (accelerometer axes)
    public static var motionSensors: [SensorType] {
        [.accelerometerX, .accelerometerY, .accelerometerZ]
    }

    /// Environmental sensors
    public static var environmentalSensors: [SensorType] {
        [.temperature]
    }

    /// System sensors
    public static var systemSensors: [SensorType] {
        [.battery]
    }

    /// Computed health metrics
    public static var computedMetrics: [SensorType] {
        [.heartRate, .spo2, .muscleActivity]
    }

    /// Raw sensor types (non-computed)
    public static var rawSensors: [SensorType] {
        opticalSensors + motionSensors + environmentalSensors + systemSensors
    }
}
