//
//  PPGChartView.swift
//  OralableCore
//
//  Created: January 15, 2026
//
//  Shared PPG chart view for displaying photoplethysmography sensor data.
//  Supports IR, Red, and Green channels with threshold and baseline indicators.
//
//  Usage:
//  ```swift
//  import OralableCore
//
//  // Simple usage with IR data only
//  PPGChartView(data: irDataPoints)
//
//  // Full usage with all channels and threshold
//  PPGChartView(
//      irData: irPoints,
//      redData: redPoints,
//      greenData: greenPoints,
//      threshold: 180000,
//      baseline: 120000
//  )
//  ```
//

import SwiftUI
import Charts

// MARK: - PPG Data Point

/// A single PPG data point with timestamp and value
public struct PPGDataPoint: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double

    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - PPG Channel

/// PPG sensor channel type
public enum PPGChannel: String, CaseIterable, Sendable {
    case infrared = "IR"
    case red = "Red"
    case green = "Green"

    /// Display name for the channel
    public var displayName: String {
        switch self {
        case .infrared: return "Infrared"
        case .red: return "Red"
        case .green: return "Green"
        }
    }

    /// Color for the channel from ColorSystem
    public var color: Color {
        let colors = DesignSystem.shared.colors
        switch self {
        case .infrared: return colors.ppgInfraredChart
        case .red: return colors.ppgRedChart
        case .green: return colors.ppgGreenChart
        }
    }
}

// MARK: - PPG Chart Configuration

/// Configuration options for PPGChartView
public struct PPGChartConfiguration: Sendable {
    /// Show threshold line
    public var showThreshold: Bool

    /// Show baseline indicator
    public var showBaseline: Bool

    /// Show grid lines
    public var showGrid: Bool

    /// Chart height
    public var height: CGFloat

    /// Line width for data lines
    public var lineWidth: CGFloat

    /// Show area fill under lines
    public var showAreaFill: Bool

    /// Interpolation method for lines
    public var smoothLines: Bool

    public init(
        showThreshold: Bool = true,
        showBaseline: Bool = true,
        showGrid: Bool = true,
        height: CGFloat = 200,
        lineWidth: CGFloat = 2,
        showAreaFill: Bool = true,
        smoothLines: Bool = true
    ) {
        self.showThreshold = showThreshold
        self.showBaseline = showBaseline
        self.showGrid = showGrid
        self.height = height
        self.lineWidth = lineWidth
        self.showAreaFill = showAreaFill
        self.smoothLines = smoothLines
    }

    /// Default configuration
    public static let `default` = PPGChartConfiguration()

    /// Compact configuration for smaller displays
    public static let compact = PPGChartConfiguration(
        showThreshold: false,
        showBaseline: false,
        showGrid: false,
        height: 100,
        lineWidth: 1.5,
        showAreaFill: false,
        smoothLines: true
    )

    /// Detailed configuration for analysis views
    public static let detailed = PPGChartConfiguration(
        showThreshold: true,
        showBaseline: true,
        showGrid: true,
        height: 300,
        lineWidth: 2.5,
        showAreaFill: true,
        smoothLines: true
    )
}

// MARK: - PPG Chart View

/// Shared PPG chart view for displaying photoplethysmography sensor data
public struct PPGChartView: View {

    // MARK: - Properties

    /// Infrared channel data
    public let irData: [PPGDataPoint]

    /// Red channel data (optional)
    public let redData: [PPGDataPoint]

    /// Green channel data (optional)
    public let greenData: [PPGDataPoint]

    /// Detection threshold value (optional)
    public let threshold: Double?

    /// Calibrated baseline value (optional)
    public let baseline: Double?

    /// Chart configuration
    public let configuration: PPGChartConfiguration

    /// Selected data point for tooltip
    @Binding public var selectedPoint: PPGDataPoint?

    private let colors = DesignSystem.shared.colors

    // MARK: - Initializers

    /// Initialize with IR data only
    public init(
        data: [PPGDataPoint],
        threshold: Double? = nil,
        baseline: Double? = nil,
        configuration: PPGChartConfiguration = .default,
        selectedPoint: Binding<PPGDataPoint?> = .constant(nil)
    ) {
        self.irData = data
        self.redData = []
        self.greenData = []
        self.threshold = threshold
        self.baseline = baseline
        self.configuration = configuration
        self._selectedPoint = selectedPoint
    }

    /// Initialize with all channels
    public init(
        irData: [PPGDataPoint],
        redData: [PPGDataPoint] = [],
        greenData: [PPGDataPoint] = [],
        threshold: Double? = nil,
        baseline: Double? = nil,
        configuration: PPGChartConfiguration = .default,
        selectedPoint: Binding<PPGDataPoint?> = .constant(nil)
    ) {
        self.irData = irData
        self.redData = redData
        self.greenData = greenData
        self.threshold = threshold
        self.baseline = baseline
        self.configuration = configuration
        self._selectedPoint = selectedPoint
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if irData.isEmpty && redData.isEmpty && greenData.isEmpty {
                emptyStateView
            } else {
                chartView
                legendView
            }
        }
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            // IR Channel
            ForEach(irData) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("IR", point.value)
                )
                .foregroundStyle(PPGChannel.infrared.color)
                .lineStyle(StrokeStyle(
                    lineWidth: configuration.lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .interpolationMethod(configuration.smoothLines ? .catmullRom : .linear)

                if configuration.showAreaFill {
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("IR", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PPGChannel.infrared.color.opacity(0.2), PPGChannel.infrared.color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(configuration.smoothLines ? .catmullRom : .linear)
                }
            }

            // Red Channel
            if !redData.isEmpty {
                ForEach(redData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Red", point.value)
                    )
                    .foregroundStyle(PPGChannel.red.color)
                    .lineStyle(StrokeStyle(
                        lineWidth: configuration.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .interpolationMethod(configuration.smoothLines ? .catmullRom : .linear)
                }
            }

            // Green Channel
            if !greenData.isEmpty {
                ForEach(greenData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Green", point.value)
                    )
                    .foregroundStyle(PPGChannel.green.color)
                    .lineStyle(StrokeStyle(
                        lineWidth: configuration.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .interpolationMethod(configuration.smoothLines ? .catmullRom : .linear)
                }
            }

            // Threshold Line
            if configuration.showThreshold, let threshold = threshold {
                RuleMark(y: .value("Threshold", threshold))
                    .foregroundStyle(colors.thresholdLine)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Threshold")
                            .font(.caption2)
                            .foregroundColor(colors.thresholdLine)
                            .padding(.horizontal, 4)
                    }
            }

            // Baseline Indicator
            if configuration.showBaseline, let baseline = baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(colors.baselineIndicator)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Baseline")
                            .font(.caption2)
                            .foregroundColor(colors.baselineIndicator)
                            .padding(.horizontal, 4)
                    }
            }

            // Selected Point Indicator
            if let selected = selectedPoint {
                PointMark(
                    x: .value("Time", selected.timestamp),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(colors.textPrimary)
                .symbolSize(100)

                RuleMark(x: .value("Time", selected.timestamp))
                    .foregroundStyle(colors.divider)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .frame(height: configuration.height)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                if configuration.showGrid {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(colors.divider)
                }
                AxisValueLabel(format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                if configuration.showGrid {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(colors.divider)
                }
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatYAxisValue(doubleValue))
                            .font(.caption2)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Legend View

    private var legendView: some View {
        HStack(spacing: 16) {
            if !irData.isEmpty {
                PPGLegendItem(channel: .infrared)
            }
            if !redData.isEmpty {
                PPGLegendItem(channel: .red)
            }
            if !greenData.isEmpty {
                PPGLegendItem(channel: .green)
            }

            Spacer()

            if configuration.showThreshold, threshold != nil {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(colors.thresholdLine)
                        .frame(width: 16, height: 2)
                    Text("Threshold")
                        .font(.caption2)
                        .foregroundColor(colors.textSecondary)
                }
            }

            if configuration.showBaseline, baseline != nil {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(colors.baselineIndicator)
                        .frame(width: 16, height: 2)
                    Text("Baseline")
                        .font(.caption2)
                        .foregroundColor(colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40))
                .foregroundColor(colors.textTertiary)
            Text("No PPG data available")
                .font(.subheadline)
                .foregroundColor(colors.textSecondary)
        }
        .frame(height: configuration.height)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formatYAxisValue(_ value: Double) -> String {
        if value >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - PPG Legend Item

/// Legend item for PPG channels
public struct PPGLegendItem: View {
    public let channel: PPGChannel

    public init(channel: PPGChannel) {
        self.channel = channel
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(channel.color)
                .frame(width: 8, height: 8)
            Text(channel.displayName)
                .font(.caption2)
                .foregroundColor(DesignSystem.shared.colors.textSecondary)
        }
    }
}

// MARK: - PPG Real-Time Chart View

/// Real-time PPG chart for live sensor data display
public struct PPGRealTimeChartView: View {

    /// Rolling buffer of data points
    @Binding public var dataPoints: [PPGDataPoint]

    /// Maximum number of points to display
    public let maxPoints: Int

    /// Current threshold value
    public let threshold: Double?

    /// Current baseline value
    public let baseline: Double?

    public init(
        dataPoints: Binding<[PPGDataPoint]>,
        maxPoints: Int = 100,
        threshold: Double? = nil,
        baseline: Double? = nil
    ) {
        self._dataPoints = dataPoints
        self.maxPoints = maxPoints
        self.threshold = threshold
        self.baseline = baseline
    }

    public var body: some View {
        PPGChartView(
            data: Array(dataPoints.suffix(maxPoints)),
            threshold: threshold,
            baseline: baseline,
            configuration: PPGChartConfiguration(
                showThreshold: threshold != nil,
                showBaseline: baseline != nil,
                showGrid: true,
                height: 150,
                lineWidth: 2,
                showAreaFill: false,
                smoothLines: false
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct PPGChartView_Previews: PreviewProvider {
    static var sampleIRData: [PPGDataPoint] {
        let now = Date()
        return (0..<60).map { i in
            let timestamp = now.addingTimeInterval(Double(i) * -1)
            let baseValue = 120000.0
            let variation = sin(Double(i) * 0.3) * 30000 + Double.random(in: -5000...5000)
            return PPGDataPoint(timestamp: timestamp, value: baseValue + variation)
        }.reversed()
    }

    static var sampleRedData: [PPGDataPoint] {
        let now = Date()
        return (0..<60).map { i in
            let timestamp = now.addingTimeInterval(Double(i) * -1)
            let baseValue = 80000.0
            let variation = sin(Double(i) * 0.3) * 15000 + Double.random(in: -3000...3000)
            return PPGDataPoint(timestamp: timestamp, value: baseValue + variation)
        }.reversed()
    }

    static var previews: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("PPG Chart - Default")
                    .font(.headline)
                PPGChartView(
                    data: sampleIRData,
                    threshold: 150000,
                    baseline: 120000
                )
                .padding()

                Text("PPG Chart - Compact")
                    .font(.headline)
                PPGChartView(
                    data: sampleIRData,
                    configuration: .compact
                )
                .padding()

                Text("PPG Chart - Multi-Channel")
                    .font(.headline)
                PPGChartView(
                    irData: sampleIRData,
                    redData: sampleRedData,
                    threshold: 150000,
                    baseline: 120000,
                    configuration: .detailed
                )
                .padding()

                Text("PPG Chart - Empty State")
                    .font(.headline)
                PPGChartView(data: [])
                    .padding()
            }
            .padding()
        }
        .previewDisplayName("PPG Chart Views")
    }
}
#endif
