//
//  IntegrationTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  End-to-end integration tests for the OralableCore processing pipeline
//  Tests the full flow from raw data to biometric results
//

import XCTest
@testable import OralableCore

// MARK: - End-to-End Pipeline Tests

final class IntegrationTests: XCTestCase {

    // MARK: - Demo Data → BiometricProcessor Pipeline

    func testDemoDataToBiometricProcessor() async {
        // Create demo data generator
        let generator = DemoDataGenerator(configuration: .standard)
        let processor = BiometricProcessor(config: .demo)

        // Generate demo sensor data sequence
        let sensorData = await generator.generateSensorDataSequence(count: 100, interval: 0.02)

        // Process each sample
        var lastResult: BiometricResult = .empty

        for data in sensorData {
            lastResult = await processor.process(
                ir: Double(data.ppg.ir),
                red: Double(data.ppg.red),
                green: Double(data.ppg.green),
                accelX: Double(data.accelerometer.x),
                accelY: Double(data.accelerometer.y),
                accelZ: Double(data.accelerometer.z)
            )
        }

        // After 100 samples at 50Hz (~2 seconds), we should have some processing done
        // The demo config uses smaller windows for faster testing
        XCTAssertNotNil(lastResult)
        XCTAssertEqual(lastResult.processingMethod, .realtime)
    }

    func testDemoDataBatchProcessing() async {
        // Create demo data generator
        let generator = DemoDataGenerator(configuration: .standard)
        let processor = BiometricProcessor(config: .demo)

        // Generate PPG sequence
        let ppgSequence = await generator.generatePPGSequence(duration: 3.0, heartRate: 72.0)

        // Convert to arrays
        let irSamples = ppgSequence.map { Double($0.ir) }
        let redSamples = ppgSequence.map { Double($0.red) }
        let greenSamples = ppgSequence.map { Double($0.green) }

        // Generate accelerometer data (at rest)
        let accelX = Array(repeating: 0.0, count: irSamples.count)
        let accelY = Array(repeating: 0.0, count: irSamples.count)
        let accelZ = Array(repeating: 16384.0, count: irSamples.count)

        // Batch process
        let result = await processor.processBatch(
            irSamples: irSamples,
            redSamples: redSamples,
            greenSamples: greenSamples,
            accelX: accelX,
            accelY: accelY,
            accelZ: accelZ
        )

        XCTAssertEqual(result.processingMethod, .batch)
    }

    // MARK: - BLE Data Parser → Signal Processing Pipeline

    func testBLEParserToHeartRateService() async {
        // Create raw PPG data packet (simulate BLE data)
        var rawData = Data()

        // Generate 20 PPG samples (typical packet size)
        for i in 0..<20 {
            // Create pulse waveform with 72 BPM (~60ms period at 50Hz = 3 samples per beat)
            let angle = Double(i) * 2.0 * .pi / 3.0  // ~3 samples per cardiac cycle
            let pulse = sin(angle)

            var red: UInt32 = UInt32(120000.0 + 2500.0 * pulse)
            var ir: UInt32 = UInt32(150000.0 + 3000.0 * pulse)
            var green: UInt32 = UInt32(80000.0 + 2000.0 * pulse)

            rawData.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
            rawData.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
            rawData.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })
        }

        // Parse BLE data
        let ppgReadings = BLEDataParser.parsePPGData(rawData)
        XCTAssertNotNil(ppgReadings)
        XCTAssertEqual(ppgReadings?.count, 20)

        // Process with HeartRateService
        let hrService = HeartRateService.demo()

        // Feed data multiple times to fill buffer
        for _ in 0..<10 {
            if let readings = ppgReadings {
                let greenValues = readings.map { Double($0.green) }
                _ = await hrService.process(samples: greenValues)
            }
        }

        // Check buffer fill level
        let fillLevel = await hrService.bufferFillLevel
        XCTAssertGreaterThan(fillLevel, 0)
    }

    func testBLEParserToSpO2Service() async {
        // Create raw PPG data packet
        var rawData = Data()

        // Generate 150 PPG samples (3 seconds at 50Hz)
        for i in 0..<150 {
            let angle = Double(i) * 2.0 * .pi / 42.0  // ~72 BPM

            // Red and IR with different AC amplitudes (for R ratio)
            var red: UInt32 = UInt32(120000.0 + 2500.0 * sin(angle))
            var ir: UInt32 = UInt32(150000.0 + 3000.0 * sin(angle))
            var green: UInt32 = UInt32(80000.0 + 2000.0 * sin(angle))

            rawData.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
            rawData.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
            rawData.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })
        }

        // Parse BLE data
        let ppgReadings = BLEDataParser.parsePPGData(rawData)
        XCTAssertNotNil(ppgReadings)
        XCTAssertEqual(ppgReadings?.count, 150)

        // Process with SpO2Service
        let spo2Service = SpO2Service.demo()

        if let readings = ppgReadings {
            let redValues = readings.map { Double($0.red) }
            let irValues = readings.map { Double($0.ir) }

            let result = await spo2Service.process(redSamples: redValues, irSamples: irValues)

            // Demo mode has low quality threshold
            XCTAssertTrue(result.rRatio >= 0)
        }
    }

    // MARK: - PPG Normalization → Signal Processing Pipeline

    func testNormalizationToHeartRateService() async {
        // Create PPG normalization service
        let normalizer = PPGNormalizationService.oralable()
        let hrService = HeartRateService.demo()

        // Create synthetic PPG data with DC baseline and AC pulse
        let sampleRate = 50.0
        let durationSeconds = 3.0
        let sampleCount = Int(sampleRate * durationSeconds)

        var ppgData: [(timestamp: Date, ir: Double, red: Double, green: Double)] = []

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let angle = 2.0 * .pi * 1.2 * t  // 72 BPM

            // DC baseline + AC pulse
            let ir = 150000.0 + 3000.0 * sin(angle)
            let red = 120000.0 + 2500.0 * sin(angle)
            let green = 80000.0 + 2000.0 * sin(angle)

            ppgData.append((Date(), ir, red, green))
        }

        // Normalize the PPG data
        let normalized = await normalizer.normalizePPGData(ppgData, method: .adaptiveBaseline)

        XCTAssertEqual(normalized.count, sampleCount)

        // Extract green channel and process with HeartRateService
        let greenAC = normalized.map { $0.green }
        _ = await hrService.process(samples: greenAC)

        let fillLevel = await hrService.bufferFillLevel
        XCTAssertEqual(fillLevel, 1.0, accuracy: 0.01)  // Buffer should be full
    }

    // MARK: - Buffer Integration Tests

    func testSensorDataBufferWithDemoGenerator() async {
        let generator = DemoDataGenerator(configuration: .standard)
        let buffer = SensorDataBuffer(maxCapacity: 100)

        // Generate and buffer sensor data
        for _ in 0..<50 {
            let data = await generator.generateSensorData()
            await buffer.append(data)
        }

        let count = await buffer.count
        XCTAssertEqual(count, 50)

        // Test time-based retrieval
        let allData = await buffer.allData
        XCTAssertEqual(allData.count, 50)

        // Test statistics
        let hrStats = await buffer.statistics(for: .heartRate, duration: 60)
        XCTAssertNotNil(hrStats)
        XCTAssertGreaterThan(hrStats?.sampleCount ?? 0, 0)
    }

    func testPPGBufferWithDemoGenerator() async {
        let generator = DemoDataGenerator(configuration: .standard)
        let ppgBuffer = PPGDataBuffer(maxCapacity: 500)

        // Generate PPG sequence
        let ppgSequence = await generator.generatePPGSequence(duration: 2.0, heartRate: 72.0)
        await ppgBuffer.append(contentsOf: ppgSequence)

        let count = await ppgBuffer.count
        XCTAssertEqual(count, ppgSequence.count)

        // Get channel values
        let irValues = await ppgBuffer.irValues
        XCTAssertEqual(irValues.count, ppgSequence.count)

        // Values should be in expected range
        for ir in irValues {
            XCTAssertGreaterThan(ir, 100000)
            XCTAssertLessThan(ir, 200000)
        }
    }

    // MARK: - Activity Detection Integration

    func testActivityDetectionIntegration() async {
        let generator = DemoDataGenerator(configuration: .standard)
        let processor = BiometricProcessor(config: .demo)

        // Generate relaxed state data
        for _ in 0..<60 {
            let data = await generator.generateSensorData(activity: .relaxed)
            _ = await processor.process(
                ir: Double(data.ppg.ir),
                red: Double(data.ppg.red),
                green: Double(data.ppg.green),
                accelX: Double(data.accelerometer.x),
                accelY: Double(data.accelerometer.y),
                accelZ: Double(data.accelerometer.z)
            )
        }

        // The last result should indicate relaxed activity
        let result = await processor.process(
            ir: 150000,
            red: 120000,
            green: 80000,
            accelX: 0,
            accelY: 0,
            accelZ: 16384
        )

        // With stationary accelerometer, should not be motion
        XCTAssertNotEqual(result.activity, .motion)
    }

    func testMotionDetectionIntegration() async {
        let generator = DemoDataGenerator(configuration: .standard)
        let processor = BiometricProcessor(config: .demo)

        // Generate motion state data
        for _ in 0..<30 {
            let data = await generator.generateSensorData(activity: .motion)
            _ = await processor.process(
                ir: Double(data.ppg.ir),
                red: Double(data.ppg.red),
                green: Double(data.ppg.green),
                accelX: Double(data.accelerometer.x),
                accelY: Double(data.accelerometer.y),
                accelZ: Double(data.accelerometer.z)
            )
        }

        // Motion data should have elevated motion level
        let result = await processor.process(
            ir: 150000,
            red: 120000,
            green: 80000,
            accelX: 10000,
            accelY: 10000,
            accelZ: 10000
        )

        // Motion level > 0 indicates some motion was detected
        XCTAssertGreaterThan(result.motionLevel, 0)
    }

    // MARK: - CSV Export Integration

    func testSensorDataToCSVExport() async throws {
        let generator = DemoDataGenerator(configuration: .standard)

        // Generate sensor data
        let sensorData = await generator.generateSensorDataSequence(count: 10, interval: 1.0)

        // Export sensor data directly to CSV
        let exporter = CSVExporter()
        let csvString = exporter.generateCSV(from: sensorData)

        XCTAssertFalse(csvString.isEmpty)
        XCTAssertTrue(csvString.contains("Timestamp"))
        XCTAssertTrue(csvString.contains("PPG_IR"))

        // Should have header + 10 data rows
        let lines = csvString.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 11)  // 1 header + 10 data
    }

    func testHistoricalDataToCSVExport() async throws {
        let generator = DemoDataGenerator(configuration: .standard)

        // Generate sensor data
        let sensorData = await generator.generateSensorDataSequence(count: 10, interval: 1.0)

        // Convert to HistoricalDataPoint
        let historicalData = sensorData.map { data -> HistoricalDataPoint in
            HistoricalDataPoint(
                timestamp: data.timestamp,
                averageHeartRate: data.heartRate?.bpm,
                heartRateQuality: data.heartRate?.quality,
                averageSpO2: data.spo2?.percentage,
                spo2Quality: data.spo2?.quality,
                averageTemperature: data.temperature.celsius,
                averageBattery: data.battery.percentage,
                movementIntensity: AccelerometerConversion.magnitude(
                    x: data.accelerometer.x,
                    y: data.accelerometer.y,
                    z: data.accelerometer.z
                ),
                movementVariability: 0.1,
                grindingEvents: nil,
                averagePPGIR: Double(data.ppg.ir),
                averagePPGRed: Double(data.ppg.red),
                averagePPGGreen: Double(data.ppg.green)
            )
        }

        // Export to CSV
        let exporter = CSVExporter()
        let csvString = exporter.generateCSV(from: historicalData)

        XCTAssertFalse(csvString.isEmpty)
        XCTAssertTrue(csvString.contains("Timestamp"))
        XCTAssertTrue(csvString.contains("Avg_HeartRate"))

        // Should have header + 10 data rows
        let lines = csvString.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 11)  // 1 header + 10 data
    }

    // MARK: - Full Pipeline Tests

    func testFullPipelineDemoToResult() async {
        // Complete pipeline: DemoData → Buffer → Processor → Result

        let generator = DemoDataGenerator(configuration: .standard)
        let buffer = SensorDataBuffer(maxCapacity: 500)
        let processor = BiometricProcessor(config: .demo)

        // Step 1: Generate demo data
        let sensorData = await generator.generateSensorDataSequence(count: 100, interval: 0.02)

        // Step 2: Buffer the data
        await buffer.append(contentsOf: sensorData)

        let bufferCount = await buffer.count
        XCTAssertEqual(bufferCount, 100)

        // Step 3: Process buffered data
        let bufferedData = await buffer.allData
        var lastResult: BiometricResult = .empty

        for data in bufferedData {
            lastResult = await processor.process(
                ir: Double(data.ppg.ir),
                red: Double(data.ppg.red),
                green: Double(data.ppg.green),
                accelX: Double(data.accelerometer.x),
                accelY: Double(data.accelerometer.y),
                accelZ: Double(data.accelerometer.z)
            )
        }

        // Step 4: Verify result
        XCTAssertEqual(lastResult.processingMethod, .realtime)
    }

    func testBLEParseToBiometricResult() async {
        // Complete pipeline: Raw BLE bytes → Parser → Processor → Result

        let processor = BiometricProcessor(config: .demo)

        // Step 1: Create raw BLE packet (simulated)
        var ppgData = Data()
        var accelData = Data()

        // Generate 20 PPG samples
        for i in 0..<20 {
            let angle = Double(i) * 2.0 * .pi / 42.0

            var red: UInt32 = UInt32(120000.0 + 2500.0 * sin(angle))
            var ir: UInt32 = UInt32(150000.0 + 3000.0 * sin(angle))
            var green: UInt32 = UInt32(80000.0 + 2000.0 * sin(angle))

            ppgData.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
            ppgData.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
            ppgData.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })
        }

        // Generate 20 accelerometer samples (at rest)
        for _ in 0..<20 {
            var x: Int16 = 0
            var y: Int16 = 0
            var z: Int16 = 16384

            accelData.append(contentsOf: withUnsafeBytes(of: &x) { Array($0) })
            accelData.append(contentsOf: withUnsafeBytes(of: &y) { Array($0) })
            accelData.append(contentsOf: withUnsafeBytes(of: &z) { Array($0) })
        }

        // Step 2: Parse BLE data
        guard let ppgReadings = BLEDataParser.parsePPGData(ppgData),
              let accelReadings = BLEDataParser.parseAccelerometerData(accelData) else {
            XCTFail("Failed to parse BLE data")
            return
        }

        XCTAssertEqual(ppgReadings.count, 20)
        XCTAssertEqual(accelReadings.count, 20)

        // Step 3: Process each sample
        var lastResult: BiometricResult = .empty

        for i in 0..<min(ppgReadings.count, accelReadings.count) {
            let ppg = ppgReadings[i]
            let accel = accelReadings[i]

            lastResult = await processor.process(
                ir: Double(ppg.ir),
                red: Double(ppg.red),
                green: Double(ppg.green),
                accelX: Double(accel.x),
                accelY: Double(accel.y),
                accelZ: Double(accel.z)
            )
        }

        // Step 4: Result is valid
        XCTAssertNotNil(lastResult)
        XCTAssertEqual(lastResult.processingMethod, .realtime)
    }

    // MARK: - Error Handling Integration

    func testInvalidDataHandling() async {
        let processor = BiometricProcessor(config: .demo)

        // Process with zeros (should not crash)
        let result = await processor.process(
            ir: 0,
            red: 0,
            green: 0,
            accelX: 0,
            accelY: 0,
            accelZ: 0
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result.heartRate, 0)
    }

    func testEmptyBLEDataHandling() {
        // Empty data should return nil
        XCTAssertNil(BLEDataParser.parsePPGData(Data()))
        XCTAssertNil(BLEDataParser.parseAccelerometerData(Data()))
        XCTAssertNil(BLEDataParser.parseTemperatureData(Data()))
        XCTAssertNil(BLEDataParser.parseTGMBatteryData(Data()))
    }

    func testMalformedBLEDataHandling() {
        // Partial data (should handle gracefully)
        let partialPPG = Data(repeating: 0xFF, count: 10)  // Less than 12 bytes
        XCTAssertNil(BLEDataParser.parsePPGData(partialPPG))

        let partialAccel = Data(repeating: 0xFF, count: 4)  // Less than 6 bytes
        XCTAssertNil(BLEDataParser.parseAccelerometerData(partialAccel))
    }

    // MARK: - Configuration Consistency Tests

    func testDemoConfigurationConsistency() async {
        // Ensure demo configurations work together
        let demoGenerator = DemoDataGenerator(configuration: .standard)
        let demoProcessor = BiometricProcessor(config: .demo)
        let demoHR = HeartRateService.demo()
        let demoSpO2 = SpO2Service.demo()

        // Generate data
        let data = await demoGenerator.generateSensorData()

        // Process with BiometricProcessor
        let biometricResult = await demoProcessor.process(
            ir: Double(data.ppg.ir),
            red: Double(data.ppg.red),
            green: Double(data.ppg.green),
            accelX: Double(data.accelerometer.x),
            accelY: Double(data.accelerometer.y),
            accelZ: Double(data.accelerometer.z)
        )
        XCTAssertNotNil(biometricResult)

        // Process with HeartRateService
        let hrResult = await demoHR.processSingle(Double(data.ppg.green))
        XCTAssertNotNil(hrResult)

        // Add sample to SpO2 service
        let spo2Result = await demoSpO2.addSample(red: Double(data.ppg.red), ir: Double(data.ppg.ir))
        XCTAssertNotNil(spo2Result)
    }

    func testOralableConfigurationConsistency() async {
        // Ensure Oralable configurations work together
        let hrService = HeartRateService.oralable()
        let spo2Service = SpO2Service.oralable()
        let normalizer = PPGNormalizationService.oralable()

        // Verify they have consistent expectations (50Hz)
        let hrBufferRequired = await hrService.bufferFillLevel
        let spo2BufferFill = await spo2Service.bufferFillLevel

        // Both should start empty
        XCTAssertEqual(hrBufferRequired, 0)
        XCTAssertEqual(spo2BufferFill, 0)

        // Reset normalizer
        await normalizer.reset()
        let isInitialized = await normalizer.isBaselineInitialized
        XCTAssertFalse(isInitialized)
    }
}

// MARK: - Performance Integration Tests

final class PerformanceIntegrationTests: XCTestCase {

    func testBiometricProcessorPerformance() async throws {
        let processor = BiometricProcessor(config: .oralable)

        // Measure processing time for 1000 samples
        let startTime = Date()

        for i in 0..<1000 {
            let angle = Double(i) * 2.0 * .pi / 42.0

            _ = await processor.process(
                ir: 150000.0 + 3000.0 * sin(angle),
                red: 120000.0 + 2500.0 * sin(angle),
                green: 80000.0 + 2000.0 * sin(angle),
                accelX: 0,
                accelY: 0,
                accelZ: 16384
            )
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should process 1000 samples in under 1 second (fast enough for real-time)
        XCTAssertLessThan(elapsed, 1.0, "Processing 1000 samples took \(elapsed)s, should be under 1s")
    }

    func testBLEParserPerformance() {
        // Create a large PPG packet (240 samples = ~5 seconds of data)
        var data = Data()

        for i in 0..<240 {
            var red: UInt32 = UInt32(120000 + i)
            var ir: UInt32 = UInt32(150000 + i)
            var green: UInt32 = UInt32(80000 + i)

            data.append(contentsOf: withUnsafeBytes(of: &red) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &ir) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: &green) { Array($0) })
        }

        let startTime = Date()

        // Parse 100 times
        for _ in 0..<100 {
            _ = BLEDataParser.parsePPGData(data)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should parse 100 packets in under 100ms
        XCTAssertLessThan(elapsed, 0.1, "Parsing took \(elapsed)s, should be under 0.1s")
    }

    func testBufferPerformance() async {
        let buffer = SensorDataBuffer(maxCapacity: 10000)

        // Create test data
        let ppg = PPGData(red: 120000, ir: 150000, green: 80000, timestamp: Date())
        let accel = AccelerometerData(x: 0, y: 0, z: 16384, timestamp: Date())
        let temp = TemperatureData(celsius: 36.5, timestamp: Date())
        let battery = BatteryData(percentage: 85, timestamp: Date())
        let hr = HeartRateData(bpm: 72, quality: 0.9, timestamp: Date())
        let spo2 = SpO2Data(percentage: 98, quality: 0.9, timestamp: Date())

        let testData = SensorData(
            timestamp: Date(),
            ppg: ppg,
            accelerometer: accel,
            temperature: temp,
            battery: battery,
            heartRate: hr,
            spo2: spo2,
            deviceType: .oralable
        )

        let startTime = Date()

        // Add 10000 samples
        for _ in 0..<10000 {
            await buffer.append(testData)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should buffer 10000 samples in under 1 second
        XCTAssertLessThan(elapsed, 1.0, "Buffering took \(elapsed)s, should be under 1s")

        let count = await buffer.count
        XCTAssertEqual(count, 10000)
    }
}
