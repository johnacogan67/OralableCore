//
//  EventRecordingSession.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 12, 2026 - Real-time event caching with memory tracking
//
//  Manages a recording session with real-time event detection and caching
//  Only stores completed events - raw samples are processed and discarded
//

import Foundation
import Combine

/// Manages a recording session with real-time event detection and caching
/// Only stores completed events - raw samples are processed and discarded
public class EventRecordingSession: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var events: [MuscleActivityEvent] = []
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var discardedCount: Int = 0
    @Published public private(set) var sessionStartTime: Date?
    @Published public private(set) var lastEventTime: Date?
    @Published public private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Streaming Statistics

    @Published public private(set) var samplesProcessed: Int = 0
    @Published public private(set) var samplesDiscarded: Int = 0

    // MARK: - Memory Tracking

    @Published public private(set) var estimatedMemoryBytes: Int = 0
    private let bytesPerEvent: Int = 200  // Approximate size of MuscleActivityEvent

    // MARK: - Event Cache (only completed events stored)

    private var discardedEvents: [MuscleActivityEvent] = []

    // MARK: - Components

    private let eventDetector: EventDetector
    private var durationTimer: Timer?
    private var lastIRValue: Int = 0

    // MARK: - Configuration

    public var threshold: Int {
        get { eventDetector.threshold }
        set { eventDetector.threshold = newValue }
    }

    // MARK: - Init

    public init(threshold: Int = 150000) {
        self.eventDetector = EventDetector(threshold: threshold)
        setupEventDetectorCallbacks()
    }

    private func setupEventDetectorCallbacks() {
        // Event detected and valid - cache it
        eventDetector.onEventDetected = { [weak self] event in
            self?.handleEventDetected(event)
        }

        // Event detected but invalid - track but don't cache
        eventDetector.onEventDiscarded = { [weak self] event in
            self?.handleEventDiscarded(event)
        }

        // Sample processed but not part of event boundary
        eventDetector.onSampleDiscarded = { [weak self] in
            DispatchQueue.main.async {
                self?.samplesDiscarded += 1
            }
        }
    }

    private func handleEventDetected(_ event: MuscleActivityEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.events.append(event)
            self.eventCount = self.events.count
            self.lastEventTime = event.endTimestamp
            self.updateMemoryEstimate()

            #if DEBUG
            Logger.shared.debug("[EventRecordingSession] Event #\(event.eventNumber) cached: \(event.eventType.rawValue), duration: \(event.durationMs)ms")
            #endif
        }
    }

    private func handleEventDiscarded(_ event: MuscleActivityEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discardedEvents.append(event)
            self.discardedCount = self.discardedEvents.count

            #if DEBUG
            Logger.shared.debug("[EventRecordingSession] Event #\(event.eventNumber) discarded (invalid)")
            #endif
        }
    }

    private func updateMemoryEstimate() {
        estimatedMemoryBytes = events.count * bytesPerEvent
    }

    // MARK: - Recording Control

    /// Start a new recording session
    public func startRecording() {
        // Reset state
        events.removeAll()
        discardedEvents.removeAll()
        eventDetector.reset()

        eventCount = 0
        discardedCount = 0
        samplesProcessed = 0
        samplesDiscarded = 0
        recordingDuration = 0
        estimatedMemoryBytes = 0
        lastEventTime = nil

        sessionStartTime = Date()
        isRecording = true

        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        Logger.shared.info("[EventRecordingSession] Recording started (real-time event detection)")
    }

    /// Stop the current recording session
    public func stopRecording() {
        guard isRecording else { return }

        // Finalize any in-progress event
        eventDetector.finalizeCurrentEvent(endIR: lastIRValue, timestamp: Date())

        durationTimer?.invalidate()
        durationTimer = nil
        isRecording = false

        let stats = eventDetector.statistics
        Logger.shared.info("[EventRecordingSession] Recording stopped")
        Logger.shared.info("[EventRecordingSession] Stats: \(stats.processed) samples → \(eventCount) events (\(stats.discarded) samples discarded)")
        Logger.shared.info("[EventRecordingSession] Memory: ~\(estimatedMemoryBytes / 1024) KB for \(eventCount) events")
    }

    /// Pause recording (events will be ignored)
    public func pauseRecording() {
        durationTimer?.invalidate()
        durationTimer = nil
        isRecording = false
    }

    /// Resume recording from paused state
    public func resumeRecording() {
        isRecording = true
        // Restart duration timer from current duration
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.sessionStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    // MARK: - Session Duration

    /// Duration of the current session in seconds
    public var sessionDuration: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    /// Formatted session duration (MM:SS)
    public var formattedSessionDuration: String {
        let duration = sessionDuration
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Sample Processing (Real-Time)

    /// Process a sensor sample in real-time
    /// The sample is evaluated for events and then discarded from memory
    /// - Parameters:
    ///   - irValue: PPG IR value
    ///   - timestamp: Sample timestamp
    ///   - accelX: Nearest accelerometer X
    ///   - accelY: Nearest accelerometer Y
    ///   - accelZ: Nearest accelerometer Z
    ///   - temperature: Current temperature
    public func processSample(
        irValue: Int,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        guard isRecording else { return }

        lastIRValue = irValue
        samplesProcessed += 1

        eventDetector.processSample(
            irValue: irValue,
            timestamp: timestamp,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ,
            temperature: temperature
        )
    }

    /// Update HR metric (call continuously during recording)
    /// - Parameters:
    ///   - value: Heart rate in BPM
    ///   - timestamp: When the measurement was taken
    public func updateHR(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateHR(value, at: timestamp)
    }

    /// Update SpO2 metric (call continuously during recording)
    /// - Parameters:
    ///   - value: SpO2 percentage
    ///   - timestamp: When the measurement was taken
    public func updateSpO2(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateSpO2(value, at: timestamp)
    }

    /// Update Sleep state (call continuously during recording)
    /// - Parameters:
    ///   - state: Current sleep state
    ///   - timestamp: When the state was determined
    public func updateSleep(_ state: SleepState, at timestamp: Date = Date()) {
        eventDetector.updateSleep(state, at: timestamp)
    }

    /// Update Temperature (call continuously during recording)
    /// Values in range 32-38°C indicate device is on skin and are used for validation
    /// - Parameters:
    ///   - value: Temperature in Celsius
    ///   - timestamp: When the measurement was taken
    public func updateTemperature(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateTemperature(value, at: timestamp)
    }

    // MARK: - Export

    /// Export events to CSV string
    /// - Parameter options: Export options controlling which columns are included
    /// - Returns: CSV content as string
    public func exportCSV(options: EventCSVExporter.ExportOptions) -> String {
        EventCSVExporter.exportToCSV(events: events, options: options)
    }

    /// Export events to a file
    /// - Parameters:
    ///   - options: Export options controlling which columns are included
    ///   - filename: Optional custom filename
    /// - Returns: URL of the exported file
    /// - Throws: Error if file write fails
    public func exportToFile(options: EventCSVExporter.ExportOptions, filename: String? = nil) throws -> URL {
        try EventCSVExporter.exportToFile(events: events, options: options, filename: filename)
    }

    /// Export events to a temporary file suitable for sharing
    /// - Parameters:
    ///   - options: Export options controlling which columns are included
    ///   - userIdentifier: Optional user identifier to include in filename
    /// - Returns: URL of the exported file
    /// - Throws: Error if file write fails
    public func exportToTempFile(options: EventCSVExporter.ExportOptions, userIdentifier: String? = nil) throws -> URL {
        try EventCSVExporter.exportToTempFile(events: events, options: options, userIdentifier: userIdentifier)
    }

    /// Get export summary for current session
    /// - Parameter options: Export options
    /// - Returns: Export summary
    public func getExportSummary(options: EventCSVExporter.ExportOptions) -> EventExportSummary {
        EventCSVExporter.getExportSummary(events: events, options: options)
    }

    // MARK: - Statistics

    /// Total duration of all events in milliseconds
    public var totalEventDurationMs: Int {
        events.reduce(0) { $0 + $1.durationMs }
    }

    /// Average event duration in milliseconds
    public var averageEventDurationMs: Double {
        guard !events.isEmpty else { return 0 }
        return Double(totalEventDurationMs) / Double(events.count)
    }

    /// Average IR value across all events
    public var averageIRValue: Double {
        guard !events.isEmpty else { return 0 }
        return events.reduce(0.0) { $0 + $1.averageIR } / Double(events.count)
    }

    /// Count of Activity events
    public var activityEventCount: Int {
        events.filter { $0.eventType == .activity }.count
    }

    /// Count of Rest events
    public var restEventCount: Int {
        events.filter { $0.eventType == .rest }.count
    }

    // MARK: - Clear

    /// Clear all events without stopping recording
    public func clearEvents() {
        events.removeAll()
        discardedEvents.removeAll()
        eventCount = 0
        discardedCount = 0
        samplesProcessed = 0
        samplesDiscarded = 0
        estimatedMemoryBytes = 0
        lastEventTime = nil
        eventDetector.reset()
    }

    // MARK: - Session Summary

    /// Get session summary for display
    public var summary: SessionSummary {
        SessionSummary(
            startTime: sessionStartTime,
            duration: recordingDuration,
            samplesProcessed: samplesProcessed,
            samplesDiscarded: samplesDiscarded,
            eventsDetected: eventCount,
            eventsDiscarded: discardedCount,
            estimatedMemoryBytes: estimatedMemoryBytes
        )
    }
}

// MARK: - Session Summary

/// Summary of a recording session
public struct SessionSummary {
    public let startTime: Date?
    public let duration: TimeInterval
    public let samplesProcessed: Int
    public let samplesDiscarded: Int
    public let eventsDetected: Int
    public let eventsDiscarded: Int
    public let estimatedMemoryBytes: Int

    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public var memoryEfficiency: String {
        guard samplesProcessed > 0 else { return "N/A" }
        let continuousBytes = samplesProcessed * 100 // Approximate bytes per SensorData
        let savings = 100.0 - (Double(estimatedMemoryBytes) / Double(continuousBytes) * 100.0)
        return String(format: "%.1f%% reduction", savings)
    }

    public var formattedMemory: String {
        if estimatedMemoryBytes < 1024 {
            return "\(estimatedMemoryBytes) B"
        } else if estimatedMemoryBytes < 1024 * 1024 {
            return "\(estimatedMemoryBytes / 1024) KB"
        } else {
            return String(format: "%.1f MB", Double(estimatedMemoryBytes) / 1024.0 / 1024.0)
        }
    }
}
