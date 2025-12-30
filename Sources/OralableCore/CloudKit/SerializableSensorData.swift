//
//  SerializableSensorData.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Serializable sensor data for CloudKit exchange between apps
//

import Foundation

// MARK: - Serializable Sensor Data

/// Simplified sensor data structure for CloudKit serialization and exchange
/// Used for sharing data between consumer and professional apps
public struct SerializableSensorData: Codable, Sendable, Equatable, Identifiable {

    public var id: Date { timestamp }

    /// Timestamp of the reading
    public let timestamp: Date

    /// Device identification
    /// "Oralable" or "ANR M40" - optional for backwards compatibility
    public let deviceType: String?

    // MARK: - PPG Data (Oralable device)

    /// PPG Red channel value
    public let ppgRed: Int32

    /// PPG Infrared channel value
    public let ppgIR: Int32

    /// PPG Green channel value
    public let ppgGreen: Int32

    // MARK: - EMG Data (ANR M40 device)

    /// EMG value (optional, only for ANR device)
    public let emg: Double?

    // MARK: - Accelerometer Data

    /// Accelerometer X axis (raw value)
    public let accelX: Int16

    /// Accelerometer Y axis (raw value)
    public let accelY: Int16

    /// Accelerometer Z axis (raw value)
    public let accelZ: Int16

    /// Calculated accelerometer magnitude
    public let accelMagnitude: Double

    // MARK: - Temperature

    /// Temperature in Celsius
    public let temperatureCelsius: Double

    // MARK: - Battery

    /// Battery level percentage (0-100)
    public let batteryPercentage: Int

    // MARK: - Calculated Metrics

    /// Heart rate in BPM (if calculated)
    public let heartRateBPM: Double?

    /// Heart rate signal quality (0.0-1.0)
    public let heartRateQuality: Double?

    /// SpO2 percentage (if calculated)
    public let spo2Percentage: Double?

    /// SpO2 signal quality (0.0-1.0)
    public let spo2Quality: Double?

    // MARK: - Initialization

    public init(
        timestamp: Date,
        deviceType: String? = nil,
        ppgRed: Int32 = 0,
        ppgIR: Int32 = 0,
        ppgGreen: Int32 = 0,
        emg: Double? = nil,
        accelX: Int16 = 0,
        accelY: Int16 = 0,
        accelZ: Int16 = 0,
        accelMagnitude: Double = 0,
        temperatureCelsius: Double = 0,
        batteryPercentage: Int = 0,
        heartRateBPM: Double? = nil,
        heartRateQuality: Double? = nil,
        spo2Percentage: Double? = nil,
        spo2Quality: Double? = nil
    ) {
        self.timestamp = timestamp
        self.deviceType = deviceType
        self.ppgRed = ppgRed
        self.ppgIR = ppgIR
        self.ppgGreen = ppgGreen
        self.emg = emg
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.accelMagnitude = accelMagnitude
        self.temperatureCelsius = temperatureCelsius
        self.batteryPercentage = batteryPercentage
        self.heartRateBPM = heartRateBPM
        self.heartRateQuality = heartRateQuality
        self.spo2Percentage = spo2Percentage
        self.spo2Quality = spo2Quality
    }

    /// Create from SensorData (main conversion from app data model)
    public init(from sensorData: SensorData) {
        self.timestamp = sensorData.timestamp
        self.deviceType = sensorData.deviceType.cloudKitIdentifier

        // PPG data
        self.ppgRed = sensorData.ppg.red
        self.ppgIR = sensorData.ppg.ir
        self.ppgGreen = sensorData.ppg.green

        // EMG data - for ANR device, ppg.ir may contain the EMG value
        if sensorData.deviceType == .anr && sensorData.ppg.ir > 0 {
            self.emg = Double(sensorData.ppg.ir)
        } else {
            self.emg = nil
        }

        // Accelerometer
        self.accelX = sensorData.accelerometer.x
        self.accelY = sensorData.accelerometer.y
        self.accelZ = sensorData.accelerometer.z
        self.accelMagnitude = sensorData.accelerometer.magnitude

        // Temperature
        self.temperatureCelsius = sensorData.temperature.celsius

        // Battery
        self.batteryPercentage = sensorData.battery.percentage

        // Calculated metrics
        self.heartRateBPM = sensorData.heartRate?.bpm
        self.heartRateQuality = sensorData.heartRate?.quality
        self.spo2Percentage = sensorData.spo2?.percentage
        self.spo2Quality = sensorData.spo2?.quality
    }

    // MARK: - Device Type Detection

    /// Inferred device type based on data characteristics
    /// For legacy data without deviceType field, infers from sensor values
    public var inferredDeviceType: String {
        // If deviceType is already set, use it
        if let deviceType = deviceType {
            return deviceType
        }

        // Infer from data patterns:
        // - Oralable has PPG data (IR values typically 1000+)
        // - ANR M40 has EMG data
        if ppgIR > 1000 {
            return DeviceType.oralable.cloudKitIdentifier
        } else if let emg = emg, emg > 0 {
            return DeviceType.anr.cloudKitIdentifier
        } else if ppgIR > 0 && ppgIR < 1000 {
            // Low ppgIR could be EMG value stored in IR field (legacy ANR data)
            return DeviceType.anr.cloudKitIdentifier
        }

        // Default to Oralable
        return DeviceType.oralable.cloudKitIdentifier
    }

    /// Whether this is from an ANR M40 device
    public var isANRDevice: Bool {
        inferredDeviceType == DeviceType.anr.cloudKitIdentifier
    }

    /// Whether this is from an Oralable device
    public var isOralableDevice: Bool {
        inferredDeviceType == DeviceType.oralable.cloudKitIdentifier
    }

    /// Get EMG value (from dedicated field or inferred from legacy data)
    public var emgValue: Double? {
        if let emg = emg, emg > 0 {
            return emg
        }
        // For legacy data, ANR stored EMG in ppgIR field
        if isANRDevice && ppgIR > 0 && ppgIR < 1000 {
            return Double(ppgIR)
        }
        return nil
    }

    /// Get PPG IR value (only valid for Oralable devices)
    public var ppgIRValue: Double? {
        if isOralableDevice && ppgIR > 1000 {
            return Double(ppgIR)
        }
        return nil
    }

    // MARK: - Validation

    /// Whether the reading has valid heart rate data
    public var hasValidHeartRate: Bool {
        guard let hr = heartRateBPM else { return false }
        return hr >= 30 && hr <= 250
    }

    /// Whether the reading has valid SpO2 data
    public var hasValidSpO2: Bool {
        guard let spo2 = spo2Percentage else { return false }
        return spo2 >= 70 && spo2 <= 100
    }

    /// Whether the reading has any valid biometric data
    public var hasValidBiometrics: Bool {
        hasValidHeartRate || hasValidSpO2
    }
}

// MARK: - DeviceType Extension

public extension DeviceType {
    /// CloudKit identifier string for this device type
    var cloudKitIdentifier: String {
        switch self {
        case .oralable:
            return "Oralable"
        case .anr:
            return "ANR M40"
        case .demo:
            return "Demo"
        }
    }

    /// Create DeviceType from CloudKit identifier
    static func fromCloudKit(_ identifier: String) -> DeviceType {
        switch identifier {
        case "Oralable":
            return .oralable
        case "ANR M40":
            return .anr
        case "Demo":
            return .demo
        default:
            return .oralable
        }
    }
}

// MARK: - Array Extensions

public extension Array where Element == SerializableSensorData {

    /// Filter to only Oralable device data
    var oralableData: [SerializableSensorData] {
        filter { $0.isOralableDevice }
    }

    /// Filter to only ANR device data
    var anrData: [SerializableSensorData] {
        filter { $0.isANRDevice }
    }

    /// Get readings with valid heart rate
    var withValidHeartRate: [SerializableSensorData] {
        filter { $0.hasValidHeartRate }
    }

    /// Get readings with valid SpO2
    var withValidSpO2: [SerializableSensorData] {
        filter { $0.hasValidSpO2 }
    }

    /// Average heart rate from valid readings
    var averageHeartRate: Double? {
        let validReadings = withValidHeartRate
        guard !validReadings.isEmpty else { return nil }
        let sum = validReadings.compactMap { $0.heartRateBPM }.reduce(0, +)
        return sum / Double(validReadings.count)
    }

    /// Average SpO2 from valid readings
    var averageSpO2: Double? {
        let validReadings = withValidSpO2
        guard !validReadings.isEmpty else { return nil }
        let sum = validReadings.compactMap { $0.spo2Percentage }.reduce(0, +)
        return sum / Double(validReadings.count)
    }

    /// Date range of the readings
    var dateRange: (start: Date, end: Date)? {
        guard let first = self.first, let last = self.last else { return nil }
        let sorted = self.sorted { $0.timestamp < $1.timestamp }
        return (sorted.first?.timestamp ?? first.timestamp,
                sorted.last?.timestamp ?? last.timestamp)
    }

    /// Total duration in seconds
    var duration: TimeInterval? {
        guard let range = dateRange else { return nil }
        return range.end.timeIntervalSince(range.start)
    }
}
