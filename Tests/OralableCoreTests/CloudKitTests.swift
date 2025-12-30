//
//  CloudKitTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for CloudKit models and compression utilities
//

import XCTest
@testable import OralableCore

final class CloudKitTests: XCTestCase {

    // MARK: - SerializableSensorData Tests

    func testSerializableSensorDataCreation() {
        let data = SerializableSensorData(
            timestamp: Date(),
            deviceType: "Oralable",
            ppgRed: 1000,
            ppgIR: 2000,
            ppgGreen: 1500,
            heartRateBPM: 72,
            heartRateQuality: 0.95
        )

        XCTAssertEqual(data.ppgIR, 2000)
        XCTAssertEqual(data.heartRateBPM, 72)
        XCTAssertTrue(data.isOralableDevice)
    }

    func testSerializableSensorDataFromSensorData() {
        let sensorData = SensorData(
            timestamp: Date(),
            ppg: PPGData(red: 1000, ir: 2000, green: 1500),
            accelerometer: AccelerometerData(x: 100, y: 200, z: 300),
            temperature: TemperatureData(celsius: 36.5),
            battery: BatteryData(percentage: 85),
            deviceType: .oralable
        )

        let serializable = SerializableSensorData(from: sensorData)

        XCTAssertEqual(serializable.ppgRed, 1000)
        XCTAssertEqual(serializable.ppgIR, 2000)
        XCTAssertEqual(serializable.temperatureCelsius, 36.5)
        XCTAssertEqual(serializable.batteryPercentage, 85)
        XCTAssertTrue(serializable.isOralableDevice)
    }

    func testSerializableSensorDataDeviceTypeInference() {
        // Oralable device (high PPG IR value)
        let oralableData = SerializableSensorData(
            timestamp: Date(),
            ppgIR: 2000
        )
        XCTAssertTrue(oralableData.isOralableDevice)
        XCTAssertFalse(oralableData.isANRDevice)

        // ANR device (EMG value present)
        let anrData = SerializableSensorData(
            timestamp: Date(),
            emg: 150.0
        )
        XCTAssertTrue(anrData.isANRDevice)

        // Explicit device type
        let explicitData = SerializableSensorData(
            timestamp: Date(),
            deviceType: "ANR M40"
        )
        XCTAssertEqual(explicitData.inferredDeviceType, "ANR M40")
    }

    func testSerializableSensorDataValidation() {
        let validData = SerializableSensorData(
            timestamp: Date(),
            heartRateBPM: 72,
            spo2Percentage: 98
        )

        XCTAssertTrue(validData.hasValidHeartRate)
        XCTAssertTrue(validData.hasValidSpO2)
        XCTAssertTrue(validData.hasValidBiometrics)

        let invalidData = SerializableSensorData(
            timestamp: Date(),
            heartRateBPM: 10,  // Too low
            spo2Percentage: 50  // Too low
        )

        XCTAssertFalse(invalidData.hasValidHeartRate)
        XCTAssertFalse(invalidData.hasValidSpO2)
    }

    func testSerializableSensorDataArrayExtensions() {
        let readings = [
            SerializableSensorData(timestamp: Date(), deviceType: "Oralable", heartRateBPM: 70),
            SerializableSensorData(timestamp: Date(), deviceType: "Oralable", heartRateBPM: 72),
            SerializableSensorData(timestamp: Date(), deviceType: "ANR M40", emg: 100),
            SerializableSensorData(timestamp: Date(), deviceType: "Oralable", heartRateBPM: 74)
        ]

        XCTAssertEqual(readings.oralableData.count, 3)
        XCTAssertEqual(readings.anrData.count, 1)
        XCTAssertEqual(readings.withValidHeartRate.count, 3)

        let avgHR = readings.averageHeartRate
        XCTAssertNotNil(avgHR)
        XCTAssertEqual(avgHR!, 72.0, accuracy: 0.1)
    }

    // MARK: - SharedSessionData Tests

    func testSharedSessionDataCreation() {
        let readings = [
            SerializableSensorData(timestamp: Date(), heartRateBPM: 70),
            SerializableSensorData(timestamp: Date().addingTimeInterval(1), heartRateBPM: 72)
        ]

        let session = SharedSessionData(
            sensorReadings: readings,
            startDate: readings.first!.timestamp,
            endDate: readings.last!.timestamp
        )

        XCTAssertEqual(session.recordingCount, 2)
        XCTAssertFalse(session.isEmpty)
        XCTAssertEqual(session.validHeartRateCount, 2)
    }

    func testSharedSessionDataFromSensorData() {
        let sensorDataArray = [
            SensorData(
                timestamp: Date(),
                ppg: PPGData(red: 1000, ir: 2000, green: 1500),
                accelerometer: AccelerometerData(x: 100, y: 200, z: 300),
                temperature: TemperatureData(celsius: 36.5),
                battery: BatteryData(percentage: 85),
                deviceType: .oralable
            ),
            SensorData(
                timestamp: Date().addingTimeInterval(1),
                ppg: PPGData(red: 1100, ir: 2100, green: 1600),
                accelerometer: AccelerometerData(x: 110, y: 210, z: 310),
                temperature: TemperatureData(celsius: 36.6),
                battery: BatteryData(percentage: 84),
                deviceType: .oralable
            )
        ]

        let session = SharedSessionData(from: sensorDataArray)

        XCTAssertEqual(session.recordingCount, 2)
        XCTAssertTrue(session.hasOralableData)
        XCTAssertFalse(session.hasANRData)
    }

    func testSharedSessionDataStatistics() {
        let readings = [
            SerializableSensorData(
                timestamp: Date(),
                temperatureCelsius: 36.5,
                heartRateBPM: 70,
                spo2Percentage: 98
            ),
            SerializableSensorData(
                timestamp: Date().addingTimeInterval(1),
                temperatureCelsius: 36.7,
                heartRateBPM: 74,
                spo2Percentage: 97
            )
        ]

        let session = SharedSessionData(
            sensorReadings: readings,
            startDate: readings.first!.timestamp,
            endDate: readings.last!.timestamp
        )

        let stats = session.statistics

        XCTAssertEqual(stats.totalReadings, 2)
        XCTAssertEqual(stats.heartRateReadings, 2)
        XCTAssertEqual(stats.averageHeartRate!, 72.0, accuracy: 0.1)
        XCTAssertEqual(stats.minHeartRate, 70.0)
        XCTAssertEqual(stats.maxHeartRate, 74.0)
    }

    func testBruxismSessionDataTypeAlias() {
        // Verify type alias works for backwards compatibility
        let session: BruxismSessionData = SharedSessionData(
            sensorReadings: [],
            startDate: Date(),
            endDate: Date()
        )

        XCTAssertTrue(session.isEmpty)
    }

    // MARK: - RecordingSession Tests

    func testRecordingSessionCreation() {
        let session = RecordingSession(
            deviceID: "test-device",
            deviceName: "Test Oralable",
            deviceType: .oralable
        )

        XCTAssertEqual(session.status, .recording)
        XCTAssertEqual(session.deviceType, .oralable)
        XCTAssertNil(session.endTime)
        XCTAssertFalse(session.status.hasEnded)
    }

    func testRecordingSessionDuration() {
        var session = RecordingSession(startTime: Date().addingTimeInterval(-60))

        XCTAssertEqual(session.duration, 60, accuracy: 1)

        session.endTime = session.startTime.addingTimeInterval(120)
        XCTAssertEqual(session.duration, 120, accuracy: 0.1)
    }

    func testRecordingSessionStatusTransitions() {
        var session = RecordingSession()

        XCTAssertEqual(session.status, .recording)
        XCTAssertTrue(session.status.isActive)

        session.pause()
        XCTAssertEqual(session.status, .paused)
        XCTAssertTrue(session.status.isActive)

        session.resume()
        XCTAssertEqual(session.status, .recording)

        session.complete()
        XCTAssertEqual(session.status, .completed)
        XCTAssertTrue(session.status.hasEnded)
        XCTAssertNotNil(session.endTime)
    }

    func testRecordingSessionDataCounts() {
        var session = RecordingSession()

        session.incrementSensorData()
        session.incrementSensorData()
        session.incrementPPGData()
        session.incrementHeartRateData()

        XCTAssertEqual(session.sensorDataCount, 2)
        XCTAssertEqual(session.ppgDataCount, 1)
        XCTAssertEqual(session.heartRateDataCount, 1)
        XCTAssertEqual(session.totalDataPoints, 4)
        XCTAssertTrue(session.hasData)
    }

    func testRecordingSessionTags() {
        var session = RecordingSession()

        session.addTag("sleep")
        session.addTag("night")
        session.addTag("sleep")  // Duplicate

        XCTAssertEqual(session.tags.count, 2)
        XCTAssertTrue(session.tags.contains("sleep"))

        session.removeTag("night")
        XCTAssertEqual(session.tags.count, 1)
    }

    func testRecordingSessionArrayExtensions() {
        let sessions = [
            RecordingSession(status: .recording, deviceType: .oralable),
            RecordingSession(status: .completed, deviceType: .oralable),
            RecordingSession(status: .completed, deviceType: .anr),
            RecordingSession(status: .failed, deviceType: .oralable)
        ]

        XCTAssertEqual(sessions.recording.count, 1)
        XCTAssertEqual(sessions.completed.count, 2)
        XCTAssertEqual(sessions.failed.count, 1)
        XCTAssertEqual(sessions.oralableSessions.count, 3)
        XCTAssertEqual(sessions.anrSessions.count, 1)
    }

    func testRecordingStatusProperties() {
        XCTAssertTrue(RecordingStatus.recording.isActive)
        XCTAssertTrue(RecordingStatus.paused.isActive)
        XCTAssertFalse(RecordingStatus.completed.isActive)
        XCTAssertFalse(RecordingStatus.failed.isActive)

        XCTAssertFalse(RecordingStatus.recording.hasEnded)
        XCTAssertTrue(RecordingStatus.completed.hasEnded)
        XCTAssertTrue(RecordingStatus.failed.hasEnded)
    }

    // MARK: - HealthDataRecord Tests

    func testHealthDataRecordCreation() {
        let record = HealthDataRecord(
            recordID: "test-record-123",
            recordingDate: Date(),
            dataType: .heartRate,
            measurements: Data(),
            sessionDuration: 3600
        )

        XCTAssertEqual(record.recordID, "test-record-123")
        XCTAssertEqual(record.dataType, .heartRate)
        XCTAssertEqual(record.sessionDuration, 3600)
        XCTAssertEqual(record.id, "test-record-123")
    }

    func testHealthDataRecordFromStringType() {
        let record = HealthDataRecord(
            recordID: "test-123",
            recordingDate: Date(),
            dataTypeString: "spo2",
            measurements: Data(),
            sessionDuration: 1800
        )

        XCTAssertEqual(record.dataType, .spo2)
    }

    func testHealthDataTypeProperties() {
        XCTAssertEqual(HealthDataType.heartRate.displayName, "Heart Rate")
        XCTAssertEqual(HealthDataType.heartRate.unit, "bpm")
        XCTAssertEqual(HealthDataType.spo2.unit, "%")
        XCTAssertEqual(HealthDataType.temperature.unit, "°C")
    }

    func testHealthDataRecordExpiration() {
        let oldRecord = HealthDataRecord(
            recordID: "old-record",
            recordingDate: Date().addingTimeInterval(-100 * 24 * 3600), // 100 days ago
            dataType: .heartRate,
            measurements: Data(),
            sessionDuration: 3600
        )

        XCTAssertTrue(oldRecord.hasExpired(retentionDays: 90))

        let newRecord = HealthDataRecord(
            recordID: "new-record",
            recordingDate: Date(),
            dataType: .heartRate,
            measurements: Data(),
            sessionDuration: 3600
        )

        XCTAssertFalse(newRecord.hasExpired(retentionDays: 90))
    }

    func testHealthDataRecordArrayExtensions() {
        let records = [
            HealthDataRecord(recordID: "1", recordingDate: Date(), dataType: .heartRate, measurements: Data(), sessionDuration: 100),
            HealthDataRecord(recordID: "2", recordingDate: Date(), dataType: .spo2, measurements: Data(), sessionDuration: 200),
            HealthDataRecord(recordID: "3", recordingDate: Date(), dataType: .heartRate, measurements: Data(), sessionDuration: 300)
        ]

        XCTAssertEqual(records.ofType(.heartRate).count, 2)
        XCTAssertEqual(records.ofType(.spo2).count, 1)
        XCTAssertEqual(records.totalDuration, 600)
        XCTAssertNotNil(records.mostRecent)
    }

    // MARK: - DeviceType CloudKit Extension Tests

    func testDeviceTypeCloudKitIdentifier() {
        XCTAssertEqual(DeviceType.oralable.cloudKitIdentifier, "Oralable")
        XCTAssertEqual(DeviceType.anr.cloudKitIdentifier, "ANR M40")
        XCTAssertEqual(DeviceType.demo.cloudKitIdentifier, "Demo")
    }

    func testDeviceTypeFromCloudKit() {
        XCTAssertEqual(DeviceType.fromCloudKit("Oralable"), .oralable)
        XCTAssertEqual(DeviceType.fromCloudKit("ANR M40"), .anr)
        XCTAssertEqual(DeviceType.fromCloudKit("Demo"), .demo)
        XCTAssertEqual(DeviceType.fromCloudKit("Unknown"), .oralable) // Default
    }

    // MARK: - Data Compression Tests

    func testDataCompression() {
        let testString = String(repeating: "Hello, World! ", count: 100)
        let originalData = testString.data(using: .utf8)!

        let compressed = originalData.compressed()
        XCTAssertNotNil(compressed)
        XCTAssertLessThan(compressed!.count, originalData.count)

        let decompressed = compressed!.decompressed(expectedSize: originalData.count * 2)
        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed, originalData)
    }

    func testDataCompressionAlgorithms() {
        let testString = String(repeating: "Test data for compression ", count: 50)
        let originalData = testString.data(using: .utf8)!

        // Test LZFSE (default)
        let lzfse = originalData.compressed(algorithm: .lzfse)
        XCTAssertNotNil(lzfse)

        // Test LZ4
        let lz4 = originalData.compressed(algorithm: .lz4)
        XCTAssertNotNil(lz4)

        // Test ZLIB
        let zlib = originalData.compressed(algorithm: .zlib)
        XCTAssertNotNil(zlib)

        // Decompress and verify
        let decompressed = lzfse!.decompressed(expectedSize: originalData.count * 2)
        XCTAssertEqual(decompressed, originalData)
    }

    func testDataCompressionRatio() {
        let testString = String(repeating: "Repetitive text ", count: 100)
        let data = testString.data(using: .utf8)!

        let ratio = data.compressionRatio()
        XCTAssertNotNil(ratio)
        XCTAssertLessThan(ratio!, 1.0) // Should compress well
    }

    func testCompressedWithStats() {
        let testString = String(repeating: "Statistics test ", count: 50)
        let data = testString.data(using: .utf8)!

        let result = data.compressedWithStats()
        XCTAssertNotNil(result)

        let stats = result!.stats
        XCTAssertEqual(stats.originalSize, data.count)
        XCTAssertLessThan(stats.compressedSize, stats.originalSize)
        XCTAssertGreaterThan(stats.savingsPercentage, 0)
    }

    func testJSONCompressionHelper() {
        struct TestModel: Codable, Equatable {
            let name: String
            let value: Int
        }

        let original = TestModel(name: "Test", value: 42)

        let compressed = Data.compress(original)
        XCTAssertNotNil(compressed)

        let decompressed: TestModel? = compressed?.decompressedObject(
            TestModel.self,
            expectedSize: 1000
        )
        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed, original)
    }

    func testEmptyDataCompression() {
        let emptyData = Data()

        XCTAssertNil(emptyData.compressed())
        XCTAssertNil(emptyData.decompressed(expectedSize: 100))
    }

    // MARK: - Codable Tests

    func testSerializableSensorDataCodable() throws {
        let original = SerializableSensorData(
            timestamp: Date(),
            deviceType: "Oralable",
            ppgRed: 1000,
            ppgIR: 2000,
            ppgGreen: 1500,
            heartRateBPM: 72
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SerializableSensorData.self, from: encoded)

        XCTAssertEqual(decoded.ppgRed, original.ppgRed)
        XCTAssertEqual(decoded.heartRateBPM, original.heartRateBPM)
    }

    func testSharedSessionDataCodable() throws {
        let readings = [
            SerializableSensorData(timestamp: Date(), heartRateBPM: 70),
            SerializableSensorData(timestamp: Date().addingTimeInterval(1), heartRateBPM: 72)
        ]

        let original = SharedSessionData(
            sensorReadings: readings,
            startDate: readings.first!.timestamp,
            endDate: readings.last!.timestamp
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedSessionData.self, from: encoded)

        XCTAssertEqual(decoded.recordingCount, original.recordingCount)
        XCTAssertEqual(decoded.sensorReadings.count, original.sensorReadings.count)
    }

    func testRecordingSessionCodable() throws {
        var original = RecordingSession(
            deviceID: "test-device",
            deviceName: "Test Device",
            deviceType: .oralable
        )
        original.addTag("test")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecordingSession.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.deviceType, original.deviceType)
        XCTAssertEqual(decoded.tags, original.tags)
    }
}
