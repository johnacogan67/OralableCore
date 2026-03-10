//
//  TransferFunctionFilter.swift
//  OralableCore
//
//  Created for parity with scipy.signal.butter + filtfilt
//  Reference: cursor_oralable/src/analysis/features.py compute_filters()
//  Uses exact (b,a) coefficients from scipy.signal.butter for bit-exact parity.
//

import Foundation

// MARK: - Transfer Function Filter

/// IIR filter using exact transfer function coefficients (b, a).
/// Implements scipy.signal.lfilter equivalent: y[n] = sum(b[i]*x[n-i]) - sum(a[1:]*y[n-i])
/// Supports filtfilt for zero-phase filtering (matches scipy.signal.filtfilt).
public final class TransferFunctionFilter: @unchecked Sendable {

    private let b: [Double]
    private let a: [Double]
    private var state: [Double]  // Direct Form II state (length = max(nb, na) - 1)

    /// Initialize with transfer function coefficients from scipy.signal.butter
    /// - Parameters:
    ///   - b: Numerator coefficients (scipy returns these)
    ///   - a: Denominator coefficients (a[0] should be 1.0)
    public init(b: [Double], a: [Double]) {
        self.b = b
        self.a = a
        let n = max(b.count, a.count) - 1
        self.state = [Double](repeating: 0, count: n)
    }

    /// Reset filter state
    public func reset() {
        state = [Double](repeating: 0, count: state.count)
    }

    /// Single-sample filter (Direct Form II Transposed, matches scipy.signal.lfilter)
    /// y = (b[0]*x + z0)/a0; z0_new = b[1]*x - a[1]*y + z1; z1_new = b[2]*x - a[2]*y + z2; ...
    public func processSample(_ input: Double) -> Double {
        guard !b.isEmpty, !a.isEmpty else { return input }
        let a0 = a[0]
        guard abs(a0) > 1e-15 else { return input }

        let y = (b[0] * input + state[0]) / a0
        for i in 0..<state.count {
            let bi = (i + 1) < b.count ? b[i + 1] : 0.0
            let ai = (i + 1) < a.count ? a[i + 1] : 0.0
            let nextState = (i + 1) < state.count ? state[i + 1] : 0.0
            state[i] = bi * input - ai * y + nextState
        }
        return y
    }

    /// Forward pass only (like scipy lfilter)
    public func process(_ input: [Double]) -> [Double] {
        input.map { processSample($0) }
    }

    /// Forward-backward filtering (zero-phase, matches scipy.signal.filtfilt)
    public func filtfilt(_ input: [Double]) -> [Double] {
        guard input.count > 3 else { return input }
        let saved = state
        reset()
        var forward = process(input)
        forward.reverse()
        reset()
        var backward = process(forward)
        backward.reverse()
        state = saved
        return backward
    }
}

// MARK: - Scipy Parity Factory

/// Factory for filters with exact scipy.signal.butter coefficients.
/// Coefficients from: butter(4, 0.8/25, btype='low') and butter(4, [0.5/25, 8/25], btype='band') at fs=50.
extension TransferFunctionFilter {

    /// IR DC lowpass: 4th-order Butterworth, 0.8 Hz cutoff, fs=50 Hz
    /// Python: butter(4, 0.8/(50/2), btype='low')
    public static func irDCLowpass() -> TransferFunctionFilter {
        let b: [Double] = [
            5.6165622863812905e-06,
            2.2466249145525162e-05,
            3.3699373718287745e-05,
            2.2466249145525162e-05,
            5.6165622863812905e-06
        ]
        let a: [Double] = [
            1.0,
            -3.737353390985822,
            5.246003306017631,
            -3.2774327939018777,
            0.7688727438666517
        ]
        return TransferFunctionFilter(b: b, a: a)
    }

    /// Heart rate bandpass: 4th-order Butterworth, 0.5–8 Hz, fs=50 Hz
    /// Python: butter(4, [0.5/25, 8/25], btype='band')
    public static func hrBandpass() -> TransferFunctionFilter {
        let b: [Double] = [
            0.01856301062689718,
            0.0,
            -0.07425204250758873,
            0.0,
            0.1113780637613831,
            0.0,
            -0.07425204250758873,
            0.0,
            0.01856301062689718
        ]
        let a: [Double] = [
            1.0,
            -5.381191122920367,
            12.756735008986515,
            -17.605766754829027,
            15.627798245411533,
            -9.169030300274239,
            3.4576491641358897,
            -0.7623854394835639,
            0.07619706461033242
        ]
        return TransferFunctionFilter(b: b, a: a)
    }
}
