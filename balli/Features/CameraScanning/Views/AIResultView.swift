//
//  AIResultView.swift
//  balli
//
//  AI-extracted nutrition result display with editing capabilities
//

import SwiftUI
import CoreData
import os.log

/// Main container view for displaying AI-extracted nutrition results
struct AIResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    // View model managing all business logic
    @StateObject private var viewModel: AIResultViewModel
    
    // UI States
    @State private var showingValidationAlert = false
    @State private var toastMessage: ToastType? = nil

    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AIResult")
    
    // MARK: - Initialization

    /// Initialize with complete nutrition results (analysis finished)
    init(nutritionResult: NutritionExtractionResult, capturedImage: UIImage) {
        self._viewModel = StateObject(wrappedValue: AIResultViewModel(
            nutritionResult: nutritionResult,
            capturedImage: capturedImage
        ))
    }

    /// Initialize with analysis in progress
    init(capturedImage: UIImage, captureFlowManager: CaptureFlowManager) {
        self._viewModel = StateObject(wrappedValue: AIResultViewModel(
            capturedImage: capturedImage,
            captureFlowManager: captureFlowManager
        ))
    }

    /// Initialize simulating post-analysis state (for previews)
    init(nutritionResult: NutritionExtractionResult, capturedImage: UIImage, simulatePostAnalysis: Bool) {
        self._viewModel = StateObject(wrappedValue: AIResultViewModel(
            nutritionResult: nutritionResult,
            capturedImage: capturedImage,
            simulatePostAnalysis: simulatePostAnalysis
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack {
                        Spacer(minLength: ResponsiveDesign.height(50))

                        // Show analysis label during analysis, or regular label when complete
                        if viewModel.isAnalyzing {
                            AnalysisNutritionLabelView(
                                capturedImage: viewModel.capturedImage,
                                currentStage: viewModel.analysisStage,
                                visualProgress: viewModel.analysisProgress,
                                errorMessage: nil,
                                nutritionResult: viewModel.nutritionResult
                            )
                            .id(viewModel.analysisStage)
                        } else {
                            // Food label container with integrated impact banner
                            NutritionLabelView(
                                productBrand: $viewModel.formState.productBrand,
                                productName: $viewModel.formState.productName,
                                calories: $viewModel.formState.calories,
                                servingSize: $viewModel.formState.servingSize,
                                carbohydrates: $viewModel.formState.carbohydrates,
                                fiber: $viewModel.formState.fiber,
                                sugars: $viewModel.formState.sugars,
                                protein: $viewModel.formState.protein,
                                fat: $viewModel.formState.fat,
                                portionGrams: $viewModel.formState.portionGrams,
                                isEditing: viewModel.uiState.isEditing,
                                showIcon: false, // No brain icon - using impact banner instead
                                iconName: "laser.burst",
                                iconColor: AppTheme.primaryPurple,
                                showImpactBanner: viewModel.uiState.showImpactBanner,
                                impactLevel: viewModel.currentImpactLevel,
                                impactScore: viewModel.currentImpactScore,
                                showingValues: viewModel.uiState.showingValues,
                                valuesAnimationProgress: viewModel.uiState.valuesAnimationProgress,
                                showSlider: viewModel.uiState.showSlider  // ✅ Control slider visibility by state
                            )
                        }
                        
                        Spacer(minLength: ResponsiveDesign.height(46))
                        
                        // Bottom controls - Analysis, Düzenle, or Kaydet
                        if viewModel.isAnalyzing {
                            // Show X mark button during analysis
                            Button(action: handleBack) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .toolbarCircularGlass(size: ResponsiveDesign.height(72))
                            .padding(.bottom, ResponsiveDesign.height(12))
                        } else if viewModel.uiState.showEditButton {
                            // Show edit (pencil) button when in read-only mode
                            Button(action: { viewModel.toggleEditMode() }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 30, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .toolbarCircularGlass(size: ResponsiveDesign.height(72))
                            .padding(.bottom, ResponsiveDesign.height(12))
                        } else if viewModel.uiState.isEditing {
                            // Show done (checkmark) button when editing - SAME SIZE as retake button
                            Button(action: { viewModel.toggleEditMode() }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                            }
                            .buttonStyle(.balliBordered(size: ResponsiveDesign.height(72)))
                            .padding(.bottom, ResponsiveDesign.height(12))
                        } else if viewModel.uiState.showSaveButtons {
                            // Show both edit and save buttons after user taps done
                            HStack(spacing: 60) {
                                // Edit button (pencil) - circular, transparent glass with purple icon
                                Button(action: { viewModel.toggleEditMode() }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 30, weight: .medium, design: .rounded))
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

                                // Save button - circular, filled purple with light purple checkmark - SAME SIZE as retake
                                Button(action: handleSave) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                }
                                .buttonStyle(.balliBordered(size: ResponsiveDesign.height(72)))
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
                    }
                }
            }
        }
        .alert("Doğrulama Hatası", isPresented: $showingValidationAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            VStack(alignment: .leading) {
                if !viewModel.uiState.validationErrors.isEmpty {
                    Text("Hatalar:")
                    ForEach(viewModel.uiState.validationErrors, id: \.self) { error in
                        Text("• \(error)")
                    }
                }
                if !viewModel.uiState.validationWarnings.isEmpty {
                    Text("\nUyarılar:")
                    ForEach(viewModel.uiState.validationWarnings, id: \.self) { warning in
                        Text("• \(warning)")
                    }
                }
            }
        }
        .onChange(of: viewModel.uiState.validationErrors) { _, newErrors in
            if !newErrors.isEmpty {
                showingValidationAlert = true
            }
        }
        .onAppear {
            handleViewAppear()
        }
    }
    
    // MARK: - Private Views


    
    // MARK: - Actions
    
    private func handleSave() {
        viewModel.saveFood(in: viewContext) {
            toastMessage = .success("Kaydedildi")
        }
    }
    
    private func handleBack() {
        // Always dismiss on back button
        dismiss()
    }

    // MARK: - Private Methods

    private func handleViewAppear() {
        // If we're in analysis mode, start the AI processing
        if viewModel.isAnalyzing {
            Task {
                await viewModel.startAnalysisProcessing()
            }
        }
    }
}

// MARK: - Previews

#Preview("Analysis In Progress") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    AIResultView(
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
        captureFlowManager: CaptureFlowManager(cameraManager: CameraManager())
    )
    .environment(\.managedObjectContext, persistenceController.viewContext)
}

#Preview("Post-Analysis Edit Button") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    // Shows edit (pencil) button after analysis completes
    AIResultView(
        nutritionResult: NutritionExtractionResult(
            productName: "Çikolatalı Gevrek",
            brandName: "Nestle",
            servingSize: NutritionServingSize(value: 30, unit: "g"),
            nutrients: ExtractedNutrients(
                calories: NutrientValue(value: 120, unit: "kcal"),
                totalCarbohydrates: NutrientValue(value: 20, unit: "g"),
                dietaryFiber: NutrientValue(value: 2.5, unit: "g"),
                sugars: NutrientValue(value: 12, unit: "g"),
                protein: NutrientValue(value: 2, unit: "g"),
                totalFat: NutrientValue(value: 1.5, unit: "g"),
                saturatedFat: NutrientValue(value: 0.5, unit: "g"),
                sodium: NutrientValue(value: 180, unit: "mg")
            ),
            metadata: ExtractionMetadata(
                confidence: 95,
                processingTime: "1.1s",
                modelVersion: "1.0"
            )
        ),
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
        simulatePostAnalysis: true
    )
    .environment(\.managedObjectContext, persistenceController.viewContext)
}

#Preview("Save Buttons State - Edit & Save") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    // Shows state after user completed editing - pencil (transparent) and checkmark (filled purple) buttons
    // Matches spacing and styling from AIPreviewView retake/use buttons
    AIResultView(
        nutritionResult: NutritionExtractionResult(
            productName: "Gummy Bears",
            brandName: "Haribo",
            servingSize: NutritionServingSize(value: 20, unit: "g"),
            nutrients: ExtractedNutrients(
                calories: NutrientValue(value: 70, unit: "kcal"),
                totalCarbohydrates: NutrientValue(value: 17, unit: "g"),
                dietaryFiber: NutrientValue(value: 0, unit: "g"),
                sugars: NutrientValue(value: 15, unit: "g"),
                protein: NutrientValue(value: 0, unit: "g"),
                totalFat: NutrientValue(value: 0, unit: "g"),
                saturatedFat: NutrientValue(value: 0, unit: "g"),
                sodium: NutrientValue(value: 5, unit: "mg")
            ),
            metadata: ExtractionMetadata(
                confidence: 98,
                processingTime: "0.8s",
                modelVersion: "1.0"
            )
        ),
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
        simulatePostAnalysis: false  // Shows save buttons state (after editing)
    )
    .environment(\.managedObjectContext, persistenceController.viewContext)
}

#Preview("Slider with Low Impact Banner") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    // Low impact food showing slider + top-right compact impact banner
    // Banner shows low impact while slider remains interactive for portion adjustments
    AIResultView(
        nutritionResult: NutritionExtractionResult(
            productName: "Badem",
            brandName: "Tariş",
            servingSize: NutritionServingSize(value: 28, unit: "g"),
            nutrients: ExtractedNutrients(
                calories: NutrientValue(value: 160, unit: "kcal"),
                totalCarbohydrates: NutrientValue(value: 6, unit: "g"),
                dietaryFiber: NutrientValue(value: 3.5, unit: "g"),
                sugars: NutrientValue(value: 1, unit: "g"),
                protein: NutrientValue(value: 6, unit: "g"),
                totalFat: NutrientValue(value: 14, unit: "g"),
                saturatedFat: NutrientValue(value: 1, unit: "g"),
                sodium: NutrientValue(value: 0, unit: "mg")
            ),
            metadata: ExtractionMetadata(
                confidence: 90,
                processingTime: "1.3s",
                modelVersion: "1.0"
            )
        ),
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage()
    )
    .environment(\.managedObjectContext, persistenceController.viewContext)
}

#Preview("Live Updates - Medium Impact") {
    @Previewable @State var persistenceController = Persistence.PersistenceController(inMemory: true)

    // Medium impact food demonstrating live banner updates with slider interaction
    // Shows how impact score changes in real-time as user adjusts portion size
    AIResultView(
        nutritionResult: NutritionExtractionResult(
            productName: "Granola Bar",
            brandName: "Nature Valley",
            servingSize: NutritionServingSize(value: 42, unit: "g"),
            nutrients: ExtractedNutrients(
                calories: NutrientValue(value: 190, unit: "kcal"),
                totalCarbohydrates: NutrientValue(value: 18, unit: "g"),
                dietaryFiber: NutrientValue(value: 3, unit: "g"),
                sugars: NutrientValue(value: 6, unit: "g"),
                protein: NutrientValue(value: 8, unit: "g"),
                totalFat: NutrientValue(value: 7, unit: "g"),
                saturatedFat: NutrientValue(value: 1, unit: "g"),
                sodium: NutrientValue(value: 160, unit: "mg")
            ),
            metadata: ExtractionMetadata(
                confidence: 93,
                processingTime: "1.0s",
                modelVersion: "1.0"
            )
        ),
        capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
        simulatePostAnalysis: false  // Shows final state with interactive slider and banner
    )
    .environment(\.managedObjectContext, persistenceController.viewContext)
}
