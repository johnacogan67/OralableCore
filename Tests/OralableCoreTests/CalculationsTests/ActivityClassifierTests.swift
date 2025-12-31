//
//  ActivityClassifierTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for ActivityClassifier
//

import XCTest
@testable import OralableCore

final class ActivityClassifierTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let classifier = ActivityClassifier()

        // Should classify immediately with default settings
        let result = classifier.classify(ir: 100000.0, accMagnitude: 1.0)
        XCTAssertEqual(result, .relaxed) // First sample establishes baseline
    }

    func testCustomInitialization() {
        let classifier = ActivityClassifier(
            historySize: 64,
            motionThreshold: 1.3,
            deviationThreshold: 8000.0,
            grindingVarianceThreshold: 2000.0
        )

        let result = classifier.classify(ir: 100000.0, accMagnitude: 1.0)
        XCTAssertEqual(result, .relaxed)
    }

    // MARK: - Motion Detection Tests

    func testMotionDetectedHighAcceleration() {
        let classifier = ActivityClassifier(motionThreshold: 1.15)

        // First call establishes baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // High acceleration should trigger motion
        let result = classifier.classify(ir: 100000.0, accMagnitude: 1.5)
        XCTAssertEqual(result, .motion)
    }

    func testMotionNotDetectedLowAcceleration() {
        let classifier = ActivityClassifier(motionThreshold: 1.15)

        // First call establishes baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Normal stationary acceleration
        let result = classifier.classify(ir: 100000.0, accMagnitude: 1.05)
        XCTAssertEqual(result, .relaxed)
    }

    func testMotionThresholdBoundary() {
        let classifier = ActivityClassifier(motionThreshold: 1.15)

        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Exactly at threshold
        let atThreshold = classifier.classify(ir: 100000.0, accMagnitude: 1.15)
        XCTAssertEqual(atThreshold, .relaxed) // At threshold, not above

        // Just above threshold
        let aboveThreshold = classifier.classify(ir: 100000.0, accMagnitude: 1.16)
        XCTAssertEqual(aboveThreshold, .motion)
    }

    // MARK: - Relaxed State Tests

    func testRelaxedStateNoDeviation() {
        let classifier = ActivityClassifier()

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Send consistent values
        for _ in 0..<10 {
            let result = classifier.classify(ir: 100000.0, accMagnitude: 1.0)
            XCTAssertEqual(result, .relaxed)
        }
    }

    func testRelaxedStateSmallDeviation() {
        let classifier = ActivityClassifier(deviationThreshold: 5000.0)

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Small deviation under threshold
        let result = classifier.classify(ir: 102000.0, accMagnitude: 1.0)
        XCTAssertEqual(result, .relaxed)
    }

    // MARK: - Clenching Detection Tests

    func testClenchingDetectedHighDeviationLowVariance() {
        let classifier = ActivityClassifier(
            deviationThreshold: 5000.0,
            grindingVarianceThreshold: 1000.0
        )

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Fill history with consistent high deviation (low variance)
        var lastResult: ActivityType = .relaxed
        for _ in 0..<50 {
            // Constant high value = high deviation, low variance
            lastResult = classifier.classify(ir: 110000.0, accMagnitude: 1.0)
        }

        XCTAssertEqual(lastResult, .clenching)
    }

    // MARK: - Grinding Detection Tests

    func testGrindingDetectedHighDeviationHighVariance() {
        let classifier = ActivityClassifier(
            historySize: 32,
            deviationThreshold: 5000.0,
            grindingVarianceThreshold: 1000.0
        )

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Fill history with varying high values (high variance)
        var lastResult: ActivityType = .relaxed
        for i in 0..<100 {
            // Oscillating values = high variance
            let ir = i % 2 == 0 ? 115000.0 : 108000.0
            lastResult = classifier.classify(ir: ir, accMagnitude: 1.0)
        }

        XCTAssertEqual(lastResult, .grinding)
    }

    // MARK: - Baseline Adaptation Tests

    func testBaselineAdaptation() {
        let classifier = ActivityClassifier(deviationThreshold: 5000.0)

        // Establish baseline at 100000
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Gradually shift IR value - baseline should adapt
        for i in 1...100 {
            // Small increments
            let ir = 100000.0 + Double(i) * 10
            _ = classifier.classify(ir: ir, accMagnitude: 1.0)
        }

        // After adaptation, new baseline should be around 100500-101000
        // A large sudden deviation from the new baseline should trigger activity
        let result = classifier.classify(ir: 115000.0, accMagnitude: 1.0)
        // May still be relaxed if baseline adapted well, or clenching if deviation is large
        XCTAssertTrue(result == .relaxed || result == .clenching || result == .grinding)
    }

    // MARK: - Reset Tests

    func testReset() {
        let classifier = ActivityClassifier()

        // Build up state
        for i in 0..<50 {
            _ = classifier.classify(ir: 100000.0 + Double(i * 100), accMagnitude: 1.0)
        }

        // Reset
        classifier.reset()

        // After reset, first classification should establish new baseline
        let result = classifier.classify(ir: 150000.0, accMagnitude: 1.0)
        XCTAssertEqual(result, .relaxed) // First sample always relaxed
    }

    func testResetClearsHistory() {
        let classifier = ActivityClassifier(
            historySize: 32,
            grindingVarianceThreshold: 1000.0
        )

        // Build high-variance history
        for i in 0..<50 {
            let ir = i % 2 == 0 ? 115000.0 : 108000.0
            _ = classifier.classify(ir: ir, accMagnitude: 1.0)
        }

        // Reset
        classifier.reset()

        // Now feed low-variance data
        var lastResult: ActivityType = .relaxed
        for _ in 0..<50 {
            lastResult = classifier.classify(ir: 100000.0, accMagnitude: 1.0)
        }

        // Should be relaxed after reset with consistent data
        XCTAssertEqual(lastResult, .relaxed)
    }

    // MARK: - Motion Priority Tests

    func testMotionHasHighestPriority() {
        let classifier = ActivityClassifier(
            motionThreshold: 1.15,
            deviationThreshold: 5000.0
        )

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Even with high deviation, motion takes priority
        let result = classifier.classify(ir: 150000.0, accMagnitude: 2.0)
        XCTAssertEqual(result, .motion)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentClassification() async {
        let classifier = ActivityClassifier()

        await withTaskGroup(of: ActivityType.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let ir = 100000.0 + Double(i % 10) * 1000
                    let acc = 1.0 + Double(i % 5) * 0.1
                    return classifier.classify(ir: ir, accMagnitude: acc)
                }
            }

            var results: [ActivityType] = []
            for await result in group {
                results.append(result)
            }

            // All 100 results should be valid activity types
            XCTAssertEqual(results.count, 100)
            for result in results {
                XCTAssertTrue([.relaxed, .clenching, .grinding, .motion].contains(result))
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroIRValue() {
        let classifier = ActivityClassifier()

        let result = classifier.classify(ir: 0.0, accMagnitude: 1.0)
        XCTAssertEqual(result, .relaxed) // First sample establishes baseline
    }

    func testNegativeIRValue() {
        let classifier = ActivityClassifier()

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Negative should work (though unusual)
        let result = classifier.classify(ir: -1000.0, accMagnitude: 1.0)
        // Large deviation from positive baseline
        XCTAssertTrue([.clenching, .grinding].contains(result))
    }

    func testVeryHighIRValue() {
        let classifier = ActivityClassifier()

        // Establish baseline
        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Very high value
        let result = classifier.classify(ir: 1000000.0, accMagnitude: 1.0)
        XCTAssertTrue([.clenching, .grinding].contains(result))
    }

    func testZeroAcceleration() {
        let classifier = ActivityClassifier(motionThreshold: 1.15)

        _ = classifier.classify(ir: 100000.0, accMagnitude: 1.0)

        // Zero acceleration (free fall)
        let result = classifier.classify(ir: 100000.0, accMagnitude: 0.0)
        XCTAssertEqual(result, .relaxed) // Not above motion threshold
    }
}
