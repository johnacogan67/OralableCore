//
//  DesignSystemTests.swift
//  OralableCoreTests
//
//  Created: December 30, 2025
//  Tests for the Design System
//

import XCTest
import SwiftUI
@testable import OralableCore

final class DesignSystemTests: XCTestCase {

    // MARK: - Design System Tests

    func testDesignSystemSharedInstance() {
        let ds1 = DesignSystem.shared
        let ds2 = DesignSystem.shared

        // Should be the same instance properties
        XCTAssertEqual(ds1.spacing.md, ds2.spacing.md)
        XCTAssertEqual(ds1.sizing.button, ds2.sizing.button)
    }

    func testDesignSystemConvenienceAlias() {
        XCTAssertEqual(DS.spacing.md, DesignSystem.shared.spacing.md)
    }

    func testDesignSystemCustomization() {
        let customSpacing = SpacingSystem()
        let customDS = DesignSystem(spacing: customSpacing)

        XCTAssertEqual(customDS.spacing.md, 16)
    }

    // MARK: - Spacing System Tests

    func testSpacingSystem4ptGrid() {
        let spacing = SpacingSystem()

        // Verify 4pt grid
        XCTAssertEqual(spacing.xxs, 2)
        XCTAssertEqual(spacing.xs, 4)
        XCTAssertEqual(spacing.sm, 8)
        XCTAssertEqual(spacing.md, 16)
        XCTAssertEqual(spacing.lg, 24)
        XCTAssertEqual(spacing.xl, 32)
        XCTAssertEqual(spacing.xxl, 40)
    }

    func testSpacingSystemProgression() {
        let spacing = SpacingSystem()

        // Ensure values increase
        XCTAssertLessThan(spacing.xxs, spacing.xs)
        XCTAssertLessThan(spacing.xs, spacing.sm)
        XCTAssertLessThan(spacing.sm, spacing.md)
        XCTAssertLessThan(spacing.md, spacing.lg)
        XCTAssertLessThan(spacing.lg, spacing.xl)
    }

    // MARK: - Sizing System Tests

    func testSizingSystemIcons() {
        let sizing = SizingSystem()

        XCTAssertEqual(sizing.iconSmall, 16)
        XCTAssertEqual(sizing.icon, 24)
        XCTAssertEqual(sizing.iconLarge, 28)
        XCTAssertEqual(sizing.iconXL, 32)
    }

    func testSizingSystemTouchTargets() {
        let sizing = SizingSystem()

        // iOS HIG minimum touch target
        XCTAssertGreaterThanOrEqual(sizing.touchTarget, 44)
        XCTAssertGreaterThanOrEqual(sizing.button, 44)
    }

    func testSizingSystemButtons() {
        let sizing = SizingSystem()

        XCTAssertLessThan(sizing.buttonSmall, sizing.button)
        XCTAssertLessThan(sizing.button, sizing.buttonLarge)
        XCTAssertLessThan(sizing.buttonLarge, sizing.buttonXL)
    }

    func testSizingSystemAvatars() {
        let sizing = SizingSystem()

        XCTAssertLessThan(sizing.avatarSmall, sizing.avatarMedium)
        XCTAssertLessThan(sizing.avatarMedium, sizing.avatar)
        XCTAssertLessThan(sizing.avatar, sizing.avatarLarge)
    }

    // MARK: - Corner Radius Tests

    func testCornerRadiusProgression() {
        let radius = CornerRadiusSystem()

        XCTAssertEqual(radius.none, 0)
        XCTAssertLessThan(radius.xs, radius.sm)
        XCTAssertLessThan(radius.sm, radius.md)
        XCTAssertLessThan(radius.md, radius.lg)
        XCTAssertLessThan(radius.lg, radius.xl)
    }

    func testCornerRadiusSemanticValues() {
        let radius = CornerRadiusSystem()

        XCTAssertEqual(radius.button, radius.md)
        XCTAssertEqual(radius.card, radius.lg)
        XCTAssertEqual(radius.sheet, radius.xl)
        XCTAssertEqual(radius.badge, radius.full)
    }

    func testCornerRadiusFull() {
        let radius = CornerRadiusSystem()

        // Full should be very large for pill shapes
        XCTAssertGreaterThan(radius.full, 100)
    }

    // MARK: - Layout System Tests

    func testLayoutSystemPadding() {
        let layout = LayoutSystem()

        XCTAssertEqual(layout.horizontalPadding, 16)
        XCTAssertEqual(layout.verticalPadding, 16)
    }

    func testLayoutSystemListItems() {
        let layout = LayoutSystem()

        // Minimum height should meet touch target
        XCTAssertGreaterThanOrEqual(layout.listItemHeight, 44)
    }

    func testLayoutSystemDividers() {
        let layout = LayoutSystem()

        XCTAssertLessThan(layout.dividerThin, layout.divider)
        XCTAssertLessThan(layout.divider, layout.dividerThick)
    }

    // MARK: - Shadow System Tests

    func testShadowSystemProgression() {
        let shadows = ShadowSystem()

        XCTAssertEqual(shadows.none.radius, 0)
        XCTAssertLessThan(shadows.sm.radius, shadows.md.radius)
        XCTAssertLessThan(shadows.md.radius, shadows.lg.radius)
        XCTAssertLessThan(shadows.lg.radius, shadows.xl.radius)
    }

    func testShadowStyleCreation() {
        let style = ShadowStyle(color: .black, radius: 4, x: 0, y: 2)

        XCTAssertEqual(style.radius, 4)
        XCTAssertEqual(style.x, 0)
        XCTAssertEqual(style.y, 2)
    }

    func testShadowSystemSemanticValues() {
        let shadows = ShadowSystem()

        XCTAssertEqual(shadows.card.radius, shadows.sm.radius)
        XCTAssertEqual(shadows.button.radius, shadows.md.radius)
        XCTAssertEqual(shadows.modal.radius, shadows.xl.radius)
    }

    // MARK: - Animation System Tests

    func testAnimationSystemDurations() {
        let animation = AnimationSystem()

        XCTAssertLessThan(animation.durationFast, animation.durationStandard)
        XCTAssertLessThan(animation.durationStandard, animation.durationSlow)
        XCTAssertLessThan(animation.durationSlow, animation.durationExtraSlow)
    }

    func testAnimationSystemDurationValues() {
        let animation = AnimationSystem()

        XCTAssertEqual(animation.durationFast, 0.15)
        XCTAssertEqual(animation.durationStandard, 0.25)
        XCTAssertEqual(animation.durationSlow, 0.35)
    }

    // MARK: - Color System Tests

    func testColorSystemCreation() {
        let colors = ColorSystem()

        // Should have all required colors
        XCTAssertNotNil(colors.textPrimary)
        XCTAssertNotNil(colors.textSecondary)
        XCTAssertNotNil(colors.backgroundPrimary)
        XCTAssertNotNil(colors.backgroundSecondary)
    }

    func testColorSystemSemanticColors() {
        let colors = ColorSystem()

        XCTAssertNotNil(colors.info)
        XCTAssertNotNil(colors.warning)
        XCTAssertNotNil(colors.error)
        XCTAssertNotNil(colors.success)
    }

    func testColorSystemHealthMetrics() {
        let colors = ColorSystem()

        XCTAssertNotNil(colors.heartRate)
        XCTAssertNotNil(colors.spo2)
        XCTAssertNotNil(colors.temperature)
        XCTAssertNotNil(colors.battery)
        XCTAssertNotNil(colors.muscleActivity)
    }

    func testColorSystemSensorTypeColor() {
        let colors = ColorSystem()

        let hrColor = colors.color(for: .heartRate)
        XCTAssertNotNil(hrColor)

        let spo2Color = colors.color(for: .spo2)
        XCTAssertNotNil(spo2Color)

        let tempColor = colors.color(for: .temperature)
        XCTAssertNotNil(tempColor)
    }

    func testColorSystemDeviceTypeColor() {
        let colors = ColorSystem()

        let oralableColor = colors.color(for: .oralable)
        XCTAssertNotNil(oralableColor)

        let anrColor = colors.color(for: .anr)
        XCTAssertNotNil(anrColor)
    }

    func testColorSystemBatteryColor() {
        let colors = ColorSystem()

        // Low battery should be error color
        let lowBattery = colors.batteryColor(for: 10)
        XCTAssertEqual(lowBattery, colors.error)

        // Medium battery should be warning
        let mediumBattery = colors.batteryColor(for: 30)
        XCTAssertEqual(mediumBattery, colors.warning)

        // High battery should be success
        let highBattery = colors.batteryColor(for: 80)
        XCTAssertEqual(highBattery, colors.success)
    }

    func testColorSystemSignalColor() {
        let colors = ColorSystem()

        XCTAssertEqual(colors.signalColor(for: .excellent), colors.success)
        XCTAssertEqual(colors.signalColor(for: .good), colors.success)
        XCTAssertEqual(colors.signalColor(for: .fair), colors.warning)
        XCTAssertEqual(colors.signalColor(for: .weak), colors.error)
        XCTAssertEqual(colors.signalColor(for: .poor), colors.error)
    }

    func testColorHexInitializer() {
        let color = Color(hex: "7B68EE")
        XCTAssertNotNil(color)

        let colorWithHash = Color(hex: "#FF0000")
        XCTAssertNotNil(colorWithHash)

        let shortHex = Color(hex: "F00")
        XCTAssertNotNil(shortHex)
    }

    func testOralableBrandColors() {
        XCTAssertNotNil(Color.oralablePurple)
        XCTAssertNotNil(Color.oralablePrimary)
        XCTAssertNotNil(Color.oralableSecondary)
        XCTAssertNotNil(Color.oralableAccent)
    }

    // MARK: - Typography System Tests

    func testTypographySystemHeadings() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.h1)
        XCTAssertNotNil(typography.h2)
        XCTAssertNotNil(typography.h3)
        XCTAssertNotNil(typography.h4)
    }

    func testTypographySystemBody() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.body)
        XCTAssertNotNil(typography.bodyBold)
        XCTAssertNotNil(typography.bodyMedium)
        XCTAssertNotNil(typography.bodyLarge)
        XCTAssertNotNil(typography.bodySmall)
    }

    func testTypographySystemLabels() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.labelLarge)
        XCTAssertNotNil(typography.labelMedium)
        XCTAssertNotNil(typography.labelSmall)
    }

    func testTypographySystemCaptions() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.caption)
        XCTAssertNotNil(typography.caption2)
        XCTAssertNotNil(typography.captionBold)
    }

    func testTypographySystemDisplay() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.displaySmall)
        XCTAssertNotNil(typography.displayMedium)
        XCTAssertNotNil(typography.displayLarge)
        XCTAssertNotNil(typography.metricDisplay)
    }

    func testTypographySystemButtons() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.button)
        XCTAssertNotNil(typography.buttonLarge)
        XCTAssertNotNil(typography.buttonSmall)
    }

    func testTypographySystemMonospaced() {
        let typography = TypographySystem()

        XCTAssertNotNil(typography.mono)
        XCTAssertNotNil(typography.monoSmall)
        XCTAssertNotNil(typography.monoMetric)
    }

    // MARK: - Theme Mode Tests

    func testThemeModeValues() {
        XCTAssertEqual(ThemeMode.light.rawValue, "light")
        XCTAssertEqual(ThemeMode.dark.rawValue, "dark")
        XCTAssertEqual(ThemeMode.system.rawValue, "system")
    }

    func testThemeModeColorScheme() {
        XCTAssertEqual(ThemeMode.light.colorScheme, .light)
        XCTAssertEqual(ThemeMode.dark.colorScheme, .dark)
        XCTAssertNil(ThemeMode.system.colorScheme)
    }

    func testThemeModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for mode in ThemeMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(ThemeMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - Design Tokens Tests

    func testDesignTokensDefaults() {
        let tokens = DesignTokens()

        XCTAssertNotNil(tokens.brandPrimary)
        XCTAssertNotNil(tokens.brandSecondary)
        XCTAssertNotNil(tokens.accent)
    }

    func testDesignTokensCustomization() {
        var tokens = DesignTokens()
        tokens.brandPrimary = .red

        XCTAssertEqual(tokens.brandPrimary, .red)
    }

    // MARK: - Font Weight Extension Tests

    func testFontWeightAllWeights() {
        let weights = Font.Weight.allWeights

        XCTAssertEqual(weights.count, 9)
        XCTAssertTrue(weights.contains(.regular))
        XCTAssertTrue(weights.contains(.bold))
        XCTAssertTrue(weights.contains(.semibold))
    }
}
