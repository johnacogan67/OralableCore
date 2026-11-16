//
//  ParityTests.swift
//  OralableCoreTests
//
//  Filter + SpO2 parity: Swift must match Mac Python research pipeline.
//  Gold: GOLD_STANDARD_FILTER_PARITY.csv from cursor_oralable
//  Run: python scripts/generate_filter_parity_data.py
//

import XCTest
@testable import OralableCore

final class ParityTests: XCTestCase {

    private let filterTolerance = 0.001
    /// SpO2 series can differ slightly at edges; clinical curve must stay tight mid-record.
    private let spo2Tolerance = 0.5

    private struct GoldStandard {
        let green: [Double]
        let ir: [Double]
        let red: [Double]
        let greenBpExpected: [Double]
        let irDcExpected: [Double]
        let redDcExpected: [Double]
        let redAcExpected: [Double]
        let irAcExpected: [Double]
        let spo2Expected: [Double]
        let rescueExpected: [Bool]
        let sashbExpected: [Double]
    }

    private func loadGoldStandard() throws -> GoldStandard {
        guard let url = Bundle.module.url(forResource: "GOLD_STANDARD_FILTER_PARITY", withExtension: "csv", subdirectory: nil) else {
            throw NSError(domain: "ParityTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "GOLD_STANDARD_FILTER_PARITY.csv not found. Run: python scripts/generate_filter_parity_data.py"])
        }
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw NSError(domain: "ParityTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV has no data rows"])
        }
        let columns = lines[0].split(separator: ",").map { String($0) }
        func idx(_ name: String) throws -> Int {
            guard let i = columns.firstIndex(of: name) else {
                throw NSError(domain: "ParityTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing column \(name)"])
            }
            return i
        }
        let greenIdx = try idx("green")
        let irIdx = try idx("ir")
        let redIdx = try idx("red")
        let greenBpIdx = try idx("green_bp_expected")
        let irDcIdx = try idx("ir_dc_expected")
        let redDcIdx = try idx("red_dc_expected")
        let redAcIdx = try idx("red_ac_expected")
        let irAcIdx = try idx("ir_ac_expected")
        let spo2Idx = try idx("spo2_pct_expected")
        let rescueIdx = try idx("is_airway_rescue_expected")
        let sashbIdx = try idx("cumulative_sashb_expected")

        var green: [Double] = []
        var ir: [Double] = []
        var red: [Double] = []
        var greenBpExpected: [Double] = []
        var irDcExpected: [Double] = []
        var redDcExpected: [Double] = []
        var redAcExpected: [Double] = []
        var irAcExpected: [Double] = []
        var spo2Expected: [Double] = []
        var rescueExpected: [Bool] = []
        var sashbExpected: [Double] = []

        for (i, line) in lines.enumerated() where i > 0 {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count > sashbIdx else { continue }
            green.append(Double(parts[greenIdx]) ?? 0)
            ir.append(Double(parts[irIdx]) ?? 0)
            red.append(Double(parts[redIdx]) ?? 0)
            greenBpExpected.append(Double(parts[greenBpIdx]) ?? 0)
            irDcExpected.append(Double(parts[irDcIdx]) ?? 0)
            redDcExpected.append(Double(parts[redDcIdx]) ?? 0)
            redAcExpected.append(Double(parts[redAcIdx]) ?? 0)
            irAcExpected.append(Double(parts[irAcIdx]) ?? 0)
            spo2Expected.append(Double(parts[spo2Idx]) ?? .nan)
            rescueExpected.append((Double(parts[rescueIdx]) ?? 0) > 0.5)
            sashbExpected.append(Double(parts[sashbIdx]) ?? 0)
        }
        return GoldStandard(
            green: green, ir: ir, red: red,
            greenBpExpected: greenBpExpected, irDcExpected: irDcExpected,
            redDcExpected: redDcExpected, redAcExpected: redAcExpected, irAcExpected: irAcExpected,
            spo2Expected: spo2Expected, rescueExpected: rescueExpected, sashbExpected: sashbExpected
        )
    }

    func testIRDCLowpassParity() throws {
        let data = try loadGoldStandard()
        let filter = TransferFunctionFilter.irDCLowpass()
        let irDcActual = filter.filtfilt(data.ir)
        XCTAssertEqual(irDcActual.count, data.irDcExpected.count)
        for i in 0..<min(irDcActual.count, data.irDcExpected.count) {
            XCTAssertEqual(irDcActual[i], data.irDcExpected[i], accuracy: filterTolerance, "ir_dc mismatch at \(i)")
        }
    }

    func testGreenBandpassParity() throws {
        let data = try loadGoldStandard()
        let filter = TransferFunctionFilter.hrBandpass()
        let mean = data.green.reduce(0, +) / Double(data.green.count)
        let detrended = data.green.map { $0 - mean }
        let greenBpActual = filter.filtfilt(detrended)
        XCTAssertEqual(greenBpActual.count, data.greenBpExpected.count)
        for i in 0..<min(greenBpActual.count, data.greenBpExpected.count) {
            XCTAssertEqual(greenBpActual[i], data.greenBpExpected[i], accuracy: filterTolerance, "green_bp mismatch at \(i)")
        }
    }

    func testFullPipelineParity() throws {
        let data = try loadGoldStandard()
        let lpFilter = TransferFunctionFilter.irDCLowpass()
        let bpFilter = TransferFunctionFilter.hrBandpass()
        let mean = data.green.reduce(0, +) / Double(data.green.count)
        let detrended = data.green.map { $0 - mean }
        let irDcActual = lpFilter.filtfilt(data.ir)
        let greenBpActual = bpFilter.filtfilt(detrended)
        var maxIRDcError: Double = 0
        var maxGreenBpError: Double = 0
        for i in 0..<data.irDcExpected.count {
            maxIRDcError = max(maxIRDcError, abs(irDcActual[i] - data.irDcExpected[i]))
        }
        for i in 0..<data.greenBpExpected.count {
            maxGreenBpError = max(maxGreenBpError, abs(greenBpActual[i] - data.greenBpExpected[i]))
        }
        XCTAssertLessThanOrEqual(maxIRDcError, filterTolerance)
        XCTAssertLessThanOrEqual(maxGreenBpError, filterTolerance)
    }

    /// Mac ClinicalBiometricSuite SpO2: filtfilt AC/DC + centered rolling RoR.
    func testProtocolASpO2SeriesParity() throws {
        let data = try loadGoldStandard()
        let spo2Actual = SpO2Service.protocolASpO2Series(
            redDC: data.redDcExpected,
            redAC: data.redAcExpected,
            irDC: data.irDcExpected,
            irAC: data.irAcExpected,
            windowSamples: 150
        )
        XCTAssertEqual(spo2Actual.count, data.spo2Expected.count)
        // Skip warm-up edges where centered window is short.
        let start = 150
        let end = max(start, data.spo2Expected.count - 150)
        var compared = 0
        for i in start..<end {
            let exp = data.spo2Expected[i]
            let act = spo2Actual[i]
            guard exp.isFinite, act.isFinite else { continue }
            XCTAssertEqual(act, exp, accuracy: spo2Tolerance, "spo2 mismatch at \(i): expected \(exp), got \(act)")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 100, "Expected mid-record SpO2 samples to compare")
    }

    func testProtocolAAirwayRescueParity() throws {
        let data = try loadGoldStandard()
        let rescue = SpO2Service.protocolAAirwayRescue(irDC: data.irDcExpected)
        XCTAssertEqual(rescue.count, data.rescueExpected.count)
        var mismatches = 0
        for i in 0..<min(rescue.count, data.rescueExpected.count) {
            if rescue[i] != data.rescueExpected[i] { mismatches += 1 }
        }
        // Allow tiny edge disagreement; bulk must match Mac −10%/500ms rule.
        XCTAssertLessThanOrEqual(mismatches, 5, "Airway rescue mismatches: \(mismatches)")
    }

    func testProtocolASASHBParity() throws {
        let data = try loadGoldStandard()
        let sashb = SpO2Service.protocolASASHB(spo2: data.spo2Expected)
        XCTAssertEqual(sashb.count, data.sashbExpected.count)
        if let lastExp = data.sashbExpected.last, let lastAct = sashb.last {
            XCTAssertEqual(lastAct, lastExp, accuracy: 0.05, "Final cumulative SASHB mismatch")
        }
    }
}
