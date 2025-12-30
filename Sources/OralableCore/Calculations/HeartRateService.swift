//
//  HeartRateService.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Dedicated heart rate extraction from cleaned PPG signals
//  Uses peak detection with bandpass filtering
//

import Foundation

// MARK: - Heart Rate Result

/// Result from heart rate calculation
public struct HRResult: Sendable, Equatable {
    /// Heart rate in beats per minute (0 if unavailable)
    public let bpm: Int

    /// Confidence score (0.0 to 1.0)
    public let confidence: Double

    /// Whether device is detected as worn
    public let isWorn: Bool

    /// Number of peaks used in calculation
    public let peakCount: Int

    /// Heart rate variability in milliseconds (if available)
    public let hrvMs: Double?

    public init(
        bpm: Int,
        confidence: Double,
        isWorn: Bool,
        peakCount: Int = 0,
        hrvMs: Double? = nil
    ) {
        self.bpm = bpm
        self.confidence = min(1.0, max(0.0, confidence))
        self.isWorn = isWorn
        self.peakCount = peakCount
        self.hrvMs = hrvMs
    }

    /// Empty result when no valid HR can be calculated
    public static let empty = HRResult(bpm: 0, confidence: 0, isWorn: false)

    /// Whether result has valid heart rate
    public var isValid: Bool {
        bpm >= 40 && bpm <= 200 && confidence > 0.5
    }
}

// MARK: - Heart Rate Service

/// Service for extracting heart rate from cleaned PPG signals
/// Expects signal data that has already been processed by MotionCompensator
public actor HeartRateService {

    // MARK: - Configuration

    /// Minimum valid heart rate (BPM)
    private let minBPM: Double

    /// Maximum valid heart rate (BPM)
    private let maxBPM: Double

    /// Sample rate in Hz
    private let sampleRate: Double

    /// Window size in samples (for buffering)
    private let windowSize: Int

    /// Minimum peak interval in samples (based on maxBPM)
    private var minPeakInterval: Int {
        Int(sampleRate * 60.0 / maxBPM * 0.8)  // 80% of minimum interval
    }

    /// Minimum peaks required for valid HR
    private let minPeaksRequired: Int

    /// Peak amplitude threshold multiplier
    private let peakThreshold: Double

    // MARK: - Internal Buffer

    private var buffer: [Double] = []

    // MARK: - Initialization

    /// Initialize with configuration
    /// - Parameters:
    ///   - sampleRate: Signal sample rate in Hz (default: 50)
    ///   - windowSeconds: Buffer window in seconds (default: 5)
    ///   - minBPM: Minimum valid BPM (default: 40)
    ///   - maxBPM: Maximum valid BPM (default: 180)
    ///   - minPeaks: Minimum peaks for valid result (default: 4)
    ///   - peakThreshold: Peak detection threshold multiplier (default: 0.4)
    public init(
        sampleRate: Double = 50.0,
        windowSeconds: Double = 5.0,
        minBPM: Double = 40.0,
        maxBPM: Double = 180.0,
        minPeaks: Int = 4,
        peakThreshold: Double = 0.4
    ) {
        self.sampleRate = sampleRate
        self.windowSize = Int(sampleRate * windowSeconds)
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.minPeaksRequired = minPeaks
        self.peakThreshold = peakThreshold

        self.buffer.reserveCapacity(windowSize)
    }

    // MARK: - Processing

    /// Process a batch of cleaned samples (typically Green channel)
    /// - Parameter samples: Array of cleaned PPG samples
    /// - Returns: HRResult with BPM, confidence, and worn status
    public func process(samples: [Double]) -> HRResult {
        // Add samples to buffer
        buffer.append(contentsOf: samples)

        // Maintain fixed window size
        if buffer.count > windowSize {
            buffer.removeFirst(buffer.count - windowSize)
        }

        // Wait for buffer to fill before processing
        guard buffer.count >= windowSize else {
            return .empty
        }

        // Stage 1: Bandpass filter (0.5Hz - 4Hz)
        let filtered = applyBandpassFilter(buffer)

        // Stage 2: Peak detection
        let peaks = findPeaks(in: filtered)

        // Stage 3: Calculate BPM and confidence
        let (bpm, confidence, hrvMs) = calculateBPM(from: peaks)

        // Stage 4: Perfusion check (worn status)
        let isWorn = checkWornStatus(bpm: bpm, confidence: confidence, filtered: filtered)

        return HRResult(
            bpm: bpm,
            confidence: confidence,
            isWorn: isWorn,
            peakCount: peaks.count,
            hrvMs: hrvMs
        )
    }

    /// Process a single sample (for real-time streaming)
    /// - Parameter sample: Single cleaned PPG sample
    /// - Returns: HRResult (may be empty if buffer not full)
    public func processSingle(_ sample: Double) -> HRResult {
        return process(samples: [sample])
    }

    /// Reset the buffer and internal state
    public func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    /// Get current buffer fill level (0.0 to 1.0)
    public var bufferFillLevel: Double {
        Double(buffer.count) / Double(windowSize)
    }

    // MARK: - Signal Processing

    /// Apply bandpass filter to isolate heart rate frequencies
    /// Focuses on 0.5Hz - 4Hz (30-240 BPM range)
    private func applyBandpassFilter(_ data: [Double]) -> [Double] {
        guard data.count > 4 else { return data }

        // Remove DC component (high-pass)
        let mean = data.reduce(0, +) / Double(data.count)
        let centered = data.map { $0 - mean }

        // Apply smoothing (low-pass) with 5-point moving average
        var smoothed = centered
        for i in 2..<(centered.count - 2) {
            smoothed[i] = (centered[i-2] + centered[i-1] + centered[i] +
                          centered[i+1] + centered[i+2]) / 5.0
        }

        return smoothed
    }

    /// Find peaks in filtered signal
    private func findPeaks(in data: [Double]) -> [Int] {
        guard data.count > 2 else { return [] }

        var peaks: [Int] = []

        // Calculate threshold based on signal amplitude
        let maxValue = data.max() ?? 0
        let minValue = data.min() ?? 0
        let amplitude = maxValue - minValue
        let threshold = minValue + amplitude * peakThreshold

        for i in 1..<(data.count - 1) {
            // Check if this is a local maximum above threshold
            if data[i] > data[i-1] && data[i] > data[i+1] && data[i] > threshold {
                // Ensure peaks are at least minPeakInterval apart
                if let lastPeak = peaks.last {
                    if (i - lastPeak) < minPeakInterval {
                        continue
                    }
                }
                peaks.append(i)
            }
        }

        return peaks
    }

    /// Calculate BPM from peak positions
    private func calculateBPM(from peaks: [Int]) -> (bpm: Int, confidence: Double, hrvMs: Double?) {
        guard peaks.count >= minPeaksRequired else {
            return (0, 0.0, nil)
        }

        // Calculate inter-peak intervals
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let interval = Double(peaks[i] - peaks[i-1])
            intervals.append(interval)
        }

        guard !intervals.isEmpty else {
            return (0, 0.0, nil)
        }

        // Calculate average interval and BPM
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let bpm = 60.0 / (avgInterval / sampleRate)

        // Validate BPM range
        guard bpm >= minBPM && bpm <= maxBPM else {
            return (0, 0.0, nil)
        }

        // Calculate confidence based on interval regularity
        let variance = intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        let confidence = max(0, min(1.0, 1.0 - (stdDev / avgInterval)))

        // Calculate HRV (RMSSD - Root Mean Square of Successive Differences)
        var hrvMs: Double? = nil
        if intervals.count > 1 {
            var successiveDiffs: [Double] = []
            for i in 1..<intervals.count {
                let diff = intervals[i] - intervals[i-1]
                successiveDiffs.append(diff * diff)
            }
            let rmssd = sqrt(successiveDiffs.reduce(0, +) / Double(successiveDiffs.count))
            hrvMs = (rmssd / sampleRate) * 1000.0  // Convert to milliseconds
        }

        return (Int(bpm.rounded()), confidence, hrvMs)
    }

    /// Check worn status based on signal characteristics
    private func checkWornStatus(bpm: Int, confidence: Double, filtered: [Double]) -> Bool {
        // Calculate AC/DC ratio (perfusion index)
        let dc = buffer.reduce(0, +) / Double(buffer.count)
        let ac = filtered.map { abs($0) }.reduce(0, +) / Double(filtered.count)

        // AC/DC ratio > 0.001 usually indicates pulsatile blood flow
        let hasBloodFlow = dc > 0 ? (ac / dc) > 0.001 : false

        return bpm > 0 && confidence > 0.5 && hasBloodFlow
    }
}

// MARK: - Factory Methods

extension HeartRateService {

    /// Create service configured for Oralable device (50 Hz)
    public static func oralable() -> HeartRateService {
        HeartRateService(
            sampleRate: 50.0,
            windowSeconds: 5.0,
            minBPM: 40.0,
            maxBPM: 180.0
        )
    }

    /// Create service configured for ANR device (100 Hz)
    public static func anr() -> HeartRateService {
        HeartRateService(
            sampleRate: 100.0,
            windowSeconds: 5.0,
            minBPM: 40.0,
            maxBPM: 180.0
        )
    }

    /// Create service for demo mode (fast response)
    public static func demo() -> HeartRateService {
        HeartRateService(
            sampleRate: 50.0,
            windowSeconds: 2.0,
            minBPM: 40.0,
            maxBPM: 200.0,
            minPeaks: 3,
            peakThreshold: 0.3
        )
    }
}
