//
//  SpO2Service.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Dedicated blood oxygen saturation (SpO2) calculation from PPG signals
//  Uses ratio-of-ratios method for pulse oximetry
//

import Foundation

// MARK: - SpO2 Result

/// Result from SpO2 calculation
public struct SpO2Result: Sendable, Equatable {
    /// Blood oxygen saturation percentage (0 if unavailable)
    public let percentage: Double

    /// Confidence score (0.0 to 1.0)
    public let confidence: Double

    /// R ratio value used in calculation
    public let rRatio: Double

    /// Whether the signal quality is sufficient
    public let isValid: Bool

    public init(
        percentage: Double,
        confidence: Double,
        rRatio: Double = 0,
        isValid: Bool = true
    ) {
        self.percentage = percentage
        self.confidence = min(1.0, max(0.0, confidence))
        self.rRatio = rRatio
        self.isValid = isValid
    }

    /// Empty result when no valid SpO2 can be calculated
    public static let empty = SpO2Result(percentage: 0, confidence: 0, rRatio: 0, isValid: false)

    /// Whether result is clinically usable
    public var isClinicallyValid: Bool {
        percentage >= 70 && percentage <= 100 && confidence > 0.6
    }
}

// MARK: - SpO2 Calibration Curve

/// SpO2 calibration curve type
public enum SpO2CalibrationCurve: String, Sendable, CaseIterable {
    /// Linear approximation: SpO2 = 110 - 25 * R
    case linear

    /// Quadratic approximation: SpO2 = -45.060 * R^2 + 30.354 * R + 94.845
    case quadratic

    /// Cubic for more accurate mid-range values
    case cubic

    public var description: String {
        switch self {
        case .linear:
            return "Linear (Simple)"
        case .quadratic:
            return "Quadratic (Standard)"
        case .cubic:
            return "Cubic (Precision)"
        }
    }
}

// MARK: - SpO2 Service

/// Service for calculating blood oxygen saturation from PPG signals
/// Thread-safe actor implementation
public actor SpO2Service {

    // MARK: - Configuration

    /// Minimum samples required for calculation
    private let minSamplesRequired: Int

    /// Valid SpO2 range
    private let validRange: ClosedRange<Double>

    /// Minimum quality threshold
    private let minQualityThreshold: Double

    /// Smoothing window size
    private let smoothingWindow: Int

    /// Calibration curve to use
    private let calibrationCurve: SpO2CalibrationCurve

    // MARK: - Internal Buffers

    private var redBuffer: [Double] = []
    private var irBuffer: [Double] = []
    private let bufferSize: Int

    // MARK: - Initialization

    /// Initialize SpO2 service with configuration
    /// - Parameters:
    ///   - minSamples: Minimum samples required (default: 150 = 3 sec at 50Hz)
    ///   - bufferSize: Internal buffer size (default: 250 = 5 sec at 50Hz)
    ///   - validRange: Valid SpO2 percentage range (default: 70-100)
    ///   - minQuality: Minimum quality threshold (default: 0.5)
    ///   - smoothingWindow: Moving average window size (default: 10)
    ///   - calibration: Calibration curve to use (default: quadratic)
    public init(
        minSamples: Int = 150,
        bufferSize: Int = 250,
        validRange: ClosedRange<Double> = 70.0...100.0,
        minQuality: Double = 0.5,
        smoothingWindow: Int = 10,
        calibration: SpO2CalibrationCurve = .quadratic
    ) {
        self.minSamplesRequired = minSamples
        self.bufferSize = bufferSize
        self.validRange = validRange
        self.minQualityThreshold = minQuality
        self.smoothingWindow = smoothingWindow
        self.calibrationCurve = calibration

        self.redBuffer.reserveCapacity(bufferSize)
        self.irBuffer.reserveCapacity(bufferSize)
    }

    // MARK: - Processing

    /// Process PPG samples and calculate SpO2
    /// - Parameters:
    ///   - redSamples: Red channel PPG values
    ///   - irSamples: Infrared channel PPG values
    /// - Returns: SpO2Result with percentage and confidence
    public func process(redSamples: [Double], irSamples: [Double]) -> SpO2Result {
        // Validate input
        guard redSamples.count == irSamples.count,
              redSamples.count >= minSamplesRequired else {
            return .empty
        }

        // Apply smoothing
        let smoothedRed = applyMovingAverage(redSamples)
        let smoothedIR = applyMovingAverage(irSamples)

        // Calculate DC components (average values)
        let dcRed = calculateMean(smoothedRed)
        let dcIR = calculateMean(smoothedIR)

        guard dcRed > 0, dcIR > 0 else {
            return .empty
        }

        // Calculate AC components (peak-to-peak amplitudes)
        let acRed = calculatePeakToPeak(smoothedRed)
        let acIR = calculatePeakToPeak(smoothedIR)

        guard acRed > 0, acIR > 0 else {
            return .empty
        }

        // Calculate R ratio
        let ratioRed = acRed / dcRed
        let ratioIR = acIR / dcIR

        guard ratioIR > 0 else {
            return .empty
        }

        let rRatio = ratioRed / ratioIR

        // Convert R to SpO2 using calibration curve
        let spo2 = convertRToSpO2(rRatio)

        // Calculate signal quality
        let quality = calculateSignalQuality(
            redSamples: smoothedRed,
            irSamples: smoothedIR,
            acRed: acRed,
            acIR: acIR,
            dcRed: dcRed,
            dcIR: dcIR
        )

        // Validate and return result
        let isValid = validRange.contains(spo2) && quality >= minQualityThreshold

        return SpO2Result(
            percentage: isValid ? (spo2 * 10).rounded() / 10 : 0,
            confidence: (quality * 100).rounded() / 100,
            rRatio: (rRatio * 1000).rounded() / 1000,
            isValid: isValid
        )
    }

    /// Process Int32 PPG samples (common from BLE data)
    public func process(redSamples: [Int32], irSamples: [Int32]) -> SpO2Result {
        let red = redSamples.map { Double($0) }
        let ir = irSamples.map { Double($0) }
        return process(redSamples: red, irSamples: ir)
    }

    /// Add samples to internal buffer and process when ready
    /// - Parameters:
    ///   - red: Single red channel value
    ///   - ir: Single infrared channel value
    /// - Returns: SpO2Result (may be empty if buffer not full)
    public func addSample(red: Double, ir: Double) -> SpO2Result {
        redBuffer.append(red)
        irBuffer.append(ir)

        // Maintain buffer size
        if redBuffer.count > bufferSize {
            redBuffer.removeFirst()
            irBuffer.removeFirst()
        }

        // Process when buffer is full
        guard redBuffer.count >= minSamplesRequired else {
            return .empty
        }

        return process(redSamples: redBuffer, irSamples: irBuffer)
    }

    /// Reset internal buffers
    public func reset() {
        redBuffer.removeAll(keepingCapacity: true)
        irBuffer.removeAll(keepingCapacity: true)
    }

    /// Get buffer fill level (0.0 to 1.0)
    public var bufferFillLevel: Double {
        Double(redBuffer.count) / Double(minSamplesRequired)
    }

    // MARK: - Private Methods

    /// Apply moving average filter for noise reduction
    private func applyMovingAverage(_ signal: [Double]) -> [Double] {
        guard signal.count >= smoothingWindow else {
            return signal
        }

        var smoothed: [Double] = []
        smoothed.reserveCapacity(signal.count)

        for i in 0..<signal.count {
            let start = max(0, i - smoothingWindow / 2)
            let end = min(signal.count, i + smoothingWindow / 2 + 1)
            let window = Array(signal[start..<end])
            let average = window.reduce(0.0, +) / Double(window.count)
            smoothed.append(average)
        }

        return smoothed
    }

    /// Calculate mean of signal
    private func calculateMean(_ signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }
        return signal.reduce(0.0, +) / Double(signal.count)
    }

    /// Calculate peak-to-peak amplitude (AC component)
    private func calculatePeakToPeak(_ signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }
        let maxValue = signal.max() ?? 0
        let minValue = signal.min() ?? 0
        return maxValue - minValue
    }

    /// Calculate standard deviation
    private func calculateStandardDeviation(_ signal: [Double]) -> Double {
        guard signal.count > 1 else { return 0 }

        let mean = calculateMean(signal)
        let squaredDiffs = signal.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0.0, +) / Double(signal.count - 1)

        return sqrt(variance)
    }

    /// Convert R ratio to SpO2 using selected calibration curve
    private func convertRToSpO2(_ rRatio: Double) -> Double {
        switch calibrationCurve {
        case .linear:
            // SpO2 = 110 - 25 * R
            return 110.0 - 25.0 * rRatio

        case .quadratic:
            // SpO2 = -45.060 * R^2 + 30.354 * R + 94.845
            return -45.060 * pow(rRatio, 2) + 30.354 * rRatio + 94.845

        case .cubic:
            // SpO2 = 10.287 * R^3 - 52.887 * R^2 + 26.871 * R + 98.283
            return 10.287 * pow(rRatio, 3) - 52.887 * pow(rRatio, 2) + 26.871 * rRatio + 98.283
        }
    }

    /// Calculate signal quality score (0.0 to 1.0)
    private func calculateSignalQuality(
        redSamples: [Double],
        irSamples: [Double],
        acRed: Double,
        acIR: Double,
        dcRed: Double,
        dcIR: Double
    ) -> Double {
        // Factor 1: Signal-to-noise ratio (SNR)
        let snrRed = dcRed > 0 ? acRed / dcRed : 0
        let snrIR = dcIR > 0 ? acIR / dcIR : 0
        let avgSNR = (snrRed + snrIR) / 2.0
        let snrScore = min(1.0, avgSNR / 0.1)  // 0.1 is good SNR

        // Factor 2: Signal stability (inverse of coefficient of variation)
        let stdRed = calculateStandardDeviation(redSamples)
        let stdIR = calculateStandardDeviation(irSamples)
        let cvRed = dcRed > 0 ? stdRed / dcRed : 1.0
        let cvIR = dcIR > 0 ? stdIR / dcIR : 1.0
        let stability = 1.0 - min(1.0, (cvRed + cvIR) / 2.0)

        // Factor 3: Signal amplitude
        let amplitudeScore = min(1.0, (acRed + acIR) / 20000.0)

        // Factor 4: DC level adequacy (not saturated, not too weak)
        let dcRedScore = (dcRed > 10000 && dcRed < 500000) ? 1.0 : 0.5
        let dcIRScore = (dcIR > 10000 && dcIR < 500000) ? 1.0 : 0.5
        let dcScore = (dcRedScore + dcIRScore) / 2.0

        // Weighted combination
        let quality = (
            snrScore * 0.4 +       // 40% weight on SNR
            stability * 0.3 +       // 30% weight on stability
            amplitudeScore * 0.2 +  // 20% weight on amplitude
            dcScore * 0.1           // 10% weight on DC levels
        )

        return max(0.0, min(1.0, quality))
    }
}

// MARK: - Factory Methods

extension SpO2Service {

    /// Create service configured for Oralable device (50 Hz)
    public static func oralable() -> SpO2Service {
        SpO2Service(
            minSamples: 150,     // 3 seconds at 50Hz
            bufferSize: 250,     // 5 seconds at 50Hz
            validRange: 70...100,
            minQuality: 0.5,
            smoothingWindow: 10,
            calibration: .quadratic
        )
    }

    /// Create service for clinical use (stricter validation)
    public static func clinical() -> SpO2Service {
        SpO2Service(
            minSamples: 200,     // 4 seconds at 50Hz
            bufferSize: 300,     // 6 seconds at 50Hz
            validRange: 70...100,
            minQuality: 0.7,     // Higher quality threshold
            smoothingWindow: 15,
            calibration: .quadratic
        )
    }

    /// Create service for demo mode (faster response)
    public static func demo() -> SpO2Service {
        SpO2Service(
            minSamples: 50,      // 1 second at 50Hz
            bufferSize: 100,     // 2 seconds at 50Hz
            validRange: 70...100,
            minQuality: 0.3,
            smoothingWindow: 5,
            calibration: .linear
        )
    }
}

// MARK: - SpO2 Utilities

extension SpO2Service {

    /// Calculate R ratio from AC/DC components
    /// - Parameters:
    ///   - acRed: AC component of red channel
    ///   - dcRed: DC component of red channel
    ///   - acIR: AC component of IR channel
    ///   - dcIR: DC component of IR channel
    /// - Returns: R ratio value
    public static func calculateRRatio(
        acRed: Double,
        dcRed: Double,
        acIR: Double,
        dcIR: Double
    ) -> Double {
        guard dcRed > 0, dcIR > 0, acIR > 0 else { return 0 }
        let ratioRed = acRed / dcRed
        let ratioIR = acIR / dcIR
        return ratioRed / ratioIR
    }

    /// Convert R ratio to SpO2 using default quadratic calibration
    /// - Parameter rRatio: R ratio value
    /// - Returns: SpO2 percentage
    public static func rRatioToSpO2(_ rRatio: Double) -> Double {
        // Quadratic calibration curve
        let spo2 = -45.060 * pow(rRatio, 2) + 30.354 * rRatio + 94.845
        return max(70, min(100, spo2))
    }

    /// Get expected R ratio for a given SpO2 value (inverse lookup)
    /// - Parameter spo2: Target SpO2 percentage
    /// - Returns: Expected R ratio (approximate)
    public static func spO2ToRRatio(_ spo2: Double) -> Double {
        // Linear approximation for inverse lookup
        // R = (110 - SpO2) / 25
        return (110.0 - spo2) / 25.0
    }
}
