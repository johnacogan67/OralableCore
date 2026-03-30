//
//  ButterworthFilter.swift
//  OralableCore
//
//  Butterworth IIR filter implementation.
//  Reference: cursor_oralable/src/analysis/features.py _butter_bandpass(), _butter_lowpass()
//
//  Location: Sources/OralableCore/Algorithms/ButterworthFilter.swift
//

import Accelerate
import Foundation

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
public class ButterworthFilter {

    public let type: ButterworthFilterType
    public let cutoffLow: Double
    public let cutoffHigh: Double?
    public let sampleRate: Double
    public let order: Int

    private var sosCoefficients: [[Double]] = []
    /// Per-section filter memory for the SOS cascade: one `[s1, s2]` row per biquad (DF-II transposed). Persisted across `processSample` calls.
    private var states: [[Double]] = []
    private var b: [Double] = []
    private var a: [Double] = []
    private var directState: [Double] = []

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
                let normalizedCutoff = cutoffLow / nyquist
                computeLowpassCoefficients(normalizedCutoff: normalizedCutoff)
                return
            }
            let normalizedLow = cutoffLow / nyquist
            let normalizedHigh = high / nyquist
            computeBandpassCoefficients(lowNorm: normalizedLow, highNorm: normalizedHigh)
        }
    }

    private func computeLowpassCoefficients(normalizedCutoff: Double) {
        let wc = tan(.pi * normalizedCutoff)
        let wc2 = wc * wc
        let q = sqrt(2.0)
        let norm = 1.0 / (1.0 + wc / q + wc2)

        let b0 = wc2 * norm
        let b1 = 2.0 * b0
        let b2 = b0

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

    private func computeHighpassCoefficients(normalizedCutoff: Double) {
        let wc = tan(.pi * normalizedCutoff)
        let wc2 = wc * wc
        let q = sqrt(2.0)
        let norm = 1.0 / (1.0 + wc / q + wc2)

        let b0 = norm
        let b1 = -2.0 * norm
        let b2 = norm

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

    private func computeBandpassCoefficients(lowNorm: Double, highNorm: Double) {
        let wcLow = tan(.pi * lowNorm)
        let wcHigh = tan(.pi * highNorm)

        let bw = wcHigh - wcLow
        let w0 = sqrt(wcLow * wcHigh)
        let w02 = w0 * w0

        let q = w0 / bw
        let norm = 1.0 / (1.0 + w0 / q + w02)

        let b0 = (w0 / q) * norm
        let b1 = 0.0
        let b2 = -b0

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
        directState = [Double](repeating: 0.0, count: max(b.count, a.count))
        states = sosCoefficients.map { _ in [0.0, 0.0] }
    }

    public func processSample(_ input: Double) -> Double {
        guard !b.isEmpty && !a.isEmpty else { return input }

        // SOS cascade (monic denominator, a0 = 1 in stored rows — see compute*Coefficients). Output of section i feeds section i+1.
        if !sosCoefficients.isEmpty {
            var x = input
            for i in 0..<sosCoefficients.count {
                let b0 = sosCoefficients[i][0], b1 = sosCoefficients[i][1], b2 = sosCoefficients[i][2]
                let a1 = sosCoefficients[i][4], a2 = sosCoefficients[i][5]
                let y = b0 * x + states[i][0]
                states[i][0] = b1 * x - a1 * y + states[i][1]
                states[i][1] = b2 * x - a2 * y
                x = y
            }
            return x
        }

        let output = b[0] * input + directState[0]

        for i in 0..<(directState.count - 1) {
            let bCoeff = i + 1 < b.count ? b[i + 1] : 0.0
            let aCoeff = i + 1 < a.count ? a[i + 1] : 0.0
            directState[i] = bCoeff * input - aCoeff * output + directState[i + 1]
        }
        directState[directState.count - 1] = 0.0

        return output
    }

    public func process(_ input: [Double]) -> [Double] {
        input.map { processSample($0) }
    }

    public func filtfilt(_ input: [Double]) -> [Double] {
        guard input.count > 3 else { return input }

        let savedDirect = directState
        let savedSOS = states

        reset()
        var forward = process(input)

        forward.reverse()

        reset()
        var backward = process(forward)

        backward.reverse()

        directState = savedDirect
        states = savedSOS

        return backward
    }

    public func reset() {
        directState = [Double](repeating: 0.0, count: directState.count)
        states = sosCoefficients.map { _ in [0.0, 0.0] }
    }
}

// MARK: - AlgorithmSpec factories

extension ButterworthFilter {

    /// IR DC lowpass — coefficients also available via `TransferFunctionFilter.irDCLowpass()` for scipy parity.
    public static func irDCLowpass(sampleRate: Double = AlgorithmSpec.ppgSampleRate) -> ButterworthFilter {
        ButterworthFilter(
            type: .lowpass,
            cutoffLow: AlgorithmSpec.irDCLowpassCutoff,
            sampleRate: sampleRate,
            order: AlgorithmSpec.filterOrder
        )
    }

    /// Heart rate / MAM AC bandpass 0.5–8 Hz (Python `butter` band for HR).
    public static func hrBandpass(sampleRate: Double = AlgorithmSpec.ppgSampleRate) -> ButterworthFilter {
        ButterworthFilter(
            type: .bandpass,
            cutoffLow: AlgorithmSpec.hrBandpassLow,
            cutoffHigh: AlgorithmSpec.hrBandpassHigh,
            sampleRate: sampleRate,
            order: AlgorithmSpec.filterOrder
        )
    }

    /// Temporalis AC bandpass 0.5–4 Hz — for scipy‑exact coefficients use `TransferFunctionFilter.temporalisACBandpass()`.
    public static func temporalisACBandpass(sampleRate: Double = AlgorithmSpec.ppgSampleRate) -> ButterworthFilter {
        ButterworthFilter(
            type: .bandpass,
            cutoffLow: AlgorithmSpec.hrBandpassLow,
            cutoffHigh: AlgorithmSpec.temporalisBandpassHigh,
            sampleRate: sampleRate,
            order: AlgorithmSpec.filterOrder
        )
    }
}

extension ButterworthFilter: @unchecked Sendable {}
