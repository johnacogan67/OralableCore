//
//  AccelerometerConversion.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  LIS2DTW12 accelerometer conversion utilities
//

import Foundation

/// Accelerometer conversion utilities for LIS2DTW12 sensor
/// Based on datasheet Table 3: Mechanical characteristics
public struct AccelerometerConversion: Sendable {

    // MARK: - LIS2DTW12 Sensitivity Values (mg/digit)

    /// Sensitivity at ±2g full scale (high-performance and most low-power modes)
    public static let sensitivity2g: Double = 0.244  // mg/digit

    /// Sensitivity at ±4g full scale
    public static let sensitivity4g: Double = 0.488  // mg/digit

    /// Sensitivity at ±8g full scale
    public static let sensitivity8g: Double = 0.976  // mg/digit

    /// Sensitivity at ±16g full scale
    public static let sensitivity16g: Double = 1.952  // mg/digit

    /// Current firmware configuration (±2g)
    public static let currentFullScale: Int = 2

    /// Tolerance for detecting rest state (device stationary)
    public static let restTolerance: Double = 0.1  // ±0.1g

    // MARK: - Conversion Methods

    /// Get sensitivity value for a given full scale setting
    /// - Parameter fullScale: Full scale range (2, 4, 8, or 16)
    /// - Returns: Sensitivity in mg/digit
    public static func sensitivity(forFullScale fullScale: Int) -> Double {
        switch fullScale {
        case 2: return sensitivity2g
        case 4: return sensitivity4g
        case 8: return sensitivity8g
        case 16: return sensitivity16g
        default: return sensitivity2g
        }
    }

    /// Convert raw Int16 value to g (gravitational acceleration)
    /// - Parameters:
    ///   - rawValue: Raw accelerometer reading (Int16, two's complement)
    ///   - fullScale: Full scale range (2, 4, 8, or 16)
    /// - Returns: Acceleration in g
    public static func toG(rawValue: Int16, fullScale: Int = currentFullScale) -> Double {
        let sens = sensitivity(forFullScale: fullScale)
        // Convert: raw * sensitivity(mg/digit) / 1000 = g
        return Double(rawValue) * sens / 1000.0
    }

    /// Convert raw Int16 values to g for all three axes
    /// - Parameters:
    ///   - x: Raw X-axis value
    ///   - y: Raw Y-axis value
    ///   - z: Raw Z-axis value
    ///   - fullScale: Full scale range (2, 4, 8, or 16)
    /// - Returns: Tuple of (x, y, z) in g
    public static func toG(x: Int16, y: Int16, z: Int16, fullScale: Int = currentFullScale) -> (x: Double, y: Double, z: Double) {
        return (
            x: toG(rawValue: x, fullScale: fullScale),
            y: toG(rawValue: y, fullScale: fullScale),
            z: toG(rawValue: z, fullScale: fullScale)
        )
    }

    /// Calculate magnitude from raw values, converted to g
    /// - Parameters:
    ///   - x: Raw X-axis value
    ///   - y: Raw Y-axis value
    ///   - z: Raw Z-axis value
    ///   - fullScale: Full scale range (2, 4, 8, or 16)
    /// - Returns: Magnitude in g
    public static func magnitude(x: Int16, y: Int16, z: Int16, fullScale: Int = currentFullScale) -> Double {
        let gValues = toG(x: x, y: y, z: z, fullScale: fullScale)
        return sqrt(gValues.x * gValues.x + gValues.y * gValues.y + gValues.z * gValues.z)
    }

    /// Check if the device is at rest (magnitude approximately 1g)
    /// - Parameters:
    ///   - x: Raw X-axis value
    ///   - y: Raw Y-axis value
    ///   - z: Raw Z-axis value
    ///   - fullScale: Full scale range (2, 4, 8, or 16)
    /// - Returns: True if device is at rest
    public static func isAtRest(x: Int16, y: Int16, z: Int16, fullScale: Int = currentFullScale) -> Bool {
        let mag = magnitude(x: x, y: y, z: z, fullScale: fullScale)
        return abs(mag - 1.0) < restTolerance
    }
}
