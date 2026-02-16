//
//  PPGProcessorResult.swift
//  OralableCore
//
//  Created by John A Cogan on 16/02/2026.
//


//
//  PPGProcessor.swift
//  OralableCore
//
//  Created: January 29, 2026
//  Purpose: PPG signal processing for heart rate extraction
//  Reference: cursor_oralable/src/analysis/features.py detect_beats_from_green_bp()
//
//  Location: Sources/OralableCore/Signal/PPGProcessor.swift
//

import Foundation

// MARK: - PPG Processor Result

/// Result from PPG processing
public struct PPGProcessorResult: Sendable {
    /// Heart rate in BPM (nil if not enough data)
    public let heartRateBPM: Int?
    
    /// Heart rate quality score (0.0 - 1.0)
    public let quality: Double
    
    /// Number of peaks detected
    public let peakCount: Int
    
    /// Inter-beat intervals in seconds
    public let rrIntervals: [Double]
    
    /// Whether the signal is stable enough for HR calculation
    public var isValid: Bool {
        heartRateBPM != nil && quality > 0.5
    }
    
    public init(
        heartRateBPM: Int? = nil,
        quality: Double = 0,
        peakCount: Int = 0,
        rrIntervals: [Double] = []
    ) {
        self.heartRateBPM = heartRateBPM
        self.quality = quality
        self.peakCount = peakCount
        self.rrIntervals = rrIntervals
    }
    
    /// Empty result when no valid data
    public static let empty = PPGProcessorResult()
}

// MARK: - PPG Processor

/// Processes PPG signals to extract heart rate and pulse features
/// Uses bandpass filtering and peak detection matching Python reference
public class PPGProcessor {
    
    // MARK: - Configuration
    
    /// Sample rate in Hz
    public let sampleRate: Double
    
    /// Minimum peak distance in samples
    private let minPeakDistanceSamples: Int
    
    /// Maximum signal buffer size (samples)
    private let maxBufferSize: Int
    
    /// Minimum samples required for HR calculation
    private let minSamplesRequired: Int
    
    // MARK: - Filters
    
    /// Bandpass filter for heart rate extraction (0.5-8 Hz)
    private let bandpassFilter: ButterworthFilter
    
    // MARK: - Buffers
    
    /// Raw signal buffer (Green channel)
    private var signalBuffer: [Double] = []
    
    /// Filtered signal buffer
    private var filteredBuffer: [Double] = []
    
    /// Detected peak indices (relative to current buffer)
    private var peakIndices: [Int] = []
    
    /// Peak timestamps
    private var peakTimes: [Date] = []
    
    // MARK: - State
    
    /// Latest calculated heart rate
    public private(set) var currentHeartRate: Int?
    
    /// Latest quality score
    public private(set) var currentQuality: Double = 0
    
    // MARK: - Initialization
    
    /// Initialize PPG processor
    /// - Parameter sampleRate: Sample rate in Hz (default 50)
    public init(sampleRate: Double = AlgorithmSpec.ppgSampleRate) {
        self.sampleRate = sampleRate
        self.maxBufferSize = Int(sampleRate * AlgorithmSpec.maxSignalBufferSeconds)
        self.minSamplesRequired = Int(sampleRate * AlgorithmSpec.minSignalBufferSeconds)
        self.minPeakDistanceSamples = Int(AlgorithmSpec.minPeakDistanceSeconds * sampleRate)
        
        // Create bandpass filter for HR detection
        self.bandpassFilter = ButterworthFilter.hrBandpass(sampleRate: sampleRate)
    }
    
    // MARK: - Processing
    
    /// Process a single PPG sample
    /// - Parameter sample: PPGData sample
    /// - Returns: Current processing result
    public func process(_ sample: PPGData) -> PPGProcessorResult {
        // Use Green channel for beat detection (per Python reference)
        return processSample(Double(sample.green), timestamp: sample.timestamp)
    }
    
    /// Process a raw sample value
    /// - Parameters:
    ///   - value: Raw signal value (typically Green channel)
    ///   - timestamp: Sample timestamp
    /// - Returns: Current processing result
    public func processSample(_ value: Double, timestamp: Date) -> PPGProcessorResult {
        // Add to buffer
        signalBuffer.append(value)
        
        // Trim buffer if needed
        if signalBuffer.count > maxBufferSize {
            let excess = signalBuffer.count - maxBufferSize
            signalBuffer.removeFirst(excess)
        }
        
        // Need minimum samples for processing
        guard signalBuffer.count >= minSamplesRequired else {
            return PPGProcessorResult()
        }
        
        // Calculate heart rate
        return calculateHeartRate(latestTimestamp: timestamp)
    }
    
    /// Process batch of PPG samples
    /// - Parameter samples: Array of PPGData
    /// - Returns: Processing result
    public func processBatch(_ samples: [PPGData]) -> PPGProcessorResult {
        guard !samples.isEmpty else { return PPGProcessorResult() }
        
        // Add all samples to buffer
        for sample in samples {
            signalBuffer.append(Double(sample.green))
        }
        
        // Trim buffer
        if signalBuffer.count > maxBufferSize {
            let excess = signalBuffer.count - maxBufferSize
            signalBuffer.removeFirst(excess)
        }
        
        // Use timestamp of last sample
        let latestTimestamp = samples.last?.timestamp ?? Date()
        
        return calculateHeartRate(latestTimestamp: latestTimestamp)
    }
    
    // MARK: - Heart Rate Calculation
    
    private func calculateHeartRate(latestTimestamp: Date) -> PPGProcessorResult {
        guard signalBuffer.count >= minSamplesRequired else {
            return PPGProcessorResult()
        }
        
        // Apply bandpass filter (uses filtfilt for zero-phase)
        let filtered = bandpassFilter.filtfilt(signalBuffer)
        filteredBuffer = filtered
        
        // Calculate signal statistics
        let mean = filtered.reduce(0, +) / Double(filtered.count)
        let sumSquaredDiff = filtered.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(filtered.count))
        
        // Signal too flat = poor quality
        guard stdDev > 1.0 else {
            return PPGProcessorResult(quality: 0)
        }
        
        // Calculate prominence threshold
        let prominence = stdDev * AlgorithmSpec.peakProminenceMultiplier
        
        // Find peaks
        let peaks = findPeaks(
            signal: filtered,
            minDistance: minPeakDistanceSamples,
            minProminence: prominence
        )
        
        peakIndices = peaks
        
        guard peaks.count >= 2 else {
            return PPGProcessorResult(peakCount: peaks.count, quality: 0.2)
        }
        
        // Calculate inter-beat intervals
        var rrIntervals: [Double] = []
        let minInterval = 60.0 / AlgorithmSpec.maxHeartRate
        let maxInterval = 60.0 / AlgorithmSpec.minHeartRate
        
        for i in 1..<peaks.count {
            let intervalSamples = Double(peaks[i] - peaks[i - 1])
            let intervalSeconds = intervalSamples / sampleRate
            
            // Filter by physiological bounds
            if intervalSeconds >= minInterval && intervalSeconds <= maxInterval {
                rrIntervals.append(intervalSeconds)
            }
        }
        
        guard !rrIntervals.isEmpty else {
            return PPGProcessorResult(peakCount: peaks.count, quality: 0.3)
        }
        
        // Use median interval (robust to outliers)
        let sortedIntervals = rrIntervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        
        let bpm = Int(60.0 / medianInterval)
        
        // Validate BPM range
        guard bpm >= Int(AlgorithmSpec.minHeartRate) && bpm <= Int(AlgorithmSpec.maxHeartRate) else {
            return PPGProcessorResult(
                peakCount: peaks.count,
                quality: 0.4,
                rrIntervals: rrIntervals
            )
        }
        
        // Calculate quality score
        let quality = calculateQuality(
            stdDev: stdDev,
            mean: mean,
            peakCount: peaks.count,
            rrIntervals: rrIntervals
        )
        
        // Update state
        currentHeartRate = bpm
        currentQuality = quality
        
        // Update peak times
        updatePeakTimes(peaks: peaks, latestTimestamp: latestTimestamp)
        
        return PPGProcessorResult(
            heartRateBPM: bpm,
            quality: quality,
            peakCount: peaks.count,
            rrIntervals: rrIntervals
        )
    }
    
    // MARK: - Peak Detection
    
    /// Find peaks in signal with minimum distance and prominence constraints
    /// Matches Python: scipy.signal.find_peaks with distance and prominence
    private func findPeaks(signal: [Double], minDistance: Int, minProminence: Double) -> [Int] {
        guard signal.count >= 5 else { return [] }
        
        var peaks: [Int] = []
        
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            
            // Local maximum check (5-point)
            guard current > signal[i - 1] && current > signal[i + 1] else { continue }
            guard current > signal[i - 2] && current > signal[i + 2] else { continue }
            
            // Prominence check
            let searchRange = min(minDistance, i, signal.count - i - 1)
            
            var leftMin = current
            for j in max(0, i - searchRange)..<i {
                leftMin = min(leftMin, signal[j])
            }
            
            var rightMin = current
            for j in (i + 1)..<min(signal.count, i + searchRange + 1) {
                rightMin = min(rightMin, signal[j])
            }
            
            let prominence = current - max(leftMin, rightMin)
            guard prominence >= minProminence else { continue }
            
            // Distance check from last peak
            if let lastPeak = peaks.last {
                guard i - lastPeak >= minDistance else { continue }
            }
            
            peaks.append(i)
        }
        
        return peaks
    }
    
    // MARK: - Quality Calculation
    
    private func calculateQuality(
        stdDev: Double,
        mean: Double,
        peakCount: Int,
        rrIntervals: [Double]
    ) -> Double {
        var score = 0.0
        
        // AC/DC ratio component (higher is better for PPG)
        let acdc = min(1.0, stdDev / max(1.0, abs(mean)))
        score += 0.3 * acdc
        
        // Peak count component (more peaks = more confident)
        let peakFactor = min(1.0, Double(peakCount) / 10.0)
        score += 0.3 * peakFactor
        
        // RR interval consistency (lower variance = better)
        if rrIntervals.count >= 2 {
            let rrMean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
            let rrVariance = rrIntervals.map { pow($0 - rrMean, 2) }.reduce(0, +) / Double(rrIntervals.count)
            let rrStd = sqrt(rrVariance)
            let cv = rrStd / max(0.001, rrMean)
            
            // Lower CV = more consistent = higher quality
            let consistencyScore = max(0, 1.0 - cv * 2)
            score += 0.4 * consistencyScore
        }
        
        return max(0, min(1.0, score))
    }
    
    // MARK: - Peak Time Tracking
    
    private func updatePeakTimes(peaks: [Int], latestTimestamp: Date) {
        peakTimes.removeAll()
        
        let sampleInterval = 1.0 / sampleRate
        let bufferDuration = Double(signalBuffer.count) * sampleInterval
        let bufferStartTime = latestTimestamp.addingTimeInterval(-bufferDuration)
        
        for peakIndex in peaks {
            let peakTime = bufferStartTime.addingTimeInterval(Double(peakIndex) * sampleInterval)
            peakTimes.append(peakTime)
        }
    }
    
    /// Get recent peak times for HRV analysis
    public func getRecentPeakTimes() -> [Date] {
        return peakTimes
    }
    
    /// Get RR intervals in milliseconds for HRV analysis
    public func getRRIntervalsMs() -> [Double] {
        guard peakTimes.count >= 2 else { return [] }
        
        var intervals: [Double] = []
        for i in 1..<peakTimes.count {
            let intervalSeconds = peakTimes[i].timeIntervalSince(peakTimes[i - 1])
            intervals.append(intervalSeconds * 1000.0)  // Convert to ms
        }
        return intervals
    }
    
    // MARK: - Reset
    
    /// Reset processor state
    public func reset() {
        signalBuffer.removeAll()
        filteredBuffer.removeAll()
        peakIndices.removeAll()
        peakTimes.removeAll()
        currentHeartRate = nil
        currentQuality = 0
        bandpassFilter.reset()
    }
}

// MARK: - Thread Safety Note

extension PPGProcessor: @unchecked Sendable {
    // Note: PPGProcessor maintains mutable state and is not inherently thread-safe.
    // Use separate instances for concurrent processing or synchronize access.
}
