//
//  MetricCardView.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared metric card views for displaying sensor values
//

import SwiftUI

// MARK: - Metric Card View

/// Card for displaying a single metric with value, unit, and optional trend
public struct MetricCardView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: MetricTrend?
    let subtitle: String?

    public init(
        title: String,
        value: String,
        unit: String,
        icon: String,
        color: Color,
        trend: MetricTrend? = nil,
        subtitle: String? = nil
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.color = color
        self.trend = trend
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if let trend = trend {
                    TrendIndicator(trend: trend)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(DesignSystem.shared.colors.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Metric Trend

/// Trend direction for metrics
public enum MetricTrend: Sendable {
    case up
    case down
    case stable
    case unknown

    public var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .unknown: return "minus"
        }
    }

    public var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .blue
        case .unknown: return .gray
        }
    }
}

// MARK: - Trend Indicator

/// Small trend indicator view
public struct TrendIndicator: View {
    let trend: MetricTrend

    public init(trend: MetricTrend) {
        self.trend = trend
    }

    public var body: some View {
        Image(systemName: trend.icon)
            .font(.caption)
            .foregroundColor(trend.color)
            .padding(4)
            .background(trend.color.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - Compact Metric View

/// Compact inline metric display
public struct CompactMetricView: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    public init(icon: String, value: String, unit: String, color: Color = .primary) {
        self.icon = icon
        self.value = value
        self.unit = unit
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Large Metric Display

/// Large metric display for primary values
public struct LargeMetricView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color

    public init(value: String, unit: String, label: String, color: Color = .primary) {
        self.value = value
        self.unit = unit
        self.label = label
        self.color = color
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text(unit)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Health Metric Card

/// Specialized card for health metrics (heart rate, SpO2, etc.)
public struct HealthMetricCard: View {
    let sensorType: SensorType
    let value: Double
    let quality: Double?

    public init(sensorType: SensorType, value: Double, quality: Double? = nil) {
        self.sensorType = sensorType
        self.value = value
        self.quality = quality
    }

    private var displayValue: String {
        switch sensorType {
        case .heartRate:
            return String(format: "%.0f", value)
        case .spo2:
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.2f", value)
        }
    }

    private var icon: String {
        switch sensorType {
        case .heartRate:
            return "heart.fill"
        case .spo2:
            return "lungs.fill"
        case .temperature:
            return "thermometer"
        case .battery:
            return "battery.100"
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return "move.3d"
        case .emg, .muscleActivity:
            return "waveform.path.ecg"
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return "waveform"
        }
    }

    private var color: Color {
        let ds = DesignSystem.shared
        return ds.colors.color(for: sensorType)
    }

    public var body: some View {
        MetricCardView(
            title: sensorType.displayName,
            value: displayValue,
            unit: sensorType.unit,
            icon: icon,
            color: color,
            subtitle: quality.map { String(format: "Quality: %.0f%%", $0 * 100) }
        )
    }
}

// MARK: - Metric Grid

/// Grid layout for multiple metrics
public struct MetricGridView<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: Content

    public init(
        columns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    public var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            content
        }
    }
}

// MARK: - Previews

#if DEBUG
struct MetricCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    Text("Standard Metric Cards").font(.headline)
                    MetricCardView(
                        title: "Heart Rate",
                        value: "72",
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .red,
                        trend: .stable,
                        subtitle: "Resting"
                    )

                    MetricCardView(
                        title: "SpO2",
                        value: "98",
                        unit: "%",
                        icon: "lungs.fill",
                        color: .blue,
                        trend: .up
                    )
                }

                Divider()

                Group {
                    Text("Compact Metrics").font(.headline)
                    HStack(spacing: 20) {
                        CompactMetricView(icon: "heart.fill", value: "72", unit: "bpm", color: .red)
                        CompactMetricView(icon: "lungs.fill", value: "98", unit: "%", color: .blue)
                        CompactMetricView(icon: "thermometer", value: "36.5", unit: "°C", color: .orange)
                    }
                }

                Divider()

                Group {
                    Text("Large Metric Display").font(.headline)
                    LargeMetricView(value: "72", unit: "bpm", label: "Heart Rate", color: .red)
                }

                Divider()

                Group {
                    Text("Health Metric Cards").font(.headline)
                    MetricGridView {
                        HealthMetricCard(sensorType: .heartRate, value: 72, quality: 0.95)
                        HealthMetricCard(sensorType: .spo2, value: 98, quality: 0.88)
                        HealthMetricCard(sensorType: .temperature, value: 36.5)
                        HealthMetricCard(sensorType: .battery, value: 85)
                    }
                }
            }
            .padding()
        }
        .background(DesignSystem.shared.colors.backgroundGrouped)
    }
}
#endif
