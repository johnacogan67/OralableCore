//
//  QualityLevel.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared quality level enumeration for sensor measurements
//

import Foundation

/// Quality level classification for sensor measurements
public enum QualityLevel: String, Codable, Sendable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case acceptable = "Acceptable"
    case poor = "Poor"

    /// Human-readable description
    public var description: String {
        return rawValue
    }

    /// Minimum quality threshold for this level
    public var minimumThreshold: Double {
        switch self {
        case .excellent:
            return 0.9
        case .good:
            return 0.8
        case .fair:
            return 0.7
        case .acceptable:
            return 0.6
        case .poor:
            return 0.0
        }
    }

    /// Color name for UI representation
    public var color: String {
        switch self {
        case .excellent, .good:
            return "green"
        case .fair:
            return "yellow"
        case .acceptable:
            return "orange"
        case .poor:
            return "red"
        }
    }
}
