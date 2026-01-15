//
//  DetectionMode.swift
//  OralableCore
//
//  Created: January 13, 2026
//  Updated: January 15, 2026 - Simplified to normalized-only detection
//
//  Detection is always normalized (percentage above calibrated baseline).
//

import Foundation

/// Detection mode - always normalized
/// Kept as enum for API compatibility, but only .normalized is available
public enum DetectionMode: String, Codable, CaseIterable, Sendable {
    /// Percentage above calibrated baseline (e.g., 40%)
    case normalized = "Normalized"

    public var displayName: String {
        "Normalized"
    }

    public var description: String {
        "Uses percentage above your baseline. Works consistently across users."
    }

    /// Always requires calibration
    public var requiresCalibration: Bool {
        true
    }
}
