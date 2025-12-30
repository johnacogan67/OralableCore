//
//  SensorDataBuffer.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Thread-safe sensor data buffer for history management
//  Framework-agnostic implementation using Swift actors
//

import Foundation
import Combine

// MARK: - Sensor Data Buffer

/// Thread-safe buffer for managing sensor data history
/// Uses Swift actor for safe concurrent access
public actor SensorDataBuffer {

    // MARK: - Properties

    /// Maximum number of data points to store
    public let maxCapacity: Int

    /// Current sensor data history
    private var history: [SensorData] = []

    /// Subject for publishing new data (nonisolated for Combine compatibility)
    private nonisolated(unsafe) let dataSubject = PassthroughSubject<SensorData, Never>()

    /// Subject for publishing batch data (nonisolated for Combine compatibility)
    private nonisolated(unsafe) let batchSubject = PassthroughSubject<[SensorData], Never>()

    // MARK: - Initialization

    /// Initialize buffer with specified capacity
    /// - Parameter maxCapacity: Maximum number of data points to store (default: 10000)
    public init(maxCapacity: Int = 10000) {
        self.maxCapacity = maxCapacity
        self.history.reserveCapacity(min(maxCapacity, 1000))
    }

    // MARK: - Data Access

    /// Get all data in the buffer
    public var allData: [SensorData] {
        return history
    }

    /// Get the count of items in the buffer
    public var count: Int {
        return history.count
    }

    /// Check if buffer is empty
    public var isEmpty: Bool {
        return history.isEmpty
    }

    /// Get the most recent data point
    public var latest: SensorData? {
        return history.last
    }

    /// Get the oldest data point
    public var oldest: SensorData? {
        return history.first
    }

    /// Get data points within a time range
    /// - Parameters:
    ///   - start: Start timestamp
    ///   - end: End timestamp (default: now)
    /// - Returns: Array of SensorData within the range
    public func data(from start: Date, to end: Date = Date()) -> [SensorData] {
        return history.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    /// Get the last N data points
    /// - Parameter count: Number of data points to retrieve
    /// - Returns: Array of the most recent SensorData
    public func lastN(_ count: Int) -> [SensorData] {
        return Array(history.suffix(count))
    }

    // MARK: - Data Modification

    /// Append a single data point to the buffer
    /// - Parameter data: SensorData to append
    public func append(_ data: SensorData) {
        history.append(data)

        // Trim if over capacity
        if history.count > maxCapacity {
            history.removeFirst(history.count - maxCapacity)
        }

        // Publish to subscribers
        dataSubject.send(data)
    }

    /// Append multiple data points to the buffer
    /// - Parameter data: Array of SensorData to append
    public func append(contentsOf data: [SensorData]) {
        guard !data.isEmpty else { return }

        history.append(contentsOf: data)

        // Trim if over capacity
        if history.count > maxCapacity {
            history.removeFirst(history.count - maxCapacity)
        }

        // Publish batch to subscribers
        batchSubject.send(data)

        // Also publish individually for single-item subscribers
        for item in data {
            dataSubject.send(item)
        }
    }

    /// Clear all data from the buffer
    public func clear() {
        history.removeAll()
    }

    /// Remove data older than the specified date
    /// - Parameter date: Cutoff date
    /// - Returns: Number of items removed
    @discardableResult
    public func removeData(before date: Date) -> Int {
        let originalCount = history.count
        history.removeAll { $0.timestamp < date }
        return originalCount - history.count
    }

    /// Remove data older than the specified time interval
    /// - Parameter interval: Time interval in seconds
    /// - Returns: Number of items removed
    @discardableResult
    public func removeData(olderThan interval: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-interval)
        return removeData(before: cutoff)
    }

    // MARK: - Publishers

    /// Publisher for individual data points
    public nonisolated var dataPublisher: AnyPublisher<SensorData, Never> {
        dataSubject.eraseToAnyPublisher()
    }

    /// Publisher for batch data
    public nonisolated var batchPublisher: AnyPublisher<[SensorData], Never> {
        batchSubject.eraseToAnyPublisher()
    }

    // MARK: - Statistics

    /// Calculate statistics for a specific sensor type within a time range
    /// - Parameters:
    ///   - type: Sensor type to analyze
    ///   - duration: Time duration to analyze (default: 60 seconds)
    /// - Returns: Statistics or nil if insufficient data
    public func statistics(for type: SensorType, duration: TimeInterval = 60) -> BufferStatistics? {
        let cutoff = Date().addingTimeInterval(-duration)
        let recentData = history.filter { $0.timestamp >= cutoff }

        guard !recentData.isEmpty else { return nil }

        let values: [Double] = recentData.compactMap { data -> Double? in
            switch type {
            case .heartRate:
                return data.heartRate.map { Double($0.bpm) }
            case .spo2:
                return data.spo2.map { Double($0.percentage) }
            case .temperature:
                return data.temperature.celsius
            case .battery:
                return Double(data.battery.percentage)
            case .accelerometerX:
                return AccelerometerConversion.toG(rawValue: data.accelerometer.x)
            case .accelerometerY:
                return AccelerometerConversion.toG(rawValue: data.accelerometer.y)
            case .accelerometerZ:
                return AccelerometerConversion.toG(rawValue: data.accelerometer.z)
            case .ppgRed:
                return Double(data.ppg.red)
            case .ppgInfrared:
                return Double(data.ppg.ir)
            case .ppgGreen:
                return Double(data.ppg.green)
            case .emg, .muscleActivity:
                return nil  // Not applicable for Oralable SensorData
            }
        }

        guard !values.isEmpty else { return nil }

        let sum = values.reduce(0, +)
        let mean = sum / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0

        // Calculate standard deviation
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)

        return BufferStatistics(
            sensorType: type,
            sampleCount: values.count,
            mean: mean,
            min: min,
            max: max,
            standardDeviation: stdDev,
            duration: duration
        )
    }
}

// MARK: - Buffer Statistics

/// Statistical summary for buffered sensor data
/// Named BufferStatistics to avoid conflict with SensorStatistics in SensorDataRepository
public struct BufferStatistics: Sendable {
    /// Type of sensor
    public let sensorType: SensorType

    /// Number of samples analyzed
    public let sampleCount: Int

    /// Mean value
    public let mean: Double

    /// Minimum value
    public let min: Double

    /// Maximum value
    public let max: Double

    /// Standard deviation
    public let standardDeviation: Double

    /// Time duration of the analysis
    public let duration: TimeInterval

    /// Coefficient of variation (stdDev / mean)
    public var coefficientOfVariation: Double {
        guard mean != 0 else { return 0 }
        return standardDeviation / abs(mean)
    }

    /// Sample rate (samples per second)
    public var sampleRate: Double {
        guard duration > 0 else { return 0 }
        return Double(sampleCount) / duration
    }
}

// MARK: - PPG Data Buffer

/// Specialized buffer for PPG data with signal processing support
public actor PPGDataBuffer {

    /// Maximum number of samples
    public let maxCapacity: Int

    /// PPG sample history
    private var samples: [PPGData] = []

    /// Subject for publishing new samples (nonisolated for Combine compatibility)
    private nonisolated(unsafe) let sampleSubject = PassthroughSubject<PPGData, Never>()

    /// Initialize buffer
    /// - Parameter maxCapacity: Maximum samples (default: 1000 = ~20 seconds at 50Hz)
    public init(maxCapacity: Int = 1000) {
        self.maxCapacity = maxCapacity
        self.samples.reserveCapacity(min(maxCapacity, 500))
    }

    /// Get all samples
    public var allSamples: [PPGData] {
        return samples
    }

    /// Get sample count
    public var count: Int {
        return samples.count
    }

    /// Get latest sample
    public var latest: PPGData? {
        return samples.last
    }

    /// Append a sample
    public func append(_ sample: PPGData) {
        samples.append(sample)

        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }

        sampleSubject.send(sample)
    }

    /// Append multiple samples
    public func append(contentsOf newSamples: [PPGData]) {
        samples.append(contentsOf: newSamples)

        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }

        for sample in newSamples {
            sampleSubject.send(sample)
        }
    }

    /// Clear all samples
    public func clear() {
        samples.removeAll()
    }

    /// Get last N samples
    public func lastN(_ count: Int) -> [PPGData] {
        return Array(samples.suffix(count))
    }

    /// Publisher for new samples
    public nonisolated var samplePublisher: AnyPublisher<PPGData, Never> {
        sampleSubject.eraseToAnyPublisher()
    }

    /// Get IR channel values for signal processing
    public var irValues: [Double] {
        return samples.map { Double($0.ir) }
    }

    /// Get Red channel values for signal processing
    public var redValues: [Double] {
        return samples.map { Double($0.red) }
    }

    /// Get Green channel values for signal processing
    public var greenValues: [Double] {
        return samples.map { Double($0.green) }
    }
}

// MARK: - Accelerometer Data Buffer

/// Specialized buffer for accelerometer data with motion analysis support
public actor AccelerometerDataBuffer {

    /// Maximum number of samples
    public let maxCapacity: Int

    /// Accelerometer sample history
    private var samples: [AccelerometerData] = []

    /// Subject for publishing new samples (nonisolated for Combine compatibility)
    private nonisolated(unsafe) let sampleSubject = PassthroughSubject<AccelerometerData, Never>()

    /// Initialize buffer
    /// - Parameter maxCapacity: Maximum samples (default: 500 = ~10 seconds at 50Hz)
    public init(maxCapacity: Int = 500) {
        self.maxCapacity = maxCapacity
        self.samples.reserveCapacity(min(maxCapacity, 250))
    }

    /// Get all samples
    public var allSamples: [AccelerometerData] {
        return samples
    }

    /// Get sample count
    public var count: Int {
        return samples.count
    }

    /// Get latest sample
    public var latest: AccelerometerData? {
        return samples.last
    }

    /// Append a sample
    public func append(_ sample: AccelerometerData) {
        samples.append(sample)

        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }

        sampleSubject.send(sample)
    }

    /// Append multiple samples
    public func append(contentsOf newSamples: [AccelerometerData]) {
        samples.append(contentsOf: newSamples)

        if samples.count > maxCapacity {
            samples.removeFirst(samples.count - maxCapacity)
        }

        for sample in newSamples {
            sampleSubject.send(sample)
        }
    }

    /// Clear all samples
    public func clear() {
        samples.removeAll()
    }

    /// Get last N samples
    public func lastN(_ count: Int) -> [AccelerometerData] {
        return Array(samples.suffix(count))
    }

    /// Publisher for new samples
    public nonisolated var samplePublisher: AnyPublisher<AccelerometerData, Never> {
        sampleSubject.eraseToAnyPublisher()
    }

    /// Get magnitude values for motion analysis
    public var magnitudes: [Double] {
        return samples.map { sample in
            AccelerometerConversion.magnitude(x: sample.x, y: sample.y, z: sample.z)
        }
    }

    /// Calculate average magnitude over recent samples
    /// - Parameter count: Number of samples to average (default: 50 = 1 second at 50Hz)
    public func averageMagnitude(samples count: Int = 50) -> Double {
        let recentMagnitudes = Array(magnitudes.suffix(count))
        guard !recentMagnitudes.isEmpty else { return 0 }
        return recentMagnitudes.reduce(0, +) / Double(recentMagnitudes.count)
    }

    /// Check if device is currently at rest
    /// - Parameter threshold: Magnitude deviation threshold (default: 0.1g)
    public func isAtRest(threshold: Double = 0.1) -> Bool {
        let avgMag = averageMagnitude()
        return abs(avgMag - 1.0) < threshold
    }
}
