//
//  HistoricalDataPointTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for HistoricalDataPoint
//

import XCTest
@testable import OralableCore

final class HistoricalDataPointComprehensiveTests: XCTestCase {

    // MARK: - Creation Tests

    func testHistoricalDataPointCreation() {
        let timestamp = Date()
        let dataPoint = HistoricalDataPoint(
            timestamp: timestamp,
            averageHeartRate: 72.0,
            heartRateQuality: 0.9,
            averageSpO2: 98.0,
            spo2Quality: 0.85,
            averageTemperature: 36.8,
            averageBattery: 85,
            movementIntensity: 16384.0,
            movementVariability: 100.0,
            grindingEvents: 5,
            averagePPGIR: 150000.0,
            averagePPGRed: 120000.0,
            averagePPGGreen: 80000.0
        )

        XCTAssertNotNil(dataPoint.id)
        XCTAssertEqual(dataPoint.timestamp, timestamp)
        XCTAssertEqual(dataPoint.averageHeartRate, 72.0)
        XCTAssertEqual(dataPoint.heartRateQuality, 0.9)
        XCTAssertEqual(dataPoint.averageSpO2, 98.0)
        XCTAssertEqual(dataPoint.spo2Quality, 0.85)
        XCTAssertEqual(dataPoint.averageTemperature, 36.8)
        XCTAssertEqual(dataPoint.averageBattery, 85)
        XCTAssertEqual(dataPoint.movementIntensity, 16384.0)
        XCTAssertEqual(dataPoint.movementVariability, 100.0)
        XCTAssertEqual(dataPoint.grindingEvents, 5)
        XCTAssertEqual(dataPoint.averagePPGIR, 150000.0)
        XCTAssertEqual(dataPoint.averagePPGRed, 120000.0)
        XCTAssertEqual(dataPoint.averagePPGGreen, 80000.0)
    }

    func testHistoricalDataPointMinimalCreation() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 37.0,
            averageBattery: 50,
            movementIntensity: 16384.0
        )

        XCTAssertNil(dataPoint.averageHeartRate)
        XCTAssertNil(dataPoint.heartRateQuality)
        XCTAssertNil(dataPoint.averageSpO2)
        XCTAssertNil(dataPoint.spo2Quality)
        XCTAssertNil(dataPoint.grindingEvents)
        XCTAssertNil(dataPoint.averagePPGIR)
        XCTAssertNil(dataPoint.averagePPGRed)
        XCTAssertNil(dataPoint.averagePPGGreen)
        XCTAssertEqual(dataPoint.movementVariability, 0)
    }

    func testHistoricalDataPointCustomId() {
        let customId = UUID()
        let dataPoint = HistoricalDataPoint(
            id: customId,
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.id, customId)
    }

    // MARK: - G-Unit Conversion Tests

    func testMovementIntensityInGAtRest() {
        // At rest: magnitude ~4098 for 1g (using sensitivity2g = 0.244 mg/digit)
        // Formula: raw * 0.244 / 1000 = g
        // For 1g: raw = 1000 / 0.244 ≈ 4098
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 4098.0
        )

        // 4098 * 0.244 / 1000 ≈ 1.0g
        XCTAssertEqual(dataPoint.movementIntensityInG, 1.0, accuracy: 0.1)
    }

    func testMovementIntensityInGHighMotion() {
        // High motion: magnitude ~8196 for 2g
        // For 2g: raw = 2000 / 0.244 ≈ 8196
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 8196.0
        )

        // 8196 * 0.244 / 1000 ≈ 2.0g
        XCTAssertEqual(dataPoint.movementIntensityInG, 2.0, accuracy: 0.1)
    }

    func testMovementIntensityInGZero() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 0.0
        )

        XCTAssertEqual(dataPoint.movementIntensityInG, 0.0)
    }

    // MARK: - isAtRest Tests

    func testIsAtRestTrue() {
        // At rest: ~1g magnitude
        // Formula: raw * 0.244 / 1000 = g
        // For 1g: raw = 1000 / 0.244 ≈ 4098
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 4098.0 // ~1g
        )

        XCTAssertTrue(dataPoint.isAtRest)
    }

    func testIsAtRestFalseHighMotion() {
        // High motion: ~2g magnitude
        // For 2g: raw = 2000 / 0.244 ≈ 8196
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 8196.0 // ~2g
        )

        XCTAssertFalse(dataPoint.isAtRest)
    }

    func testIsAtRestFalseLowMagnitude() {
        // Free fall: ~0g
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 0.0 // ~0g
        )

        XCTAssertFalse(dataPoint.isAtRest)
    }

    // MARK: - Temperature Status Tests

    func testTemperatureStatusLow() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 33.0,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .low)
    }

    func testTemperatureStatusBelowNormal() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 35.0,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .belowNormal)
    }

    func testTemperatureStatusNormal() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.8,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .normal)
    }

    func testTemperatureStatusNormalLowerBound() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.0,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .normal)
    }

    func testTemperatureStatusNormalUpperBound() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 37.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .normal)
    }

    func testTemperatureStatusSlightlyElevated() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 38.0,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .slightlyElevated)
    }

    func testTemperatureStatusElevated() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 39.0,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.temperatureStatus, .elevated)
    }

    // MARK: - Battery Status Tests

    func testBatteryStatusCritical() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 5,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.batteryStatus, .critical)
    }

    func testBatteryStatusLow() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 15,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.batteryStatus, .low)
    }

    func testBatteryStatusMedium() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 35,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.batteryStatus, .medium)
    }

    func testBatteryStatusGood() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 65,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.batteryStatus, .good)
    }

    func testBatteryStatusExcellent() {
        let dataPoint = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 90,
            movementIntensity: 16384.0
        )

        XCTAssertEqual(dataPoint.batteryStatus, .excellent)
    }

    func testBatteryStatusBoundaries() {
        // Critical: 0-9
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 0, movementIntensity: 16384.0).batteryStatus, .critical)
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 9, movementIntensity: 16384.0).batteryStatus, .critical)

        // Low: 10-19
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 10, movementIntensity: 16384.0).batteryStatus, .low)
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 19, movementIntensity: 16384.0).batteryStatus, .low)

        // Medium: 20-49
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 20, movementIntensity: 16384.0).batteryStatus, .medium)
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 49, movementIntensity: 16384.0).batteryStatus, .medium)

        // Good: 50-79
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 50, movementIntensity: 16384.0).batteryStatus, .good)
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 79, movementIntensity: 16384.0).batteryStatus, .good)

        // Excellent: 80+
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 80, movementIntensity: 16384.0).batteryStatus, .excellent)
        XCTAssertEqual(HistoricalDataPoint(timestamp: Date(), averageTemperature: 36.5, averageBattery: 100, movementIntensity: 16384.0).batteryStatus, .excellent)
    }

    // MARK: - Equatable Tests

    func testEquatableSameId() {
        let id = UUID()
        let dataPoint1 = HistoricalDataPoint(
            id: id,
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )
        let dataPoint2 = HistoricalDataPoint(
            id: id,
            timestamp: Date().addingTimeInterval(100), // Different timestamp
            averageTemperature: 37.0, // Different temperature
            averageBattery: 50, // Different battery
            movementIntensity: 20000.0 // Different movement
        )

        XCTAssertEqual(dataPoint1, dataPoint2) // Same ID = equal
    }

    func testEquatableDifferentId() {
        let dataPoint1 = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )
        let dataPoint2 = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        XCTAssertNotEqual(dataPoint1, dataPoint2) // Different IDs = not equal
    }

    // MARK: - Hashable Tests

    func testHashable() {
        let id = UUID()
        let dataPoint1 = HistoricalDataPoint(
            id: id,
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )
        let dataPoint2 = HistoricalDataPoint(
            id: id,
            timestamp: Date(),
            averageTemperature: 37.0,
            averageBattery: 50,
            movementIntensity: 16384.0
        )

        var set = Set<HistoricalDataPoint>()
        set.insert(dataPoint1)
        set.insert(dataPoint2)

        XCTAssertEqual(set.count, 1) // Same ID = same hash
    }

    func testHashableDifferentIds() {
        let dataPoint1 = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )
        let dataPoint2 = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        var set = Set<HistoricalDataPoint>()
        set.insert(dataPoint1)
        set.insert(dataPoint2)

        XCTAssertEqual(set.count, 2) // Different IDs = different hashes
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        let original = HistoricalDataPoint(
            timestamp: Date(),
            averageHeartRate: 72.0,
            heartRateQuality: 0.9,
            averageSpO2: 98.0,
            spo2Quality: 0.85,
            averageTemperature: 36.8,
            averageBattery: 85,
            movementIntensity: 16384.0,
            movementVariability: 100.0,
            grindingEvents: 3,
            averagePPGIR: 150000.0,
            averagePPGRed: 120000.0,
            averagePPGGreen: 80000.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HistoricalDataPoint.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.averageHeartRate, original.averageHeartRate)
        XCTAssertEqual(decoded.heartRateQuality, original.heartRateQuality)
        XCTAssertEqual(decoded.averageSpO2, original.averageSpO2)
        XCTAssertEqual(decoded.spo2Quality, original.spo2Quality)
        XCTAssertEqual(decoded.averageTemperature, original.averageTemperature)
        XCTAssertEqual(decoded.averageBattery, original.averageBattery)
        XCTAssertEqual(decoded.movementIntensity, original.movementIntensity)
        XCTAssertEqual(decoded.movementVariability, original.movementVariability)
        XCTAssertEqual(decoded.grindingEvents, original.grindingEvents)
        XCTAssertEqual(decoded.averagePPGIR, original.averagePPGIR)
        XCTAssertEqual(decoded.averagePPGRed, original.averagePPGRed)
        XCTAssertEqual(decoded.averagePPGGreen, original.averagePPGGreen)
    }

    func testCodableWithNilValues() throws {
        let original = HistoricalDataPoint(
            timestamp: Date(),
            averageTemperature: 36.5,
            averageBattery: 80,
            movementIntensity: 16384.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HistoricalDataPoint.self, from: data)

        XCTAssertNil(decoded.averageHeartRate)
        XCTAssertNil(decoded.averageSpO2)
        XCTAssertNil(decoded.grindingEvents)
        XCTAssertNil(decoded.averagePPGIR)
    }
}
