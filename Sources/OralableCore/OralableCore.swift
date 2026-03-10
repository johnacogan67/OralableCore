//
//  OralableCore.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Purpose: Shared data models, CSV handling, and biometric calculations
//           for Oralable consumer and professional apps.
//

import Foundation

/// OralableCore package version information
public enum OralableCore {
    /// Current version of the OralableCore package
    public static let version = "1.0.0"

    /// Build date (ISO 8601)
    public static let buildDate: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }()
}

// MARK: - Legacy Compatibility

/// Legacy alias for backwards compatibility
public typealias CoreVersion = OralableCore

/// Legacy alias for backwards compatibility
/// @available(*, deprecated, renamed: "OralableCore")
public typealias OralableCoreVersion = OralableCore
