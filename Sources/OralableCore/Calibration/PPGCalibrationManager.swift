//
//  PPGCalibrationManager.swift
//  OralableCore
//
//  Created: January 13, 2026
//
//  Manages baseline calibration for PPG IR normalization.
//
//  Calibration Process:
//  1. User remains still for 15 seconds
//  2. Collect PPG IR samples during this period
//  3. Calculate baseline as median value
//  4. Validate stability (coefficient of variation < 150%)
//
//  After calibration, IR values are normalized as:
//  Normalized = (Current IR - Baseline) / Baseline × 100
//
//  This allows threshold to be set as percentage (e.g., 40%)
//  which works consistently across different users and placements.
//

import Foundation
import Combine

// MARK: - Calibration State

/// State of PPG calibration
public enum CalibrationState: Equatable, Sendable {
    case notStarted
    case calibrating(progress: Double)
    case calibrated(baseline: Double)
    case failed(reason: String)

    public var isCalibrated: Bool {
        if case .calibrated = self { return true }
        return false
    }

    public var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }

    public var statusText: String {
        switch self {
        case .notStarted:
            return "Not Calibrated"
        case .calibrating(let progress):
            return "Calibrating \(Int(progress * 100))%"
        case .calibrated(let baseline):
            return "Calibrated (\(Int(baseline)))"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }
}

// MARK: - PPGCalibrationManager

/// Manages baseline calibration for PPG IR normalization
public class PPGCalibrationManager: ObservableObject {

    // MARK: - Configuration

    /// Duration of calibration period in seconds
    public var calibrationDuration: TimeInterval = 15.0

    /// Minimum samples required for valid calibration (at 50 Hz)
    public var minimumSamples: Int = 500

    /// Maximum coefficient of variation for stable signal
    /// Note: Real PPG signals naturally vary 30-100% due to heartbeat, respiration, and motion
    public var maxCoefficientOfVariation: Double = 1.5  // 150% - allows for normal PPG variability

    /// Minimum valid IR value
    public var minValidIR: Int = 10000

    /// Maximum valid IR value
    public var maxValidIR: Int = 5_000_000

    // MARK: - Published State

    @Published public private(set) var state: CalibrationState = .notStarted
    @Published public private(set) var baseline: Double = 0
    @Published public private(set) var progress: Double = 0

    // MARK: - Internal State

    private var calibrationSamples: [Int] = []
    private var calibrationStartTime: Date?

    // MARK: - Callbacks

    public var onCalibrationComplete: ((Double) -> Void)?
    public var onCalibrationFailed: ((String) -> Void)?
    public var onProgressUpdate: ((Double) -> Void)?

    // MARK: - Init

    public init(calibrationDuration: TimeInterval = 15.0) {
        self.calibrationDuration = calibrationDuration
    }

    // MARK: - Calibration Control

    /// Start calibration - user should remain still
    public func startCalibration() {
        calibrationSamples.removeAll()
        calibrationSamples.reserveCapacity(Int(calibrationDuration * 55))  // ~50 Hz + buffer
        calibrationStartTime = Date()
        state = .calibrating(progress: 0)
        progress = 0

        Logger.shared.info("[PPGCalibrationManager] Calibration started (duration: \(calibrationDuration)s)")
    }

    /// Cancel ongoing calibration
    public func cancelCalibration() {
        state = .notStarted
        calibrationSamples.removeAll()
        calibrationStartTime = nil
        progress = 0

        Logger.shared.info("[PPGCalibrationManager] Calibration cancelled")
    }

    /// Reset all calibration state
    public func reset() {
        state = .notStarted
        baseline = 0
        progress = 0
        calibrationSamples.removeAll()
        calibrationStartTime = nil

        Logger.shared.info("[PPGCalibrationManager] Calibration reset")
    }

    // MARK: - Sample Collection

    /// Add a sample during calibration
    /// - Parameter irValue: Raw PPG IR value
    /// - Returns: true if calibration is still in progress
    @discardableResult
    public func addCalibrationSample(_ irValue: Int) -> Bool {
        guard case .calibrating = state else { return false }

        // Validate sample is in reasonable range
        guard irValue >= minValidIR && irValue <= maxValidIR else {
            Logger.shared.debug("[PPGCalibrationManager] Skipping invalid sample: \(irValue)")
            return true  // Continue calibration
        }

        calibrationSamples.append(irValue)

        // Update progress
        if let startTime = calibrationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let newProgress = min(elapsed / calibrationDuration, 1.0)
            progress = newProgress
            state = .calibrating(progress: newProgress)
            onProgressUpdate?(newProgress)

            // Check if calibration complete
            if elapsed >= calibrationDuration {
                completeCalibration()
                return false
            }
        }

        return true
    }

    // MARK: - Calibration Completion

    private func completeCalibration() {
        Logger.shared.info("[PPGCalibrationManager] Processing \(calibrationSamples.count) samples")

        // Check minimum samples
        guard calibrationSamples.count >= minimumSamples else {
            let reason = "Insufficient samples (\(calibrationSamples.count)/\(minimumSamples))"
            failCalibration(reason: reason)
            return
        }

        // Sort for median calculation
        let sorted = calibrationSamples.sorted()
        let count = sorted.count

        // Calculate median (more robust than mean)
        let median: Double
        if count % 2 == 0 {
            median = Double(sorted[count/2 - 1] + sorted[count/2]) / 2.0
        } else {
            median = Double(sorted[count/2])
        }

        // Calculate mean and standard deviation for stability check
        let sum = calibrationSamples.reduce(0, +)
        let mean = Double(sum) / Double(count)

        let squaredDiffs = calibrationSamples.map { pow(Double($0) - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(count)
        let stdDev = sqrt(variance)

        // Check coefficient of variation (CV = stdDev / mean)
        let cv = stdDev / mean

        Logger.shared.info("[PPGCalibrationManager] Stats: median=\(Int(median)), mean=\(Int(mean)), stdDev=\(Int(stdDev)), CV=\(String(format: "%.0f%%", cv * 100))")

        // Log warning for high CV but continue (PPG signals naturally have high variability)
        if cv > 0.50 {
            Logger.shared.warning("[PPGCalibrationManager] High CV: \(String(format: "%.0f%%", cv * 100)) - continuing anyway")
        }

        if cv > maxCoefficientOfVariation {
            let reason = "Signal unstable (CV: \(String(format: "%.0f%%", cv * 100))). Please remain still."
            failCalibration(reason: reason)
            return
        }

        // Validate baseline is in reasonable range
        guard median >= Double(minValidIR) && median <= Double(maxValidIR) else {
            let reason = "Invalid baseline value (\(Int(median)))"
            failCalibration(reason: reason)
            return
        }

        // Success!
        baseline = median
        state = .calibrated(baseline: baseline)
        progress = 1.0

        Logger.shared.info("[PPGCalibrationManager] Calibration complete: baseline = \(Int(baseline))")
        onCalibrationComplete?(baseline)
    }

    private func failCalibration(reason: String) {
        state = .failed(reason: reason)
        Logger.shared.warning("[PPGCalibrationManager] Calibration failed: \(reason)")
        onCalibrationFailed?(reason)
    }

    // MARK: - Normalization

    /// Normalize an IR value to percentage change from baseline
    /// - Parameter irValue: Raw PPG IR value
    /// - Returns: Percentage change from baseline, or nil if not calibrated
    public func normalize(_ irValue: Int) -> Double? {
        guard case .calibrated(let baseline) = state, baseline > 0 else {
            return nil
        }

        return (Double(irValue) - baseline) / baseline * 100.0
    }

    /// Check if normalized value exceeds threshold
    /// - Parameters:
    ///   - irValue: Raw PPG IR value
    ///   - thresholdPercent: Threshold as percentage above baseline
    /// - Returns: true if above threshold, false otherwise or if not calibrated
    public func isAboveThreshold(_ irValue: Int, thresholdPercent: Double) -> Bool {
        guard let normalized = normalize(irValue) else {
            return false
        }
        return normalized > thresholdPercent
    }

    /// Convert threshold percentage to absolute IR value
    /// - Parameter thresholdPercent: Threshold as percentage
    /// - Returns: Absolute IR threshold, or nil if not calibrated
    public func thresholdToAbsolute(_ thresholdPercent: Double) -> Int? {
        guard case .calibrated(let baseline) = state, baseline > 0 else {
            return nil
        }
        return Int(baseline * (1.0 + thresholdPercent / 100.0))
    }

    // MARK: - Statistics

    public var calibrationStatistics: (sampleCount: Int, baseline: Double, isCalibrated: Bool) {
        (calibrationSamples.count, baseline, state.isCalibrated)
    }
}
