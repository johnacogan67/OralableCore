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
/// Note: Named CoreVersion (not OralableCore) to avoid shadowing the module name
public enum CoreVersion {
    /// Current version of the OralableCore package
    public static let version = "1.0.0"

    /// Build date
    public static let buildDate = "2025-12-30"
}

// MARK: - Legacy Compatibility

/// Legacy alias for backwards compatibility
/// @available(*, deprecated, renamed: "CoreVersion")
public typealias OralableCoreVersion = CoreVersion
