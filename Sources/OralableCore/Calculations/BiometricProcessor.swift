//
//  BiometricProcessor.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Unified biometric processor combining HR, SpO2, motion compensation,
//  and activity detection from all PPG channels and accelerometer.
//

import Foundation

// MARK: - Unified Biometric Processor

/// Thread-safe biometric processor using Swift actors.
/// Processes PPG (IR, Red, Green) and accelerometer data to calculate:
/// - Heart rate with quality score
/// - SpO2 with quality score
/// - Activity classification (relaxed, clenching, grinding, motion)
/// - Worn detection via perfusion index
public actor BiometricProcessor {

    // MARK: - Configuration

    private let config: BiometricConfiguration

    // MARK: - Sub-processors

    private let motionCompensator: MotionCompensator
    private let activityClassifier: ActivityClassifier

    // MARK: - Signal Buffers

    private var irBuffer: [Double]
    private var redBuffer: [Double]
    private var greenBuffer: [Double]
    private var accelMagnitudeBuffer: [Double]
    /// Mac Protocol A SpO2 prep streams (LP 0.8 DC + BP 0.5–8 AC).
    private var redDCBuffer: [Double] = []
    private var irDCBuffer: [Double] = []
    private var redACSpO2Buffer: [Double] = []
    private var irACSpO2Buffer: [Double] = []

    // MARK: - Filter State (for real-time processing)

    private var irLowPass: Double = 0
    private var irHighPass: Double = 0
    private var greenLowPass: Double = 0
    private var greenHighPass: Double = 0

    private let redDCFilter = TransferFunctionFilter.irDCLowpass()
    private let irDCFilter = TransferFunctionFilter.irDCLowpass()
    private let redACSpO2Filter = TransferFunctionFilter.hrBandpass()
    private let irACSpO2Filter = TransferFunctionFilter.hrBandpass()

    // MARK: - Baseline State

    private var irBaseline: Double = 0
    private var isBaselineInitialized: Bool = false

    // MARK: - Initialization

    /// Initialize with configuration
    /// - Parameter config: Biometric configuration (default: Oralable 50 Hz)
    public init(config: BiometricConfiguration = .oralable) {
        self.config = config

        // Initialize sub-processors
        self.motionCompensator = MotionCompensator()
        self.activityClassifier = ActivityClassifier()

        // Initialize buffers with capacity
        let capacity = config.hrWindowSize
        self.irBuffer = []
        self.redBuffer = []
        self.greenBuffer = []
        self.accelMagnitudeBuffer = []

        irBuffer.reserveCapacity(capacity)
        redBuffer.reserveCapacity(capacity)
        greenBuffer.reserveCapacity(capacity)
        accelMagnitudeBuffer.reserveCapacity(capacity)
    }

    // MARK: - Real-time Processing

    /// Process a single frame of sensor data (called at sample rate, e.g., 50 Hz)
    /// - Parameters:
    ///   - ir: Infrared PPG value (primary HR source)
    ///   - red: Red PPG value (for SpO2)
    ///   - green: Green PPG value (backup HR source)
    ///   - accelX: Accelerometer X (raw, ~16384 = 1g)
    ///   - accelY: Accelerometer Y (raw)
    ///   - accelZ: Accelerometer Z (raw)
    ///   - temperatureC: Optional skin temperature (°C) for soft corroboration
    /// - Returns: BiometricResult with all calculated values
    public func process(
        ir: Double,
        red: Double,
        green: Double,
        accelX: Double,
        accelY: Double,
        accelZ: Double,
        temperatureC: Double? = nil
    ) -> BiometricResult {

        // Stage 1: Motion detection
        let motionLevel = calculateMotionLevel(x: accelX, y: accelY, z: accelZ)

        // Stage 2: Motion compensation
        let compensatedIR = motionCompensator.filter(signal: ir, noiseReference: motionLevel)
        let compensatedRed = motionCompensator.filter(signal: red, noiseReference: motionLevel)
        let compensatedGreen = motionCompensator.filter(signal: green, noiseReference: motionLevel)

        // Stage 3: Activity classification
        let activity = activityClassifier.classify(ir: compensatedIR, accMagnitude: motionLevel + 1.0)

        // Stage 4: Update buffers (HR on compensated; SpO2 prep on raw Mac path)
        updateBuffers(
            ir: compensatedIR,
            red: compensatedRed,
            green: compensatedGreen,
            motion: motionLevel,
            redRaw: red,
            irRaw: ir
        )

        // Stage 5: Check if we have enough data
        guard irBuffer.count >= config.hrWindowSize else {
            return BiometricResult(
                heartRate: 0,
                heartRateQuality: 0,
                heartRateSource: .unavailable,
                spo2: 0,
                spo2Quality: 0,
                perfusionIndex: 0,
                isWorn: false,
                activity: activity,
                motionLevel: motionLevel,
                signalStrength: .none,
                processingMethod: .realtime
            )
        }

        // Stage 6: Calculate perfusion index
        let perfusionIndex = calculatePerfusionIndex(signal: irBuffer)
        let signalStrength = SignalStrength(perfusionIndex: perfusionIndex)

        // Stage 7: Calculate heart rate (skip if too much motion)
        var heartRate = 0
        var heartRateQuality = 0.0
        var heartRateSource = HRSource.unavailable

        if activity != .motion {
            (heartRate, heartRateQuality, heartRateSource) = calculateHeartRate()
        }

        // Stage 8: SpO2 — Mac Protocol A parity: compute whenever window is full
        // (no perfusion / motion gate; missing values stay 0, never fake 98%).
        var spo2 = 0.0
        var spo2Quality = 0.0
        (spo2, spo2Quality) = calculateSpO2()

        // Soft ACC + skin-temp corroboration: quality / isWorn only (not SpO2/HR numbers).
        let qualityMul = SensorCorroboration.vitalsQualityMultiplier(
            temperatureC: temperatureC,
            motionLevel: motionLevel,
            motionThreshold: config.motionThresholdG
        )
        heartRateQuality *= qualityMul
        spo2Quality *= qualityMul

        // Stage 9: Determine worn status
        let isWorn = perfusionIndex > config.minPerfusionIndex &&
                     heartRate > 0 &&
                     heartRateQuality > config.minHRQuality &&
                     SensorCorroboration.isLikelyOnSkin(temperatureC: temperatureC)

        return BiometricResult(
            heartRate: heartRate,
            heartRateQuality: heartRateQuality,
            heartRateSource: heartRateSource,
            spo2: spo2,
            spo2Quality: spo2Quality,
            perfusionIndex: perfusionIndex,
            isWorn: isWorn,
            activity: activity,
            motionLevel: motionLevel,
            signalStrength: signalStrength,
            processingMethod: .realtime
        )
    }

    // MARK: - Batch Processing

    /// Process arrays of samples (for historical data or CSV import)
    /// - Parameters:
    ///   - irSamples: Array of IR values
    ///   - redSamples: Array of Red values
    ///   - greenSamples: Array of Green values
    ///   - accelX: Array of accelerometer X values
    ///   - accelY: Array of accelerometer Y values
    ///   - accelZ: Array of accelerometer Z values
    /// - Returns: BiometricResult for the entire batch
    public func processBatch(
        irSamples: [Double],
        redSamples: [Double],
        greenSamples: [Double],
        accelX: [Double],
        accelY: [Double],
        accelZ: [Double],
        temperatureC: Double? = nil
    ) -> BiometricResult {

        // Reset state for batch processing
        reset()

        // Process all samples
        var lastResult = BiometricResult.empty

        let count = min(irSamples.count, redSamples.count, greenSamples.count, accelX.count, accelY.count, accelZ.count)

        for i in 0..<count {
            lastResult = process(
                ir: irSamples[i],
                red: redSamples[i],
                green: greenSamples[i],
                accelX: accelX[i],
                accelY: accelY[i],
                accelZ: accelZ[i],
                temperatureC: temperatureC
            )
        }

        // Return with batch processing method
        return BiometricResult(
            heartRate: lastResult.heartRate,
            heartRateQuality: lastResult.heartRateQuality,
            heartRateSource: lastResult.heartRateSource,
            spo2: lastResult.spo2,
            spo2Quality: lastResult.spo2Quality,
            perfusionIndex: lastResult.perfusionIndex,
            isWorn: lastResult.isWorn,
            activity: lastResult.activity,
            motionLevel: lastResult.motionLevel,
            signalStrength: lastResult.signalStrength,
            processingMethod: .batch
        )
    }

    // MARK: - Reset

    /// Reset all internal state (call when device reconnects or starting new session)
    public func reset() {
        irBuffer.removeAll(keepingCapacity: true)
        redBuffer.removeAll(keepingCapacity: true)
        greenBuffer.removeAll(keepingCapacity: true)
        accelMagnitudeBuffer.removeAll(keepingCapacity: true)
        redDCBuffer.removeAll(keepingCapacity: true)
        irDCBuffer.removeAll(keepingCapacity: true)
        redACSpO2Buffer.removeAll(keepingCapacity: true)
        irACSpO2Buffer.removeAll(keepingCapacity: true)

        irLowPass = 0
        irHighPass = 0
        greenLowPass = 0
        greenHighPass = 0
        irBaseline = 0
        isBaselineInitialized = false

        redDCFilter.reset()
        irDCFilter.reset()
        redACSpO2Filter.reset()
        irACSpO2Filter.reset()
        motionCompensator.reset()
        activityClassifier.reset()
    }

    // MARK: - Accessors for Testing

    /// Current buffer size (for testing and diagnostics)
    public var currentBufferSize: Int {
        irBuffer.count
    }

    /// Required buffer size for calculations
    public var requiredBufferSize: Int {
        config.hrWindowSize
    }

    // MARK: - Private: Motion Detection

    private func calculateMotionLevel(x: Double, y: Double, z: Double) -> Double {
        // Normalize accelerometer values (16384 LSB/g for LIS2DTW12 at ±2g)
        let normX = x / 16384.0
        let normY = y / 16384.0
        let normZ = z / 16384.0

        // Calculate magnitude (should be ~1.0 when stationary due to gravity)
        let magnitude = sqrt(normX * normX + normY * normY + normZ * normZ)

        // Motion level is deviation from 1.0 (stationary)
        return abs(magnitude - 1.0)
    }

    // MARK: - Private: Buffer Management

    private func updateBuffers(
        ir: Double,
        red: Double,
        green: Double,
        motion: Double,
        redRaw: Double,
        irRaw: Double
    ) {
        // Apply bandpass filtering for IR
        let previousIR = irBuffer.last ?? ir
        irHighPass = config.alphaHP * (irHighPass + ir - previousIR)
        irLowPass = irLowPass + config.alphaLP * (irHighPass - irLowPass)

        // Apply bandpass filtering for Green
        let previousGreen = greenBuffer.last ?? green
        greenHighPass = config.alphaHP * (greenHighPass + green - previousGreen)
        greenLowPass = greenLowPass + config.alphaLP * (greenHighPass - greenLowPass)

        // Append filtered values
        irBuffer.append(irLowPass)
        redBuffer.append(red)
        greenBuffer.append(greenLowPass)
        accelMagnitudeBuffer.append(motion)

        // Mac Protocol A SpO2 prep (causal streaming)
        redDCBuffer.append(redDCFilter.processSample(redRaw))
        irDCBuffer.append(irDCFilter.processSample(irRaw))
        redACSpO2Buffer.append(redACSpO2Filter.processSample(redRaw))
        irACSpO2Buffer.append(irACSpO2Filter.processSample(irRaw))

        // Trim to window size
        if irBuffer.count > config.hrWindowSize {
            irBuffer.removeFirst()
            redBuffer.removeFirst()
            greenBuffer.removeFirst()
            accelMagnitudeBuffer.removeFirst()
        }
        let spo2Cap = config.spo2WindowSize
        while redDCBuffer.count > spo2Cap { redDCBuffer.removeFirst() }
        while irDCBuffer.count > spo2Cap { irDCBuffer.removeFirst() }
        while redACSpO2Buffer.count > spo2Cap { redACSpO2Buffer.removeFirst() }
        while irACSpO2Buffer.count > spo2Cap { irACSpO2Buffer.removeFirst() }
    }

    // MARK: - Private: Perfusion Index

    private func calculatePerfusionIndex(signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }

        // DC component (mean)
        let dc = signal.reduce(0, +) / Double(signal.count)
        guard dc > 0 else { return 0 }

        // AC component (peak-to-peak)
        let maxVal = signal.max() ?? 0
        let minVal = signal.min() ?? 0
        let ac = maxVal - minVal

        // Perfusion Index = AC / DC
        return ac / dc
    }

    // MARK: - Private: Heart Rate Calculation

    private func calculateHeartRate() -> (bpm: Int, quality: Double, source: HRSource) {
        // Try IR channel first (primary)
        if let (bpm, quality) = calculateHeartRateFromSignal(irBuffer) {
            if quality >= config.minHRQuality {
                return (bpm, quality, .ir)
            }
        }

        // Try Green channel (backup)
        if let (bpm, quality) = calculateHeartRateFromSignal(greenBuffer) {
            if quality >= config.minHRQuality {
                return (bpm, quality, .green)
            }
        }

        // TODO: Add FFT fallback in future version

        return (0, 0, .unavailable)
    }

    private func calculateHeartRateFromSignal(_ signal: [Double]) -> (bpm: Int, quality: Double)? {
        guard signal.count >= config.hrWindowSize else { return nil }

        // Calculate statistics
        let mean = signal.reduce(0, +) / Double(signal.count)
        let sumSquaredDiff = signal.map { pow($0 - mean, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(signal.count))

        // Signal too flat = poor quality
        guard stdDev > 1.0 else { return nil }

        // Adaptive threshold for peak detection
        let threshold = mean + (stdDev * 0.6)

        // Find peaks
        var peaks: [Int] = []
        for i in 2..<(signal.count - 2) {
            let current = signal[i]
            if current > signal[i-1] && current > signal[i+1] && current > threshold {
                // Ensure minimum distance between peaks (max 180 BPM)
                if let lastPeak = peaks.last {
                    let intervalSamples = i - lastPeak
                    let intervalSeconds = Double(intervalSamples) / config.sampleRate
                    if intervalSeconds < 0.33 { continue }  // 180 BPM limit
                }
                peaks.append(i)
            }
        }

        guard peaks.count >= 2 else { return nil }

        // Calculate inter-beat intervals
        var intervals: [Double] = []
        for j in 1..<peaks.count {
            let intervalSamples = Double(peaks[j] - peaks[j-1])
            let intervalSeconds = intervalSamples / config.sampleRate

            // Filter by physiological bounds
            if intervalSeconds > (60.0 / config.maxBPM) && intervalSeconds < (60.0 / config.minBPM) {
                intervals.append(intervalSeconds)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // Use median interval (robust to outliers)
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]

        let bpm = Int(60.0 / medianInterval)

        // Validate BPM
        guard bpm >= Int(config.minBPM) && bpm <= Int(config.maxBPM) else { return nil }

        // Calculate quality score
        // Higher AC/DC ratio and more consistent intervals = higher quality
        let acdc = min(1.0, stdDev / max(1.0, abs(mean)))
        let peakFactor = min(1.0, Double(intervals.count) / 10.0)
        let quality = 0.6 * acdc + 0.4 * peakFactor

        return (bpm, max(0, min(1.0, quality)))
    }

    // MARK: - Private: SpO2 Calculation

    private func calculateSpO2() -> (spo2: Double, quality: Double) {
        let n = config.spo2WindowSize
        guard redDCBuffer.count >= n,
              irDCBuffer.count >= n,
              redACSpO2Buffer.count >= n,
              irACSpO2Buffer.count >= n else {
            return (0, 0)
        }
        return SpO2Service.protocolASpO2(
            redDCSamples: Array(redDCBuffer.suffix(n)),
            redACSamples: Array(redACSpO2Buffer.suffix(n)),
            irDCSamples: Array(irDCBuffer.suffix(n)),
            irACSamples: Array(irACSpO2Buffer.suffix(n))
        )
    }

    // MARK: - Temporalis Fatigue Index

    /// Maps normalized drift `combined` from `calculate_tfi` in `features.py` to a squashed 0–100 score:
    /// `50 + 50 * tanh(driftCombined / 2)`.
    public nonisolated static func temporalisFatigueIndex(driftCombined: Double) -> Double {
        50.0 + 50.0 * tanh(driftCombined / 2.0)
    }
}
