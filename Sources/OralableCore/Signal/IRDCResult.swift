//
//  IRDCResult.swift
//  OralableCore
//
//  Created by John A Cogan on 16/02/2026.
//


//
//  IRDCProcessor.swift
//  OralableCore
//
//  Created: January 29, 2026
//  Purpose: IR DC baseline extraction and shift detection for occlusion/activity
//  Reference: cursor_oralable/src/analysis/features.py compute_filters(), _ir_dc_shift_5s()
//
//  Location: Sources/OralableCore/Signal/IRDCProcessor.swift
//

import Foundation

// MARK: - IR DC Result

/// Result from IR DC analysis
public struct IRDCResult: Sendable {
    /// Current DC value (low-frequency component)
    public let dcValue: Double
    
    /// 5-second rolling mean of DC
    public let rollingMean5s: Double
    
    /// DC shift from baseline (positive = drop = occlusion/muscle activity)
    public let shift5s: Double
    
    /// Current normalized IR value (percentage above/below baseline)
    public let normalizedPercent: Double?
    
    /// Whether shift indicates significant muscle activity
    public var indicatesActivity: Bool {
        shift5s > AlgorithmSpec.irDCShiftThreshold
    }
    
    /// Whether normalized value exceeds activity threshold
    public var isAboveActivityThreshold: Bool {
        guard let normalized = normalizedPercent else { return false }
        return normalized > AlgorithmSpec.activityThresholdPercent
    }
    
    public init(
        dcValue: Double,
        rollingMean5s: Double,
        shift5s: Double,
        normalizedPercent: Double? = nil
    ) {
        self.dcValue = dcValue
        self.rollingMean5s = rollingMean5s
        self.shift5s = shift5s
        self.normalizedPercent = normalizedPercent
    }
    
    /// Empty result
    public static let empty = IRDCResult(dcValue: 0, rollingMean5s: 0, shift5s: 0)
}

// MARK: - IR DC Processor

/// Processes IR signal to extract DC baseline for occlusion and activity detection
/// Uses lowpass filtering matching Python reference
public class IRDCProcessor {
    
    // MARK: - Configuration
    
    /// Sample rate in Hz
    public let sampleRate: Double
    
    /// Rolling window size in samples
    private let rollingWindowSamples: Int
    
    /// Reference window size in samples (for baseline calculation)
    private let referenceWindowSamples: Int
    
    /// Maximum buffer size (samples)
    private let maxBufferSize: Int
    
    // MARK: - Filter
    
    /// Lowpass filter for DC extraction (<0.8 Hz)
    private let lowpassFilter: ButterworthFilter
    
    // MARK: - Buffers
    
    /// Raw IR value buffer
    private var rawBuffer: [Double] = []
    
    /// DC (filtered) value buffer
    private var dcBuffer: [Double] = []
    
    // MARK: - Calibration State
    
    /// Calibration baseline (median IR during calibration)
    public private(set) var calibrationBaseline: Double?
    
    /// Whether calibration is complete
    public var isCalibrated: Bool {
        calibrationBaseline != nil
    }
    
    // MARK: - Current Values
    
    /// Latest raw IR value
    public private(set) var currentRawIR: Double = 0
    
    /// Latest DC value
    public private(set) var currentDC: Double = 0
    
    /// Current rolling mean
    public private(set) var rollingMean: Double = 0
    
    /// Current DC shift
    public private(set) var dcShift: Double = 0
    
    /// Current normalized percentage
    public private(set) var normalizedPercent: Double?
    
    // MARK: - Initialization
    
    /// Initialize IR DC processor
    /// - Parameter sampleRate: Sample rate in Hz (default 50)
    public init(sampleRate: Double = AlgorithmSpec.ppgSampleRate) {
        self.sampleRate = sampleRate
        self.maxBufferSize = Int(sampleRate * 60)  // 1 minute max
        self.rollingWindowSamples = Int(AlgorithmSpec.irDCRollingWindowSeconds * sampleRate)
        self.referenceWindowSamples = Int(AlgorithmSpec.irDCReferenceWindowSeconds * sampleRate)
        
        // Create lowpass filter for DC extraction
        self.lowpassFilter = ButterworthFilter.irDCLowpass(sampleRate: sampleRate)
    }
    
    // MARK: - Processing
    
    /// Process a single PPG sample
    /// - Parameter sample: PPGData sample
    /// - Returns: Current IR DC result
    public func process(_ sample: PPGData) -> IRDCResult {
        return processSample(Double(sample.ir))
    }
    
    /// Process a raw IR value
    /// - Parameter irValue: Raw IR signal value
    /// - Returns: Current IR DC result
    public func processSample(_ irValue: Double) -> IRDCResult {
        currentRawIR = irValue
        
        // Add to raw buffer
        rawBuffer.append(irValue)
        if rawBuffer.count > maxBufferSize {
            rawBuffer.removeFirst()
        }
        
        // Apply lowpass filter to get DC component
        let dc = lowpassFilter.processSample(irValue)
        currentDC = dc
        
        // Add to DC buffer
        dcBuffer.append(dc)
        if dcBuffer.count > maxBufferSize {
            dcBuffer.removeFirst()
        }
        
        // Calculate rolling mean
        updateRollingMean()
        
        // Calculate shift
        updateShift()
        
        // Calculate normalized percentage if calibrated
        updateNormalizedPercent()
        
        return IRDCResult(
            dcValue: currentDC,
            rollingMean5s: rollingMean,
            shift5s: dcShift,
            normalizedPercent: normalizedPercent
        )
    }
    
    /// Process batch of samples
    /// - Parameter samples: Array of PPGData
    /// - Returns: Latest IR DC result
    public func processBatch(_ samples: [PPGData]) -> IRDCResult {
        var result = IRDCResult.empty
        
        for sample in samples {
            result = processSample(Double(sample.ir))
        }
        
        return result
    }
    
    // MARK: - Calculations
    
    private func updateRollingMean() {
        let window = Array(dcBuffer.suffix(rollingWindowSamples))
        guard !window.isEmpty else {
            rollingMean = 0
            return
        }
        rollingMean = window.reduce(0, +) / Double(window.count)
    }
    
    private func updateShift() {
        let window = Array(dcBuffer.suffix(rollingWindowSamples))
        guard window.count >= referenceWindowSamples else {
            dcShift = 0
            return
        }
        
        // Reference baseline: first N samples of window
        let refSamples = Array(window.prefix(referenceWindowSamples))
        let baseline = refSamples.reduce(0, +) / Double(refSamples.count)
        
        // Window mean
        let windowMean = window.reduce(0, +) / Double(window.count)
        
        // Positive shift = baseline dropped (occlusion/muscle activity)
        dcShift = baseline - windowMean
    }
    
    private func updateNormalizedPercent() {
        guard let baseline = calibrationBaseline, baseline > 0 else {
            normalizedPercent = nil
            return
        }
        
        // Normalized = (current - baseline) / baseline * 100
        normalizedPercent = ((currentRawIR - baseline) / baseline) * 100.0
    }
    
    // MARK: - Calibration
    
    /// Set calibration baseline
    /// - Parameter baseline: Median IR value from calibration period
    public func setCalibration(baseline: Double) {
        calibrationBaseline = baseline
    }
    
    /// Calculate calibration baseline from recent samples
    /// - Parameter sampleCount: Number of recent samples to use
    /// - Returns: Median value, or nil if insufficient samples
    public func calculateCalibrationBaseline(sampleCount: Int? = nil) -> Double? {
        let count = sampleCount ?? Int(AlgorithmSpec.calibrationDurationSeconds * sampleRate)
        let samples = Array(rawBuffer.suffix(count))
        
        guard samples.count >= AlgorithmSpec.calibrationMinSamples else {
            return nil
        }
        
        // Calculate median
        let sorted = samples.sorted()
        let median: Double
        if sorted.count % 2 == 0 {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        } else {
            median = sorted[sorted.count / 2]
        }
        
        return median
    }
    
    /// Perform calibration using recent samples
    /// - Returns: True if calibration succeeded
    @discardableResult
    public func calibrate() -> Bool {
        guard let baseline = calculateCalibrationBaseline() else {
            return false
        }
        
        // Validate stability (CV check)
        let samples = Array(rawBuffer.suffix(Int(AlgorithmSpec.calibrationDurationSeconds * sampleRate)))
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / max(1.0, abs(mean))
        
        guard cv <= AlgorithmSpec.calibrationMaxCV else {
            return false
        }
        
        calibrationBaseline = baseline
        return true
    }
    
    /// Clear calibration
    public func clearCalibration() {
        calibrationBaseline = nil
        normalizedPercent = nil
    }
    
    // MARK: - Activity Detection
    
    /// Check if current shift indicates muscle activity
    /// - Parameter threshold: ADC units threshold (default from AlgorithmSpec)
    /// - Returns: True if significant shift detected
    public func hasSignificantShift(threshold: Double? = nil) -> Bool {
        let thresh = threshold ?? AlgorithmSpec.irDCShiftThreshold
        return dcShift > thresh
    }
    
    /// Check if normalized IR is above activity threshold
    /// - Parameter threshold: Percentage threshold (default from AlgorithmSpec)
    /// - Returns: True if above threshold, nil if not calibrated
    public func isAboveActivityThreshold(threshold: Double? = nil) -> Bool? {
        guard let normalized = normalizedPercent else { return nil }
        let thresh = threshold ?? AlgorithmSpec.activityThresholdPercent
        return normalized > thresh
    }
    
    // MARK: - Buffer Access
    
    /// Get recent raw IR values
    /// - Parameter count: Number of samples (default all)
    /// - Returns: Array of raw IR values
    public func getRecentRawValues(count: Int? = nil) -> [Double] {
        if let c = count {
            return Array(rawBuffer.suffix(c))
        }
        return rawBuffer
    }
    
    /// Get recent DC values
    /// - Parameter count: Number of samples (default all)
    /// - Returns: Array of DC values
    public func getRecentDCValues(count: Int? = nil) -> [Double] {
        if let c = count {
            return Array(dcBuffer.suffix(c))
        }
        return dcBuffer
    }
    
    /// Get current buffer size
    public var bufferSize: Int {
        return rawBuffer.count
    }
    
    // MARK: - Reset
    
    /// Reset processor state (keeps calibration)
    public func reset() {
        rawBuffer.removeAll()
        dcBuffer.removeAll()
        currentRawIR = 0
        currentDC = 0
        rollingMean = 0
        dcShift = 0
        normalizedPercent = nil
        lowpassFilter.reset()
    }
    
    /// Full reset including calibration
    public func fullReset() {
        reset()
        clearCalibration()
    }
}

// MARK: - Thread Safety Note

extension IRDCProcessor: @unchecked Sendable {
    // Note: IRDCProcessor maintains mutable state and is not inherently thread-safe.
    // Use separate instances for concurrent processing or synchronize access.
}
