//
//  EventDetector.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Detects muscle activity events when PPG IR crosses threshold
//  Events alternate between Activity (above threshold) and Rest (below threshold)
//

import Foundation

/// Detects muscle activity events when PPG IR crosses threshold
public class EventDetector {

    // MARK: - Configuration

    public var threshold: Int
    public let validationWindowSeconds: TimeInterval = 180 // 3 minutes

    // MARK: - Temperature Validation Range

    public static let validTemperatureMin: Double = 32.0
    public static let validTemperatureMax: Double = 38.0

    // MARK: - State

    private var currentEventType: EventType?
    private var eventStartTimestamp: Date?
    private var eventStartIR: Int?
    private var eventIRValues: [Int] = []
    private var eventStartAccel: (x: Int, y: Int, z: Int)?
    private var eventStartTemperature: Double?
    private var eventCounter: Int = 0
    private var discardedEventCounter: Int = 0

    // MARK: - Metric History (for validation)

    private var hrHistory: [(timestamp: Date, value: Double)] = []
    private var spO2History: [(timestamp: Date, value: Double)] = []
    private var sleepHistory: [(timestamp: Date, state: SleepState)] = []
    private var temperatureHistory: [(timestamp: Date, value: Double)] = []

    // MARK: - Output

    public var onEventDetected: ((MuscleActivityEvent) -> Void)?
    public var onEventDiscarded: ((MuscleActivityEvent) -> Void)?

    // MARK: - Init

    public init(threshold: Int = 150000) {
        self.threshold = threshold
    }

    // MARK: - Metric Updates (call these continuously)

    /// Update heart rate value for validation
    /// - Parameters:
    ///   - value: Heart rate in BPM
    ///   - timestamp: When the measurement was taken
    public func updateHR(_ value: Double, at timestamp: Date) {
        if value > 0 {
            hrHistory.append((timestamp, value))
            pruneHistory()
        }
    }

    /// Update SpO2 value for validation
    /// - Parameters:
    ///   - value: SpO2 percentage
    ///   - timestamp: When the measurement was taken
    public func updateSpO2(_ value: Double, at timestamp: Date) {
        if value > 0 {
            spO2History.append((timestamp, value))
            pruneHistory()
        }
    }

    /// Update sleep state for validation
    /// - Parameters:
    ///   - state: Current sleep state
    ///   - timestamp: When the state was determined
    public func updateSleep(_ state: SleepState, at timestamp: Date) {
        if state.isValid {
            sleepHistory.append((timestamp, state))
            pruneHistory()
        }
    }

    /// Update temperature for validation
    /// Only stores values in valid range (32-38°C indicates device on skin)
    /// - Parameters:
    ///   - value: Temperature in Celsius
    ///   - timestamp: When the measurement was taken
    public func updateTemperature(_ value: Double, at timestamp: Date) {
        if value >= Self.validTemperatureMin && value <= Self.validTemperatureMax {
            temperatureHistory.append((timestamp, value))
            pruneHistory()
        }
    }

    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-validationWindowSeconds - 60) // Keep extra buffer
        hrHistory.removeAll { $0.timestamp < cutoff }
        spO2History.removeAll { $0.timestamp < cutoff }
        sleepHistory.removeAll { $0.timestamp < cutoff }
        temperatureHistory.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Sample Processing

    /// Process a new PPG IR sample
    /// - Parameters:
    ///   - irValue: PPG IR value
    ///   - timestamp: Sample timestamp
    ///   - accelX: Nearest accelerometer X
    ///   - accelY: Nearest accelerometer Y
    ///   - accelZ: Nearest accelerometer Z
    ///   - temperature: Nearest temperature
    public func processSample(
        irValue: Int,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        let aboveThreshold = irValue > threshold
        let newEventType: EventType = aboveThreshold ? .activity : .rest

        // First sample - initialize state
        if currentEventType == nil {
            currentEventType = newEventType
            startEvent(
                eventType: newEventType,
                irValue: irValue,
                timestamp: timestamp,
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                temperature: temperature
            )
            return
        }

        // Check for threshold crossing (event type change)
        if newEventType != currentEventType {
            // End current event
            endEvent(irValue: irValue, timestamp: timestamp)

            // Start new event of opposite type
            currentEventType = newEventType
            startEvent(
                eventType: newEventType,
                irValue: irValue,
                timestamp: timestamp,
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                temperature: temperature
            )
        } else {
            // Same event type - accumulate IR values
            eventIRValues.append(irValue)
        }
    }

    private func startEvent(
        eventType: EventType,
        irValue: Int,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        eventStartTimestamp = timestamp
        eventStartIR = irValue
        eventIRValues = [irValue]
        eventStartAccel = (accelX, accelY, accelZ)
        eventStartTemperature = temperature
    }

    private func endEvent(irValue: Int, timestamp: Date) {
        guard let startTimestamp = eventStartTimestamp,
              let startIR = eventStartIR,
              let accel = eventStartAccel,
              let temp = eventStartTemperature,
              let eventType = currentEventType else {
            resetEventState()
            return
        }

        eventCounter += 1

        // Calculate average IR
        let avgIR = eventIRValues.isEmpty ? Double(startIR) :
            Double(eventIRValues.reduce(0, +)) / Double(eventIRValues.count)

        // Check validation
        let isValid = hasValidMetricInWindow(before: startTimestamp)

        // Get latest metrics for export
        let latestHR = getLatestHR(before: startTimestamp)
        let latestSpO2 = getLatestSpO2(before: startTimestamp)
        let latestSleep = getLatestSleep(before: startTimestamp)

        let event = MuscleActivityEvent(
            eventNumber: eventCounter,
            eventType: eventType,
            startTimestamp: startTimestamp,
            endTimestamp: timestamp,
            startIR: startIR,
            endIR: irValue,
            averageIR: avgIR,
            accelX: accel.x,
            accelY: accel.y,
            accelZ: accel.z,
            temperature: temp,
            heartRate: latestHR,
            spO2: latestSpO2,
            sleepState: latestSleep,
            isValid: isValid
        )

        // Only emit valid events
        if isValid {
            onEventDetected?(event)
        } else {
            discardedEventCounter += 1
            onEventDiscarded?(event)
        }

        resetEventState()
    }

    private func resetEventState() {
        eventStartTimestamp = nil
        eventStartIR = nil
        eventIRValues = []
        eventStartAccel = nil
        eventStartTemperature = nil
        // Note: currentEventType is NOT reset - it tracks the current state
    }

    // MARK: - Validation

    private func hasValidMetricInWindow(before timestamp: Date) -> Bool {
        let windowStart = timestamp.addingTimeInterval(-validationWindowSeconds)

        let hasValidHR = hrHistory.contains { $0.timestamp >= windowStart && $0.timestamp <= timestamp }
        let hasValidSpO2 = spO2History.contains { $0.timestamp >= windowStart && $0.timestamp <= timestamp }
        let hasValidSleep = sleepHistory.contains { $0.timestamp >= windowStart && $0.timestamp <= timestamp }
        let hasValidTemp = temperatureHistory.contains { $0.timestamp >= windowStart && $0.timestamp <= timestamp }

        return hasValidHR || hasValidSpO2 || hasValidSleep || hasValidTemp
    }

    private func getLatestHR(before timestamp: Date) -> Double? {
        hrHistory
            .filter { $0.timestamp <= timestamp }
            .max(by: { $0.timestamp < $1.timestamp })?
            .value
    }

    private func getLatestSpO2(before timestamp: Date) -> Double? {
        spO2History
            .filter { $0.timestamp <= timestamp }
            .max(by: { $0.timestamp < $1.timestamp })?
            .value
    }

    private func getLatestSleep(before timestamp: Date) -> SleepState? {
        sleepHistory
            .filter { $0.timestamp <= timestamp }
            .max(by: { $0.timestamp < $1.timestamp })?
            .state
    }

    private func getLatestTemperature(before timestamp: Date) -> Double? {
        temperatureHistory
            .filter { $0.timestamp <= timestamp }
            .max(by: { $0.timestamp < $1.timestamp })?
            .value
    }

    // MARK: - Statistics

    /// Total number of events detected (including discarded)
    public var totalEventsDetected: Int {
        eventCounter
    }

    /// Number of events discarded due to validation failure
    public var discardedEventCount: Int {
        discardedEventCounter
    }

    /// Number of valid events (total - discarded)
    public var validEventCount: Int {
        eventCounter - discardedEventCounter
    }

    // MARK: - Reset

    /// Reset all state and counters
    public func reset() {
        resetEventState()
        currentEventType = nil
        eventCounter = 0
        discardedEventCounter = 0
        hrHistory.removeAll()
        spO2History.removeAll()
        sleepHistory.removeAll()
        temperatureHistory.removeAll()
    }
}
