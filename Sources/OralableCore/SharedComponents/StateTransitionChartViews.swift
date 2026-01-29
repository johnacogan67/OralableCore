//
//  StateTransitionChartViews.swift
//  OralableCore
//
//  Created: January 29, 2026
//
//  Chart views for displaying state transition data.
//
//  Components:
//  - StateTimelineView: Timeline showing colored segments for each state
//  - StateDistributionView: Pie or bar chart showing time distribution
//  - StateLegendView: Legend explaining the three states and colors
//

import Foundation

#if canImport(SwiftUI) && canImport(Charts) && canImport(UIKit)
import SwiftUI
import Charts
import UIKit

// MARK: - State Timeline View

/// Timeline view showing state transitions as colored segments
@available(iOS 16.0, *)
public struct StateTimelineView: View {
    let events: [StateTransitionEvent]
    let endTime: Date

    public init(events: [StateTransitionEvent], endTime: Date = Date()) {
        self.events = events
        self.endTime = endTime
    }

    public var body: some View {
        GeometryReader { geometry in
            if events.isEmpty {
                Text("No data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Canvas { context, size in
                    drawTimeline(context: context, size: size)
                }
            }
        }
        .frame(height: 40)
    }

    private func drawTimeline(context: GraphicsContext, size: CGSize) {
        let sorted = events.sortedByTime
        guard let firstEvent = sorted.first else { return }

        let startTime = firstEvent.timestamp
        let totalDuration = endTime.timeIntervalSince(startTime)
        guard totalDuration > 0 else { return }

        for (index, event) in sorted.enumerated() {
            let nextTime: Date
            if index + 1 < sorted.count {
                nextTime = sorted[index + 1].timestamp
            } else {
                nextTime = endTime
            }

            let eventStart = event.timestamp.timeIntervalSince(startTime)
            let eventDuration = nextTime.timeIntervalSince(event.timestamp)

            let x = CGFloat(eventStart / totalDuration) * size.width
            let width = CGFloat(eventDuration / totalDuration) * size.width

            let rect = CGRect(x: x, y: 0, width: max(width, 1), height: size.height)
            let color = colorForState(event.state)

            context.fill(Path(rect), with: .color(color))
        }
    }

    private func colorForState(_ state: DeviceRecordingState) -> Color {
        switch state {
        case .dataStreaming:
            return .black.opacity(0.7)
        case .positioned:
            return .green.opacity(0.8)
        case .activity:
            return .red.opacity(0.8)
        }
    }
}

// MARK: - State Distribution View

/// Bar chart showing time distribution across states
@available(iOS 16.0, *)
public struct StateDistributionView: View {
    let events: [StateTransitionEvent]
    let endTime: Date

    public init(events: [StateTransitionEvent], endTime: Date = Date()) {
        self.events = events
        self.endTime = endTime
    }

    private var timeInStates: [DeviceRecordingState: TimeInterval] {
        events.timeInStates(endTime: endTime)
    }

    private var totalTime: TimeInterval {
        timeInStates.values.reduce(0, +)
    }

    public var body: some View {
        if events.isEmpty {
            Text("No data")
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(DeviceRecordingState.allCases, id: \.self) { state in
                    stateRow(state: state)
                }
            }
        }
    }

    private func stateRow(state: DeviceRecordingState) -> some View {
        let duration = timeInStates[state] ?? 0
        let percentage = totalTime > 0 ? (duration / totalTime) * 100 : 0

        return HStack {
            Circle()
                .fill(state.color)
                .frame(width: 12, height: 12)

            Text(state.displayName)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(state.color.opacity(0.7))
                    .frame(width: geometry.size.width * CGFloat(percentage / 100))
            }
            .frame(height: 16)

            Text(formatDuration(duration))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.0f%%", percentage))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - State Legend View

/// Legend explaining the three recording states
public struct StateLegendView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 16) {
            legendItem(state: .dataStreaming)
            legendItem(state: .positioned)
            legendItem(state: .activity)
        }
    }

    private func legendItem(state: DeviceRecordingState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 10, height: 10)

            Text(state.shortName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - State Summary Card

/// Summary card showing state statistics
@available(iOS 16.0, *)
public struct StateSummaryCard: View {
    let events: [StateTransitionEvent]
    let endTime: Date

    public init(events: [StateTransitionEvent], endTime: Date = Date()) {
        self.events = events
        self.endTime = endTime
    }

    private var summary: StateEventExportSummary {
        StateEventCSVExporter.getSummary(events: events)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Summary")
                .font(.headline)

            HStack {
                summaryItem(title: "Events", value: "\(events.count)")
                Spacer()
                summaryItem(title: "Duration", value: summary.formattedTotalDuration)
            }

            Divider()

            StateDistributionView(events: events, endTime: endTime)

            Divider()

            StateLegendView()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
        }
    }
}

// MARK: - Previews

@available(iOS 16.0, *)
struct StateTransitionChartViews_Previews: PreviewProvider {
    static var sampleEvents: [StateTransitionEvent] {
        let now = Date()
        return [
            StateTransitionEvent(
                timestamp: now.addingTimeInterval(-3600),
                state: .dataStreaming,
                irValue: 100000,
                temperature: 25.0,
                accelX: 0, accelY: 0, accelZ: 16384
            ),
            StateTransitionEvent(
                timestamp: now.addingTimeInterval(-3000),
                state: .positioned,
                irValue: 150000,
                heartRate: 72,
                temperature: 34.5,
                accelX: 0, accelY: 0, accelZ: 16384
            ),
            StateTransitionEvent(
                timestamp: now.addingTimeInterval(-2400),
                state: .activity,
                irValue: 200000,
                normalizedIRPercent: 45.0,
                heartRate: 75,
                temperature: 35.0,
                accelX: 0, accelY: 0, accelZ: 16384
            ),
            StateTransitionEvent(
                timestamp: now.addingTimeInterval(-1800),
                state: .positioned,
                irValue: 140000,
                normalizedIRPercent: 20.0,
                heartRate: 70,
                temperature: 34.8,
                accelX: 0, accelY: 0, accelZ: 16384
            ),
            StateTransitionEvent(
                timestamp: now.addingTimeInterval(-600),
                state: .activity,
                irValue: 210000,
                normalizedIRPercent: 50.0,
                heartRate: 78,
                temperature: 35.2,
                accelX: 0, accelY: 0, accelZ: 16384
            )
        ]
    }

    static var previews: some View {
        VStack(spacing: 20) {
            Text("State Timeline")
                .font(.headline)
            StateTimelineView(events: sampleEvents)
                .padding()

            Divider()

            Text("State Distribution")
                .font(.headline)
            StateDistributionView(events: sampleEvents)
                .padding()

            Divider()

            StateLegendView()
                .padding()

            Divider()

            StateSummaryCard(events: sampleEvents)
                .padding()
        }
        .padding()
    }
}

#endif
