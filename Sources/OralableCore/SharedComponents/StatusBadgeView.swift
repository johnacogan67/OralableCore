//
//  StatusBadgeView.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared status badge views for displaying states and statuses
//

import SwiftUI

// MARK: - Status Badge View

/// Generic status badge with icon and label
public struct StatusBadgeView: View {
    let text: String
    let icon: String?
    let color: Color
    let style: StatusBadgeStyle

    public enum StatusBadgeStyle {
        case filled
        case outlined
        case subtle
    }

    public init(
        text: String,
        icon: String? = nil,
        color: Color = .blue,
        style: StatusBadgeStyle = .subtle
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style == .outlined ? color : Color.clear, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:
            return color
        case .outlined:
            return Color.clear
        case .subtle:
            return color.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .outlined, .subtle:
            return color
        }
    }
}

// MARK: - Connection Status Badge

/// Badge for showing device connection status
public struct ConnectionBadge: View {
    let state: DeviceConnectionState

    public init(state: DeviceConnectionState) {
        self.state = state
    }

    private var color: Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .disconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }

    private var icon: String {
        switch state {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "circle"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    public var body: some View {
        StatusBadgeView(
            text: state.description,
            icon: icon,
            color: color,
            style: .subtle
        )
    }
}

// MARK: - Recording Status Badge

/// Badge for showing recording status
public struct RecordingBadge: View {
    let status: RecordingStatus

    public init(status: RecordingStatus) {
        self.status = status
    }

    private var color: Color {
        switch status {
        case .recording:
            return .red
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var icon: String {
        switch status {
        case .recording:
            return "record.circle"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    public var body: some View {
        StatusBadgeView(
            text: status.rawValue,
            icon: icon,
            color: color,
            style: status == .recording ? .filled : .subtle
        )
    }
}

// MARK: - Device Type Badge

/// Badge for showing device type
public struct DeviceTypeBadge: View {
    let type: DeviceType

    public init(type: DeviceType) {
        self.type = type
    }

    private var color: Color {
        DesignSystem.shared.colors.color(for: type)
    }

    private var icon: String {
        switch type {
        case .oralable:
            return "mouth"
        case .anr:
            return "waveform.path.ecg"
        case .demo:
            return "play.circle"
        }
    }

    public var body: some View {
        StatusBadgeView(
            text: type.displayName,
            icon: icon,
            color: color,
            style: .subtle
        )
    }
}

// MARK: - Quality Badge

/// Badge for showing data quality
public struct QualityBadge: View {
    let quality: Double // 0.0 to 1.0

    public init(quality: Double) {
        self.quality = max(0, min(1, quality))
    }

    private var qualityLevel: String {
        switch quality {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "Good"
        case 0.4..<0.6:
            return "Fair"
        case 0.2..<0.4:
            return "Poor"
        default:
            return "Low"
        }
    }

    private var color: Color {
        switch quality {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .blue
        case 0.4..<0.6:
            return .yellow
        case 0.2..<0.4:
            return .orange
        default:
            return .red
        }
    }

    public var body: some View {
        StatusBadgeView(
            text: qualityLevel,
            icon: "chart.bar.fill",
            color: color,
            style: .subtle
        )
    }
}

// MARK: - Activity Badge

/// Badge for showing activity type
public struct ActivityBadge: View {
    let activity: ActivityType

    public init(activity: ActivityType) {
        self.activity = activity
    }

    private var color: Color {
        switch activity {
        case .relaxed:
            return .green
        case .motion:
            return .blue
        case .clenching:
            return .orange
        case .grinding:
            return .purple
        }
    }

    public var body: some View {
        StatusBadgeView(
            text: activity.description,
            icon: activity.iconName,
            color: color,
            style: .subtle
        )
    }
}

// MARK: - Worn Status Badge

/// Badge for showing if device is worn
public struct WornStatusBadge: View {
    let isWorn: Bool

    public init(isWorn: Bool) {
        self.isWorn = isWorn
    }

    public var body: some View {
        StatusBadgeView(
            text: isWorn ? "Worn" : "Not Worn",
            icon: isWorn ? "person.fill" : "person",
            color: isWorn ? .green : .gray,
            style: .subtle
        )
    }
}

// MARK: - Pill Badge

/// Simple pill-shaped badge (no icon)
public struct PillBadge: View {
    let text: String
    let color: Color

    public init(text: String, color: Color = .blue) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Dot Badge

/// Simple dot indicator with optional count
public struct DotBadge: View {
    let color: Color
    let count: Int?
    let size: CGFloat

    public init(color: Color = .red, count: Int? = nil, size: CGFloat = 8) {
        self.color = color
        self.count = count
        self.size = size
    }

    public var body: some View {
        if let count = count, count > 0 {
            Text("\(count)")
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: size * 2, minHeight: size * 2)
                .background(color)
                .clipShape(Capsule())
        } else {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct StatusBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    Text("Generic Badges").font(.headline)
                    HStack(spacing: 10) {
                        StatusBadgeView(text: "Active", icon: "checkmark", color: .green, style: .filled)
                        StatusBadgeView(text: "Pending", icon: "clock", color: .orange, style: .outlined)
                        StatusBadgeView(text: "Inactive", icon: "xmark", color: .gray, style: .subtle)
                    }
                }

                Divider()

                Group {
                    Text("Connection Badges").font(.headline)
                    HStack(spacing: 10) {
                        ConnectionBadge(state: .connected)
                        ConnectionBadge(state: .connecting)
                        ConnectionBadge(state: .disconnected)
                        ConnectionBadge(state: .failed)
                    }
                }

                Divider()

                Group {
                    Text("Recording Badges").font(.headline)
                    HStack(spacing: 10) {
                        RecordingBadge(status: .recording)
                        RecordingBadge(status: .paused)
                        RecordingBadge(status: .completed)
                    }
                }

                Divider()

                Group {
                    Text("Device Type Badges").font(.headline)
                    HStack(spacing: 10) {
                        DeviceTypeBadge(type: .oralable)
                        DeviceTypeBadge(type: .anr)
                        DeviceTypeBadge(type: .demo)
                    }
                }

                Divider()

                Group {
                    Text("Quality Badges").font(.headline)
                    HStack(spacing: 10) {
                        QualityBadge(quality: 0.95)
                        QualityBadge(quality: 0.7)
                        QualityBadge(quality: 0.3)
                    }
                }

                Divider()

                Group {
                    Text("Activity Badges").font(.headline)
                    HStack(spacing: 10) {
                        ActivityBadge(activity: .relaxed)
                        ActivityBadge(activity: .clenching)
                        ActivityBadge(activity: .grinding)
                    }
                }

                Divider()

                Group {
                    Text("Other Badges").font(.headline)
                    HStack(spacing: 10) {
                        WornStatusBadge(isWorn: true)
                        WornStatusBadge(isWorn: false)
                        PillBadge(text: "New", color: .blue)
                        DotBadge(color: .red, count: 5)
                    }
                }
            }
            .padding()
        }
        .background(DesignSystem.shared.colors.backgroundGrouped)
    }
}
#endif
