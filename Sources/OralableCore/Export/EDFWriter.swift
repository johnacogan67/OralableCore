//
//  EDFWriter.swift
//  OralableCore
//
//  Pure Swift EDF+C writer for Dual A / research Share packs.
//  When ANR is used, include EMG channel (required for Dual A).
//

import Foundation

public struct EDFChannel: Sendable, Equatable {
    public var label: String
    public var unit: String
    public var samples: [Double]
    public var physicalMin: Double
    public var physicalMax: Double

    public init(
        label: String,
        unit: String = "",
        samples: [Double],
        physicalMin: Double? = nil,
        physicalMax: Double? = nil
    ) {
        self.label = String(label.prefix(16))
        self.unit = String(unit.prefix(8))
        self.samples = samples
        let finite = samples.filter(\.isFinite)
        let lo = physicalMin ?? (finite.min() ?? 0)
        var hi = physicalMax ?? (finite.max() ?? 1)
        if hi <= lo { hi = lo + 1 }
        self.physicalMin = lo
        self.physicalMax = hi
    }
}

public struct EDFAnnotation: Sendable, Equatable {
    /// Onset from recording start (seconds).
    public var onsetSeconds: Double
    /// Duration seconds; nil = instantaneous.
    public var durationSeconds: Double?
    public var text: String

    public init(onsetSeconds: Double, durationSeconds: Double? = nil, text: String) {
        self.onsetSeconds = onsetSeconds
        self.durationSeconds = durationSeconds
        self.text = String(text.prefix(40))
    }
}

public enum EDFWriterError: Error, LocalizedError, Sendable, Equatable {
    case emptyChannels
    case unequalLength
    case durationTooShort
    case missingEMG
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyChannels: return "No EDF channels to write."
        case .unequalLength: return "EDF channels must have equal sample counts."
        case .durationTooShort: return "Need at least 1 second of 50 Hz data."
        case .missingEMG: return "Dual A EDF requires ANR EMG channel."
        case .writeFailed(let m): return m
        }
    }
}

public enum EDFWriter {
    private static let recordDurationSeconds = 1
    private static let annotationSamplesPerRecord = 60 // 120 bytes / record

    /// Write EDF+C. Set `requireEMG` true for Dual A (ANR used).
    public static func write(
        channels: [EDFChannel],
        annotations: [EDFAnnotation] = [],
        to url: URL,
        startDate: Date = Date(),
        patientId: String = "X X X X",
        recordingId: String = "Startdate X X X X",
        requireEMG: Bool = false
    ) throws {
        guard !channels.isEmpty else { throw EDFWriterError.emptyChannels }
        if requireEMG {
            guard channels.contains(where: { $0.label == EDFExportSpec.channelEMG }) else {
                throw EDFWriterError.missingEMG
            }
        }
        let n = channels[0].samples.count
        guard channels.allSatisfy({ $0.samples.count == n }) else {
            throw EDFWriterError.unequalLength
        }
        let fs = Int(EDFExportSpec.sampleRateHz)
        let nRecords = n / fs
        guard nRecords >= 1 else { throw EDFWriterError.durationTooShort }
        let nKeep = nRecords * fs

        let ordinary = channels.map { ch -> EDFChannel in
            var c = ch
            c.samples = Array(ch.samples.prefix(nKeep))
            return c
        }

        let nsOrdinary = ordinary.count
        let nsTotal = nsOrdinary + 1 // + EDF Annotations
        let headerBytes = 256 + nsTotal * 256

        var data = Data()
        data.reserveCapacity(headerBytes + nRecords * (nsOrdinary * fs * 2 + annotationSamplesPerRecord * 2))

        // Fixed header (256)
        appendASCII(&data, "0", width: 8)
        appendASCII(&data, asciiOnly(patientId), width: 80)
        appendASCII(&data, asciiOnly(recordingId), width: 80)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone.current, from: startDate)
        let dd = String(format: "%02d", comps.day ?? 1)
        let mm = String(format: "%02d", comps.month ?? 1)
        let yy = String(format: "%02d", (comps.year ?? 2000) % 100)
        let hh = String(format: "%02d", comps.hour ?? 0)
        let mi = String(format: "%02d", comps.minute ?? 0)
        let ss = String(format: "%02d", comps.second ?? 0)
        appendASCII(&data, "\(dd).\(mm).\(yy)", width: 8)
        appendASCII(&data, "\(hh).\(mi).\(ss)", width: 8)
        appendASCII(&data, "\(headerBytes)", width: 8)
        appendASCII(&data, "EDF+C", width: 44)
        appendASCII(&data, "\(nRecords)", width: 8)
        appendASCII(&data, "\(recordDurationSeconds)", width: 8)
        appendASCII(&data, "\(nsTotal)", width: 4)

        // Per-signal interleaved headers
        var labels: [String] = ordinary.map(\.label)
        labels.append("EDF Annotations")
        for l in labels { appendASCII(&data, l, width: 16) }

        var transducers = Array(repeating: "Oralable-ANR", count: nsOrdinary)
        transducers.append("")
        for t in transducers { appendASCII(&data, t, width: 80) }

        var dims = ordinary.map(\.unit)
        dims.append("")
        for d in dims { appendASCII(&data, d, width: 8) }

        var pmins = ordinary.map { formatPhys($0.physicalMin) }
        pmins.append("-1")
        for v in pmins { appendASCII(&data, v, width: 8) }

        var pmaxs = ordinary.map { formatPhys($0.physicalMax) }
        pmaxs.append("1")
        for v in pmaxs { appendASCII(&data, v, width: 8) }

        for _ in 0..<nsTotal { appendASCII(&data, "-32768", width: 8) }
        for _ in 0..<nsTotal { appendASCII(&data, "32767", width: 8) }
        for _ in 0..<nsTotal { appendASCII(&data, "", width: 80) }

        var samplesPerRecord: [String] = Array(repeating: "\(fs)", count: nsOrdinary)
        samplesPerRecord.append("\(annotationSamplesPerRecord)")
        for s in samplesPerRecord { appendASCII(&data, s, width: 8) }
        for _ in 0..<nsTotal { appendASCII(&data, "", width: 32) }

        precondition(data.count == headerBytes)

        // Group annotations by record index
        var byRecord: [Int: [EDFAnnotation]] = [:]
        for ann in annotations {
            let idx = max(0, min(nRecords - 1, Int(floor(ann.onsetSeconds))))
            byRecord[idx, default: []].append(ann)
        }

        for r in 0..<nRecords {
            for ch in ordinary {
                let pmin = ch.physicalMin
                let pmax = ch.physicalMax
                let scale = (pmax - pmin) > 0 ? 65535.0 / (pmax - pmin) : 1.0
                let base = r * fs
                for i in 0..<fs {
                    let v = ch.samples[base + i]
                    let clipped = min(pmax, max(pmin, v.isFinite ? v : pmin))
                    var dig = Int(((clipped - pmin) * scale) - 32768.0)
                    dig = min(32767, max(-32768, dig))
                    var le = Int16(clamping: dig).littleEndian
                    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
                }
            }
            // Annotation signal for this record
            let tal = buildTAL(
                recordIndex: r,
                annotations: byRecord[r] ?? []
            )
            var annBytes = Array(tal.utf8)
            let need = annotationSamplesPerRecord * 2
            if annBytes.count > need {
                annBytes = Array(annBytes.prefix(need))
            }
            while annBytes.count < need { annBytes.append(0) }
            data.append(contentsOf: annBytes)
        }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try data.write(to: url, options: .atomic)
        } catch {
            throw EDFWriterError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private static func buildTAL(recordIndex: Int, annotations: [EDFAnnotation]) -> String {
        // Time-keeping TAL: onset from start of recording
        var s = "+\(recordIndex)\u{14}\u{14}\u{00}"
        for ann in annotations {
            let localOnset = ann.onsetSeconds - Double(recordIndex)
            var tal = "+\(formatOnset(localOnset))\u{14}"
            if let dur = ann.durationSeconds, dur > 0 {
                tal += "\(formatOnset(dur))\u{14}"
            }
            tal += "\(asciiOnly(ann.text))\u{14}\u{00}"
            s += tal
        }
        return s
    }

    private static func formatOnset(_ v: Double) -> String {
        String(format: "%.4g", v)
    }

    private static func formatPhys(_ v: Double) -> String {
        let av = abs(v)
        let s: String
        if av >= 1e6 {
            s = String(format: "%.3e", v)
        } else if av >= 1000 {
            s = String(format: "%.1f", v)
        } else {
            s = String(format: "%.4g", v)
        }
        return String(s.prefix(8))
    }

    private static func asciiOnly(_ s: String) -> String {
        String(s.unicodeScalars.filter { $0.isASCII && $0.value >= 32 && $0.value < 127 }.map(Character.init))
    }

    private static func appendASCII(_ data: inout Data, _ s: String, width: Int) {
        var bytes = Array(asciiOnly(s).utf8)
        if bytes.count > width {
            bytes = Array(bytes.prefix(width))
        }
        while bytes.count < width { bytes.append(0x20) } // space pad
        data.append(contentsOf: bytes)
    }
}

// MARK: - Grid builder (Dual A / Oralable-only)

public enum EDFSessionGrid {
    public struct Point: Sendable {
        public var time: Date
        public var red: Double?
        public var ir: Double?
        public var green: Double?
        public var accX: Double?
        public var accY: Double?
        public var accZ: Double?
        public var spo2: Double?

        public init(
            time: Date,
            red: Double? = nil,
            ir: Double? = nil,
            green: Double? = nil,
            accX: Double? = nil,
            accY: Double? = nil,
            accZ: Double? = nil,
            spo2: Double? = nil
        ) {
            self.time = time
            self.red = red
            self.ir = ir
            self.green = green
            self.accX = accX
            self.accY = accY
            self.accZ = accZ
            self.spo2 = spo2
        }
    }

    /// Resample Oralable points + optional ANR EMG onto a 50 Hz elapsed grid.
    /// Raw Red/Green are omitted by default (EDFbrowser amplitude); pass `includeRawPPG: true` for AC-scaled a.u.
    public static func buildChannels(
        oralable: [Point],
        emg: [(Date, Double)],
        requireEMG: Bool,
        includeRawPPG: Bool = false
    ) throws -> (channels: [EDFChannel], annotations: [EDFAnnotation], start: Date) {
        let start: Date
        if let o = oralable.first?.time {
            start = o
        } else if let e = emg.first?.0 {
            start = e
        } else {
            throw EDFWriterError.durationTooShort
        }

        let endCandidates = [oralable.last?.time, emg.last?.0].compactMap { $0 }
        guard let end = endCandidates.max() else { throw EDFWriterError.durationTooShort }
        let duration = end.timeIntervalSince(start)
        let n = max(Int(EDFExportSpec.sampleRateHz), Int((duration * EDFExportSpec.sampleRateHz).rounded(.down)))
        guard n >= Int(EDFExportSpec.sampleRateHz) else { throw EDFWriterError.durationTooShort }

        func interp(_ series: [(Double, Double)], at elapsed: Double) -> Double {
            guard !series.isEmpty else { return .nan }
            if elapsed <= series[0].0 { return series[0].1 }
            if elapsed >= series[series.count - 1].0 { return series[series.count - 1].1 }
            var lo = 0
            var hi = series.count - 1
            while hi - lo > 1 {
                let mid = (lo + hi) / 2
                if series[mid].0 <= elapsed { lo = mid } else { hi = mid }
            }
            let (t0, v0) = series[lo]
            let (t1, v1) = series[hi]
            let u = (elapsed - t0) / max(1e-9, t1 - t0)
            return v0 + u * (v1 - v0)
        }

        let irSeries = oralable.compactMap { p -> (Double, Double)? in
            guard let ir = p.ir else { return nil }
            return (p.time.timeIntervalSince(start), ir)
        }
        let redSeries = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.red else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let greenSeries = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.green else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let spo2Series = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.spo2 else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let axSeries = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.accX else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let aySeries = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.accY else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let azSeries = oralable.compactMap { p -> (Double, Double)? in
            guard let v = p.accZ else { return nil }
            return (p.time.timeIntervalSince(start), v)
        }
        let emgSeries = emg.map { ($0.0.timeIntervalSince(start), $0.1) }

        if requireEMG && emgSeries.count < 2 {
            throw EDFWriterError.missingEMG
        }

        var irDC = [Double](repeating: .nan, count: n)
        var emgOut = [Double](repeating: .nan, count: n)
        var spo2 = [Double](repeating: .nan, count: n)
        var red = [Double](repeating: .nan, count: n)
        var green = [Double](repeating: .nan, count: n)
        var ax = [Double](repeating: .nan, count: n)
        var ay = [Double](repeating: .nan, count: n)
        var az = [Double](repeating: .nan, count: n)

        for i in 0..<n {
            let e = Double(i) / EDFExportSpec.sampleRateHz
            if !irSeries.isEmpty { irDC[i] = interp(irSeries, at: e) }
            if !emgSeries.isEmpty { emgOut[i] = interp(emgSeries, at: e) }
            if !spo2Series.isEmpty { spo2[i] = interp(spo2Series, at: e) }
            if !redSeries.isEmpty { red[i] = interp(redSeries, at: e) }
            if !greenSeries.isEmpty { green[i] = interp(greenSeries, at: e) }
            if !axSeries.isEmpty { ax[i] = interp(axSeries, at: e) }
            if !aySeries.isEmpty { ay[i] = interp(aySeries, at: e) }
            if !azSeries.isEmpty { az[i] = interp(azSeries, at: e) }
        }

        let sashb = SpO2Service.protocolASASHB(spo2: spo2.map { $0.isFinite ? $0 : 100 })
        var channels: [EDFChannel] = []
        if irSeries.count >= 2 {
            // LP <1 Hz + local occlusion vs ~5 s baseline (up = trough); absolute in CSV.
            let (y, lo, hi) = Self.irDCViewer(irDC.map { $0.isFinite ? $0 : 0 })
            channels.append(EDFChannel(label: EDFExportSpec.channelIRDC, unit: "a.u.", samples: y, physicalMin: lo, physicalMax: hi))
        }
        if requireEMG || emgSeries.count >= 2 {
            channels.append(EDFChannel(label: EDFExportSpec.channelEMG, samples: emgOut.map { $0.isFinite ? $0 : 0 }, physicalMin: 0, physicalMax: 1023))
        }
        if spo2Series.count >= 2 {
            // Viewer %dev from 100% so desat/rescue fills the ±100 pane; absolute % in CSV.
            let (y, lo, hi) = Self.spo2Viewer(spo2.map { $0.isFinite ? $0 : 0 })
            channels.append(EDFChannel(label: EDFExportSpec.channelSpO2, unit: "%dev", samples: y, physicalMin: lo, physicalMax: hi))
            channels.append(EDFChannel(label: EDFExportSpec.channelSASHB, unit: "%s", samples: sashb))
        }
        if includeRawPPG {
            if redSeries.count >= 2 {
                let (y, lo, hi) = Self.viewerScale(red.map { $0.isFinite ? $0 : 0 }, invert: false, target: 100)
                channels.append(EDFChannel(label: EDFExportSpec.channelRed, unit: "a.u.", samples: y, physicalMin: lo, physicalMax: hi))
            }
            if greenSeries.count >= 2 {
                let (y, lo, hi) = Self.viewerScale(green.map { $0.isFinite ? $0 : 0 }, invert: false, target: 100)
                channels.append(EDFChannel(label: EDFExportSpec.channelGreen, unit: "a.u.", samples: y, physicalMin: lo, physicalMax: hi))
            }
        }
        if axSeries.count >= 2 {
            channels.append(EDFChannel(label: EDFExportSpec.channelAccX, samples: ax.map { $0.isFinite ? $0 : 0 }))
        }
        if aySeries.count >= 2 {
            channels.append(EDFChannel(label: EDFExportSpec.channelAccY, samples: ay.map { $0.isFinite ? $0 : 0 }))
        }
        if azSeries.count >= 2 {
            channels.append(EDFChannel(label: EDFExportSpec.channelAccZ, samples: az.map { $0.isFinite ? $0 : 0 }))
        }

        guard !channels.isEmpty else { throw EDFWriterError.emptyChannels }

        var annotations: [EDFAnnotation] = []
        // EMG bouts: z-score vs first 60 s (or half)
        if emgSeries.count >= 2 {
            let vals = emgOut.map { $0.isFinite ? $0 : 0 }
            let nBase = min(vals.count / 2, Int(60 * EDFExportSpec.sampleRateHz))
            let base = Array(vals.prefix(max(1, nBase)))
            let med = base.sorted()[base.count / 2]
            let mad = max(1e-6, base.map { abs($0 - med) }.sorted()[base.count / 2])
            let thr = med + 1.5 * 1.4826 * mad
            var i = 0
            while i < vals.count {
                if vals[i] < thr { i += 1; continue }
                var j = i
                while j < vals.count && vals[j] >= thr { j += 1 }
                if j - i >= Int(0.5 * EDFExportSpec.sampleRateHz) {
                    annotations.append(EDFAnnotation(
                        onsetSeconds: Double(i) / EDFExportSpec.sampleRateHz,
                        durationSeconds: Double(j - i) / EDFExportSpec.sampleRateHz,
                        text: EDFExportSpec.annotationEMGBout
                    ))
                }
                i = j
            }
        }
        // SpO2 desat >= 10 s below 90
        if spo2Series.count >= 2 {
            let thr = 90.0
            let minLen = Int(10 * EDFExportSpec.sampleRateHz)
            var i = 0
            while i < spo2.count {
                guard spo2[i].isFinite, spo2[i] < thr else { i += 1; continue }
                var j = i
                while j < spo2.count, spo2[j].isFinite, spo2[j] < thr { j += 1 }
                if j - i >= minLen {
                    annotations.append(EDFAnnotation(
                        onsetSeconds: Double(i) / EDFExportSpec.sampleRateHz,
                        durationSeconds: Double(j - i) / EDFExportSpec.sampleRateHz,
                        text: EDFExportSpec.annotationSpO2Desat
                    ))
                }
                i = j
            }
        }

        return (channels, annotations, start)
    }

    /// Median-center + robust scale into ±target (EDFbrowser default ~±100).
    /// invert: optical occlusion trough → upward peak (EMG-matched).
    private static func viewerScale(
        _ samples: [Double],
        invert: Bool,
        target: Double
    ) -> (samples: [Double], lo: Double, hi: Double) {
        let finite = samples.map { $0.isFinite ? $0 : 0.0 }
        let sorted = finite.sorted()
        let med = sorted.isEmpty ? 0.0 : sorted[sorted.count / 2]
        var y = finite.map { invert ? (med - $0) : ($0 - med) }
        let absSorted = y.map { abs($0) }.sorted()
        let peak: Double
        if absSorted.isEmpty {
            peak = 0
        } else {
            let idx = min(absSorted.count - 1, Int(Double(absSorted.count - 1) * 0.99))
            peak = absSorted[idx]
        }
        let scale = max(peak / (0.9 * target), 1e-9)
        y = y.map { min(target, max(-target, $0 / scale)) }
        return (y, -target, target)
    }

    /// SpO2 deviation from 100%, scaled so session floor ≈ -90 on ±100 pane.
    private static func spo2Viewer(_ samples: [Double]) -> (samples: [Double], lo: Double, hi: Double) {
        let finite = samples.map { $0.isFinite ? $0 : 0.0 }
        let dev = finite.map { $0 - 100.0 }
        var deepest = dev.min() ?? -10.0
        if deepest >= -0.5 { deepest = -10.0 }
        let scale = 90.0 / abs(deepest)
        let y = dev.map { min(10.0, max(-100.0, $0 * scale)) }
        return (y, -100.0, 10.0)
    }

    /// LP IR-DC + occlusion max(0, roll − LP); quiet baseline + upward peaks (EMG-like).
    private static func irDCViewer(_ samples: [Double]) -> (samples: [Double], lo: Double, hi: Double) {
        let finite = samples.map { $0.isFinite ? $0 : 0.0 }
        let lp: [Double]
        if finite.count >= 27 {
            lp = ButterworthFilter.irDCLowpass().filtfilt(finite)
        } else {
            lp = finite
        }
        var win = max(3, Int(5.0 * EDFExportSpec.sampleRateHz))
        if win % 2 == 0 { win += 1 }
        var roll = [Double](repeating: 0, count: lp.count)
        let half = win / 2
        for i in 0..<lp.count {
            let a = max(0, i - half)
            let b = min(lp.count, i + half + 1)
            let slice = lp[a..<b].sorted()
            roll[i] = slice[slice.count / 2]
        }
        var occ = zip(roll, lp).map { max(0.0, $0 - $1) }
        let pos = occ.filter { $0 > 0 }.sorted()
        if !pos.isEmpty {
            let floor = pos[Int(Double(pos.count - 1) * 0.40)]
            occ = occ.map { max(0.0, $0 - floor) }
        }
        return viewerScale(occ, invert: false, target: 100)
    }
}
