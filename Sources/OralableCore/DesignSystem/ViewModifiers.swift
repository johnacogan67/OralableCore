//
//  ViewModifiers.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Common view modifiers using the design system
//

import SwiftUI

// MARK: - Card Modifier

/// Card-style container modifier
public struct CardModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .padding(ds.spacing.md)
            .background(ds.colors.backgroundSecondary)
            .cornerRadius(ds.cornerRadius.card)
            .shadow(ds.shadows.card)
    }
}

public extension View {
    /// Apply card styling
    func card() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Primary Button Modifier

/// Primary button style modifier
public struct PrimaryButtonModifier: ViewModifier {
    let ds = DesignSystem.shared
    var isEnabled: Bool = true

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.button)
            .foregroundColor(ds.colors.primaryWhite)
            .frame(maxWidth: .infinity)
            .frame(height: ds.sizing.button)
            .background(isEnabled ? ds.colors.info : ds.colors.gray400)
            .cornerRadius(ds.cornerRadius.button)
            .shadow(isEnabled ? ds.shadows.button : ds.shadows.none)
    }
}

public extension View {
    /// Apply primary button styling
    func primaryButton(isEnabled: Bool = true) -> some View {
        modifier(PrimaryButtonModifier(isEnabled: isEnabled))
    }
}

// MARK: - Secondary Button Modifier

/// Secondary button style modifier
public struct SecondaryButtonModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.button)
            .foregroundColor(ds.colors.info)
            .frame(maxWidth: .infinity)
            .frame(height: ds.sizing.button)
            .background(ds.colors.backgroundSecondary)
            .cornerRadius(ds.cornerRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: ds.cornerRadius.button)
                    .stroke(ds.colors.info, lineWidth: 1)
            )
    }
}

public extension View {
    /// Apply secondary button styling
    func secondaryButton() -> some View {
        modifier(SecondaryButtonModifier())
    }
}

// MARK: - Text Field Modifier

/// Styled text field modifier
public struct TextFieldModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.body)
            .padding(ds.spacing.sm)
            .background(ds.colors.backgroundSecondary)
            .cornerRadius(ds.cornerRadius.input)
            .overlay(
                RoundedRectangle(cornerRadius: ds.cornerRadius.input)
                    .stroke(ds.colors.border, lineWidth: 1)
            )
    }
}

public extension View {
    /// Apply text field styling
    func styledTextField() -> some View {
        modifier(TextFieldModifier())
    }
}

// MARK: - Section Header Modifier

/// Section header styling
public struct SectionHeaderModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.headline)
            .foregroundColor(ds.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ds.spacing.md)
            .padding(.top, ds.spacing.lg)
            .padding(.bottom, ds.spacing.xs)
    }
}

public extension View {
    /// Apply section header styling
    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
}

// MARK: - Metric Display Modifier

/// Large metric display styling (for sensor values)
public struct MetricDisplayModifier: ViewModifier {
    let ds = DesignSystem.shared
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.metricDisplay)
            .foregroundColor(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

public extension View {
    /// Apply metric display styling
    func metricDisplay(color: Color = DesignSystem.shared.colors.textPrimary) -> some View {
        modifier(MetricDisplayModifier(color: color))
    }
}

// MARK: - Status Badge Modifier

/// Status badge styling
public struct StatusBadgeModifier: ViewModifier {
    let ds = DesignSystem.shared
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(ds.typography.captionBold)
            .foregroundColor(.white)
            .padding(.horizontal, ds.spacing.sm)
            .padding(.vertical, ds.spacing.xs)
            .background(color)
            .cornerRadius(ds.cornerRadius.badge)
    }
}

public extension View {
    /// Apply status badge styling
    func statusBadge(color: Color) -> some View {
        modifier(StatusBadgeModifier(color: color))
    }
}

// MARK: - Loading Overlay Modifier

/// Loading overlay with dimmed background
public struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)

            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ds.colors.primaryWhite)
            }
        }
    }
}

public extension View {
    /// Show loading overlay when loading
    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}

// MARK: - Shake Animation Modifier

/// Shake animation for error states
public struct ShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    @State private var shakeOffset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { newValue in
                if newValue {
                    withAnimation(.linear(duration: 0.05).repeatCount(6, autoreverses: true)) {
                        shakeOffset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shakeOffset = 0
                        trigger = false
                    }
                }
            }
    }
}

public extension View {
    /// Apply shake animation on trigger
    func shake(trigger: Binding<Bool>) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

// MARK: - Pulse Animation Modifier

/// Pulse animation for attention
public struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                isActive ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { newValue in
                isPulsing = newValue
            }
    }
}

public extension View {
    /// Apply pulse animation when active
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Conditional Modifier

public extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a modifier conditionally with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
}

// MARK: - List Row Modifier

/// Standard list row styling
public struct ListRowModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .padding(.vertical, ds.spacing.sm)
            .padding(.horizontal, ds.spacing.md)
            .frame(minHeight: ds.layout.listItemHeight)
            .background(ds.colors.backgroundPrimary)
    }
}

public extension View {
    /// Apply list row styling
    func listRow() -> some View {
        modifier(ListRowModifier())
    }
}

// MARK: - Screen Container Modifier

/// Standard screen container styling
public struct ScreenContainerModifier: ViewModifier {
    let ds = DesignSystem.shared

    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ds.colors.backgroundPrimary)
    }
}

public extension View {
    /// Apply screen container styling
    func screenContainer() -> some View {
        modifier(ScreenContainerModifier())
    }
}
