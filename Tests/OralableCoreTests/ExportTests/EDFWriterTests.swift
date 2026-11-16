import XCTest
@testable import OralableCore

final class EDFWriterTests: XCTestCase {

    func testDualAEDFIncludesEMGChannel() throws {
        let n = 250
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var oral: [EDFSessionGrid.Point] = []
        var emg: [(Date, Double)] = []
        for i in 0..<n {
            let t = t0.addingTimeInterval(Double(i) / 50.0)
            oral.append(.init(time: t, red: 2000, ir: 1_000_000 + Double(i), green: 2100, spo2: i > 100 && i < 160 ? 85 : 97))
            emg.append((t, 200 + Double(i % 50)))
        }
        let built = try EDFSessionGrid.buildChannels(oralable: oral, emg: emg, requireEMG: true)
        XCTAssertTrue(built.channels.contains { $0.label == EDFExportSpec.channelEMG })
        XCTAssertFalse(built.channels.contains { $0.label == EDFExportSpec.channelRed })
        XCTAssertFalse(built.channels.contains { $0.label == EDFExportSpec.channelGreen })

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dual_a_test.edf")
        try EDFWriter.write(
            channels: built.channels,
            annotations: built.annotations,
            to: url,
            startDate: built.start,
            requireEMG: true
        )
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 512)
        // Header reserved should contain EDF+C
        let reserved = String(data: data.subdata(in: 192..<236), encoding: .ascii) ?? ""
        XCTAssertTrue(reserved.hasPrefix("EDF+C"), reserved)
        // Labels block starts at byte 256; EMG should appear
        let labelBlock = String(data: data.subdata(in: 256..<(256 + built.channels.count * 16 + 16)), encoding: .ascii) ?? ""
        XCTAssertTrue(labelBlock.contains(EDFExportSpec.channelEMG), labelBlock)
        try? FileManager.default.removeItem(at: url)
    }

    func testRequireEMGFailsWithoutANR() {
        let n = 100
        let t0 = Date()
        let oral = (0..<n).map { i in
            EDFSessionGrid.Point(time: t0.addingTimeInterval(Double(i) / 50.0), ir: 1e6, spo2: 97)
        }
        XCTAssertThrowsError(try EDFSessionGrid.buildChannels(oralable: oral, emg: [], requireEMG: true)) { err in
            XCTAssertEqual(err as? EDFWriterError, .missingEMG)
        }
    }
}
