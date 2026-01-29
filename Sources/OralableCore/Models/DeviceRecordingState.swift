//
//  DeviceRecordingState.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Represents the recording state of the Oralable device based on
//  sensor data quality and positioning.
//
//  States:
//  - DataStreaming (Black): Device connected, receiving data, but not positioned
//  - Positioned (Green): Device positioned on skin, optical metrics valid
//  - Activity (Red): Device calibrated and detecting muscle activity above threshold
//
//  State transitions are automatic based on sensor data analysis.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Device Recording State

/// State of the device for recording purposes
public enum DeviceRecordingState: String, Codable, CaseIterable, Sendable {
    /// Device is streaming data but not positioned on skin
    /// Visual indicator: Black
    case dataStreaming = "DataStreaming"

    /// Device is positioned on skin with valid optical metrics (HR, SpO2, or PI)
    /// Visual indicator: Green
    case positioned = "Positioned"

    /// Device is calibrated and detecting muscle activity above threshold
    /// Visual indicator: Red
    case activity = "Activity"

    // MARK: - Display Properties

    /// Human-readable description of the state
    public var displayName: String {
        switch self {
        case .dataStreaming:
            return "Data Streaming"
        case .positioned:
            return "Positioned"
        case .activity:
            return "Activity"
        }
    }

    /// Short description for charts and compact displays
    public var shortName: String {
        switch self {
        case .dataStreaming:
            return "Streaming"
        case .positioned:
            return "Ready"
        case .activity:
            return "Active"
        }
    }

    #if canImport(SwiftUI)
    /// Color associated with this state for UI display
    public var color: Color {
        switch self {
        case .dataStreaming:
            return .black
        case .positioned:
            return .green
        case .activity:
            return .red
        }
    }

    /// Color with opacity for chart backgrounds
    public var colorWithOpacity: Color {
        switch self {
        case .dataStreaming:
            return .black.opacity(0.6)
        case .positioned:
            return .green.opacity(0.7)
        case .activity:
            return .red.opacity(0.8)
        }
    }
    #endif

    /// Whether this state indicates valid device positioning
    public var isPositioned: Bool {
        switch self {
        case .dataStreaming:
            return false
        case .positioned, .activity:
            return true
        }
    }

    /// Whether this state indicates active muscle activity detection
    public var isActive: Bool {
        self == .activity
    }
}

// MARK: - State Transition

/// Represents a transition between recording states
public struct StateTransition: Sendable {
    public let fromState: DeviceRecordingState?
    public let toState: DeviceRecordingState
    public let timestamp: Date

    public init(from: DeviceRecordingState?, to: DeviceRecordingState, at timestamp: Date = Date()) {
        self.fromState = from
        self.toState = to
        self.timestamp = timestamp
    }

    /// Whether this is the initial state (no previous state)
    public var isInitial: Bool {
        fromState == nil
    }
}
