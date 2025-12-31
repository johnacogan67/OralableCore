//
//  SharedComponentsTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for shared component helper types
//

import XCTest
import SwiftUI
@testable import OralableCore

// MARK: - MetricTrend Tests

final class MetricTrendTests: XCTestCase {

    func testMetricTrendIconUp() {
        XCTAssertEqual(MetricTrend.up.icon, "arrow.up.right")
    }

    func testMetricTrendIconDown() {
        XCTAssertEqual(MetricTrend.down.icon, "arrow.down.right")
    }

    func testMetricTrendIconStable() {
        XCTAssertEqual(MetricTrend.stable.icon, "arrow.right")
    }

    func testMetricTrendIconUnknown() {
        XCTAssertEqual(MetricTrend.unknown.icon, "minus")
    }

    func testMetricTrendColorUp() {
        XCTAssertEqual(MetricTrend.up.color, .green)
    }

    func testMetricTrendColorDown() {
        XCTAssertEqual(MetricTrend.down.color, .red)
    }

    func testMetricTrendColorStable() {
        XCTAssertEqual(MetricTrend.stable.color, .blue)
    }

    func testMetricTrendColorUnknown() {
        XCTAssertEqual(MetricTrend.unknown.color, .gray)
    }

    func testMetricTrendAllCases() {
        let trends: [MetricTrend] = [.up, .down, .stable, .unknown]

        for trend in trends {
            XCTAssertFalse(trend.icon.isEmpty)
        }
    }

    func testMetricTrendSendable() {
        let trend = MetricTrend.up

        Task {
            let icon = trend.icon
            XCTAssertEqual(icon, "arrow.up.right")
        }
    }
}

// MARK: - StatusBadgeStyle Tests

final class StatusBadgeStyleTests: XCTestCase {

    func testStatusBadgeStyleCases() {
        let styles: [StatusBadgeView.StatusBadgeStyle] = [.filled, .outlined, .subtle]
        XCTAssertEqual(styles.count, 3)
    }
}

// MARK: - RecordingStatus Extended Tests

final class RecordingStatusExtendedTests: XCTestCase {

    // MARK: - Icon Name Tests

    func testRecordingIconName() {
        XCTAssertEqual(RecordingStatus.recording.iconName, "record.circle.fill")
    }

    func testPausedIconName() {
        XCTAssertEqual(RecordingStatus.paused.iconName, "pause.circle.fill")
    }

    func testCompletedIconName() {
        XCTAssertEqual(RecordingStatus.completed.iconName, "checkmark.circle.fill")
    }

    func testFailedIconName() {
        XCTAssertEqual(RecordingStatus.failed.iconName, "xmark.circle.fill")
    }

    func testAllStatusesHaveIcons() {
        for status in RecordingStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty, "\(status) should have an icon")
        }
    }

    // MARK: - Color Name Tests

    func testRecordingColorName() {
        XCTAssertEqual(RecordingStatus.recording.colorName, "red")
    }

    func testPausedColorName() {
        XCTAssertEqual(RecordingStatus.paused.colorName, "orange")
    }

    func testCompletedColorName() {
        XCTAssertEqual(RecordingStatus.completed.colorName, "green")
    }

    func testFailedColorName() {
        XCTAssertEqual(RecordingStatus.failed.colorName, "gray")
    }

    func testAllStatusesHaveColors() {
        for status in RecordingStatus.allCases {
            XCTAssertFalse(status.colorName.isEmpty, "\(status) should have a color")
        }
    }

    // MARK: - Raw Value Tests

    func testRecordingRawValue() {
        XCTAssertEqual(RecordingStatus.recording.rawValue, "Recording")
    }

    func testPausedRawValue() {
        XCTAssertEqual(RecordingStatus.paused.rawValue, "Paused")
    }

    func testCompletedRawValue() {
        XCTAssertEqual(RecordingStatus.completed.rawValue, "Completed")
    }

    func testFailedRawValue() {
        XCTAssertEqual(RecordingStatus.failed.rawValue, "Failed")
    }

    // MARK: - CaseIterable Tests

    func testRecordingStatusAllCases() {
        XCTAssertEqual(RecordingStatus.allCases.count, 4)
        XCTAssertTrue(RecordingStatus.allCases.contains(.recording))
        XCTAssertTrue(RecordingStatus.allCases.contains(.paused))
        XCTAssertTrue(RecordingStatus.allCases.contains(.completed))
        XCTAssertTrue(RecordingStatus.allCases.contains(.failed))
    }

    // MARK: - Codable Tests

    func testRecordingStatusCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in RecordingStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(RecordingStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }
}

// MARK: - RecordingSession Extended Tests

final class RecordingSessionExtendedTests: XCTestCase {

    // MARK: - Data Type Label Tests

    func testDataTypeLabelOralable() {
        let session = RecordingSession(deviceType: .oralable)
        XCTAssertEqual(session.dataTypeLabel, "IR")
    }

    func testDataTypeLabelANR() {
        let session = RecordingSession(deviceType: .anr)
        XCTAssertEqual(session.dataTypeLabel, "EMG")
    }

    func testDataTypeLabelDemo() {
        let session = RecordingSession(deviceType: .demo)
        XCTAssertEqual(session.dataTypeLabel, "Demo")
    }

    func testDataTypeLabelNone() {
        let session = RecordingSession(deviceType: nil)
        XCTAssertEqual(session.dataTypeLabel, "Unknown")
    }

    // MARK: - Data Type Icon Tests

    func testDataTypeIconOralable() {
        let session = RecordingSession(deviceType: .oralable)
        XCTAssertEqual(session.dataTypeIcon, "waveform.path.ecg")
    }

    func testDataTypeIconANR() {
        let session = RecordingSession(deviceType: .anr)
        XCTAssertEqual(session.dataTypeIcon, "bolt.horizontal.circle.fill")
    }

    func testDataTypeIconDemo() {
        let session = RecordingSession(deviceType: .demo)
        XCTAssertEqual(session.dataTypeIcon, "play.circle.fill")
    }

    func testDataTypeIconNone() {
        let session = RecordingSession(deviceType: nil)
        XCTAssertEqual(session.dataTypeIcon, "questionmark.circle")
    }

    // MARK: - Data Type Color Name Tests

    func testDataTypeColorNameOralable() {
        let session = RecordingSession(deviceType: .oralable)
        XCTAssertEqual(session.dataTypeColorName, "purple")
    }

    func testDataTypeColorNameANR() {
        let session = RecordingSession(deviceType: .anr)
        XCTAssertEqual(session.dataTypeColorName, "blue")
    }

    func testDataTypeColorNameDemo() {
        let session = RecordingSession(deviceType: .demo)
        XCTAssertEqual(session.dataTypeColorName, "orange")
    }

    func testDataTypeColorNameNone() {
        let session = RecordingSession(deviceType: nil)
        XCTAssertEqual(session.dataTypeColorName, "gray")
    }

    // MARK: - Formatted Duration Tests

    func testFormattedDurationShort() {
        let start = Date()
        let end = start.addingTimeInterval(65) // 1 minute 5 seconds

        var session = RecordingSession(startTime: start)
        session.endTime = end

        XCTAssertEqual(session.formattedDuration, "01:05")
    }

    func testFormattedDurationLong() {
        let start = Date()
        let end = start.addingTimeInterval(3665) // 1 hour 1 minute 5 seconds

        var session = RecordingSession(startTime: start)
        session.endTime = end

        XCTAssertEqual(session.formattedDuration, "01:01:05")
    }

    // MARK: - Data Flags Tests

    func testHasAccelerometerDataTrue() {
        let session = RecordingSession(sensorDataCount: 100)
        XCTAssertTrue(session.hasAccelerometerData)
    }

    func testHasAccelerometerDataFalse() {
        let session = RecordingSession(sensorDataCount: 0)
        XCTAssertFalse(session.hasAccelerometerData)
    }

    func testHasTemperatureDataOralable() {
        let session = RecordingSession(deviceType: .oralable, sensorDataCount: 100)
        XCTAssertTrue(session.hasTemperatureData)
    }

    func testHasTemperatureDataNonOralable() {
        let session = RecordingSession(deviceType: .anr, sensorDataCount: 100)
        XCTAssertFalse(session.hasTemperatureData)
    }

    func testHasDataTrue() {
        let session = RecordingSession(ppgDataCount: 50)
        XCTAssertTrue(session.hasData)
    }

    func testHasDataFalse() {
        let session = RecordingSession()
        XCTAssertFalse(session.hasData)
    }

    func testTotalDataPoints() {
        let session = RecordingSession(
            sensorDataCount: 100,
            ppgDataCount: 200,
            heartRateDataCount: 50,
            spo2DataCount: 50
        )
        XCTAssertEqual(session.totalDataPoints, 400)
    }

    // MARK: - Mutating Methods Tests

    func testComplete() {
        var session = RecordingSession()
        XCTAssertEqual(session.status, .recording)
        XCTAssertNil(session.endTime)

        session.complete()

        XCTAssertEqual(session.status, .completed)
        XCTAssertNotNil(session.endTime)
    }

    func testPause() {
        var session = RecordingSession()
        session.pause()
        XCTAssertEqual(session.status, .paused)
    }

    func testResume() {
        var session = RecordingSession()
        session.pause()
        session.resume()
        XCTAssertEqual(session.status, .recording)
    }

    func testFail() {
        var session = RecordingSession()
        session.fail()
        XCTAssertEqual(session.status, .failed)
        XCTAssertNotNil(session.endTime)
    }

    func testIncrementCounters() {
        var session = RecordingSession()

        session.incrementSensorData()
        XCTAssertEqual(session.sensorDataCount, 1)

        session.incrementPPGData()
        XCTAssertEqual(session.ppgDataCount, 1)

        session.incrementHeartRateData()
        XCTAssertEqual(session.heartRateDataCount, 1)

        session.incrementSpO2Data()
        XCTAssertEqual(session.spo2DataCount, 1)
    }

    func testAddTag() {
        var session = RecordingSession()

        session.addTag("test")
        XCTAssertEqual(session.tags, ["test"])

        // Adding same tag should not duplicate
        session.addTag("test")
        XCTAssertEqual(session.tags, ["test"])

        session.addTag("another")
        XCTAssertEqual(session.tags, ["test", "another"])
    }

    func testRemoveTag() {
        var session = RecordingSession(tags: ["test", "another"])

        session.removeTag("test")
        XCTAssertEqual(session.tags, ["another"])

        session.removeTag("nonexistent")
        XCTAssertEqual(session.tags, ["another"])
    }
}

// MARK: - RecordingSession Array Extension Tests

final class RecordingSessionArrayTests: XCTestCase {

    func testRecordingFilter() {
        let sessions = [
            RecordingSession(status: .recording),
            RecordingSession(status: .paused),
            RecordingSession(status: .completed),
            RecordingSession(status: .recording)
        ]

        XCTAssertEqual(sessions.recording.count, 2)
    }

    func testPausedFilter() {
        let sessions = [
            RecordingSession(status: .recording),
            RecordingSession(status: .paused),
            RecordingSession(status: .paused)
        ]

        XCTAssertEqual(sessions.paused.count, 2)
    }

    func testCompletedFilter() {
        let sessions = [
            RecordingSession(status: .completed),
            RecordingSession(status: .completed),
            RecordingSession(status: .failed)
        ]

        XCTAssertEqual(sessions.completed.count, 2)
    }

    func testFailedFilter() {
        let sessions = [
            RecordingSession(status: .failed),
            RecordingSession(status: .completed)
        ]

        XCTAssertEqual(sessions.failed.count, 1)
    }

    func testOralableSessionsFilter() {
        let sessions = [
            RecordingSession(deviceType: .oralable),
            RecordingSession(deviceType: .anr),
            RecordingSession(deviceType: .oralable)
        ]

        XCTAssertEqual(sessions.oralableSessions.count, 2)
    }

    func testANRSessionsFilter() {
        let sessions = [
            RecordingSession(deviceType: .anr),
            RecordingSession(deviceType: .oralable)
        ]

        XCTAssertEqual(sessions.anrSessions.count, 1)
    }

    func testWithTagFilter() {
        let sessions = [
            RecordingSession(tags: ["test", "important"]),
            RecordingSession(tags: ["test"]),
            RecordingSession(tags: ["other"])
        ]

        XCTAssertEqual(sessions.withTag("test").count, 2)
        XCTAssertEqual(sessions.withTag("important").count, 1)
        XCTAssertEqual(sessions.withTag("nonexistent").count, 0)
    }

    func testInRangeFilter() {
        let now = Date()
        let sessions = [
            RecordingSession(startTime: now.addingTimeInterval(-3600)), // 1 hour ago
            RecordingSession(startTime: now.addingTimeInterval(-1800)), // 30 min ago
            RecordingSession(startTime: now.addingTimeInterval(-86400)) // 1 day ago
        ]

        let rangeStart = now.addingTimeInterval(-7200) // 2 hours ago
        let rangeEnd = now

        XCTAssertEqual(sessions.inRange(from: rangeStart, to: rangeEnd).count, 2)
    }

    func testTotalDuration() {
        let now = Date()

        var session1 = RecordingSession(startTime: now.addingTimeInterval(-100))
        session1.endTime = now.addingTimeInterval(-50) // 50 seconds

        var session2 = RecordingSession(startTime: now.addingTimeInterval(-200))
        session2.endTime = now.addingTimeInterval(-100) // 100 seconds

        let sessions = [session1, session2]

        XCTAssertEqual(sessions.totalDuration, 150, accuracy: 1)
    }

    func testTotalSensorDataCount() {
        let sessions = [
            RecordingSession(sensorDataCount: 100),
            RecordingSession(sensorDataCount: 200),
            RecordingSession(sensorDataCount: 50)
        ]

        XCTAssertEqual(sessions.totalSensorDataCount, 350)
    }
}
