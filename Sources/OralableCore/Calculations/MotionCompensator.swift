//
//  MotionCompensator.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Adaptive LMS filter for motion artifact compensation in PPG signals
//

import Foundation

/// Adaptive LMS (Least Mean Squares) filter for motion compensation in PPG signals.
/// Uses accelerometer data as a noise reference to subtract motion artifacts from the PPG signal.
public final class MotionCompensator: @unchecked Sendable {
    // MARK: - Configuration

    /// Size of the filter history
    private let historySize: Int

    /// LMS learning rate (mu) - controls adaptation speed
    private let learningRate: Double

    /// Variance threshold for excessive motion detection
    private let varianceThreshold: Double

    // MARK: - State

    private var weights: [Double]
    private var noiseHistory: [Double]
    private let lock = NSLock()

    // MARK: - Initialization

    /// Initialize the motion compensator with configurable parameters
    /// - Parameters:
    ///   - historySize: Filter tap length (default: 32)
    ///   - learningRate: LMS learning rate mu (default: 0.01)
    ///   - varianceThreshold: Variance threshold for motion dampening (default: 1.0)
    public init(
        historySize: Int = 32,
        learningRate: Double = 0.01,
        varianceThreshold: Double = 1.0
    ) {
        self.historySize = historySize
        self.learningRate = learningRate
        self.varianceThreshold = varianceThreshold
        self.weights = Array(repeating: 0.0, count: historySize)
        self.noiseHistory = Array(repeating: 0.0, count: historySize)
    }

    // MARK: - Filtering

    /// Filters the signal by subtracting the adaptive noise estimate.
    /// - Parameters:
    ///   - signal: The primary signal containing desired data plus noise (e.g., PPG)
    ///   - noiseReference: The reference noise signal (e.g., accelerometer magnitude deviation)
    /// - Returns: The filtered signal with motion artifacts reduced
    public func filter(signal: Double, noiseReference: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }

        // Update noise history (shift and insert new sample)
        noiseHistory.removeLast()
        noiseHistory.insert(noiseReference, at: 0)

        // Variance check for excessive motion
        let variance = calculateVariance(noiseHistory)

        if variance > varianceThreshold {
            // Excessive motion detected; dampen the signal significantly
            return signal * 0.01
        }

        // LMS Adaptive Filter
        // Calculate noise estimate using current weights
        var noiseEstimate: Double = 0.0
        for i in 0..<historySize {
            noiseEstimate += weights[i] * noiseHistory[i]
        }

        // Error is the filtered output
        let error = signal - noiseEstimate

        // Update weights using LMS rule: w(n+1) = w(n) + mu * e(n) * x(n)
        for i in 0..<historySize {
            weights[i] += learningRate * error * noiseHistory[i]
        }

        return error
    }

    /// Resets the internal filter state (weights and noise history).
    /// Call this when the sensor is re-attached or when starting a new measurement session.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        weights = Array(repeating: 0.0, count: historySize)
        noiseHistory = Array(repeating: 0.0, count: historySize)
    }

    // MARK: - Private Methods

    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    }
}
