//
//  PPGData.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  PPG (Photoplethysmography) sensor data model
//

import Foundation

/// PPG (Photoplethysmography) sensor data with three wavelengths
public struct PPGData: Codable, Sendable, Equatable {
    /// Red LED channel value
    public let red: Int32

    /// Infrared LED channel value
    public let ir: Int32

    /// Green LED channel value
    public let green: Int32

    /// Timestamp of measurement
    public let timestamp: Date

    // MARK: - Initialization

    public init(red: Int32, ir: Int32, green: Int32, timestamp: Date = Date()) {
        self.red = red
        self.ir = ir
        self.green = green
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Signal quality indicator (0.0 to 1.0)
    /// Based on whether values fall within expected ranges
    public var signalQuality: Double {
        let redValid = (10000...500000).contains(red)
        let irValid = (10000...500000).contains(ir)
        let greenValid = (10000...500000).contains(green)

        let validCount = [redValid, irValid, greenValid].filter { $0 }.count
        return Double(validCount) / 3.0
    }

    /// Whether the PPG signal is considered valid for analysis
    public var isValid: Bool {
        return signalQuality >= 0.66  // At least 2 of 3 channels valid
    }
}
