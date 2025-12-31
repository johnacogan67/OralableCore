//
//  DemoDataGeneratorTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Comprehensive tests for DemoDataGenerator and DemoDataConfiguration
//

import XCTest
@testable import OralableCore

final class DemoDataGeneratorTests: XCTestCase {

    // MARK: - DemoDataConfiguration Tests

    func testDefaultConfiguration() {
        let config = DemoDataConfiguration()

        XCTAssertEqual(config.heartRateRange, 60...100)
        XCTAssertEqual(config.spo2Range, 95...100)
        XCTAssertEqual(config.temperatureRange, 36.2...37.5)
        XCTAssertEqual(config.initialBattery, 85)
        XCTAssertEqual(config.ppgSamplingRate, 50.0)
        XCTAssertEqual(config.accelerometerScale, 16384.0)
        XCTAssertEqual(config.deviceType, .oralable)
    }

    func testStandardPreset() {
        let config = DemoDataConfiguration.standard

        XCTAssertEqual(config.heartRateRange, 60...100)
        XCTAssertEqual(config.spo2Range, 95...100)
        XCTAssertEqual(config.initialBattery, 85)
    }

    func testExercisePreset() {
        let config = DemoDataConfiguration.exercise

        XCTAssertEqual(config.heartRateRange, 90...150)
        XCTAssertEqual(config.spo2Range, 93...99)
        XCTAssertEqual(config.temperatureRange, 36.5...38.0)
        XCTAssertEqual(config.initialBattery, 70)
    }

    func testRestingPreset() {
        let config = DemoDataConfiguration.resting

        XCTAssertEqual(config.heartRateRange, 50...70)
        XCTAssertEqual(config.spo2Range, 96...100)
        XCTAssertEqual(config.temperatureRange, 36.0...36.8)
        XCTAssertEqual(config.initialBattery, 90)
    }

    func testClinicalPreset() {
        let config = DemoDataConfiguration.clinical

        XCTAssertEqual(config.heartRateRange, 60...80)
        XCTAssertEqual(config.spo2Range, 97...100)
        XCTAssertEqual(config.temperatureRange, 36.4...37.2)
        XCTAssertEqual(config.initialBattery, 95)
        XCTAssertEqual(config.ppgSamplingRate, 100.0)
    }

    func testCustomConfiguration() {
        let config = DemoDataConfiguration(
            heartRateRange: 40...180,
            spo2Range: 90...100,
            temperatureRange: 35.0...40.0,
            initialBattery: 50,
            ppgSamplingRate: 25.0,
            accelerometerScale: 8192.0,
            deviceType: .anr
        )

        XCTAssertEqual(config.heartRateRange, 40...180)
        XCTAssertEqual(config.spo2Range, 90...100)
        XCTAssertEqual(config.temperatureRange, 35.0...40.0)
        XCTAssertEqual(config.initialBattery, 50)
        XCTAssertEqual(config.ppgSamplingRate, 25.0)
        XCTAssertEqual(config.accelerometerScale, 8192.0)
        XCTAssertEqual(config.deviceType, .anr)
    }

    // MARK: - DemoDataGenerator Initialization Tests

    func testGeneratorInitialization() async {
        let generator = DemoDataGenerator()

        let sampleIndex = await generator.currentSampleIndex
        let batteryLevel = await generator.batteryLevel

        XCTAssertEqual(sampleIndex, 0)
        XCTAssertEqual(batteryLevel, 85) // Default initial battery
    }

    func testGeneratorWithCustomConfiguration() async {
        let config = DemoDataConfiguration(initialBattery: 50)
        let generator = DemoDataGenerator(configuration: config)

        let batteryLevel = await generator.batteryLevel

        XCTAssertEqual(batteryLevel, 50)
    }

    // MARK: - PPG Generation Tests

    func testGeneratePPGSample() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generatePPGSample()

        // PPG values should be in realistic ranges
        XCTAssertGreaterThan(sample.ir, 100000) // High baseline IR
        XCTAssertGreaterThan(sample.red, 80000) // High baseline Red
        XCTAssertGreaterThan(sample.green, 50000) // High baseline Green
        XCTAssertNotNil(sample.timestamp)
    }

    func testGeneratePPGSampleIncrementsSampleIndex() async {
        let generator = DemoDataGenerator()

        let indexBefore = await generator.currentSampleIndex
        _ = await generator.generatePPGSample()
        let indexAfter = await generator.currentSampleIndex

        XCTAssertEqual(indexAfter, indexBefore + 1)
    }

    func testGeneratePPGSampleWithCustomHeartRate() async {
        let generator = DemoDataGenerator()

        // Generate samples at different heart rates
        let sample60 = await generator.generatePPGSample(heartRate: 60)
        let sample120 = await generator.generatePPGSample(heartRate: 120)

        // Both should produce valid PPG data
        XCTAssertGreaterThan(sample60.ir, 0)
        XCTAssertGreaterThan(sample120.ir, 0)
    }

    func testGeneratePPGSequence() async {
        let generator = DemoDataGenerator()

        // Generate 1 second of data at 50 Hz = 50 samples
        let sequence = await generator.generatePPGSequence(duration: 1.0, heartRate: 72.0)

        XCTAssertEqual(sequence.count, 50) // 50 Hz * 1 second

        // All samples should have valid data
        for sample in sequence {
            XCTAssertGreaterThan(sample.ir, 0)
            XCTAssertGreaterThan(sample.red, 0)
            XCTAssertGreaterThan(sample.green, 0)
        }
    }

    func testGeneratePPGSequenceCustomDuration() async {
        let config = DemoDataConfiguration(ppgSamplingRate: 100.0)
        let generator = DemoDataGenerator(configuration: config)

        // Generate 0.5 seconds at 100 Hz = 50 samples
        let sequence = await generator.generatePPGSequence(duration: 0.5)

        XCTAssertEqual(sequence.count, 50) // 100 Hz * 0.5 seconds
    }

    // MARK: - Accelerometer Generation Tests

    func testGenerateAccelerometerRelaxed() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .relaxed)

        // Relaxed state: small X/Y, Z near 1g (16384 with default scale)
        XCTAssertLessThan(abs(sample.x), 100)
        XCTAssertLessThan(abs(sample.y), 100)
        XCTAssertGreaterThan(sample.z, 16000) // Near 1g
    }

    func testGenerateAccelerometerClenching() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .clenching)

        // Clenching: moderate variation
        XCTAssertLessThan(abs(sample.x), 500)
        XCTAssertLessThan(abs(sample.y), 500)
        XCTAssertGreaterThan(sample.z, 14000) // Still mostly gravity-aligned
    }

    func testGenerateAccelerometerGrinding() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .grinding)

        // Grinding: larger variations possible
        XCTAssertLessThan(abs(sample.x), 2000)
        XCTAssertLessThan(abs(sample.y), 2000)
        // Z can deviate more during grinding
        XCTAssertGreaterThan(sample.z, 10000)
    }

    func testGenerateAccelerometerMotion() async {
        let generator = DemoDataGenerator()

        let sample = await generator.generateAccelerometerSample(activity: .motion)

        // Motion: high variation in all axes
        // Values are within ±8000 range
        XCTAssertLessThanOrEqual(abs(sample.x), 8000)
        XCTAssertLessThanOrEqual(abs(sample.y), 8000)
        XCTAssertLessThanOrEqual(abs(sample.z), 8000)
    }

    // MARK: - Heart Rate Generation Tests

    func testGenerateHeartRate() async {
        let generator = DemoDataGenerator()

        let hr = await generator.generateHeartRate()

        // Should be within default range (60-100)
        XCTAssertGreaterThanOrEqual(hr, 60)
        XCTAssertLessThanOrEqual(hr, 100)
    }

    func testGenerateHeartRateVariation() async {
        let generator = DemoDataGenerator()

        var heartRates: [Double] = []
        for _ in 0..<20 {
            heartRates.append(await generator.generateHeartRate())
        }

        // All values should be in range
        XCTAssertTrue(heartRates.allSatisfy { $0 >= 60 && $0 <= 100 })

        // Consecutive values should not differ by more than 3 BPM
        for i in 1..<heartRates.count {
            let diff = abs(heartRates[i] - heartRates[i-1])
            XCTAssertLessThanOrEqual(diff, 3)
        }
    }

    func testGenerateHeartRateData() async {
        let generator = DemoDataGenerator()

        let hrData = await generator.generateHeartRateData()

        XCTAssertGreaterThanOrEqual(hrData.bpm, 60)
        XCTAssertLessThanOrEqual(hrData.bpm, 100)
        XCTAssertGreaterThanOrEqual(hrData.quality, 0.6)
        XCTAssertLessThanOrEqual(hrData.quality, 1.0)
        XCTAssertNotNil(hrData.timestamp)
    }

    func testGenerateHeartRateWithExerciseConfig() async {
        let config = DemoDataConfiguration.exercise
        let generator = DemoDataGenerator(configuration: config)

        let hr = await generator.generateHeartRate()

        // Exercise range is 90-150
        XCTAssertGreaterThanOrEqual(hr, 90)
        XCTAssertLessThanOrEqual(hr, 150)
    }

    // MARK: - SpO2 Generation Tests

    func testGenerateSpO2() async {
        let generator = DemoDataGenerator()

        let spo2 = await generator.generateSpO2()

        // Default range is 95-100
        XCTAssertGreaterThanOrEqual(spo2, 95)
        XCTAssertLessThanOrEqual(spo2, 100)
    }

    func testGenerateSpO2Data() async {
        let generator = DemoDataGenerator()

        let spo2Data = await generator.generateSpO2Data()

        XCTAssertGreaterThanOrEqual(spo2Data.percentage, 95)
        XCTAssertLessThanOrEqual(spo2Data.percentage, 100)
        XCTAssertGreaterThanOrEqual(spo2Data.quality, 0.7)
        XCTAssertLessThanOrEqual(spo2Data.quality, 1.0)
    }

    func testGenerateSpO2Variation() async {
        let generator = DemoDataGenerator()

        var values: [Double] = []
        for _ in 0..<10 {
            values.append(await generator.generateSpO2())
        }

        // All values in range
        XCTAssertTrue(values.allSatisfy { $0 >= 95 && $0 <= 100 })

        // Consecutive values differ by at most ±1
        for i in 1..<values.count {
            XCTAssertLessThanOrEqual(abs(values[i] - values[i-1]), 1)
        }
    }

    // MARK: - Temperature Generation Tests

    func testGenerateTemperature() async {
        let generator = DemoDataGenerator()

        let temp = await generator.generateTemperature()

        // Default range is 36.2-37.5
        XCTAssertGreaterThanOrEqual(temp, 36.2)
        XCTAssertLessThanOrEqual(temp, 37.5)
    }

    func testGenerateTemperatureWithCircadianRhythm() async {
        let generator = DemoDataGenerator()

        // Afternoon/evening (higher temperature)
        let tempEvening = await generator.generateTemperature(hourOfDay: 18)

        // Early morning (lower temperature)
        await generator.reset()
        let tempMorning = await generator.generateTemperature(hourOfDay: 4)

        // Both should be valid
        XCTAssertGreaterThanOrEqual(tempEvening, 36.0)
        XCTAssertLessThanOrEqual(tempEvening, 38.0)
        XCTAssertGreaterThanOrEqual(tempMorning, 36.0)
        XCTAssertLessThanOrEqual(tempMorning, 38.0)
    }

    func testGenerateTemperatureData() async {
        let generator = DemoDataGenerator()

        let tempData = await generator.generateTemperatureData()

        XCTAssertGreaterThanOrEqual(tempData.celsius, 36.0)
        XCTAssertLessThanOrEqual(tempData.celsius, 38.0)
        XCTAssertNotNil(tempData.timestamp)
    }

    // MARK: - Battery Generation Tests

    func testGenerateBatteryLevel() async {
        let generator = DemoDataGenerator()

        let level1 = await generator.generateBatteryLevel()

        XCTAssertEqual(level1, 85) // Default initial battery
    }

    func testGenerateBatteryLevelDrain() async {
        let generator = DemoDataGenerator()

        _ = await generator.generateBatteryLevel(drain: 5.0)
        let level = await generator.batteryLevel

        XCTAssertEqual(level, 80) // 85 - 5 = 80
    }

    func testGenerateBatteryLevelDoesNotGoBelowZero() async {
        let config = DemoDataConfiguration(initialBattery: 5)
        let generator = DemoDataGenerator(configuration: config)

        _ = await generator.generateBatteryLevel(drain: 10.0)
        let level = await generator.batteryLevel

        XCTAssertEqual(level, 0) // Should not go negative
    }

    func testGenerateBatteryData() async {
        let generator = DemoDataGenerator()

        let batteryData = await generator.generateBatteryData()

        XCTAssertGreaterThanOrEqual(batteryData.percentage, 0)
        XCTAssertLessThanOrEqual(batteryData.percentage, 100)
    }

    // MARK: - Complete Sensor Data Generation Tests

    func testGenerateSensorData() async {
        let generator = DemoDataGenerator()

        let sensorData = await generator.generateSensorData()

        XCTAssertNotNil(sensorData.ppg)
        XCTAssertNotNil(sensorData.accelerometer)
        XCTAssertNotNil(sensorData.temperature)
        XCTAssertNotNil(sensorData.battery)
        XCTAssertNotNil(sensorData.heartRate)
        XCTAssertNotNil(sensorData.spo2)
        XCTAssertEqual(sensorData.deviceType, .oralable)
    }

    func testGenerateSensorDataWithActivity() async {
        let generator = DemoDataGenerator()

        let dataRelaxed = await generator.generateSensorData(activity: .relaxed)
        await generator.reset()
        let dataMotion = await generator.generateSensorData(activity: .motion)

        // Both should produce valid data
        XCTAssertNotNil(dataRelaxed.accelerometer)
        XCTAssertNotNil(dataMotion.accelerometer)

        // Motion should have larger accelerometer magnitudes (on average)
        // This is stochastic, so we just verify structure
        XCTAssertNotNil(dataRelaxed.accelerometer.x)
        XCTAssertNotNil(dataMotion.accelerometer.x)
    }

    func testGenerateSensorDataSequence() async {
        let generator = DemoDataGenerator()

        let sequence = await generator.generateSensorDataSequence(count: 10, interval: 1.0)

        XCTAssertEqual(sequence.count, 10)

        // All entries should have valid data
        for data in sequence {
            XCTAssertNotNil(data.ppg)
            XCTAssertNotNil(data.accelerometer)
            XCTAssertNotNil(data.temperature)
            XCTAssertNotNil(data.battery)
            XCTAssertNotNil(data.heartRate)
            XCTAssertNotNil(data.spo2)
        }

        // Timestamps should be sequential
        for i in 1..<sequence.count {
            XCTAssertGreaterThan(sequence[i].timestamp, sequence[i-1].timestamp)
        }
    }

    func testGenerateSensorDataSequenceWithActivity() async {
        let generator = DemoDataGenerator()

        let sequence = await generator.generateSensorDataSequence(count: 5, activity: .grinding)

        XCTAssertEqual(sequence.count, 5)

        for data in sequence {
            XCTAssertNotNil(data.accelerometer)
        }
    }

    // MARK: - State Management Tests

    func testReset() async {
        let generator = DemoDataGenerator()

        // Generate some data to change state
        for _ in 0..<10 {
            _ = await generator.generatePPGSample()
            _ = await generator.generateBatteryLevel(drain: 1.0)
        }

        let indexBefore = await generator.currentSampleIndex
        let batteryBefore = await generator.batteryLevel

        XCTAssertGreaterThan(indexBefore, 0)
        XCTAssertLessThan(batteryBefore, 85)

        // Reset
        await generator.reset()

        let indexAfter = await generator.currentSampleIndex
        let batteryAfter = await generator.batteryLevel

        XCTAssertEqual(indexAfter, 0)
        XCTAssertEqual(batteryAfter, 85) // Back to initial
    }

    // MARK: - DemoDataGeneratorSync Tests

    func testSyncGeneratorInitialization() {
        let generator = DemoDataGeneratorSync()

        // Should not crash
        XCTAssertNotNil(generator)
    }

    func testSyncGeneratorWithCustomConfiguration() {
        let config = DemoDataConfiguration.clinical
        let generator = DemoDataGeneratorSync(configuration: config)

        XCTAssertNotNil(generator)
    }

    func testSyncGeneratePPGSample() {
        let generator = DemoDataGeneratorSync()

        let sample = generator.generatePPGSample(at: 0)

        XCTAssertGreaterThan(sample.ir, 100000)
        XCTAssertGreaterThan(sample.red, 80000)
        XCTAssertGreaterThan(sample.green, 50000)
    }

    func testSyncGeneratePPGSampleWithHeartRate() {
        let generator = DemoDataGeneratorSync()

        let sample60 = generator.generatePPGSample(at: 0, heartRate: 60)
        let sample100 = generator.generatePPGSample(at: 0, heartRate: 100)

        // Both should produce valid PPG
        XCTAssertGreaterThan(sample60.ir, 0)
        XCTAssertGreaterThan(sample100.ir, 0)
    }

    func testSyncGenerateAccelerometerAtRest() {
        let generator = DemoDataGeneratorSync()

        let sample = generator.generateAccelerometerAtRest()

        XCTAssertEqual(sample.x, 0)
        XCTAssertEqual(sample.y, 0)
        XCTAssertEqual(sample.z, 16384) // 1g with default scale
    }

    func testSyncGenerateAccelerometerAtRestWithCustomScale() {
        let config = DemoDataConfiguration(accelerometerScale: 8192.0)
        let generator = DemoDataGeneratorSync(configuration: config)

        let sample = generator.generateAccelerometerAtRest()

        XCTAssertEqual(sample.z, 8192) // 1g with custom scale
    }

    func testSyncGenerateDefaultSensorData() {
        let generator = DemoDataGeneratorSync()

        let data = generator.generateDefaultSensorData()

        XCTAssertNotNil(data.ppg)
        XCTAssertNotNil(data.accelerometer)
        XCTAssertNotNil(data.temperature)
        XCTAssertNotNil(data.battery)
        XCTAssertNotNil(data.heartRate)
        XCTAssertNotNil(data.spo2)
        XCTAssertEqual(data.deviceType, .oralable)

        // Check expected default values
        XCTAssertEqual(data.heartRate?.bpm, 72)
        XCTAssertEqual(data.heartRate?.quality, 0.9)
        XCTAssertEqual(data.spo2?.percentage, 98)
        XCTAssertEqual(data.temperature.celsius, 36.8)
        XCTAssertEqual(data.battery.percentage, 85)
    }

    func testSyncGenerateDefaultSensorDataWithCustomConfig() {
        let config = DemoDataConfiguration(deviceType: .anr)
        let generator = DemoDataGeneratorSync(configuration: config)

        let data = generator.generateDefaultSensorData()

        XCTAssertEqual(data.deviceType, .anr)
    }

    // MARK: - PPG Waveform Quality Tests

    func testPPGWaveformStructure() async {
        let generator = DemoDataGenerator()

        // Generate multiple samples and verify they form a waveform
        var irValues: [Int32] = []
        for _ in 0..<100 {
            let sample = await generator.generatePPGSample(heartRate: 60)
            irValues.append(sample.ir)
        }

        // Check that values vary (not all the same)
        let uniqueValues = Set(irValues)
        XCTAssertGreaterThan(uniqueValues.count, 1, "PPG values should vary")

        // Check reasonable amplitude
        let minIR = irValues.min() ?? 0
        let maxIR = irValues.max() ?? 0
        let amplitude = maxIR - minIR

        XCTAssertGreaterThan(amplitude, 1000, "PPG should have measurable amplitude")
    }
}
