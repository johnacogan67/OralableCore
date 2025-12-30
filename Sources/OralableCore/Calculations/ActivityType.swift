//
//  ActivityType.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Activity classification types for oral biometric monitoring
//

import Foundation

/// Types of oral activity detected from sensor data
public enum ActivityType: String, Codable, Sendable, CaseIterable {
    /// Normal relaxed state - no significant muscle activity
    case relaxed

    /// Clenching detected - sustained muscle contraction (low variance)
    case clenching

    /// Grinding detected - rhythmic muscle movement (high variance)
    case grinding

    /// Motion detected - device movement affecting readings
    case motion

    /// Human-readable description
    public var description: String {
        switch self {
        case .relaxed:
            return "Relaxed"
        case .clenching:
            return "Clenching"
        case .grinding:
            return "Grinding"
        case .motion:
            return "Motion"
        }
    }

    /// Whether this activity type indicates potential bruxism
    public var isBruxismIndicator: Bool {
        switch self {
        case .clenching, .grinding:
            return true
        case .relaxed, .motion:
            return false
        }
    }

    /// SF Symbol icon name for this activity type
    public var iconName: String {
        switch self {
        case .relaxed:
            return "face.smiling"
        case .clenching:
            return "face.dashed"
        case .grinding:
            return "waveform"
        case .motion:
            return "figure.walk"
        }
    }
}
