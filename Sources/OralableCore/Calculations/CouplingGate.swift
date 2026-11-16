//
//  CouplingGate.swift
//  OralableCore
//
//  Mac Protocol A seat QC (`couple`) — parity with cursor_oralable/src/utils/coupling_gate.py.
//
//  States (only while BLE + PPG are live; ACC corroborates):
//    nil / unknown — no PPG (or waiting for ACC)
//    0 desk — not on body
//    1 poor — on skin, weak pulse / vitals
//    2 good — on skin + IR pulse + plausible HR and/or SpO2 AC
//
//  GATT status `worn` is separate (Protocol A often forces mode 3).
//

import Foundation

public enum CoupleState: Int, Sendable, Equatable {
    case desk = 0
    case poor = 1
    case good = 2
}

public enum CoupleLabel {
    public static func label(_ state: CoupleState?) -> String {
        switch state {
        case .none: return "unknown"
        case .desk: return "desk"
        case .poor: return "poor"
        case .good: return "ok"
        }
    }
}

/// Online Mac seat QC from PPG IR + ACC (+ optional temp / on_dock).
public final class CouplingGate: @unchecked Sendable {

    // Match FW ir_pulse_* in tgm_service.c
    public static let irPulseDCMin: Double = 2_000
    public static let irPulseOnS: Double = 2.5
    public static let irPulseHoldS: Double = 20.0
    public static let piOn: Double = 0.0005
    public static let piOff: Double = 0.0002

    public static let irDCTempleMin32: Double = 10_000_000
    public static let irDCTempleMax32: Double = 70_000_000

    public static let hrMinBPM: Double = 40
    public static let hrMaxBPM: Double = 180
    public static let hrBufferS: Double = 4.0
    public static let vitalsGapGraceS: Double = 20.0
    public static let dcContactS: Double = 1.5
    public static let accStillVar: Double = 2.5e4
    public static let accHighMotionVar: Double = 2.5e6
    public static let accWindow: Int = 50
    public static let ppgStallUnknownS: Double = 8.0

    /// Protocol A cue windows where demotion 2→1 should freeze (elapsed from T=0).
    public static let artifactCueWindows: [(start: Double, end: Double)] = [
        (120, 130),
        (180, 200),
        (240, 270)
    ]

    public var requireAcc: Bool
    public var allowPPGOnly: Bool

    private var stateInternal: CoupleState?
    private var ppgSeen = false
    private var accSeen = false
    private var lastPPGMono: Double = 0
    private var lastAccMono: Double = 0

    private var irDC: Double = 0
    private var irACLP: Double = 0
    private var filtInit = false
    private var pulseLatched = false
    private var pulseGoodSince: Double?
    private var pulseBadSince: Double?
    private var dcOkSince: Double?
    private var dcBadSince: Double?

    private var accMags: [Double] = []
    private var accVar: Double = 0
    private var highMotion = false
    private var still = false

    private var irResidBuf: [(t: Double, v: Double)] = []
    private var hrBPM: Double?
    private var spo2ACOk = false
    private var vitalsOkSince: Double?
    private var vitalsBadSince: Double?

    private var tempC: Double?
    private var onDock = false
    private var freezeDemote = false

    public init(requireAcc: Bool = true, allowPPGOnly: Bool = false) {
        self.requireAcc = requireAcc
        self.allowPPGOnly = allowPPGOnly
    }

    public var state: CoupleState? { stateInternal }

    public var isPulseLatched: Bool { pulseLatched }

    public var heartRateBPM: Double? { hrBPM }

    public var isStill: Bool { still }

    public var streamsReady: Bool {
        guard ppgSeen else { return false }
        if requireAcc && !allowPPGOnly && !accSeen { return false }
        return true
    }

    public func markUnknown() {
        stateInternal = nil
        ppgSeen = false
        accSeen = false
        filtInit = false
        pulseLatched = false
        pulseGoodSince = nil
        pulseBadSince = nil
        dcOkSince = nil
        dcBadSince = nil
        irResidBuf.removeAll(keepingCapacity: true)
        hrBPM = nil
        spo2ACOk = false
        vitalsOkSince = nil
        vitalsBadSince = nil
    }

    public func setOnDock(_ onDock: Bool) {
        self.onDock = onDock
    }

    public func setFreezeDemote(_ freeze: Bool) {
        freezeDemote = freeze
    }

    public func setSessionElapsed(_ elapsedS: Double?) {
        freezeDemote = Self.inArtifactWindow(elapsedS)
    }

    public func feedTempC(_ tempC: Double) {
        guard tempC.isFinite else { return }
        self.tempC = tempC
    }

    @discardableResult
    public func feedPPGSamples(
        irSamples: [Int],
        monoS: Double,
        reds: [Int]? = nil
    ) -> CoupleState? {
        guard !irSamples.isEmpty else { return stateInternal }
        ppgSeen = true
        lastPPGMono = monoS
        let redList = reds ?? []
        for (i, ir) in irSamples.enumerated() {
            let red = i < redList.count ? redList[i] : nil
            updateIRFilters(ir: ir, monoS: monoS, red: red)
        }
        updateHR(monoS: monoS)
        recomputeState(monoS: monoS)
        return stateInternal
    }

    @discardableResult
    public func feedAccMagnitudes(_ magnitudes: [Double], monoS: Double) -> CoupleState? {
        guard !magnitudes.isEmpty else { return stateInternal }
        accSeen = true
        lastAccMono = monoS
        accMags.append(contentsOf: magnitudes)
        let cap = Self.accWindow * 4
        if accMags.count > cap {
            accMags = Array(accMags.suffix(cap))
        }
        let window = Array(accMags.suffix(Self.accWindow))
        if window.count >= 8 {
            let mean = window.reduce(0, +) / Double(window.count)
            accVar = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(window.count)
            still = accVar < Self.accStillVar
            highMotion = accVar > Self.accHighMotionVar
        }
        recomputeState(monoS: monoS)
        return stateInternal
    }

    @discardableResult
    public func tick(monoS: Double) -> CoupleState? {
        if ppgSeen && (monoS - lastPPGMono) >= Self.ppgStallUnknownS {
            markUnknown()
            return nil
        }
        recomputeState(monoS: monoS)
        return stateInternal
    }

    public func statusSnippet() -> String {
        let label = CoupleLabel.label(stateInternal)
        let hr = hrBPM.map { String(format: "%.0f", $0) } ?? "-"
        return "couple=\(label) pulse=\(pulseLatched ? 1 : 0) hr=\(hr) still=\(still ? 1 : 0)"
    }

    // MARK: - Internals

    private static func inArtifactWindow(_ elapsedS: Double?) -> Bool {
        guard let elapsedS else { return false }
        for w in artifactCueWindows where elapsedS >= w.start && elapsedS < w.end {
            return true
        }
        return false
    }

    private func dcInBand() -> Bool {
        let dc = irDC
        if dc < Self.irPulseDCMin { return false }
        if dc >= 1_000_000 {
            return dc >= Self.irDCTempleMin32 && dc <= Self.irDCTempleMax32
        }
        return true
    }

    private func updateIRFilters(ir: Int, monoS: Double, red: Int?) {
        if !filtInit {
            irDC = Double(ir)
            irACLP = 0
            filtInit = true
            return
        }

        var dc = irDC
        let resid = abs(Double(ir) - dc)
        dc += (Double(ir) - dc) / 32.0
        if dc < 0 { dc = 0 }
        irDC = dc
        irACLP += (resid - irACLP) / 8.0
        irResidBuf.append((monoS, Double(ir) - dc))
        let cutoff = monoS - Self.hrBufferS
        irResidBuf = irResidBuf.filter { $0.t >= cutoff }

        if let red, dc > 0 {
            let redResid = abs(Double(red) - dc)
            let piIR = irACLP / max(dc, 1.0)
            spo2ACOk = piIR >= Self.piOff && redResid > 0
        }

        if !dcInBand() {
            dcOkSince = nil
            if dcBadSince == nil { dcBadSince = monoS }
            pulseGoodSince = nil
            if pulseBadSince == nil { pulseBadSince = monoS }
            if let bad = pulseBadSince, monoS - bad >= Self.irPulseHoldS {
                pulseLatched = false
            }
            return
        }

        if dcOkSince == nil { dcOkSince = monoS }
        dcBadSince = nil

        let pi = irACLP / max(irDC, 1.0)
        let pulseOn = pi >= Self.piOn
        let pulseOff = pi < Self.piOff

        if pulseOn {
            pulseBadSince = nil
            if pulseGoodSince == nil { pulseGoodSince = monoS }
            if let good = pulseGoodSince, monoS - good >= Self.irPulseOnS {
                pulseLatched = true
            }
        } else if pulseOff {
            pulseGoodSince = nil
            if pulseBadSince == nil { pulseBadSince = monoS }
            if let bad = pulseBadSince, monoS - bad >= Self.irPulseHoldS {
                pulseLatched = false
            }
        }
    }

    private func updateHR(monoS: Double) {
        _ = monoS
        guard irResidBuf.count >= 20 else {
            hrBPM = nil
            return
        }
        let vals = irResidBuf.map(\.v)
        let times = irResidBuf.map(\.t)
        let peakAbs = vals.map(abs).max() ?? 0
        let thr = max(0, 0.4 * peakAbs)
        var peaks: [Double] = []
        for i in 1..<(vals.count - 1) {
            if vals[i] >= thr && vals[i] >= vals[i - 1] && vals[i] >= vals[i + 1] {
                if peaks.isEmpty || (times[i] - peaks.last!) >= 0.30 {
                    peaks.append(times[i])
                }
            }
        }
        guard peaks.count >= 2 else {
            hrBPM = nil
            return
        }
        var intervals: [Double] = []
        for i in 0..<(peaks.count - 1) {
            intervals.append(peaks[i + 1] - peaks[i])
        }
        let meanI = intervals.reduce(0, +) / Double(intervals.count)
        guard meanI > 0 else {
            hrBPM = nil
            return
        }
        let bpm = 60.0 / meanI
        if bpm >= Self.hrMinBPM && bpm <= Self.hrMaxBPM {
            hrBPM = bpm
        } else {
            hrBPM = nil
        }
    }

    private func vitalsPlausible() -> Bool {
        let hrOk = hrBPM.map { $0 >= Self.hrMinBPM && $0 <= Self.hrMaxBPM } ?? false
        return hrOk || spo2ACOk
    }

    private func recomputeState(monoS: Double) {
        if onDock {
            stateInternal = nil
            return
        }
        if !streamsReady || !filtInit {
            stateInternal = nil
            return
        }

        let dcContact =
            dcOkSince.map { monoS - $0 >= Self.dcContactS } == true
            && dcInBand()

        if !dcContact {
            let lost = dcBadSince.map { monoS - $0 >= min(Self.irPulseHoldS, 3.0) } == true
            if lost || !dcInBand() {
                stateInternal = .desk
            } else if stateInternal == nil {
                stateInternal = .desk
            }
            return
        }

        let vitals = vitalsPlausible()
        if vitals {
            vitalsBadSince = nil
            if vitalsOkSince == nil { vitalsOkSince = monoS }
        } else {
            vitalsOkSince = nil
            if vitalsBadSince == nil { vitalsBadSince = monoS }
        }

        let wantGood = pulseLatched && vitals && !highMotion
        if wantGood {
            stateInternal = .good
            return
        }

        if stateInternal == .good {
            if freezeDemote { return }
            let vitalsGap = vitalsBadSince.map { monoS - $0 >= Self.vitalsGapGraceS } == true
            let pulseLost = !pulseLatched
            if vitalsGap || pulseLost {
                stateInternal = .poor
            }
            return
        }

        stateInternal = .poor
    }
}
