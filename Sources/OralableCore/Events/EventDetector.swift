//
//  EventDetector.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 15, 2026 - Normalized-only detection, keep all events
//
//  Real-time event detector for muscle activity monitoring.
//
//  Features:
//  - Normalized detection mode (percentage above baseline)
//  - Real-time streaming (no raw sample storage)
//  - Calibration required before recording
//  - Event validation based on recent metrics
//  - Keeps ALL events (valid and invalid) for analysis
//
//  Memory Efficiency:
//  - Only stores completed events
//  - Uses running averages instead of sample arrays
//  - ~99.9% memory reduction vs storing all samples
//

import Foundation
import Combine

/// Real-time muscle activity event detector
public class EventDetector: ObservableObject {

    // MARK: - Configuration

    /// Normalized threshold as percentage (e.g., 40% above baseline)
    @Published public var normalizedThresholdPercent: Double = 40.0

    /// Minimum time signal must stay in new state before committing event change (debounce)
    /// This prevents heartbeat oscillations from creating excessive events
    public var stateChangeDebounceMs: Int = 1000

    /// Minimum event duration in milliseconds to filter heartbeat noise
    /// Events shorter than this are discarded as transient threshold crossings
    public var minimumEventDurationMs: Int = 1000

    /// Validation window in seconds
    public let validationWindowSeconds: TimeInterval = 180  // 3 minutes

    // MARK: - Temperature Validation

    public static let validTemperatureMin: Double = 32.0
    public static let validTemperatureMax: Double = 38.0

    // MARK: - SpO2 Validation

    /// Minimum SpO2 percentage for valid positioning (70% is very conservative)
    /// SpO2 is more stable during muscle activity than HR due to ratio-of-ratios calculation
    public static let validSpO2Min: Double = 70.0

    // MARK: - Perfusion Index Validation

    /// Minimum perfusion index to indicate valid blood flow (0.1% = 0.001)
    /// PI = AC/DC ratio, indicates pulsatile blood flow detected
    public static let validPerfusionIndexMin: Double = 0.001

    // MARK: - Calibration

    public let calibrationManager = PPGCalibrationManager()

    @Published public private(set) var calibrationState: CalibrationState = .notStarted
    @Published public private(set) var baseline: Double = 0
    @Published public private(set) var calibrationProgress: Double = 0

    // MARK: - Event State

    private var isInEvent: Bool = false
    private var currentEventType: EventType?
    private var eventStartTimestamp: Date?
    private var eventStartIR: Int?
    private var eventStartNormalized: Double?
    private var eventIRSum: Int64 = 0
    private var eventNormalizedSum: Double = 0
    private var eventSampleCount: Int = 0
    private var eventStartAccel: (x: Int, y: Int, z: Int)?
    private var eventStartTemperature: Double?
    private var eventCounter: Int = 0
    private var lastIRValue: Int = 0

    // MARK: - Pending Crossing State (for minimum duration filter)

    private var pendingCrossingTimestamp: Date?
    private var pendingCrossingType: EventType?
    private var pendingStartIR: Int?
    private var pendingStartNormalized: Double?
    private var pendingStartAccel: (x: Int, y: Int, z: Int)?
    private var pendingStartTemperature: Double?

    // MARK: - Statistics

    @Published public private(set) var totalSamplesProcessed: Int = 0
    @Published public private(set) var samplesDiscarded: Int = 0
    @Published public private(set) var validEventCount: Int = 0
    @Published public private(set) var invalidEventCount: Int = 0

    /// Total events detected (valid + invalid)
    public var totalEventsDetected: Int {
        validEventCount + invalidEventCount
    }

    /// Legacy property for backwards compatibility
    public var eventsDetected: Int {
        totalEventsDetected
    }

    /// Legacy property for backwards compatibility
    public var eventsDiscarded: Int {
        invalidEventCount
    }

    // MARK: - Metric History (for validation)

    private var hrHistory: [(timestamp: Date, value: Double)] = []
    private var spO2History: [(timestamp: Date, value: Double)] = []
    private var sleepHistory: [(timestamp: Date, state: SleepState)] = []
    private var temperatureHistory: [(timestamp: Date, value: Double)] = []
    private var piHistory: [(timestamp: Date, value: Double)] = []  // Perfusion Index

    // MARK: - Callbacks

    /// Called for EVERY event detected (both valid and invalid)
    public var onEventDetected: ((MuscleActivityEvent) -> Void)?

    /// Called specifically for invalid events (optional, for logging)
    public var onInvalidEventDetected: ((MuscleActivityEvent) -> Void)?

    /// Legacy callback - now points to onInvalidEventDetected
    public var onEventDiscarded: ((MuscleActivityEvent) -> Void)? {
        get { onInvalidEventDetected }
        set { onInvalidEventDetected = newValue }
    }

    public var onSampleProcessed: (() -> Void)?
    public var onCalibrationProgress: ((Double) -> Void)?
    public var onCalibrationComplete: ((Double) -> Void)?
    public var onCalibrationFailed: ((String) -> Void)?

    // MARK: - Init

    public init(normalizedThresholdPercent: Double = 40.0) {
        self.normalizedThresholdPercent = normalizedThresholdPercent
        setupCalibrationCallbacks()
    }

    /// Legacy init for API compatibility - ignores detectionMode and absoluteThreshold
    public convenience init(
        detectionMode: DetectionMode = .normalized,
        absoluteThreshold: Int = 150000,
        normalizedThresholdPercent: Double = 40.0
    ) {
        self.init(normalizedThresholdPercent: normalizedThresholdPercent)
    }

    private func setupCalibrationCallbacks() {
        calibrationManager.onCalibrationComplete = { [weak self] baseline in
            guard let self = self else { return }
            self.baseline = baseline
            self.calibrationState = .calibrated(baseline: baseline)
            self.onCalibrationComplete?(baseline)
            Logger.shared.info("[EventDetector] Calibration complete, baseline: \(Int(baseline))")
        }

        calibrationManager.onCalibrationFailed = { [weak self] reason in
            guard let self = self else { return }
            self.calibrationState = .failed(reason: reason)
            self.onCalibrationFailed?(reason)
            Logger.shared.warning("[EventDetector] Calibration failed: \(reason)")
        }

        calibrationManager.onProgressUpdate = { [weak self] progress in
            guard let self = self else { return }
            self.calibrationProgress = progress
            self.calibrationState = .calibrating(progress: progress)
            self.onCalibrationProgress?(progress)
        }
    }

    // MARK: - Calibration Control

    /// Start calibration (required before recording)
    public func startCalibration() {
        calibrationManager.startCalibration()
        calibrationState = .calibrating(progress: 0)
        calibrationProgress = 0
    }

    /// Cancel ongoing calibration
    public func cancelCalibration() {
        calibrationManager.cancelCalibration()
        calibrationState = .notStarted
        calibrationProgress = 0
    }

    /// Check if detector is ready for recording
    public var isReadyForRecording: Bool {
        calibrationState.isCalibrated
    }

    /// Get effective threshold for display
    public var effectiveThreshold: String {
        if let absThreshold = calibrationManager.thresholdToAbsolute(normalizedThresholdPercent) {
            return "\(Int(normalizedThresholdPercent))% (\(absThreshold))"
        }
        return "\(Int(normalizedThresholdPercent))%"
    }

    // MARK: - Legacy Properties (for API compatibility)

    /// Always returns .normalized
    public var detectionMode: DetectionMode {
        get { .normalized }
        set { /* ignored - always normalized */ }
    }

    /// Legacy property - no longer used
    public var absoluteThreshold: Int {
        get { 150000 }
        set { /* ignored - always use normalized */ }
    }

    // MARK: - Metric Updates

    public func updateHR(_ value: Double, at timestamp: Date = Date()) {
        guard value > 0 else { return }
        hrHistory.append((timestamp, value))
        pruneHistory()
    }

    public func updateSpO2(_ value: Double, at timestamp: Date = Date()) {
        guard value > 0 else { return }
        spO2History.append((timestamp, value))
        pruneHistory()
    }

    public func updateSleep(_ state: SleepState, at timestamp: Date = Date()) {
        guard state.isValid else { return }
        sleepHistory.append((timestamp, state))
        pruneHistory()
    }

    public func updateTemperature(_ value: Double, at timestamp: Date = Date()) {
        // Store ALL temperature readings - validation will check if any are in valid range
        // This allows us to track warmup time and validate when device reaches 32°C
        temperatureHistory.append((timestamp, value))
        pruneHistory()
    }

    /// Update perfusion index for positioning validation
    /// PI > 0.001 (0.1%) indicates pulsatile blood flow detected
    public func updatePerfusionIndex(_ value: Double, at timestamp: Date = Date()) {
        guard value > 0 else { return }
        piHistory.append((timestamp, value))
        pruneHistory()
    }

    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-validationWindowSeconds - 60)
        hrHistory.removeAll { $0.timestamp < cutoff }
        spO2History.removeAll { $0.timestamp < cutoff }
        sleepHistory.removeAll { $0.timestamp < cutoff }
        temperatureHistory.removeAll { $0.timestamp < cutoff }
        piHistory.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Sample Processing

    /// Process a new sensor sample in real-time
    public func processSample(
        irValue: Int,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        totalSamplesProcessed += 1
        lastIRValue = irValue

        // During calibration, only collect samples
        if case .calibrating = calibrationState {
            calibrationManager.addCalibrationSample(irValue)
            calibrationProgress = calibrationManager.progress
            calibrationState = calibrationManager.state
            return
        }

        // Normalize the IR value
        guard let normalizedValue = calibrationManager.normalize(irValue) else {
            // Not calibrated - skip
            samplesDiscarded += 1
            return
        }

        // Determine if above threshold
        let aboveThreshold = normalizedValue > normalizedThresholdPercent

        // First sample - initialize state
        if currentEventType == nil {
            currentEventType = aboveThreshold ? .activity : .rest
            startEvent(
                eventType: currentEventType!,
                irValue: irValue,
                normalizedValue: normalizedValue,
                timestamp: timestamp,
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                temperature: temperature
            )
            onSampleProcessed?()
            return
        }

        // Determine potential new state
        let potentialState: EventType = aboveThreshold ? .activity : .rest

        // Check if signal state matches current event state
        if potentialState == currentEventType {
            // Signal matches current state - reset any pending state change
            pendingCrossingTimestamp = nil
            pendingCrossingType = nil
            pendingStartIR = nil
            pendingStartNormalized = nil
            pendingStartAccel = nil
            pendingStartTemperature = nil

            // Update running averages (sample not stored)
            eventIRSum += Int64(irValue)
            eventNormalizedSum += normalizedValue
            eventSampleCount += 1
            samplesDiscarded += 1
        } else {
            // Signal crossed threshold - potential state change
            if pendingCrossingType == potentialState {
                // Already tracking this potential state change
                if let startTime = pendingCrossingTimestamp {
                    let elapsedMs = Int(timestamp.timeIntervalSince(startTime) * 1000)
                    if elapsedMs >= stateChangeDebounceMs {
                        // State has been sustained for debounce period - commit the change
                        endEvent(irValue: pendingStartIR ?? irValue,
                                 normalizedValue: pendingStartNormalized ?? normalizedValue,
                                 timestamp: startTime)

                        currentEventType = potentialState
                        startEvent(
                            eventType: potentialState,
                            irValue: pendingStartIR ?? irValue,
                            normalizedValue: pendingStartNormalized ?? normalizedValue,
                            timestamp: startTime,
                            accelX: pendingStartAccel?.x ?? accelX,
                            accelY: pendingStartAccel?.y ?? accelY,
                            accelZ: pendingStartAccel?.z ?? accelZ,
                            temperature: pendingStartTemperature ?? temperature
                        )

                        // Log state change
                        Logger.shared.info("[EventDetector] State change: \(currentEventType?.rawValue ?? "nil") → \(potentialState.rawValue), norm=\(String(format: "%.1f", pendingStartNormalized ?? normalizedValue))%")

                        // Clear pending state
                        pendingCrossingTimestamp = nil
                        pendingCrossingType = nil
                        pendingStartIR = nil
                        pendingStartNormalized = nil
                        pendingStartAccel = nil
                        pendingStartTemperature = nil

                        // Add samples from debounce period to new event
                        // (approximation based on sample rate)
                        let debounceSamples = Int(Double(stateChangeDebounceMs) / 20.0) // ~50Hz
                        eventSampleCount += debounceSamples
                    }
                }
            } else {
                // New potential state change - start tracking
                pendingCrossingTimestamp = timestamp
                pendingCrossingType = potentialState
                pendingStartIR = irValue
                pendingStartNormalized = normalizedValue
                pendingStartAccel = (accelX, accelY, accelZ)
                pendingStartTemperature = temperature
            }

            // Continue updating running averages for current event
            eventIRSum += Int64(irValue)
            eventNormalizedSum += normalizedValue
            eventSampleCount += 1
            samplesDiscarded += 1
        }

        // Log status periodically
        if totalSamplesProcessed % 500 == 0 {
            let norm = calibrationManager.normalize(irValue) ?? 0
            Logger.shared.info("[EventDetector] Sample #\(totalSamplesProcessed): IR=\(irValue), norm=\(String(format: "%.1f", norm))%, state=\(currentEventType?.rawValue ?? "nil"), events=\(eventCounter)")
        }

        onSampleProcessed?()
    }

    private func startEvent(
        eventType: EventType,
        irValue: Int,
        normalizedValue: Double,
        timestamp: Date,
        accelX: Int,
        accelY: Int,
        accelZ: Int,
        temperature: Double
    ) {
        isInEvent = true
        eventStartTimestamp = timestamp
        eventStartIR = irValue
        eventStartNormalized = normalizedValue
        eventIRSum = Int64(irValue)
        eventNormalizedSum = normalizedValue
        eventSampleCount = 1
        eventStartAccel = (accelX, accelY, accelZ)
        eventStartTemperature = temperature
    }

    private func endEvent(irValue: Int, normalizedValue: Double?, timestamp: Date) {
        guard let startTimestamp = eventStartTimestamp,
              let startIR = eventStartIR,
              let accel = eventStartAccel,
              let temp = eventStartTemperature,
              let eventType = currentEventType else {
            resetEventState()
            return
        }

        // Calculate duration and filter short events (heartbeat noise)
        let durationMs = Int(timestamp.timeIntervalSince(startTimestamp) * 1000)
        guard durationMs >= minimumEventDurationMs else {
            // Event too short - discard as noise
            resetEventState()
            return
        }

        eventCounter += 1

        // Calculate averages
        let avgIR = eventSampleCount > 0 ? Double(eventIRSum) / Double(eventSampleCount) : Double(startIR)
        let avgNormalized = eventSampleCount > 0 ? eventNormalizedSum / Double(eventSampleCount) : eventStartNormalized

        // FIXED: Validation now checks from (eventStart - window) to eventEnd
        // This allows metrics received DURING the event to count for validation
        let isValid = hasValidMetricInWindow(eventStart: startTimestamp, eventEnd: timestamp)

        // Get latest metrics (up to event end time)
        let latestHR = getLatestHR(before: timestamp)
        let latestSpO2 = getLatestSpO2(before: timestamp)
        let latestSleep = getLatestSleep(before: timestamp)

        let event = MuscleActivityEvent(
            eventNumber: eventCounter,
            eventType: eventType,
            startTimestamp: startTimestamp,
            endTimestamp: timestamp,
            startIR: startIR,
            endIR: irValue,
            averageIR: avgIR,
            normalizedStartIR: eventStartNormalized,
            normalizedEndIR: normalizedValue,
            normalizedAverageIR: avgNormalized,
            baseline: baseline > 0 ? baseline : nil,
            accelX: accel.x,
            accelY: accel.y,
            accelZ: accel.z,
            temperature: temp,
            heartRate: latestHR,
            spO2: latestSpO2,
            sleepState: latestSleep,
            isValid: isValid
        )

        // Track counts
        if isValid {
            validEventCount += 1
        } else {
            invalidEventCount += 1
            onInvalidEventDetected?(event)
        }

        // ALWAYS emit the event (valid or invalid)
        onEventDetected?(event)

        resetEventState()
    }

    /// Finalize any in-progress event
    public func finalizeCurrentEvent(timestamp: Date = Date()) {
        guard isInEvent else { return }
        let normalizedEnd = calibrationManager.normalize(lastIRValue)
        endEvent(irValue: lastIRValue, normalizedValue: normalizedEnd, timestamp: timestamp)
    }

    private func resetEventState() {
        isInEvent = false
        eventStartTimestamp = nil
        eventStartIR = nil
        eventStartNormalized = nil
        eventIRSum = 0
        eventNormalizedSum = 0
        eventSampleCount = 0
        eventStartAccel = nil
        eventStartTemperature = nil
        // Clear pending state
        pendingCrossingTimestamp = nil
        pendingCrossingType = nil
        pendingStartIR = nil
        pendingStartNormalized = nil
        pendingStartAccel = nil
        pendingStartTemperature = nil
    }

    // MARK: - Positioning Detection

    /// Check if device is correctly positioned
    /// Positioned = (HR OR SpO2 OR PI) in last 3 minutes
    /// All three metrics prove the device is getting valid optical readings:
    /// - HR: Heartbeat peaks detected in PPG signal
    /// - SpO2: Valid Red/IR absorption ratio
    /// - PI: Pulsatile blood flow detected (AC/DC ratio)
    public func isDevicePositioned(at timestamp: Date) -> Bool {
        let windowStart = timestamp.addingTimeInterval(-validationWindowSeconds)

        // Check for HR reading in window
        let hasRecentHR = hrHistory.contains { entry in
            entry.timestamp >= windowStart && entry.timestamp <= timestamp
        }

        // Check for valid SpO2 reading in window (more stable during muscle activity)
        let hasRecentSpO2 = spO2History.contains { entry in
            entry.timestamp >= windowStart &&
            entry.timestamp <= timestamp &&
            entry.value >= Self.validSpO2Min
        }

        // Check for valid Perfusion Index in window (PI > 0.1%)
        let hasRecentPI = piHistory.contains { entry in
            entry.timestamp >= windowStart &&
            entry.timestamp <= timestamp &&
            entry.value >= Self.validPerfusionIndexMin
        }

        // Device is positioned if we have ANY optical proof
        // Temperature removed as positioning indicator - optical metrics are sufficient
        let hasOpticalProof = hasRecentHR || hasRecentSpO2 || hasRecentPI
        return hasOpticalProof
    }

    // MARK: - Validation Helpers

    /// Validate event by checking device positioning
    /// Device must have optical proof (HR, SpO2, or PI) in last 3 minutes
    private func hasValidMetricInWindow(eventStart: Date, eventEnd: Date) -> Bool {
        return isDevicePositioned(at: eventEnd)
    }

    private func getLatestHR(before timestamp: Date) -> Double? {
        hrHistory.filter { $0.timestamp <= timestamp }.max(by: { $0.timestamp < $1.timestamp })?.value
    }

    private func getLatestSpO2(before timestamp: Date) -> Double? {
        spO2History.filter { $0.timestamp <= timestamp }.max(by: { $0.timestamp < $1.timestamp })?.value
    }

    private func getLatestSleep(before timestamp: Date) -> SleepState? {
        sleepHistory.filter { $0.timestamp <= timestamp }.max(by: { $0.timestamp < $1.timestamp })?.state
    }

    // MARK: - Statistics

    /// Streaming statistics tuple
    public var statistics: (processed: Int, discarded: Int, eventsDetected: Int) {
        (totalSamplesProcessed, samplesDiscarded, eventCounter)
    }

    // MARK: - Reset

    /// Reset event state (keep calibration)
    public func reset() {
        resetEventState()
        currentEventType = nil
        eventCounter = 0
        totalSamplesProcessed = 0
        samplesDiscarded = 0
        validEventCount = 0
        invalidEventCount = 0
        lastIRValue = 0
        // Clear pending state
        pendingCrossingTimestamp = nil
        pendingCrossingType = nil
        pendingStartIR = nil
        pendingStartNormalized = nil
        pendingStartAccel = nil
        pendingStartTemperature = nil

        hrHistory.removeAll()
        spO2History.removeAll()
        sleepHistory.removeAll()
        temperatureHistory.removeAll()
        piHistory.removeAll()
    }

    /// Full reset including calibration
    public func fullReset() {
        reset()
        calibrationManager.reset()
        calibrationState = .notStarted
        baseline = 0
        calibrationProgress = 0
    }
}
