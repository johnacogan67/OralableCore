//
//  TypographySystem.swift
//  OralableCore
//
//  Created: December 30, 2025
//  Typography system using iOS system fonts (SF Pro)
//

import SwiftUI

// MARK: - Typography System

/// Typography system using iOS system fonts (SF Pro) for consistent rendering
public struct TypographySystem: Sendable {

    // MARK: - Headings

    /// Heading 1 - Largest heading
    public var h1: Font { .system(size: 34, weight: .bold) }

    /// Heading 2
    public var h2: Font { .system(size: 28, weight: .semibold) }

    /// Heading 3
    public var h3: Font { .system(size: 22, weight: .semibold) }

    /// Heading 4
    public var h4: Font { .system(size: 18, weight: .medium) }

    // MARK: - iOS Standard Styles

    /// Large title (iOS navigation large title)
    public var largeTitle: Font { .system(size: 34, weight: .bold) }

    /// Headline (iOS standard headline)
    public var headline: Font { .system(size: 17, weight: .semibold) }

    /// Subheadline
    public var subheadline: Font { .system(size: 15, weight: .regular) }

    /// Title
    public var title: Font { .system(size: 20, weight: .semibold) }

    /// Title 2
    public var title2: Font { .system(size: 22, weight: .bold) }

    /// Title 3
    public var title3: Font { .system(size: 20, weight: .regular) }

    // MARK: - Body Variants

    /// Body - Standard body text
    public var body: Font { .system(size: 16, weight: .regular) }

    /// Body bold
    public var bodyBold: Font { .system(size: 16, weight: .bold) }

    /// Body medium weight
    public var bodyMedium: Font { .system(size: 16, weight: .medium) }

    /// Body large
    public var bodyLarge: Font { .system(size: 18, weight: .regular) }

    /// Body small
    public var bodySmall: Font { .system(size: 14, weight: .regular) }

    // MARK: - Label Variants

    /// Label large
    public var labelLarge: Font { .system(size: 16, weight: .medium) }

    /// Label medium
    public var labelMedium: Font { .system(size: 14, weight: .medium) }

    /// Label small
    public var labelSmall: Font { .system(size: 12, weight: .medium) }

    // MARK: - Caption & Footnote

    /// Caption - Small descriptive text
    public var caption: Font { .system(size: 14, weight: .regular) }

    /// Caption 2 - Smaller caption
    public var caption2: Font { .system(size: 11, weight: .regular) }

    /// Caption bold
    public var captionBold: Font { .system(size: 14, weight: .semibold) }

    /// Caption small
    public var captionSmall: Font { .system(size: 12, weight: .regular) }

    /// Footnote
    public var footnote: Font { .system(size: 12, weight: .regular) }

    // MARK: - Display

    /// Display small - For large metrics/values
    public var displaySmall: Font { .system(size: 24, weight: .bold) }

    /// Display medium
    public var displayMedium: Font { .system(size: 32, weight: .bold) }

    /// Display large
    public var displayLarge: Font { .system(size: 48, weight: .bold) }

    /// Metric display - For sensor values
    public var metricDisplay: Font { .system(size: 56, weight: .bold, design: .rounded) }

    // MARK: - Interactive Elements

    /// Button text
    public var button: Font { .system(size: 16, weight: .semibold) }

    /// Button large
    public var buttonLarge: Font { .system(size: 18, weight: .semibold) }

    /// Button medium
    public var buttonMedium: Font { .system(size: 16, weight: .medium) }

    /// Button small
    public var buttonSmall: Font { .system(size: 14, weight: .semibold) }

    /// Link text
    public var link: Font { .system(size: 16, weight: .medium) }

    // MARK: - Monospaced (for data/code)

    /// Monospaced regular
    public var mono: Font { .system(size: 14, weight: .regular, design: .monospaced) }

    /// Monospaced small
    public var monoSmall: Font { .system(size: 12, weight: .regular, design: .monospaced) }

    /// Monospaced for metrics
    public var monoMetric: Font { .system(size: 20, weight: .medium, design: .monospaced) }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Font Weight Extension

public extension Font.Weight {
    /// All font weights for reference
    static let allWeights: [Font.Weight] = [
        .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black
    ]
}

// MARK: - View Extension for Typography

public extension View {
    /// Apply heading 1 style
    func h1Style() -> some View {
        self.font(.system(size: 34, weight: .bold))
    }

    /// Apply heading 2 style
    func h2Style() -> some View {
        self.font(.system(size: 28, weight: .semibold))
    }

    /// Apply heading 3 style
    func h3Style() -> some View {
        self.font(.system(size: 22, weight: .semibold))
    }

    /// Apply body style
    func bodyStyle() -> some View {
        self.font(.system(size: 16, weight: .regular))
    }

    /// Apply caption style
    func captionStyle() -> some View {
        self.font(.system(size: 14, weight: .regular))
    }

    /// Apply metric display style (for large sensor values)
    func metricStyle() -> some View {
        self.font(.system(size: 56, weight: .bold, design: .rounded))
    }
}
