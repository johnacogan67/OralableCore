//
//  MAMInferenceManager.swift
//  OralableCore
//
//  Created: March 2026
//  Purpose: CoreML inference pipeline for MAM Net research model.
//  Implements sliding window logic and tensor-formatting bridge for bruxism classification.
//
//  Input: PPG-Red (AC), PPG-IR (DC), Accelerometer (Magnitude) @ 50 Hz
//  Window: 250 samples (5 seconds)
//  Stride: 50 samples (1 second) — classifier invoked every 50 new samples
//

import Foundation
import CoreML

// MARK: - Bruxism State

/// Sleep bruxism classification states from MAM Net
public enum BruxismState: String, Sendable, CaseIterable {
    case quiet   // No clenching/grinding
    case phasic  // Rhythmic grinding
    case tonic   // Sustained clenching
    case rescue  // Rescue/artifact
}

// MARK: - Bruxism Probabilities

/// Raw probability scores for each bruxism state (sum to ~1.0)
public struct BruxismProbabilities: Sendable {
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

    /// Most likely state
    public var dominantState: BruxismState {
        let maxVal = max(quiet, phasic, tonic, rescue)
        if quiet == maxVal { return .quiet }
        if phasic == maxVal { return .phasic }
        if tonic == maxVal { return .tonic }
        return .rescue
    }
}

// MARK: - Bruxism Classifier Protocol

/// Protocol for bruxism classification models (MAM Net, mock, or future CoreML)
public protocol BruxismClassifier: Sendable {
    /// Classify bruxism state from preformatted tensor
    /// - Parameter input: MLMultiArray of shape [1, 250, 3] (batch, time, channels)
    /// - Returns: Classified BruxismState
    func classify(input: MLMultiArray) async -> BruxismState

    /// Return raw probabilities for each state (Quiet, Phasic, Tonic, Rescue)
    /// - Parameter input: MLMultiArray of shape [1, 250, 3]
    /// - Returns: BruxismProbabilities summing to ~1.0
    func probabilities(input: MLMultiArray) async -> BruxismProbabilities?
}

// MARK: - Mock MAM Classifier

/// Stub classifier for development and testing. Returns random BruxismState.
public final class MockMAMClassifier: BruxismClassifier, @unchecked Sendable {
    public init() {}

    public func classify(input: MLMultiArray) async -> BruxismState {
        await Task.detached(priority: .utility) {
            BruxismState.allCases.randomElement() ?? .quiet
        }.value
    }

    public func probabilities(input: MLMultiArray) async -> BruxismProbabilities? {
        let q = Double.random(in: 0.2...0.3)
        let p = Double.random(in: 0.2...0.3)
        let t = Double.random(in: 0.2...0.3)
        let r = 1.0 - q - p - t
        return BruxismProbabilities(quiet: q, phasic: p, tonic: t, rescue: max(0, r))
    }
}

// MARK: - CoreML MAM Classifier

/// CoreML-backed BruxismMAM model. Returns probabilities for Quiet, Phasic, Tonic, Rescue.
public final class CoreMLMAMClassifier: BruxismClassifier, @unchecked Sendable {
    private let model: MLModel?

    public init() {
        do {
            guard let url = Bundle.module.url(forResource: "BruxismMAM", withExtension: "mlpackage") else {
                Logger.shared.warning("[MAM] BruxismMAM.mlpackage not found in bundle")
                self.model = nil
                return
            }
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            self.model = try MLModel(contentsOf: url, configuration: config)
        } catch {
            Logger.shared.warning("[MAM] Failed to load BruxismMAM model: \(error); using mock")
            self.model = nil
        }
    }

    public func classify(input: MLMultiArray) async -> BruxismState {
        if let probs = await probabilities(input: input) {
            return probs.dominantState
        }
        return .quiet
    }

    public func probabilities(input: MLMultiArray) async -> BruxismProbabilities? {
        guard let model = model else { return nil }
        return await Task.detached(priority: .userInitiated) {
            do {
                let inputProvider = try MLDictionaryFeatureProvider(dictionary: ["input": MLFeatureValue(multiArray: input)])
                let output = try model.prediction(from: inputProvider)
                guard let probArray = output.featureValue(for: "probabilities")?.multiArrayValue else {
                    return nil
                }
                // Shape (1, 4) — [quiet, phasic, tonic, rescue]
                let quiet = probArray[[0, 0] as [NSNumber]].doubleValue
                let phasic = probArray[[0, 1] as [NSNumber]].doubleValue
                let tonic = probArray[[0, 2] as [NSNumber]].doubleValue
                let rescue = probArray[[0, 3] as [NSNumber]].doubleValue
                return BruxismProbabilities(quiet: quiet, phasic: phasic, tonic: tonic, rescue: rescue)
            } catch {
                Logger.shared.warning("[MAM] CoreML prediction failed: \(error)")
                return nil
            }
        }.value
    }
}

// MARK: - Clinical Log Manager

/// Appends raw MAM probabilities to mam_clinical_audit.csv in the app Documents directory.
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

    /// Append one row: timestamp, quiet, phasic, tonic, rescue
    public func append(timestamp: Date, probabilities: BruxismProbabilities) {
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

/// Maintains the last 250 samples (5 seconds @ 50 Hz) for three channels:
/// - PPG-Red (AC): Bandpass-filtered red for heart rate component
/// - PPG-IR (DC): Low-pass IR for muscle occlusion / DC shift
/// - Accelerometer (Magnitude): sqrt(x²+y²+z²) in g
public struct ClassificationBuffer: Sendable {
    private var ppgRedAC: [Double]
    private var ppgIRDC: [Double]
    private var accelMagnitude: [Double]

    public static let windowSize: Int = 250
    public static let strideSize: Int = 50

    public init() {
        self.ppgRedAC = []
        self.ppgIRDC = []
        self.accelMagnitude = []
    }

    /// Append one sample for each channel
    public mutating func append(ppgRedAC: Double, ppgIRDC: Double, accelMagnitude: Double) {
        self.ppgRedAC.append(ppgRedAC)
        self.ppgIRDC.append(ppgIRDC)
        self.accelMagnitude.append(accelMagnitude)

        // Trim to window size (keep last 250)
        if self.ppgRedAC.count > Self.windowSize {
            self.ppgRedAC.removeFirst(self.ppgRedAC.count - Self.windowSize)
        }
        if self.ppgIRDC.count > Self.windowSize {
            self.ppgIRDC.removeFirst(self.ppgIRDC.count - Self.windowSize)
        }
        if self.accelMagnitude.count > Self.windowSize {
            self.accelMagnitude.removeFirst(self.accelMagnitude.count - Self.windowSize)
        }
    }

    /// Number of samples (min of three channels)
    public var count: Int {
        min(ppgRedAC.count, ppgIRDC.count, accelMagnitude.count)
    }

    /// Whether buffer has full window for inference
    public var isFull: Bool {
        count >= Self.windowSize
    }

    /// Convert buffer to MLMultiArray of shape [1, 250, 3], Float32
    /// Layout: [batch, time, channel] — channel 0: PPG-Red AC, 1: PPG-IR DC, 2: Accel Magnitude
    public func convertToMultiArray() -> MLMultiArray? {
        guard count >= Self.windowSize else { return nil }

        let shape = [1, Self.windowSize, 3] as [NSNumber]
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            return nil
        }

        let redSlice = ppgRedAC.suffix(Self.windowSize)
        let irSlice = ppgIRDC.suffix(Self.windowSize)
        let accelSlice = accelMagnitude.suffix(Self.windowSize)

        for t in 0..<Self.windowSize {
            let redVal = Float(redSlice[redSlice.startIndex + t])
            let irVal = Float(irSlice[irSlice.startIndex + t])
            let accVal = Float(accelSlice[accelSlice.startIndex + t])

            array[[0, t, 0] as [NSNumber]] = NSNumber(value: redVal)
            array[[0, t, 1] as [NSNumber]] = NSNumber(value: irVal)
            array[[0, t, 2] as [NSNumber]] = NSNumber(value: accVal)
        }

        return array
    }

    /// Reset buffer (e.g. on session start)
    public mutating func reset() {
        ppgRedAC.removeAll()
        ppgIRDC.removeAll()
        accelMagnitude.removeAll()
    }
}

// MARK: - MAM Inference Manager

/// Raw accelerometer scale: 16384 LSB/g (LIS2DTW12 ±2g typical)
private let kAccelScale: Double = 16384.0

/// Manages the sliding window buffer and triggers classification every 50 new samples.
/// Classification runs off the main thread to avoid blocking biometric ingestion.
public final class MAMInferenceManager: @unchecked Sendable {
    private var buffer: ClassificationBuffer
    private let classifier: any BruxismClassifier
    private let clinicalLog: ClinicalLogManager?
    private let classificationQueue: DispatchQueue
    private var samplesSinceLastClassification: Int = 0

    /// Callback invoked when classification completes (called on classification queue)
    public var onClassificationResult: ((BruxismState) -> Void)?

    public init(
        classifier: any BruxismClassifier = CoreMLMAMClassifier(),
        clinicalLog: ClinicalLogManager? = ClinicalLogManager()
    ) {
        self.buffer = ClassificationBuffer()
        self.classifier = classifier
        self.clinicalLog = clinicalLog
        self.classificationQueue = DispatchQueue(label: "com.oralable.mam.inference", qos: .utility)
    }

    /// Add one sample. Computes accelerometer magnitude as √(x²+y²+z²) in g.
    /// - Parameters:
    ///   - ppgRedAC: Bandpass-filtered PPG red (AC component)
    ///   - ppgIRDC: Low-pass PPG IR (DC component for occlusion)
    ///   - accelX: Accelerometer X in g (or raw / 16384)
    ///   - accelY: Accelerometer Y in g
    ///   - accelZ: Accelerometer Z in g
    public func addSample(
        ppgRedAC: Double,
        ppgIRDC: Double,
        accelX: Double,
        accelY: Double,
        accelZ: Double
    ) {
        // 3rd channel: Accelerometer Magnitude √(x²+y²+z²)
        let accelMagnitude = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
        buffer.append(ppgRedAC: ppgRedAC, ppgIRDC: ppgIRDC, accelMagnitude: accelMagnitude)
        samplesSinceLastClassification += 1

        // Trigger classification every 50 new samples (1-second stride) once buffer is full
        if buffer.isFull && samplesSinceLastClassification >= ClassificationBuffer.strideSize {
            samplesSinceLastClassification = 0
            if let input = buffer.convertToMultiArray() {
                runClassificationAsync(input: input)
            }
        }
    }

    /// Feed one sample (legacy). Use addSample when raw accel x,y,z are available.
    /// - Parameters:
    ///   - ppgRedAC: Bandpass-filtered PPG red (AC component)
    ///   - ppgIRDC: Low-pass PPG IR (DC component for occlusion)
    ///   - accelMagnitude: Accelerometer magnitude in g (pre-computed)
    public func feed(ppgRedAC: Double, ppgIRDC: Double, accelMagnitude: Double) {
        buffer.append(ppgRedAC: ppgRedAC, ppgIRDC: ppgIRDC, accelMagnitude: accelMagnitude)
        samplesSinceLastClassification += 1

        if buffer.isFull && samplesSinceLastClassification >= ClassificationBuffer.strideSize {
            samplesSinceLastClassification = 0
            if let input = buffer.convertToMultiArray() {
                runClassificationAsync(input: input)
            }
        }
    }

    /// Run classification on background queue; does not block caller
    private func runClassificationAsync(input: MLMultiArray) {
        classificationQueue.async { [weak self] in
            guard let self = self else { return }
            Task {
                let probs = await self.classifier.probabilities(input: input)
                if let probs = probs {
                    self.onClassificationResult?(probs.dominantState)
                    self.clinicalLog?.append(timestamp: Date(), probabilities: probs)
                    Logger.shared.debug("[MAM Inference] quiet=\(String(format: "%.3f", probs.quiet)) phasic=\(String(format: "%.3f", probs.phasic)) tonic=\(String(format: "%.3f", probs.tonic)) rescue=\(String(format: "%.3f", probs.rescue))")
                } else {
                    let state = await self.classifier.classify(input: input)
                    self.onClassificationResult?(state)
                }
            }
        }
    }

    /// Reset buffer and stride counter (e.g. on session start)
    public func reset() {
        buffer.reset()
        samplesSinceLastClassification = 0
    }
}
