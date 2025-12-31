//
//  CompressionTests.swift
//  OralableCoreTests
//
//  Created: December 31, 2025
//  Tests for Data+Compression utilities
//

import XCTest
@testable import OralableCore

// MARK: - CompressionAlgorithm Tests

final class CompressionAlgorithmTests: XCTestCase {

    func testAlgorithmCases() {
        // Verify all algorithms exist
        let _ = CompressionAlgorithm.lzfse
        let _ = CompressionAlgorithm.lz4
        let _ = CompressionAlgorithm.lzma
        let _ = CompressionAlgorithm.zlib
    }
}

// MARK: - Data Compression Tests

final class DataCompressionTests: XCTestCase {

    // MARK: - Basic Compression Tests

    func testCompressEmptyData() {
        let data = Data()
        XCTAssertNil(data.compressed())
    }

    func testCompressSmallData() {
        let data = "Hello, World!".data(using: .utf8)!
        let compressed = data.compressed()

        XCTAssertNotNil(compressed)
    }

    func testCompressLargeRepetitiveData() {
        // Repetitive data should compress well
        let repeated = String(repeating: "ABCDEFGHIJ", count: 1000)
        let data = repeated.data(using: .utf8)!
        let compressed = data.compressed()

        XCTAssertNotNil(compressed)
        XCTAssertLessThan(compressed!.count, data.count)
    }

    func testCompressRandomData() {
        // Random data may not compress well
        var bytes = [UInt8](repeating: 0, count: 1000)
        for i in 0..<1000 {
            bytes[i] = UInt8.random(in: 0...255)
        }
        let data = Data(bytes)
        let compressed = data.compressed()

        XCTAssertNotNil(compressed)
        // Random data might be similar or larger
    }

    // MARK: - Decompression Tests

    func testDecompressEmptyData() {
        let data = Data()
        XCTAssertNil(data.decompressed(expectedSize: 100))
    }

    func testDecompressInvalidExpectedSize() {
        let data = "Hello".data(using: .utf8)!
        let compressed = data.compressed()!

        XCTAssertNil(compressed.decompressed(expectedSize: 0))
        XCTAssertNil(compressed.decompressed(expectedSize: -10))
    }

    func testCompressDecompressRoundTrip() {
        let original = "The quick brown fox jumps over the lazy dog. ".data(using: .utf8)!
        let compressed = original.compressed()!
        let decompressed = compressed.decompressed(expectedSize: original.count)

        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed, original)
    }

    func testCompressDecompressLargeData() {
        let largeString = String(repeating: "Swift is a powerful programming language. ", count: 500)
        let original = largeString.data(using: .utf8)!
        let compressed = original.compressed()!
        let decompressed = compressed.decompressed(expectedSize: original.count)

        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed, original)
    }

    // MARK: - Algorithm Tests

    func testCompressWithLZFSE() {
        let data = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        let compressed = data.compressed(algorithm: .lzfse)

        XCTAssertNotNil(compressed)
        XCTAssertLessThan(compressed!.count, data.count)

        let decompressed = compressed!.decompressed(expectedSize: data.count, algorithm: .lzfse)
        XCTAssertEqual(decompressed, data)
    }

    func testCompressWithLZ4() {
        let data = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        let compressed = data.compressed(algorithm: .lz4)

        XCTAssertNotNil(compressed)

        let decompressed = compressed!.decompressed(expectedSize: data.count, algorithm: .lz4)
        XCTAssertEqual(decompressed, data)
    }

    func testCompressWithLZMA() {
        let data = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        let compressed = data.compressed(algorithm: .lzma)

        XCTAssertNotNil(compressed)

        let decompressed = compressed!.decompressed(expectedSize: data.count, algorithm: .lzma)
        XCTAssertEqual(decompressed, data)
    }

    func testCompressWithZLIB() {
        let data = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        let compressed = data.compressed(algorithm: .zlib)

        XCTAssertNotNil(compressed)

        let decompressed = compressed!.decompressed(expectedSize: data.count, algorithm: .zlib)
        XCTAssertEqual(decompressed, data)
    }

    // MARK: - Compression Ratio Tests

    func testCompressionRatio() {
        let data = String(repeating: "AAAA", count: 1000).data(using: .utf8)!
        let ratio = data.compressionRatio()

        XCTAssertNotNil(ratio)
        XCTAssertLessThan(ratio!, 1.0) // Highly compressible
    }

    func testCompressionRatioEmptyData() {
        let data = Data()
        XCTAssertNil(data.compressionRatio())
    }

    func testCompressionRatioWithAlgorithm() {
        let data = String(repeating: "Compression test ", count: 100).data(using: .utf8)!

        let lzfseRatio = data.compressionRatio(algorithm: .lzfse)
        let lz4Ratio = data.compressionRatio(algorithm: .lz4)
        let lzmaRatio = data.compressionRatio(algorithm: .lzma)
        let zlibRatio = data.compressionRatio(algorithm: .zlib)

        XCTAssertNotNil(lzfseRatio)
        XCTAssertNotNil(lz4Ratio)
        XCTAssertNotNil(lzmaRatio)
        XCTAssertNotNil(zlibRatio)

        // LZMA typically has best compression ratio
        // LZ4 typically has worst (but fastest)
    }

    // MARK: - JSON Compression Tests

    func testCompressCodableObject() {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
            let values: [Double]
        }

        let object = TestObject(id: 1, name: "Test", values: [1.0, 2.0, 3.0, 4.0, 5.0])
        let compressed = Data.compress(object)

        XCTAssertNotNil(compressed)
    }

    func testDecompressToObject() {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
        }

        let original = TestObject(id: 42, name: "Hello")
        let jsonData = try! JSONEncoder().encode(original)
        let compressed = jsonData.compressed()!

        let decompressed: TestObject? = compressed.decompressedObject(
            TestObject.self,
            expectedSize: jsonData.count
        )

        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed, original)
    }

    func testCompressDecompressComplexObject() {
        struct ComplexObject: Codable, Equatable {
            let timestamp: Date
            let readings: [Double]
            let metadata: [String: String]
        }

        let original = ComplexObject(
            timestamp: Date(),
            readings: Array(repeating: 1.5, count: 100),
            metadata: ["key1": "value1", "key2": "value2"]
        )

        let compressed = Data.compress(original)
        XCTAssertNotNil(compressed)

        // For decompression, we need to know the original JSON size
        let jsonData = try! JSONEncoder().encode(original)
        let compressedJson = jsonData.compressed()!

        let decompressed: ComplexObject? = compressedJson.decompressedObject(
            ComplexObject.self,
            expectedSize: jsonData.count
        )

        XCTAssertNotNil(decompressed)
        XCTAssertEqual(decompressed?.readings, original.readings)
        XCTAssertEqual(decompressed?.metadata, original.metadata)
    }

    // MARK: - Compressed With Stats Tests

    func testCompressedWithStats() {
        let data = String(repeating: "Statistics test ", count: 100).data(using: .utf8)!
        let result = data.compressedWithStats()

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.stats.originalSize, data.count)
        XCTAssertEqual(result!.stats.compressedSize, result!.data.count)
    }
}

// MARK: - CompressionStats Tests

final class CompressionStatsTests: XCTestCase {

    func testCompressionStatsCreation() {
        let stats = CompressionStats(originalSize: 1000, compressedSize: 250)

        XCTAssertEqual(stats.originalSize, 1000)
        XCTAssertEqual(stats.compressedSize, 250)
    }

    func testRatioCalculation() {
        let stats = CompressionStats(originalSize: 1000, compressedSize: 250)

        XCTAssertEqual(stats.ratio, 0.25, accuracy: 0.001)
    }

    func testRatioWithZeroOriginalSize() {
        let stats = CompressionStats(originalSize: 0, compressedSize: 100)

        XCTAssertEqual(stats.ratio, 1.0)
    }

    func testSavingsPercentage() {
        let stats = CompressionStats(originalSize: 1000, compressedSize: 250)

        XCTAssertEqual(stats.savingsPercentage, 75.0, accuracy: 0.1)
    }

    func testSavingsPercentageNoSavings() {
        let stats = CompressionStats(originalSize: 100, compressedSize: 100)

        XCTAssertEqual(stats.savingsPercentage, 0.0, accuracy: 0.1)
    }

    func testSavingsPercentageNegative() {
        // When compressed is larger than original
        let stats = CompressionStats(originalSize: 100, compressedSize: 120)

        XCTAssertEqual(stats.savingsPercentage, -20.0, accuracy: 0.1)
    }

    func testDescription() {
        let stats = CompressionStats(originalSize: 10000, compressedSize: 2500)

        let description = stats.description
        XCTAssertTrue(description.contains("75"))
        XCTAssertTrue(description.contains("savings"))
    }

    func testDescriptionWithVariousSizes() {
        // Small sizes
        let small = CompressionStats(originalSize: 100, compressedSize: 50)
        XCTAssertFalse(small.description.isEmpty)

        // Large sizes
        let large = CompressionStats(originalSize: 10_000_000, compressedSize: 1_000_000)
        XCTAssertFalse(large.description.isEmpty)
    }
}
