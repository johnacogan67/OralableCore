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
    /// On Oralable case or explicit charger mode — green status LED only when BLE is down.
    case onCharger
    /// Off body, bench / table — green status LED only when BLE is down.
    case benchIdle
    /// On body (temple) — status LEDs off; PPG drives sensing while linked.
    case onBody
    /// On body with sufficient PPG quality for HR / SpO2 display.
    case vitalsReady

    public var title: String {
        switch self {
            case .onCharger: return "On Oralable case"
            case .benchIdle: return "Off case"
            case .onBody: return "On temple"
            case .vitalsReady: return "Vitals ready"
        }
    }

    public var detail: String {
        switch self {
        case .onCharger:
            return "On the Oralable case. Sensors off. Clip LED off while linked."
        case .benchIdle:
            return "Not worn. Place on the Oralable case or set Worn on temple."
        case .onBody:
            return "Pad or tape on the temple. Waiting for stable PPG."
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
