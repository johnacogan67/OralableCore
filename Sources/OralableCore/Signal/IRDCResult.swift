//
//  IRDCResult.swift
//  OralableCore
//
//  Value type for IR DC analysis. Processor: `Algorithms/IRDCProcessor`.
//

import Foundation

// MARK: - IR DC Result

/// Result from IR DC analysis
public struct IRDCResult: Sendable {
    /// Current DC value (low-frequency component)
    public let dcValue: Double

    /// 5-second rolling mean of DC
    public let rollingMean5s: Double

    /// DC shift from baseline (positive = drop = occlusion/muscle activity)
    public let shift5s: Double

    /// Current normalized IR value (percentage above/below baseline)
    public let normalizedPercent: Double?

    /// Relative occlusion drop over the rolling mean (percent).
    public var relativeDropPercent5s: Double {
        guard rollingMean5s > 1e-9 else { return 0 }
        return (shift5s / rollingMean5s) * 100.0
    }

    /// Whether shift indicates significant muscle activity
    public var indicatesActivity: Bool {
        shift5s > AlgorithmSpec.irDCShiftThreshold ||
            relativeDropPercent5s > AlgorithmSpec.irDCRelativeDropThresholdPercent
    }

    /// Whether normalized value exceeds activity threshold
    public var isAboveActivityThreshold: Bool {
        guard let normalized = normalizedPercent else { return false }
        return normalized > AlgorithmSpec.activityThresholdPercent
    }

    public init(
        dcValue: Double,
        rollingMean5s: Double,
        shift5s: Double,
        normalizedPercent: Double? = nil
    ) {
        self.dcValue = dcValue
        self.rollingMean5s = rollingMean5s
        self.shift5s = shift5s
        self.normalizedPercent = normalizedPercent
    }

    /// Empty result
    public static let empty = IRDCResult(dcValue: 0, rollingMean5s: 0, shift5s: 0)
}
