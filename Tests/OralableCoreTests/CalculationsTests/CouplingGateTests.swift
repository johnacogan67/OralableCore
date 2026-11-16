//
//  CouplingGateTests.swift
//  OralableCoreTests
//
//  Parity with cursor_oralable/tests/test_coupling_gate.py
//

import XCTest
@testable import OralableCore

final class CouplingGateTests: XCTestCase {

    func testCoupleLabel() {
        XCTAssertEqual(CoupleLabel.label(nil), "unknown")
        XCTAssertEqual(CoupleLabel.label(.desk), "desk")
        XCTAssertEqual(CoupleLabel.label(.poor), "poor")
        XCTAssertEqual(CoupleLabel.label(.good), "ok")
    }

    func testUnknownWithoutSamples() {
        let g = CouplingGate()
        XCTAssertNil(g.state)
        XCTAssertFalse(g.streamsReady)
    }

    func testUnknownAccOnly() {
        let g = CouplingGate(requireAcc: true)
        var t = 0.0
        for _ in 0..<20 {
            g.feedAccMagnitudes(Array(repeating: 1000, count: 10), monoS: t)
            t += 0.1
        }
        XCTAssertNil(g.state)
        XCTAssertFalse(g.streamsReady)
    }

    func testDeskFlatIRStillAcc() {
        let g = CouplingGate(requireAcc: true)
        var t = 0.0
        for _ in 0..<10 {
            g.feedAccMagnitudes(Array(repeating: 16000, count: 10), monoS: t)
            t += 0.05
        }
        for _ in 0..<200 {
            g.feedPPGSamples(irSamples: Array(repeating: 500, count: 5), monoS: t)
            t += 0.02
        }
        XCTAssertTrue(g.streamsReady)
        XCTAssertEqual(g.state, .desk)
    }

    func testPoorDCNoPulse() {
        let g = CouplingGate(requireAcc: true, allowPPGOnly: false)
        var t = 0.0
        for _ in 0..<10 {
            g.feedAccMagnitudes(Array(repeating: 16000, count: 5), monoS: t)
            t += 0.05
        }
        for _ in 0..<300 {
            g.feedPPGSamples(irSamples: Array(repeating: 30_000_000, count: 5), monoS: t)
            t += 0.02
        }
        XCTAssertEqual(g.state, .poor)
    }

    func testGoodPulseAndHR() {
        let g = CouplingGate(requireAcc: true)
        var t = 0.0
        for _ in 0..<10 {
            g.feedAccMagnitudes(Array(repeating: 16000, count: 5), monoS: t)
            t += 0.05
        }
        let fs = 50.0
        for i in 0..<400 {
            let phase = 2 * Double.pi * 1.0 * (Double(i) / fs)
            let ir = Int(30_000_000 + 80_000 * sin(phase))
            let red = Int(28_000_000 + 60_000 * sin(phase))
            g.feedPPGSamples(irSamples: [ir], monoS: t, reds: [red])
            t += 1.0 / fs
        }
        XCTAssertTrue(g.isPulseLatched)
        XCTAssertEqual(g.state, .good)
    }

    func testPPGStallMarksUnknown() {
        let g = CouplingGate(requireAcc: true)
        let t = 1.0
        g.feedAccMagnitudes(Array(repeating: 16000, count: 10), monoS: t)
        g.feedPPGSamples(irSamples: Array(repeating: 30_000_000, count: 5), monoS: t)
        XCTAssertTrue(g.streamsReady)
        g.tick(monoS: t + 9.0)
        XCTAssertNil(g.state)
    }

    func testOnDockForcesUnknown() {
        let g = CouplingGate(requireAcc: true, allowPPGOnly: true)
        var t = 0.0
        g.setOnDock(true)
        for _ in 0..<100 {
            g.feedPPGSamples(irSamples: Array(repeating: 30_000_000, count: 5), monoS: t)
            t += 0.02
        }
        XCTAssertNil(g.state)
    }
}
