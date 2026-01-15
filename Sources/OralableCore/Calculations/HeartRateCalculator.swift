//
//  HeartRateCalculator.swift
//  OralableCore
//
//  Created: January 15, 2026
//  Moved from OralableApp for shared use
//
//  A robust heart rate calculator designed for reflective PPG on muscle sites.
//  Uses bandpass filtering, derivative analysis, and adaptive thresholding.
//
//  Usage:
//  ```swift
//  import OralableCore
//
//  let calculator = HeartRateCalculator()
//
//  // Real-time processing
//  if let bpm = calculator.process(irValue: Double(sample)) {
//      print("Heart rate: \(bpm) BPM")
//  }
//
//  // Batch processing
//  if let result = calculator.calculateHeartRate(irSamples: samples) {
//      print("BPM: \(result.bpm), Quality: \(result.qualityLevel)")
//  }
//  ```
//

import Foundation

// MARK: - Heart Rate Result

/// Result of heart rate calculation
public struct HeartRateResult: Sendable {
    /// Heart rate in beats per minute
    public let bpm: Double

    /// Signal quality score (0.0 to 1.0)
    public let quality: Double

    /// Human-readable quality level
    public var qualityLevel: String {
        switch quality {
        case 0.9...1.0: return "Excellent"
        case 0.8..<0.9: return "Good"
        case 0.7..<0.8: return "Fair"
        case 0.6..<0.7: return "Acceptable"
        default: return "Poor"
        }
    }

    /// Whether the quality is sufficient for reliable reading
    public var isReliable: Bool {
        quality >= 0.6
    }

    public init(bpm: Double, quality: Double) {
        self.bpm = bpm
        self.quality = quality
    }
}

// MARK: - Heart Rate Calculator

/// A robust heart rate calculator designed for reflective PPG on muscle sites.
/// Uses a combination of bandpass filtering, derivative analysis, and adaptive thresholding.
public class HeartRateCalculator {

    // MARK: - Properties

    private var irValues: [Double] = []
    private let windowSize: Int
    private let sampleRate: Double

    // Filter State
    private var lowPassValue: Double = 0
    private var highPassValue: Double = 0
    private let alphaLP: Double = 0.15  // Smoothing
    private let alphaHP: Double = 0.05  // Baseline tracking

    // Peak Detection State
    private var lastPeakTime = Date()
    private var minPeakInterval: TimeInterval = 0.4  // Max HR ~150bpm

    // Physiological limits
    private let minBPM: Int = 40
    private let maxBPM: Int = 180

    // MARK: - Initialization

    /// Initialize with configurable sample rate
    /// - Parameter sampleRate: PPG sample rate in Hz. Default 50.0 for Oralable device.
    public init(sampleRate: Double = 50.0) {
        self.sampleRate = sampleRate
        self.windowSize = Int(sampleRate * 3.0)  // ~3 seconds of data
    }

    // MARK: - Real-Time Processing

    /// Process a single IR value in real-time
    /// - Parameter irValue: Raw IR value from sensor
    /// - Returns: Heart rate in BPM if calculable, nil otherwise
    public func process(irValue: Double) -> Int? {
        // DC Offset Removal & Bandpass Filter
        highPassValue = alphaHP * (highPassValue + irValue - (irValues.last ?? irValue))
        lowPassValue = lowPassValue + alphaLP * (highPassValue - lowPassValue)

        irValues.append(lowPassValue)

        if irValues.count > windowSize {
            irValues.removeFirst()
        }

        guard irValues.count >= windowSize else {
            return nil
        }

        return calculateHeartRateFromWindow()
    }

    // MARK: - Batch Processing

    /// Batch API: feed a set of raw IR samples and compute BPM and quality score
    /// - Parameter irSamples: Raw IR samples (UInt32) from the sensor
    /// - Returns: HeartRateResult with bpm and quality, or nil if insufficient/poor signal
    public func calculateHeartRate(irSamples: [UInt32]) -> HeartRateResult? {
        guard !irSamples.isEmpty else { return nil }

        // Reset state for batch processing
        irValues.removeAll(keepingCapacity: true)
        lowPassValue = 0
        highPassValue = 0

        // Feed samples through the filter
        for sample in irSamples {
            let value = Double(sample)
            highPassValue = alphaHP * (highPassValue + value - (irValues.last ?? value))
            lowPassValue = lowPassValue + alphaLP * (highPassValue - lowPassValue)
            irValues.append(lowPassValue)
        }

        // Require minimum window
        guard irValues.count >= windowSize else { return nil }

        return calculateHeartRateWithQuality()
    }

    /// Batch API with Double values
    /// - Parameter samples: Pre-converted Double samples
    /// - Returns: HeartRateResult with bpm and quality, or nil if insufficient/poor signal
    public func calculateHeartRate(samples: [Double]) -> HeartRateResult? {
        guard !samples.isEmpty else { return nil }

        // Reset state for batch processing
        irValues.removeAll(keepingCapacity: true)
        lowPassValue = 0
        highPassValue = 0

        // Feed samples through the filter
        for value in samples {
            highPassValue = alphaHP * (highPassValue + value - (irValues.last ?? value))
            lowPassValue = lowPassValue + alphaLP * (highPassValue - lowPassValue)
            irValues.append(lowPassValue)
        }

        // Require minimum window
        guard irValues.count >= windowSize else { return nil }

        return calculateHeartRateWithQuality()
    }

    // MARK: - Private Methods

    private func calculateHeartRateFromWindow() -> Int? {
        let signal = irValues

        // Adaptive threshold based on signal's standard deviation
        let mean = signal.reduce(0, +) / Double(signal.count)
        let sumSquaredDiff = signal.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(signal.count))

        // If signal is too flat, quality is poor
        if stdDev < 1.0 {
            return nil
        }

        let threshold = mean + (stdDev * 0.6)

        // Find peaks
        var peaks: [Int] = []
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            if current > signal[i-1] && current > signal[i+1] && current > threshold {
                peaks.append(i)
            }
        }

        guard peaks.count >= 2 else { return nil }

        // Calculate intervals
        var intervals: [Double] = []
        for j in 1..<peaks.count {
            let intervalSamples = Double(peaks[j] - peaks[j-1])
            let intervalSeconds = intervalSamples / sampleRate
            // Physiological filter: 40bpm to 180bpm
            if intervalSeconds > 0.33 && intervalSeconds < 1.5 {
                intervals.append(intervalSeconds)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // Use median to filter outliers
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        let bpm = Int(60.0 / medianInterval)

        return (minBPM...maxBPM).contains(bpm) ? bpm : nil
    }

    private func calculateHeartRateWithQuality() -> HeartRateResult? {
        let signal = irValues

        let mean = signal.reduce(0, +) / Double(signal.count)
        let sumSquaredDiff = signal.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(signal.count))

        if stdDev < 1.0 {
            return nil
        }

        let threshold = mean + (stdDev * 0.6)

        var peaks: [Int] = []
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            if current > signal[i-1] && current > signal[i+1] && current > threshold {
                peaks.append(i)
            }
        }

        guard peaks.count >= 2 else { return nil }

        var intervals: [Double] = []
        for j in 1..<peaks.count {
            let intervalSamples = Double(peaks[j] - peaks[j-1])
            let intervalSeconds = intervalSamples / sampleRate
            if intervalSeconds > 0.33 && intervalSeconds < 1.5 {
                intervals.append(intervalSeconds)
            }
        }

        guard !intervals.isEmpty else { return nil }

        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        let bpm = Int(60.0 / medianInterval)

        guard (minBPM...maxBPM).contains(bpm) else { return nil }

        // Calculate quality metric
        let acdc = max(0.0, min(1.0, stdDev / max(1.0, abs(mean))))
        let peakFactor = max(0.0, min(1.0, Double(intervals.count) / 10.0))
        let quality = max(0.0, min(1.0, 0.6 * acdc + 0.4 * peakFactor))

        return HeartRateResult(bpm: Double(bpm), quality: quality)
    }

    // MARK: - Reset

    /// Reset the calculator state
    public func reset() {
        irValues.removeAll()
        lowPassValue = 0
        highPassValue = 0
    }
}
