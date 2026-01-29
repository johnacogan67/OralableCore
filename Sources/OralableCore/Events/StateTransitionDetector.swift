//
//  StateTransitionDetector.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  State machine for detecting device recording state transitions.
//
//  States:
//  - DataStreaming: Device connected, receiving data, not positioned
//  - Positioned: Device on skin with valid optical metrics
//  - Activity: Calibrated and detecting muscle activity above threshold
//
//  Debounce Timers (to prevent rapid oscillations):
//  - DataStreaming → Positioned: 2000ms
//  - Positioned → Activity: 1000ms
//  - Activity → Positioned: 1000ms
//  - Positioned → DataStreaming: 3000ms
//

import Foundation
import Combine

// MARK: - State Transition Detector

/// Detects device state transitions based on sensor data
public class StateTransitionDetector: ObservableObject {

    // MARK: - Debounce Configuration (milliseconds)

    /// Debounce time for DataStreaming → Positioned transition
    public var debounceDataStreamingToPositioned: Int = 2000

    /// Debounce time for Positioned → Activity transition
    public var debouncePositionedToActivity: Int = 1000

    /// Debounce time for Activity → Positioned transition
    public var debounceActivityToPositioned: Int = 1000

    /// Debounce time for Positioned → DataStreaming transition
    public var debouncePositionedToDataStreaming: Int = 3000

    // MARK: - Thresholds

    /// Normalized IR threshold for Activity detection (percentage above baseline)
    public var activityThresholdPercent: Double = 40.0

    /// Minimum heart rate to consider device positioned
    public var minHeartRateForPositioned: Int = 30

    /// Minimum SpO2 to consider device positioned
    public var minSpO2ForPositioned: Double = 70.0

    /// Minimum perfusion index to consider device positioned
    public var minPerfusionIndexForPositioned: Double = 0.001

    // MARK: - Published State

    @Published public private(set) var currentState: DeviceRecordingState = .dataStreaming
    @Published public private(set) var isCalibrated: Bool = false
    @Published public private(set) var baseline: Double = 0

    // MARK: - Calibration Manager

    public let calibrationManager = PPGCalibrationManager()

    // MARK: - Callbacks

    /// Called when state transitions
    public var onStateTransition: ((DeviceRecordingState, DeviceRecordingState) -> Void)?

    /// Called when calibration completes
    public var onCalibrationComplete: ((Double) -> Void)?

    /// Called when calibration fails
    public var onCalibrationFailed: ((String) -> Void)?

    // MARK: - Private State

    private var pendingState: DeviceRecordingState?
    private var pendingStateStartTime: Date?

    /// Current metrics for positioning detection
    private var currentHeartRate: Double = 0
    private var currentSpO2: Double = 0
    private var currentPerfusionIndex: Double = 0
    private var lastMetricUpdateTime: Date = Date.distantPast

    /// Metric validity window (3 minutes)
    private let metricValiditySeconds: TimeInterval = 180

    // MARK: - Initialization

    public init() {
        setupCalibrationCallbacks()
    }

    private func setupCalibrationCallbacks() {
        calibrationManager.onCalibrationComplete = { [weak self] baseline in
            guard let self = self else { return }
            self.baseline = baseline
            self.isCalibrated = true
            Logger.shared.info("[StateTransitionDetector] Calibration complete, baseline: \(Int(baseline))")
            self.onCalibrationComplete?(baseline)
        }

        calibrationManager.onCalibrationFailed = { [weak self] reason in
            guard let self = self else { return }
            Logger.shared.warning("[StateTransitionDetector] Calibration failed: \(reason)")
            self.onCalibrationFailed?(reason)
        }
    }

    // MARK: - Calibration Control

    /// Start calibration
    public func startCalibration() {
        calibrationManager.startCalibration()
        Logger.shared.info("[StateTransitionDetector] Starting calibration")
    }

    /// Cancel calibration
    public func cancelCalibration() {
        calibrationManager.cancelCalibration()
    }

    /// Reset calibration
    public func resetCalibration() {
        calibrationManager.reset()
        isCalibrated = false
        baseline = 0
    }

    // MARK: - Metric Updates

    /// Update heart rate value
    public func updateHeartRate(_ hr: Double) {
        currentHeartRate = hr
        lastMetricUpdateTime = Date()
    }

    /// Update SpO2 value
    public func updateSpO2(_ spo2: Double) {
        currentSpO2 = spo2
        lastMetricUpdateTime = Date()
    }

    /// Update perfusion index
    public func updatePerfusionIndex(_ pi: Double) {
        currentPerfusionIndex = pi
        lastMetricUpdateTime = Date()
    }

    // MARK: - State Evaluation

    /// Evaluate state based on current sensor data
    /// Call this with each sensor sample
    public func evaluateState(
        irValue: Int,
        timestamp: Date,
        heartRate: Double? = nil,
        spO2: Double? = nil,
        perfusionIndex: Double? = nil
    ) -> (newState: DeviceRecordingState, didTransition: Bool) {
        // Update metrics if provided
        if let hr = heartRate {
            updateHeartRate(hr)
        }
        if let spo2 = spO2 {
            updateSpO2(spo2)
        }
        if let pi = perfusionIndex {
            updatePerfusionIndex(pi)
        }

        // During calibration, just collect samples
        if calibrationManager.state.isCalibrating {
            calibrationManager.addCalibrationSample(irValue)
            return (currentState, false)
        }

        // Determine target state based on sensor data
        let targetState = determineTargetState(irValue: irValue, timestamp: timestamp)

        // Check if state change is needed
        if targetState == currentState {
            // Same state - clear pending
            pendingState = nil
            pendingStateStartTime = nil
            return (currentState, false)
        }

        // State change detected - check if we're already tracking this pending change
        if pendingState == targetState, let startTime = pendingStateStartTime {
            // Calculate elapsed time
            let elapsedMs = Int(timestamp.timeIntervalSince(startTime) * 1000)
            let requiredDebounce = getDebounceTime(from: currentState, to: targetState)

            if elapsedMs >= requiredDebounce {
                // Debounce period complete - commit state change
                let previousState = currentState
                currentState = targetState

                // Clear pending state
                pendingState = nil
                pendingStateStartTime = nil

                Logger.shared.info("[StateTransitionDetector] State transition: \(previousState.rawValue) → \(targetState.rawValue)")
                onStateTransition?(previousState, targetState)

                return (currentState, true)
            }

            // Still in debounce period
            return (currentState, false)
        } else {
            // New pending state change
            pendingState = targetState
            pendingStateStartTime = timestamp
            return (currentState, false)
        }
    }

    /// Determine target state based on sensor data
    private func determineTargetState(irValue: Int, timestamp: Date) -> DeviceRecordingState {
        // Check if device is positioned (valid optical metrics)
        let isPositioned = checkIsPositioned(timestamp: timestamp)

        if !isPositioned {
            return .dataStreaming
        }

        // Device is positioned - check for activity
        if isCalibrated {
            // Check if IR is above activity threshold
            if let normalized = calibrationManager.normalize(irValue) {
                if normalized > activityThresholdPercent {
                    return .activity
                }
            }
        }

        // Positioned but no activity (or not calibrated)
        return .positioned
    }

    /// Check if device is positioned based on optical metrics
    private func checkIsPositioned(timestamp: Date) -> Bool {
        let cutoff = timestamp.addingTimeInterval(-metricValiditySeconds)

        // Check if we have recent metrics
        guard lastMetricUpdateTime > cutoff else {
            return false
        }

        // Check HR
        if currentHeartRate >= Double(minHeartRateForPositioned) {
            return true
        }

        // Check SpO2
        if currentSpO2 >= minSpO2ForPositioned {
            return true
        }

        // Check Perfusion Index
        if currentPerfusionIndex >= minPerfusionIndexForPositioned {
            return true
        }

        return false
    }

    /// Get debounce time for a state transition
    private func getDebounceTime(from: DeviceRecordingState, to: DeviceRecordingState) -> Int {
        switch (from, to) {
        case (.dataStreaming, .positioned):
            return debounceDataStreamingToPositioned
        case (.positioned, .activity):
            return debouncePositionedToActivity
        case (.activity, .positioned):
            return debounceActivityToPositioned
        case (.positioned, .dataStreaming):
            return debouncePositionedToDataStreaming
        case (.dataStreaming, .activity):
            // Direct transition - use sum of intermediate debounces
            return debounceDataStreamingToPositioned + debouncePositionedToActivity
        case (.activity, .dataStreaming):
            // Direct transition - use sum of intermediate debounces
            return debounceActivityToPositioned + debouncePositionedToDataStreaming
        default:
            // Same state - no debounce needed
            return 0
        }
    }

    // MARK: - Reset

    /// Reset detector state
    public func reset() {
        currentState = .dataStreaming
        pendingState = nil
        pendingStateStartTime = nil
        currentHeartRate = 0
        currentSpO2 = 0
        currentPerfusionIndex = 0
        lastMetricUpdateTime = Date.distantPast

        Logger.shared.info("[StateTransitionDetector] Reset to initial state")
    }

    /// Full reset including calibration
    public func fullReset() {
        reset()
        resetCalibration()
    }

    // MARK: - State Queries

    /// Whether device is currently positioned
    public var isDevicePositioned: Bool {
        currentState == .positioned || currentState == .activity
    }

    /// Whether device is detecting activity
    public var isDetectingActivity: Bool {
        currentState == .activity
    }

    /// Current state as string
    public var stateDescription: String {
        currentState.displayName
    }
}
