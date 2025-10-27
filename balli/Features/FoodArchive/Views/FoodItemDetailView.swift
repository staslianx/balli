//
//  FoodItemDetailView.swift
//  balli
//
//  Product detail view with nutrition display and editing capabilities
//

import SwiftUI
import CoreData
import os.log

/// Main container view for displaying saved product details
struct FoodItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    // The food item to display
    let foodItem: FoodItem

    // UI States
    @State private var isEditMode: Bool = false
    @State private var showingSaveConfirmation = false
    @State private var showingValidationAlert = false

    // Form state for editing
    @State private var productBrand: String = ""
    @State private var productName: String = ""
    @State private var calories: String = ""
    @State private var servingSize: String = ""
    @State private var carbohydrates: String = ""
    @State private var fiber: String = ""
    @State private var sugars: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var portionGrams: Double = 100.0

    // Validation
    @State private var validationErrors: [String] = []
    @State private var validationWarnings: [String] = []

    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "FoodDetail")

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack {
                        Spacer(minLength: ResponsiveDesign.height(50))

                        // Food label container with integrated impact banner
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
                            isEditing: isEditMode,
                            showIcon: false,
                            iconName: "laser.burst",
                            iconColor: AppTheme.primaryPurple,
                            showImpactBanner: true,
                            impactLevel: currentImpactLevel,
                            impactScore: currentImpactScore,
                            showingValues: true,
                            valuesAnimationProgress: [:]
                        )

                        Spacer(minLength: ResponsiveDesign.height(50))

                        // Bottom controls - Düzenle or Save buttons
                        if !isEditMode && !showSaveButtons {
                            // Show edit (pencil) button when in read-only mode
                            Button(action: { toggleEditMode() }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.primaryPurple)
                                    .frame(width: ResponsiveDesign.height(72), height: ResponsiveDesign.height(72))
                                    .background(
                                        Circle()
                                            .fill(.clear)
                                            .glassEffect(.regular.interactive(), in: Circle())
                                    )
                            }
                            .padding(.bottom, ResponsiveDesign.height(12))
                        } else if isEditMode {
                            // Show done (checkmark) button when editing
                            Button(action: { toggleEditMode() }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.primaryPurple)
                                    .frame(width: ResponsiveDesign.height(72), height: ResponsiveDesign.height(72))
                                    .background(
                                        Circle()
                                            .fill(.clear)
                                            .glassEffect(.regular.interactive(), in: Circle())
                                    )
                            }
                            .padding(.bottom, ResponsiveDesign.height(12))
                        } else if showSaveButtons {
                            // Show both edit and save buttons after user taps done
                            HStack(spacing: 60) {
                                // Edit button (pencil) - transparent like retake button
                                Button(action: { toggleEditMode() }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 24, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.primaryPurple)
                                        .frame(width: ResponsiveDesign.height(72), height: ResponsiveDesign.height(72))
                                        .background(
                                            Circle()
                                                .fill(.clear)
                                                .glassEffect(.regular.interactive(), in: Circle())
                                        )
                                        .overlay(
                                            Circle()
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
                                }

                                // Save button (checkmark) - filled purple like use button
                                Button(action: handleSave) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(width: ResponsiveDesign.height(72), height: ResponsiveDesign.height(72))
                                        .background(
                                            Circle()
                                                .fill(AppTheme.primaryPurple)
                                                .glassEffect(.regular.interactive(), in: Circle())
                                        )
                                }
                            }
                            .padding(.bottom, ResponsiveDesign.height(12))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toast($toastMessage)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(ThemeColors.primaryPurple)
                    }
                }
            }
        }
        .alert("Doğrulama Hatası", isPresented: $showingValidationAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            VStack(alignment: .leading) {
                if !validationErrors.isEmpty {
                    Text("Hatalar:")
                    ForEach(validationErrors, id: \.self) { error in
                        Text("• \(error)")
                    }
                }
                if !validationWarnings.isEmpty {
                    Text("\nUyarılar:")
                    ForEach(validationWarnings, id: \.self) { warning in
                        Text("• \(warning)")
                    }
                }
            }
        }
        .alert("Ardiye'ye Kaydedildi", isPresented: $showingSaveConfirmation) {
            Button("Tamam") {
                dismiss()
            }
        } message: {
            Text("\(productName.isEmpty ? "Ürün" : productName) başarıyla güncellendi.")
        }
        .onChange(of: validationErrors) { _, newErrors in
            if !newErrors.isEmpty {
                showingValidationAlert = true
            }
        }
        .onAppear {
            loadFoodItemData()
        }
    }

    // MARK: - Private Views

    // MARK: - Computed Properties

    private var showSaveButtons: Bool {
        !isEditMode && hasUnsavedChanges
    }

    private var hasUnsavedChanges: Bool {
        productBrand != (foodItem.brand ?? "") ||
        productName != foodItem.name ||
        calories != String(format: "%.0f", foodItem.calories) ||
        servingSize != String(format: "%.0f", foodItem.servingSize) ||
        carbohydrates != String(format: "%.1f", foodItem.totalCarbs) ||
        fiber != String(format: "%.1f", foodItem.fiber) ||
        sugars != String(format: "%.1f", foodItem.sugars) ||
        protein != String(format: "%.1f", foodItem.protein) ||
        fat != String(format: "%.1f", foodItem.totalFat) ||
        portionGrams != foodItem.servingSize  // Check if portion size (slider) changed
    }

    // Toast notification for save feedback
    @State private var toastMessage: ToastType? = nil

    // Calculate current impact using Nestlé formula for the current portion
    private var currentImpactResult: ImpactScoreResult? {
        guard let baseCarbs = Double(carbohydrates),
              let baseFiber = Double(fiber),
              let baseSugars = Double(sugars),
              let baseProtein = Double(protein),
              let baseFat = Double(fat),
              let baseServing = Double(servingSize),
              baseServing > 0 else {
            return nil
        }

        return ImpactScoreCalculator.calculate(
            totalCarbs: baseCarbs,
            fiber: baseFiber,
            sugar: baseSugars,
            protein: baseProtein,
            fat: baseFat,
            servingSize: baseServing,
            portionGrams: portionGrams
        )
    }

    private var currentImpactScore: Double {
        return currentImpactResult?.score ?? 0.0
    }

    private var currentImpactLevel: ImpactLevel {
        guard let result = currentImpactResult else {
            return .low
        }
        // Use three-threshold evaluation for accurate safety assessment
        return ImpactLevel.from(
            score: result.score,
            fat: Double(fat) ?? 0.0,
            protein: Double(protein) ?? 0.0
        )
    }

    // MARK: - Actions

    private func loadFoodItemData() {
        productBrand = foodItem.brand ?? ""
        productName = foodItem.name
        calories = String(format: "%.0f", foodItem.calories)
        servingSize = String(format: "%.0f", foodItem.servingSize)
        carbohydrates = String(format: "%.1f", foodItem.totalCarbs)
        fiber = String(format: "%.1f", foodItem.fiber)
        sugars = String(format: "%.1f", foodItem.sugars)
        protein = String(format: "%.1f", foodItem.protein)
        fat = String(format: "%.1f", foodItem.totalFat)
        portionGrams = foodItem.servingSize
    }

    private func toggleEditMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode.toggle()
        }
    }

    private func handleSave() {
        // Validate inputs
        validationErrors.removeAll()
        validationWarnings.removeAll()

        if productName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Ürün adı boş olamaz")
        }

        if let caloriesValue = Double(calories), caloriesValue < 0 {
            validationErrors.append("Kalori değeri negatif olamaz")
        }

        if !validationErrors.isEmpty {
            showingValidationAlert = true
            return
        }

        // CRITICAL: Verify foodItem is in the correct context
        guard foodItem.managedObjectContext == viewContext else {
            logger.error("❌ FoodItem is not in viewContext - cannot save")
            validationErrors.append("Veri tutarsızlığı - lütfen tekrar açın")
            showingValidationAlert = true
            return
        }

        // Save to Core Data
        Task { @MainActor in
            do {
                let baseServing = Double(servingSize) ?? 100.0
                let portionChanged = portionGrams != foodItem.servingSize

                // Update food item
                foodItem.brand = productBrand.trimmingCharacters(in: .whitespaces)
                foodItem.name = productName.trimmingCharacters(in: .whitespaces)
                foodItem.lastModified = Date()

                // If portion size changed, recalculate nutrition values proportionally
                if portionChanged {
                    let adjustmentRatio = portionGrams / baseServing

                    logger.info("🔧 PORTION CHANGE DETECTED")
                    logger.info("  - Product: \(foodItem.name)")
                    logger.info("  - Old portion: \(foodItem.servingSize)g")
                    logger.info("  - New portion: \(portionGrams)g")
                    logger.info("  - Adjustment ratio: \(adjustmentRatio)")
                    logger.info("  - Old carbs: \(foodItem.totalCarbs)g")

                    // Update serving size to the new portion
                    foodItem.servingSize = portionGrams

                    // Adjust all nutrition values proportionally to maintain consistency
                    foodItem.calories = (Double(calories) ?? 0) * adjustmentRatio
                    foodItem.totalCarbs = (Double(carbohydrates) ?? 0) * adjustmentRatio
                    foodItem.fiber = (Double(fiber) ?? 0) * adjustmentRatio
                    foodItem.sugars = (Double(sugars) ?? 0) * adjustmentRatio
                    foodItem.protein = (Double(protein) ?? 0) * adjustmentRatio
                    foodItem.totalFat = (Double(fat) ?? 0) * adjustmentRatio
                    foodItem.sodium = (foodItem.sodium) * adjustmentRatio

                    logger.info("  - New carbs: \(foodItem.totalCarbs)g")
                    logger.info("✅ Portion update complete - ready to save")
                } else {
                    // No portion change - just update the text fields
                    logger.info("📝 TEXT FIELD UPDATE (no portion change)")
                    logger.info("  - Product: \(foodItem.name)")

                    foodItem.calories = Double(calories) ?? 0
                    foodItem.totalCarbs = Double(carbohydrates) ?? 0
                    foodItem.fiber = Double(fiber) ?? 0
                    foodItem.sugars = Double(sugars) ?? 0
                    foodItem.protein = Double(protein) ?? 0
                    foodItem.totalFat = Double(fat) ?? 0
                }

                logger.info("💾 Saving to Core Data...")
                try viewContext.save()
                logger.info("✅ Core Data save successful")

                toastMessage = .success("Kaydedildi")
                showingSaveConfirmation = true

                logger.info("Successfully updated food item: \(foodItem.name)")
            } catch {
                toastMessage = .error("Kaydetme başarısız oldu")
                validationErrors.append("Kaydedilemedi: \(error.localizedDescription)")
                showingValidationAlert = true

                logger.error("Failed to save food item: \(error.localizedDescription)")
            }
        }
    }

    private func handleBack() {
        dismiss()
    }
}

// MARK: - Previews

#Preview("Product Detail - View Mode") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    // Create a sample FoodItem
    let context = persistenceController.viewContext
    let foodItem = FoodItem(context: context)
    foodItem.id = UUID()
    foodItem.name = "Çikolatalı Gofret"
    foodItem.brand = "Ülker"
    foodItem.calories = 240
    foodItem.servingSize = 100
    foodItem.servingUnit = "g"
    foodItem.totalCarbs = 20
    foodItem.fiber = 6
    foodItem.sugars = 8
    foodItem.protein = 12
    foodItem.totalFat = 8
    foodItem.source = "ai_scanned"
    foodItem.dateAdded = Date()
    foodItem.lastModified = Date()

    return NavigationStack {
        FoodItemDetailView(foodItem: foodItem)
            .environment(\.managedObjectContext, context)
    }
}

#Preview("Product Detail - Low Impact Food") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    let context = persistenceController.viewContext
    let foodItem = FoodItem(context: context)
    foodItem.id = UUID()
    foodItem.name = "Badem"
    foodItem.brand = "Tariş"
    foodItem.calories = 160
    foodItem.servingSize = 28
    foodItem.servingUnit = "g"
    foodItem.totalCarbs = 6
    foodItem.fiber = 3.5
    foodItem.sugars = 1
    foodItem.protein = 6
    foodItem.totalFat = 14
    foodItem.source = "ai_scanned"
    foodItem.dateAdded = Date()
    foodItem.lastModified = Date()

    return NavigationStack {
        FoodItemDetailView(foodItem: foodItem)
            .environment(\.managedObjectContext, context)
    }
}

#Preview("Product Detail - High Impact Food") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    let context = persistenceController.viewContext
    let foodItem = FoodItem(context: context)
    foodItem.id = UUID()
    foodItem.name = "Gummy Bears"
    foodItem.brand = "Haribo"
    foodItem.calories = 70
    foodItem.servingSize = 20
    foodItem.servingUnit = "g"
    foodItem.totalCarbs = 17
    foodItem.fiber = 0
    foodItem.sugars = 15
    foodItem.protein = 0
    foodItem.totalFat = 0
    foodItem.source = "ai_scanned"
    foodItem.dateAdded = Date()
    foodItem.lastModified = Date()

    return NavigationStack {
        FoodItemDetailView(foodItem: foodItem)
            .environment(\.managedObjectContext, context)
    }
}
