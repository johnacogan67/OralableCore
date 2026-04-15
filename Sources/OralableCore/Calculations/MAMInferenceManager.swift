//
//  MAMInferenceManager.swift
//  OralableCore
//
//  Temporalis MAM: CoreML inference for 1 s windows (50 × 6 tensor @ 50 Hz).
//  States: Quiet, Phasic, Tonic, Rescue (replaces legacy Masseter-only naming in UI elsewhere).
//

import Foundation
import CoreML

// MARK: - Temporalis State

/// Four-class Temporalis / sleep-bruxism state from the research model
public enum TemporalisState: String, Codable, Sendable, CaseIterable {
    case quiet
    case phasic
    case tonic
    case rescue
}

/// Deprecated alias — use `TemporalisState`
public typealias BruxismState = TemporalisState

// MARK: - Class Probabilities

public struct TemporalisProbabilities: Sendable {
    public let quiet: Double
    public let phasic: Double
    public let tonic: Double
    public let rescue: Double

    public init(quiet: Double, phasic: Double, tonic: Double, rescue: Double) {
        self.quiet = quiet
        self.phasic = phasic
        self.tonic = tonic
        self.rescue = rescue
    }

    public var dominantState: TemporalisState {
        let maxVal = max(quiet, phasic, tonic, rescue)
        if quiet == maxVal { return .quiet }
        if phasic == maxVal { return .phasic }
        if tonic == maxVal { return .tonic }
        return .rescue
    }
}

public typealias BruxismProbabilities = TemporalisProbabilities

// MARK: - Classifier Protocol

public protocol TemporalisClassifier: Sendable {
    /// - Parameter input: MLMultiArray of shape [1, 50, 6] (batch, time, channels)
    func classify(input: MLMultiArray) async -> TemporalisState

    /// - Parameter input: MLMultiArray of shape [1, 50, 6]
    func probabilities(input: MLMultiArray) async -> TemporalisProbabilities?
}

public typealias BruxismClassifier = TemporalisClassifier

// MARK: - Mock Classifier

public final class MockTemporalisClassifier: TemporalisClassifier, @unchecked Sendable {
    public init() {}

    public func classify(input: MLMultiArray) async -> TemporalisState {
        await Task.detached(priority: .utility) {
            TemporalisState.allCases.randomElement() ?? .quiet
        }.value
    }

    public func probabilities(input: MLMultiArray) async -> TemporalisProbabilities? {
        let q = Double.random(in: 0.2...0.3)
        let p = Double.random(in: 0.2...0.3)
        let t = Double.random(in: 0.2...0.3)
        let r = 1.0 - q - p - t
        return TemporalisProbabilities(quiet: q, phasic: p, tonic: t, rescue: max(0, r))
    }
}

public typealias MockMAMClassifier = MockTemporalisClassifier

// MARK: - Core ML Classifier

/// CoreML `BruxismMAM_Temporalis` — input [1, 50, 6], output softmax `probabilities` (1×4).
public final class CoreMLTemporalisClassifier: TemporalisClassifier, @unchecked Sendable {
    private let model: MLModel?
    private static let modelName = "BruxismMAM_Temporalis"

    public init() {
        do {
            guard let url = Self.resolveModelURL() else {
                Logger.shared.warning("[Temporalis] BruxismMAM_Temporalis model not found in package/app bundles")
                self.model = nil
                return
            }
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            self.model = try MLModel(contentsOf: url, configuration: config)
            Logger.shared.info("[MAM] SUCCESS: Temporalis Model Loaded from Bundle (\(url.lastPathComponent))")
        } catch {
            Logger.shared.warning("[Temporalis] Failed to load model: \(error)")
            self.model = nil
        }
    }

    private static func resolveModelURL() -> URL? {
        let primaryCandidates: [URL?] = [
            Bundle.module.url(forResource: modelName, withExtension: "mlpackage"),
            Bundle.module.url(forResource: modelName, withExtension: "mlmodelc"),
            Bundle.main.url(forResource: modelName, withExtension: "mlpackage"),
            Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
        ]
        if let found = primaryCandidates.compactMap({ $0 }).first {
            return found
        }

        let bundlesToScan = Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundlesToScan {
            if let direct = bundle.url(forResource: modelName, withExtension: "mlmodelc")
                ?? bundle.url(forResource: modelName, withExtension: "mlpackage") {
                return direct
            }
            guard let resourceURL = bundle.resourceURL else { continue }
            let nestedCandidates = [
                resourceURL.appendingPathComponent("\(modelName).mlmodelc"),
                resourceURL.appendingPathComponent("\(modelName).mlpackage")
            ]
            if let found = nestedCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                return found
            }
        }
        return nil
    }

    public func classify(input: MLMultiArray) async -> TemporalisState {
        if let probs = await probabilities(input: input) {
            return probs.dominantState
        }
        return .quiet
    }

    public func probabilities(input: MLMultiArray) async -> TemporalisProbabilities? {
        guard let model = model else { return nil }
        return await Task.detached(priority: .userInitiated) {
            do {
                let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["input": MLFeatureValue(multiArray: input)])
                let output = try model.prediction(from: inputProvider)
                let probArray = output.featureValue(for: "probabilities")?.multiArrayValue
                    ?? output.featureValue(for: "Identity")?.multiArrayValue
                guard let probArray else {
                    return nil
                }
                let quiet = probArray[[0, 0] as [NSNumber]].doubleValue
                let phasic = probArray[[0, 1] as [NSNumber]].doubleValue
                let tonic = probArray[[0, 2] as [NSNumber]].doubleValue
                let rescue = probArray[[0, 3] as [NSNumber]].doubleValue
                return TemporalisProbabilities(quiet: quiet, phasic: phasic, tonic: tonic, rescue: rescue)
            } catch {
                Logger.shared.warning("[Temporalis] CoreML prediction failed: \(error)")
                return nil
            }
        }.value
    }

    private static func auditInput(_ input: MLMultiArray) -> (irMin: Double, irMax: Double, motionVariance: Double) {
        var irValues: [Double] = []
        var mags: [Double] = []
        irValues.reserveCapacity(50)
        mags.reserveCapacity(50)
        for t in 0..<50 {
            let ir = input[[0, t, 1] as [NSNumber]].doubleValue
            let ax = input[[0, t, 3] as [NSNumber]].doubleValue
            let ay = input[[0, t, 4] as [NSNumber]].doubleValue
            let az = input[[0, t, 5] as [NSNumber]].doubleValue
            irValues.append(ir)
            mags.append(sqrt(ax * ax + ay * ay + az * az))
        }
        let irMin = irValues.min() ?? 0
        let irMax = irValues.max() ?? 0
        let mean = mags.reduce(0.0, +) / Double(max(1, mags.count))
        var varSum = 0.0
        for d in mags {
            let e = d - mean
            varSum += e * e
        }
        let motionVariance = mags.isEmpty ? 0 : varSum / Double(mags.count)
        return (irMin, irMax, motionVariance)
    }
}

public typealias CoreMLMAMClassifier = CoreMLTemporalisClassifier

// MARK: - Clinical Log Manager

public final class ClinicalLogManager: @unchecked Sendable {
    private let fileURL: URL
    private let queue: DispatchQueue
    private var hasWrittenHeader: Bool = false

    public init?(documentsDirectory: URL? = nil) {
        let dir = documentsDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let dir = dir else { return nil }
        self.fileURL = dir.appendingPathComponent("mam_clinical_audit.csv")
        self.queue = DispatchQueue(label: "com.oralable.clinical.log", qos: .utility)
    }

    public func append(timestamp: Date, probabilities: TemporalisProbabilities) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso = formatter.string(from: timestamp)
            let line = "\(iso),\(probabilities.quiet),\(probabilities.phasic),\(probabilities.tonic),\(probabilities.rescue)\n"
            guard let data = line.data(using: .utf8) else { return }
            let exists = FileManager.default.fileExists(atPath: self.fileURL.path)
            if !self.hasWrittenHeader && !exists {
                let header = "timestamp,quiet,phasic,tonic,rescue\n"
                FileManager.default.createFile(atPath: self.fileURL.path, contents: (header + line).data(using: .utf8), attributes: nil)
                self.hasWrittenHeader = true
                return
            }
            self.hasWrittenHeader = true
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            }
        }
    }
}

// MARK: - Classification Buffer

/// 1 s @ 50 Hz, six channels (Temporalis tensor layout):
/// 0: Green AC (0.5–4 Hz), 1: IR DC (<1 Hz), 2: Red AC (0.5–4 Hz), 3–5: accel x,y,z (g).
public struct ClassificationBuffer: Sendable {
    private var greenAC: [Double]
    private var irDC: [Double]
    private var redAC: [Double]
    private var accelX: [Double]
    private var accelY: [Double]
    private var accelZ: [Double]

    public static let windowSize: Int = 50
    public static let strideSize: Int = 50
    public static let historySize: Int = 250
    private static let zScoreEpsilon: Double = 1e-5
    private static let zScoreClamp: ClosedRange<Double> = -5.0...5.0

    public init() {
        self.greenAC = []
        self.irDC = []
        self.redAC = []
        self.accelX = []
        self.accelY = []
        self.accelZ = []
    }

    public mutating func append(
        greenAC: Double,
        irDC: Double,
        redAC: Double,
        accelX: Double,
        accelY: Double,
        accelZ: Double
    ) {
        self.greenAC.append(greenAC)
        self.irDC.append(irDC)
        self.redAC.append(redAC)
        self.accelX.append(accelX)
        self.accelY.append(accelY)
        self.accelZ.append(accelZ)
        trim()
    }

    private mutating func trim() {
        if greenAC.count > Self.historySize {
            greenAC.removeFirst(greenAC.count - Self.historySize)
        }
        if irDC.count > Self.historySize {
            irDC.removeFirst(irDC.count - Self.historySize)
        }
        if redAC.count > Self.historySize {
            redAC.removeFirst(redAC.count - Self.historySize)
        }
        if accelX.count > Self.historySize {
            accelX.removeFirst(accelX.count - Self.historySize)
        }
        if accelY.count > Self.historySize {
            accelY.removeFirst(accelY.count - Self.historySize)
        }
        if accelZ.count > Self.historySize {
            accelZ.removeFirst(accelZ.count - Self.historySize)
        }
    }

    public var count: Int {
        min(greenAC.count, irDC.count, redAC.count, accelX.count, accelY.count, accelZ.count)
    }

    public var isFull: Bool {
        count >= Self.windowSize
    }

    public func convertToMultiArray() -> MLMultiArray? {
        guard count >= Self.windowSize else { return nil }
        let shape = [1, Self.windowSize, 6] as [NSNumber]
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            return nil
        }
        let g = Array(greenAC.suffix(Self.windowSize))
        let irRaw = Array(irDC.suffix(Self.windowSize))
        let r = Array(redAC.suffix(Self.windowSize))
        let axRaw = Array(accelX.suffix(Self.windowSize))
        let ayRaw = Array(accelY.suffix(Self.windowSize))
        let azRaw = Array(accelZ.suffix(Self.windowSize))
        let ir = Self.zScoreNormalized(irRaw)
        let ax = Self.zScoreNormalized(axRaw)
        let ay = Self.zScoreNormalized(ayRaw)
        let az = Self.zScoreNormalized(azRaw)
        for t in 0..<Self.windowSize {
            array[[0, t, 0] as [NSNumber]] = NSNumber(value: Float(g[t]))
            array[[0, t, 1] as [NSNumber]] = NSNumber(value: Float(ir[t]))
            array[[0, t, 2] as [NSNumber]] = NSNumber(value: Float(r[t]))
            array[[0, t, 3] as [NSNumber]] = NSNumber(value: Float(ax[t]))
            array[[0, t, 4] as [NSNumber]] = NSNumber(value: Float(ay[t]))
            array[[0, t, 5] as [NSNumber]] = NSNumber(value: Float(az[t]))
        }
        return array
    }

    fileprivate func featureSnapshot(latestSpO2Estimate: Double?) -> MAMFeatureSnapshot? {
        guard count >= Self.windowSize else { return nil }

        let irHistory = Array(irDC.suffix(Self.historySize))
        let irRecentRaw = Array(irDC.suffix(Self.windowSize))
        let irRecentNorm = Self.zScoreNormalized(irRecentRaw)
        guard !irHistory.isEmpty, !irRecentRaw.isEmpty else { return nil }

        let baselineWindowCount = min(Self.windowSize, irHistory.count)
        let baselineWindow = Array(irHistory.prefix(baselineWindowCount))

        let baseline = baselineWindow.reduce(0.0, +) / Double(max(1, baselineWindow.count))
        let rollingMean = irHistory.reduce(0.0, +) / Double(max(1, irHistory.count))
        let shiftAbsolute = baseline - rollingMean
        let shiftPercent = rollingMean > 1e-9 ? (shiftAbsolute / rollingMean) * 100.0 : 0

        let ax = Array(accelX.suffix(Self.windowSize))
        let ay = Array(accelY.suffix(Self.windowSize))
        let az = Array(accelZ.suffix(Self.windowSize))
        var motionMag: [Double] = []
        motionMag.reserveCapacity(ax.count)
        for i in 0..<ax.count {
            motionMag.append(sqrt(ax[i] * ax[i] + ay[i] * ay[i] + az[i] * az[i]))
        }
        let motionMean = motionMag.reduce(0.0, +) / Double(max(1, motionMag.count))
        var motionVariance = 0.0
        if !motionMag.isEmpty {
            var varianceSum = 0.0
            for m in motionMag {
                let e = m - motionMean
                varianceSum += e * e
            }
            motionVariance = varianceSum / Double(motionMag.count)
        }

        let irRawMin = irRecentRaw.min() ?? 0
        let irRawMax = irRecentRaw.max() ?? 0
        let irNormMin = irRecentNorm.min() ?? 0
        let irNormMax = irRecentNorm.max() ?? 0
        let spo2ForDebug = Self.sanitizeSpO2(latestSpO2Estimate)

        return MAMFeatureSnapshot(
            irDCBaseline: rollingMean,
            irDCShiftPercent: shiftPercent,
            spo2Estimate: spo2ForDebug,
            motionVariance: motionVariance,
            irDCRawMin: irRawMin,
            irDCRawMax: irRawMax,
            irDCNormMin: irNormMin,
            irDCNormMax: irNormMax
        )
    }

    private static func zScoreNormalized(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let mean = values.reduce(0.0, +) / Double(values.count)
        var varSum = 0.0
        for v in values {
            let d = v - mean
            varSum += d * d
        }
        let std = sqrt(varSum / Double(values.count))
        let denom = std + zScoreEpsilon
        return values.map { v in
            let z = (v - mean) / denom
            return min(zScoreClamp.upperBound, max(zScoreClamp.lowerBound, z))
        }
    }

    private static func sanitizeSpO2(_ value: Double?) -> Double {
        guard let value, value.isFinite, !value.isNaN, value > 0 else {
            return 98.0
        }
        return value
    }

    public mutating func reset() {
        greenAC.removeAll()
        irDC.removeAll()
        redAC.removeAll()
        accelX.removeAll()
        accelY.removeAll()
        accelZ.removeAll()
    }
}

private struct MAMFeatureSnapshot: Sendable {
    let irDCBaseline: Double
    let irDCShiftPercent: Double
    let spo2Estimate: Double
    let motionVariance: Double
    let irDCRawMin: Double
    let irDCRawMax: Double
    let irDCNormMin: Double
    let irDCNormMax: Double
}

// MARK: - Inference Manager

public final class MAMInferenceManager: @unchecked Sendable {
    private var buffer: ClassificationBuffer
    private let classifier: any TemporalisClassifier
    private let clinicalLog: ClinicalLogManager?
    private let classificationQueue: DispatchQueue
    /// Minimum IR-DC drop gate before running CoreML inference (percent).
    private let activityGateShiftPercentThreshold: Double
    private let inputGapWarningThresholdSeconds: TimeInterval = 1.0
    private let inputGapWarningCooldownSeconds: TimeInterval = 10.0
    private let diagnosticLogCooldownSeconds: TimeInterval = 15.0
    /// Suppress "gap/OOD" warnings during the first few seconds of a new stream.
    private let warmupSuppressWarningsSeconds: TimeInterval = 10.0
    private var samplesSinceLastClassification: Int = 0
    private var latestSpO2Estimate: Double?
    private var lastSampleArrival: Date?
    private var lastInputGapWarningAt: Date?
    private var lastDiagnosticLogAt: Date?
    private var warmupUntil: Date?
    /// After a large input gap, reset the buffer and suppress classification briefly to avoid
    /// running inference on stale/underfilled windows.
    private var suspendInferenceUntil: Date?

    public var onClassificationResult: ((TemporalisState) -> Void)?

    /// Full class probabilities (softmax), emitted whenever Core ML returns a vector.
    public var onTemporalisProbabilities: ((TemporalisProbabilities) -> Void)?

    public init(
        classifier: any TemporalisClassifier = CoreMLTemporalisClassifier(),
        clinicalLog: ClinicalLogManager? = ClinicalLogManager(),
        activityGateShiftPercentThreshold: Double = 10.0
    ) {
        self.buffer = ClassificationBuffer()
        self.classifier = classifier
        self.clinicalLog = clinicalLog
        self.activityGateShiftPercentThreshold = activityGateShiftPercentThreshold
        self.classificationQueue = DispatchQueue(label: "com.oralable.temporalis.inference", qos: .utility)
    }

    public func addSample(
        greenAC: Double,
        irDC: Double,
        redAC: Double,
        accelX: Double,
        accelY: Double,
        accelZ: Double
    ) {
        let now = Date()
        if warmupUntil == nil {
            warmupUntil = now.addingTimeInterval(warmupSuppressWarningsSeconds)
        }
        if let previous = lastSampleArrival {
            let dt = now.timeIntervalSince(previous)
            if dt > inputGapWarningThresholdSeconds,
               (warmupUntil == nil || now >= warmupUntil!),
               lastInputGapWarningAt == nil || now.timeIntervalSince(lastInputGapWarningAt!) > inputGapWarningCooldownSeconds {
                Logger.shared.warning("[MAM_FEATURES] Input gap warning: \(String(format: "%.3f", dt))s between samples; 50Hz window may be underfilled")
                lastInputGapWarningAt = now
            }
            if dt > inputGapWarningThresholdSeconds {
                // Hard reset to ensure the next inference window is fully fresh.
                buffer.reset()
                samplesSinceLastClassification = 0
                suspendInferenceUntil = now.addingTimeInterval(2.0)
            }
        }
        lastSampleArrival = now

        buffer.append(
            greenAC: greenAC,
            irDC: irDC,
            redAC: redAC,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ
        )
        samplesSinceLastClassification += 1

        if buffer.isFull && samplesSinceLastClassification >= ClassificationBuffer.strideSize {
            samplesSinceLastClassification = 0
            if let input = buffer.convertToMultiArray() {
                let snapshot = buffer.featureSnapshot(latestSpO2Estimate: latestSpO2Estimate)
                runClassificationAsync(input: input, featureSnapshot: snapshot)
            }
        }
    }

    public func updateSpO2Estimate(_ spo2: Double?) {
        if let spo2, spo2.isFinite, !spo2.isNaN, spo2 > 0 {
            latestSpO2Estimate = spo2
        } else {
            latestSpO2Estimate = 98.0
        }
    }

    private func runClassificationAsync(input: MLMultiArray, featureSnapshot: MAMFeatureSnapshot?) {
        classificationQueue.async { [weak self] in
            guard let self = self else { return }
            Task {
                if let until = self.suspendInferenceUntil, Date() < until {
                    self.onClassificationResult?(.quiet)
                    return
                }

                let shouldLogDiagnostics = self.shouldEmitDiagnosticLog()
                if let featureSnapshot {
                    self.logFeatureSnapshot(featureSnapshot, emitDebugLog: shouldLogDiagnostics)
                    let shiftAbs = abs(featureSnapshot.irDCShiftPercent)
                    if shiftAbs < self.activityGateShiftPercentThreshold {
                        if shouldLogDiagnostics {
                            Logger.shared.debug(
                                "[MAM_INPUT_AUDIT] Gate closed: |shift| \(String(format: "%.3f", shiftAbs))% < \(String(format: "%.1f", self.activityGateShiftPercentThreshold))% threshold (raw \(String(format: "%.3f", featureSnapshot.irDCShiftPercent))%)"
                            )
                        }
                        self.onClassificationResult?(.quiet)
                        return
                    }
                    if shouldLogDiagnostics {
                        Logger.shared.debug(
                            "[MAM_INPUT_AUDIT] Gate open: |shift| \(String(format: "%.3f", shiftAbs))% >= \(String(format: "%.1f", self.activityGateShiftPercentThreshold))% threshold (raw \(String(format: "%.3f", featureSnapshot.irDCShiftPercent))%)"
                        )
                    }
                }
                let probs = await self.classifier.probabilities(input: input)
                if let probs = probs {
                    self.onTemporalisProbabilities?(probs)
                    self.onClassificationResult?(probs.dominantState)
                    self.clinicalLog?.append(timestamp: Date(), probabilities: probs)
                    if shouldLogDiagnostics {
                        Logger.shared.debug(
                            "[Temporalis] quiet=\(String(format: "%.3f", probs.quiet)) phasic=\(String(format: "%.3f", probs.phasic)) tonic=\(String(format: "%.3f", probs.tonic)) rescue=\(String(format: "%.3f", probs.rescue))"
                        )
                    }
                } else {
                    let state = await self.classifier.classify(input: input)
                    self.onClassificationResult?(state)
                }
            }
        }
    }

    private func logFeatureSnapshot(_ snapshot: MAMFeatureSnapshot, emitDebugLog: Bool) {
        if emitDebugLog {
            Logger.shared.debug(
                "[MAM_FEATURES] SpO2: \(String(format: "%.1f", snapshot.spo2Estimate)), IR_DC: \(String(format: "%.3f", snapshot.irDCBaseline)), Shift%: \(String(format: "%.3f", snapshot.irDCShiftPercent)), Motion: \(String(format: "%.6f", snapshot.motionVariance)), IR_DC_RAW_RANGE: [\(String(format: "%.3f", snapshot.irDCRawMin)), \(String(format: "%.3f", snapshot.irDCRawMax))], IR_DC_NORM_RANGE: [\(String(format: "%.3f", snapshot.irDCNormMin)), \(String(format: "%.3f", snapshot.irDCNormMax))]"
            )
        }

        let now = Date()
        let shouldEmitWarnings = warmupUntil == nil || now >= warmupUntil!

        if shouldEmitWarnings, snapshot.spo2Estimate < 90 {
            Logger.shared.warning("[MAM_FEATURES] OOD warning: SpO2 estimate < 90 (\(String(format: "%.1f", snapshot.spo2Estimate)))")
        }
        let irNormAbsMax = max(abs(snapshot.irDCNormMin), abs(snapshot.irDCNormMax))
        if shouldEmitWarnings, irNormAbsMax > 4.8 {
            Logger.shared.warning("[MAM_FEATURES] OOD warning: IR-DC normalized values are near clamp limits (abs max \(String(format: "%.3f", irNormAbsMax)))")
        }
    }

    private func shouldEmitDiagnosticLog() -> Bool {
        let now = Date()
        guard let lastLogAt = lastDiagnosticLogAt else {
            lastDiagnosticLogAt = now
            return true
        }
        if now.timeIntervalSince(lastLogAt) >= diagnosticLogCooldownSeconds {
            lastDiagnosticLogAt = now
            return true
        }
        return false
    }

    public func reset() {
        buffer.reset()
        samplesSinceLastClassification = 0
        latestSpO2Estimate = nil
        lastSampleArrival = nil
        lastInputGapWarningAt = nil
        lastDiagnosticLogAt = nil
        warmupUntil = nil
        suspendInferenceUntil = nil
    }
}
