//
//  SignalStrengthView.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Shared signal strength indicator views for Oralable apps
//

import SwiftUI

// MARK: - Signal Bars View

/// Classic signal bars indicator (like WiFi/cellular)
public struct SignalBarsView: View {
    let quality: SignalQuality
    let barCount: Int
    let spacing: CGFloat
    let barWidth: CGFloat
    let maxHeight: CGFloat

    public init(
        quality: SignalQuality,
        barCount: Int = 4,
        spacing: CGFloat = 2,
        barWidth: CGFloat = 4,
        maxHeight: CGFloat = 16
    ) {
        self.quality = quality
        self.barCount = barCount
        self.spacing = spacing
        self.barWidth = barWidth
        self.maxHeight = maxHeight
    }

    public init(
        rssi: Int,
        barCount: Int = 4,
        spacing: CGFloat = 2,
        barWidth: CGFloat = 4,
        maxHeight: CGFloat = 16
    ) {
        self.quality = SignalQuality.from(rssi: rssi)
        self.barCount = barCount
        self.spacing = spacing
        self.barWidth = barWidth
        self.maxHeight = maxHeight
    }

    private var filledBars: Int {
        quality.bars
    }

    private var color: Color {
        switch quality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .weak, .poor, .unknown:
            return .red
        }
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let height = maxHeight * CGFloat(index + 1) / CGFloat(barCount)
                let isFilled = index < filledBars

                RoundedRectangle(cornerRadius: 1)
                    .fill(isFilled ? color : Color.gray.opacity(0.3))
                    .frame(width: barWidth, height: height)
            }
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Signal Compact View

/// Compact signal indicator with icon and label
public struct SignalCompactView: View {
    let quality: SignalQuality
    let showLabel: Bool

    public init(quality: SignalQuality, showLabel: Bool = true) {
        self.quality = quality
        self.showLabel = showLabel
    }

    public init(rssi: Int, showLabel: Bool = true) {
        self.quality = SignalQuality.from(rssi: rssi)
        self.showLabel = showLabel
    }

    private var color: Color {
        switch quality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .weak, .poor, .unknown:
            return .red
        }
    }

    private var iconName: String {
        switch quality {
        case .excellent:
            return "wifi"
        case .good:
            return "wifi"
        case .fair:
            return "wifi"
        case .weak:
            return "wifi.exclamationmark"
        case .poor, .unknown:
            return "wifi.slash"
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundColor(color)

            if showLabel {
                Text(quality.description)
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Signal Badge View

/// Badge-style signal indicator
public struct SignalBadgeView: View {
    let quality: SignalQuality

    public init(quality: SignalQuality) {
        self.quality = quality
    }

    public init(rssi: Int) {
        self.quality = SignalQuality.from(rssi: rssi)
    }

    private var color: Color {
        switch quality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .weak, .poor, .unknown:
            return .red
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            SignalBarsView(quality: quality, maxHeight: 12)

            Text(quality.description)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Signal Card View

/// Card-style signal strength display with RSSI value
public struct SignalCardView: View {
    let rssi: Int
    let quality: SignalQuality
    let showRSSI: Bool

    public init(rssi: Int, showRSSI: Bool = true) {
        self.rssi = rssi
        self.quality = SignalQuality.from(rssi: rssi)
        self.showRSSI = showRSSI
    }

    private var color: Color {
        switch quality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .weak, .poor, .unknown:
            return .red
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)

                    SignalBarsView(quality: quality, maxHeight: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Signal")
                        .font(.headline)
                    Text(quality.description)
                        .font(.caption)
                        .foregroundColor(color)
                }

                Spacer()

                if showRSSI {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(rssi)")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        Text("dBm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Quality bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(quality.bars) / 4.0)
                }
            }
            .frame(height: 8)

            if !quality.isAdequate {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(color)
                    Text(quality == .poor || quality == .unknown ? "Signal too weak for reliable data" : "Signal may affect data quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(DesignSystem.shared.colors.backgroundPrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Connection Status View

/// Combined connection and signal status view
public struct ConnectionStatusView: View {
    let isConnected: Bool
    let rssi: Int?
    let deviceName: String?

    public init(isConnected: Bool, rssi: Int? = nil, deviceName: String? = nil) {
        self.isConnected = isConnected
        self.rssi = rssi
        self.deviceName = deviceName
    }

    private var quality: SignalQuality {
        guard let rssi = rssi else { return .unknown }
        return SignalQuality.from(rssi: rssi)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            if isConnected {
                if let name = deviceName {
                    Text(name)
                        .font(.caption)
                        .lineLimit(1)
                }

                if rssi != nil {
                    SignalBarsView(quality: quality, barCount: 4, maxHeight: 12)
                }
            } else {
                Text("Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct SignalStrengthView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    Text("Signal Bars").font(.headline)
                    HStack(spacing: 20) {
                        SignalBarsView(quality: .excellent)
                        SignalBarsView(quality: .good)
                        SignalBarsView(quality: .fair)
                        SignalBarsView(quality: .weak)
                        SignalBarsView(quality: .poor)
                    }
                }

                Divider()

                Group {
                    Text("Compact Views").font(.headline)
                    HStack(spacing: 20) {
                        SignalCompactView(quality: .excellent)
                        SignalCompactView(quality: .fair)
                        SignalCompactView(quality: .poor)
                    }
                }

                Divider()

                Group {
                    Text("Signal Badges").font(.headline)
                    HStack(spacing: 10) {
                        SignalBadgeView(quality: .excellent)
                        SignalBadgeView(quality: .fair)
                        SignalBadgeView(quality: .weak)
                    }
                }

                Divider()

                Group {
                    Text("Signal Cards").font(.headline)
                    SignalCardView(rssi: -45)
                    SignalCardView(rssi: -75)
                }

                Divider()

                Group {
                    Text("Connection Status").font(.headline)
                    VStack(spacing: 10) {
                        ConnectionStatusView(isConnected: true, rssi: -50, deviceName: "Oralable Device")
                        ConnectionStatusView(isConnected: true, rssi: -80, deviceName: "Weak Signal")
                        ConnectionStatusView(isConnected: false)
                    }
                }
            }
            .padding()
        }
        .background(DesignSystem.shared.colors.backgroundGrouped)
    }
}
#endif
