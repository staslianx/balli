//
//  AIResultViewModel.swift
//  balli
//
//  View model for AI result processing with separated concerns
//

import SwiftUI
import CoreData
import os.log
import Combine

/// View model handling AI result display and editing workflow
@MainActor
final class AIResultViewModel: ObservableObject {
    // MARK: - Published State

    /// Form data (editable nutrition values)
    @Published var formState: NutritionFormState

    /// UI state (flags, animations, validation)
    @Published var uiState: AIResultUIState

    /// Analysis state
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Double = 0.0
    @Published var analysisStage: AnalysisStage = .preparing

    // MARK: - Properties

    let capturedImage: UIImage
    @Published var nutritionResult: NutritionExtractionResult?
    private var captureFlowManager: CaptureFlowManager?
    private let validationService = NutritionValidationService()
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AIResultViewModel")

    // Task and subscription management for proper cleanup
    private var analysisTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize with complete nutrition results
    init(nutritionResult: NutritionExtractionResult, capturedImage: UIImage) {
        self.nutritionResult = nutritionResult
        self.capturedImage = capturedImage
        self.formState = NutritionFormState(from: nutritionResult)
        self.uiState = .readOnly()
        self.isAnalyzing = false
    }

    /// Initialize with nutrition results simulating post-analysis state (for previews)
    init(nutritionResult: NutritionExtractionResult, capturedImage: UIImage, simulatePostAnalysis: Bool) {
        self.nutritionResult = nutritionResult
        self.capturedImage = capturedImage
        self.formState = NutritionFormState(from: nutritionResult)
        self.isAnalyzing = false

        if simulatePostAnalysis {
            self.uiState = .readOnly()
        } else {
            self.uiState = .saveReady()
        }
    }

    /// Initialize with analysis in progress
    init(capturedImage: UIImage, captureFlowManager: CaptureFlowManager) {
        self.capturedImage = capturedImage
        self.captureFlowManager = captureFlowManager
        self.formState = NutritionFormState()
        self.uiState = .analyzing()
        self.isAnalyzing = true
        // Note: Don't start tracking here - wait until analysis actually begins
    }

    // MARK: - Public Methods - UI Actions

    func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            uiState.toggleEditMode()
        }
    }

    func saveFood(in viewContext: NSManagedObjectContext, onSuccess: @escaping () -> Void) {
        // Prevent multiple saves
        guard !uiState.isSaveInProgress else {
            logger.warning("Save already in progress, ignoring duplicate request")
            return
        }

        Task {
            // Validate data first
            let validation = await validationService.validate(formState)

            await MainActor.run {
                uiState.setValidationErrors(validation.errors, warnings: validation.warnings)

                if !validation.isValid {
                    return
                }

                uiState.startSaving()
                performSave(in: viewContext, onSuccess: onSuccess)
            }
        }
    }

    func createShareText() -> String {
        var text = "🍎 Balli - Besin Değerleri\n"
        text += "━━━━━━━━━━━━━━━━━━\n"

        if !formState.productName.isEmpty {
            text += "📦 Ürün: \(formState.productName)\n"
        }
        if !formState.productBrand.isEmpty {
            text += "🏷️ Marka: \(formState.productBrand)\n"
        }

        text += "\n📊 Besin Değerleri (\(formState.servingSize)g):\n"
        text += "• Kalori: \(formState.calories) kcal\n"
        text += "• Karbonhidrat: \(formState.carbohydrates)g\n"
        text += "• Lif: \(formState.fiber)g\n"
        text += "• Şeker: \(formState.sugars)g\n"
        text += "• Protein: \(formState.protein)g\n"
        text += "• Yağ: \(formState.fat)g\n"

        if formState.portionGrams != 100 {
            text += "\n🍽️ Porsiyon: \(Int(formState.portionGrams))g\n"
            text += "• Net Karb: \(String(format: "%.1f", formState.calculateNetCarbs()))g\n"
        }

        text += "\n🤖 AI ile analiz edildi"

        return text
    }

    /// Start the actual AI processing (called from view)
    func startAnalysisProcessing() async {
        guard let captureFlowManager = captureFlowManager else {
            logger.error("No captureFlowManager available for analysis")
            return
        }

        logger.info("Starting AI analysis processing")

        // Start confirmAndProcess (which sets isAnalyzing = true) and tracking concurrently
        // confirmAndProcess will set isAnalyzing immediately, then tracking will see it as true
        async let processing: () = captureFlowManager.confirmAndProcess()

        // Give confirmAndProcess a moment to set isAnalyzing = true before starting tracking
        try? await Task.sleep(for: .milliseconds(100))
        startAnalysisTracking()

        // Wait for processing to complete
        await processing
    }

    // MARK: - Private Methods - Core Data Persistence

    private func performSave(in viewContext: NSManagedObjectContext, onSuccess: @escaping () -> Void) {
        // Create FoodItem in Core Data
        let foodItem = FoodItem(context: viewContext)
        foodItem.id = UUID()
        foodItem.name = formState.productName.isEmpty ? "Bilinmeyen Ürün" : formState.productName
        foodItem.brand = formState.productBrand.isEmpty ? nil : formState.productBrand

        // Store the user's selected serving size
        foodItem.servingSize = formState.portionGrams
        foodItem.servingUnit = "g"

        // Calculate adjusted values based on portion
        let baseServing = formState.servingSize.toDouble ?? 100.0
        let adjustmentRatio = formState.portionGrams / baseServing

        // Save adjusted values based on the selected portion
        foodItem.calories = (formState.calories.toDouble ?? 0) * adjustmentRatio
        foodItem.totalCarbs = (formState.carbohydrates.toDouble ?? 0) * adjustmentRatio
        foodItem.fiber = (formState.fiber.toDouble ?? 0) * adjustmentRatio
        foodItem.sugars = (formState.sugars.toDouble ?? 0) * adjustmentRatio
        foodItem.protein = (formState.protein.toDouble ?? 0) * adjustmentRatio
        foodItem.totalFat = (formState.fat.toDouble ?? 0) * adjustmentRatio
        foodItem.sodium = (formState.sodium.toDouble ?? 0) * adjustmentRatio

        foodItem.source = "ai_scanned"
        foodItem.dateAdded = Date()
        foodItem.lastModified = Date()

        // Set confidence scores
        foodItem.carbsConfidence = Double(formState.carbsConfidence)
        foodItem.overallConfidence = formState.calculateOverallConfidence()

        do {
            try viewContext.save()
            logger.info("Saved FoodItem: \(foodItem.name, privacy: .public)")

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            // Reset save state after a small delay to ensure UI updates
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                self.uiState.completeSaving()
            }

            onSuccess()
        } catch {
            logger.error("Failed to save FoodItem: \(error.localizedDescription)")
            uiState.completeSaving()
            uiState.setValidationErrors(["Kaydetme hatası: \(error.localizedDescription)"], warnings: [])
        }
    }

    // MARK: - Private Methods - Analysis Tracking

    /// Start tracking analysis progress using Combine observation (battery-efficient)
    private func startAnalysisTracking() {
        guard let captureFlowManager = captureFlowManager else { return }

        // Cancel any existing tracking
        analysisTask?.cancel()
        cancellables.removeAll()

        // Observe extractedNutrition for completion
        captureFlowManager.$extractedNutrition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nutrition in
                if let nutrition = nutrition {
                    self?.handleAnalysisComplete(nutrition)
                }
            }
            .store(in: &cancellables)

        // Observe errors
        captureFlowManager.$currentError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if error != nil {
                    self?.handleAnalysisError()
                }
            }
            .store(in: &cancellables)

        // Progress simulation task (runs until analysis completes or is cancelled)
        analysisTask = Task { @MainActor [weak self, weak captureFlowManager] in
            guard let self = self, let captureFlowManager = captureFlowManager else { return }

            // Update progress at reasonable intervals (5Hz instead of 6.67Hz)
            while !Task.isCancelled && captureFlowManager.isAnalyzing {
                self.updateAnalysisState()

                // Sleep for 200ms between updates (battery-friendly)
                try? await Task.sleep(for: .milliseconds(200))
            }

            self.logger.debug("Analysis tracking completed or cancelled")
        }
    }

    private func updateAnalysisState() {
        // More balanced progress tracking with even stage distribution
        let increment = 0.015 // Slower, more even progression
        let oldProgress = analysisProgress
        let oldStage = analysisStage

        analysisProgress = min(0.98, analysisProgress + increment)

        // Evenly distributed stage transitions
        if analysisProgress < 0.15 {
            analysisStage = .preparing
        } else if analysisProgress < 0.35 {
            analysisStage = .analyzing
        } else if analysisProgress < 0.55 {
            analysisStage = .reading
        } else if analysisProgress < 0.75 {
            analysisStage = .sending
        } else if analysisProgress < 0.90 {
            analysisStage = .processing
        } else {
            analysisStage = .validating
        }

        // Log stage transitions for debugging
        if oldStage != self.analysisStage {
            logger.info("🔄 VM STAGE TRANSITION: \(String(describing: oldStage)) → \(String(describing: self.analysisStage)) (progress: \(oldProgress, format: .fixed(precision: 2)) → \(self.analysisProgress, format: .fixed(precision: 2)))")
        }
    }

    private func handleAnalysisComplete(_ nutrition: NutritionExtractionResult) {
        nutritionResult = nutrition
        analysisProgress = 1.0
        analysisStage = .completed
        isAnalyzing = false

        // Update form state with real data
        formState = NutritionFormState(from: nutrition)

        // Transition to read-only mode with edit button
        uiState = .readOnly()

        // Trigger staggered animations
        initializeFieldsWithAnimation()
    }

    private func handleAnalysisError() {
        analysisStage = .error
        isAnalyzing = false
    }

    /// Initialize fields with staggered fade-in animations
    private func initializeFieldsWithAnimation() {
        // Set animation states BEFORE showing values
        uiState.showingValues = false
        uiState.valuesAnimationProgress = [:]

        // Start staggered animations after a brief delay
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            self.triggerValueAnimations()
        }
    }

    /// Trigger staggered fade-in animations for each nutrition value
    private func triggerValueAnimations() {
        let animationFields = [
            "calories", "carbohydrates", "fiber",
            "sugars", "protein", "fat"
        ]

        // Show general values state after all animations start
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.4)) {
                self.uiState.showingValues = true
            }
        }

        // Stagger field animations
        for (index, field) in animationFields.enumerated() {
            let delay = Duration.milliseconds(index * 150) // 150ms between each animation

            Task {
                try? await Task.sleep(for: delay)
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.uiState.valuesAnimationProgress[field] = true
                }
            }
        }
    }

    // MARK: - Computed Properties (Convenience accessors for View)

    var currentImpactScore: Double {
        formState.calculateImpactScore()
    }

    var currentImpactLevel: ImpactLevel {
        formState.impactLevel
    }

    // MARK: - Cleanup

    deinit {
        logger.debug("AIResultViewModel deinitializing - cleaning up resources")

        // Cancel ongoing tasks
        analysisTask?.cancel()
        // Note: cancellables will be automatically cleaned up by ARC

        logger.debug("AIResultViewModel cleanup complete")
    }
}
