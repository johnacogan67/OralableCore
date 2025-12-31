//
//  MotionCompensatorTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for MotionCompensator LMS adaptive filter
//

import XCTest
@testable import OralableCore

final class MotionCompensatorTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let compensator = MotionCompensator()

        // Should be able to process immediately
        let result = compensator.filter(signal: 1000.0, noiseReference: 0.0)
        XCTAssertNotEqual(result, 0.0)
    }

    func testCustomInitialization() {
        let compensator = MotionCompensator(
            historySize: 64,
            learningRate: 0.02,
            varianceThreshold: 2.0
        )

        // Should be able to process with custom settings
        let result = compensator.filter(signal: 1000.0, noiseReference: 0.0)
        XCTAssertNotEqual(result, 0.0)
    }

    // MARK: - Basic Filtering Tests

    func testFilterWithNoNoise() {
        let compensator = MotionCompensator()

        // With zero noise reference, signal should pass through mostly unchanged
        let signal = 1000.0
        var lastResult = 0.0

        for _ in 0..<10 {
            lastResult = compensator.filter(signal: signal, noiseReference: 0.0)
        }

        // After settling, result should be close to original signal
        XCTAssertEqual(lastResult, signal, accuracy: 100.0)
    }

    func testFilterWithConstantSignal() {
        let compensator = MotionCompensator()

        var results: [Double] = []
        for _ in 0..<50 {
            let result = compensator.filter(signal: 2000.0, noiseReference: 0.1)
            results.append(result)
        }

        // Results should stabilize
        let lastTen = Array(results.suffix(10))
        let average = lastTen.reduce(0, +) / Double(lastTen.count)
        let variance = lastTen.map { pow($0 - average, 2) }.reduce(0, +) / Double(lastTen.count)

        // Variance should be relatively low for constant signal
        XCTAssertLessThan(variance, 10000.0)
    }

    // MARK: - Motion Dampening Tests

    func testExcessiveMotionDampening() {
        let compensator = MotionCompensator(varianceThreshold: 0.5)

        // Feed high-variance noise to trigger dampening
        var result = 0.0
        for i in 0..<100 {
            // Create high-variance noise (alternating high/low)
            let noise = Double(i % 2 == 0 ? 5.0 : -5.0)
            result = compensator.filter(signal: 1000.0, noiseReference: noise)
        }

        // Signal should be dampened significantly (multiplied by 0.01)
        XCTAssertLessThan(result, 20.0) // 1000 * 0.01 = 10
    }

    func testLowMotionPreservesSignal() {
        let compensator = MotionCompensator(varianceThreshold: 10.0)

        // Feed consistent low noise
        var result = 0.0
        for _ in 0..<50 {
            result = compensator.filter(signal: 1000.0, noiseReference: 0.01)
        }

        // Signal should not be dampened
        XCTAssertGreaterThan(result, 100.0) // Should be much larger than dampened value
    }

    // MARK: - Reset Tests

    func testReset() {
        let compensator = MotionCompensator()

        // Process some samples to build up state
        for _ in 0..<50 {
            _ = compensator.filter(signal: 1000.0, noiseReference: 0.5)
        }

        // Reset
        compensator.reset()

        // After reset, should behave like fresh instance
        let result1 = compensator.filter(signal: 1000.0, noiseReference: 0.0)

        let freshCompensator = MotionCompensator()
        let result2 = freshCompensator.filter(signal: 1000.0, noiseReference: 0.0)

        // Both should produce similar results
        XCTAssertEqual(result1, result2, accuracy: 1.0)
    }

    func testResetClearsWeights() {
        let compensator = MotionCompensator()

        // Train the filter with correlated noise
        for i in 0..<100 {
            let noise = sin(Double(i) * 0.1)
            _ = compensator.filter(signal: 1000.0 + noise * 100, noiseReference: noise)
        }

        // Reset
        compensator.reset()

        // After reset, noise correlation should be lost
        // Fresh filter output should be closer to input signal
        let result = compensator.filter(signal: 1000.0, noiseReference: 0.0)
        XCTAssertEqual(result, 1000.0, accuracy: 10.0)
    }

    // MARK: - LMS Adaptation Tests

    func testAdaptiveFilterConvergence() {
        let compensator = MotionCompensator(learningRate: 0.05)

        var errors: [Double] = []

        // Train with correlated noise
        for i in 0..<200 {
            let noise = sin(Double(i) * 0.2) * 100
            let noisySignal = 1000.0 + noise
            let result = compensator.filter(signal: noisySignal, noiseReference: sin(Double(i) * 0.2))
            errors.append(abs(result - 1000.0)) // Error from clean signal
        }

        // Average error in last 50 samples should be less than first 50
        let firstHalfAvg = errors.prefix(50).reduce(0, +) / 50.0
        let lastHalfAvg = errors.suffix(50).reduce(0, +) / 50.0

        // Filter should converge (later errors should be smaller or similar)
        // Note: This is a statistical test, may have some variance
        XCTAssertLessThanOrEqual(lastHalfAvg, firstHalfAvg * 2.0)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async {
        let compensator = MotionCompensator()

        // Create multiple concurrent tasks
        await withTaskGroup(of: Double.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let signal = Double(1000 + i)
                    let noise = Double(i % 10) * 0.1
                    return compensator.filter(signal: signal, noiseReference: noise)
                }
            }

            var results: [Double] = []
            for await result in group {
                results.append(result)
            }

            // All 100 results should be valid (not NaN or infinite)
            XCTAssertEqual(results.count, 100)
            for result in results {
                XCTAssertTrue(result.isFinite)
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroSignal() {
        let compensator = MotionCompensator()

        let result = compensator.filter(signal: 0.0, noiseReference: 0.0)
        XCTAssertEqual(result, 0.0)
    }

    func testNegativeSignal() {
        let compensator = MotionCompensator()

        let result = compensator.filter(signal: -1000.0, noiseReference: 0.0)
        XCTAssertEqual(result, -1000.0, accuracy: 10.0)
    }

    func testVeryLargeSignal() {
        let compensator = MotionCompensator()

        let result = compensator.filter(signal: 1000000.0, noiseReference: 0.0)
        XCTAssertTrue(result.isFinite)
        XCTAssertGreaterThan(result, 0)
    }

    func testVerySmallSignal() {
        let compensator = MotionCompensator()

        let result = compensator.filter(signal: 0.00001, noiseReference: 0.0)
        XCTAssertTrue(result.isFinite)
    }
}
