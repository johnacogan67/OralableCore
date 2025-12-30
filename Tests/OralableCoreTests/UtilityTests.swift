//
//  UtilityTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for utility classes and extensions
//

import XCTest
@testable import OralableCore

final class UtilityTests: XCTestCase {

    // MARK: - Logger Tests

    func testLoggerSingleton() {
        let logger1 = Logger.shared
        let logger2 = Logger.shared
        XCTAssertTrue(logger1 === logger2)
    }

    func testLoggerMinimumLevel() {
        Logger.shared.minimumLevel = .warning
        Logger.shared.clearRecentLogs()

        Logger.shared.debug("Debug message")
        Logger.shared.info("Info message")
        Logger.shared.warning("Warning message")
        Logger.shared.error("Error message")

        let logs = Logger.shared.getRecentLogs()
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(logs.allSatisfy { $0.level >= .warning })

        // Reset
        Logger.shared.minimumLevel = .debug
    }

    func testLoggerCategoryFiltering() {
        Logger.shared.clearRecentLogs()

        Logger.shared.bluetooth("BLE message")
        Logger.shared.sensor("Sensor message")
        Logger.shared.info("System message")

        let bluetoothLogs = Logger.shared.getRecentLogs(category: .bluetooth)
        XCTAssertEqual(bluetoothLogs.count, 1)
        XCTAssertEqual(bluetoothLogs.first?.category, .bluetooth)
    }

    func testLoggerRecentLogs() {
        Logger.shared.clearRecentLogs()

        for i in 0..<10 {
            Logger.shared.info("Message \(i)")
        }

        let logs = Logger.shared.getRecentLogs()
        XCTAssertEqual(logs.count, 10)
    }

    // MARK: - Feature Flags Tests

    func testFeatureFlagsRegistration() {
        let flags = FeatureFlags.shared
        flags.register(.heartRateEnabled)

        XCTAssertTrue(flags.isEnabled(.heartRateEnabled))
    }

    func testFeatureFlagsToggle() {
        let flags = FeatureFlags.shared
        let testFlag = FeatureFlag(
            key: "test.toggle",
            name: "Test Toggle",
            description: "Test flag",
            defaultValue: false
        )
        flags.register(testFlag)

        XCTAssertFalse(flags.isEnabled(testFlag))
        flags.toggle(testFlag.key)
        XCTAssertTrue(flags.isEnabled(testFlag))
        flags.toggle(testFlag.key)
        XCTAssertFalse(flags.isEnabled(testFlag))
    }

    func testFeatureFlagsPreset() {
        let flags = FeatureFlags.shared
        flags.register(FeatureFlag.allCommon)

        flags.applyPreset(.minimal)
        XCTAssertFalse(flags.isEnabled("sensors.spo2"))

        flags.applyPreset(.full)
        XCTAssertTrue(flags.isEnabled("sensors.spo2"))
    }

    func testFeatureFlagsCategories() {
        let flags = FeatureFlags.shared
        flags.register(FeatureFlag.allCommon)

        let sensorFlags = flags.flags(in: .sensors)
        XCTAssertTrue(sensorFlags.count >= 3)
        XCTAssertTrue(sensorFlags.allSatisfy { $0.category == .sensors })
    }

    func testFeatureFlagNonConfigurable() {
        let flags = FeatureFlags.shared
        flags.register(.mockSensorData)

        let initialValue = flags.isEnabled(.mockSensorData)
        flags.setEnabled(.mockSensorData, !initialValue)

        // Should not change because isUserConfigurable is false
        XCTAssertEqual(flags.isEnabled(.mockSensorData), initialValue)
    }

    // MARK: - Date Extension Tests

    func testDateFormatting() {
        let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        XCTAssertFalse(date.timeString.isEmpty)
        XCTAssertFalse(date.dateString.isEmpty)
        XCTAssertFalse(date.iso8601String.isEmpty)
    }

    func testDateStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)

        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testDateAdding() {
        let date = Date()

        let plusMinutes = date.adding(minutes: 5)
        XCTAssertEqual(plusMinutes.minutes(from: date), 5.0, accuracy: 0.01)

        let plusHours = date.adding(hours: 2)
        XCTAssertEqual(plusHours.hours(from: date), 2.0, accuracy: 0.01)

        let plusDays = date.adding(days: 1)
        XCTAssertEqual(plusDays.hours(from: date), 24.0, accuracy: 0.01)
    }

    func testDateIsToday() {
        let today = Date()
        let yesterday = today.adding(days: -1)
        let tomorrow = today.adding(days: 1)

        XCTAssertTrue(today.isToday)
        XCTAssertFalse(yesterday.isToday)
        XCTAssertFalse(tomorrow.isToday)
        XCTAssertTrue(yesterday.isYesterday)
    }

    func testDateIsWithin() {
        let date = Date()
        let nearby = date.adding(seconds: 5)
        let farAway = date.adding(seconds: 100)

        XCTAssertTrue(nearby.isWithin(10, of: date))
        XCTAssertFalse(farAway.isWithin(10, of: date))
    }

    func testDateUnixMilliseconds() {
        let date = Date()
        let ms = date.unixMilliseconds
        let reconstructed = Date.fromUnixMilliseconds(ms)

        XCTAssertEqual(date.timeIntervalSince1970, reconstructed.timeIntervalSince1970, accuracy: 0.001)
    }

    func testTimeIntervalDurationString() {
        XCTAssertEqual(TimeInterval(65).durationString, "1:05")
        XCTAssertEqual(TimeInterval(3661).durationString, "1:01:01")
        XCTAssertEqual(TimeInterval(30).durationString, "0:30")
    }

    func testTimeIntervalCompactDuration() {
        XCTAssertEqual(TimeInterval(30).compactDurationString, "30s")
        XCTAssertEqual(TimeInterval(90).compactDurationString, "1m 30s")
        XCTAssertEqual(TimeInterval(3700).compactDurationString, "1h 1m")
    }

    // MARK: - Double Extension Tests

    func testDoubleFormatting() {
        let value = 72.567

        XCTAssertEqual(value.formatted(decimals: 0), "73")
        XCTAssertEqual(value.formatted(decimals: 1), "72.6")
        XCTAssertEqual(value.formatted(decimals: 2), "72.57")
    }

    func testDoubleSensorFormatting() {
        XCTAssertEqual((72.5).asHeartRate, "73 bpm")
        XCTAssertEqual((98.2).asSpO2, "98%")
        XCTAssertEqual((36.5).asTemperature, "36.5°C")
        XCTAssertEqual((0.95).asAcceleration, "0.95 g")
        XCTAssertEqual((85.0).asBatteryPercentage, "85%")
    }

    func testDoubleRounding() {
        let value = 72.5678

        XCTAssertEqual(value.rounded(toPlaces: 0), 73.0)
        XCTAssertEqual(value.rounded(toPlaces: 1), 72.6)
        XCTAssertEqual(value.rounded(toPlaces: 2), 72.57)
        XCTAssertEqual(value.roundedInt, 73)
    }

    func testDoubleClamping() {
        XCTAssertEqual((150.0).clamped(to: 0...100), 100.0)
        XCTAssertEqual((-10.0).clamped(to: 0...100), 0.0)
        XCTAssertEqual((50.0).clamped(to: 0...100), 50.0)

        XCTAssertEqual((25.0).clampedHeartRate, 30.0)
        XCTAssertEqual((300.0).clampedHeartRate, 250.0)
    }

    func testDoubleValidation() {
        XCTAssertTrue((72.0).isValidHeartRate)
        XCTAssertFalse((20.0).isValidHeartRate)
        XCTAssertFalse((300.0).isValidHeartRate)

        XCTAssertTrue((98.0).isValidSpO2)
        XCTAssertFalse((60.0).isValidSpO2)

        XCTAssertTrue((37.0).isValidBodyTemperature)
        XCTAssertFalse((30.0).isValidBodyTemperature)

        XCTAssertTrue((42.0).isValidNumber)
        XCTAssertFalse(Double.nan.isValidNumber)
        XCTAssertFalse(Double.infinity.isValidNumber)
    }

    func testDoubleLerp() {
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 0.5), 50.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 0.0), 0.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 1.0), 100.0)
        XCTAssertEqual(Double.lerp(from: 0, to: 100, t: 1.5), 100.0) // Clamped
    }

    func testDoubleMapped() {
        let value = 50.0
        let mapped = value.mapped(from: 0...100, to: 0...1)
        XCTAssertEqual(mapped, 0.5)

        let mapped2 = (25.0).mapped(from: 0...100, to: 200...300)
        XCTAssertEqual(mapped2, 225.0)
    }

    func testDoubleNormalized() {
        XCTAssertEqual((50.0).normalized(min: 0, max: 100), 0.5)
        XCTAssertEqual((75.0).normalized(min: 50, max: 100), 0.5)
    }

    func testDoubleTemperatureConversion() {
        XCTAssertEqual((0.0).celsiusToFahrenheit, 32.0)
        XCTAssertEqual((100.0).celsiusToFahrenheit, 212.0)
        XCTAssertEqual((32.0).fahrenheitToCelsius, 0.0, accuracy: 0.01)
    }

    // MARK: - Int Extension Tests

    func testIntBatteryLevel() {
        XCTAssertEqual(90.batteryLevel, .high)
        XCTAssertEqual(60.batteryLevel, .medium)
        XCTAssertEqual(30.batteryLevel, .low)
        XCTAssertEqual(10.batteryLevel, .critical)
    }

    func testIntBatteryDisplay() {
        XCTAssertEqual(85.batteryDisplayString, "85%")
        XCTAssertEqual((-5).batteryDisplayString, "0%")
        XCTAssertEqual(150.batteryDisplayString, "100%")
    }

    // MARK: - Array Extension Tests

    func testArraySum() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(values.sum, 15.0)
    }

    func testArrayAverage() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(values.average, 3.0)
        XCTAssertNil([Double]().average)
    }

    func testArrayStandardDeviation() {
        let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let stdDev = values.standardDeviation!
        // Using sample standard deviation (n-1 divisor)
        XCTAssertEqual(stdDev, 2.14, accuracy: 0.1)
    }

    func testArrayMinMax() {
        let values = [5.0, 2.0, 8.0, 1.0, 9.0]
        XCTAssertEqual(values.minimum, 1.0)
        XCTAssertEqual(values.maximum, 9.0)
        XCTAssertEqual(values.range, 8.0)
    }

    func testArrayMedian() {
        let oddValues = [1.0, 3.0, 5.0, 7.0, 9.0]
        XCTAssertEqual(oddValues.median, 5.0)

        let evenValues = [1.0, 2.0, 3.0, 4.0]
        XCTAssertEqual(evenValues.median, 2.5)

        XCTAssertNil([Double]().median)
    }

    func testArrayOutlierRemoval() {
        let values = [1.0, 2.0, 2.0, 2.0, 3.0, 100.0] // 100 is an outlier
        let filtered = values.withoutOutliers()
        XCTAssertFalse(filtered.contains(100.0))
        XCTAssertTrue(filtered.contains(2.0))
    }

    // MARK: - Battery Level Tests

    func testBatteryLevelIcon() {
        XCTAssertEqual(BatteryLevel.high.iconName, "battery.100")
        XCTAssertEqual(BatteryLevel.medium.iconName, "battery.50")
        XCTAssertEqual(BatteryLevel.low.iconName, "battery.25")
        XCTAssertEqual(BatteryLevel.critical.iconName, "battery.0")
    }

    func testBatteryLevelWarning() {
        XCTAssertFalse(BatteryLevel.high.shouldWarn)
        XCTAssertFalse(BatteryLevel.medium.shouldWarn)
        XCTAssertTrue(BatteryLevel.low.shouldWarn)
        XCTAssertTrue(BatteryLevel.critical.shouldWarn)
    }
}
