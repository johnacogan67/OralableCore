//
//  DemoDataGenerator.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Framework-agnostic demo data generator for testing and simulation
//  Generates realistic synthetic sensor data without UI dependencies
//

import Foundation

// MARK: - Demo Data Configuration

/// Configuration for demo data generation
public struct DemoDataConfiguration: Sendable {
    /// Heart rate range (BPM)
    public let heartRateRange: ClosedRange<Int>

    /// SpO2 range (percentage)
    public let spo2Range: ClosedRange<Int>

    /// Temperature range (Celsius)
    public let temperatureRange: ClosedRange<Double>

    /// Initial battery percentage
    public let initialBattery: Int

    /// Sampling rate for PPG data (Hz)
    public let ppgSamplingRate: Double

    /// Accelerometer scale (LSB per g)
    public let accelerometerScale: Double

    /// Device type for generated data
    public let deviceType: DeviceType

    public init(
        heartRateRange: ClosedRange<Int> = 60...100,
        spo2Range: ClosedRange<Int> = 95...100,
        temperatureRange: ClosedRange<Double> = 36.2...37.5,
        initialBattery: Int = 85,
        ppgSamplingRate: Double = 50.0,
        accelerometerScale: Double = 16384.0,
        deviceType: DeviceType = .oralable
    ) {
        self.heartRateRange = heartRateRange
        self.spo2Range = spo2Range
        self.temperatureRange = temperatureRange
        self.initialBattery = initialBattery
        self.ppgSamplingRate = ppgSamplingRate
        self.accelerometerScale = accelerometerScale
        self.deviceType = deviceType
    }

    // MARK: - Presets

    /// Standard configuration for consumer app testing
    public static let standard = DemoDataConfiguration()

    /// Configuration for exercise/activity simulation
    public static let exercise = DemoDataConfiguration(
        heartRateRange: 90...150,
        spo2Range: 93...99,
        temperatureRange: 36.5...38.0,
        initialBattery: 70
    )

    /// Configuration for resting/sleep simulation
    public static let resting = DemoDataConfiguration(
        heartRateRange: 50...70,
        spo2Range: 96...100,
        temperatureRange: 36.0...36.8,
        initialBattery: 90
    )

    /// Configuration for clinical testing (high precision)
    public static let clinical = DemoDataConfiguration(
        heartRateRange: 60...80,
        spo2Range: 97...100,
        temperatureRange: 36.4...37.2,
        initialBattery: 95,
        ppgSamplingRate: 100.0
    )
}

// MARK: - Demo Data Generator

/// Generates realistic synthetic sensor data for testing and simulation
/// Thread-safe actor implementation for concurrent access
public actor DemoDataGenerator {

    // MARK: - Properties

    private let configuration: DemoDataConfiguration
    private var sampleIndex: Int = 0
    private var currentBattery: Int

    // MARK: - State for Realistic Variation

    private var lastHeartRate: Int
    private var lastSpO2: Int
    private var lastTemperature: Double

    // MARK: - Initialization

    public init(configuration: DemoDataConfiguration = .standard) {
        self.configuration = configuration
        self.currentBattery = configuration.initialBattery

        // Initialize with mid-range values
        self.lastHeartRate = (configuration.heartRateRange.lowerBound + configuration.heartRateRange.upperBound) / 2
        self.lastSpO2 = (configuration.spo2Range.lowerBound + configuration.spo2Range.upperBound) / 2
        self.lastTemperature = (configuration.temperatureRange.lowerBound + configuration.temperatureRange.upperBound) / 2.0
    }

    // MARK: - PPG Data Generation

    /// Generate a realistic PPG waveform sample
    /// - Parameter heartRate: Current heart rate in BPM for pulse frequency
    /// - Returns: PPGData with realistic IR, Red, and Green channel values
    public func generatePPGSample(heartRate: Double = 72.0) -> PPGData {
        let time = Double(sampleIndex) / configuration.ppgSamplingRate
        sampleIndex += 1

        let frequency = heartRate / 60.0 // Hz
        let angle = 2.0 * .pi * frequency * time

        // Baseline values (DC component) - muscle-site PPG has very high DC
        let baselineIR: Double = 150000
        let baselineRed: Double = 120000
        let baselineGreen: Double = 80000

        // Amplitude (AC component) - typically 1-3% of DC
        let amplitudeIR: Double = 3000
        let amplitudeRed: Double = 2500
        let amplitudeGreen: Double = 2000

        // Generate pulse waveform with systolic and diastolic components
        let systolic = sin(angle)
        let diastolic = 0.3 * sin(2 * angle + .pi / 4) // Dicrotic notch
        let signal = systolic + diastolic

        // Add realistic noise (motion artifact, electronic noise)
        let noiseIR = Double.random(in: -200...200)
        let noiseRed = Double.random(in: -150...150)
        let noiseGreen = Double.random(in: -100...100)

        let ir = Int32(baselineIR + signal * amplitudeIR + noiseIR)
        let red = Int32(baselineRed + signal * amplitudeRed + noiseRed)
        let green = Int32(baselineGreen + signal * amplitudeGreen + noiseGreen)

        return PPGData(red: red, ir: ir, green: green, timestamp: Date())
    }

    /// Generate multiple PPG samples for a given duration
    /// - Parameters:
    ///   - duration: Duration in seconds
    ///   - heartRate: Heart rate in BPM
    /// - Returns: Array of PPGData samples
    public func generatePPGSequence(duration: TimeInterval, heartRate: Double = 72.0) -> [PPGData] {
        let sampleCount = Int(duration * configuration.ppgSamplingRate)
        var samples: [PPGData] = []
        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            samples.append(generatePPGSample(heartRate: heartRate))
        }

        return samples
    }

    // MARK: - Accelerometer Data Generation

    /// Generate accelerometer data for a given activity state
    /// - Parameter activity: Activity type to simulate
    /// - Returns: AccelerometerData with realistic values
    public func generateAccelerometerSample(activity: ActivityType = .relaxed) -> AccelerometerData {
        let scale = configuration.accelerometerScale

        switch activity {
        case .relaxed:
            // At rest - gravity in Z axis, minimal noise
            let x = Int16.random(in: -50...50)
            let y = Int16.random(in: -50...50)
            let z = Int16(scale) + Int16.random(in: -30...30) // ~1g
            return AccelerometerData(x: x, y: y, z: z, timestamp: Date())

        case .clenching:
            // Clenching - small muscle tension, slight device movement
            let x = Int16.random(in: -300...300)
            let y = Int16.random(in: -300...300)
            let z = Int16(scale * 0.95) + Int16.random(in: -100...100)
            return AccelerometerData(x: x, y: y, z: z, timestamp: Date())

        case .grinding:
            // Grinding - rhythmic movement, moderate variations
            let x = Int16.random(in: -1500...1500)
            let y = Int16.random(in: -1500...1500)
            let z = Int16(scale * 0.85) + Int16.random(in: -500...500)
            return AccelerometerData(x: x, y: y, z: z, timestamp: Date())

        case .motion:
            // Heavy motion - maximum variation
            let x = Int16.random(in: -8000...8000)
            let y = Int16.random(in: -8000...8000)
            let z = Int16.random(in: -8000...8000)
            return AccelerometerData(x: x, y: y, z: z, timestamp: Date())
        }
    }

    // MARK: - Heart Rate Generation

    /// Generate a realistic heart rate value with natural variation
    /// - Returns: Heart rate in BPM
    public func generateHeartRate() -> Double {
        // Natural variation: ±3 BPM from last value
        let variation = Int.random(in: -3...3)
        var newRate = lastHeartRate + variation

        // Clamp to configured range
        newRate = max(configuration.heartRateRange.lowerBound,
                     min(configuration.heartRateRange.upperBound, newRate))
        lastHeartRate = newRate

        return Double(newRate)
    }

    /// Generate HeartRateData with realistic confidence
    public func generateHeartRateData() -> HeartRateData {
        let bpm = generateHeartRate()
        // Confidence based on how centered the value is in the range
        let rangeSize = Double(configuration.heartRateRange.upperBound - configuration.heartRateRange.lowerBound)
        let distanceFromCenter = abs(bpm - (Double(configuration.heartRateRange.lowerBound) + rangeSize / 2))
        let quality = max(0.6, 1.0 - (distanceFromCenter / rangeSize))

        return HeartRateData(bpm: bpm, quality: quality, timestamp: Date())
    }

    // MARK: - SpO2 Generation

    /// Generate a realistic SpO2 value
    /// - Returns: SpO2 percentage
    public func generateSpO2() -> Double {
        // Natural variation: ±1% from last value
        let variation = Int.random(in: -1...1)
        var newValue = lastSpO2 + variation

        // Clamp to configured range
        newValue = max(configuration.spo2Range.lowerBound,
                      min(configuration.spo2Range.upperBound, newValue))
        lastSpO2 = newValue

        return Double(newValue)
    }

    /// Generate SpO2Data with realistic confidence
    public func generateSpO2Data() -> SpO2Data {
        let percentage = generateSpO2()
        // Higher SpO2 values typically have higher confidence
        let quality = percentage >= 96 ? Double.random(in: 0.85...1.0) : Double.random(in: 0.7...0.9)

        return SpO2Data(percentage: percentage, quality: quality, timestamp: Date())
    }

    // MARK: - Temperature Generation

    /// Generate a realistic temperature value with circadian variation
    /// - Parameter hourOfDay: Optional hour (0-23) for circadian rhythm simulation
    /// - Returns: Temperature in Celsius
    public func generateTemperature(hourOfDay: Int? = nil) -> Double {
        // Apply circadian rhythm if hour provided
        var circadianAdjustment = 0.0
        if let hour = hourOfDay {
            // Body temperature is typically higher in late afternoon (16:00-20:00)
            if hour >= 16 && hour <= 20 {
                circadianAdjustment = 0.2
            } else if hour >= 2 && hour <= 6 {
                circadianAdjustment = -0.2
            }
        }

        // Natural variation: ±0.1°C from last value
        let variation = Double.random(in: -0.1...0.1)
        var newTemp = lastTemperature + variation + circadianAdjustment

        // Clamp to configured range
        newTemp = max(configuration.temperatureRange.lowerBound,
                     min(configuration.temperatureRange.upperBound, newTemp))
        lastTemperature = newTemp

        return (newTemp * 10).rounded() / 10 // Round to 1 decimal
    }

    /// Generate TemperatureData
    public func generateTemperatureData(hourOfDay: Int? = nil) -> TemperatureData {
        return TemperatureData(celsius: generateTemperature(hourOfDay: hourOfDay), timestamp: Date())
    }

    // MARK: - Battery Generation

    /// Generate battery level (simulates gradual drain)
    /// - Parameter drain: Amount to drain per call (default: 0.01%)
    /// - Returns: Current battery percentage
    public func generateBatteryLevel(drain: Double = 0.01) -> Int {
        // Simulate gradual battery drain
        currentBattery = max(0, currentBattery - Int(drain.rounded()))
        return currentBattery
    }

    /// Generate BatteryData
    public func generateBatteryData(drain: Double = 0.01) -> BatteryData {
        return BatteryData(percentage: generateBatteryLevel(drain: drain), timestamp: Date())
    }

    // MARK: - Complete Sensor Data Generation

    /// Generate a complete SensorData object with all sensor values
    /// - Parameter activity: Activity type for accelerometer simulation
    /// - Returns: Complete SensorData
    public func generateSensorData(activity: ActivityType = .relaxed) -> SensorData {
        let hr = generateHeartRateData()
        let ppg = generatePPGSample(heartRate: hr.bpm)
        let accelerometer = generateAccelerometerSample(activity: activity)

        let hour = Calendar.current.component(.hour, from: Date())
        let temperature = generateTemperatureData(hourOfDay: hour)
        let battery = generateBatteryData()
        let spo2 = generateSpO2Data()

        return SensorData(
            timestamp: Date(),
            ppg: ppg,
            accelerometer: accelerometer,
            temperature: temperature,
            battery: battery,
            heartRate: hr,
            spo2: spo2,
            deviceType: configuration.deviceType
        )
    }

    /// Generate a sequence of SensorData points
    /// - Parameters:
    ///   - count: Number of data points to generate
    ///   - interval: Time interval between points (seconds)
    ///   - activity: Activity type for accelerometer simulation
    /// - Returns: Array of SensorData
    public func generateSensorDataSequence(
        count: Int,
        interval: TimeInterval = 1.0,
        activity: ActivityType = .relaxed
    ) -> [SensorData] {
        var data: [SensorData] = []
        data.reserveCapacity(count)

        let startTime = Date()

        for i in 0..<count {
            let timestamp = startTime.addingTimeInterval(Double(i) * interval)

            let hr = generateHeartRateData()
            let ppg = generatePPGSample(heartRate: hr.bpm)
            let accelerometer = generateAccelerometerSample(activity: activity)

            let hour = Calendar.current.component(.hour, from: timestamp)
            let temperature = generateTemperatureData(hourOfDay: hour)
            let battery = generateBatteryData(drain: 0.001) // Very slow drain for sequence
            let spo2 = generateSpO2Data()

            let sensorData = SensorData(
                timestamp: timestamp,
                ppg: ppg,
                accelerometer: accelerometer,
                temperature: temperature,
                battery: battery,
                heartRate: hr,
                spo2: spo2,
                deviceType: configuration.deviceType
            )

            data.append(sensorData)
        }

        return data
    }

    // MARK: - State Management

    /// Reset generator to initial state
    public func reset() {
        sampleIndex = 0
        currentBattery = configuration.initialBattery
        lastHeartRate = (configuration.heartRateRange.lowerBound + configuration.heartRateRange.upperBound) / 2
        lastSpO2 = (configuration.spo2Range.lowerBound + configuration.spo2Range.upperBound) / 2
        lastTemperature = (configuration.temperatureRange.lowerBound + configuration.temperatureRange.upperBound) / 2.0
    }

    /// Get current sample index
    public var currentSampleIndex: Int {
        sampleIndex
    }

    /// Get current battery level
    public var batteryLevel: Int {
        currentBattery
    }
}

// MARK: - Synchronous Generator

/// Non-actor version for simple synchronous usage in tests
public struct DemoDataGeneratorSync: Sendable {

    private let configuration: DemoDataConfiguration

    public init(configuration: DemoDataConfiguration = .standard) {
        self.configuration = configuration
    }

    /// Generate a single PPG sample at a specific time index
    public func generatePPGSample(at sampleIndex: Int, heartRate: Double = 72.0) -> PPGData {
        let time = Double(sampleIndex) / configuration.ppgSamplingRate
        let frequency = heartRate / 60.0
        let angle = 2.0 * .pi * frequency * time

        let baselineIR: Double = 150000
        let baselineRed: Double = 120000
        let baselineGreen: Double = 80000

        let amplitudeIR: Double = 3000
        let amplitudeRed: Double = 2500
        let amplitudeGreen: Double = 2000

        let systolic = sin(angle)
        let diastolic = 0.3 * sin(2 * angle + .pi / 4)
        let signal = systolic + diastolic

        let ir = Int32(baselineIR + signal * amplitudeIR)
        let red = Int32(baselineRed + signal * amplitudeRed)
        let green = Int32(baselineGreen + signal * amplitudeGreen)

        return PPGData(red: red, ir: ir, green: green, timestamp: Date())
    }

    /// Generate accelerometer at rest
    public func generateAccelerometerAtRest() -> AccelerometerData {
        AccelerometerData(
            x: 0,
            y: 0,
            z: Int16(configuration.accelerometerScale),
            timestamp: Date()
        )
    }

    /// Generate default sensor data
    public func generateDefaultSensorData() -> SensorData {
        let ppg = generatePPGSample(at: 0)
        let accelerometer = generateAccelerometerAtRest()
        let temperature = TemperatureData(celsius: 36.8, timestamp: Date())
        let battery = BatteryData(percentage: 85, timestamp: Date())
        let heartRate = HeartRateData(bpm: 72, quality: 0.9, timestamp: Date())
        let spo2 = SpO2Data(percentage: 98, quality: 0.9, timestamp: Date())

        return SensorData(
            ppg: ppg,
            accelerometer: accelerometer,
            temperature: temperature,
            battery: battery,
            heartRate: heartRate,
            spo2: spo2,
            deviceType: configuration.deviceType
        )
    }
}
