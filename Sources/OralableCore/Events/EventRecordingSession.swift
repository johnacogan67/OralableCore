//
//  EventRecordingSession.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 15, 2026 - Normalized-only detection, store all events
//
//  Manages a recording session with real-time event detection.
//
//  Features:
//  - Calibration phase before recording (always required)
//  - Real-time event caching (ALL events, valid and invalid)
//  - Memory-efficient (only stores events)
//  - Session statistics with valid/invalid breakdown
//

import Foundation
import Combine

// MARK: - Session State

/// Recording session state
public enum SessionState: Equatable, Sendable {
    case idle
    case calibrating(progress: Double)
    case calibrated
    case recording
    case stopped

    public var canStartRecording: Bool {
        self == .calibrated || self == .stopped
    }

    public var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }
}

// MARK: - Event Recording Session

/// Manages a recording session with real-time event detection
public class EventRecordingSession: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var validEventCount: Int = 0
    @Published public private(set) var invalidEventCount: Int = 0
    @Published public private(set) var samplesProcessed: Int = 0
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var estimatedMemoryBytes: Int = 0
    @Published public private(set) var lastEventTime: Date?

    /// Legacy property - returns invalidEventCount
    public var discardedEventCount: Int {
        invalidEventCount
    }

    // MARK: - Calibration State (for UI access)

    /// Whether calibration is in progress
    public var isCalibrating: Bool {
        sessionState.isCalibrating
    }

    /// Current calibration progress (0.0 to 1.0)
    public var calibrationProgress: Double {
        if case .calibrating(let progress) = sessionState {
            return progress
        }
        return sessionState == .calibrated || sessionState == .recording ? 1.0 : 0.0
    }

    /// Whether calibration is complete
    public var isCalibrated: Bool {
        eventDetector.calibrationState.isCalibrated
    }

    /// Current baseline value
    public var baseline: Double {
        eventDetector.baseline
    }

    // MARK: - Event Storage

    private var cachedEvents: [MuscleActivityEvent] = []
    private let bytesPerEvent: Int = 250

    // MARK: - Components

    public let eventDetector: EventDetector
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Callbacks

    public var onEventDetected: ((MuscleActivityEvent) -> Void)?
    public var onCalibrationComplete: ((Double) -> Void)?
    public var onCalibrationFailed: ((String) -> Void)?

    // MARK: - Init

    public init(normalizedThresholdPercent: Double = 40.0) {
        self.eventDetector = EventDetector(normalizedThresholdPercent: normalizedThresholdPercent)
        setupCallbacks()
    }

    /// Legacy init for API compatibility
    public convenience init(
        detectionMode: DetectionMode = .normalized,
        absoluteThreshold: Int = 150000,
        normalizedThresholdPercent: Double = 40.0
    ) {
        self.init(normalizedThresholdPercent: normalizedThresholdPercent)
    }

    private func setupCallbacks() {
        // Receive ALL events (valid and invalid)
        eventDetector.onEventDetected = { [weak self] event in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.cachedEvents.append(event)
                self.eventCount = self.cachedEvents.count
                self.lastEventTime = event.endTimestamp
                self.updateMemoryEstimate()

                if event.isValid {
                    self.validEventCount += 1
                } else {
                    self.invalidEventCount += 1
                }

                self.onEventDetected?(event)
            }
        }

        eventDetector.onCalibrationComplete = { [weak self] baseline in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.sessionState = .calibrated
                self.onCalibrationComplete?(baseline)
            }
        }

        eventDetector.onCalibrationFailed = { [weak self] reason in
            DispatchQueue.main.async {
                self?.sessionState = .idle
                self?.onCalibrationFailed?(reason)
            }
        }

        eventDetector.onCalibrationProgress = { [weak self] progress in
            DispatchQueue.main.async {
                self?.sessionState = .calibrating(progress: progress)
            }
        }
    }

    private func updateMemoryEstimate() {
        estimatedMemoryBytes = cachedEvents.count * bytesPerEvent
    }

    // MARK: - Session Control

    /// Start calibration (required before recording)
    public func startCalibration() {
        guard sessionState == .idle || sessionState == .stopped else { return }

        cachedEvents.removeAll()
        eventCount = 0
        validEventCount = 0
        invalidEventCount = 0
        samplesProcessed = 0
        estimatedMemoryBytes = 0
        lastEventTime = nil

        eventDetector.reset()
        eventDetector.startCalibration()
        sessionState = .calibrating(progress: 0)

        Logger.shared.info("[EventRecordingSession] Calibration started")
    }

    /// Start recording (after calibration)
    public func startRecording() {
        guard sessionState.canStartRecording else {
            Logger.shared.warning("[EventRecordingSession] Cannot start - calibration required")
            return
        }

        if sessionState == .stopped {
            cachedEvents.removeAll()
            eventCount = 0
            validEventCount = 0
            invalidEventCount = 0
            samplesProcessed = 0
            estimatedMemoryBytes = 0
            lastEventTime = nil
            eventDetector.reset()
        }

        recordingStartTime = Date()
        sessionState = .recording

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        Logger.shared.info("[EventRecordingSession] Recording started")
    }

    /// Stop recording
    public func stopRecording() {
        guard sessionState == .recording else { return }

        eventDetector.finalizeCurrentEvent()

        durationTimer?.invalidate()
        durationTimer = nil
        sessionState = .stopped

        Logger.shared.info("[EventRecordingSession] Recording stopped: \(eventCount) events (\(validEventCount) valid, \(invalidEventCount) invalid)")
    }

    /// Reset session completely
    public func reset() {
        stopRecording()
        eventDetector.fullReset()

        cachedEvents.removeAll()
        eventCount = 0
        validEventCount = 0
        invalidEventCount = 0
        samplesProcessed = 0
        recordingDuration = 0
        estimatedMemoryBytes = 0
        recordingStartTime = nil
        lastEventTime = nil
        sessionState = .idle
    }

    // MARK: - Sample Processing

    /// Process incoming sensor sample
    public func processSample(
        irValue: Int,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        guard sessionState == .recording || sessionState.isCalibrating else { return }

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

    /// Update heart rate for validation
    public func updateHR(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateHR(value, at: timestamp)
    }

    /// Update SpO2 for validation
    public func updateSpO2(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateSpO2(value, at: timestamp)
    }

    /// Update sleep state for validation
    public func updateSleep(_ state: SleepState, at timestamp: Date = Date()) {
        eventDetector.updateSleep(state, at: timestamp)
    }

    /// Update temperature for validation
    public func updateTemperature(_ value: Double, at timestamp: Date = Date()) {
        eventDetector.updateTemperature(value, at: timestamp)
    }

    // MARK: - Configuration

    /// Always returns .normalized
    public var detectionMode: DetectionMode {
        get { .normalized }
        set { /* ignored */ }
    }

    /// Legacy property - no longer used
    public var absoluteThreshold: Int {
        get { 150000 }
        set { /* ignored */ }
    }

    public var normalizedThresholdPercent: Double {
        get { eventDetector.normalizedThresholdPercent }
        set { eventDetector.normalizedThresholdPercent = newValue }
    }

    // MARK: - Results

    /// Get all detected events (valid and invalid)
    public var events: [MuscleActivityEvent] {
        cachedEvents
    }

    /// Get only valid events
    public var validEvents: [MuscleActivityEvent] {
        cachedEvents.filter { $0.isValid }
    }

    /// Get only invalid events
    public var invalidEvents: [MuscleActivityEvent] {
        cachedEvents.filter { !$0.isValid }
    }

    /// Check if recording is active
    public var isRecording: Bool {
        sessionState == .recording
    }

    /// Get session summary
    public var summary: SessionSummary {
        SessionSummary(
            startTime: recordingStartTime,
            duration: recordingDuration,
            samplesProcessed: samplesProcessed,
            eventsDetected: eventCount,
            validEvents: validEventCount,
            invalidEvents: invalidEventCount,
            estimatedMemoryBytes: estimatedMemoryBytes,
            baseline: eventDetector.baseline
        )
    }

    // MARK: - Statistics

    /// Total duration of all events in milliseconds
    public var totalEventDurationMs: Int {
        cachedEvents.reduce(0) { $0 + $1.durationMs }
    }

    /// Average event duration in milliseconds
    public var averageEventDurationMs: Double {
        guard !cachedEvents.isEmpty else { return 0 }
        return Double(totalEventDurationMs) / Double(cachedEvents.count)
    }

    /// Count of Activity events
    public var activityEventCount: Int {
        cachedEvents.filter { $0.eventType == .activity }.count
    }

    /// Count of Rest events
    public var restEventCount: Int {
        cachedEvents.filter { $0.eventType == .rest }.count
    }

    // MARK: - Export

    /// Export events to CSV string
    public func exportCSV(options: EventCSVExporter.ExportOptions = .all) -> String {
        EventCSVExporter.exportToCSV(events: cachedEvents, options: options)
    }

    /// Export events to file
    public func exportToFile(options: EventCSVExporter.ExportOptions = .all, filename: String? = nil) throws -> URL {
        try EventCSVExporter.exportToFile(events: cachedEvents, options: options, filename: filename)
    }

    /// Export events to temp file for sharing
    public func exportToTempFile(options: EventCSVExporter.ExportOptions = .all, userIdentifier: String? = nil) throws -> URL {
        try EventCSVExporter.exportToTempFile(events: cachedEvents, options: options, userIdentifier: userIdentifier)
    }

    /// Get export summary
    public func getExportSummary(options: EventCSVExporter.ExportOptions = .all) -> EventExportSummary {
        EventCSVExporter.getExportSummary(events: cachedEvents, options: options)
    }
}

// MARK: - Session Summary

/// Summary of a recording session
public struct SessionSummary: Sendable {
    public let startTime: Date?
    public let duration: TimeInterval
    public let samplesProcessed: Int
    public let eventsDetected: Int
    public let validEvents: Int
    public let invalidEvents: Int
    public let estimatedMemoryBytes: Int
    public let baseline: Double

    public var eventsDiscarded: Int { invalidEvents }

    public var formattedDuration: String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    public var formattedMemory: String {
        if estimatedMemoryBytes < 1024 {
            return "\(estimatedMemoryBytes) B"
        } else if estimatedMemoryBytes < 1024 * 1024 {
            return "\(estimatedMemoryBytes / 1024) KB"
        }
        return String(format: "%.1f MB", Double(estimatedMemoryBytes) / 1024.0 / 1024.0)
    }

    public var memoryEfficiency: String {
        guard samplesProcessed > 0 else { return "N/A" }
        let continuousBytes = samplesProcessed * 100
        let savings = 100.0 - (Double(estimatedMemoryBytes) / Double(continuousBytes) * 100.0)
        return String(format: "%.1f%% reduction", max(0, savings))
    }

    public var validationRate: String {
        guard eventsDetected > 0 else { return "N/A" }
        let rate = Double(validEvents) / Double(eventsDetected) * 100.0
        return String(format: "%.1f%% valid", rate)
    }
}
