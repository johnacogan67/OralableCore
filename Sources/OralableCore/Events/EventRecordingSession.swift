//
//  EventRecordingSession.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Manages a recording session that collects muscle activity events
//

import Foundation
import Combine

/// Manages a recording session that collects muscle activity events
public class EventRecordingSession: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var events: [MuscleActivityEvent] = []
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var discardedCount: Int = 0
    @Published public private(set) var sessionStartTime: Date?
    @Published public private(set) var lastEventTime: Date?

    // MARK: - Components

    private let eventDetector: EventDetector

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
        eventDetector.onEventDetected = { [weak self] event in
            self?.handleEventDetected(event)
        }

        eventDetector.onEventDiscarded = { [weak self] event in
            self?.handleEventDiscarded(event)
        }
    }

    private func handleEventDetected(_ event: MuscleActivityEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.events.append(event)
            self.eventCount += 1
            self.lastEventTime = event.endTimestamp
        }
    }

    private func handleEventDiscarded(_ event: MuscleActivityEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discardedCount += 1
        }
    }

    // MARK: - Recording Control

    /// Start a new recording session
    public func startRecording() {
        events.removeAll()
        eventCount = 0
        discardedCount = 0
        lastEventTime = nil
        eventDetector.reset()
        sessionStartTime = Date()
        isRecording = true
    }

    /// Stop the current recording session
    public func stopRecording() {
        isRecording = false
    }

    /// Pause recording (events will be ignored)
    public func pauseRecording() {
        isRecording = false
    }

    /// Resume recording from paused state
    public func resumeRecording() {
        isRecording = true
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

    // MARK: - Data Input

    /// Feed a PPG IR sample to the event detector
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
        eventCount = 0
        discardedCount = 0
        lastEventTime = nil
        eventDetector.reset()
    }
}
