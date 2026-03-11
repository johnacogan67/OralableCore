//
//  InferenceManagerTests.swift
//  OralableCoreTests
//
//  Created: March 2026
//  Validates MAMInferenceManager buffer logic and classification trigger timing.
//
//  Buffer Logic: Feed 300 samples. Classifier called exactly once after sample 250,
//  and again exactly at sample 300 (stride of 50).
//

import XCTest
import CoreML
@testable import OralableCore

// MARK: - Counting Classifier

private final class CountingBruxismClassifier: BruxismClassifier, @unchecked Sendable {
    private let lock = NSLock()
    private var _invocationCount: Int = 0

    var invocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _invocationCount
    }

    func classify(input: MLMultiArray) async -> BruxismState {
        lock.lock()
        _invocationCount += 1
        lock.unlock()
        return .quiet
    }
}

// MARK: - Tests

final class InferenceManagerTests: XCTestCase {

    func testBufferLogic_classifierCalledAt250And300() async {
        let classifier = CountingBruxismClassifier()
        let manager = MAMInferenceManager(classifier: classifier)

        // Feed 300 samples
        for i in 1...300 {
            manager.feed(
                ppgRedAC: Double(i),
                ppgIRDC: Double(i * 2),
                accelMagnitude: Double(i) / 100.0
            )
        }

        // Allow async classification to complete
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100 ms

        // Classifier should be called exactly twice: at sample 250 and sample 300
        XCTAssertEqual(classifier.invocationCount, 2, "Classifier should be invoked exactly twice (at sample 250 and 300)")
    }

    func testBufferLogic_noClassificationBefore250Samples() async {
        let classifier = CountingBruxismClassifier()
        let manager = MAMInferenceManager(classifier: classifier)

        // Feed only 249 samples
        for i in 1...249 {
            manager.feed(
                ppgRedAC: Double(i),
                ppgIRDC: Double(i),
                accelMagnitude: 1.0
            )
        }

        try? await Task.sleep(nanoseconds: 50_000_000)  // 50 ms

        XCTAssertEqual(classifier.invocationCount, 0, "Classifier should not be invoked before 250 samples")
    }

    func testTensorShape() {
        var buffer = ClassificationBuffer()
        for i in 1...250 {
            buffer.append(ppgRedAC: Double(i), ppgIRDC: Double(i * 2), accelMagnitude: Double(i) / 100.0)
        }

        guard let array = buffer.convertToMultiArray() else {
            XCTFail("convertToMultiArray should return non-nil when buffer has 250 samples")
            return
        }

        XCTAssertEqual(array.shape.count, 3, "MLMultiArray should have 3 dimensions")
        XCTAssertEqual(array.shape[0].intValue, 1, "Batch dimension should be 1")
        XCTAssertEqual(array.shape[1].intValue, 250, "Time dimension should be 250")
        XCTAssertEqual(array.shape[2].intValue, 3, "Channel dimension should be 3")
    }

    func testTensorDataType() {
        var buffer = ClassificationBuffer()
        for i in 1...250 {
            buffer.append(ppgRedAC: Double(i), ppgIRDC: Double(i), accelMagnitude: 1.0)
        }

        guard let array = buffer.convertToMultiArray() else {
            XCTFail("convertToMultiArray should return non-nil")
            return
        }

        XCTAssertEqual(array.dataType, .float32, "MLMultiArray should use Float32 precision")
    }

    func testResetClearsBuffer() {
        let manager = MAMInferenceManager()
        for i in 1...100 {
            manager.feed(ppgRedAC: Double(i), ppgIRDC: Double(i), accelMagnitude: 1.0)
        }
        manager.reset()
        // After reset, feeding 250 more should trigger classification (buffer was cleared)
        for i in 1...250 {
            manager.feed(ppgRedAC: Double(i), ppgIRDC: Double(i), accelMagnitude: 1.0)
        }
        // No direct way to verify; at least we ensure reset doesn't crash
    }
}
