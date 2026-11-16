//
//  SensorCorroboration.swift
//  OralableCore
//
//  Soft skin-temperature + accelerometer corroboration for vitals quality
//  and on-body gating. Matches EventDetector skin range (32–38 °C).
//  Missing / NaN temperature is treated as unknown → do not block (Mac parity).
//

import Foundation

/// Soft corroboration helpers for ACC + skin temperature.
public enum SensorCorroboration: Sendable {

    /// Match `EventDetector.validTemperatureMin`.
    public static let skinTempMinC: Double = 32.0
    /// Match `EventDetector.validTemperatureMax`.
    public static let skinTempMaxC: Double = 38.0

    /// Quality scale when motion exceeds threshold (vitals still computed).
    public static let highMotionQualityMultiplier: Double = 0.3

    /// Whether temperature suggests the clip is on skin.
    /// - Returns `true` when temperature is missing/NaN (unknown → allow).
    /// - Returns `false` when finite and outside `[skinTempMinC, skinTempMaxC]`.
    public static func isLikelyOnSkin(temperatureC: Double?) -> Bool {
        guard let temperatureC, temperatureC.isFinite else { return true }
        return temperatureC >= skinTempMinC && temperatureC <= skinTempMaxC
    }

    /// Convenience for sample streams that use `.nan` for missing temp.
    public static func isLikelyOnSkin(temperatureC: Double) -> Bool {
        isLikelyOnSkin(temperatureC: temperatureC as Double?)
    }

    /// Multiplier for HR / SpO₂ *quality* (not the numeric SpO₂/HR values).
    /// - Off-skin with a present temperature → `0`
    /// - High motion → `highMotionQualityMultiplier`
    /// - Otherwise → `1`
    public static func vitalsQualityMultiplier(
        temperatureC: Double?,
        motionLevel: Double,
        motionThreshold: Double
    ) -> Double {
        guard isLikelyOnSkin(temperatureC: temperatureC) else { return 0 }
        if motionLevel.isFinite, motionThreshold.isFinite, motionLevel > motionThreshold {
            return highMotionQualityMultiplier
        }
        return 1.0
    }
}
