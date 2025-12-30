//
//  DesignSystem.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Unified design system for Oralable apps
//

import SwiftUI

// MARK: - Design System

/// Unified design system providing consistent styling across Oralable apps
///
/// Usage:
/// ```swift
/// struct MyView: View {
///     let ds = DesignSystem.shared
///
///     var body: some View {
///         Text("Hello")
///             .font(ds.typography.h1)
///             .foregroundColor(ds.colors.textPrimary)
///             .padding(ds.spacing.md)
///     }
/// }
/// ```
public struct DesignSystem: Sendable {

    /// Shared instance for convenience
    public static let shared = DesignSystem()

    /// Color system
    public let colors: ColorSystem

    /// Typography system
    public let typography: TypographySystem

    /// Spacing system
    public let spacing: SpacingSystem

    /// Sizing system
    public let sizing: SizingSystem

    /// Corner radius system
    public let cornerRadius: CornerRadiusSystem

    /// Layout system
    public let layout: LayoutSystem

    /// Shadow system
    public let shadows: ShadowSystem

    /// Animation system
    public let animation: AnimationSystem

    public init(
        colors: ColorSystem = ColorSystem(),
        typography: TypographySystem = TypographySystem(),
        spacing: SpacingSystem = SpacingSystem(),
        sizing: SizingSystem = SizingSystem(),
        cornerRadius: CornerRadiusSystem = CornerRadiusSystem(),
        layout: LayoutSystem = LayoutSystem(),
        shadows: ShadowSystem = ShadowSystem(),
        animation: AnimationSystem = AnimationSystem()
    ) {
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.sizing = sizing
        self.cornerRadius = cornerRadius
        self.layout = layout
        self.shadows = shadows
        self.animation = animation
    }
}

// MARK: - Environment Key

private struct DesignSystemKey: EnvironmentKey {
    static let defaultValue = DesignSystem.shared
}

public extension EnvironmentValues {
    /// Access the design system from the environment
    var designSystem: DesignSystem {
        get { self[DesignSystemKey.self] }
        set { self[DesignSystemKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Inject a design system into the environment
    func designSystem(_ ds: DesignSystem) -> some View {
        environment(\.designSystem, ds)
    }
}

// MARK: - Property Wrapper for Design System Access

/// Property wrapper to access the design system easily in views
///
/// Usage:
/// ```swift
/// struct MyView: View {
///     @DesignSystemAccess var ds
///
///     var body: some View {
///         Text("Hello")
///             .font(ds.typography.body)
///     }
/// }
/// ```
@propertyWrapper
public struct DesignSystemAccess: DynamicProperty {
    @Environment(\.designSystem) private var designSystem

    public init() {}

    public var wrappedValue: DesignSystem {
        designSystem
    }
}

// MARK: - Convenience Aliases

/// Shorthand access to the shared design system
public let DS = DesignSystem.shared

// MARK: - Theme Support

/// Theme mode for light/dark appearance
public enum ThemeMode: String, Codable, Sendable, CaseIterable {
    case light
    case dark
    case system

    /// Get the color scheme for this mode
    public var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Design Tokens

/// Common design tokens that can be overridden
public struct DesignTokens: Sendable {

    /// Primary brand color
    public var brandPrimary: Color = .purple

    /// Secondary brand color
    public var brandSecondary: Color = Color(hex: "7B68EE")

    /// Accent color
    public var accent: Color = .blue

    public init() {}
}

// MARK: - Responsive Helpers

public extension DesignSystem {

    /// Check if device is compact width (iPhone portrait)
    static var isCompactWidth: Bool {
        #if os(iOS)
        return UIScreen.main.bounds.width < 428
        #else
        return false
        #endif
    }

    /// Check if device is iPad
    static var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    /// Get appropriate spacing for current device
    func responsiveSpacing(_ compact: CGFloat, _ regular: CGFloat) -> CGFloat {
        Self.isCompactWidth ? compact : regular
    }

    /// Get appropriate font for current device
    func responsiveFont(_ compact: Font, _ regular: Font) -> Font {
        Self.isCompactWidth ? compact : regular
    }
}

// MARK: - Debug Support

#if DEBUG
public extension DesignSystem {
    /// Print all design system values for debugging
    func printDebugInfo() {
        print("=== Design System Debug ===")
        print("Spacing: xxs=\(spacing.xxs), xs=\(spacing.xs), sm=\(spacing.sm), md=\(spacing.md), lg=\(spacing.lg), xl=\(spacing.xl)")
        print("Sizing: icon=\(sizing.icon), button=\(sizing.button), touchTarget=\(sizing.touchTarget)")
        print("Corner Radius: sm=\(cornerRadius.sm), md=\(cornerRadius.md), lg=\(cornerRadius.lg)")
        print("Animation durations: fast=\(animation.durationFast), standard=\(animation.durationStandard)")
        print("===========================")
    }
}
#endif
