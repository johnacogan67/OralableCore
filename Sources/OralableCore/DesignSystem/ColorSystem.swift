//
//  ColorSystem.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Unified color system for Oralable apps
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color System

/// Unified color system using iOS system colors for consistency across apps
public struct ColorSystem: Sendable {

    // MARK: - Text Colors

    /// Primary text color (adapts to dark mode)
    public let textPrimary: Color

    /// Secondary text color
    public let textSecondary: Color

    /// Tertiary text color
    public let textTertiary: Color

    /// Disabled text color
    public let textDisabled: Color

    // MARK: - Background Colors

    /// Primary background color
    public let backgroundPrimary: Color

    /// Secondary background color
    public let backgroundSecondary: Color

    /// Tertiary background color
    public let backgroundTertiary: Color

    /// Grouped background color (for table views)
    public let backgroundGrouped: Color

    // MARK: - Primary Colors

    /// Primary black color
    public let primaryBlack: Color

    /// Primary white color
    public let primaryWhite: Color

    // MARK: - Grayscale

    /// Gray 50 (lightest)
    public let gray50: Color

    /// Gray 100
    public let gray100: Color

    /// Gray 200
    public let gray200: Color

    /// Gray 300
    public let gray300: Color

    /// Gray 400
    public let gray400: Color

    /// Gray 500 (system gray)
    public let gray500: Color

    /// Gray 600
    public let gray600: Color

    /// Gray 700
    public let gray700: Color

    /// Gray 800
    public let gray800: Color

    /// Gray 900 (darkest)
    public let gray900: Color

    // MARK: - Interactive States

    /// Hover state color
    public let hover: Color

    /// Pressed state color
    public let pressed: Color

    /// Border color
    public let border: Color

    /// Divider color
    public let divider: Color

    // MARK: - Semantic Colors

    /// Information color (blue)
    public let info: Color

    /// Warning color (orange)
    public let warning: Color

    /// Error color (red)
    public let error: Color

    /// Success color (green)
    public let success: Color

    // MARK: - Health Metric Colors

    /// Heart rate display color
    public let heartRate: Color

    /// SpO2 display color
    public let spo2: Color

    /// Temperature display color
    public let temperature: Color

    /// Battery indicator color
    public let battery: Color

    /// Movement/activity color
    public let movement: Color

    /// Muscle activity (EMG) color
    public let muscleActivity: Color

    /// Oral wellness metric color
    public let oralWellness: Color

    // MARK: - Shadow

    /// Shadow color
    public let shadow: Color

    // MARK: - Initialization

    public init() {
        #if canImport(UIKit)
        // Text colors using UIKit system colors
        self.textPrimary = Color(UIColor.label)
        self.textSecondary = Color(UIColor.secondaryLabel)
        self.textTertiary = Color(UIColor.tertiaryLabel)
        self.textDisabled = Color(UIColor.quaternaryLabel)

        // Background colors
        self.backgroundPrimary = Color(UIColor.systemBackground)
        self.backgroundSecondary = Color(UIColor.secondarySystemBackground)
        self.backgroundTertiary = Color(UIColor.tertiarySystemBackground)
        self.backgroundGrouped = Color(UIColor.systemGroupedBackground)

        // Primary colors
        self.primaryBlack = Color.black
        self.primaryWhite = Color.white

        // Grayscale using system grays
        self.gray50 = Color(UIColor.systemGray6)
        self.gray100 = Color(UIColor.systemGray5)
        self.gray200 = Color(UIColor.systemGray4)
        self.gray300 = Color(UIColor.systemGray3)
        self.gray400 = Color(UIColor.systemGray2)
        self.gray500 = Color(UIColor.systemGray)
        self.gray600 = Color(UIColor.darkGray)
        self.gray700 = Color(red: 0.3, green: 0.3, blue: 0.3)
        self.gray800 = Color(red: 0.2, green: 0.2, blue: 0.2)
        self.gray900 = Color(red: 0.1, green: 0.1, blue: 0.1)

        // Interactive states
        self.hover = Color(UIColor.systemGray5)
        self.pressed = Color(UIColor.systemGray4)
        self.border = Color(UIColor.separator)
        self.divider = Color(UIColor.separator)
        #else
        // Fallback for non-UIKit platforms
        self.textPrimary = Color.primary
        self.textSecondary = Color.secondary
        self.textTertiary = Color.gray
        self.textDisabled = Color.gray.opacity(0.5)

        self.backgroundPrimary = Color.white
        self.backgroundSecondary = Color(white: 0.95)
        self.backgroundTertiary = Color(white: 0.9)
        self.backgroundGrouped = Color(white: 0.95)

        self.primaryBlack = Color.black
        self.primaryWhite = Color.white

        self.gray50 = Color(white: 0.98)
        self.gray100 = Color(white: 0.96)
        self.gray200 = Color(white: 0.9)
        self.gray300 = Color(white: 0.8)
        self.gray400 = Color(white: 0.7)
        self.gray500 = Color.gray
        self.gray600 = Color(white: 0.4)
        self.gray700 = Color(white: 0.3)
        self.gray800 = Color(white: 0.2)
        self.gray900 = Color(white: 0.1)

        self.hover = Color(white: 0.95)
        self.pressed = Color(white: 0.9)
        self.border = Color.gray.opacity(0.3)
        self.divider = Color.gray.opacity(0.3)
        #endif

        // Semantic colors (same across platforms)
        self.info = Color.blue
        self.warning = Color.orange
        self.error = Color.red
        self.success = Color.green

        // Health metric colors
        self.heartRate = Color.red
        self.spo2 = Color.blue
        self.temperature = Color.orange
        self.battery = Color.green
        self.movement = Color.blue
        self.muscleActivity = Color.purple
        self.oralWellness = Color.purple

        // Shadow
        self.shadow = Color.black.opacity(0.1)
    }

    // MARK: - Convenience Methods

    /// Get color for a sensor type
    public func color(for sensorType: SensorType) -> Color {
        switch sensorType {
        case .heartRate:
            return heartRate
        case .spo2:
            return spo2
        case .temperature:
            return temperature
        case .battery:
            return battery
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return movement
        case .emg, .muscleActivity:
            return muscleActivity
        case .ppgRed:
            return Color.red
        case .ppgInfrared:
            return Color.purple
        case .ppgGreen:
            return Color.green
        }
    }

    /// Get color for a device type
    public func color(for deviceType: DeviceType) -> Color {
        switch deviceType {
        case .oralable:
            return oralWellness
        case .anr:
            return muscleActivity
        case .demo:
            return info
        }
    }

    /// Get color for battery level
    public func batteryColor(for percentage: Int) -> Color {
        switch percentage {
        case 0..<15:
            return error
        case 15..<40:
            return warning
        default:
            return success
        }
    }

    /// Get color for signal quality
    public func signalColor(for quality: SignalQuality) -> Color {
        switch quality {
        case .excellent, .good:
            return success
        case .fair:
            return warning
        case .weak, .poor, .unknown:
            return error
        }
    }
}

// MARK: - Color Extensions

public extension Color {

    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Oralable brand purple
    static let oralablePurple = Color(hex: "7B68EE")

    /// Oralable brand colors
    static let oralablePrimary = Color.black
    static let oralableSecondary = Color(hex: "7B68EE")
    static let oralableAccent = Color.purple
}
