//
//  IRDCProcessor.swift
//  OralableCore
//
//  IR DC baseline extraction, rolling statistics, and occlusion / shift detection.
//  Low-pass uses `TransferFunctionFilter.irDCLowpass()` (AlgorithmSpec.irDCLowpassCutoff).
//  Reference: cursor_oralable/src/analysis/features.py compute_filters(), _ir_dc_shift_5s()
//

import Foundation

/// Processes IR signal to extract DC baseline for occlusion and activity detection.
public final class IRDCProcessor {

    public let sampleRate: Double

    private let rollingWindowSamples: Int
    private let referenceWindowSamples: Int
    private let maxBufferSize: Int

    /// Lowpass for DC extraction (matches Python 0.8 Hz, order 4 — scipy `(b,a)`).
    private let lowpassFilter: TransferFunctionFilter

    private var rawBuffer: [Double] = []
    private var dcBuffer: [Double] = []

    public private(set) var calibrationBaseline: Double?

    public var isCalibrated: Bool {
        calibrationBaseline != nil
    }

    public private(set) var currentRawIR: Double = 0
    public private(set) var currentDC: Double = 0
    public private(set) var rollingMean: Double = 0
    public private(set) var dcShift: Double = 0
    public private(set) var normalizedPercent: Double?

    public init(sampleRate: Double = AlgorithmSpec.ppgSampleRate) {
        self.sampleRate = sampleRate
        self.maxBufferSize = Int(sampleRate * 60)
        self.rollingWindowSamples = Int(AlgorithmSpec.irDCRollingWindowSeconds * sampleRate)
        self.referenceWindowSamples = Int(AlgorithmSpec.irDCReferenceWindowSeconds * sampleRate)
        self.lowpassFilter = TransferFunctionFilter.irDCLowpass()
    }

    public func process(_ sample: PPGData) -> IRDCResult {
        processSample(Double(sample.ir))
    }

    public func processSample(_ irValue: Double) -> IRDCResult {
        currentRawIR = irValue

        rawBuffer.append(irValue)
        if rawBuffer.count > maxBufferSize {
            rawBuffer.removeFirst()
        }

        let dc = lowpassFilter.processSample(irValue)
        currentDC = dc

        dcBuffer.append(dc)
        if dcBuffer.count > maxBufferSize {
            dcBuffer.removeFirst()
        }

        updateRollingMean()
        updateShift()
        updateNormalizedPercent()

        return IRDCResult(
            dcValue: currentDC,
            rollingMean5s: rollingMean,
            shift5s: dcShift,
            normalizedPercent: normalizedPercent
        )
    }

    public func processBatch(_ samples: [PPGData]) -> IRDCResult {
        var result = IRDCResult.empty
        for sample in samples {
            result = processSample(Double(sample.ir))
        }
        return result
    }

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

        let refSamples = Array(window.prefix(referenceWindowSamples))
        let baseline = refSamples.reduce(0, +) / Double(refSamples.count)
        let windowMean = window.reduce(0, +) / Double(window.count)
        dcShift = baseline - windowMean
    }

    private func updateNormalizedPercent() {
        guard let baseline = calibrationBaseline, baseline > 0 else {
            normalizedPercent = nil
            return
        }
        normalizedPercent = ((currentRawIR - baseline) / baseline) * 100.0
    }

    public func setCalibration(baseline: Double) {
        calibrationBaseline = baseline
    }

    public func calculateCalibrationBaseline(sampleCount: Int? = nil) -> Double? {
        let count = sampleCount ?? Int(AlgorithmSpec.calibrationDurationSeconds * sampleRate)
        let samples = Array(rawBuffer.suffix(count))

        guard samples.count >= AlgorithmSpec.calibrationMinSamples else {
            return nil
        }

        let sorted = samples.sorted()
        let median: Double
        if sorted.count % 2 == 0 {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        } else {
            median = sorted[sorted.count / 2]
        }

        return median
    }

    @discardableResult
    public func calibrate() -> Bool {
        guard let baseline = calculateCalibrationBaseline() else {
            return false
        }

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

    public func clearCalibration() {
        calibrationBaseline = nil
        normalizedPercent = nil
    }

    public func hasSignificantShift(threshold: Double? = nil) -> Bool {
        let thresh = threshold ?? AlgorithmSpec.irDCShiftThreshold
        if dcShift > thresh {
            return true
        }
        return relativeDropPercent() > AlgorithmSpec.irDCRelativeDropThresholdPercent
    }

    public func isAboveActivityThreshold(threshold: Double? = nil) -> Bool? {
        guard let normalized = normalizedPercent else { return nil }
        let thresh = threshold ?? AlgorithmSpec.activityThresholdPercent
        return normalized > thresh
    }

    /// Relative occlusion drop over rolling mean (%), robust to elevated DC offsets.
    public func relativeDropPercent() -> Double {
        guard rollingMean > 1e-9 else { return 0 }
        return (dcShift / rollingMean) * 100.0
    }

    public func getRecentRawValues(count: Int? = nil) -> [Double] {
        if let c = count {
            return Array(rawBuffer.suffix(c))
        }
        return rawBuffer
    }

    public func getRecentDCValues(count: Int? = nil) -> [Double] {
        if let c = count {
            return Array(dcBuffer.suffix(c))
        }
        return dcBuffer
    }

    public var bufferSize: Int { rawBuffer.count }

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

    public func fullReset() {
        reset()
        clearCalibration()
    }
}

extension IRDCProcessor: @unchecked Sendable {}
