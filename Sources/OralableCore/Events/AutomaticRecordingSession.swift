//
//  AutomaticRecordingSession.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Automatic recording session that starts on BLE connect and stops on disconnect.
//
//  Features:
//  - Automatic start/stop based on BLE connection
//  - State-based event recording (DataStreaming, Positioned, Activity)
//  - Auto-save timer (every 3 minutes)
//  - File management with 14-day retention
//  - CloudKit sync on disconnect
//

import Foundation
import Combine

// MARK: - Automatic Recording Session

/// Manages automatic state-based event recording
public class AutomaticRecordingSession: ObservableObject {

    // MARK: - Configuration

    /// Auto-save interval in seconds
    public var autoSaveInterval: TimeInterval = 180  // 3 minutes

    /// Whether to sync to CloudKit on disconnect
    public var syncOnDisconnect: Bool = true

    // MARK: - Published State

    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var currentState: DeviceRecordingState = .dataStreaming
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var sessionStartTime: Date?
    @Published public private(set) var lastSaveTime: Date?
    @Published public private(set) var isCalibrated: Bool = false
    @Published public private(set) var calibrationProgress: Double = 0

    // MARK: - State Detector

    public let stateDetector = StateTransitionDetector()

    // MARK: - File Manager

    public let fileManager = StateEventFileManager.shared

    // MARK: - Pending Events

    private var pendingEvents: [StateTransitionEvent] = []
    private let pendingEventsLock = NSLock()

    // MARK: - Timers

    private var autoSaveTimer: Timer?

    // MARK: - Current Sensor Data

    private var currentIRValue: Int = 0
    private var currentHeartRate: Double = 0
    private var currentSpO2: Double = 0
    private var currentPerfusionIndex: Double = 0
    private var currentTemperature: Double = 0
    private var currentAccelX: Int = 0
    private var currentAccelY: Int = 0
    private var currentAccelZ: Int = 0
    private var currentBatteryMV: Int?

    // MARK: - Callbacks

    /// Called when session starts
    public var onSessionStarted: (() -> Void)?

    /// Called when session stops
    public var onSessionStopped: ((Int) -> Void)?  // eventCount

    /// Called when state changes
    public var onStateChanged: ((DeviceRecordingState) -> Void)?

    /// Called when event is recorded
    public var onEventRecorded: ((StateTransitionEvent) -> Void)?

    /// Called when events are saved
    public var onEventsSaved: ((Int) -> Void)?  // savedCount

    /// Called to trigger CloudKit sync
    public var onSyncRequested: (() -> Void)?

    // MARK: - Initialization

    public init() {
        setupStateDetectorCallbacks()
    }

    private func setupStateDetectorCallbacks() {
        // State transition callback
        stateDetector.onStateTransition = { [weak self] previousState, newState in
            guard let self = self, self.isSessionActive else { return }
            self.handleStateTransition(from: previousState, to: newState)
        }

        // Calibration callbacks
        stateDetector.onCalibrationComplete = { [weak self] baseline in
            guard let self = self else { return }
            self.isCalibrated = true
            Logger.shared.info("[AutomaticRecordingSession] Calibration complete: baseline = \(Int(baseline))")
        }

        stateDetector.onCalibrationFailed = { reason in
            Logger.shared.warning("[AutomaticRecordingSession] Calibration failed: \(reason)")
        }
    }

    // MARK: - Session Control

    /// Called when BLE device connects
    public func onDeviceConnected() {
        guard !isSessionActive else {
            Logger.shared.warning("[AutomaticRecordingSession] Session already active")
            return
        }

        isSessionActive = true
        sessionStartTime = Date()
        eventCount = 0
        pendingEvents.removeAll()

        // Record initial DataStreaming state
        currentState = .dataStreaming
        recordCurrentState()

        // Start auto-save timer
        startAutoSaveTimer()

        // Cleanup old files
        fileManager.cleanupOldFiles()

        Logger.shared.info("[AutomaticRecordingSession] Session started")
        onSessionStarted?()
    }

    /// Called when BLE device disconnects
    public func onDeviceDisconnected() {
        guard isSessionActive else { return }

        // Stop auto-save timer
        stopAutoSaveTimer()

        // Save any pending events
        savePendingEvents()

        // Trigger CloudKit sync if enabled
        if syncOnDisconnect {
            Logger.shared.info("[AutomaticRecordingSession] Triggering CloudKit sync")
            onSyncRequested?()
        }

        let finalEventCount = eventCount
        isSessionActive = false
        sessionStartTime = nil

        // Reset state detector
        stateDetector.reset()
        currentState = .dataStreaming
        isCalibrated = false
        calibrationProgress = 0

        Logger.shared.info("[AutomaticRecordingSession] Session stopped: \(finalEventCount) events recorded")
        onSessionStopped?(finalEventCount)
    }

    // MARK: - Sensor Data Processing

    /// Process incoming sensor data
    /// Call this with each sensor batch
    public func processSensorData(
        irValue: Int,
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        spO2: Double? = nil,
        perfusionIndex: Double? = nil,
        temperature: Double? = nil,
        accelX: Int? = nil,
        accelY: Int? = nil,
        accelZ: Int? = nil,
        batteryMV: Int? = nil
    ) {
        guard isSessionActive else { return }

        // Update current values
        currentIRValue = irValue
        if let hr = heartRate { currentHeartRate = hr }
        if let spo2 = spO2 { currentSpO2 = spo2 }
        if let pi = perfusionIndex { currentPerfusionIndex = pi }
        if let temp = temperature { currentTemperature = temp }
        if let x = accelX { currentAccelX = x }
        if let y = accelY { currentAccelY = y }
        if let z = accelZ { currentAccelZ = z }
        if let battery = batteryMV { currentBatteryMV = battery }

        // Update calibration progress
        if stateDetector.calibrationManager.state.isCalibrating {
            calibrationProgress = stateDetector.calibrationManager.progress
        }

        // Evaluate state
        let result = stateDetector.evaluateState(
            irValue: irValue,
            timestamp: timestamp,
            heartRate: heartRate,
            spO2: spO2,
            perfusionIndex: perfusionIndex
        )

        // State transition is handled by callback
        if result.didTransition {
            currentState = result.newState
        }
    }

    // MARK: - Calibration

    /// Start calibration (device must be positioned)
    public func startCalibration() {
        stateDetector.startCalibration()
        Logger.shared.info("[AutomaticRecordingSession] Starting calibration")
    }

    /// Check if ready to start calibration (device positioned)
    public var canStartCalibration: Bool {
        currentState == .positioned && !isCalibrated
    }

    // MARK: - State Transitions

    private func handleStateTransition(from previousState: DeviceRecordingState, to newState: DeviceRecordingState) {
        currentState = newState
        recordCurrentState()
        onStateChanged?(newState)

        Logger.shared.info("[AutomaticRecordingSession] State: \(previousState.rawValue) → \(newState.rawValue)")

        // Auto-start calibration when positioned (if not already calibrated)
        if newState == .positioned && !isCalibrated {
            startCalibration()
        }
    }

    // MARK: - Event Recording

    private func recordCurrentState() {
        let normalizedIR = stateDetector.calibrationManager.normalize(currentIRValue)

        let event = StateTransitionEvent(
            timestamp: Date(),
            state: currentState,
            irValue: currentIRValue,
            normalizedIRPercent: normalizedIR,
            heartRate: currentHeartRate > 0 ? currentHeartRate : nil,
            spO2: currentSpO2 > 0 ? currentSpO2 : nil,
            perfusionIndex: currentPerfusionIndex > 0 ? currentPerfusionIndex : nil,
            temperature: currentTemperature,
            accelX: currentAccelX,
            accelY: currentAccelY,
            accelZ: currentAccelZ,
            batteryMV: currentBatteryMV,
            baseline: stateDetector.baseline > 0 ? stateDetector.baseline : nil
        )

        // Add to pending events
        pendingEventsLock.lock()
        pendingEvents.append(event)
        eventCount = pendingEvents.count
        pendingEventsLock.unlock()

        onEventRecorded?(event)

        Logger.shared.info("[AutomaticRecordingSession] Event #\(eventCount): \(currentState.rawValue)")
    }

    // MARK: - Auto-Save

    private func startAutoSaveTimer() {
        stopAutoSaveTimer()

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.savePendingEvents()
        }

        Logger.shared.info("[AutomaticRecordingSession] Auto-save timer started (interval: \(Int(autoSaveInterval))s)")
    }

    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    /// Save pending events to file
    public func savePendingEvents() {
        pendingEventsLock.lock()
        let eventsToSave = pendingEvents
        pendingEvents.removeAll()
        pendingEventsLock.unlock()

        guard !eventsToSave.isEmpty else {
            Logger.shared.debug("[AutomaticRecordingSession] No pending events to save")
            return
        }

        do {
            try fileManager.appendEvents(eventsToSave)
            lastSaveTime = Date()
            Logger.shared.info("[AutomaticRecordingSession] Saved \(eventsToSave.count) events")
            onEventsSaved?(eventsToSave.count)
        } catch {
            Logger.shared.error("[AutomaticRecordingSession] Failed to save events: \(error)")
            // Put events back
            pendingEventsLock.lock()
            pendingEvents.insert(contentsOf: eventsToSave, at: 0)
            pendingEventsLock.unlock()
        }
    }

    // MARK: - Session Statistics

    /// Session duration in seconds
    public var sessionDuration: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    /// Formatted session duration
    public var formattedDuration: String {
        let duration = sessionDuration
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// Get today's events from file
    public func getTodayEvents() -> [StateTransitionEvent] {
        do {
            return try fileManager.loadTodayEvents()
        } catch {
            Logger.shared.error("[AutomaticRecordingSession] Failed to load today's events: \(error)")
            return []
        }
    }

    /// Get storage statistics
    public var storageStats: StateEventStorageStats {
        fileManager.getStorageStats()
    }
}
