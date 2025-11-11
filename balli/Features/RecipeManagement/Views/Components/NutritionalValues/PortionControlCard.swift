//
//  PortionControlCard.swift
//  balli
//
//  Consolidated portion adjustment UI for both saved and unsaved recipes
//  Extracted from NutritionalValuesView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

/// Unified portion control card that works for both saved and unsaved recipes
@MainActor
struct PortionControlCard: View {
    // Core recipe data
    let recipe: ObservableRecipeWrapper
    let isRecipeSaved: Bool

    // State bindings
    @Binding var adjustingPortionWeight: Double
    @Binding var portionMultiplier: Double
    @Binding var isExpanded: Bool
    @Binding var animateSaveButton: Bool

    // Display values
    let currentPortionSize: Double
    let minPortionSize: Double
    let totalRecipeWeight: String

    // Actions
    let onSave: () -> Void

    let logger: Logger

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            // HEADER: Always visible
            headerRow

            // EXPANDED CONTENT: Conditional rendering
            if isExpanded {
                expandedContent
            }
        }
        .padding(ResponsiveDesign.Spacing.large)
        .recipeGlass(tint: .transparent, cornerRadius: ResponsiveDesign.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryPurple.opacity(0.15),
                            AppTheme.primaryPurple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: ResponsiveDesign.Spacing.medium) {
                // Icon
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.primaryPurple)
                    .frame(width: ResponsiveDesign.width(32), height: ResponsiveDesign.height(32))
                    .recipeGlass(tint: .purple, cornerRadius: ResponsiveDesign.CornerRadius.small)

                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                    Text("Porsiyon Ayarla")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Şu anki: \(Int(currentPortionSize))g")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.primaryPurple.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            // Current portion display
            currentPortionDisplay

            // Slider (ONLY for saved recipes)
            if isRecipeSaved {
                sliderSection
            }

            // Save button
            saveButton
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }

    // MARK: - Current Portion Display

    private var currentPortionDisplay: some View {
        HStack {
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text("Yeni Porsiyon")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text("\(Int(adjustingPortionWeight))g")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(28), weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryPurple)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text("Toplam Tarif")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text(totalRecipeWeight)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))
            }
        }
    }

    // MARK: - Slider Section (Saved Recipes Only)

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
            Text("Porsiyon boyutunu ayarlayın")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Slider(value: $adjustingPortionWeight, in: minPortionSize...recipe.totalRecipeWeight, step: 1.0)
                .accentColor(AppTheme.primaryPurple)
                .onChange(of: adjustingPortionWeight) { oldValue, newValue in
                    logger.debug("🎚️ Slider adjusted: \(newValue)g")
                }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            logger.info("💾 Save button tapped")

            // Trigger haptic feedback
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()

            // Animate button
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                animateSaveButton = true
            }

            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    animateSaveButton = false
                }
            }

            // Execute save action
            onSave()

        } label: {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))

                Text("Kaydet")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(15), weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ResponsiveDesign.height(48))
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.primaryPurple,
                                AppTheme.primaryPurple.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(animateSaveButton ? 0.95 : 1.0)
            .shadow(
                color: AppTheme.primaryPurple.opacity(animateSaveButton ? 0.5 : 0.3),
                radius: animateSaveButton ? 8 : 12,
                x: 0,
                y: animateSaveButton ? 2 : 4
            )
        }
        .buttonStyle(.plain)
    }
}
