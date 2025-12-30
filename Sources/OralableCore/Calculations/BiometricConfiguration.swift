//
//  BiometricConfiguration.swift
//  OralableCore
//
//  Migrated from OralableApp: December 30, 2025
//  Configuration for biometric processing parameters
//

import Foundation

/// Configuration for the biometric processor
public struct BiometricConfiguration: Sendable {
    // MARK: - Sample Rate

    /// Sample rate in Hz (must match device)
    public let sampleRate: Double

    // MARK: - Window Sizes

    /// Heart rate calculation window in seconds
    public let hrWindowSeconds: Double

    /// SpO2 calculation window in seconds
    public let spo2WindowSeconds: Double

    // MARK: - Quality Thresholds

    /// Minimum perfusion index for worn detection
    public let minPerfusionIndex: Double

    /// Minimum quality score for valid HR output
    public let minHRQuality: Double

    /// Minimum quality score for valid SpO2 output
    public let minSpO2Quality: Double

    // MARK: - Motion Threshold

    /// Motion threshold in G (1.0 = stationary)
    public let motionThresholdG: Double

    // MARK: - Physiological Bounds

    /// Minimum valid heart rate (BPM)
    public let minBPM: Double

    /// Maximum valid heart rate (BPM)
    public let maxBPM: Double

    /// Minimum valid SpO2 (%)
    public let minSpO2: Double

    /// Maximum valid SpO2 (%)
    public let maxSpO2: Double

    // MARK: - Filter Coefficients

    /// Low-pass smoothing coefficient (0.0-1.0, higher = smoother)
    public let alphaLP: Double

    /// High-pass baseline tracking coefficient (0.0-1.0, higher = faster tracking)
    public let alphaHP: Double

    // MARK: - Computed Properties

    /// Heart rate window size in samples
    public var hrWindowSize: Int {
        Int(sampleRate * hrWindowSeconds)
    }

    /// SpO2 window size in samples
    public var spo2WindowSize: Int {
        Int(sampleRate * spo2WindowSeconds)
    }

    // MARK: - Initialization

    public init(
        sampleRate: Double,
        hrWindowSeconds: Double = 3.0,
        spo2WindowSeconds: Double = 3.0,
        minPerfusionIndex: Double = 0.001,
        minHRQuality: Double = 0.5,
        minSpO2Quality: Double = 0.6,
        motionThresholdG: Double = 0.15,
        minBPM: Double = 40,
        maxBPM: Double = 180,
        minSpO2: Double = 70,
        maxSpO2: Double = 100,
        alphaLP: Double = 0.15,
        alphaHP: Double = 0.05
    ) {
        self.sampleRate = sampleRate
        self.hrWindowSeconds = hrWindowSeconds
        self.spo2WindowSeconds = spo2WindowSeconds
        self.minPerfusionIndex = minPerfusionIndex
        self.minHRQuality = minHRQuality
        self.minSpO2Quality = minSpO2Quality
        self.motionThresholdG = motionThresholdG
        self.minBPM = minBPM
        self.maxBPM = maxBPM
        self.minSpO2 = minSpO2
        self.maxSpO2 = maxSpO2
        self.alphaLP = alphaLP
        self.alphaHP = alphaHP
    }

    // MARK: - Presets

    /// Default configuration for Oralable device (50 Hz)
    public static let oralable = BiometricConfiguration(
        sampleRate: 50.0,
        hrWindowSeconds: 3.0,
        spo2WindowSeconds: 3.0,
        minPerfusionIndex: 0.001,
        minHRQuality: 0.5,
        minSpO2Quality: 0.6,
        motionThresholdG: 0.15,
        minBPM: 40,
        maxBPM: 180,
        minSpO2: 70,
        maxSpO2: 100,
        alphaLP: 0.15,
        alphaHP: 0.05
    )

    /// Configuration for ANR device (100 Hz)
    public static let anr = BiometricConfiguration(
        sampleRate: 100.0,
        hrWindowSeconds: 3.0,
        spo2WindowSeconds: 3.0,
        minPerfusionIndex: 0.001,
        minHRQuality: 0.5,
        minSpO2Quality: 0.6,
        motionThresholdG: 0.15,
        minBPM: 40,
        maxBPM: 180,
        minSpO2: 70,
        maxSpO2: 100,
        alphaLP: 0.15,
        alphaHP: 0.05
    )

    /// Demo/test configuration (10 Hz)
    public static let demo = BiometricConfiguration(
        sampleRate: 10.0,
        hrWindowSeconds: 5.0,
        spo2WindowSeconds: 5.0,
        minPerfusionIndex: 0.0005,
        minHRQuality: 0.3,
        minSpO2Quality: 0.3,
        motionThresholdG: 0.2,
        minBPM: 40,
        maxBPM: 180,
        minSpO2: 70,
        maxSpO2: 100,
        alphaLP: 0.2,
        alphaHP: 0.1
    )
}
