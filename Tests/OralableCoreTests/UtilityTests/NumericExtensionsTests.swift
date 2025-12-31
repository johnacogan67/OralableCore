//
//  NumericExtensionsTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for Double+Extensions and related numeric utilities
//

import XCTest
@testable import OralableCore

// MARK: - Double Formatting Tests

final class DoubleFormattingTests: XCTestCase {

    func testFormattedDecimals() {
        XCTAssertEqual(3.14159.formatted(decimals: 0), "3")
        XCTAssertEqual(3.14159.formatted(decimals: 1), "3.1")
        XCTAssertEqual(3.14159.formatted(decimals: 2), "3.14")
        XCTAssertEqual(3.14159.formatted(decimals: 3), "3.142")
        XCTAssertEqual(3.14159.formatted(decimals: 4), "3.1416")
    }

    func testAsInteger() {
        XCTAssertEqual(72.4.asInteger, "72")
        XCTAssertEqual(72.6.asInteger, "73")
        XCTAssertEqual(72.9.asInteger, "73")
        XCTAssertEqual(0.0.asInteger, "0")
    }

    func testOneDecimal() {
        XCTAssertEqual(36.85.oneDecimal, "36.9")
        XCTAssertEqual(36.84.oneDecimal, "36.8")
        XCTAssertEqual(0.0.oneDecimal, "0.0")
    }

    func testTwoDecimals() {
        XCTAssertEqual(3.14159.twoDecimals, "3.14")
        XCTAssertEqual(98.5.twoDecimals, "98.50")
    }

    func testThreeDecimals() {
        XCTAssertEqual(0.123456.threeDecimals, "0.123")
        XCTAssertEqual(1.0.threeDecimals, "1.000")
    }
}

// MARK: - Sensor Value Formatting Tests

final class SensorValueFormattingTests: XCTestCase {

    func testAsHeartRate() {
        XCTAssertEqual(72.0.asHeartRate, "72 bpm")
        XCTAssertEqual(72.4.asHeartRate, "72 bpm")
        XCTAssertEqual(72.6.asHeartRate, "73 bpm")
    }

    func testAsSpO2() {
        XCTAssertEqual(98.0.asSpO2, "98%")
        XCTAssertEqual(98.4.asSpO2, "98%")
        XCTAssertEqual(98.6.asSpO2, "99%")
    }

    func testAsTemperature() {
        XCTAssertEqual(36.5.asTemperature, "36.5°C")
        XCTAssertEqual(37.85.asTemperature, "37.9°C")
    }

    func testAsTemperatureFahrenheit() {
        XCTAssertEqual(0.0.asTemperatureFahrenheit, "32.0°F")
        XCTAssertEqual(100.0.asTemperatureFahrenheit, "212.0°F")
        XCTAssertEqual(37.0.asTemperatureFahrenheit, "98.6°F")
    }

    func testAsAcceleration() {
        XCTAssertEqual(1.0.asAcceleration, "1.00 g")
        XCTAssertEqual(0.123.asAcceleration, "0.12 g")
        XCTAssertEqual((-0.5).asAcceleration, "-0.50 g")
    }

    func testAsBatteryPercentage() {
        XCTAssertEqual(85.0.asBatteryPercentage, "85%")
        XCTAssertEqual(100.0.asBatteryPercentage, "100%")
        XCTAssertEqual(0.0.asBatteryPercentage, "0%")
        XCTAssertEqual(105.0.asBatteryPercentage, "100%") // Clamped
        XCTAssertEqual((-5.0).asBatteryPercentage, "0%") // Clamped
    }

    func testAsSignalStrength() {
        XCTAssertEqual((-65.0).asSignalStrength, "-65 dBm")
        XCTAssertEqual((-85.4).asSignalStrength, "-85 dBm")
    }

    func testAsMillivolts() {
        XCTAssertEqual(3800.0.asMillivolts, "3800.0 mV")
        XCTAssertEqual(3.7.asMillivolts, "3.7 mV")
    }

    func testAsHz() {
        XCTAssertEqual(50.0.asHz, "50 Hz")
        XCTAssertEqual(100.4.asHz, "100 Hz")
    }
}

// MARK: - Rounding Tests

final class DoubleRoundingTests: XCTestCase {

    func testRoundedToPlaces() {
        XCTAssertEqual(3.14159.rounded(toPlaces: 0), 3.0)
        XCTAssertEqual(3.14159.rounded(toPlaces: 1), 3.1)
        XCTAssertEqual(3.14159.rounded(toPlaces: 2), 3.14)
        XCTAssertEqual(3.14159.rounded(toPlaces: 3), 3.142)
        XCTAssertEqual(3.14159.rounded(toPlaces: 4), 3.1416)
    }

    func testRoundedInt() {
        XCTAssertEqual(72.4.roundedInt, 72)
        XCTAssertEqual(72.5.roundedInt, 73)
        XCTAssertEqual(72.9.roundedInt, 73)
        XCTAssertEqual((-1.5).roundedInt, -2)
    }
}

// MARK: - Clamping Tests

final class DoubleClampingTests: XCTestCase {

    func testClampedToRange() {
        XCTAssertEqual(50.0.clamped(to: 0...100), 50.0)
        XCTAssertEqual((-10.0).clamped(to: 0...100), 0.0)
        XCTAssertEqual(150.0.clamped(to: 0...100), 100.0)
        XCTAssertEqual(0.0.clamped(to: 0...100), 0.0)
        XCTAssertEqual(100.0.clamped(to: 0...100), 100.0)
    }

    func testClampedHeartRate() {
        XCTAssertEqual(72.0.clampedHeartRate, 72.0)
        XCTAssertEqual(25.0.clampedHeartRate, 30.0)
        XCTAssertEqual(300.0.clampedHeartRate, 250.0)
    }

    func testClampedSpO2() {
        XCTAssertEqual(98.0.clampedSpO2, 98.0)
        XCTAssertEqual(40.0.clampedSpO2, 50.0)
        XCTAssertEqual(105.0.clampedSpO2, 100.0)
    }

    func testClampedTemperature() {
        XCTAssertEqual(36.5.clampedTemperature, 36.5)
        XCTAssertEqual(10.0.clampedTemperature, 20.0)
        XCTAssertEqual(50.0.clampedTemperature, 45.0)
    }

    func testClampedBattery() {
        XCTAssertEqual(85.0.clampedBattery, 85.0)
        XCTAssertEqual((-10.0).clampedBattery, 0.0)
        XCTAssertEqual(150.0.clampedBattery, 100.0)
    }
}

// MARK: - Validation Tests

final class DoubleValidationTests: XCTestCase {

    func testIsValidHeartRate() {
        XCTAssertTrue(72.0.isValidHeartRate)
        XCTAssertTrue(30.0.isValidHeartRate)
        XCTAssertTrue(250.0.isValidHeartRate)

        XCTAssertFalse(25.0.isValidHeartRate)
        XCTAssertFalse(260.0.isValidHeartRate)
    }

    func testIsValidSpO2() {
        XCTAssertTrue(98.0.isValidSpO2)
        XCTAssertTrue(70.0.isValidSpO2)
        XCTAssertTrue(100.0.isValidSpO2)

        XCTAssertFalse(60.0.isValidSpO2)
        XCTAssertFalse(105.0.isValidSpO2)
    }

    func testIsValidBodyTemperature() {
        XCTAssertTrue(36.5.isValidBodyTemperature)
        XCTAssertTrue(35.0.isValidBodyTemperature)
        XCTAssertTrue(42.0.isValidBodyTemperature)

        XCTAssertFalse(30.0.isValidBodyTemperature)
        XCTAssertFalse(45.0.isValidBodyTemperature)
    }

    func testIsValidNumber() {
        XCTAssertTrue(72.0.isValidNumber)
        XCTAssertTrue(0.0.isValidNumber)
        XCTAssertTrue((-100.0).isValidNumber)

        XCTAssertFalse(Double.nan.isValidNumber)
        XCTAssertFalse(Double.infinity.isValidNumber)
        XCTAssertFalse((-Double.infinity).isValidNumber)
    }
}

// MARK: - Math Utilities Tests

final class DoubleMathUtilitiesTests: XCTestCase {

    func testLerp() {
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 0.0), 0.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 0.5), 50.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 1.0), 100.0)

        // t clamped to 0...1
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: -0.5), 0.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 1.5), 100.0)
    }

    func testMapped() {
        // Map from 0...100 to 0...1
        XCTAssertEqual(50.0.mapped(from: 0...100, to: 0...1), 0.5, accuracy: 0.001)
        XCTAssertEqual(0.0.mapped(from: 0...100, to: 0...1), 0.0, accuracy: 0.001)
        XCTAssertEqual(100.0.mapped(from: 0...100, to: 0...1), 1.0, accuracy: 0.001)

        // Map temperature range
        XCTAssertEqual(36.5.mapped(from: 35...42, to: 0...100), 21.43, accuracy: 0.1)
    }

    func testNormalized() {
        XCTAssertEqual(50.0.normalized(min: 0, max: 100), 0.5, accuracy: 0.001)
        XCTAssertEqual(0.0.normalized(min: 0, max: 100), 0.0, accuracy: 0.001)
        XCTAssertEqual(100.0.normalized(min: 0, max: 100), 1.0, accuracy: 0.001)

        // Edge case: max <= min
        XCTAssertEqual(50.0.normalized(min: 100, max: 0), 0.0)
        XCTAssertEqual(50.0.normalized(min: 50, max: 50), 0.0)
    }
}

// MARK: - Conversion Tests

final class DoubleConversionTests: XCTestCase {

    func testCelsiusToFahrenheit() {
        XCTAssertEqual(0.0.celsiusToFahrenheit, 32.0, accuracy: 0.1)
        XCTAssertEqual(100.0.celsiusToFahrenheit, 212.0, accuracy: 0.1)
        XCTAssertEqual(37.0.celsiusToFahrenheit, 98.6, accuracy: 0.1)
    }

    func testFahrenheitToCelsius() {
        XCTAssertEqual(32.0.fahrenheitToCelsius, 0.0, accuracy: 0.1)
        XCTAssertEqual(212.0.fahrenheitToCelsius, 100.0, accuracy: 0.1)
        XCTAssertEqual(98.6.fahrenheitToCelsius, 37.0, accuracy: 0.1)
    }

    func testMsToSeconds() {
        XCTAssertEqual(1000.0.msToSeconds, 1.0, accuracy: 0.001)
        XCTAssertEqual(500.0.msToSeconds, 0.5, accuracy: 0.001)
        XCTAssertEqual(0.0.msToSeconds, 0.0, accuracy: 0.001)
    }

    func testSecondsToMs() {
        XCTAssertEqual(1.0.secondsToMs, 1000.0, accuracy: 0.001)
        XCTAssertEqual(0.5.secondsToMs, 500.0, accuracy: 0.001)
        XCTAssertEqual(0.0.secondsToMs, 0.0, accuracy: 0.001)
    }
}

// MARK: - Int Extensions Tests

final class IntExtensionsTests: XCTestCase {

    func testBatteryDisplayString() {
        XCTAssertEqual(85.batteryDisplayString, "85%")
        XCTAssertEqual(100.batteryDisplayString, "100%")
        XCTAssertEqual(0.batteryDisplayString, "0%")
        XCTAssertEqual(105.batteryDisplayString, "100%") // Clamped
        XCTAssertEqual((-5).batteryDisplayString, "0%") // Clamped
    }

    func testBatteryLevelHigh() {
        XCTAssertEqual(100.batteryLevel, .high)
        XCTAssertEqual(85.batteryLevel, .high)
        XCTAssertEqual(75.batteryLevel, .high)
    }

    func testBatteryLevelMedium() {
        XCTAssertEqual(74.batteryLevel, .medium)
        XCTAssertEqual(50.batteryLevel, .medium)
        XCTAssertEqual(40.batteryLevel, .medium)
    }

    func testBatteryLevelLow() {
        XCTAssertEqual(39.batteryLevel, .low)
        XCTAssertEqual(20.batteryLevel, .low)
        XCTAssertEqual(15.batteryLevel, .low)
    }

    func testBatteryLevelCritical() {
        XCTAssertEqual(14.batteryLevel, .critical)
        XCTAssertEqual(5.batteryLevel, .critical)
        XCTAssertEqual(0.batteryLevel, .critical)
    }

    func testBatteryLevelUnknown() {
        XCTAssertEqual((-1).batteryLevel, .unknown)
        XCTAssertEqual(101.batteryLevel, .unknown) // Over 100 falls to default case
    }

    func testIntClamped() {
        XCTAssertEqual(50.clamped(to: 0...100), 50)
        XCTAssertEqual((-10).clamped(to: 0...100), 0)
        XCTAssertEqual(150.clamped(to: 0...100), 100)
    }
}

// MARK: - BatteryLevel Tests

final class BatteryLevelTests: XCTestCase {

    func testBatteryLevelRawValues() {
        XCTAssertEqual(BatteryLevel.high.rawValue, "high")
        XCTAssertEqual(BatteryLevel.medium.rawValue, "medium")
        XCTAssertEqual(BatteryLevel.low.rawValue, "low")
        XCTAssertEqual(BatteryLevel.critical.rawValue, "critical")
        XCTAssertEqual(BatteryLevel.unknown.rawValue, "unknown")
    }

    func testBatteryLevelIconNames() {
        XCTAssertEqual(BatteryLevel.high.iconName, "battery.100")
        XCTAssertEqual(BatteryLevel.medium.iconName, "battery.50")
        XCTAssertEqual(BatteryLevel.low.iconName, "battery.25")
        XCTAssertEqual(BatteryLevel.critical.iconName, "battery.0")
        XCTAssertEqual(BatteryLevel.unknown.iconName, "battery.0")
    }

    func testBatteryLevelShouldWarn() {
        XCTAssertFalse(BatteryLevel.high.shouldWarn)
        XCTAssertFalse(BatteryLevel.medium.shouldWarn)
        XCTAssertTrue(BatteryLevel.low.shouldWarn)
        XCTAssertTrue(BatteryLevel.critical.shouldWarn)
        XCTAssertFalse(BatteryLevel.unknown.shouldWarn)
    }
}

// MARK: - Double Array Extensions Tests

final class DoubleArrayExtensionsTests: XCTestCase {

    func testSum() {
        XCTAssertEqual([1.0, 2.0, 3.0, 4.0, 5.0].sum, 15.0, accuracy: 0.001)
        XCTAssertEqual([Double]().sum, 0.0)
        XCTAssertEqual([10.0].sum, 10.0)
    }

    func testAverage() {
        XCTAssertEqual([1.0, 2.0, 3.0, 4.0, 5.0].average!, 3.0, accuracy: 0.001)
        XCTAssertNil([Double]().average)
        XCTAssertEqual([10.0].average!, 10.0, accuracy: 0.001)
    }

    func testStandardDeviation() {
        // Standard deviation of [1,2,3,4,5] = sqrt(2.5) ≈ 1.58
        let stdDev = [1.0, 2.0, 3.0, 4.0, 5.0].standardDeviation
        XCTAssertNotNil(stdDev)
        XCTAssertEqual(stdDev!, 1.58, accuracy: 0.1)

        XCTAssertNil([Double]().standardDeviation)
        XCTAssertNil([10.0].standardDeviation) // Need > 1 element
    }

    func testMinimum() {
        XCTAssertEqual([5.0, 2.0, 8.0, 1.0, 9.0].minimum, 1.0)
        XCTAssertNil([Double]().minimum)
    }

    func testMaximum() {
        XCTAssertEqual([5.0, 2.0, 8.0, 1.0, 9.0].maximum, 9.0)
        XCTAssertNil([Double]().maximum)
    }

    func testRange() {
        XCTAssertEqual([5.0, 2.0, 8.0, 1.0, 9.0].range, 8.0) // 9 - 1 = 8
        XCTAssertNil([Double]().range)
    }

    func testMedianOddCount() {
        XCTAssertEqual([1.0, 2.0, 3.0, 4.0, 5.0].median, 3.0)
        XCTAssertEqual([5.0, 1.0, 3.0].median, 3.0) // Sorted: [1,3,5]
    }

    func testMedianEvenCount() {
        XCTAssertEqual([1.0, 2.0, 3.0, 4.0].median, 2.5) // (2+3)/2
        XCTAssertEqual([1.0, 2.0].median, 1.5)
    }

    func testMedianEmpty() {
        XCTAssertNil([Double]().median)
    }

    func testWithoutOutliers() {
        // Array with outliers
        let values = [10.0, 12.0, 11.0, 13.0, 12.0, 100.0, 11.0, 12.0, 10.0]
        let filtered = values.withoutOutliers()

        // 100 should be removed as an outlier
        XCTAssertFalse(filtered.contains(100.0))
        XCTAssertEqual(filtered.count, 8)
    }

    func testWithoutOutliersSmallArray() {
        // Arrays with <= 4 elements return unchanged
        let small = [1.0, 2.0, 100.0]
        XCTAssertEqual(small.withoutOutliers(), small)
    }
}
