//
//  SensorData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Main container for all sensor data from Oralable devices
//

import Foundation

/// Container for all sensor data from the Oralable device
public struct SensorData: Identifiable, Codable, Sendable {
    /// Unique identifier for this data point
    public let id: UUID

    /// Timestamp of the data collection
    public let timestamp: Date

    // MARK: - Raw Sensor Data

    /// PPG (Photoplethysmography) sensor data
    public let ppg: PPGData

    /// 3-axis accelerometer data
    public let accelerometer: AccelerometerData

    /// Temperature sensor data
    public let temperature: TemperatureData

    /// Battery level data
    public let battery: BatteryData

    // MARK: - Calculated Metrics

    /// Calculated heart rate (optional, may not be available)
    public let heartRate: HeartRateData?

    /// Calculated SpO2/blood oxygen (optional, may not be available)
    public let spo2: SpO2Data?

    // MARK: - Device Information

    /// Type of device that collected this data
    public let deviceType: DeviceType

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        ppg: PPGData,
        accelerometer: AccelerometerData,
        temperature: TemperatureData,
        battery: BatteryData,
        heartRate: HeartRateData? = nil,
        spo2: SpO2Data? = nil,
        deviceType: DeviceType = .oralable
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ppg = ppg
        self.accelerometer = accelerometer
        self.temperature = temperature
        self.battery = battery
        self.heartRate = heartRate
        self.spo2 = spo2
        self.deviceType = deviceType
    }

    // MARK: - Convenience Properties

    /// Whether this data point has valid heart rate data
    public var hasValidHeartRate: Bool {
        return heartRate?.isValid ?? false
    }

    /// Whether this data point has valid SpO2 data
    public var hasValidSpO2: Bool {
        return spo2?.isValid ?? false
    }

    /// Overall data quality (average of available quality metrics)
    public var overallQuality: Double {
        var qualities: [Double] = [ppg.signalQuality]

        if let hr = heartRate {
            qualities.append(hr.quality)
        }
        if let sp = spo2 {
            qualities.append(sp.quality)
        }

        return qualities.reduce(0, +) / Double(qualities.count)
    }
}

// MARK: - Equatable

extension SensorData: Equatable {
    public static func == (lhs: SensorData, rhs: SensorData) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension SensorData: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
