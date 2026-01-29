//
//  StateTransitionEvent.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Represents a state transition event recorded when the device
//  changes between DataStreaming, Positioned, and Activity states.
//
//  Unlike the continuous sample-based MuscleActivityEvent, this event
//  captures the moment of state change with all relevant sensor data.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - State Transition Event

/// Represents a recorded state transition event
public struct StateTransitionEvent: Codable, Identifiable, Equatable, Sendable {

    // MARK: - Identification

    /// Unique identifier for this event
    public let id: UUID

    /// Timestamp when the state transition occurred
    public let timestamp: Date

    /// The state the device transitioned to
    public let state: DeviceRecordingState

    // MARK: - PPG Data

    /// Raw IR value at the time of transition
    public let irValue: Int

    /// Normalized IR as percentage above baseline (nil if not calibrated)
    public let normalizedIRPercent: Double?

    // MARK: - Biometric Data

    /// Heart rate in BPM (nil if not detected)
    public let heartRate: Double?

    /// Blood oxygen saturation percentage (nil if not detected)
    public let spO2: Double?

    /// Perfusion index as AC/DC ratio (nil if not calculated)
    public let perfusionIndex: Double?

    // MARK: - Environmental Data

    /// Temperature in Celsius
    public let temperature: Double

    // MARK: - Accelerometer Data

    /// Accelerometer X value (raw LSB)
    public let accelX: Int

    /// Accelerometer Y value (raw LSB)
    public let accelY: Int

    /// Accelerometer Z value (raw LSB)
    public let accelZ: Int

    // MARK: - Device Data

    /// Battery voltage in millivolts (nil if not available)
    public let batteryMV: Int?

    // MARK: - Calibration Data

    /// Baseline value used for normalization (nil if not calibrated)
    public let baseline: Double?

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        state: DeviceRecordingState,
        irValue: Int,
        normalizedIRPercent: Double? = nil,
        heartRate: Double? = nil,
        spO2: Double? = nil,
        perfusionIndex: Double? = nil,
        temperature: Double,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        batteryMV: Int? = nil,
        baseline: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.irValue = irValue
        self.normalizedIRPercent = normalizedIRPercent
        self.heartRate = heartRate
        self.spO2 = spO2
        self.perfusionIndex = perfusionIndex
        self.temperature = temperature
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
        self.batteryMV = batteryMV
        self.baseline = baseline
    }

    // MARK: - Display Properties

    #if canImport(SwiftUI)
    /// Color for this event based on state
    public var displayColor: Color {
        state.color
    }
    #endif

    /// Formatted timestamp for display
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// Formatted normalized IR for display
    public var formattedNormalizedIR: String {
        if let normalized = normalizedIRPercent {
            return String(format: "%.1f%%", normalized)
        }
        return "N/A"
    }

    /// Accelerometer magnitude in g-units
    public var accelerometerMagnitudeG: Double {
        // LIS2DTW12 at ±2g has 16384 LSB/g sensitivity
        let x = Double(accelX)
        let y = Double(accelY)
        let z = Double(accelZ)
        return sqrt(x*x + y*y + z*z) / 16384.0
    }
}

// MARK: - Array Extensions

public extension Array where Element == StateTransitionEvent {

    /// Filter events to a specific state
    func events(for state: DeviceRecordingState) -> [StateTransitionEvent] {
        filter { $0.state == state }
    }

    /// Count of events for each state
    var stateCounts: [DeviceRecordingState: Int] {
        var counts: [DeviceRecordingState: Int] = [:]
        for state in DeviceRecordingState.allCases {
            counts[state] = filter { $0.state == state }.count
        }
        return counts
    }

    /// Get events sorted by timestamp (oldest first)
    var sortedByTime: [StateTransitionEvent] {
        sorted { $0.timestamp < $1.timestamp }
    }

    /// Get the most recent event
    var mostRecent: StateTransitionEvent? {
        self.max(by: { $0.timestamp < $1.timestamp })
    }

    /// Get events within a time range
    func events(from startDate: Date, to endDate: Date) -> [StateTransitionEvent] {
        filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Calculate time spent in each state between events
    /// Returns dictionary of state to duration in seconds
    func timeInStates(endTime: Date = Date()) -> [DeviceRecordingState: TimeInterval] {
        var durations: [DeviceRecordingState: TimeInterval] = [:]
        for state in DeviceRecordingState.allCases {
            durations[state] = 0
        }

        let sorted = sortedByTime
        guard !sorted.isEmpty else { return durations }

        for i in 0..<sorted.count {
            let event = sorted[i]
            let nextTime: Date
            if i + 1 < sorted.count {
                nextTime = sorted[i + 1].timestamp
            } else {
                nextTime = endTime
            }

            let duration = nextTime.timeIntervalSince(event.timestamp)
            durations[event.state, default: 0] += duration
        }

        return durations
    }
}
