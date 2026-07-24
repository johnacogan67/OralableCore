//
//  BatteryConversionTests.swift
//  OralableCoreTests
//
//  Remapped Oralable gauge (FW >= 1.0.68): 3610 mV = 0%, 4350 mV = 100%
//

import XCTest
@testable import OralableCore

final class BatteryConversionTests: XCTestCase {

    // MARK: - Voltage Constants Tests

    func testVoltageConstants() {
        XCTAssertEqual(BatteryConversion.voltageMax, 4350)
        XCTAssertEqual(BatteryConversion.voltageMin, 3610)
        XCTAssertEqual(BatteryConversion.voltageLowWarning, 3720)
        XCTAssertEqual(BatteryConversion.voltageCritical, 3610)
    }

    func testVoltageConstantsRelationship() {
        XCTAssertGreaterThan(BatteryConversion.voltageMax, BatteryConversion.voltageLowWarning)
        XCTAssertGreaterThanOrEqual(BatteryConversion.voltageLowWarning, BatteryConversion.voltageCritical)
        XCTAssertGreaterThanOrEqual(BatteryConversion.voltageCritical, BatteryConversion.voltageMin)
    }

    // MARK: - Voltage to Percentage Conversion Tests

    func testVoltageToPercentageFullCharge() {
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 4350), 100.0)
    }

    func testVoltageToPercentageAboveMax() {
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 4500), 100.0)
    }

    func testVoltageToPercentageEmpty() {
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3610), 0.0)
    }

    func testVoltageToPercentageBelowMin() {
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3000), 0.0)
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 2500), 0.0)
    }

    func testVoltageToPercentageMidRange() {
        // (3980 - 3610) * 100 / 740 = 50
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3980), 50.0, accuracy: 0.5)
        // (3980 + half range toward max roughly) — 75%: 3610 + 0.75*740 = 4165
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 4165), 75.0, accuracy: 0.5)
        // Soft floor
        XCTAssertEqual(BatteryConversion.voltageToPercentage(millivolts: 3610), 0.0, accuracy: 0.1)
    }

    func testVoltageToPercentageMonotonicity() {
        var previousPercentage = 0.0
        for voltage: Int32 in stride(from: 3610, through: 4350, by: 50) {
            let percentage = BatteryConversion.voltageToPercentage(millivolts: voltage)
            XCTAssertGreaterThanOrEqual(percentage, previousPercentage,
                "Voltage \(voltage)mV should have >= percentage than lower voltages")
            previousPercentage = percentage
        }
    }

    // MARK: - Integer Percentage Tests

    func testVoltageToPercentageInt() {
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 4350), 100)
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 3610), 0)
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 3980), 50)
    }

    // MARK: - Linear Percentage Tests

    func testLinearPercentageFullCharge() {
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 4350), 100.0)
    }

    func testLinearPercentageEmpty() {
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 3610), 0.0)
    }

    func testLinearPercentageMidRange() {
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 3980), 50.0, accuracy: 0.1)
    }

    func testLinearPercentageClamping() {
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 5000), 100.0)
        XCTAssertEqual(BatteryConversion.linearPercentage(millivolts: 2000), 0.0)
    }

    func testVoltageToPercentageMatchesLinear() {
        for voltage: Int32 in stride(from: 3610, through: 4350, by: 100) {
            let curve = BatteryConversion.voltageToPercentage(millivolts: voltage)
            let linear = BatteryConversion.linearPercentage(millivolts: voltage)
            XCTAssertEqual(curve, linear, accuracy: 0.01)
        }
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
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 4350), .excellent)
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 4165), .good)
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3980), .good)
        // ~12%: 3610 + 0.12*740 ≈ 3700
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3700), .low)
        XCTAssertEqual(BatteryConversion.batteryStatus(millivolts: 3610), .critical)
    }

    func testNeedsCharging() {
        XCTAssertTrue(BatteryConversion.needsCharging(percentage: 19))
        XCTAssertFalse(BatteryConversion.needsCharging(percentage: 20))
    }

    func testIsCritical() {
        XCTAssertTrue(BatteryConversion.isCritical(percentage: 9))
        XCTAssertFalse(BatteryConversion.isCritical(percentage: 10))
    }

    func testFormatVoltage() {
        XCTAssertEqual(BatteryConversion.formatVoltage(millivolts: 4350), "4.35V")
        XCTAssertEqual(BatteryConversion.formatVoltage(millivolts: 3610), "3.61V")
    }

    func testFormatPercentage() {
        XCTAssertEqual(BatteryConversion.formatPercentage(85), "85%")
    }

    func testChemistryPercentage() {
        XCTAssertEqual(BatteryConversion.chemistryPercentageInt(millivolts: 3000), 0)
        XCTAssertEqual(BatteryConversion.chemistryPercentageInt(millivolts: 4350), 100)
        // Mid chemistry: (3675 - 3000) * 100 / 1350 = 50
        XCTAssertEqual(BatteryConversion.chemistryPercentageInt(millivolts: 3675), 50)
        // Soft-floor voltage still has chemistry headroom: (3610-3000)*100/1350 ≈ 45
        XCTAssertEqual(BatteryConversion.chemistryPercentageInt(millivolts: 3610), 45)
        XCTAssertEqual(BatteryConversion.voltageToPercentageInt(millivolts: 3610), 0)
    }
}
