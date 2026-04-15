//
//  InferenceManagerTests.swift
//  OralableCoreTests
//
//  Temporalis buffer: 50×6 tensor, stride 50 (one inference per second @ 50 Hz).
//

import XCTest
import CoreML
@testable import OralableCore

private final class CountingTemporalisClassifier: TemporalisClassifier, @unchecked Sendable {
    nonisolated(unsafe) private var _invocationCount: Int = 0

    var invocationCount: Int { _invocationCount }

    func classify(input: MLMultiArray) async -> TemporalisState {
        _invocationCount += 1
        return .quiet
    }

    func probabilities(input: MLMultiArray) async -> TemporalisProbabilities? {
        nil
    }
}

final class InferenceManagerTests: XCTestCase {

    func testBufferLogic_classifierEveryFiftySamplesAfterWindow() async {
        let classifier = CountingTemporalisClassifier()
        let manager = MAMInferenceManager(classifier: classifier, activityGateShiftPercentThreshold: 0.0)

        for i in 1...300 {
            manager.addSample(
                greenAC: Double(i),
                irDC: Double(i * 2),
                redAC: Double(i) * 0.5,
                accelX: Double(i) / 100.0,
                accelY: 0,
                accelZ: 1.0
            )
        }

        // Allow async dispatch + Task scheduling to complete on CI / loaded machines.
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(classifier.invocationCount, 6, "Expected 6 inferences for 300 samples (50 Hz stride, 50-sample window)")
    }

    func testNoClassificationBeforeFiftySamples() async {
        let classifier = CountingTemporalisClassifier()
        let manager = MAMInferenceManager(classifier: classifier, activityGateShiftPercentThreshold: 0.0)

        for i in 1...49 {
            manager.addSample(
                greenAC: Double(i),
                irDC: Double(i),
                redAC: 0,
                accelX: 0,
                accelY: 0,
                accelZ: 1.0
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(classifier.invocationCount, 0)
    }

    func testTensorShape() {
        var buffer = ClassificationBuffer()
        for i in 1...50 {
            buffer.append(
                greenAC: Double(i),
                irDC: Double(i * 2),
                redAC: Double(i) * 0.5,
                accelX: 0.1,
                accelY: 0.2,
                accelZ: 0.9
            )
        }

        guard let array = buffer.convertToMultiArray() else {
            XCTFail("convertToMultiArray should return non-nil when buffer has 50 samples")
            return
        }

        XCTAssertEqual(array.shape.count, 3)
        XCTAssertEqual(array.shape[0].intValue, 1)
        XCTAssertEqual(array.shape[1].intValue, 50)
        XCTAssertEqual(array.shape[2].intValue, 6)
    }

    func testTensorDataType() {
        var buffer = ClassificationBuffer()
        for i in 1...50 {
            buffer.append(greenAC: Double(i), irDC: 1, redAC: 1, accelX: 0, accelY: 0, accelZ: 1)
        }

        guard let array = buffer.convertToMultiArray() else {
            XCTFail("convertToMultiArray should return non-nil")
            return
        }

        XCTAssertEqual(array.dataType, .float32)
    }

    func testResetClearsBuffer() {
        let manager = MAMInferenceManager()
        for i in 1...30 {
            manager.addSample(greenAC: Double(i), irDC: 1, redAC: 1, accelX: 0, accelY: 0, accelZ: 1)
        }
        manager.reset()
        for i in 1...50 {
            manager.addSample(greenAC: Double(i), irDC: 1, redAC: 1, accelX: 0, accelY: 0, accelZ: 1)
        }
    }
}
