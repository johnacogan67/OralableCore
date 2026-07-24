//
//  DeviceStatusLED.swift
//  OralableCore
//
//  Mirrors firmware battery_led_indicator.c policy for Phase 0 vitals UX.
//

import Foundation

/// Color channel used for off-body status indication (PPG green/red LEDs).
public enum DeviceStatusLEDColor: String, Sendable, Equatable {
    case red
    case green
    case none
}

/// Solid, flashing, or off (worn / PPG sensing).
public enum DeviceStatusLEDPattern: String, Sendable, Equatable {
    case solid
    case flashing
    case off
}

/// App-facing mirror of on-device status LED policy.
public struct DeviceStatusLEDRepresentation: Sendable, Equatable {
    public let color: DeviceStatusLEDColor
    public let pattern: DeviceStatusLEDPattern
    public let accessibilityLabel: String
    public let detail: String

    public init(
        color: DeviceStatusLEDColor,
        pattern: DeviceStatusLEDPattern,
        accessibilityLabel: String,
        detail: String
    ) {
        self.color = color
        self.pattern = pattern
        self.accessibilityLabel = accessibilityLabel
        self.detail = detail
    }
}

public enum DeviceStatusLEDPolicy {
    /// Matches `BATTERY_LED_FULL_THRESHOLD_PCT` in firmware.
    public static let fullThresholdPercent: UInt8 = 80
    /// Matches `BATTERY_TRULY_FULL_MV` in firmware.
    public static let trulyFullMillivolts: Int32 = 4320
}

public extension TGMDeviceStatus {
    /// Mirror firmware `battery_led_indicator_apply()` using status notify fields.
    ///
    /// FW ≥ 1.0.70 on-dock LEDs follow `chargeActive` (STAT blink → flash; taper → solid).
    /// Off-dock green still uses optional Vmax for solid-vs-flash when pct > 80%.
    ///
    /// - Parameters:
    ///   - userPlacementMode: App placement override (0=auto, 1=charger, 2=idle, 3=worn).
    ///   - batteryMillivolts: Optional GATT battery mV for off-dock solid green when pct > 80%.
    func statusLED(
        userPlacementMode: UInt8 = 0,
        batteryMillivolts: Int32? = nil
    ) -> DeviceStatusLEDRepresentation {
        if worn || userPlacementMode == 3 {
            return DeviceStatusLEDRepresentation(
                color: .none,
                pattern: .off,
                accessibilityLabel: "Status LED off",
                detail: "On body — PPG sensing active."
            )
        }

        let onDockEffective = userPlacementMode == 1 || onDock
        let trulyFull: Bool
        if let batteryMillivolts {
            trulyFull = batteryMillivolts >= DeviceStatusLEDPolicy.trulyFullMillivolts
        } else {
            trulyFull = false
        }
        let full = batteryPercent > DeviceStatusLEDPolicy.fullThresholdPercent && trulyFull

        if onDockEffective {
            // FW >= 1.0.70: LTC4124 STAT blink → flash red; STAT taper → solid red.
            if chargeActive {
                return DeviceStatusLEDRepresentation(
                    color: .red,
                    pattern: .flashing,
                    accessibilityLabel: "Flashing red status LED",
                    detail: "On charger — charging (STAT blink)."
                )
            }
            return DeviceStatusLEDRepresentation(
                color: .red,
                pattern: .solid,
                accessibilityLabel: "Solid red status LED",
                detail: full
                    ? "On charger — charge hold / full."
                    : "On charger — charge taper (STAT steady)."
            )
        }

        if full {
            return DeviceStatusLEDRepresentation(
                color: .green,
                pattern: .solid,
                accessibilityLabel: "Solid green status LED",
                detail: "Off charger — battery full."
            )
        }

        return DeviceStatusLEDRepresentation(
            color: .green,
            pattern: .flashing,
            accessibilityLabel: "Flashing green status LED",
            detail: "Off charger — below full."
        )
    }
}
