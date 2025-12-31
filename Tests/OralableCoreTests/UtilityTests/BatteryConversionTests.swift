//
//  BatteryConversionTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Comprehensive tests for BatteryConversion utility
//

import XCTest
@testable import OralableCore

final class BatteryConversionTests: XCTestCase {

    // MARK: - Voltage Constants Tests

    func testVoltageConstants() {
        XCTAssertEqual(BatteryConversion.voltageMax, 4200)
        XCTAssertEqual(BatteryConversion.voltageMin, 3000)
        XCTAssertEqual(BatteryConversion.voltageLowWarning, 3400)
        XCTAssertEqual(BatteryConversion.voltageCritical, 3200)
    }

    func testVoltageConstantsRelationship() {
        // Verify logical ordering
        XCTAssertGreaterThan(BatteryConversion.voltageMax, BatteryConversion.voltageLowWarning)
        XCTAssertGreaterThan(BatteryConversion.voltageLowWarning, BatteryConversion.voltageCritical)
        XCTAssertGreaterThan(BatteryConversion.voltageCritical, BatteryConversion.voltageMin)
    }

    // MARK: - Voltage to Percentage Conversion Tests

    func testVoltageToPercentageFullCharge() {
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 4200)
        XCTAssertEqual(percentage, 100.0)
    }

    func testVoltageToPercentageAboveMax() {
        // Voltage above max should return 100%
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 4500)
        XCTAssertEqual(percentage, 100.0)
    }

    func testVoltageToPercentageEmpty() {
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 3000)
        XCTAssertEqual(percentage, 0.0)
    }

    func testVoltageToPercentageBelowMin() {
        // Voltage below min should return 0%
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 2500)
        XCTAssertEqual(percentage, 0.0)
    }

    func testVoltageToPercentageMidRange() {
        // Test mid-range values from the discharge curve
        let at50Percent = BatteryConversion.voltageToPercentage(millivolts: 3800)
        XCTAssertEqual(at50Percent, 50.0, accuracy: 1.0)

        let at75Percent = BatteryConversion.voltageToPercentage(millivolts: 3980)
        XCTAssertEqual(at75Percent, 75.0, accuracy: 1.0)

        let at25Percent = BatteryConversion.voltageToPercentage(millivolts: 3610)
        XCTAssertEqual(at25Percent, 25.0, accuracy: 1.0)
    }

    func testVoltageToPercentageCurvePoints() {
        // Test exact curve points from the discharge curve
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 4150), 95.0, accuracy: 0.1)
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3910), 65.0, accuracy: 0.1)
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3500), 15.0, accuracy: 0.1)
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3300), 5.0, accuracy: 0.1)
    }

    func testVoltageToPercentageInterpolation() {
        // Test values between curve points (should interpolate)
        let between90and95 = BatteryConversion.voltageToPercentage(millivolts: 4130)
        XCTAssertGreaterThan(between90and95, 90.0)
        XCTAssertLessThan(between90and95, 95.0)

        let between30and35 = BatteryConversion.voltageToPercentage(millivolts: 3665)
        XCTAssertGreaterThan(between30and35, 30.0)
        XCTAssertLessThan(between30and35, 35.0)
    }

    func testVoltageToPercentageMonotonicity() {
        // Higher voltage should always give higher percentage
        var previousPercentage = 0.0
        for voltage: Int32 in stride(from: 3000, through: 4200, by: 50) {
            let percentage = BatteryConversion.voltageToPercentage(millivolts: voltage)
            XCTAssertGreaterThanOrEqual(percentage, previousPercentage,
                "Voltage \(voltage)mV should have >= percentage than lower voltages")
            previousPercentage = percentage
        }
    }

    // MARK: - Integer Percentage Tests

    func testVoltageToPercentageInt() {
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 4200), 100)
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 3000), 0)
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 3800), 50)
    }

    func testVoltageToPercentageIntRounding() {
        // Test rounding behavior
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 3665)
        let intPercentage = BatteryConversion.voltageToPercentageInt(millivolts: 3665)
        XCTAssertEqual(intPercentage, Int(percentage.rounded()))
    }

    // MARK: - Linear Percentage Tests

    func testLinearPercentageFullCharge() {
        let percentage = BatteryConversion.linearPercentage(millivolts: 4200)
        XCTAssertEqual(percentage, 100.0)
    }

    func testLinearPercentageEmpty() {
        let percentage = BatteryConversion.linearPercentage(millivolts: 3000)
        XCTAssertEqual(percentage, 0.0)
    }

    func testLinearPercentageMidRange() {
        // Linear: (3.6 - 3.0) / (4.2 - 3.0) * 100 = 50%
        let percentage = BatteryConversion.linearPercentage(millivolts: 3600)
        XCTAssertEqual(percentage, 50.0)
    }

    func testLinearPercentageClamping() {
        // Above max should clamp to 100
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 5000), 100.0)
        // Below min should clamp to 0
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 2000), 0.0)
    }

    func testCurveVsLinearDifference() {
        // At mid-range, curve and linear should differ
        // (LiPo batteries have non-linear discharge)
        let curveAt3600 = BatteryConversion.voltageToPercentage(millivolts: 3600)
        let linearAt3600 = BatteryConversion.linearPercentage(millivolts: 3600)

        // The curve should give different (usually lower) percentage at this voltage
        // because the discharge curve is steeper at the low end
        XCTAssertNotEqual(curveAt3600, linearAt3600, accuracy: 0.1)
    }

    // MARK: - Battery Status Tests

    func testBatteryStatusFromPercentage() {
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 90), .excellent)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 80), .excellent)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 75), .good)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 50), .good)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 45), .medium)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 20), .medium)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 15), .low)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 10), .low)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 5), .critical)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 0), .critical)
    }

    func testBatteryStatusFromVoltage() {
        // Full charge
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 4200), .excellent)

        // High
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 4000), .good)

        // Medium
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3700), .medium)

        // Low
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3400), .low)

        // Critical
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3100), .critical)
    }

    func testBatteryStatusBoundaryConditions() {
        // Test exact boundary values
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 80.0), .excellent)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 79.9), .good)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 50.0), .good)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 49.9), .medium)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 20.0), .medium)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 19.9), .low)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 10.0), .low)
        XCTAssertEqual(BatteryConversion.batteryStatus(percentage: 9.9), .critical)
    }

    // MARK: - Needs Charging Tests

    func testNeedsCharging() {
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 15))
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 10))
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 5))
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 0))

        XCTAssertFalse(BatteryConversion.needsCharging(percentage: 20))
        XCTAssertFalse(BatteryConversion.needsCharging(percentage: 50))
        XCTAssertFalse(BatteryConversion.needsCharging(percentage: 100))
    }

    func testNeedsChargingBoundary() {
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 19.9))
        XCTAssertFalse(BatteryConversion.needsCharging(percentage: 20.0))
    }

    // MARK: - Is Critical Tests

    func testIsCritical() {
        XCTAssertTrue(BatteryConversion.isCritical(percentage: 5))
        XCTAssertTrue(BatteryConversion.isCritical(percentage: 0))

        XCTAssertFalse(BatteryConversion.isCritical(percentage: 10))
        XCTAssertFalse(BatteryConversion.isCritical(percentage: 20))
        XCTAssertFalse(BatteryConversion.isCritical(percentage: 50))
    }

    func testIsCriticalBoundary() {
        XCTAssertTrue(BatteryConversion.isCritical(percentage: 9.9))
        XCTAssertFalse(BatteryConversion.isCritical(percentage: 10.0))
    }

    // MARK: - Formatting Tests

    func testFormatPercentage() {
        XCTAssertEqual(BatteryConversion.formatPercentage(100), "100%")
        XCTAssertEqual(BatteryConversion.formatPercentage(85), "85%")
        XCTAssertEqual(BatteryConversion.formatPercentage(50.6), "51%") // Rounds up
        XCTAssertEqual(BatteryConversion.formatPercentage(50.4), "50%") // Rounds down
        XCTAssertEqual(BatteryConversion.formatPercentage(0), "0%")
    }

    func testFormatVoltage() {
        XCTAssertEqual(BatteryConversion.formatVoltage(millivolts: 4200), "4.20V")
        XCTAssertEqual(BatteryConversion.formatVoltage(millivolts: 3850), "3.85V")
        XCTAssertEqual(BatteryConversion.formatVoltage(millivolts: 3000), "3.00V")
    }

    // MARK: - Data Parsing Tests

    func testParseAndConvertValidData() {
        // Create data with 4200mV (full charge)
        var voltage: Int32 = 4200
        let data = Data(bytes: &voltage, count: 4)

        let percentage = BatteryConversion.parseAndConvert(data: data)
        XCTAssertNotNil(percentage)
        XCTAssertEqual(percentage!, 100.0)
    }

    func testParseAndConvertMidRange() {
        var voltage: Int32 = 3800
        let data = Data(bytes: &voltage, count: 4)

        let percentage = BatteryConversion.parseAndConvert(data: data)
        XCTAssertNotNil(percentage)
        XCTAssertEqual(percentage!, 50.0, accuracy: 1.0)
    }

    func testParseAndConvertInsufficientData() {
        let shortData = Data([0x00, 0x01]) // Only 2 bytes
        XCTAssertNil(BatteryConversion.parseAndConvert(data: shortData))
    }

    func testParseAndConvertEmptyData() {
        let emptyData = Data()
        XCTAssertNil(BatteryConversion.parseAndConvert(data: emptyData))
    }

    // MARK: - Parse Complete Tests

    func testParseCompleteValidData() {
        var voltage: Int32 = 4000
        let data = Data(bytes: &voltage, count: 4)

        let result = BatteryConversion.parseComplete(data: data)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.millivolts, 4000)
        XCTAssertGreaterThan(result!.percentage, 70)
        XCTAssertEqual(result!.status, .good)
    }

    func testParseCompleteInsufficientData() {
        let shortData = Data([0x00, 0x01, 0x02]) // Only 3 bytes
        XCTAssertNil(BatteryConversion.parseComplete(data: shortData))
    }

    func testParseCompleteOutOfRangeLow() {
        var voltage: Int32 = 2000 // Below 2500mV threshold
        let data = Data(bytes: &voltage, count: 4)

        XCTAssertNil(BatteryConversion.parseComplete(data: data))
    }

    func testParseCompleteOutOfRangeHigh() {
        var voltage: Int32 = 5000 // Above 4500mV threshold
        let data = Data(bytes: &voltage, count: 4)

        XCTAssertNil(BatteryConversion.parseComplete(data: data))
    }

    func testParseCompleteBoundaryValues() {
        // Test at boundary values
        var lowVoltage: Int32 = 2500
        let lowData = Data(bytes: &lowVoltage, count: 4)
        XCTAssertNotNil(BatteryConversion.parseComplete(data: lowData))

        var highVoltage: Int32 = 4500
        let highData = Data(bytes: &highVoltage, count: 4)
        XCTAssertNotNil(BatteryConversion.parseComplete(data: highData))
    }

    func testParseCompleteAllStatuses() {
        // Test data that produces each battery status
        let testCases: [(voltage: Int32, expectedStatus: BatteryStatus)] = [
            (4200, .excellent),
            (3900, .good),
            (3700, .medium),
            (3400, .low),
            (3100, .critical)
        ]

        for testCase in testCases {
            var voltage = testCase.voltage
            let data = Data(bytes: &voltage, count: 4)
            let result = BatteryConversion.parseComplete(data: data)

            XCTAssertNotNil(result, "Failed for voltage \(testCase.voltage)")
            XCTAssertEqual(result!.status, testCase.expectedStatus,
                "Expected \(testCase.expectedStatus) for \(testCase.voltage)mV, got \(result!.status)")
        }
    }

    // MARK: - Edge Cases

    func testNegativeVoltage() {
        // Negative voltage should return 0%
        let percentage = BatteryConversion.voltageToPercentage(millivolts: -1000)
        XCTAssertEqual(percentage, 0.0)
    }

    func testZeroVoltage() {
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 0)
        XCTAssertEqual(percentage, 0.0)
    }

    func testVeryHighVoltage() {
        // Very high voltage should cap at 100%
        let percentage = BatteryConversion.voltageToPercentage(millivolts: 10000)
        XCTAssertEqual(percentage, 100.0)
    }

    // MARK: - Discharge Curve Consistency

    func testDischargeCurveCoversFullRange() {
        // Test that we get reasonable percentages across the full range
        let voltages: [Int32] = [4200, 4100, 4000, 3900, 3800, 3700, 3600, 3500, 3400, 3300, 3200, 3100, 3000]

        var previousPercentage = 100.0
        for voltage in voltages {
            let percentage = BatteryConversion.voltageToPercentage(millivolts: voltage)
            XCTAssertLessThanOrEqual(percentage, previousPercentage,
                "Percentage should decrease as voltage decreases")
            XCTAssertGreaterThanOrEqual(percentage, 0.0)
            XCTAssertLessThanOrEqual(percentage, 100.0)
            previousPercentage = percentage
        }
    }

    // MARK: - Performance Test

    func testVoltageConversionPerformance() {
        measure {
            for voltage: Int32 in stride(from: 3000, through: 4200, by: 1) {
                _ = BatteryConversion.voltageToPercentage(millivolts: voltage)
            }
        }
    }

    // MARK: - Debug Comparison Table

    #if DEBUG
    func testComparisonTableGeneration() {
        let table = BatteryConversion.generateComparisonTable()

        // Table should have entries
        XCTAssertGreaterThan(table.count, 0)

        // Each entry should have valid data
        for entry in table {
            XCTAssertGreaterThanOrEqual(entry.voltage, BatteryConversion.voltageMin)
            XCTAssertLessThanOrEqual(entry.voltage, BatteryConversion.voltageMax)
            XCTAssertGreaterThanOrEqual(entry.linear, 0)
            XCTAssertLessThanOrEqual(entry.linear, 100)
            XCTAssertGreaterThanOrEqual(entry.curve, 0)
            XCTAssertLessThanOrEqual(entry.curve, 100)
        }
    }
    #endif
}
