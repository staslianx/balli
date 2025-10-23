//
//  RecipeConstants.swift
//  balli
//
//  Recipe-related constants and configurations
//

import Foundation
import SwiftUI

// MARK: - Recipe Constants
public enum RecipeConstants {
    // MARK: - Default Values
    public enum Defaults {
        public static let servings: Int = 1
        public static let prepTime: String = "15"
        public static let cookTime: String = "30"
        public static let source: String = "manual"
        public static let nutritionConfidence: Double = 100.0
    }
    
    // MARK: - Validation
    enum Validation {
        static let minIngredients: Int = 1
        static let minDirections: Int = 1
        static let maxNameLength: Int = 100
        static let maxIngredientLength: Int = 200
        static let maxDirectionLength: Int = 500
        static let maxNotesLength: Int = 1000
    }
    
    // MARK: - UI Constants
    public enum UI {
        public static let scallopSize: CGFloat = 10
        public static let scallopWidth: CGFloat = 30
        public static let dashedLinePadding: CGFloat = 8
        public static let cardOuterCornerRadius: CGFloat = 30
        public static let dashPattern: [CGFloat] = [5, 3]
        public static let dashPhase: CGFloat = 0
        public static let strokeLineWidth: CGFloat = 2
        public static let borderStrokeWidth: CGFloat = 1
        
        // Font size multipliers for handwritten font
        public static let handwrittenTitleMultiplier: CGFloat = 1.3
        public static let handwrittenBodyMultiplier: CGFloat = 1.25
        public static let handwrittenLabelMultiplier: CGFloat = 1.2
        
        // Caveat font weight (400-700 range)
        public static let caveatMaxWeight: CGFloat = 700
        
        // Field widths
        public static let timeFieldWidth: CGFloat = 55
        public static let nutritionValueFieldWidth: CGFloat = 75
        public static let nutritionLabelWidth: CGFloat = 140
        public static let nutritionGapWidth: CGFloat = 20
        public static let nutritionUnitMinWidth: CGFloat = 30
        public static let nutritionUnitKcalWidth: CGFloat = 45
        
        // Button dimensions
        public static let circularButtonSize: CGFloat = 44
        public static let saveButtonWidth: CGFloat = 200
        public static let saveButtonHeight: CGFloat = 56
        
        // Animation durations
        public static let springResponse: TimeInterval = 0.3
        public static let springDampingFraction: CGFloat = 0.8
        public static let checkmarkDelay: TimeInterval = 1.0
        public static let streamAnimationDelay: TimeInterval = 0.05
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let recipeSource = "source"
        static let recipeMealType = "mealType"
        static let recipeStyleType = "styleType"
        static let isVerified = "isVerified"
        static let isFavorite = "isFavorite"
        static let timesCooked = "timesCooked"
    }
    
    // MARK: - Recipe Sources
    public enum Source {
        public static let manual = "manual"
        public static let ai = "ai"
        public static let imported = "imported"
    }
    
    // MARK: - Default Meal/Style Types
    public enum DefaultTypes {
        public static let customMeal = "Custom"
        public static let customStyle = "Custom"
        public static let manualHistory = "Manual"
    }
    
    // MARK: - Error Messages
    public enum ErrorMessages {
        public static let saveFailed = "Tarif kaydedilemedi"
        public static let nutritionValidationTitle = "Besin Değeri Hatası"
        public static let recipeNotFound = "Tarif Alınamadı"
    }
    
    // MARK: - Success Messages
    public enum SuccessMessages {
        public static let recipeSaved = "Tarif Kaydedildi"
        public static let recipeSavedDescription = "başarıyla kaydedildi."
    }
}

// MARK: - Preference Keys
public struct ViewHeightKey: PreferenceKey {
    public static let defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}