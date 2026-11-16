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
///
/// Firmware hold on the pad is a rare green pulse (not a continuous LED).
/// The app still uses `.solid` for that "charged / hold" meaning.
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
    /// Matches `BATTERY_LED_FULL_THRESHOLD_PCT` in firmware (on-pad SOC clamp).
    public static let fullThresholdPercent: UInt8 = 80
    /// Matches `BATTERY_LED_HOLD_GREEN_PCT` — enter hold LED (~4.20 V).
    public static let holdGreenPercent: UInt8 = 80
    /// Matches `BATTERY_LED_HOLD_GREEN_MV`.
    public static let holdGreenMillivolts: Int32 = 4200
    /// Matches `BATTERY_LED_HOLD_GREEN_EXIT_PCT` (firmware hysteresis).
    public static let holdGreenExitPercent: UInt8 = 75
    /// Matches `BATTERY_LED_HOLD_GREEN_EXIT_MV`.
    public static let holdGreenExitMillivolts: Int32 = 4150
    /// Legacy Vmax gate; not used for status LEDs.
    public static let trulyFullMillivolts: Int32 = 4320
}

public extension TGMDeviceStatus {
    /// Mirror firmware `battery_led_indicator_apply()` using status notify fields.
    ///
    /// Status LEDs are green-only (never red). FW ≥ 1.0.71: no status LED while BLE
    /// is connected (optics are PPG-only). Disconnected on-dock: flash green while
    /// below hold SOC/voltage (charging or early STAT taper). Hold (app `.solid`,
    /// clip: rare green pulse) only when SOC/voltage is in hold. STAT taper alone
    /// is not full.
    /// FW ≥ 1.0.72: off-dock and placement mode 2 stay dark.
    ///
    /// - Parameters:
    ///   - userPlacementMode: App placement override (0=auto, 1=charger, 2=idle, 3=worn).
    ///   - batteryMillivolts: Used to enter hold at/above hold voltage.
    ///   - bleConnected: True when a central is linked — status LED off on the MAM.
    func statusLED(
        userPlacementMode: UInt8 = 0,
        batteryMillivolts: Int32? = nil,
        bleConnected: Bool = false
    ) -> DeviceStatusLEDRepresentation {
        if bleConnected {
            return DeviceStatusLEDRepresentation(
                color: .none,
                pattern: .off,
                accessibilityLabel: "Status LED off",
                detail: "Connected — no status LED. Optical LEDs are PPG-only."
            )
        }

        let onDockEffective = userPlacementMode == 1 || (userPlacementMode != 2 && onDock)

        if onDockEffective {
            let holdByPercent = batteryPercent >= DeviceStatusLEDPolicy.holdGreenPercent
            let holdByVoltage = (batteryMillivolts ?? 0) >= DeviceStatusLEDPolicy.holdGreenMillivolts
            if holdByPercent || holdByVoltage {
                return DeviceStatusLEDRepresentation(
                    color: .green,
                    pattern: .solid,
                    accessibilityLabel: "Hold green status LED",
                    detail: "On Oralable case — hold (brief green pulse; cell in hold range)."
                )
            }
            return DeviceStatusLEDRepresentation(
                color: .green,
                pattern: .flashing,
                accessibilityLabel: "Flashing green status LED",
                detail: "On Oralable case — charging, or taper below hold voltage."
            )
        }

        return DeviceStatusLEDRepresentation(
            color: .none,
            pattern: .off,
            accessibilityLabel: "Status LED off",
            detail: "Off case — no status LED."
        )
    }
}
