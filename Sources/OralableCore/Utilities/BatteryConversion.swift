//
//  BatteryConversion.swift
//  OralableCore
//
//  Oralable CG-320B user gauge — matches firmware battery_voltage_to_percent
//  (FW >= 1.0.68): 4.35 V = 100%, 3.61 V = remapped 0% (operational empty).
//

import Foundation

// MARK: - Battery Conversion Utilities

/// Converts battery voltage to percentage using the Oralable remapped linear gauge.
public struct BatteryConversion: Sendable {

    // MARK: - Voltage Constants (aligned with oralable_nrf battery.c)

    /// Fully charged voltage (mV) — CG320B Vmax
    public static let voltageMax: Int32 = 4350

    /// Remapped empty / soft floor (mV) — operational 0%, not chemistry empty (~3000)
    public static let voltageMin: Int32 = 3610

    /// Chemistry empty (mV) — diagnostic % only
    public static let chemistryVoltageMin: Int32 = 3000

    /// Low battery warning threshold (mV) — ~15% on remapped gauge
    public static let voltageLowWarning: Int32 = 3720

    /// Critical / soft-floor adjacent (mV)
    public static let voltageCritical: Int32 = 3610

    // MARK: - Conversion Methods

    /// Convert battery voltage in millivolts to percentage (firmware-aligned linear map).
    /// - Parameter millivolts: Battery voltage in millivolts
    /// - Returns: Battery percentage (0.0 to 100.0)
    public static func voltageToPercentage(millivolts: Int32) -> Double {
        return linearPercentage(millivolts: millivolts)
    }

    /// Linear map matching firmware: (V - 3610) * 100 / (4350 - 3610)
    public static func linearPercentage(millivolts: Int32) -> Double {
        if millivolts >= voltageMax {
            return 100.0
        }
        if millivolts <= voltageMin {
            return 0.0
        }
        let range = Double(voltageMax - voltageMin)
        let pct = Double(millivolts - voltageMin) * 100.0 / range
        return min(100.0, max(0.0, pct))
    }

    /// Full chemistry span: 3.0 V = 0%, 4.35 V = 100% (logs / diagnostics).
    public static func chemistryPercentage(millivolts: Int32) -> Double {
        if millivolts >= voltageMax {
            return 100.0
        }
        if millivolts <= chemistryVoltageMin {
            return 0.0
        }
        let range = Double(voltageMax - chemistryVoltageMin)
        let pct = Double(millivolts - chemistryVoltageMin) * 100.0 / range
        return min(100.0, max(0.0, pct))
    }

    public static func chemistryPercentageInt(millivolts: Int32) -> Int {
        return Int(chemistryPercentage(millivolts: millivolts).rounded())
    }

    /// Convert voltage to percentage with rounding to integer
    public static func voltageToPercentageInt(millivolts: Int32) -> Int {
        return Int(voltageToPercentage(millivolts: millivolts).rounded())
    }

    // MARK: - Status Methods

    public static func batteryStatus(percentage: Double) -> BatteryStatus {
        switch percentage {
        case 80...100: return .excellent
        case 50..<80: return .good
        case 20..<50: return .medium
        case 10..<20: return .low
        default: return .critical
        }
    }

    public static func batteryStatus(millivolts: Int32) -> BatteryStatus {
        return batteryStatus(percentage: voltageToPercentage(millivolts: millivolts))
    }

    public static func needsCharging(percentage: Double) -> Bool {
        return percentage < 20.0
    }

    public static func isCritical(percentage: Double) -> Bool {
        return percentage < 10.0
    }

    // MARK: - Formatting

    public static func formatPercentage(_ percentage: Double) -> String {
        return String(format: "%.0f%%", percentage)
    }

    public static func formatVoltage(millivolts: Int32) -> String {
        let volts = Double(millivolts) / 1000.0
        return String(format: "%.2fV", volts)
    }

    // MARK: - Data Parsing

    public static func parseAndConvert(data: Data) -> Double? {
        guard data.count >= 4 else { return nil }

        let millivolts = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self)
        }

        return voltageToPercentage(millivolts: millivolts)
    }

    public static func parseComplete(data: Data) -> (millivolts: Int32, percentage: Double, status: BatteryStatus)? {
        guard data.count >= 4 else { return nil }

        let millivolts = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self)
        }

        guard millivolts >= 2500 && millivolts <= 4500 else { return nil }

        let percentage = voltageToPercentage(millivolts: millivolts)
        let status = batteryStatus(percentage: percentage)

        return (millivolts: millivolts, percentage: percentage, status: status)
    }

    #if DEBUG
    public static func generateComparisonTable() -> [(voltage: Int32, linear: Double, curve: Double, difference: Double)] {
        var results: [(voltage: Int32, linear: Double, curve: Double, difference: Double)] = []

        for voltage in stride(from: voltageMax, through: voltageMin, by: -100) {
            let linear = linearPercentage(millivolts: voltage)
            results.append((voltage: voltage, linear: linear, curve: linear, difference: 0))
        }

        return results
    }
    #endif
}
