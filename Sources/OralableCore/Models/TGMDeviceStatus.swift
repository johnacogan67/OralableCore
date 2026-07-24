//
//  TGMDeviceStatus.swift
//  OralableCore
//
//  Device status from firmware characteristic 3A0FF009 (tgm_service_status_t).
//

import Foundation

/// Status payload from Oralable nRF firmware.
///
/// Legacy 4-byte packets (FW < 1.0.47): byte 0 was misnamed `charging` (meant on-dock).
/// Current 5-byte layout (FW >= 1.0.47):
///   byte 0 on_dock, byte 1 worn, byte 2 device_state, byte 3 battery_pct, byte 4 charge_active
public struct TGMDeviceStatus: Sendable, Equatable {
    /// Clip seated on charging dock (`chrsts` GPIO).
    public let onDock: Bool
    /// Cell voltage rising on dock (inferred from trend; not charge-current hardware).
    public let chargeActive: Bool
    public let worn: Bool
    /// Firmware `device_state_t` (0 = off dock, 1 = on dock, 2 = worn).
    public let deviceState: UInt8
    public let batteryPercent: UInt8
    public let receivedAt: Date

    public init(
        onDock: Bool,
        chargeActive: Bool,
        worn: Bool,
        deviceState: UInt8,
        batteryPercent: UInt8,
        receivedAt: Date = Date()
    ) {
        self.onDock = onDock
        self.chargeActive = chargeActive
        self.worn = worn
        self.deviceState = deviceState
        self.batteryPercent = batteryPercent
        self.receivedAt = receivedAt
    }
}
