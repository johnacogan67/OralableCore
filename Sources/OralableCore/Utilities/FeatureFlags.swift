//
//  FeatureFlags.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic feature flags system
//

import Foundation
import Combine

// MARK: - Feature Flag Storage Protocol

/// Protocol for persisting feature flags
/// Apps implement this to provide their own storage mechanism (UserDefaults, etc.)
public protocol FeatureFlagStorage: AnyObject, Sendable {
    /// Load a boolean flag value
    func loadBool(for key: String) -> Bool?

    /// Save a boolean flag value
    func saveBool(_ value: Bool, for key: String)

    /// Load all stored flag values
    func loadAll() -> [String: Bool]

    /// Clear all stored flags
    func clearAll()
}

// MARK: - Feature Flag

/// Individual feature flag definition
public struct FeatureFlag: Hashable, Sendable {
    /// Unique key for the flag
    public let key: String

    /// Human-readable name
    public let name: String

    /// Description of what the flag controls
    public let description: String

    /// Default value when not set
    public let defaultValue: Bool

    /// Category for grouping flags
    public let category: FeatureFlagCategory

    /// Whether this flag can be changed at runtime
    public let isUserConfigurable: Bool

    public init(
        key: String,
        name: String,
        description: String,
        defaultValue: Bool,
        category: FeatureFlagCategory = .general,
        isUserConfigurable: Bool = true
    ) {
        self.key = key
        self.name = name
        self.description = description
        self.defaultValue = defaultValue
        self.category = category
        self.isUserConfigurable = isUserConfigurable
    }
}

// MARK: - Feature Flag Category

/// Categories for organizing feature flags
public enum FeatureFlagCategory: String, CaseIterable, Sendable {
    case general
    case bluetooth
    case sensors
    case recording
    case export
    case ui
    case debug
    case experimental

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Feature Flags Manager

/// Thread-safe feature flags manager
/// Configure with your own FeatureFlagStorage implementation for persistence
public final class FeatureFlags: @unchecked Sendable {

    // MARK: - Shared Instance

    /// Shared feature flags instance
    public static let shared = FeatureFlags()

    // MARK: - Properties

    /// Storage provider (optional - flags work in-memory without it)
    private var storage: FeatureFlagStorage?

    /// In-memory flag values
    private var flagValues: [String: Bool] = [:]

    /// Registered flags
    private var registeredFlags: [String: FeatureFlag] = [:]

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.oralable.core.featureflags", qos: .userInitiated)

    /// Publisher for flag changes
    private let flagChangedSubject = PassthroughSubject<(String, Bool), Never>()

    /// Publisher for observing flag changes
    public var flagChanged: AnyPublisher<(String, Bool), Never> {
        flagChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configure with a storage provider
    public func configure(storage: FeatureFlagStorage) {
        queue.sync {
            self.storage = storage
            // Load persisted values
            let stored = storage.loadAll()
            for (key, value) in stored {
                flagValues[key] = value
            }
        }
    }

    /// Register a feature flag
    public func register(_ flag: FeatureFlag) {
        queue.sync {
            registeredFlags[flag.key] = flag
            // Set default value if not already set
            if flagValues[flag.key] == nil {
                flagValues[flag.key] = flag.defaultValue
            }
        }
    }

    /// Register multiple flags at once
    public func register(_ flags: [FeatureFlag]) {
        for flag in flags {
            register(flag)
        }
    }

    // MARK: - Flag Access

    /// Check if a flag is enabled
    public func isEnabled(_ key: String) -> Bool {
        queue.sync {
            if let value = flagValues[key] {
                return value
            }
            if let flag = registeredFlags[key] {
                return flag.defaultValue
            }
            return false
        }
    }

    /// Check if a flag is enabled (using FeatureFlag)
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        isEnabled(flag.key)
    }

    /// Set a flag value
    public func setEnabled(_ key: String, _ value: Bool) {
        queue.sync {
            let flag = registeredFlags[key]
            guard flag?.isUserConfigurable != false else {
                Logger.shared.warning("Attempted to modify non-configurable flag: \(key)")
                return
            }

            flagValues[key] = value
            storage?.saveBool(value, for: key)
        }
        flagChangedSubject.send((key, value))
    }

    /// Set a flag value (using FeatureFlag)
    public func setEnabled(_ flag: FeatureFlag, _ value: Bool) {
        setEnabled(flag.key, value)
    }

    /// Toggle a flag
    public func toggle(_ key: String) {
        let current = isEnabled(key)
        setEnabled(key, !current)
    }

    /// Get all registered flags
    public func allFlags() -> [FeatureFlag] {
        queue.sync {
            Array(registeredFlags.values)
        }
    }

    /// Get flags by category
    public func flags(in category: FeatureFlagCategory) -> [FeatureFlag] {
        allFlags().filter { $0.category == category }
    }

    /// Get current values for all flags
    public func currentValues() -> [String: Bool] {
        queue.sync {
            var values: [String: Bool] = [:]
            for flag in registeredFlags.values {
                values[flag.key] = flagValues[flag.key] ?? flag.defaultValue
            }
            return values
        }
    }

    // MARK: - Presets

    /// Apply a preset configuration
    public func applyPreset(_ preset: FeatureFlagPreset) {
        for (key, value) in preset.values {
            setEnabled(key, value)
        }
        Logger.shared.info("Applied feature flag preset: \(preset.name)")
    }

    /// Reset all flags to defaults
    public func resetToDefaults() {
        queue.sync {
            flagValues.removeAll()
            for flag in registeredFlags.values {
                flagValues[flag.key] = flag.defaultValue
            }
            storage?.clearAll()
        }
        Logger.shared.info("Reset all feature flags to defaults")
    }
}

// MARK: - Feature Flag Preset

/// A preset configuration of feature flags
public struct FeatureFlagPreset: Sendable {
    /// Name of the preset
    public let name: String

    /// Description of when to use this preset
    public let description: String

    /// Flag values in this preset
    public let values: [String: Bool]

    public init(name: String, description: String, values: [String: Bool]) {
        self.name = name
        self.description = description
        self.values = values
    }
}

// MARK: - Common Feature Flags

/// Common feature flags used by OralableCore
public extension FeatureFlag {

    // MARK: - Bluetooth

    static let autoReconnect = FeatureFlag(
        key: "bluetooth.autoReconnect",
        name: "Auto Reconnect",
        description: "Automatically reconnect to devices on disconnect",
        defaultValue: true,
        category: .bluetooth
    )

    static let backgroundScanning = FeatureFlag(
        key: "bluetooth.backgroundScanning",
        name: "Background Scanning",
        description: "Continue scanning for devices in background",
        defaultValue: false,
        category: .bluetooth
    )

    // MARK: - Sensors

    static let heartRateEnabled = FeatureFlag(
        key: "sensors.heartRate",
        name: "Heart Rate",
        description: "Enable heart rate calculation from PPG",
        defaultValue: true,
        category: .sensors
    )

    static let spo2Enabled = FeatureFlag(
        key: "sensors.spo2",
        name: "SpO2",
        description: "Enable SpO2 calculation from PPG",
        defaultValue: true,
        category: .sensors
    )

    static let motionCompensation = FeatureFlag(
        key: "sensors.motionCompensation",
        name: "Motion Compensation",
        description: "Apply LMS filtering for motion artifacts",
        defaultValue: true,
        category: .sensors
    )

    // MARK: - Recording

    static let autoStartRecording = FeatureFlag(
        key: "recording.autoStart",
        name: "Auto-Start Recording",
        description: "Start recording when device connects",
        defaultValue: false,
        category: .recording
    )

    static let continuousRecording = FeatureFlag(
        key: "recording.continuous",
        name: "Continuous Recording",
        description: "Record data continuously without manual start",
        defaultValue: false,
        category: .recording
    )

    // MARK: - Export

    static let includeRawData = FeatureFlag(
        key: "export.includeRaw",
        name: "Include Raw Data",
        description: "Include raw sensor values in exports",
        defaultValue: true,
        category: .export
    )

    static let compressExports = FeatureFlag(
        key: "export.compress",
        name: "Compress Exports",
        description: "Compress export files (ZIP)",
        defaultValue: false,
        category: .export
    )

    // MARK: - Debug

    static let verboseLogging = FeatureFlag(
        key: "debug.verboseLogging",
        name: "Verbose Logging",
        description: "Enable detailed debug logging",
        defaultValue: false,
        category: .debug
    )

    static let mockSensorData = FeatureFlag(
        key: "debug.mockData",
        name: "Mock Sensor Data",
        description: "Generate simulated sensor data",
        defaultValue: false,
        category: .debug,
        isUserConfigurable: false
    )

    // MARK: - All Common Flags

    static let allCommon: [FeatureFlag] = [
        .autoReconnect,
        .backgroundScanning,
        .heartRateEnabled,
        .spo2Enabled,
        .motionCompensation,
        .autoStartRecording,
        .continuousRecording,
        .includeRawData,
        .compressExports,
        .verboseLogging,
        .mockSensorData
    ]
}

// MARK: - Common Presets

public extension FeatureFlagPreset {

    /// Full-featured configuration
    static let full = FeatureFlagPreset(
        name: "Full",
        description: "All features enabled",
        values: [
            "bluetooth.autoReconnect": true,
            "bluetooth.backgroundScanning": true,
            "sensors.heartRate": true,
            "sensors.spo2": true,
            "sensors.motionCompensation": true,
            "recording.autoStart": false,
            "recording.continuous": false,
            "export.includeRaw": true,
            "export.compress": false,
            "debug.verboseLogging": false
        ]
    )

    /// Minimal configuration for basic functionality
    static let minimal = FeatureFlagPreset(
        name: "Minimal",
        description: "Basic features only",
        values: [
            "bluetooth.autoReconnect": true,
            "bluetooth.backgroundScanning": false,
            "sensors.heartRate": true,
            "sensors.spo2": false,
            "sensors.motionCompensation": false,
            "recording.autoStart": false,
            "recording.continuous": false,
            "export.includeRaw": false,
            "export.compress": false,
            "debug.verboseLogging": false
        ]
    )

    /// Research/clinical configuration
    static let research = FeatureFlagPreset(
        name: "Research",
        description: "Full data collection for research",
        values: [
            "bluetooth.autoReconnect": true,
            "bluetooth.backgroundScanning": true,
            "sensors.heartRate": true,
            "sensors.spo2": true,
            "sensors.motionCompensation": true,
            "recording.autoStart": true,
            "recording.continuous": true,
            "export.includeRaw": true,
            "export.compress": true,
            "debug.verboseLogging": true
        ]
    )

    /// Debug configuration
    static let debug = FeatureFlagPreset(
        name: "Debug",
        description: "Configuration for debugging",
        values: [
            "bluetooth.autoReconnect": false,
            "bluetooth.backgroundScanning": false,
            "sensors.heartRate": true,
            "sensors.spo2": true,
            "sensors.motionCompensation": true,
            "recording.autoStart": false,
            "recording.continuous": false,
            "export.includeRaw": true,
            "export.compress": false,
            "debug.verboseLogging": true
        ]
    )
}
