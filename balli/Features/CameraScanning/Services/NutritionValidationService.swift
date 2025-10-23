//
//  NutritionValidationService.swift
//  balli
//
//  Service for validating nutrition form data
//

import Foundation

/// Result of nutrition validation
struct NutritionValidationResult: Sendable {
    let errors: [String]
    let warnings: [String]
    var isValid: Bool { errors.isEmpty }
}

/// Service for validating nutrition form data
actor NutritionValidationService {

    /// Validate nutrition form data
    func validate(_ formState: NutritionFormState) -> NutritionValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Check for required fields
        if formState.carbohydrates.isEmpty {
            errors.append("Karbonhidrat değeri gerekli")
        }

        // Check numeric validity
        if let carbValue = Double(formState.carbohydrates), carbValue < 0 {
            errors.append("Karbonhidrat değeri negatif olamaz")
        }

        // Check fiber vs carbs relationship
        if let fiberValue = Double(formState.fiber),
           let carbValue = Double(formState.carbohydrates),
           fiberValue > carbValue {
            warnings.append("Lif değeri toplam karbonhidrattan fazla")
        }

        // Check confidence warnings
        if formState.carbsConfidence < 50 {
            warnings.append("Karbonhidrat değeri çok belirsiz")
        } else if formState.carbsConfidence < 80 {
            warnings.append("Karbonhidrat değerini kontrol edin")
        }

        return NutritionValidationResult(errors: errors, warnings: warnings)
    }
}
