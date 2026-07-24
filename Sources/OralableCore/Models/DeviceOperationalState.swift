//
//  DeviceOperationalState.swift
//  OralableCore
//
//  App-facing operational state derived from firmware `009` status + placement mode.
//  Phase 0 vitals: no user calibration required.
//

import Foundation

/// High-level device state for dashboard / pilot UX.
public enum DeviceOperationalState: String, Sendable, Equatable {
    /// On Qi pad or explicit charger mode — red status LED policy on Gen1 FW >= 1.0.63.
    case onCharger
    /// Off body, bench / table — green status LED policy.
    case benchIdle
    /// On body (temple/cheek) — status LEDs off; PPG drives sensing.
    case onBody
    /// On body with sufficient PPG quality for HR / SpO2 display.
    case vitalsReady

    public var title: String {
        switch self {
        case .onCharger: return "On charger"
        case .benchIdle: return "Bench / idle"
        case .onBody: return "On body"
        case .vitalsReady: return "Vitals ready"
        }
    }

    public var detail: String {
        switch self {
        case .onCharger:
            return "Charging or on wireless pad. Streaming suppressed."
        case .benchIdle:
            return "Not worn. Place on charger or set Worn before vitals."
        case .onBody:
            return "Contact detected. Waiting for stable PPG signal."
        case .vitalsReady:
            return "Heart rate and SpO2 quality sufficient for display."
        }
    }
}

public extension TGMDeviceStatus {
    /// Derive operational state from firmware status and optional app placement override.
    ///
    /// - Parameters:
    ///   - userPlacementMode: App `FeatureFlags` value (0=auto, 1=charger, 2=idle, 3=worn).
    ///   - heartRateQuality: 0…1 from signal processor; nil if unavailable.
    ///   - spo2Quality: 0…1 from signal processor; nil if unavailable.
    ///   - vitalsQualityThreshold: Minimum quality for `.vitalsReady` (default 0.5).
    func operationalState(
        userPlacementMode: UInt8 = 0,
        heartRateQuality: Double? = nil,
        spo2Quality: Double? = nil,
        vitalsQualityThreshold: Double = 0.5
    ) -> DeviceOperationalState {
        if userPlacementMode == 1 || onDock {
            return .onCharger
        }
        if userPlacementMode == 2 && !worn {
            return .benchIdle
        }

        let onBody = worn || userPlacementMode == 3
        if !onBody {
            return .benchIdle
        }

        let hrOK = (heartRateQuality ?? 0) >= vitalsQualityThreshold
        let spo2OK = (spo2Quality ?? 0) >= vitalsQualityThreshold
        if hrOK && spo2OK {
            return .vitalsReady
        }
        return .onBody
    }
}
