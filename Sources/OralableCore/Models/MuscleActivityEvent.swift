//
//  MuscleActivityEvent.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 15, 2026 - Added validation-based coloring (valid=green, invalid=black)
//
//  Represents a single muscle activity event detected by threshold crossing.
//
//  Event Types:
//  - Activity: PPG IR above threshold (muscle contraction)
//  - Rest: PPG IR below threshold (muscle relaxation)
//
//  Validation Coloring:
//  - Valid events (biometric data present): Green
//  - Invalid events (no biometric data in window): Black
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Event Type

/// Type of muscle activity event
public enum EventType: String, Codable, CaseIterable, Sendable {
    case activity = "Activity"  // IR above threshold
    case rest = "Rest"          // IR below threshold

    #if canImport(SwiftUI)
    /// Legacy color for event type (deprecated - use MuscleActivityEvent.displayColor instead)
    public var color: Color {
        switch self {
        case .activity:
            return .red
        case .rest:
            return .green
        }
    }
    #endif
}

// MARK: - Sleep State

/// Sleep state during event
public enum SleepState: String, Codable, CaseIterable, Sendable {
    case awake = "Awake"
    case likelySleeping = "Likely_Sleeping"
    case unknown = "Unknown"

    public var isValid: Bool {
        self != .unknown
    }
}

// MARK: - Muscle Activity Event

/// Represents a single detected muscle activity event
public struct MuscleActivityEvent: Codable, Identifiable, Equatable, Sendable {

    // MARK: - Identification

    public let id: UUID
    public let eventNumber: Int
    public let eventType: EventType

    // MARK: - Timing

    public let startTimestamp: Date
    public let endTimestamp: Date

    /// Duration in milliseconds
    public var durationMs: Int {
        Int((endTimestamp.timeIntervalSince(startTimestamp)) * 1000)
    }

    /// Duration as formatted string
    public var formattedDuration: String {
        let ms = durationMs
        if ms < 1000 {
            return "\(ms)ms"
        } else if ms < 60000 {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        } else {
            let minutes = ms / 60000
            let seconds = (ms % 60000) / 1000
            return "\(minutes)m \(seconds)s"
        }
    }

    // MARK: - Raw PPG IR Values

    public let startIR: Int
    public let endIR: Int
    public let averageIR: Double

    // MARK: - Normalized Values (percentage above baseline)

    /// Normalized start IR (percentage above baseline)
    public let normalizedStartIR: Double?

    /// Normalized end IR (percentage above baseline)
    public let normalizedEndIR: Double?

    /// Normalized average IR (percentage above baseline)
    public let normalizedAverageIR: Double?

    /// Baseline used for normalization
    public let baseline: Double?

    // MARK: - Accelerometer Context

    public let accelX: Int
    public let accelY: Int
    public let accelZ: Int

    /// Accelerometer magnitude
    public var accelMagnitude: Double {
        sqrt(Double(accelX * accelX + accelY * accelY + accelZ * accelZ))
    }

    // MARK: - Temperature

    public let temperature: Double

    // MARK: - Calculated Metrics

    public let heartRate: Double?
    public let spO2: Double?
    public let sleepState: SleepState?

    // MARK: - Validation

    /// Whether this event has valid biometric data in the validation window
    public let isValid: Bool

    // MARK: - Display Properties

    #if canImport(SwiftUI)
    /// Color for chart display based on validation status
    /// Uses ColorSystem for consistent styling across apps
    /// - Valid events: Green
    /// - Invalid events: Black
    public var displayColor: Color {
        let colors = DesignSystem.shared.colors
        return isValid ? colors.eventValid : colors.eventInvalid
    }

    /// Color with opacity for chart display
    public var displayColorWithOpacity: Color {
        let colors = DesignSystem.shared.colors
        if isValid {
            return colors.eventValid.opacity(colors.eventValidOpacity)
        } else {
            return colors.eventInvalid.opacity(colors.eventInvalidOpacity)
        }
    }

    /// Opacity value for chart display
    public var displayOpacity: Double {
        let colors = DesignSystem.shared.colors
        return isValid ? colors.eventValidOpacity : colors.eventInvalidOpacity
    }
    #endif

    /// Validation status description
    public var validationDescription: String {
        isValid ? "Valid" : "Invalid"
    }

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        eventNumber: Int,
        eventType: EventType,
        startTimestamp: Date,
        endTimestamp: Date,
        startIR: Int,
        endIR: Int,
        averageIR: Double,
        normalizedStartIR: Double? = nil,
        normalizedEndIR: Double? = nil,
        normalizedAverageIR: Double? = nil,
        baseline: Double? = nil,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double,
        heartRate: Double? = nil,
        spO2: Double? = nil,
        sleepState: SleepState? = nil,
        isValid: Bool = true
    ) {
        self.id = id
        self.eventNumber = eventNumber
        self.eventType = eventType
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.startIR = startIR
        self.endIR = endIR
        self.averageIR = averageIR
        self.normalizedStartIR = normalizedStartIR
        self.normalizedEndIR = normalizedEndIR
        self.normalizedAverageIR = normalizedAverageIR
        self.baseline = baseline
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.temperature = temperature
        self.heartRate = heartRate
        self.spO2 = spO2
        self.sleepState = sleepState
        self.isValid = isValid
    }
}

// MARK: - Array Extension

public extension Array where Element == MuscleActivityEvent {

    /// Filter to valid events only
    var validEvents: [MuscleActivityEvent] {
        filter { $0.isValid }
    }

    /// Filter to invalid events only
    var invalidEvents: [MuscleActivityEvent] {
        filter { !$0.isValid }
    }

    /// Count of valid events
    var validCount: Int {
        filter { $0.isValid }.count
    }

    /// Count of invalid events
    var invalidCount: Int {
        filter { !$0.isValid }.count
    }

    /// Activity events (regardless of validation)
    var activityEvents: [MuscleActivityEvent] {
        filter { $0.eventType == .activity }
    }

    /// Rest events (regardless of validation)
    var restEvents: [MuscleActivityEvent] {
        filter { $0.eventType == .rest }
    }
}
