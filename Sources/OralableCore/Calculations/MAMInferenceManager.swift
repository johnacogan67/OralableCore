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

// MARK: - Bruxism Classifier Protocol

/// Protocol for bruxism classification models (MAM Net, mock, or future CoreML)
public protocol BruxismClassifier: Sendable {
    /// Classify bruxism state from preformatted tensor
    /// - Parameter input: MLMultiArray of shape [1, 250, 3] (batch, time, channels)
    /// - Returns: Classified BruxismState
    func classify(input: MLMultiArray) async -> BruxismState
}

// MARK: - Mock MAM Classifier

/// Stub classifier for development and testing. Returns random BruxismState.
public final class MockMAMClassifier: BruxismClassifier, @unchecked Sendable {
    public init() {}

    public func classify(input: MLMultiArray) async -> BruxismState {
        // Run on background to avoid blocking; simulate inference delay
        await Task.detached(priority: .utility) {
            BruxismState.allCases.randomElement() ?? .quiet
        }.value
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

/// Manages the sliding window buffer and triggers classification every 50 new samples.
/// Classification runs off the main thread to avoid blocking biometric ingestion.
public final class MAMInferenceManager: @unchecked Sendable {
    private var buffer: ClassificationBuffer
    private let classifier: any BruxismClassifier
    private let classificationQueue: DispatchQueue
    private var samplesSinceLastClassification: Int = 0

    /// Callback invoked when classification completes (called on classification queue)
    public var onClassificationResult: ((BruxismState) -> Void)?

    public init(classifier: any BruxismClassifier = MockMAMClassifier()) {
        self.buffer = ClassificationBuffer()
        self.classifier = classifier
        self.classificationQueue = DispatchQueue(label: "com.oralable.mam.inference", qos: .utility)
    }

    /// Feed one sample. Triggers classification every 50 samples when buffer is full.
    /// - Parameters:
    ///   - ppgRedAC: Bandpass-filtered PPG red (AC component)
    ///   - ppgIRDC: Low-pass PPG IR (DC component for occlusion)
    ///   - accelMagnitude: Accelerometer magnitude in g
    public func feed(ppgRedAC: Double, ppgIRDC: Double, accelMagnitude: Double) {
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

    /// Run classification on background queue; does not block caller
    private func runClassificationAsync(input: MLMultiArray) {
        classificationQueue.async { [weak self] in
            guard let self = self else { return }
            Task {
                let result = await self.classifier.classify(input: input)
                self.onClassificationResult?(result)
            }
        }
    }

    /// Reset buffer and stride counter (e.g. on session start)
    public func reset() {
        buffer.reset()
        samplesSinceLastClassification = 0
    }
}
