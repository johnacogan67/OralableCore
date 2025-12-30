//
//  PPGNormalizationService.swift
//  OralableCore
//
//  Created: December 30, 2025
//  PPG signal normalization and baseline tracking service
//  Essential for muscle-site PPG where the DC component is very high
//

import Foundation

// MARK: - Normalization Method

/// PPG normalization method
public enum PPGNormalizationMethod: String, Sendable, CaseIterable {
    /// Pass-through (no normalization)
    case raw

    /// Simple min-max or z-score like scaling per window
    case dynamicRange

    /// Baseline corrected using moving average
    case adaptiveBaseline

    /// Persistent baseline tracking across samples
    case persistent

    public var description: String {
        switch self {
        case .raw:
            return "Raw (No Processing)"
        case .dynamicRange:
            return "Dynamic Range Scaling"
        case .adaptiveBaseline:
            return "Adaptive Baseline"
        case .persistent:
            return "Persistent Baseline"
        }
    }
}

// MARK: - Normalized PPG Sample

/// A single normalized PPG sample with all three channels
public struct NormalizedPPGSample: Sendable {
    public let timestamp: Date
    public let ir: Double
    public let red: Double
    public let green: Double

    public init(timestamp: Date, ir: Double, red: Double, green: Double) {
        self.timestamp = timestamp
        self.ir = ir
        self.red = red
        self.green = green
    }
}

// MARK: - PPG Normalization Service

/// Service for normalizing PPG signals by removing DC component
/// Thread-safe actor implementation
public actor PPGNormalizationService {

    // MARK: - Configuration

    /// Slow tracking coefficient for DC component
    private let alpha: Double

    /// Signal validation thresholds
    private let saturationThreshold: Double
    private let lowSignalThreshold: Double

    // MARK: - Baseline State (for persistent mode)

    private var movingAverageIR: Double = 0
    private var movingAverageRed: Double = 0
    private var movingAverageGreen: Double = 0

    private var initializedIR: Bool = false
    private var initializedRed: Bool = false
    private var initializedGreen: Bool = false

    // Single-channel state (for simple normalize)
    private var movingAverage: Double = 0
    private var isInitialized: Bool = false

    // MARK: - Initialization

    /// Initialize normalization service
    /// - Parameters:
    ///   - alpha: Baseline tracking coefficient (default: 0.01, very slow)
    ///   - saturationThreshold: Upper limit for valid signal (default: 65000)
    ///   - lowSignalThreshold: Lower limit for valid signal (default: 1000)
    public init(
        alpha: Double = 0.01,
        saturationThreshold: Double = 65000,
        lowSignalThreshold: Double = 1000
    ) {
        self.alpha = alpha
        self.saturationThreshold = saturationThreshold
        self.lowSignalThreshold = lowSignalThreshold
    }

    // MARK: - Single Channel Normalization

    /// Normalize a single signal value by removing DC component
    /// - Parameter rawValue: Raw PPG value
    /// - Returns: AC signal (pulsatile component)
    public func normalize(_ rawValue: Double) -> Double {
        if !isInitialized {
            movingAverage = rawValue
            isInitialized = true
            return 0
        }

        // Update DC baseline estimate (slow tracking)
        movingAverage = (alpha * rawValue) + ((1.0 - alpha) * movingAverage)

        // Subtract baseline to get AC signal
        return rawValue - movingAverage
    }

    /// Get current baseline estimate
    public var currentBaseline: Double {
        movingAverage
    }

    // MARK: - Multi-Channel Normalization

    /// Normalize multi-channel PPG data
    /// - Parameters:
    ///   - samples: Array of (timestamp, ir, red, green) tuples
    ///   - method: Normalization method to apply
    /// - Returns: Array of normalized samples
    public func normalizePPGData(
        _ samples: [(timestamp: Date, ir: Double, red: Double, green: Double)],
        method: PPGNormalizationMethod
    ) -> [NormalizedPPGSample] {
        guard !samples.isEmpty else { return [] }

        switch method {
        case .raw:
            return samples.map {
                NormalizedPPGSample(timestamp: $0.timestamp, ir: $0.ir, red: $0.red, green: $0.green)
            }

        case .dynamicRange:
            return applyDynamicRangeNormalization(samples)

        case .adaptiveBaseline:
            return applyAdaptiveBaselineNormalization(samples)

        case .persistent:
            return applyPersistentBaselineNormalization(samples)
        }
    }

    /// Normalize PPG data from PPGData array
    /// - Parameters:
    ///   - ppgData: Array of PPGData
    ///   - method: Normalization method
    /// - Returns: Array of normalized samples
    public func normalizePPGData(
        _ ppgData: [PPGData],
        method: PPGNormalizationMethod
    ) -> [NormalizedPPGSample] {
        let tuples = ppgData.map { data in
            (timestamp: data.timestamp,
             ir: Double(data.ir),
             red: Double(data.red),
             green: Double(data.green))
        }
        return normalizePPGData(tuples, method: method)
    }

    // MARK: - Signal Validation

    /// Check if the signal is valid (not saturated or too low)
    /// - Parameter value: Raw signal value
    /// - Returns: True if signal is valid
    public func isSignalValid(_ value: Double) -> Bool {
        return value > lowSignalThreshold && value < saturationThreshold
    }

    /// Validate IR signal for worn detection
    /// - Parameter ir: Infrared channel value
    /// - Returns: True if signal indicates sensor is on skin
    public func validateWornStatus(ir: Double) -> Bool {
        return isSignalValid(ir)
    }

    // MARK: - State Management

    /// Reset all persistent baselines
    public func reset() {
        movingAverageIR = 0
        movingAverageRed = 0
        movingAverageGreen = 0
        initializedIR = false
        initializedRed = false
        initializedGreen = false
        movingAverage = 0
        isInitialized = false
    }

    /// Check if baselines have been initialized
    public var isBaselineInitialized: Bool {
        initializedIR && initializedRed && initializedGreen
    }

    // MARK: - Private Normalization Methods

    /// Apply dynamic range (min-max) normalization
    private func applyDynamicRangeNormalization(
        _ samples: [(timestamp: Date, ir: Double, red: Double, green: Double)]
    ) -> [NormalizedPPGSample] {
        let irValues = samples.map { $0.ir }
        let redValues = samples.map { $0.red }
        let greenValues = samples.map { $0.green }

        let irMin = irValues.min() ?? 0
        let irMax = irValues.max() ?? 1
        let redMin = redValues.min() ?? 0
        let redMax = redValues.max() ?? 1
        let greenMin = greenValues.min() ?? 0
        let greenMax = greenValues.max() ?? 1

        return samples.map { sample in
            let irNorm = irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0
            let redNorm = redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0
            let greenNorm = greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0

            return NormalizedPPGSample(
                timestamp: sample.timestamp,
                ir: irNorm,
                red: redNorm,
                green: greenNorm
            )
        }
    }

    /// Apply adaptive baseline normalization (resets per batch)
    private func applyAdaptiveBaselineNormalization(
        _ samples: [(timestamp: Date, ir: Double, red: Double, green: Double)]
    ) -> [NormalizedPPGSample] {
        var irBaseline = samples.first?.ir ?? 0
        var redBaseline = samples.first?.red ?? 0
        var greenBaseline = samples.first?.green ?? 0

        let alphaLocal = 0.02  // Faster tracking within batch

        return samples.map { sample in
            irBaseline = alphaLocal * sample.ir + (1 - alphaLocal) * irBaseline
            redBaseline = alphaLocal * sample.red + (1 - alphaLocal) * redBaseline
            greenBaseline = alphaLocal * sample.green + (1 - alphaLocal) * greenBaseline

            return NormalizedPPGSample(
                timestamp: sample.timestamp,
                ir: sample.ir - irBaseline,
                red: sample.red - redBaseline,
                green: sample.green - greenBaseline
            )
        }
    }

    /// Apply persistent baseline normalization (maintains state across calls)
    private func applyPersistentBaselineNormalization(
        _ samples: [(timestamp: Date, ir: Double, red: Double, green: Double)]
    ) -> [NormalizedPPGSample] {
        return samples.map { sample in
            // IR channel
            if !initializedIR {
                movingAverageIR = sample.ir
                initializedIR = true
            } else {
                movingAverageIR = alpha * sample.ir + (1 - alpha) * movingAverageIR
            }
            let irAC = sample.ir - movingAverageIR

            // Red channel
            if !initializedRed {
                movingAverageRed = sample.red
                initializedRed = true
            } else {
                movingAverageRed = alpha * sample.red + (1 - alpha) * movingAverageRed
            }
            let redAC = sample.red - movingAverageRed

            // Green channel
            if !initializedGreen {
                movingAverageGreen = sample.green
                initializedGreen = true
            } else {
                movingAverageGreen = alpha * sample.green + (1 - alpha) * movingAverageGreen
            }
            let greenAC = sample.green - movingAverageGreen

            return NormalizedPPGSample(
                timestamp: sample.timestamp,
                ir: irAC,
                red: redAC,
                green: greenAC
            )
        }
    }
}

// MARK: - Perfusion Index Calculator

extension PPGNormalizationService {

    /// Calculate perfusion index from raw and normalized signals
    /// PI = (AC component / DC component) * 100
    /// - Parameters:
    ///   - rawValue: Raw PPG value (DC + AC)
    ///   - normalizedValue: Normalized value (AC only)
    /// - Returns: Perfusion index as percentage
    public func calculatePerfusionIndex(rawValue: Double, normalizedValue: Double) -> Double {
        guard rawValue > 0 else { return 0 }
        return (abs(normalizedValue) / rawValue) * 100.0
    }

    /// Calculate R value for SpO2 calculation
    /// R = (AC_Red / DC_Red) / (AC_IR / DC_IR)
    /// - Parameters:
    ///   - redAC: AC component of red channel
    ///   - redDC: DC component of red channel
    ///   - irAC: AC component of IR channel
    ///   - irDC: DC component of IR channel
    /// - Returns: R ratio value
    public func calculateRRatio(redAC: Double, redDC: Double, irAC: Double, irDC: Double) -> Double {
        guard irDC > 0 && redDC > 0 && irAC != 0 else { return 0 }

        let redRatio = abs(redAC) / redDC
        let irRatio = abs(irAC) / irDC

        guard irRatio > 0 else { return 0 }

        return redRatio / irRatio
    }

    /// Estimate SpO2 from R ratio using empirical calibration curve
    /// SpO2 = 110 - 25 * R (simplified linear approximation)
    /// - Parameter rRatio: R ratio from calculateRRatio
    /// - Returns: Estimated SpO2 percentage (clamped to 70-100%)
    public func estimateSpO2(rRatio: Double) -> Double {
        guard rRatio > 0 else { return 0 }

        // Empirical calibration curve (simplified)
        // Real devices use device-specific calibration tables
        let spo2 = 110.0 - 25.0 * rRatio

        // Clamp to physiological range
        return min(100.0, max(70.0, spo2))
    }
}

// MARK: - Factory Methods

extension PPGNormalizationService {

    /// Create service with default settings for Oralable device
    public static func oralable() -> PPGNormalizationService {
        PPGNormalizationService(
            alpha: 0.01,
            saturationThreshold: 500000,  // Higher for 32-bit values
            lowSignalThreshold: 10000
        )
    }

    /// Create service for real-time processing (faster tracking)
    public static func realtime() -> PPGNormalizationService {
        PPGNormalizationService(
            alpha: 0.05,  // Faster tracking
            saturationThreshold: 500000,
            lowSignalThreshold: 10000
        )
    }
}
