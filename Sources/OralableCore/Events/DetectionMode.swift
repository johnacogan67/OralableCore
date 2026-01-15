//
//  DetectionMode.swift
//  OralableCore
//
//  Created: January 13, 2026
//
//  Detection mode for event detection threshold comparison.
//

import Foundation

/// Detection mode for event threshold comparison
public enum DetectionMode: String, Codable, CaseIterable, Sendable {
    /// Fixed absolute threshold value (e.g., 150,000)
    case absolute = "Absolute"

    /// Percentage above calibrated baseline (e.g., 40%)
    case normalized = "Normalized"

    public var displayName: String {
        switch self {
        case .absolute:
            return "Absolute (Fixed)"
        case .normalized:
            return "Normalized (Recommended)"
        }
    }

    public var description: String {
        switch self {
        case .absolute:
            return "Uses a fixed threshold value. May need adjustment for different users."
        case .normalized:
            return "Uses percentage above your baseline. Works consistently across users."
        }
    }

    public var requiresCalibration: Bool {
        self == .normalized
    }
}
