//
//  ButterworthFilterType.swift
//  OralableCore
//
//  Created by John A Cogan on 16/02/2026.
//


//
//  ButterworthFilter.swift
//  OralableCore
//
//  Created: January 29, 2026
//  Purpose: Butterworth IIR filter implementation
//  Reference: cursor_oralable/src/analysis/features.py _butter_bandpass(), _butter_lowpass()
//
//  Location: Sources/OralableCore/Filters/ButterworthFilter.swift
//

import Foundation
import Accelerate

// MARK: - Filter Type

/// Type of Butterworth filter
public enum ButterworthFilterType: Sendable {
    case lowpass
    case highpass
    case bandpass
}

// MARK: - Butterworth Filter

/// Butterworth IIR filter implementation
/// Supports lowpass, highpass, and bandpass configurations
/// Uses second-order sections (biquads) for numerical stability
public class ButterworthFilter {
    
    // MARK: - Properties
    
    /// Filter type
    public let type: ButterworthFilterType
    
    /// Low cutoff frequency (Hz) - used for lowpass, highpass, and bandpass
    public let cutoffLow: Double
    
    /// High cutoff frequency (Hz) - used for bandpass only
    public let cutoffHigh: Double?
    
    /// Sample rate (Hz)
    public let sampleRate: Double
    
    /// Filter order
    public let order: Int
    
    // Filter coefficients (second-order sections)
    private var sosCoefficients: [[Double]] = []
    
    // State for each second-order section
    private var states: [[Double]] = []
    
    // Direct form coefficients for simple filters
    private var b: [Double] = []
    private var a: [Double] = []
    private var directState: [Double] = []
    
    // MARK: - Initialization
    
    /// Initialize a Butterworth filter
    /// - Parameters:
    ///   - type: Filter type (lowpass, highpass, bandpass)
    ///   - cutoffLow: Low cutoff frequency in Hz
    ///   - cutoffHigh: High cutoff frequency in Hz (required for bandpass)
    ///   - sampleRate: Sample rate in Hz
    ///   - order: Filter order (default 4)
    public init(
        type: ButterworthFilterType,
        cutoffLow: Double,
        cutoffHigh: Double? = nil,
        sampleRate: Double,
        order: Int = 4
    ) {
        self.type = type
        self.cutoffLow = cutoffLow
        self.cutoffHigh = cutoffHigh
        self.sampleRate = sampleRate
        self.order = order
        
        computeCoefficients()
        initializeState()
    }
    
    // MARK: - Coefficient Computation
    
    private func computeCoefficients() {
        let nyquist = sampleRate / 2.0
        
        switch type {
        case .lowpass:
            let normalizedCutoff = cutoffLow / nyquist
            computeLowpassCoefficients(normalizedCutoff: normalizedCutoff)
            
        case .highpass:
            let normalizedCutoff = cutoffLow / nyquist
            computeHighpassCoefficients(normalizedCutoff: normalizedCutoff)
            
        case .bandpass:
            guard let high = cutoffHigh else {
                // Fallback to lowpass if no high cutoff provided
                let normalizedCutoff = cutoffLow / nyquist
                computeLowpassCoefficients(normalizedCutoff: normalizedCutoff)
                return
            }
            let normalizedLow = cutoffLow / nyquist
            let normalizedHigh = high / nyquist
            computeBandpassCoefficients(lowNorm: normalizedLow, highNorm: normalizedHigh)
        }
    }
    
    /// Compute lowpass filter coefficients using bilinear transform
    private func computeLowpassCoefficients(normalizedCutoff: Double) {
        // Pre-warp the cutoff frequency
        let wc = tan(.pi * normalizedCutoff)
        let wc2 = wc * wc
        
        // Second-order Butterworth (Q = 1/sqrt(2) for maximally flat response)
        let q = sqrt(2.0)
        let norm = 1.0 / (1.0 + wc / q + wc2)
        
        // Numerator coefficients (b)
        let b0 = wc2 * norm
        let b1 = 2.0 * b0
        let b2 = b0
        
        // Denominator coefficients (a)
        let a0 = 1.0
        let a1 = 2.0 * (wc2 - 1.0) * norm
        let a2 = (1.0 - wc / q + wc2) * norm
        
        self.b = [b0, b1, b2]
        self.a = [a0, a1, a2]
        
        // For higher orders, cascade multiple second-order sections
        if order > 2 {
            // Store as SOS for cascaded filtering
            sosCoefficients = [[b0, b1, b2, a0, a1, a2]]
            
            // Add more sections for higher orders
            for _ in 1..<(order / 2) {
                sosCoefficients.append([b0, b1, b2, a0, a1, a2])
            }
        }
    }
    
    /// Compute highpass filter coefficients using bilinear transform
    private func computeHighpassCoefficients(normalizedCutoff: Double) {
        let wc = tan(.pi * normalizedCutoff)
        let wc2 = wc * wc
        let q = sqrt(2.0)
        let norm = 1.0 / (1.0 + wc / q + wc2)
        
        // Highpass numerator
        let b0 = norm
        let b1 = -2.0 * norm
        let b2 = norm
        
        // Denominator (same as lowpass)
        let a0 = 1.0
        let a1 = 2.0 * (wc2 - 1.0) * norm
        let a2 = (1.0 - wc / q + wc2) * norm
        
        self.b = [b0, b1, b2]
        self.a = [a0, a1, a2]
        
        if order > 2 {
            sosCoefficients = [[b0, b1, b2, a0, a1, a2]]
            for _ in 1..<(order / 2) {
                sosCoefficients.append([b0, b1, b2, a0, a1, a2])
            }
        }
    }
    
    /// Compute bandpass filter coefficients
    private func computeBandpassCoefficients(lowNorm: Double, highNorm: Double) {
        // Pre-warp frequencies
        let wcLow = tan(.pi * lowNorm)
        let wcHigh = tan(.pi * highNorm)
        
        // Bandwidth and center frequency
        let bw = wcHigh - wcLow
        let w0 = sqrt(wcLow * wcHigh)
        let w02 = w0 * w0
        
        // Q factor
        let q = w0 / bw
        
        let norm = 1.0 / (1.0 + w0 / q + w02)
        
        // Bandpass numerator
        let b0 = (w0 / q) * norm
        let b1 = 0.0
        let b2 = -b0
        
        // Denominator
        let a0 = 1.0
        let a1 = 2.0 * (w02 - 1.0) * norm
        let a2 = (1.0 - w0 / q + w02) * norm
        
        self.b = [b0, b1, b2]
        self.a = [a0, a1, a2]
        
        if order > 2 {
            sosCoefficients = [[b0, b1, b2, a0, a1, a2]]
            for _ in 1..<(order / 2) {
                sosCoefficients.append([b0, b1, b2, a0, a1, a2])
            }
        }
    }
    
    private func initializeState() {
        // Initialize state for direct form filtering
        directState = [Double](repeating: 0.0, count: max(b.count, a.count))
        
        // Initialize states for SOS cascade
        states = sosCoefficients.map { _ in [0.0, 0.0] }
    }
    
    // MARK: - Single Sample Processing
    
    /// Process a single sample through the filter
    /// - Parameter input: Input sample value
    /// - Returns: Filtered output value
    public func processSample(_ input: Double) -> Double {
        guard !b.isEmpty && !a.isEmpty else { return input }
        
        // Direct Form II Transposed implementation
        let output = b[0] * input + directState[0]
        
        for i in 0..<(directState.count - 1) {
            let bCoeff = i + 1 < b.count ? b[i + 1] : 0.0
            let aCoeff = i + 1 < a.count ? a[i + 1] : 0.0
            directState[i] = bCoeff * input - aCoeff * output + directState[i + 1]
        }
        directState[directState.count - 1] = 0.0
        
        return output
    }
    
    // MARK: - Batch Processing
    
    /// Process an array of samples (forward filtering only)
    /// - Parameter input: Array of input samples
    /// - Returns: Array of filtered samples
    public func process(_ input: [Double]) -> [Double] {
        var output = [Double](repeating: 0.0, count: input.count)
        
        for i in 0..<input.count {
            output[i] = processSample(input[i])
        }
        
        return output
    }
    
    /// Forward-backward filtering (zero-phase, like scipy.signal.filtfilt)
    /// - Parameter input: Array of input samples
    /// - Returns: Array of filtered samples with zero phase distortion
    public func filtfilt(_ input: [Double]) -> [Double] {
        guard input.count > 3 else { return input }
        
        // Save current state
        let savedState = directState
        
        // Forward pass
        reset()
        var forward = process(input)
        
        // Reverse
        forward.reverse()
        
        // Backward pass
        reset()
        var backward = process(forward)
        
        // Reverse back
        backward.reverse()
        
        // Restore state
        directState = savedState
        
        return backward
    }
    
    // MARK: - State Management
    
    /// Reset filter state to zero
    public func reset() {
        directState = [Double](repeating: 0.0, count: directState.count)
        states = sosCoefficients.map { _ in [0.0, 0.0] }
    }
}

// MARK: - Convenience Factory Methods

extension ButterworthFilter {
    
    /// Create a lowpass filter for IR DC extraction
    /// Uses parameters from AlgorithmSpec
    public static func irDCLowpass(sampleRate: Double = AlgorithmSpec.ppgSampleRate) -> ButterworthFilter {
        return ButterworthFilter(
            type: .lowpass,
            cutoffLow: AlgorithmSpec.irDCLowpassCutoff,
            sampleRate: sampleRate,
            order: AlgorithmSpec.filterOrder
        )
    }
    
    /// Create a bandpass filter for heart rate detection
    /// Uses parameters from AlgorithmSpec
    public static func hrBandpass(sampleRate: Double = AlgorithmSpec.ppgSampleRate) -> ButterworthFilter {
        return ButterworthFilter(
            type: .bandpass,
            cutoffLow: AlgorithmSpec.hrBandpassLow,
            cutoffHigh: AlgorithmSpec.hrBandpassHigh,
            sampleRate: sampleRate,
            order: AlgorithmSpec.filterOrder
        )
    }
}

// MARK: - Sendable Conformance

extension ButterworthFilter: @unchecked Sendable {
    // Note: ButterworthFilter is not inherently thread-safe due to mutable state.
    // Use separate instances for concurrent processing or synchronize access.
}
