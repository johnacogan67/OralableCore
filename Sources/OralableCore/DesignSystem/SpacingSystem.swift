//
//  SpacingSystem.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Spacing, sizing, corner radius, layout, shadow, and animation systems
//

import SwiftUI

// MARK: - Spacing System

/// Spacing system using 4pt grid
public struct SpacingSystem: Sendable {

    /// 2pt - Extra extra small
    public let xxs: CGFloat = 2

    /// 4pt - Extra small
    public let xs: CGFloat = 4

    /// 8pt - Small
    public let sm: CGFloat = 8

    /// 12pt - Small-medium
    public let smd: CGFloat = 12

    /// 16pt - Medium (base)
    public let md: CGFloat = 16

    /// 20pt - Medium-large
    public let mdl: CGFloat = 20

    /// 24pt - Large
    public let lg: CGFloat = 24

    /// 32pt - Extra large
    public let xl: CGFloat = 32

    /// 40pt - Extra extra large
    public let xxl: CGFloat = 40

    /// 48pt - Triple extra large
    public let xxxl: CGFloat = 48

    /// 64pt - Quad extra large
    public let xxxxl: CGFloat = 64

    public init() {}
}

// MARK: - Sizing System

/// Icon and component sizing system
public struct SizingSystem: Sendable {

    // MARK: - Icons

    /// 12pt - Tiny icon
    public let iconTiny: CGFloat = 12

    /// 16pt - Small icon
    public let iconSmall: CGFloat = 16

    /// 20pt - Medium icon
    public let iconMedium: CGFloat = 20

    /// 24pt - Standard icon
    public let icon: CGFloat = 24

    /// 28pt - Large icon
    public let iconLarge: CGFloat = 28

    /// 32pt - Extra large icon
    public let iconXL: CGFloat = 32

    /// 48pt - Huge icon
    public let iconHuge: CGFloat = 48

    // MARK: - Touch Targets

    /// 44pt - Minimum touch target (iOS HIG)
    public let touchTarget: CGFloat = 44

    /// 48pt - Comfortable touch target
    public let touchTargetLarge: CGFloat = 48

    // MARK: - Buttons

    /// 36pt - Small button height
    public let buttonSmall: CGFloat = 36

    /// 44pt - Standard button height
    public let button: CGFloat = 44

    /// 50pt - Large button height
    public let buttonLarge: CGFloat = 50

    /// 56pt - Extra large button height
    public let buttonXL: CGFloat = 56

    // MARK: - Avatars

    /// 32pt - Small avatar
    public let avatarSmall: CGFloat = 32

    /// 40pt - Medium avatar
    public let avatarMedium: CGFloat = 40

    /// 56pt - Standard avatar
    public let avatar: CGFloat = 56

    /// 80pt - Large avatar
    public let avatarLarge: CGFloat = 80

    // MARK: - Cards

    /// Minimum card width
    public let cardMinWidth: CGFloat = 280

    /// Maximum card width
    public let cardMaxWidth: CGFloat = 400

    // MARK: - Metrics Display

    /// 80pt - Small metric circle
    public let metricSmall: CGFloat = 80

    /// 120pt - Medium metric circle
    public let metricMedium: CGFloat = 120

    /// 160pt - Large metric circle
    public let metricLarge: CGFloat = 160

    public init() {}
}

// MARK: - Corner Radius System

/// Corner radius values for UI elements
public struct CornerRadiusSystem: Sendable {

    /// 0pt - No radius
    public let none: CGFloat = 0

    /// 4pt - Extra small
    public let xs: CGFloat = 4

    /// 8pt - Small
    public let sm: CGFloat = 8

    /// 12pt - Medium
    public let md: CGFloat = 12

    /// 16pt - Large
    public let lg: CGFloat = 16

    /// 20pt - Extra large
    public let xl: CGFloat = 20

    /// 24pt - Extra extra large
    public let xxl: CGFloat = 24

    /// Full radius (circular)
    public let full: CGFloat = 9999

    // MARK: - Semantic Values

    /// Button corner radius
    public var button: CGFloat { md }

    /// Card corner radius
    public var card: CGFloat { lg }

    /// Sheet corner radius
    public var sheet: CGFloat { xl }

    /// Input field corner radius
    public var input: CGFloat { sm }

    /// Badge corner radius
    public var badge: CGFloat { full }

    public init() {}
}

// MARK: - Layout System

/// Layout constants for consistent UI structure
public struct LayoutSystem: Sendable {

    // MARK: - Screen Padding

    /// 16pt - Standard horizontal padding
    public let horizontalPadding: CGFloat = 16

    /// 20pt - Large horizontal padding
    public let horizontalPaddingLarge: CGFloat = 20

    /// 16pt - Standard vertical padding
    public let verticalPadding: CGFloat = 16

    // MARK: - Content Width

    /// Maximum content width for readability
    public let maxContentWidth: CGFloat = 600

    /// Maximum width for forms
    public let maxFormWidth: CGFloat = 500

    // MARK: - List Items

    /// 44pt - Minimum list item height
    public let listItemHeight: CGFloat = 44

    /// 60pt - Standard list item height
    public let listItemHeightMedium: CGFloat = 60

    /// 80pt - Large list item height
    public let listItemHeightLarge: CGFloat = 80

    // MARK: - Navigation

    /// 44pt - Navigation bar height
    public let navigationBarHeight: CGFloat = 44

    /// 49pt - Tab bar height
    public let tabBarHeight: CGFloat = 49

    // MARK: - Dividers

    /// 0.5pt - Hairline divider
    public let dividerThin: CGFloat = 0.5

    /// 1pt - Standard divider
    public let divider: CGFloat = 1

    /// 8pt - Section divider
    public let dividerThick: CGFloat = 8

    public init() {}
}

// MARK: - Shadow System

/// Shadow presets for depth and elevation
public struct ShadowSystem: Sendable {

    // MARK: - Shadow Definitions

    /// No shadow
    public var none: ShadowStyle { ShadowStyle(color: .clear, radius: 0, x: 0, y: 0) }

    /// Subtle shadow for cards
    public var sm: ShadowStyle {
        ShadowStyle(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    /// Standard shadow
    public var md: ShadowStyle {
        ShadowStyle(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    /// Elevated shadow
    public var lg: ShadowStyle {
        ShadowStyle(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    /// High elevation shadow
    public var xl: ShadowStyle {
        ShadowStyle(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    // MARK: - Semantic Shadows

    /// Card shadow
    public var card: ShadowStyle { sm }

    /// Button shadow
    public var button: ShadowStyle { md }

    /// Modal shadow
    public var modal: ShadowStyle { xl }

    /// Floating action button shadow
    public var fab: ShadowStyle { lg }

    public init() {}
}

/// Shadow style definition
public struct ShadowStyle: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

// MARK: - Animation System

/// Animation presets for consistent motion
public struct AnimationSystem: Sendable {

    // MARK: - Durations

    /// 0.15s - Fast animations
    public let durationFast: Double = 0.15

    /// 0.25s - Standard animations
    public let durationStandard: Double = 0.25

    /// 0.35s - Slow animations
    public let durationSlow: Double = 0.35

    /// 0.5s - Extra slow animations
    public let durationExtraSlow: Double = 0.5

    // MARK: - Spring Animations

    /// Quick spring animation
    public var springQuick: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }

    /// Standard spring animation
    public var springStandard: Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
    }

    /// Bouncy spring animation
    public var springBouncy: Animation {
        .spring(response: 0.5, dampingFraction: 0.6)
    }

    /// Gentle spring animation
    public var springGentle: Animation {
        .spring(response: 0.6, dampingFraction: 0.8)
    }

    // MARK: - Easing Animations

    /// Fast ease-out
    public var easeOutFast: Animation {
        .easeOut(duration: durationFast)
    }

    /// Standard ease-out
    public var easeOut: Animation {
        .easeOut(duration: durationStandard)
    }

    /// Standard ease-in-out
    public var easeInOut: Animation {
        .easeInOut(duration: durationStandard)
    }

    /// Slow ease-in-out
    public var easeInOutSlow: Animation {
        .easeInOut(duration: durationSlow)
    }

    // MARK: - Linear

    /// Linear animation for continuous motion
    public var linear: Animation {
        .linear(duration: durationStandard)
    }

    /// Slow linear for pulse effects
    public var linearSlow: Animation {
        .linear(duration: durationExtraSlow)
    }

    // MARK: - Semantic Animations

    /// Button press animation
    public var buttonPress: Animation { easeOutFast }

    /// Page transition
    public var pageTransition: Animation { springStandard }

    /// Modal presentation
    public var modalPresent: Animation { springGentle }

    /// Card expand/collapse
    public var cardExpand: Animation { springBouncy }

    /// Value change animation (for metrics)
    public var valueChange: Animation { easeInOut }

    public init() {}
}

// MARK: - View Extensions for Shadow

public extension View {
    /// Apply a shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
