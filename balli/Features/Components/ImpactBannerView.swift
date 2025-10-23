//
//  ImpactBannerView.swift
//  balli
//
//  Blood sugar impact banner with iOS 26 Liquid Glass styling
//

import SwiftUI

/// Banner component showing blood sugar impact level with color-coded visual styling
struct ImpactBannerView: View {
    let impactLevel: ImpactLevel
    let impactScore: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.Spacing.medium) {
            // Impact level icon - using semantic card symbols
            Image(systemName: impactLevel.cardSymbolName)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                .foregroundColor(impactLevel.color)
                .frame(height: ResponsiveDesign.Font.scaledSize(20), alignment: .center)
                .accessibilityHidden(true)

            // Simple score and level display with monospaced digits
            Text("\(Int(ceil(impactScore))), \(impactLevel.displayText)")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(impactLevel.textColor)

            Spacer()

            // Visual impact indicator
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small)
                .fill(impactLevel.color)
                .frame(width: ResponsiveDesign.width(4), height: ResponsiveDesign.height(40))
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.xLarge)
        .padding(.vertical, ResponsiveDesign.Spacing.large)
        .background(
            // iOS 26 Liquid Glass effect with color tinting
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                .fill(impactLevel.backgroundTintColor)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                )
        )
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Etki skoru \(Int(ceil(impactScore))), \(impactLevel.accessibilityLabel)")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Compact version of impact banner for top-right overlay positioning
struct CompactImpactBannerView: View {
    let impactLevel: ImpactLevel
    let impactScore: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.Spacing.small) {
            // Impact level symbol - using semantic card symbols, larger size
            Image(systemName: impactLevel.cardSymbolName)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .semibold))
                .foregroundColor(impactLevel.color)
                .frame(height: ResponsiveDesign.Font.scaledSize(26), alignment: .center)
                .accessibilityHidden(true)

            // Score only - no text label, monospaced digits
            Text("\(Int(ceil(impactScore)))")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(22), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(impactLevel.color)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Etki skoru \(Int(ceil(impactScore))), \(impactLevel.accessibilityLabel)")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Toolbar version of impact banner with full descriptive text for top-right placement
struct ToolbarImpactBannerView: View {
    let impactLevel: ImpactLevel
    let impactScore: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: ResponsiveDesign.Spacing.small) {
            // Impact level icon - using semantic card symbols
            Image(systemName: impactLevel.cardSymbolName)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold))
                .foregroundColor(impactLevel.color)
                .frame(height: ResponsiveDesign.Font.scaledSize(16), alignment: .center)
                .accessibilityHidden(true)

            // Simple score and level display for toolbar with monospaced digits
            Text("\(Int(ceil(impactScore))), \(impactLevel.displayText)")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(12), weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(impactLevel.textColor)
                .lineLimit(1)

            // Visual indicator bar
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.xSmall)
                .fill(impactLevel.color)
                .frame(width: ResponsiveDesign.width(3), height: ResponsiveDesign.height(28))
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.small)
        .padding(.vertical, ResponsiveDesign.Spacing.xSmall)
        .background(
            // Toolbar glass effect
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .fill(impactLevel.backgroundTintColor)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Etki skoru \(Int(ceil(impactScore))), \(impactLevel.accessibilityLabel)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview
#Preview("Impact Banner Levels") {
    VStack(spacing: ResponsiveDesign.Spacing.large) {
        // Low impact - shows "12, Düşük"
        ImpactBannerView(impactLevel: .low, impactScore: 12)

        // Medium impact - shows "28, Orta" for typical carb-heavy meals under 100g
        ImpactBannerView(impactLevel: .medium, impactScore: 28)

        // High impact - shows "48, Yüksek" (threshold ≥36)
        ImpactBannerView(impactLevel: .high, impactScore: 48)
    }
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Clean Compact Pills") {
    VStack(spacing: ResponsiveDesign.Spacing.large) {
        // Low impact - shows symbol + "12"
        CompactImpactBannerView(impactLevel: .low, impactScore: 12)

        // Medium impact - shows symbol + "28"
        CompactImpactBannerView(impactLevel: .medium, impactScore: 28)

        // High impact - shows symbol + "48" (threshold ≥36)
        CompactImpactBannerView(impactLevel: .high, impactScore: 48)
    }
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Toolbar Impact Banner") {
    VStack(spacing: ResponsiveDesign.Spacing.large) {
        // Shows "12, Düşük" in toolbar format
        ToolbarImpactBannerView(impactLevel: .low, impactScore: 12)

        // Shows "28, Orta" in toolbar format
        ToolbarImpactBannerView(impactLevel: .medium, impactScore: 28)
    }
    .padding()
    .background(Color(.systemGray6))
}

#Preview("Dark Mode") {
    VStack(spacing: ResponsiveDesign.Spacing.large) {
        // Shows "12, Düşük"
        ImpactBannerView(impactLevel: .low, impactScore: 12)

        // Shows "28, Orta"
        ImpactBannerView(impactLevel: .medium, impactScore: 28)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
