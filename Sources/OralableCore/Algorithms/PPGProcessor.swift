//
//  PPGProcessor.swift
//  OralableCore
//
//  Peak detection and heart-rate estimation; streaming processor with scipy-parity HR bandpass.
//  Reference: cursor_oralable/src/analysis/features.py detect_beats_from_green_bp()
//

import Foundation

// MARK: - PPG Processor

/// Processes PPG signals to extract heart rate and pulse features.
public final class PPGProcessor {

    // MARK: - Bandpassed HR (real-time windows)

    /// Heart rate from samples **already** bandpassed (0.5–8 Hz), using `AlgorithmSpec` peak rules.
    public static func heartRateFromBandpassedSignal(
        _ signal: [Double],
        sampleRate: Double,
        minBPM: Double = AlgorithmSpec.minHeartRate,
        maxBPM: Double = AlgorithmSpec.maxHeartRate,
        minStdForDetection: Double = 1.0
    ) -> (bpm: Int, quality: Double)? {
        guard signal.count >= Int(sampleRate * AlgorithmSpec.minSignalBufferSeconds) else { return nil }

        let mean = signal.reduce(0, +) / Double(signal.count)
        let sumSquaredDiff = signal.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(signal.count))

        guard stdDev > minStdForDetection else { return nil }

        let minDistanceSamples = max(1, Int(AlgorithmSpec.minPeakDistanceSeconds * sampleRate))
        let minProm = stdDev * AlgorithmSpec.peakProminenceMultiplier

        let peaks = peakIndices(signal: signal, minDistanceSamples: minDistanceSamples, minProminence: minProm)
        guard peaks.count >= 2 else { return nil }

        var intervals: [Double] = []
        let minInterval = 60.0 / maxBPM
        let maxInterval = 60.0 / minBPM
        for j in 1..<peaks.count {
            let intervalSamples = Double(peaks[j] - peaks[j - 1])
            let intervalSeconds = intervalSamples / sampleRate
            if intervalSeconds >= minInterval && intervalSeconds <= maxInterval {
                intervals.append(intervalSeconds)
            }
        }

        guard !intervals.isEmpty else { return nil }

        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        let bpm = Int(60.0 / medianInterval)

        guard bpm >= Int(minBPM) && bpm <= Int(maxBPM) else { return nil }

        let acdc = min(1.0, stdDev / max(1.0, abs(mean)))
        let peakFactor = min(1.0, Double(intervals.count) / 10.0)
        let quality = max(0, min(1.0, 0.6 * acdc + 0.4 * peakFactor))

        return (bpm, quality)
    }

    /// SciPy-style prominence + minimum distance (matches `find_peaks` constraints in research tooling).
    private static func peakIndices(signal: [Double], minDistanceSamples: Int, minProminence: Double) -> [Int] {
        var peaks: [Int] = []
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            guard current > signal[i - 1] && current > signal[i + 1] else { continue }
            guard current > signal[i - 2] && current > signal[i + 2] else { continue }

            let leftMin = signal[max(0, i - minDistanceSamples)..<i].min() ?? current
            let rightMin = signal[(i + 1)..<min(signal.count, i + minDistanceSamples + 1)].min() ?? current
            let prominence = current - max(leftMin, rightMin)
            guard prominence >= minProminence else { continue }

            if let last = peaks.last {
                guard i - last >= minDistanceSamples else { continue }
            }
            peaks.append(i)
        }
        return peaks
    }

    // MARK: - Streaming / batch (filtfilt HR bandpass)

    public let sampleRate: Double
    private let minPeakDistanceSamples: Int
    private let maxBufferSize: Int
    private let minSamplesRequired: Int
    private let bandpassFilter: TransferFunctionFilter

    private var signalBuffer: [Double] = []
    private var filteredBuffer: [Double] = []
    private var peakIndicesStorage: [Int] = []
    private var peakTimes: [Date] = []

    public private(set) var currentHeartRate: Int?
    public private(set) var currentQuality: Double = 0

    public init(sampleRate: Double = AlgorithmSpec.ppgSampleRate) {
        self.sampleRate = sampleRate
        self.maxBufferSize = Int(sampleRate * AlgorithmSpec.maxSignalBufferSeconds)
        self.minSamplesRequired = Int(sampleRate * AlgorithmSpec.minSignalBufferSeconds)
        self.minPeakDistanceSamples = Int(AlgorithmSpec.minPeakDistanceSeconds * sampleRate)
        self.bandpassFilter = TransferFunctionFilter.hrBandpass()
    }

    public func process(_ sample: PPGData) -> PPGProcessorResult {
        processSample(Double(sample.green), timestamp: sample.timestamp)
    }

    public func processSample(_ value: Double, timestamp: Date) -> PPGProcessorResult {
        signalBuffer.append(value)
        if signalBuffer.count > maxBufferSize {
            let excess = signalBuffer.count - maxBufferSize
            signalBuffer.removeFirst(excess)
        }
        guard signalBuffer.count >= minSamplesRequired else {
            return PPGProcessorResult()
        }
        return calculateHeartRate(latestTimestamp: timestamp)
    }

    public func processBatch(_ samples: [PPGData]) -> PPGProcessorResult {
        guard !samples.isEmpty else { return PPGProcessorResult() }
        for sample in samples {
            signalBuffer.append(Double(sample.green))
        }
        if signalBuffer.count > maxBufferSize {
            let excess = signalBuffer.count - maxBufferSize
            signalBuffer.removeFirst(excess)
        }
        let latestTimestamp = samples.last?.timestamp ?? Date()
        return calculateHeartRate(latestTimestamp: latestTimestamp)
    }

    private func calculateHeartRate(latestTimestamp: Date) -> PPGProcessorResult {
        guard signalBuffer.count >= minSamplesRequired else {
            return PPGProcessorResult()
        }

        let filtered = bandpassFilter.filtfilt(signalBuffer)
        filteredBuffer = filtered

        let mean = filtered.reduce(0, +) / Double(filtered.count)
        let sumSquaredDiff = filtered.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(filtered.count))

        guard stdDev > 1.0 else {
            return PPGProcessorResult(quality: 0)
        }

        let prominence = stdDev * AlgorithmSpec.peakProminenceMultiplier
        let peaks = Self.peakIndices(
            signal: filtered,
            minDistanceSamples: minPeakDistanceSamples,
            minProminence: prominence
        )
        peakIndicesStorage = peaks

        guard peaks.count >= 2 else {
            return PPGProcessorResult(quality: 0.2, peakCount: peaks.count)
        }

        var rrIntervals: [Double] = []
        let minInterval = 60.0 / AlgorithmSpec.maxHeartRate
        let maxInterval = 60.0 / AlgorithmSpec.minHeartRate

        for i in 1..<peaks.count {
            let intervalSamples = Double(peaks[i] - peaks[i - 1])
            let intervalSeconds = intervalSamples / sampleRate
            if intervalSeconds >= minInterval && intervalSeconds <= maxInterval {
                rrIntervals.append(intervalSeconds)
            }
        }

        guard !rrIntervals.isEmpty else {
            return PPGProcessorResult(quality: 0.3, peakCount: peaks.count)
        }

        let sortedIntervals = rrIntervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        let bpm = Int(60.0 / medianInterval)

        guard bpm >= Int(AlgorithmSpec.minHeartRate) && bpm <= Int(AlgorithmSpec.maxHeartRate) else {
            return PPGProcessorResult(quality: 0.4, peakCount: peaks.count, rrIntervals: rrIntervals)
        }

        let quality = calculateQuality(stdDev: stdDev, mean: mean, peakCount: peaks.count, rrIntervals: rrIntervals)
        currentHeartRate = bpm
        currentQuality = quality
        updatePeakTimes(peaks: peaks, latestTimestamp: latestTimestamp)

        return PPGProcessorResult(
            heartRateBPM: bpm,
            quality: quality,
            peakCount: peaks.count,
            rrIntervals: rrIntervals
        )
    }

    private func calculateQuality(stdDev: Double, mean: Double, peakCount: Int, rrIntervals: [Double]) -> Double {
        var score = 0.0
        let acdc = min(1.0, stdDev / max(1.0, abs(mean)))
        score += 0.3 * acdc
        let peakFactor = min(1.0, Double(peakCount) / 10.0)
        score += 0.3 * peakFactor
        if rrIntervals.count >= 2 {
            let rrMean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
            let rrVariance = rrIntervals.map { pow($0 - rrMean, 2) }.reduce(0, +) / Double(rrIntervals.count)
            let rrStd = sqrt(rrVariance)
            let cv = rrStd / max(0.001, rrMean)
            let consistencyScore = max(0, 1.0 - cv * 2)
            score += 0.4 * consistencyScore
        }
        return max(0, min(1.0, score))
    }

    private func updatePeakTimes(peaks: [Int], latestTimestamp: Date) {
        peakTimes.removeAll()
        let sampleInterval = 1.0 / sampleRate
        let bufferDuration = Double(signalBuffer.count) * sampleInterval
        let bufferStartTime = latestTimestamp.addingTimeInterval(-bufferDuration)
        for peakIndex in peaks {
            let peakTime = bufferStartTime.addingTimeInterval(Double(peakIndex) * sampleInterval)
            peakTimes.append(peakTime)
        }
    }

    public func getRecentPeakTimes() -> [Date] { peakTimes }

    public func getRRIntervalsMs() -> [Double] {
        guard peakTimes.count >= 2 else { return [] }
        var intervals: [Double] = []
        for i in 1..<peakTimes.count {
            intervals.append(peakTimes[i].timeIntervalSince(peakTimes[i - 1]) * 1000.0)
        }
        return intervals
    }

    public func reset() {
        signalBuffer.removeAll()
        filteredBuffer.removeAll()
        peakIndicesStorage.removeAll()
        peakTimes.removeAll()
        currentHeartRate = nil
        currentQuality = 0
        bandpassFilter.reset()
    }
}

extension PPGProcessor: @unchecked Sendable {}
