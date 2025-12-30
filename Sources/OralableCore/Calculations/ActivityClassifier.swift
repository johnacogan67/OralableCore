//
//  ActivityClassifier.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Classifies oral activity based on IR PPG and accelerometer data
//

import Foundation

/// Classifies oral activity (relaxed, clenching, grinding, motion)
/// based on IR PPG signal deviation and accelerometer magnitude.
public final class ActivityClassifier: @unchecked Sendable {
    // MARK: - Configuration

    /// Size of the history buffer for variance calculation
    private let historySize: Int

    /// Accelerometer magnitude threshold for motion detection (in g)
    private let motionThreshold: Double

    /// IR signal deviation threshold for activity detection
    private let deviationThreshold: Double

    /// Variance threshold to distinguish grinding from clenching
    private let grindingVarianceThreshold: Double

    // MARK: - State

    private var irHistory: [Double]
    private var baseline: Double = 0.0
    private var isBaselineInitialized = false
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initialize the activity classifier with configurable thresholds
    /// - Parameters:
    ///   - historySize: Number of samples to keep for variance calculation (default: 32)
    ///   - motionThreshold: Accelerometer magnitude threshold for motion detection in g (default: 1.15)
    ///   - deviationThreshold: IR signal deviation threshold for activity detection (default: 5000.0)
    ///   - grindingVarianceThreshold: Variance threshold to distinguish grinding from clenching (default: 1000.0)
    public init(
        historySize: Int = 32,
        motionThreshold: Double = 1.15,
        deviationThreshold: Double = 5000.0,
        grindingVarianceThreshold: Double = 1000.0
    ) {
        self.historySize = historySize
        self.motionThreshold = motionThreshold
        self.deviationThreshold = deviationThreshold
        self.grindingVarianceThreshold = grindingVarianceThreshold
        self.irHistory = []
        self.irHistory.reserveCapacity(historySize)
    }

    // MARK: - Classification

    /// Classifies the current activity based on IR and accelerometer data.
    /// - Parameters:
    ///   - ir: The infrared PPG signal value
    ///   - accMagnitude: The magnitude of the accelerometer vector (in g, ~1.0 = stationary)
    /// - Returns: The detected ActivityType
    public func classify(ir: Double, accMagnitude: Double) -> ActivityType {
        lock.lock()
        defer { lock.unlock() }

        // Initialize baseline with the first sample if needed
        if !isBaselineInitialized {
            baseline = ir
            isBaselineInitialized = true
        }

        // Update IR history for variance calculation
        if irHistory.count >= historySize {
            irHistory.removeFirst()
        }
        irHistory.append(ir)

        // 1. Check for Motion (highest priority)
        if accMagnitude > motionThreshold {
            return .motion
        }

        // 2. Check for Deviation from Baseline
        let deviation = abs(ir - baseline)

        if deviation > deviationThreshold {
            // Calculate variance of the signal history
            let variance = calculateVariance(irHistory)

            // High variance indicates grinding; low variance indicates clenching
            if variance > grindingVarianceThreshold {
                return .grinding
            } else {
                return .clenching
            }
        } else {
            // 3. Relaxed State
            // Slowly adapt baseline to account for drift
            baseline = (baseline * 0.95) + (ir * 0.05)
            return .relaxed
        }
    }

    /// Reset the classifier state
    /// Call this when starting a new session or when the device is reattached
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        irHistory.removeAll(keepingCapacity: true)
        baseline = 0.0
        isBaselineInitialized = false
    }

    // MARK: - Private Methods

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    }
}
