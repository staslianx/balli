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
    
    @State private var showingSaveConfirmation = false
    @State private var isSaveInProgress = false // Prevent duplicate saves
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.appBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack {
                        Spacer(minLength: ResponsiveDesign.height(50))
                        
                        // Food label container - exact same positioning as camera guide
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
                            showIcon: true,
                            iconName: "hand.rays.fill",
                            iconColor: .primary
                        )
                        
                        Spacer(minLength: ResponsiveDesign.height(50))
                        
                        // Bottom controls
                        Button(action: saveFood) {
                            Text("Kaydet")
                                .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: ResponsiveDesign.width(180))
                                .frame(height: ResponsiveDesign.height(56))
                                .background(AppTheme.adaptiveBalliGradient(for: colorScheme))
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primaryPurple.opacity(0.3), radius: ResponsiveDesign.height(4), x: 0, y: ResponsiveDesign.height(2))
                        }
                        .padding(.bottom, ResponsiveDesign.height(30))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
        .alert("Ardiye'ye Kaydedildi", isPresented: $showingSaveConfirmation) {
            Button("Tamam") {
                dismiss()
            }
        } message: {
            Text("\(productName.isEmpty ? "Ürün" : productName) başarıyla Ardiye'ye kaydedildi.")
        }
    }
    
    private func saveFood() {
        // Prevent multiple saves
        guard !isSaveInProgress else {
            logger.debug("Save already in progress, ignoring duplicate request")
            return
        }
        isSaveInProgress = true
        
        // Create FoodItem in Core Data
        let foodItem = FoodItem(context: viewContext)
        foodItem.id = UUID()
        foodItem.name = productName.isEmpty ? "Bilinmeyen Ürün" : productName
        foodItem.brand = productBrand.isEmpty ? nil : productBrand
        
        // Store the user's selected serving size
        foodItem.servingSize = portionGrams
        foodItem.servingUnit = "g"
        
        // Calculate adjusted values based on portion
        let baseServing = Double(servingSize) ?? 100.0
        let adjustmentRatio = portionGrams / baseServing
        
        // Save adjusted values based on the selected portion
        foodItem.calories = (Double(calories) ?? 0) * adjustmentRatio
        foodItem.totalCarbs = (Double(carbohydrates) ?? 0) * adjustmentRatio
        foodItem.fiber = (Double(fiber) ?? 0) * adjustmentRatio
        foodItem.sugars = (Double(sugars) ?? 0) * adjustmentRatio
        foodItem.protein = (Double(protein) ?? 0) * adjustmentRatio
        foodItem.totalFat = (Double(fat) ?? 0) * adjustmentRatio
        foodItem.sodium = 0 // Not collected in manual entry
        
        foodItem.source = "manual_entry"
        foodItem.dateAdded = Date()
        foodItem.lastModified = Date()
        
        // Set high confidence for manual entry
        foodItem.carbsConfidence = 100.0
        foodItem.overallConfidence = 100.0
        
        do {
            try viewContext.save()
            showingSaveConfirmation = true
            
            // Reset the form after successful save
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                productBrand = ""
                productName = ""
                calories = ""
                servingSize = "100"  // Keep base as 100g
                carbohydrates = ""
                fiber = ""
                sugars = ""
                protein = ""
                fat = ""
                portionGrams = 100.0
                isSaveInProgress = false // Reset save state
            }
        } catch {
            logger.error("Failed to save FoodItem: \(error.localizedDescription)")
            isSaveInProgress = false // Reset save state on error
            // Could add error alert here
        }
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
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
