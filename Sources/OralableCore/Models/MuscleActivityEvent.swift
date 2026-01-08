//
//  MuscleActivityEvent.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Represents a single muscle activity event detected when PPG IR crosses threshold
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Type of muscle activity event
public enum EventType: String, Codable, Sendable {
    case activity = "Activity"  // IR above threshold
    case rest = "Rest"          // IR below threshold

    #if canImport(SwiftUI)
    /// Color for graphing in iOS app
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

/// Represents a single muscle activity event detected when PPG IR crosses threshold
public struct MuscleActivityEvent: Codable, Identifiable, Sendable {

    // MARK: - Identification

    public let id: UUID
    public let eventNumber: Int

    // MARK: - Event Type

    public let eventType: EventType

    // MARK: - Timing

    public let startTimestamp: Date
    public let endTimestamp: Date

    /// Duration of event in milliseconds
    public var durationMs: Int {
        Int((endTimestamp.timeIntervalSince(startTimestamp)) * 1000)
    }

    // MARK: - PPG IR Values

    public let startIR: Int
    public let endIR: Int
    public let averageIR: Double

    // MARK: - Context (nearest to event start)

    public let accelX: Int
    public let accelY: Int
    public let accelZ: Int
    public let temperature: Double

    // MARK: - Calculated Metrics (optional in export)

    public let heartRate: Double?
    public let spO2: Double?
    public let sleepState: SleepState?

    // MARK: - Validation

    public let isValid: Bool

    public init(
        id: UUID = UUID(),
        eventNumber: Int,
        eventType: EventType,
        startTimestamp: Date,
        endTimestamp: Date,
        startIR: Int,
        endIR: Int,
        averageIR: Double,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double,
        heartRate: Double?,
        spO2: Double?,
        sleepState: SleepState?,
        isValid: Bool
    ) {
        self.id = id
        self.eventNumber = eventNumber
        self.eventType = eventType
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.startIR = startIR
        self.endIR = endIR
        self.averageIR = averageIR
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

/// Sleep state enumeration for event validation and export
public enum SleepState: String, Codable, Sendable {
    case awake = "Awake"
    case likelySleeping = "Likely_Sleeping"
    case unknown = "Unknown"

    public var isValid: Bool {
        self != .unknown
    }
}
