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
    /// Pre-computed ``lfilter_zi`` from SciPy (avoids Gauss–Jordan error on fixed Butterworth designs).
    private let steadyStateZi: [Double]?
    private var state: [Double]  // Direct Form II state (length = max(nb, na) - 1)

    /// Initialize with transfer function coefficients from scipy.signal.butter
    /// - Parameters:
    ///   - b: Numerator coefficients (scipy returns these)
    ///   - a: Denominator coefficients (a[0] should be 1.0)
    ///   - steadyStateZi: Optional SciPy ``lfilter_zi(b,a)`` for exact ``filtfilt`` edges
    public init(b: [Double], a: [Double], steadyStateZi: [Double]? = nil) {
        self.b = b
        self.a = a
        self.steadyStateZi = steadyStateZi
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

    /// Forward-backward filtering (``scipy.signal.filtfilt`` pad + ``lfilter_zi`` initial conditions).
    public func filtfilt(_ input: [Double]) -> [Double] {
        guard input.count > 3 else { return input }
        let ntaps = max(b.count, a.count)
        let edge = ntaps * 3
        guard input.count > edge else { return input }

        let ext = Self.oddExtension(input, n: edge)
        let ziBase = steadyStateZi ?? Self.lfilterZi(b: b, a: a)
        let x0 = ext[0]
        let ziFwd = ziBase.map { $0 * x0 }

        let (yFwd, _) = Self.lfilter(b: b, a: a, x: ext, zi: ziFwd)
        let y0 = yFwd[yFwd.count - 1]
        let ziBwd = ziBase.map { $0 * y0 }
        let (yBwd, _) = Self.lfilter(b: b, a: a, x: yFwd.reversed(), zi: ziBwd)
        let yFull = Array(yBwd.reversed())

        return Array(yFull[edge..<(yFull.count - edge)])
    }

    // MARK: - SciPy-compat static helpers

    private static func oddExtension(_ x: [Double], n: Int) -> [Double] {
        guard n >= 1, x.count > n else { return x }
        let x0 = x[0]
        var left: [Double] = []
        left.reserveCapacity(n)
        for j in stride(from: n, through: 1, by: -1) {
            left.append(2 * x0 - x[j])
        }
        let xN = x[x.count - 1]
        var right: [Double] = []
        right.reserveCapacity(n)
        for j in 2..<(n + 2) {
            let idx = x.count - j
            right.append(2 * xN - x[idx])
        }
        return left + x + right
    }

    /// ``scipy.signal.lfilter_zi`` (steady-state step IC).
    private static func lfilterZi(b: [Double], a: [Double]) -> [Double] {
        var bn = b
        var an = a
        guard let a0 = an.first, abs(a0) > 1e-15 else { return [] }
        if a0 != 1.0 {
            bn = bn.map { $0 / a0 }
            an = an.map { $0 / a0 }
        }
        let n = max(bn.count, an.count)
        var bp = bn
        var ap = an
        if bp.count < n {
            bp.append(contentsOf: [Double](repeating: 0, count: n - bp.count))
        }
        if ap.count < n {
            ap.append(contentsOf: [Double](repeating: 0, count: n - ap.count))
        }
        let m = n - 1
        if m <= 0 { return [] }

        var M = [[Double]](repeating: [Double](repeating: 0, count: m), count: m)
        for r in 0..<m {
            for c in 0..<m {
                let ident = (r == c) ? 1.0 : 0.0
                let cElem: Double
                if c == 0 { cElem = -ap[r + 1] }
                else if c >= 1, r == c - 1 { cElem = 1.0 }
                else { cElem = 0.0 }
                M[r][c] = ident - cElem
            }
        }

        var rhs = [Double](repeating: 0, count: m)
        for i in 0..<m {
            rhs[i] = bp[i + 1] - ap[i + 1] * bp[0]
        }
        return solveLinearSystem(A: M, b: rhs)
    }

    /// Solves ``A x = b`` for small dense ``A`` (Gauss–Jordan).
    private static func solveLinearSystem(A: [[Double]], b: [Double]) -> [Double] {
        let n = b.count
        guard n > 0, A.count == n, A[0].count == n else { return b }
        var M = A
        var x = b
        for k in 0..<n {
            var piv = k
            for i in (k + 1)..<n {
                if abs(M[i][k]) > abs(M[piv][k]) { piv = i }
            }
            if piv != k {
                M.swapAt(piv, k)
                x.swapAt(piv, k)
            }
            let diag = M[k][k]
            if abs(diag) < 1e-18 { return [Double](repeating: 0, count: n) }
            for j in 0..<n { M[k][j] /= diag }
            x[k] /= diag
            for i in 0..<n where i != k {
                let f = M[i][k]
                if abs(f) < 1e-18 { continue }
                for j in 0..<n { M[i][j] -= f * M[k][j] }
                x[i] -= f * x[k]
            }
        }
        return x
    }

    /// ``scipy.signal.lfilter`` with optional initial state (DF II transposed).
    private static func lfilter(b: [Double], a: [Double], x: [Double], zi: [Double]?) -> ([Double], [Double]) {
        var bn = b
        var an = a
        guard let a0 = an.first, abs(a0) > 1e-15 else { return (x, []) }
        if a0 != 1.0 {
            bn = bn.map { $0 / a0 }
            an = an.map { $0 / a0 }
        }
        let n = max(bn.count, an.count)
        var bp = bn
        var ap = an
        if bp.count < n {
            bp.append(contentsOf: [Double](repeating: 0, count: n - bp.count))
        }
        if ap.count < n {
            ap.append(contentsOf: [Double](repeating: 0, count: n - ap.count))
        }
        let m = n - 1
        var z = zi ?? [Double](repeating: 0, count: m)
        if z.count < m {
            z.append(contentsOf: [Double](repeating: 0, count: m - z.count))
        } else if z.count > m {
            z = Array(z.prefix(m))
        }

        var y = [Double](repeating: 0, count: x.count)
        for t in 0..<x.count {
            let xi = x[t]
            let yi = bp[0] * xi + z[0]
            y[t] = yi
            if m == 1 {
                z[0] = bp[1] * xi - ap[1] * yi
            } else {
                for i in 0..<(m - 1) {
                    z[i] = bp[i + 1] * xi - ap[i + 1] * yi + z[i + 1]
                }
                z[m - 1] = bp[m] * xi - ap[m] * yi
            }
        }
        return (y, z)
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
        return TransferFunctionFilter(
            b: b,
            a: a,
            steadyStateZi: [
                0.9999943834352425, -2.7373814737904896, 2.508588132840459, -0.7688671273024655
            ]
        )
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
        return TransferFunctionFilter(
            b: b,
            a: a,
            steadyStateZi: [
                -0.018563010617193284, -0.01856301066941182, 0.0556890319619669, 0.05568903179112236,
                -0.05568903181861021, -0.055689031907585534, 0.018563010633555883, 0.018563010626157773
            ]
        )
    }

    /// Temporalis PPG AC bandpass: 4th-order Butterworth, 0.5–4 Hz, fs=50 Hz
    /// Python: `scipy.signal.butter(4, [0.5/25, 4/25], btype='band')`
    public static func temporalisACBandpass() -> TransferFunctionFilter {
        let b: [Double] = [
            0.0013974753593581635,
            0.0,
            -0.005589901437432654,
            0.0,
            0.00838485215614898,
            0.0,
            -0.005589901437432654,
            0.0,
            0.0013974753593581635
        ]
        let a: [Double] = [
            1.0,
            -6.745129351175544,
            20.03216197823941,
            -34.23711133289609,
            36.84995311765309,
            -25.58472163744186,
            11.191389945327915,
            -2.8199133792458992,
            0.31337124779083303
        ]
        return TransferFunctionFilter(
            b: b,
            a: a,
            steadyStateZi: [
                -0.0013974753597267816, -0.0013974753572404052, 0.004192426072808027, 0.00419242608542845,
                -0.00419242608430409, -0.004192426074873098, 0.0013974753584342066, 0.0013974753594736778
            ]
        )
    }
}
