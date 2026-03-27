//
//  PPGProcessorResult.swift
//  OralableCore
//
//  Result value for PPG heart-rate processing. Processor: `Algorithms/PPGProcessor`.
//

import Foundation

// MARK: - PPG Processor Result

/// Result from PPG processing
public struct PPGProcessorResult: Sendable {
    /// Heart rate in BPM (nil if not enough data)
    public let heartRateBPM: Int?

    /// Heart rate quality score (0.0 - 1.0)
    public let quality: Double

    /// Number of peaks detected
    public let peakCount: Int

    /// Inter-beat intervals in seconds
    public let rrIntervals: [Double]

    /// Whether the signal is stable enough for HR calculation
    public var isValid: Bool {
        heartRateBPM != nil && quality > 0.5
    }

    public init(
        heartRateBPM: Int? = nil,
        quality: Double = 0,
        peakCount: Int = 0,
        rrIntervals: [Double] = []
    ) {
        self.heartRateBPM = heartRateBPM
        self.quality = quality
        self.peakCount = peakCount
        self.rrIntervals = rrIntervals
    }

    /// Empty result when no valid data
    public static let empty = PPGProcessorResult()
}
