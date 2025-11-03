//
//  EdamamTestView.swift
//  balli
//
//  EDAMAM API test harness view
//  Tests Turkish language support and ingredient parsing accuracy
//

import SwiftUI
import CoreData
import OSLog

struct EdamamTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var viewModel: RecipeViewModel
    @StateObject private var testService = EdamamTestService()

    @State private var showingMealSelection = false
    @State private var selectedMealType = "Kahvaltı"
    @State private var selectedStyleType = ""
    @State private var isGenerating = false
    @State private var testResult: EdamamTestResult?
    @State private var showingResults = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "EdamamTestView")

    init(viewContext: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: RecipeViewModel(context: viewContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Status Section
                    if isGenerating || testService.isLoading {
                        loadingSection
                    } else if let result = testResult {
                        resultsSection(result: result)
                    } else {
                        welcomeSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("EDAMAM Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ThemeColors.primaryPurple)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingMealSelection = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ThemeColors.primaryPurple)
                    }
                    .disabled(isGenerating || testService.isLoading)
                }
            }
            .sheet(isPresented: $showingMealSelection) {
                RecipeMealSelectionView(
                    selectedMealType: $selectedMealType,
                    selectedStyleType: $selectedStyleType,
                    onGenerate: {
                        Task {
                            await startTest()
                        }
                    }
                )
                .presentationDetents([.fraction(0.4)])
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flask.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("EDAMAM API Test")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Turkish Language & Measurement Testing")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Test indicators
            HStack(spacing: 12) {
                TestBadge(icon: "🇹🇷", title: "Turkish", subtitle: "Language")
                TestBadge(icon: "½", title: "Fractions", subtitle: "1/2, 1/4")
                TestBadge(icon: "📏", title: "Measurements", subtitle: "Çay bardağı")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Test EDAMAM API")
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            Text("Generate a recipe with Gemini, then test if EDAMAM can parse Turkish ingredients and measurements.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingMealSelection = true
            }) {
                Label("Start Test", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.primaryPurple)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            if isGenerating {
                Text("Generating recipe with Gemini...")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
            } else {
                Text("Testing with EDAMAM API...")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
            }

            if !viewModel.recipeName.isEmpty {
                Text(viewModel.recipeName)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(40)
    }

    // MARK: - Results Section

    private func resultsSection(result: EdamamTestResult) -> some View {
        VStack(spacing: 20) {
            // Overall Score Card
            scoreCard(result: result)

            // Nutrition Comparison
            nutritionComparison(result: result)

            // Ingredient Recognition
            ingredientRecognition(result: result)

            // Compatibility Stats
            compatibilityStats(result: result)

            // Test Again Button
            Button(action: {
                testResult = nil
                viewModel.clearAllFields()
                showingMealSelection = true
            }) {
                Label("Test Another Recipe", systemImage: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeColors.primaryPurple)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ThemeColors.primaryPurple, lineWidth: 2)
                    )
            }
        }
    }

    // MARK: - Score Card

    private func scoreCard(result: EdamamTestResult) -> some View {
        VStack(spacing: 16) {
            Text(result.recipeName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 40) {
                ScoreCircle(
                    value: result.overallAccuracy,
                    title: "Accuracy",
                    color: colorForAccuracy(result.overallAccuracy)
                )

                ScoreCircle(
                    value: result.recognitionRate,
                    title: "Recognition",
                    color: colorForAccuracy(result.recognitionRate)
                )
            }

            Text(result.processingTime)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Nutrition Comparison

    private func nutritionComparison(result: EdamamTestResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Comparison")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 4)

            NutrientRow(
                name: "Calories",
                gemini: result.geminiNutrition.formattedCalories,
                edamam: result.edamamNutrition.formattedCalories,
                accuracy: result.accuracyScores.calories
            )

            NutrientRow(
                name: "Carbs",
                gemini: "\(result.geminiNutrition.formattedCarbs)g",
                edamam: "\(result.edamamNutrition.formattedCarbs)g",
                accuracy: result.accuracyScores.carbs
            )

            NutrientRow(
                name: "Protein",
                gemini: "\(result.geminiNutrition.formattedProtein)g",
                edamam: "\(result.edamamNutrition.formattedProtein)g",
                accuracy: result.accuracyScores.protein
            )

            NutrientRow(
                name: "Fat",
                gemini: "\(result.geminiNutrition.formattedFat)g",
                edamam: "\(result.edamamNutrition.formattedFat)g",
                accuracy: result.accuracyScores.fat
            )

            NutrientRow(
                name: "Fiber",
                gemini: "\(result.geminiNutrition.formattedFiber)g",
                edamam: "\(result.edamamNutrition.formattedFiber)g",
                accuracy: result.accuracyScores.fiber
            )

            NutrientRow(
                name: "Sugar",
                gemini: "\(result.geminiNutrition.formattedSugar)g",
                edamam: "\(result.edamamNutrition.formattedSugar)g",
                accuracy: result.accuracyScores.sugar
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Ingredient Recognition

    private func ingredientRecognition(result: EdamamTestResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredient Recognition")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 4)

            ForEach(result.ingredients) { ingredient in
                IngredientStatusRow(ingredient: ingredient)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Compatibility Stats

    private func compatibilityStats(result: EdamamTestResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compatibility Analysis")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 4)

            HStack {
                EdamamStatBox(
                    icon: "🇹🇷",
                    title: "Turkish",
                    value: "\(result.compatibility.turkishIngredientsCount)",
                    subtitle: "ingredients"
                )

                EdamamStatBox(
                    icon: "½",
                    title: "Fractions",
                    value: "\(result.compatibility.fractionalMeasurementsCount)",
                    subtitle: "measurements"
                )

                EdamamStatBox(
                    icon: "📏",
                    title: "Turkish Units",
                    value: "\(result.compatibility.turkishMeasurementsCount)",
                    subtitle: "found"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Actions

    private func startTest() async {
        logger.info("🧪 [TEST-UI] ═══════════════════════════════════════")
        logger.info("🧪 [TEST-UI] Starting EDAMAM test workflow")
        logger.info("🧪 [TEST-UI] Meal Type: \(selectedMealType)")
        logger.info("🧪 [TEST-UI] Style Type: \(selectedStyleType.isEmpty ? "(using meal type)" : selectedStyleType)")
        logger.info("🧪 [TEST-UI] ═══════════════════════════════════════")

        // Reset state
        testResult = nil
        isGenerating = true

        logger.info("🔄 [TEST-UI] STEP 1: Generating recipe with Gemini...")
        logger.info("🔄 [TEST-UI] Calling RecipeViewModel.generationCoordinator.generateRecipeWithStreaming()")

        // Step 1: Generate recipe with Gemini
        await viewModel.generationCoordinator.generateRecipeWithStreaming(
            mealType: selectedMealType,
            styleType: selectedStyleType.isEmpty ? selectedMealType : selectedStyleType
        )

        isGenerating = false
        logger.info("✅ [TEST-UI] Recipe generation completed")

        // Check if recipe generation succeeded
        logger.info("🔍 [TEST-UI] Validating recipe generation results...")
        logger.info("   Recipe name: '\(viewModel.recipeName)'")
        logger.info("   Recipe content length: \(viewModel.recipeContent.count) characters")
        logger.info("   Calories: \(viewModel.calories)")
        logger.info("   Carbs: \(viewModel.carbohydrates)g")
        logger.info("   Protein: \(viewModel.protein)g")
        logger.info("   Fat: \(viewModel.fat)g")

        guard !viewModel.recipeName.isEmpty && !viewModel.recipeContent.isEmpty else {
            logger.error("❌ [TEST-UI] Recipe generation failed - empty name or content")
            logger.error("   Recipe name empty: \(viewModel.recipeName.isEmpty)")
            logger.error("   Recipe content empty: \(viewModel.recipeContent.isEmpty)")
            testService.errorMessage = "Failed to generate recipe"
            return
        }

        logger.info("✅ [TEST-UI] Recipe validation passed: '\(viewModel.recipeName)'")

        // Log a preview of the recipe content
        let contentPreview = String(viewModel.recipeContent.prefix(300))
        logger.debug("📝 [TEST-UI] Recipe content preview (first 300 chars):")
        logger.debug("\(contentPreview)...")

        logger.info("🔄 [TEST-UI] ═══════════════════════════════════════")
        logger.info("🔄 [TEST-UI] STEP 2: Testing with EDAMAM API...")
        logger.info("🔄 [TEST-UI] ═══════════════════════════════════════")

        // Step 2: Test with EDAMAM
        do {
            logger.info("📦 [TEST-UI] Preparing RequestNutrition object:")
            let requestNutrition = RequestNutrition(
                calories: viewModel.calories,
                carbohydrates: viewModel.carbohydrates,
                protein: viewModel.protein,
                fat: viewModel.fat,
                fiber: viewModel.fiber,
                sugar: viewModel.sugar,
                glycemicLoad: viewModel.glycemicLoad
            )
            logger.info("   Calories: \(requestNutrition.calories)")
            logger.info("   Carbs: \(requestNutrition.carbohydrates)g")
            logger.info("   Protein: \(requestNutrition.protein)g")
            logger.info("   Fat: \(requestNutrition.fat)g")
            logger.info("   Fiber: \(requestNutrition.fiber)g")
            logger.info("   Sugar: \(requestNutrition.sugar)g")
            logger.info("   Glycemic Load: \(requestNutrition.glycemicLoad)")

            logger.info("🌐 [TEST-UI] Calling EdamamTestService.testRecipe()...")

            let result = try await testService.testRecipe(
                userId: "serhat@balli",
                recipeName: viewModel.recipeName,
                mealType: selectedMealType,
                styleType: selectedStyleType.isEmpty ? selectedMealType : selectedStyleType,
                recipeContent: viewModel.recipeContent,
                geminiNutrition: requestNutrition
            )

            logger.info("✅ [TEST-UI] EDAMAM test completed successfully!")
            logger.info("📊 [TEST-UI] ═══════════════════════════════════════")
            logger.info("📊 [TEST-UI] FINAL RESULTS:")
            logger.info("   Test ID: \(result.testId)")
            logger.info("   Overall Accuracy: \(result.overallAccuracy)% (Grade: \(result.accuracyGrade))")
            logger.info("   Recognition Rate: \(result.recognitionRate)% (\(result.recognitionStatus))")
            logger.info("   Total Ingredients: \(result.ingredients.count)")
            logger.info("   Recognized: \(result.ingredients.filter { $0.recognized }.count)")
            logger.info("   Processing Time: \(result.processingTime)")
            logger.info("📊 [TEST-UI] ═══════════════════════════════════════")

            testResult = result

            // Detailed ingredient breakdown
            logger.info("📋 [TEST-UI] Ingredient Breakdown:")
            for (index, ingredient) in result.ingredients.enumerated() {
                let status = ingredient.recognized ? "✅" : "❌"
                logger.info("   \(index + 1). \(status) \(ingredient.text)")
                if ingredient.hasTurkishCharacters {
                    logger.info("      🇹🇷 Contains Turkish characters")
                }
                if ingredient.hasFractionalMeasurement {
                    logger.info("      ½ Contains fractional measurement")
                }
                if ingredient.hasTurkishMeasurement {
                    logger.info("      📏 Contains Turkish measurement unit")
                }
            }

            logger.info("✅ [TEST-UI] Test workflow completed successfully!")

        } catch {
            logger.error("❌ [TEST-UI] ═══════════════════════════════════════")
            logger.error("❌ [TEST-UI] EDAMAM test failed!")
            logger.error("❌ [TEST-UI] Error type: \(type(of: error))")
            logger.error("❌ [TEST-UI] Error description: \(error.localizedDescription)")

            if let edamamError = error as? EdamamTestError {
                logger.error("❌ [TEST-UI] EDAMAM-specific error:")
                switch edamamError {
                case .invalidResponse:
                    logger.error("   - Invalid response from server")
                case .httpError(let code):
                    logger.error("   - HTTP error code: \(code)")
                case .apiError(let message):
                    logger.error("   - API error: \(message)")
                case .testFailed(let message):
                    logger.error("   - Test failed: \(message)")
                case .decodingError(let message):
                    logger.error("   - Decoding error: \(message)")
                }
            }

            logger.error("❌ [TEST-UI] ═══════════════════════════════════════")
            testService.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func colorForAccuracy(_ value: Int) -> Color {
        switch value {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

struct TestBadge: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 24))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScoreCircle: View {
    let value: Int
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(value)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

struct NutrientRow: View {
    let name: String
    let gemini: String
    let edamam: String
    let accuracy: Double

    private var accuracyColor: Color {
        switch accuracy {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text(gemini)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(edamam)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .frame(width: 60, alignment: .leading)

            Circle()
                .fill(accuracyColor)
                .frame(width: 8, height: 8)
        }
    }
}

struct IngredientStatusRow: View {
    let ingredient: IngredientResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ingredient.statusIcon)
                .font(.system(size: 16))
                .foregroundColor(ingredient.recognized ? .green : .red)

            Text(ingredient.text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .lineLimit(2)

            Spacer()

            ForEach(ingredient.badges, id: \.self) { badge in
                Text(badge)
                    .font(.system(size: 14))
            }
        }
    }
}

struct EdamamStatBox: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 24))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))

            Text(subtitle)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

#Preview {
    EdamamTestView(viewContext: PersistenceController.preview.container.viewContext)
}
