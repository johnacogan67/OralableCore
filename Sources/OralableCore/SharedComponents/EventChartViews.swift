//
//  EventChartViews.swift
//  OralableCore
//
//  Created: January 8, 2026
//  Updated: January 15, 2026 - Moved to OralableCore for shared use
//
//  Chart views for displaying muscle activity events
//  Valid events: Green | Invalid events: Black
//
//  Usage:
//  ```swift
//  import OralableCore
//
//  EventChartView(events: myEvents)
//  EventTimelineView(events: myEvents)
//  EventPointChartView(events: myEvents)
//  EventDistributionView(events: myEvents)
//  ```
//

import SwiftUI
import Charts

// MARK: - Event Chart View

/// Chart view that displays muscle activity events with IR values
/// - Valid events: Green (from ColorSystem)
/// - Invalid events: Black (from ColorSystem)
public struct EventChartView: View {

    public let events: [MuscleActivityEvent]

    private let colors = DesignSystem.shared.colors

    public init(events: [MuscleActivityEvent]) {
        self.events = events
    }

    public var body: some View {
        Chart {
            ForEach(events) { event in
                RectangleMark(
                    xStart: .value("Start", event.startTimestamp),
                    xEnd: .value("End", event.endTimestamp),
                    y: .value("IR", event.averageIR)
                )
                .foregroundStyle(event.displayColor)
                .opacity(event.displayOpacity)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let ir = value.as(Double.self) {
                        Text("\(Int(ir / 1000))k")
                    }
                }
            }
        }
        .chartLegend(position: .bottom) {
            HStack(spacing: 20) {
                EventLegendItem(color: colors.eventValid, label: "Valid")
                EventLegendItem(color: colors.eventInvalid, label: "Invalid")
            }
        }
    }
}

// MARK: - Event Timeline View

/// Timeline view showing events as colored segments
/// Valid: Green | Invalid: Black
public struct EventTimelineView: View {

    public let events: [MuscleActivityEvent]

    public init(events: [MuscleActivityEvent]) {
        self.events = events
    }

    public var body: some View {
        Chart {
            ForEach(events) { event in
                RectangleMark(
                    xStart: .value("Start", event.startTimestamp),
                    xEnd: .value("End", event.endTimestamp),
                    yStart: .value("Bottom", 0),
                    yEnd: .value("Top", 1)
                )
                .foregroundStyle(event.displayColor)
                .opacity(event.displayOpacity)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Event Point Chart View

/// Point chart showing event durations over time
/// Valid: Green | Invalid: Black
public struct EventPointChartView: View {

    public let events: [MuscleActivityEvent]

    public init(events: [MuscleActivityEvent]) {
        self.events = events
    }

    public var body: some View {
        Chart {
            ForEach(events) { event in
                PointMark(
                    x: .value("Time", event.startTimestamp),
                    y: .value("Duration", event.durationMs)
                )
                .foregroundStyle(event.displayColor)
                .symbolSize(event.isValid ? 100 : 60)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let ms = value.as(Int.self) {
                        if ms >= 1000 {
                            Text("\(ms / 1000)s")
                        } else {
                            Text("\(ms)ms")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Event Distribution View

/// Combined chart showing event distribution by validation status
public struct EventDistributionView: View {

    public let events: [MuscleActivityEvent]

    private let colors = DesignSystem.shared.colors

    public init(events: [MuscleActivityEvent]) {
        self.events = events
    }

    private var validEvents: [MuscleActivityEvent] {
        events.filter { $0.isValid }
    }

    private var invalidEvents: [MuscleActivityEvent] {
        events.filter { !$0.isValid }
    }

    private var validDuration: Int {
        validEvents.reduce(0) { $0 + $1.durationMs }
    }

    private var invalidDuration: Int {
        invalidEvents.reduce(0) { $0 + $1.durationMs }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Summary stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(validEvents.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(colors.eventValid)
                    Text("Valid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(validDuration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(invalidEvents.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(colors.eventInvalid)
                    Text("Invalid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(invalidDuration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar showing ratio
            GeometryReader { geometry in
                let total = validEvents.count + invalidEvents.count
                let validRatio = total > 0 ? CGFloat(validEvents.count) / CGFloat(total) : 0.5

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(colors.eventValid)
                        .frame(width: geometry.size.width * validRatio)

                    Rectangle()
                        .fill(colors.eventInvalid.opacity(0.7))
                        .frame(width: geometry.size.width * (1 - validRatio))
                }
                .cornerRadius(4)
            }
            .frame(height: 20)
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            return String(format: "%.1fm", seconds / 60.0)
        }
    }
}

// MARK: - Legend Item

/// Legend item helper for chart legends
public struct EventLegendItem: View {

    public let color: Color
    public let label: String

    public init(color: Color, label: String) {
        self.color = color
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EventChartViews_Previews: PreviewProvider {
    static var sampleEvents: [MuscleActivityEvent] {
        [
            MuscleActivityEvent(
                eventNumber: 1,
                eventType: .rest,
                startTimestamp: Date().addingTimeInterval(-3700),
                endTimestamp: Date().addingTimeInterval(-3600),
                startIR: 120000,
                endIR: 155000,
                averageIR: 130000,
                accelX: -5600,
                accelY: 15200,
                accelZ: -1760,
                temperature: 34.0,
                heartRate: 70,
                spO2: 98,
                sleepState: .awake,
                isValid: true
            ),
            MuscleActivityEvent(
                eventNumber: 2,
                eventType: .activity,
                startTimestamp: Date().addingTimeInterval(-3600),
                endTimestamp: Date().addingTimeInterval(-3599.5),
                startIR: 285000,
                endIR: 162000,
                averageIR: 245000,
                accelX: -5608,
                accelY: 15180,
                accelZ: -1756,
                temperature: 34.0,
                heartRate: nil,
                spO2: nil,
                sleepState: nil,
                isValid: false
            ),
            MuscleActivityEvent(
                eventNumber: 3,
                eventType: .rest,
                startTimestamp: Date().addingTimeInterval(-3599.5),
                endTimestamp: Date().addingTimeInterval(-3500),
                startIR: 162000,
                endIR: 148000,
                averageIR: 95000,
                accelX: -5600,
                accelY: 15200,
                accelZ: -1760,
                temperature: 34.1,
                heartRate: 70,
                spO2: 98,
                sleepState: .awake,
                isValid: true
            ),
            MuscleActivityEvent(
                eventNumber: 4,
                eventType: .activity,
                startTimestamp: Date().addingTimeInterval(-3500),
                endTimestamp: Date().addingTimeInterval(-3499),
                startIR: 312000,
                endIR: 158000,
                averageIR: 278000,
                accelX: -4200,
                accelY: 12500,
                accelZ: -2100,
                temperature: 30.0,
                heartRate: nil,
                spO2: nil,
                sleepState: nil,
                isValid: false
            )
        ]
    }

    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Event Timeline")
                    .font(.headline)
                EventTimelineView(events: sampleEvents)
                    .padding()

                Text("Event Duration Chart")
                    .font(.headline)
                EventPointChartView(events: sampleEvents)
                    .frame(height: 200)
                    .padding()

                Text("Event Distribution")
                    .font(.headline)
                EventDistributionView(events: sampleEvents)
                    .padding()

                Text("Event IR Chart")
                    .font(.headline)
                EventChartView(events: sampleEvents)
                    .frame(height: 200)
                    .padding()
            }
            .padding()
        }
        .previewDisplayName("Event Charts - Valid/Invalid")
    }
}
#endif
