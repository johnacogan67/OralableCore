//
//  Double+Extensions.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Numeric utilities and extensions for sensor values
//

import Foundation

// MARK: - Double Extensions

public extension Double {

    // MARK: - Formatting

    /// Format with specified decimal places
    func formatted(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }

    /// Format as integer (rounded)
    var asInteger: String {
        String(format: "%.0f", self)
    }

    /// Format with 1 decimal place
    var oneDecimal: String {
        formatted(decimals: 1)
    }

    /// Format with 2 decimal places
    var twoDecimals: String {
        formatted(decimals: 2)
    }

    /// Format with 3 decimal places (for precise sensor values)
    var threeDecimals: String {
        formatted(decimals: 3)
    }

    // MARK: - Sensor Value Formatting

    /// Format as heart rate (bpm)
    var asHeartRate: String {
        "\(Int(self.rounded())) bpm"
    }

    /// Format as SpO2 percentage
    var asSpO2: String {
        "\(Int(self.rounded()))%"
    }

    /// Format as temperature (Celsius)
    var asTemperature: String {
        "\(formatted(decimals: 1))°C"
    }

    /// Format as temperature (Fahrenheit)
    var asTemperatureFahrenheit: String {
        let fahrenheit = self * 9.0 / 5.0 + 32.0
        return "\(fahrenheit.formatted(decimals: 1))°F"
    }

    /// Format as acceleration (g)
    var asAcceleration: String {
        "\(formatted(decimals: 2)) g"
    }

    /// Format as battery percentage
    var asBatteryPercentage: String {
        "\(Int(self.clamped(to: 0...100)))%"
    }

    /// Format as signal strength (dBm)
    var asSignalStrength: String {
        "\(Int(self.rounded())) dBm"
    }

    /// Format as millivolts
    var asMillivolts: String {
        "\(formatted(decimals: 1)) mV"
    }

    /// Format as Hz (sampling rate)
    var asHz: String {
        "\(Int(self.rounded())) Hz"
    }

    // MARK: - Rounding

    /// Round to specified number of decimal places
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }

    /// Round to nearest integer
    var roundedInt: Int {
        Int(self.rounded())
    }

    // MARK: - Clamping

    /// Clamp value to a range
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Clamp to valid heart rate range (30-250 bpm)
    var clampedHeartRate: Double {
        clamped(to: 30...250)
    }

    /// Clamp to valid SpO2 range (50-100%)
    var clampedSpO2: Double {
        clamped(to: 50...100)
    }

    /// Clamp to valid temperature range (20-45°C)
    var clampedTemperature: Double {
        clamped(to: 20...45)
    }

    /// Clamp to valid battery range (0-100%)
    var clampedBattery: Double {
        clamped(to: 0...100)
    }

    // MARK: - Validation

    /// Check if value is in valid heart rate range
    var isValidHeartRate: Bool {
        (30...250).contains(self)
    }

    /// Check if value is in valid SpO2 range
    var isValidSpO2: Bool {
        (70...100).contains(self)
    }

    /// Check if value is in valid temperature range (body)
    var isValidBodyTemperature: Bool {
        (35...42).contains(self)
    }

    /// Check if value is finite and not NaN
    var isValidNumber: Bool {
        isFinite && !isNaN
    }

    // MARK: - Math Utilities

    /// Linear interpolation between two values
    static func lerp(from: Double, to: Double, t: Double) -> Double {
        from + (to - from) * t.clamped(to: 0...1)
    }

    /// Map value from one range to another
    func mapped(from inputRange: ClosedRange<Double>, to outputRange: ClosedRange<Double>) -> Double {
        let normalizedInput = (self - inputRange.lowerBound) / (inputRange.upperBound - inputRange.lowerBound)
        return outputRange.lowerBound + normalizedInput * (outputRange.upperBound - outputRange.lowerBound)
    }

    /// Normalize value to 0...1 range
    func normalized(min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        return (self - min) / (max - min)
    }

    // MARK: - Conversion

    /// Convert Celsius to Fahrenheit
    var celsiusToFahrenheit: Double {
        self * 9.0 / 5.0 + 32.0
    }

    /// Convert Fahrenheit to Celsius
    var fahrenheitToCelsius: Double {
        (self - 32.0) * 5.0 / 9.0
    }

    /// Convert milliseconds to seconds
    var msToSeconds: Double {
        self / 1000.0
    }

    /// Convert seconds to milliseconds
    var secondsToMs: Double {
        self * 1000.0
    }
}

// MARK: - Int Extensions

public extension Int {

    /// Format as battery percentage with icon hint
    var batteryDisplayString: String {
        let clamped = Swift.min(Swift.max(self, 0), 100)
        return "\(clamped)%"
    }

    /// Battery level classification
    var batteryLevel: BatteryLevel {
        switch self {
        case 75...100:
            return .high
        case 40..<75:
            return .medium
        case 15..<40:
            return .low
        case 0..<15:
            return .critical
        default:
            return .unknown
        }
    }

    /// Clamp to range
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Battery Level

/// Battery level classification
public enum BatteryLevel: String, Sendable {
    case high
    case medium
    case low
    case critical
    case unknown

    public var iconName: String {
        switch self {
        case .high:
            return "battery.100"
        case .medium:
            return "battery.50"
        case .low:
            return "battery.25"
        case .critical:
            return "battery.0"
        case .unknown:
            return "battery.0"
        }
    }

    public var shouldWarn: Bool {
        self == .low || self == .critical
    }
}

// MARK: - Array Extensions for Numeric Operations

public extension Array where Element == Double {

    /// Calculate sum of values
    var sum: Double {
        reduce(0, +)
    }

    /// Calculate average of values
    var average: Double? {
        isEmpty ? nil : sum / Double(count)
    }

    /// Calculate standard deviation
    var standardDeviation: Double? {
        guard let avg = average, count > 1 else { return nil }
        let variance = reduce(0) { $0 + pow($1 - avg, 2) } / Double(count - 1)
        return sqrt(variance)
    }

    /// Find minimum value
    var minimum: Double? {
        self.min()
    }

    /// Find maximum value
    var maximum: Double? {
        self.max()
    }

    /// Calculate range (max - min)
    var range: Double? {
        guard let min = minimum, let max = maximum else { return nil }
        return max - min
    }

    /// Calculate median
    var median: Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let middleIndex = count / 2
        if count.isMultiple(of: 2) {
            return (sorted[middleIndex - 1] + sorted[middleIndex]) / 2.0
        } else {
            return sorted[middleIndex]
        }
    }

    /// Remove outliers using IQR method
    func withoutOutliers() -> [Double] {
        guard count > 4 else { return self }
        let sorted = self.sorted()
        let q1Index = count / 4
        let q3Index = (count * 3) / 4
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        return filter { $0 >= lowerBound && $0 <= upperBound }
    }
}
