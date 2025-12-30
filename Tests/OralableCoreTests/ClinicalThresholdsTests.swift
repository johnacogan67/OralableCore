//
//  ClinicalThresholdsTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for ClinicalThresholds utility
//

import XCTest
@testable import OralableCore

// MARK: - Heart Rate Thresholds Tests

final class HeartRateThresholdsTests: XCTestCase {

    // MARK: - Static Values

    func testAbsoluteLimits() {
        XCTAssertEqual(ClinicalThresholds.HeartRate.absoluteMinimum, 30)
        XCTAssertEqual(ClinicalThresholds.HeartRate.absoluteMaximum, 250)
    }

    func testBradycardiaAndTachycardiaThresholds() {
        XCTAssertEqual(ClinicalThresholds.HeartRate.bradycardiaThreshold, 60)
        XCTAssertEqual(ClinicalThresholds.HeartRate.tachycardiaThreshold, 100)
    }

    func testNormalRestingRange() {
        let range = ClinicalThresholds.HeartRate.normalRestingRange
        XCTAssertEqual(range.lowerBound, 60)
        XCTAssertEqual(range.upperBound, 100)
    }

    func testAthleticRestingRange() {
        let range = ClinicalThresholds.HeartRate.athleticRestingRange
        XCTAssertEqual(range.lowerBound, 40)
        XCTAssertEqual(range.upperBound, 60)
    }

    func testSleepingRange() {
        let range = ClinicalThresholds.HeartRate.sleepingRange
        XCTAssertTrue(range.contains(50))
        XCTAssertTrue(range.contains(65))
    }

    // MARK: - Heart Rate Zones

    func testZonePercentageRanges() {
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.resting.percentageRange, 0...50)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.warmUp.percentageRange, 50...60)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.fatBurn.percentageRange, 60...70)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.cardio.percentageRange, 70...85)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.peak.percentageRange, 85...100)
    }

    func testZoneFromHeartRate() {
        let maxHR = 180.0

        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.zone(heartRate: 80, maxHeartRate: maxHR), .resting)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.zone(heartRate: 100, maxHeartRate: maxHR), .warmUp)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.zone(heartRate: 120, maxHeartRate: maxHR), .fatBurn)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.zone(heartRate: 140, maxHeartRate: maxHR), .cardio)
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.zone(heartRate: 170, maxHeartRate: maxHR), .peak)
    }

    func testZoneRawValues() {
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.resting.rawValue, "Resting")
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.fatBurn.rawValue, "Fat Burn")
        XCTAssertEqual(ClinicalThresholds.HeartRate.Zone.peak.rawValue, "Peak")
    }

    // MARK: - Estimated Maximum Heart Rate (Tanaka Formula)

    func testEstimatedMaxHeartRate() {
        // Tanaka formula: maxHR = 208 - (0.7 × age)
        XCTAssertEqual(ClinicalThresholds.HeartRate.estimatedMaxHeartRate(age: 20), 194)
        XCTAssertEqual(ClinicalThresholds.HeartRate.estimatedMaxHeartRate(age: 40), 180)
        XCTAssertEqual(ClinicalThresholds.HeartRate.estimatedMaxHeartRate(age: 60), 166)
        XCTAssertEqual(ClinicalThresholds.HeartRate.estimatedMaxHeartRate(age: 80), 152)
    }

    // MARK: - Target Heart Rate Range

    func testTargetHeartRateRangeSimple() {
        // 40 year old: maxHR = 180
        // 50% = 90, 85% = 153
        let range = ClinicalThresholds.HeartRate.targetHeartRateRange(age: 40)
        XCTAssertEqual(range.lowerBound, 90, accuracy: 1)
        XCTAssertEqual(range.upperBound, 153, accuracy: 1)
    }

    func testTargetHeartRateRangeKarvonen() {
        // 40 year old: maxHR = 180, restingHR = 60
        // Reserve = 180 - 60 = 120
        // 50% target = (120 × 0.5) + 60 = 120
        // 85% target = (120 × 0.85) + 60 = 162
        let range = ClinicalThresholds.HeartRate.targetHeartRateRange(age: 40, restingHR: 60)
        XCTAssertEqual(range.lowerBound, 120, accuracy: 1)
        XCTAssertEqual(range.upperBound, 162, accuracy: 1)
    }

    func testTargetHeartRateRangeCustomIntensity() {
        // Custom 60-70% intensity
        let range = ClinicalThresholds.HeartRate.targetHeartRateRange(
            age: 40,
            minIntensity: 0.6,
            maxIntensity: 0.7
        )
        // maxHR = 180
        // 60% = 108, 70% = 126
        XCTAssertEqual(range.lowerBound, 108, accuracy: 1)
        XCTAssertEqual(range.upperBound, 126, accuracy: 1)
    }

    // MARK: - Age-Based Normal Resting Range

    func testNormalRestingRangeByAge() {
        // Infant
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 0), 100...160)

        // Toddler
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 2), 90...150)

        // Preschool
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 4), 80...140)

        // School age
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 8), 70...120)

        // Adolescent
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 15), 60...100)

        // Adult
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 30), 60...100)
        XCTAssertEqual(ClinicalThresholds.HeartRate.normalRestingRange(age: 70), 60...100)
    }
}

// MARK: - SpO2 Thresholds Tests

final class SpO2ThresholdsTests: XCTestCase {

    func testAbsoluteLimits() {
        XCTAssertEqual(ClinicalThresholds.SpO2.absoluteMinimum, 50)
        XCTAssertEqual(ClinicalThresholds.SpO2.absoluteMaximum, 100)
    }

    func testNormalRange() {
        let range = ClinicalThresholds.SpO2.normalRange
        XCTAssertEqual(range.lowerBound, 95)
        XCTAssertEqual(range.upperBound, 100)
    }

    func testCriticalThresholds() {
        XCTAssertEqual(ClinicalThresholds.SpO2.lowThreshold, 90)
        XCTAssertEqual(ClinicalThresholds.SpO2.criticalThreshold, 85)
        XCTAssertEqual(ClinicalThresholds.SpO2.severeHypoxemiaThreshold, 80)
    }

    // MARK: - SpO2 Status

    func testStatusFromPercentage() {
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 98), .normal)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 95), .normal)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 92), .borderline)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 90), .borderline)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 87), .low)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 85), .low)
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.status(for: 80), .critical)
    }

    func testStatusColorNames() {
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.normal.colorName, "green")
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.borderline.colorName, "yellow")
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.low.colorName, "orange")
        XCTAssertEqual(ClinicalThresholds.SpO2.Status.critical.colorName, "red")
    }

    // MARK: - Altitude Adjustment

    func testAltitudeAdjustedNormalMinimum() {
        // Sea level
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 0), 95)

        // Low altitude (no adjustment)
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 1000), 95)

        // At threshold
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 1500), 95)

        // High altitude
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 2500), 94)
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 3500), 93)

        // Very high altitude (caps at 88%)
        XCTAssertEqual(ClinicalThresholds.SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: 10000), 88)
    }
}

// MARK: - Temperature Thresholds Tests

final class TemperatureThresholdsTests: XCTestCase {

    func testAbsoluteLimits() {
        XCTAssertEqual(ClinicalThresholds.Temperature.absoluteMinimum, 30.0)
        XCTAssertEqual(ClinicalThresholds.Temperature.absoluteMaximum, 45.0)
    }

    func testNormalRange() {
        let range = ClinicalThresholds.Temperature.normalRange
        XCTAssertEqual(range.lowerBound, 36.1)
        XCTAssertEqual(range.upperBound, 37.2)
    }

    func testFeverThresholds() {
        XCTAssertEqual(ClinicalThresholds.Temperature.lowGradeFeverThreshold, 37.5)
        XCTAssertEqual(ClinicalThresholds.Temperature.feverThreshold, 38.0)
        XCTAssertEqual(ClinicalThresholds.Temperature.highFeverThreshold, 39.0)
        XCTAssertEqual(ClinicalThresholds.Temperature.dangerousFeverThreshold, 40.0)
    }

    func testHypothermiaThresholds() {
        XCTAssertEqual(ClinicalThresholds.Temperature.hypothermiaThreshold, 35.0)
        XCTAssertEqual(ClinicalThresholds.Temperature.severeHypothermiaThreshold, 32.0)
    }

    // MARK: - Temperature Status

    func testStatusFromCelsius() {
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 33), .hypothermia)
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 35.5), .low)
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 36.8), .normal)
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 37.5), .elevated)
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 38.5), .fever)
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.status(celsius: 40), .highFever)
    }

    func testStatusRawValues() {
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.hypothermia.rawValue, "Hypothermia")
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.normal.rawValue, "Normal")
        XCTAssertEqual(ClinicalThresholds.Temperature.Status.fever.rawValue, "Fever")
    }

    // MARK: - Temperature Conversions

    func testCelsiusToFahrenheit() {
        XCTAssertEqual(ClinicalThresholds.Temperature.celsiusToFahrenheit(0), 32, accuracy: 0.1)
        XCTAssertEqual(ClinicalThresholds.Temperature.celsiusToFahrenheit(37), 98.6, accuracy: 0.1)
        XCTAssertEqual(ClinicalThresholds.Temperature.celsiusToFahrenheit(100), 212, accuracy: 0.1)
    }

    func testFahrenheitToCelsius() {
        XCTAssertEqual(ClinicalThresholds.Temperature.fahrenheitToCelsius(32), 0, accuracy: 0.1)
        XCTAssertEqual(ClinicalThresholds.Temperature.fahrenheitToCelsius(98.6), 37, accuracy: 0.1)
        XCTAssertEqual(ClinicalThresholds.Temperature.fahrenheitToCelsius(212), 100, accuracy: 0.1)
    }

    func testTemperatureRoundTrip() {
        let original = 36.5
        let converted = ClinicalThresholds.Temperature.fahrenheitToCelsius(
            ClinicalThresholds.Temperature.celsiusToFahrenheit(original)
        )
        XCTAssertEqual(converted, original, accuracy: 0.001)
    }
}

// MARK: - Quality Thresholds Tests

final class QualityThresholdsTests: XCTestCase {

    func testThresholdValues() {
        XCTAssertEqual(ClinicalThresholds.Quality.minimumValid, 0.5)
        XCTAssertEqual(ClinicalThresholds.Quality.clinicalGrade, 0.7)
        XCTAssertEqual(ClinicalThresholds.Quality.excellent, 0.9)
    }

    func testLevelFromQuality() {
        XCTAssertEqual(ClinicalThresholds.Quality.Level.level(for: 0.3), .poor)
        XCTAssertEqual(ClinicalThresholds.Quality.Level.level(for: 0.55), .acceptable)
        XCTAssertEqual(ClinicalThresholds.Quality.Level.level(for: 0.75), .good)
        XCTAssertEqual(ClinicalThresholds.Quality.Level.level(for: 0.95), .excellent)
    }

    func testLevelRawValues() {
        XCTAssertEqual(ClinicalThresholds.Quality.Level.poor.rawValue, "Poor")
        XCTAssertEqual(ClinicalThresholds.Quality.Level.excellent.rawValue, "Excellent")
    }

    func testIsClinicallyAcceptable() {
        XCTAssertFalse(ClinicalThresholds.Quality.Level.poor.isClinicallyAcceptable)
        XCTAssertFalse(ClinicalThresholds.Quality.Level.acceptable.isClinicallyAcceptable)
        XCTAssertTrue(ClinicalThresholds.Quality.Level.good.isClinicallyAcceptable)
        XCTAssertTrue(ClinicalThresholds.Quality.Level.excellent.isClinicallyAcceptable)
    }
}

// MARK: - Movement Thresholds Tests

final class MovementThresholdsTests: XCTestCase {

    func testVariabilityThresholds() {
        XCTAssertEqual(ClinicalThresholds.Movement.defaultVariabilityThreshold, 1500)
        XCTAssertEqual(ClinicalThresholds.Movement.sensitiveThreshold, 500)
        XCTAssertEqual(ClinicalThresholds.Movement.insensitiveThreshold, 5000)
    }

    func testAdjustableRange() {
        let range = ClinicalThresholds.Movement.adjustableRange
        XCTAssertEqual(range.lowerBound, 500)
        XCTAssertEqual(range.upperBound, 5000)
    }

    func testRestDetectionValues() {
        XCTAssertEqual(ClinicalThresholds.Movement.restMagnitude, 1.0)
        XCTAssertEqual(ClinicalThresholds.Movement.restTolerance, 0.1)
    }

    func testActivityDetectionThresholds() {
        XCTAssertEqual(ClinicalThresholds.Movement.clenchingThreshold, 0.05)
        XCTAssertEqual(ClinicalThresholds.Movement.grindingThreshold, 0.15)
        XCTAssertEqual(ClinicalThresholds.Movement.motionThreshold, 0.3)

        // Thresholds should be in ascending order
        XCTAssertLessThan(ClinicalThresholds.Movement.clenchingThreshold, ClinicalThresholds.Movement.grindingThreshold)
        XCTAssertLessThan(ClinicalThresholds.Movement.grindingThreshold, ClinicalThresholds.Movement.motionThreshold)
    }
}

// MARK: - Perfusion Index Thresholds Tests

final class PerfusionIndexThresholdsTests: XCTestCase {

    func testSignalThresholds() {
        XCTAssertEqual(ClinicalThresholds.PerfusionIndex.noSignal, 0.0005)
        XCTAssertEqual(ClinicalThresholds.PerfusionIndex.weakSignal, 0.001)
        XCTAssertEqual(ClinicalThresholds.PerfusionIndex.moderateSignal, 0.003)
        XCTAssertEqual(ClinicalThresholds.PerfusionIndex.strongSignal, 0.01)
    }

    func testWornDetectionThreshold() {
        XCTAssertEqual(ClinicalThresholds.PerfusionIndex.minimumForWornDetection, 0.001)
    }

    func testThresholdsAscendingOrder() {
        XCTAssertLessThan(ClinicalThresholds.PerfusionIndex.noSignal, ClinicalThresholds.PerfusionIndex.weakSignal)
        XCTAssertLessThan(ClinicalThresholds.PerfusionIndex.weakSignal, ClinicalThresholds.PerfusionIndex.moderateSignal)
        XCTAssertLessThan(ClinicalThresholds.PerfusionIndex.moderateSignal, ClinicalThresholds.PerfusionIndex.strongSignal)
    }
}

// MARK: - R Ratio Thresholds Tests

final class RRatioThresholdsTests: XCTestCase {

    func testValidRange() {
        XCTAssertEqual(ClinicalThresholds.RRatio.minimum, 0.4)
        XCTAssertEqual(ClinicalThresholds.RRatio.maximum, 3.4)
        XCTAssertEqual(ClinicalThresholds.RRatio.validRange, 0.4...3.4)
    }

    func testTheoreticalValues() {
        XCTAssertEqual(ClinicalThresholds.RRatio.at100Percent, 0.4)
        XCTAssertEqual(ClinicalThresholds.RRatio.at0Percent, 3.4)
    }
}

// MARK: - Validation Helpers Tests

final class ClinicalThresholdsValidationTests: XCTestCase {

    // MARK: - Heart Rate Validation

    func testIsValidHeartRate() {
        XCTAssertTrue(ClinicalThresholds.isValidHeartRate(72))
        XCTAssertTrue(ClinicalThresholds.isValidHeartRate(30))  // Minimum
        XCTAssertTrue(ClinicalThresholds.isValidHeartRate(250)) // Maximum
        XCTAssertFalse(ClinicalThresholds.isValidHeartRate(29))
        XCTAssertFalse(ClinicalThresholds.isValidHeartRate(251))
    }

    // MARK: - SpO2 Validation

    func testIsValidSpO2() {
        XCTAssertTrue(ClinicalThresholds.isValidSpO2(98))
        XCTAssertTrue(ClinicalThresholds.isValidSpO2(50))  // Minimum
        XCTAssertTrue(ClinicalThresholds.isValidSpO2(100)) // Maximum
        XCTAssertFalse(ClinicalThresholds.isValidSpO2(49))
        XCTAssertFalse(ClinicalThresholds.isValidSpO2(101))
    }

    // MARK: - Temperature Validation

    func testIsValidTemperature() {
        XCTAssertTrue(ClinicalThresholds.isValidTemperature(36.5))
        XCTAssertTrue(ClinicalThresholds.isValidTemperature(30))  // Minimum
        XCTAssertTrue(ClinicalThresholds.isValidTemperature(45))  // Maximum
        XCTAssertFalse(ClinicalThresholds.isValidTemperature(29.9))
        XCTAssertFalse(ClinicalThresholds.isValidTemperature(45.1))
    }

    // MARK: - Quality Validation

    func testIsValidQuality() {
        XCTAssertTrue(ClinicalThresholds.isValidQuality(0.5))
        XCTAssertTrue(ClinicalThresholds.isValidQuality(0))
        XCTAssertTrue(ClinicalThresholds.isValidQuality(1.0))
        XCTAssertFalse(ClinicalThresholds.isValidQuality(-0.1))
        XCTAssertFalse(ClinicalThresholds.isValidQuality(1.1))
    }

    // MARK: - Age-Based Heart Rate Validation

    func testIsNormalRestingHeartRate() {
        // Adult (30 years): normal range 60-100
        XCTAssertTrue(ClinicalThresholds.isNormalRestingHeartRate(72, age: 30))
        XCTAssertTrue(ClinicalThresholds.isNormalRestingHeartRate(60, age: 30))
        XCTAssertTrue(ClinicalThresholds.isNormalRestingHeartRate(100, age: 30))
        XCTAssertFalse(ClinicalThresholds.isNormalRestingHeartRate(55, age: 30))
        XCTAssertFalse(ClinicalThresholds.isNormalRestingHeartRate(105, age: 30))

        // Infant (6 months): normal range 100-160
        XCTAssertTrue(ClinicalThresholds.isNormalRestingHeartRate(130, age: 0))
        XCTAssertFalse(ClinicalThresholds.isNormalRestingHeartRate(90, age: 0))
    }

    // MARK: - Altitude-Adjusted SpO2 Validation

    func testIsNormalSpO2() {
        // At sea level
        XCTAssertTrue(ClinicalThresholds.isNormalSpO2(98))
        XCTAssertTrue(ClinicalThresholds.isNormalSpO2(95))
        XCTAssertFalse(ClinicalThresholds.isNormalSpO2(94))

        // At high altitude (3500m)
        XCTAssertTrue(ClinicalThresholds.isNormalSpO2(93, altitudeMeters: 3500))
        XCTAssertFalse(ClinicalThresholds.isNormalSpO2(92, altitudeMeters: 3500))
    }
}
