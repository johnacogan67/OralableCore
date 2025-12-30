//
//  ClinicalThresholds.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Clinical reference values and thresholds for biometric data
//  Used by both consumer and professional apps for consistent health assessment
//

import Foundation

// MARK: - Clinical Thresholds

/// Clinical reference values and thresholds for biometric data assessment
/// All values are based on standard medical guidelines and should not be used
/// for medical diagnosis without professional consultation.
public struct ClinicalThresholds: Sendable {

    // MARK: - Heart Rate Thresholds

    /// Heart rate thresholds in beats per minute (BPM)
    public struct HeartRate: Sendable {

        /// Absolute minimum valid heart rate (BPM)
        public static let absoluteMinimum: Double = 30

        /// Absolute maximum valid heart rate (BPM)
        public static let absoluteMaximum: Double = 250

        /// Bradycardia threshold (resting HR below this is considered low)
        public static let bradycardiaThreshold: Double = 60

        /// Tachycardia threshold (resting HR above this is considered elevated)
        public static let tachycardiaThreshold: Double = 100

        /// Normal resting heart rate range for adults
        public static let normalRestingRange: ClosedRange<Double> = 60...100

        /// Athletic resting heart rate range (well-trained individuals)
        public static let athleticRestingRange: ClosedRange<Double> = 40...60

        /// Sleeping heart rate is typically lower
        public static let sleepingRange: ClosedRange<Double> = 40...70

        // MARK: - Heart Rate Zones

        /// Heart rate zones based on percentage of max heart rate
        public enum Zone: String, CaseIterable, Sendable {
            case resting = "Resting"
            case warmUp = "Warm Up"
            case fatBurn = "Fat Burn"
            case cardio = "Cardio"
            case peak = "Peak"

            /// Zone percentage of max heart rate
            public var percentageRange: ClosedRange<Double> {
                switch self {
                case .resting: return 0...50
                case .warmUp: return 50...60
                case .fatBurn: return 60...70
                case .cardio: return 70...85
                case .peak: return 85...100
                }
            }

            /// Get zone for a given heart rate and maximum heart rate
            public static func zone(heartRate: Double, maxHeartRate: Double) -> Zone {
                let percentage = (heartRate / maxHeartRate) * 100
                switch percentage {
                case ..<50: return .resting
                case 50..<60: return .warmUp
                case 60..<70: return .fatBurn
                case 70..<85: return .cardio
                default: return .peak
                }
            }
        }

        // MARK: - Age-Based Maximum Heart Rate

        /// Calculate estimated maximum heart rate using Tanaka formula
        /// maxHR = 208 - (0.7 × age)
        /// - Parameter age: Age in years
        /// - Returns: Estimated maximum heart rate
        public static func estimatedMaxHeartRate(age: Int) -> Double {
            return 208.0 - (0.7 * Double(age))
        }

        /// Calculate target heart rate range for exercise
        /// - Parameters:
        ///   - age: Age in years
        ///   - restingHR: Resting heart rate (optional, for Karvonen formula)
        ///   - minIntensity: Minimum intensity percentage (default 50%)
        ///   - maxIntensity: Maximum intensity percentage (default 85%)
        /// - Returns: Target heart rate range
        public static func targetHeartRateRange(
            age: Int,
            restingHR: Double? = nil,
            minIntensity: Double = 0.5,
            maxIntensity: Double = 0.85
        ) -> ClosedRange<Double> {
            let maxHR = estimatedMaxHeartRate(age: age)

            if let restingHR = restingHR {
                // Karvonen formula: THR = ((maxHR - restingHR) × intensity) + restingHR
                let reserve = maxHR - restingHR
                let minTarget = (reserve * minIntensity) + restingHR
                let maxTarget = (reserve * maxIntensity) + restingHR
                return minTarget...maxTarget
            } else {
                // Simple percentage method
                return (maxHR * minIntensity)...(maxHR * maxIntensity)
            }
        }

        /// Recommended resting heart rate by age group
        public static func normalRestingRange(age: Int) -> ClosedRange<Double> {
            switch age {
            case 0..<1: return 100...160
            case 1..<3: return 90...150
            case 3..<5: return 80...140
            case 5..<12: return 70...120
            case 12..<18: return 60...100
            default: return 60...100
            }
        }
    }

    // MARK: - SpO2 Thresholds

    /// Blood oxygen saturation thresholds (percentage)
    public struct SpO2: Sendable {

        /// Absolute minimum valid SpO2
        public static let absoluteMinimum: Double = 50

        /// Absolute maximum valid SpO2
        public static let absoluteMaximum: Double = 100

        /// Normal SpO2 range (healthy individuals at sea level)
        public static let normalRange: ClosedRange<Double> = 95...100

        /// Borderline low SpO2 (may warrant monitoring)
        public static let borderlineRange: ClosedRange<Double> = 90...94

        /// Low SpO2 threshold (medical attention may be needed)
        public static let lowThreshold: Double = 90

        /// Critical SpO2 threshold (immediate medical attention)
        public static let criticalThreshold: Double = 85

        /// Severe hypoxemia threshold
        public static let severeHypoxemiaThreshold: Double = 80

        // MARK: - SpO2 Status

        /// SpO2 health status categories
        public enum Status: String, CaseIterable, Sendable {
            case normal = "Normal"
            case borderline = "Borderline"
            case low = "Low"
            case critical = "Critical"

            /// Color indicator for status
            public var colorName: String {
                switch self {
                case .normal: return "green"
                case .borderline: return "yellow"
                case .low: return "orange"
                case .critical: return "red"
                }
            }

            /// Get status for SpO2 percentage
            public static func status(for percentage: Double) -> Status {
                switch percentage {
                case 95...100: return .normal
                case 90..<95: return .borderline
                case 85..<90: return .low
                default: return .critical
                }
            }
        }

        /// Altitude-adjusted normal SpO2 threshold
        /// SpO2 naturally decreases at higher altitudes
        /// - Parameter altitudeMeters: Altitude in meters above sea level
        /// - Returns: Adjusted minimum normal SpO2
        public static func altitudeAdjustedNormalMinimum(altitudeMeters: Double) -> Double {
            // SpO2 drops approximately 1% per 1000m above 1500m
            if altitudeMeters < 1500 {
                return 95
            } else {
                let drop = (altitudeMeters - 1500) / 1000
                return max(88, 95 - drop)
            }
        }
    }

    // MARK: - Temperature Thresholds

    /// Body temperature thresholds (Celsius)
    public struct Temperature: Sendable {

        /// Absolute minimum valid temperature (Celsius)
        public static let absoluteMinimum: Double = 30.0

        /// Absolute maximum valid temperature (Celsius)
        public static let absoluteMaximum: Double = 45.0

        /// Normal body temperature range (Celsius)
        public static let normalRange: ClosedRange<Double> = 36.1...37.2

        /// Normal core body temperature (Celsius)
        public static let normalCore: Double = 37.0

        /// Low-grade fever threshold (Celsius)
        public static let lowGradeFeverThreshold: Double = 37.5

        /// Fever threshold (Celsius)
        public static let feverThreshold: Double = 38.0

        /// High fever threshold (Celsius)
        public static let highFeverThreshold: Double = 39.0

        /// Dangerous fever threshold (Celsius)
        public static let dangerousFeverThreshold: Double = 40.0

        /// Hypothermia threshold (Celsius)
        public static let hypothermiaThreshold: Double = 35.0

        /// Severe hypothermia threshold (Celsius)
        public static let severeHypothermiaThreshold: Double = 32.0

        // MARK: - Temperature Status

        /// Temperature health status categories
        public enum Status: String, CaseIterable, Sendable {
            case hypothermia = "Hypothermia"
            case low = "Low"
            case normal = "Normal"
            case elevated = "Elevated"
            case fever = "Fever"
            case highFever = "High Fever"

            /// Get status for temperature in Celsius
            public static func status(celsius: Double) -> Status {
                switch celsius {
                case ..<35.0: return .hypothermia
                case 35.0..<36.1: return .low
                case 36.1...37.2: return .normal
                case 37.2..<38.0: return .elevated
                case 38.0..<39.0: return .fever
                default: return .highFever
                }
            }
        }

        /// Convert Celsius to Fahrenheit
        public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
            return (celsius * 9.0 / 5.0) + 32.0
        }

        /// Convert Fahrenheit to Celsius
        public static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
            return (fahrenheit - 32.0) * 5.0 / 9.0
        }
    }

    // MARK: - Quality Thresholds

    /// Signal quality thresholds for valid readings
    public struct Quality: Sendable {

        /// Minimum quality for a reading to be considered valid
        public static let minimumValid: Double = 0.5

        /// Minimum quality for clinical-grade readings
        public static let clinicalGrade: Double = 0.7

        /// Minimum quality for excellent readings
        public static let excellent: Double = 0.9

        /// Quality level categories
        public enum Level: String, CaseIterable, Sendable {
            case poor = "Poor"
            case acceptable = "Acceptable"
            case good = "Good"
            case excellent = "Excellent"

            /// Get level for quality value (0.0 - 1.0)
            public static func level(for quality: Double) -> Level {
                switch quality {
                case ..<0.5: return .poor
                case 0.5..<0.7: return .acceptable
                case 0.7..<0.9: return .good
                default: return .excellent
                }
            }

            /// Whether this level is clinically acceptable
            public var isClinicallyAcceptable: Bool {
                switch self {
                case .poor, .acceptable: return false
                case .good, .excellent: return true
                }
            }
        }
    }

    // MARK: - Movement Thresholds

    /// Movement and activity detection thresholds
    public struct Movement: Sendable {

        /// Default movement variability threshold
        public static let defaultVariabilityThreshold: Double = 1500

        /// Minimum movement threshold (very sensitive)
        public static let sensitiveThreshold: Double = 500

        /// Maximum movement threshold (very insensitive)
        public static let insensitiveThreshold: Double = 5000

        /// Threshold range for user adjustment
        public static let adjustableRange: ClosedRange<Double> = 500...5000

        /// Step size for threshold adjustment
        public static let adjustmentStep: Double = 100

        /// Accelerometer magnitude for rest detection (in g)
        public static let restMagnitude: Double = 1.0

        /// Tolerance for rest detection (in g)
        public static let restTolerance: Double = 0.1

        /// Clenching detection threshold (accelerometer variability)
        public static let clenchingThreshold: Double = 0.05

        /// Grinding detection threshold (accelerometer variability)
        public static let grindingThreshold: Double = 0.15

        /// Motion detection threshold (accelerometer variability)
        public static let motionThreshold: Double = 0.3
    }

    // MARK: - Perfusion Index Thresholds

    /// Perfusion index thresholds for sensor contact quality
    public struct PerfusionIndex: Sendable {

        /// No signal detected threshold
        public static let noSignal: Double = 0.0005

        /// Weak signal threshold
        public static let weakSignal: Double = 0.001

        /// Moderate signal threshold
        public static let moderateSignal: Double = 0.003

        /// Strong signal threshold
        public static let strongSignal: Double = 0.01

        /// Minimum perfusion index for valid worn detection
        public static let minimumForWornDetection: Double = 0.001
    }

    // MARK: - R Ratio Thresholds (SpO2 Calculation)

    /// R ratio thresholds for SpO2 calculation validation
    public struct RRatio: Sendable {

        /// Minimum valid R ratio
        public static let minimum: Double = 0.4

        /// Maximum valid R ratio
        public static let maximum: Double = 3.4

        /// Valid R ratio range
        public static let validRange: ClosedRange<Double> = 0.4...3.4

        /// R ratio at 100% SpO2 (theoretical)
        public static let at100Percent: Double = 0.4

        /// R ratio at 0% SpO2 (theoretical)
        public static let at0Percent: Double = 3.4
    }
}

// MARK: - Validation Helpers

extension ClinicalThresholds {

    /// Validate a heart rate value
    public static func isValidHeartRate(_ bpm: Double) -> Bool {
        return bpm >= HeartRate.absoluteMinimum && bpm <= HeartRate.absoluteMaximum
    }

    /// Validate an SpO2 value
    public static func isValidSpO2(_ percentage: Double) -> Bool {
        return percentage >= SpO2.absoluteMinimum && percentage <= SpO2.absoluteMaximum
    }

    /// Validate a temperature value in Celsius
    public static func isValidTemperature(_ celsius: Double) -> Bool {
        return celsius >= Temperature.absoluteMinimum && celsius <= Temperature.absoluteMaximum
    }

    /// Validate a quality value
    public static func isValidQuality(_ quality: Double) -> Bool {
        return quality >= 0 && quality <= 1.0
    }

    /// Check if heart rate is within normal resting range for age
    public static func isNormalRestingHeartRate(_ bpm: Double, age: Int) -> Bool {
        let range = HeartRate.normalRestingRange(age: age)
        return range.contains(bpm)
    }

    /// Check if SpO2 is normal for altitude
    public static func isNormalSpO2(_ percentage: Double, altitudeMeters: Double = 0) -> Bool {
        let minimum = SpO2.altitudeAdjustedNormalMinimum(altitudeMeters: altitudeMeters)
        return percentage >= minimum
    }
}
