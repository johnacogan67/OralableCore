//
//  BatteryIndicatorView.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared battery indicator views for Oralable apps
//

import SwiftUI

// MARK: - Battery Compact View

/// Compact battery indicator with icon and percentage
public struct BatteryCompactView: View {
    let percentage: Double
    let status: BatteryStatus

    public init(percentage: Double) {
        self.percentage = percentage
        self.status = BatteryConversion.batteryStatus(percentage: percentage)
    }

    public init(millivolts: Int32) {
        self.percentage = BatteryConversion.voltageToPercentage(millivolts: millivolts)
        self.status = BatteryConversion.batteryStatus(percentage: percentage)
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImageName)
                .foregroundColor(status.color)

            Text(BatteryConversion.formatPercentage(percentage))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Battery Bar View

/// Horizontal battery bar indicator
public struct BatteryBarView: View {
    let percentage: Double
    let status: BatteryStatus
    let height: CGFloat

    public init(percentage: Double, height: CGFloat = 24) {
        self.percentage = percentage
        self.status = BatteryConversion.batteryStatus(percentage: percentage)
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 6)
                    .fill(status.color)
                    .frame(width: max(0, geometry.size.width * CGFloat(percentage / 100.0)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Battery Display View

/// Full battery display with icon, percentage, and optional voltage
public struct BatteryDisplayView: View {
    let millivolts: Int32
    let showVoltage: Bool

    private var percentage: Double {
        BatteryConversion.voltageToPercentage(millivolts: millivolts)
    }

    private var status: BatteryStatus {
        BatteryConversion.batteryStatus(percentage: percentage)
    }

    public init(millivolts: Int32, showVoltage: Bool = true) {
        self.millivolts = millivolts
        self.showVoltage = showVoltage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.systemImageName)
                    .foregroundColor(status.color)
                    .font(.title2)

                Text("Battery")
                    .font(.headline)

                Spacer()

                Text(status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.2))
                    .foregroundColor(status.color)
                    .cornerRadius(8)
            }

            BatteryBarView(percentage: percentage)

            HStack {
                Text(BatteryConversion.formatPercentage(percentage))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)

                Spacer()

                if showVoltage {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(BatteryConversion.formatVoltage(millivolts: millivolts))
                            .font(.system(.body, design: .monospaced))
                        Text("voltage")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if BatteryConversion.needsCharging(percentage: percentage) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(BatteryConversion.isCritical(percentage: percentage) ? .red : .orange)
                    Text(BatteryConversion.isCritical(percentage: percentage) ? "Battery critically low!" : "Battery low - charge soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(DesignSystem.shared.colors.backgroundPrimary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Battery Card View

/// Card-style battery display with icon, status, and bar
public struct BatteryCardView: View {
    let millivolts: Int32
    let isCharging: Bool

    private var percentage: Double {
        BatteryConversion.voltageToPercentage(millivolts: millivolts)
    }

    private var status: BatteryStatus {
        BatteryConversion.batteryStatus(percentage: percentage)
    }

    public init(millivolts: Int32, isCharging: Bool = false) {
        self.millivolts = millivolts
        self.isCharging = isCharging
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: isCharging ? "battery.100.bolt" : status.systemImageName)
                        .foregroundColor(status.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery")
                        .font(.headline)
                    Text(isCharging ? "Charging" : status.rawValue)
                        .font(.caption)
                        .foregroundColor(isCharging ? .green : status.color)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", percentage))
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            BatteryBarView(percentage: percentage)

            HStack {
                Text("Voltage:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(BatteryConversion.formatVoltage(millivolts: millivolts))
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
        .background(DesignSystem.shared.colors.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Battery Icon View

/// Simple battery icon that changes based on level
public struct BatteryIconView: View {
    let percentage: Double
    let size: CGFloat

    private var status: BatteryStatus {
        BatteryConversion.batteryStatus(percentage: percentage)
    }

    public init(percentage: Double, size: CGFloat = 24) {
        self.percentage = percentage
        self.size = size
    }

    public init(millivolts: Int32, size: CGFloat = 24) {
        self.percentage = BatteryConversion.voltageToPercentage(millivolts: millivolts)
        self.size = size
    }

    public var body: some View {
        Image(systemName: status.systemImageName)
            .font(.system(size: size))
            .foregroundColor(status.color)
    }
}

// MARK: - Previews

#if DEBUG
struct BatteryIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    Text("Compact Views").font(.headline)
                    HStack(spacing: 20) {
                        BatteryCompactView(millivolts: 4100)
                        BatteryCompactView(millivolts: 3700)
                        BatteryCompactView(millivolts: 3300)
                    }
                }

                Divider()

                Group {
                    Text("Battery Icons").font(.headline)
                    HStack(spacing: 20) {
                        BatteryIconView(percentage: 100, size: 32)
                        BatteryIconView(percentage: 75, size: 32)
                        BatteryIconView(percentage: 50, size: 32)
                        BatteryIconView(percentage: 25, size: 32)
                        BatteryIconView(percentage: 5, size: 32)
                    }
                }

                Divider()

                Group {
                    Text("Full Display Views").font(.headline)
                    BatteryDisplayView(millivolts: 4150)
                    BatteryDisplayView(millivolts: 3450)
                }

                Divider()

                Group {
                    Text("Card Views").font(.headline)
                    BatteryCardView(millivolts: 4000, isCharging: false)
                    BatteryCardView(millivolts: 3800, isCharging: true)
                }
            }
            .padding()
        }
        .background(DesignSystem.shared.colors.backgroundGrouped)
    }
}
#endif
