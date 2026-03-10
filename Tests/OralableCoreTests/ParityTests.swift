//
//  ParityTests.swift
//  OralableCoreTests
//
//  Filter parity tests: Swift output must match Python research pipeline within 0.001.
//  Gold standard: GOLD_STANDARD_FILTER_PARITY.csv from cursor_oralable (Python compute_filters).
//  Run: python scripts/generate_filter_parity_data.py to regenerate the CSV.
//

import XCTest
@testable import OralableCore

final class ParityTests: XCTestCase {

    private let tolerance = 0.001

    // MARK: - Load Gold Standard

    private func loadGoldStandard() throws -> (green: [Double], ir: [Double], greenBpExpected: [Double], irDcExpected: [Double]) {
        guard let url = Bundle.module.url(forResource: "GOLD_STANDARD_FILTER_PARITY", withExtension: "csv", subdirectory: nil) else {
            throw NSError(domain: "ParityTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "GOLD_STANDARD_FILTER_PARITY.csv not found in test bundle. Run: python scripts/generate_filter_parity_data.py in cursor_oralable"])
        }
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw NSError(domain: "ParityTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV has no data rows"])
        }
        let header = lines[0]
        let columns = header.split(separator: ",").map { String($0) }
        guard columns.contains("green"), columns.contains("ir"), columns.contains("green_bp_expected"), columns.contains("ir_dc_expected") else {
            throw NSError(domain: "ParityTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "CSV missing required columns"])
        }
        let greenIdx = columns.firstIndex(of: "green")!
        let irIdx = columns.firstIndex(of: "ir")!
        let greenBpIdx = columns.firstIndex(of: "green_bp_expected")!
        let irDcIdx = columns.firstIndex(of: "ir_dc_expected")!

        var green: [Double] = []
        var ir: [Double] = []
        var greenBpExpected: [Double] = []
        var irDcExpected: [Double] = []

        for (i, line) in lines.enumerated() where i > 0 {
            let parts = line.split(separator: ",").map { String($0) }
            guard parts.count > max(greenIdx, irIdx, greenBpIdx, irDcIdx) else { continue }
            green.append(Double(parts[greenIdx]) ?? 0)
            ir.append(Double(parts[irIdx]) ?? 0)
            greenBpExpected.append(Double(parts[greenBpIdx]) ?? 0)
            irDcExpected.append(Double(parts[irDcIdx]) ?? 0)
        }
        return (green, ir, greenBpExpected, irDcExpected)
    }

    // MARK: - IR DC Lowpass Parity

    func testIRDCLowpassParity() throws {
        let data = try loadGoldStandard()
        let filter = TransferFunctionFilter.irDCLowpass()
        let irDcActual = filter.filtfilt(data.ir)

        XCTAssertEqual(irDcActual.count, data.irDcExpected.count, "Output length mismatch")
        for i in 0..<min(irDcActual.count, data.irDcExpected.count) {
            let expected = data.irDcExpected[i]
            let actual = irDcActual[i]
            XCTAssertEqual(actual, expected, accuracy: tolerance, "ir_dc mismatch at index \(i): expected \(expected), got \(actual)")
        }
    }

    // MARK: - Green Bandpass Parity

    func testGreenBandpassParity() throws {
        let data = try loadGoldStandard()
        let filter = TransferFunctionFilter.hrBandpass()
        let mean = data.green.reduce(0, +) / Double(data.green.count)
        let detrended = data.green.map { $0 - mean }
        let greenBpActual = filter.filtfilt(detrended)

        XCTAssertEqual(greenBpActual.count, data.greenBpExpected.count, "Output length mismatch")
        for i in 0..<min(greenBpActual.count, data.greenBpExpected.count) {
            let expected = data.greenBpExpected[i]
            let actual = greenBpActual[i]
            XCTAssertEqual(actual, expected, accuracy: tolerance, "green_bp mismatch at index \(i): expected \(expected), got \(actual)")
        }
    }

    // MARK: - Full Pipeline Parity

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
            let e = abs(irDcActual[i] - data.irDcExpected[i])
            if e > maxIRDcError { maxIRDcError = e }
        }
        for i in 0..<data.greenBpExpected.count {
            let e = abs(greenBpActual[i] - data.greenBpExpected[i])
            if e > maxGreenBpError { maxGreenBpError = e }
        }
        XCTAssertLessThanOrEqual(maxIRDcError, tolerance, "Max ir_dc error \(maxIRDcError) exceeds tolerance \(tolerance)")
        XCTAssertLessThanOrEqual(maxGreenBpError, tolerance, "Max green_bp error \(maxGreenBpError) exceeds tolerance \(tolerance)")
    }
}
