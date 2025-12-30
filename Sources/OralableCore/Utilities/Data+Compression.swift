//
//  Data+Compression.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Data compression utilities for CloudKit data exchange
//

import Foundation
import Compression

// MARK: - Compression Algorithm

/// Supported compression algorithms
public enum CompressionAlgorithm {
    case lzfse   // Apple's fast compression (default)
    case lz4     // Very fast, lower compression ratio
    case lzma    // High compression, slower
    case zlib    // Standard, good balance

    var algorithm: compression_algorithm {
        switch self {
        case .lzfse: return COMPRESSION_LZFSE
        case .lz4: return COMPRESSION_LZ4
        case .lzma: return COMPRESSION_LZMA
        case .zlib: return COMPRESSION_ZLIB
        }
    }
}

// MARK: - Data Extension

public extension Data {

    // MARK: - Decompression

    /// Decompress data using LZFSE algorithm (default for CloudKit)
    /// - Parameter expectedSize: Expected size of decompressed data
    /// - Returns: Decompressed data, or nil if decompression fails
    func decompressed(expectedSize: Int) -> Data? {
        decompressed(expectedSize: expectedSize, algorithm: .lzfse)
    }

    /// Decompress data using specified algorithm
    /// - Parameters:
    ///   - expectedSize: Expected size of decompressed data
    ///   - algorithm: Compression algorithm used
    /// - Returns: Decompressed data, or nil if decompression fails
    func decompressed(expectedSize: Int, algorithm: CompressionAlgorithm) -> Data? {
        guard !isEmpty else { return nil }
        guard expectedSize > 0 else { return nil }

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                expectedSize,
                sourcePointer,
                count,
                nil,
                algorithm.algorithm
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }

    // MARK: - Compression

    /// Compress data using LZFSE algorithm (default for CloudKit)
    /// - Returns: Compressed data, or nil if compression fails
    func compressed() -> Data? {
        compressed(algorithm: .lzfse)
    }

    /// Compress data using specified algorithm
    /// - Parameter algorithm: Compression algorithm to use
    /// - Returns: Compressed data, or nil if compression fails
    func compressed(algorithm: CompressionAlgorithm) -> Data? {
        guard !isEmpty else { return nil }

        // Allocate buffer for worst-case scenario (data doesn't compress)
        let bufferSize = count + 512
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let compressedSize = withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                bufferSize,
                sourcePointer,
                count,
                nil,
                algorithm.algorithm
            )
        }

        guard compressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    // MARK: - Compression Ratio

    /// Calculate compression ratio for this data
    /// - Parameter algorithm: Algorithm to test
    /// - Returns: Compression ratio (compressed/original), or nil if compression fails
    func compressionRatio(algorithm: CompressionAlgorithm = .lzfse) -> Double? {
        guard let compressed = compressed(algorithm: algorithm) else { return nil }
        guard !isEmpty else { return nil }
        return Double(compressed.count) / Double(count)
    }

    // MARK: - JSON Compression Helpers

    /// Compress a Codable object to Data
    /// - Parameters:
    ///   - object: Object to compress
    ///   - algorithm: Compression algorithm
    /// - Returns: Compressed data, or nil if encoding/compression fails
    static func compress<T: Encodable>(_ object: T, algorithm: CompressionAlgorithm = .lzfse) -> Data? {
        do {
            let jsonData = try JSONEncoder().encode(object)
            return jsonData.compressed(algorithm: algorithm)
        } catch {
            return nil
        }
    }

    /// Decompress and decode to a Codable object
    /// - Parameters:
    ///   - type: Type to decode to
    ///   - expectedSize: Expected decompressed size
    ///   - algorithm: Compression algorithm used
    /// - Returns: Decoded object, or nil if decompression/decoding fails
    func decompressedObject<T: Decodable>(
        _ type: T.Type,
        expectedSize: Int,
        algorithm: CompressionAlgorithm = .lzfse
    ) -> T? {
        guard let decompressedData = decompressed(expectedSize: expectedSize, algorithm: algorithm) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(type, from: decompressedData)
        } catch {
            return nil
        }
    }
}

// MARK: - Compression Statistics

/// Statistics about compression operation
public struct CompressionStats: Sendable {
    /// Original data size in bytes
    public let originalSize: Int

    /// Compressed data size in bytes
    public let compressedSize: Int

    /// Compression ratio (0.0 - 1.0, lower is better)
    public var ratio: Double {
        guard originalSize > 0 else { return 1.0 }
        return Double(compressedSize) / Double(originalSize)
    }

    /// Space savings percentage (0-100)
    public var savingsPercentage: Double {
        (1.0 - ratio) * 100.0
    }

    /// Human-readable description
    public var description: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let originalStr = formatter.string(fromByteCount: Int64(originalSize))
        let compressedStr = formatter.string(fromByteCount: Int64(compressedSize))
        return "\(originalStr) -> \(compressedStr) (\(String(format: "%.1f", savingsPercentage))% savings)"
    }

    public init(originalSize: Int, compressedSize: Int) {
        self.originalSize = originalSize
        self.compressedSize = compressedSize
    }
}

public extension Data {

    /// Compress and return statistics
    func compressedWithStats(algorithm: CompressionAlgorithm = .lzfse) -> (data: Data, stats: CompressionStats)? {
        guard let compressed = compressed(algorithm: algorithm) else { return nil }
        let stats = CompressionStats(originalSize: count, compressedSize: compressed.count)
        return (compressed, stats)
    }
}
