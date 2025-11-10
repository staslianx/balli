//
//  ManualEntryView.swift
//  balli
//
//  Manual food label entry interface
//

import SwiftUI
import CoreData
import OSLog

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    private let logger = AppLoggers.Food.entry
    
    // Food information
    @State private var productBrand = ""
    @State private var productName = ""
    
    // Nutritional values
    @State private var calories = ""
    @State private var servingSize = "100"  // Default serving size
    @State private var carbohydrates = ""
    @State private var fiber = ""
    @State private var sugars = ""
    @State private var protein = ""
    @State private var fat = ""
    
    // Portion slider
    @State private var portionGrams: Double = 100.0

    // Impact calculation
    @State private var currentImpactLevel: ImpactLevel? = nil
    @State private var currentImpactScore: Double? = nil

    @State private var showingSaveConfirmation = false
    @State private var isSaveInProgress = false // Prevent duplicate saves
    @State private var savedProductName = "" // Store name for toast message
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.appBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack {
                        Spacer(minLength: ResponsiveDesign.height(50))
                        
                        // Food label container - exact same as AI result view
                        NutritionLabelView(
                            productBrand: $productBrand,
                            productName: $productName,
                            calories: $calories,
                            servingSize: $servingSize,
                            carbohydrates: $carbohydrates,
                            fiber: $fiber,
                            sugars: $sugars,
                            protein: $protein,
                            fat: $fat,
                            portionGrams: $portionGrams,
                            isEditing: true,  // Always editing in manual entry
                            showIcon: false,  // No icon - using impact banner like AI view
                            iconName: "hand.rays.fill",
                            iconColor: .primary,
                            showImpactBanner: true,  // ✅ Show impact banner
                            impactLevel: currentImpactLevel,
                            impactScore: currentImpactScore,
                            showingValues: true,
                            valuesAnimationProgress: [:],
                            showSlider: true  // ✅ Always show slider in manual entry
                        )
                        .onChange(of: portionGrams) { _, _ in
                            updateImpactCalculation()
                        }
                        .onChange(of: carbohydrates) { _, _ in
                            updateImpactCalculation()
                        }
                        .onChange(of: fiber) { _, _ in
                            updateImpactCalculation()
                        }
                        .onChange(of: sugars) { _, _ in
                            updateImpactCalculation()
                        }
                        .onChange(of: protein) { _, _ in
                            updateImpactCalculation()
                        }
                        .onChange(of: fat) { _, _ in
                            updateImpactCalculation()
                        }
                        
                        Spacer(minLength: ResponsiveDesign.height(50))

                        // Bottom controls - Checkmark button matching AI analysis style
                        Button(action: saveFood) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.balliBordered(size: ResponsiveDesign.height(72)))
                        .disabled(isSaveInProgress)
                        .opacity(isSaveInProgress ? 0.6 : 1.0)
                        .padding(.bottom, ResponsiveDesign.height(12))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)

                // Save confirmation toast
                if showingSaveConfirmation {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.primaryPurple)
                            Text("\(savedProductName) Ardiye'ye kaydedildi!")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .recipeGlass(tint: .warm, cornerRadius: 100)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingSaveConfirmation)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.primaryPurple)
                    }
                }
            }
        }
    }
    
    private func saveFood() {
        // Prevent multiple saves
        guard !isSaveInProgress else {
            logger.debug("Save already in progress, ignoring duplicate request")
            return
        }
        isSaveInProgress = true

        // Store product name for toast message
        savedProductName = productName.isEmpty ? "Ürün" : productName

        // Create FoodItem in Core Data
        let foodItem = FoodItem(context: viewContext)
        foodItem.id = UUID()
        foodItem.name = productName.isEmpty ? "Bilinmeyen Ürün" : productName
        foodItem.brand = productBrand.isEmpty ? nil : productBrand

        // Store the user's selected serving size
        foodItem.servingSize = portionGrams
        foodItem.servingUnit = "g"

        // Calculate adjusted values based on portion
        let baseServing = servingSize.toDouble ?? 100.0
        let adjustmentRatio = portionGrams / baseServing

        // Save adjusted values based on the selected portion
        foodItem.calories = (calories.toDouble ?? 0) * adjustmentRatio
        foodItem.totalCarbs = (carbohydrates.toDouble ?? 0) * adjustmentRatio
        foodItem.fiber = (fiber.toDouble ?? 0) * adjustmentRatio
        foodItem.sugars = (sugars.toDouble ?? 0) * adjustmentRatio
        foodItem.protein = (protein.toDouble ?? 0) * adjustmentRatio
        foodItem.totalFat = (fat.toDouble ?? 0) * adjustmentRatio
        foodItem.sodium = 0 // Not collected in manual entry

        foodItem.source = "manual_entry"
        foodItem.dateAdded = Date()
        foodItem.lastModified = Date()

        // Set high confidence for manual entry
        foodItem.carbsConfidence = 100.0
        foodItem.overallConfidence = 100.0

        do {
            try viewContext.save()
            logger.info("Saved FoodItem: \(foodItem.name)")

            // Haptic feedback on successful save
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            // Show confirmation toast
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingSaveConfirmation = true
            }

            // Auto-dismiss toast and reset form
            Task { @MainActor in
                // Hide toast after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingSaveConfirmation = false
                }

                // Wait a bit before dismissing to let animation complete
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            }
        } catch {
            logger.error("Failed to save FoodItem: \(error.localizedDescription)")
            isSaveInProgress = false
            ErrorHandler.shared.handle(error)
        }
    }

    /// Update impact calculation based on current form values and portion
    /// Matches the calculation logic from NutritionFormState
    private func updateImpactCalculation() {
        // Validate we have a valid serving size
        guard let baseServing = servingSize.toDouble, baseServing > 0 else {
            currentImpactScore = nil
            currentImpactLevel = nil
            return
        }

        // Parse values with 0.0 fallback for missing/empty data
        let baseCarbs = carbohydrates.toDouble ?? 0.0
        let baseFiber = fiber.toDouble ?? 0.0
        let baseSugars = sugars.toDouble ?? 0.0
        let baseProtein = protein.toDouble ?? 0.0
        let baseFat = fat.toDouble ?? 0.0

        // Calculate impact score using validated Nestlé formula
        let result = ImpactScoreCalculator.calculate(
            totalCarbs: baseCarbs,
            fiber: baseFiber,
            sugar: baseSugars,
            protein: baseProtein,
            fat: baseFat,
            servingSize: baseServing,
            portionGrams: portionGrams
        )

        // Update score state
        currentImpactScore = result.score

        // Calculate scaled fat and protein for current portion to determine level
        let adjustmentRatio = portionGrams / baseServing
        let scaledFat = baseFat * adjustmentRatio
        let scaledProtein = baseProtein * adjustmentRatio

        // Determine impact level using three-threshold evaluation
        currentImpactLevel = ImpactLevel.from(
            score: result.score,
            fat: scaledFat,
            protein: scaledProtein
        )

        logger.debug("Impact calculation updated - Score: \(result.score), Level: \(currentImpactLevel?.rawValue ?? "nil")")
    }
}

// MARK: - Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12) // Using fixed value since ResponsiveDesign requires MainActor
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
            .shadow(color: AppTheme.primaryPurple.opacity(0.08), radius: 8, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            .foregroundColor(.primary)
    }
}

#Preview {
    ManualEntryView()
        .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
