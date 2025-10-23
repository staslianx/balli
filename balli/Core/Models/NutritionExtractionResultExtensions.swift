//
//  NutritionExtractionResultExtensions.swift
//  balli
//
//  Extensions for NutritionExtractionResult with helper methods
//

import Foundation

// MARK: - NutritionExtractionResult Extensions

extension NutritionExtractionResult {
    
    /// Determines if the result needs manual review based on confidence
    var needsManualReview: Bool {
        return metadata.confidence < 80
    }
    
    /// Gets the confidence level category
    func getConfidenceLevel() -> ConfidenceLevel {
        switch metadata.confidence {
        case 80...100:
            return .high
        case 60..<80:
            return .medium
        default:
            return .low
        }
    }
    
    /// Gets review suggestions based on confidence and warnings
    func getReviewSuggestions() -> [String] {
        var suggestions: [String] = []
        
        // Add suggestions based on confidence level
        if metadata.confidence < 50 {
            suggestions.append("Düşük güven seviyesi: Besin değerlerini manuel olarak kontrol edin")
        } else if metadata.confidence < 80 {
            suggestions.append("Orta güven seviyesi: Kritik değerleri gözden geçirin")
        }
        
        // Add any warnings from metadata
        if let warnings = metadata.warnings {
            suggestions.append(contentsOf: warnings)
        }
        
        // Add specific nutrient suggestions
        if let fiber = nutrients.dietaryFiber, fiber.value == 0 {
            suggestions.append("Lif değeri 0 görünüyor, ürün etiketini kontrol edin")
        }
        
        if nutrients.calories.value > 1000 {
            suggestions.append("Yüksek kalori değeri tespit edildi, porsiyon boyutunu kontrol edin")
        }
        
        return suggestions
    }
    
    /// Validates the nutrition data for common issues
    func validate() -> (errors: [String], warnings: [String]) {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check for required values
        if let productName = productName, productName.isEmpty {
            errors.append("Ürün adı eksik")
        }
        
        if servingSize.value <= 0 {
            errors.append("Geçersiz porsiyon boyutu")
        }
        
        // Check for logical consistency
        _ = nutrients.totalCarbohydrates.value + nutrients.protein.value + nutrients.totalFat.value
        let expectedCalories = (nutrients.totalCarbohydrates.value * 4) + (nutrients.protein.value * 4) + (nutrients.totalFat.value * 9)
        
        if abs(expectedCalories - nutrients.calories.value) > 50 {
            warnings.append("Kalori değeri makro besinlerle tutarsız görünüyor")
        }
        
        // Check for unusual values
        if nutrients.calories.value > 900 {
            warnings.append("100g için yüksek kalori değeri")
        }
        
        if let sugar = nutrients.sugars, sugar.value > nutrients.totalCarbohydrates.value {
            errors.append("Şeker miktarı toplam karbonhidrattan fazla olamaz")
        }
        
        if let saturatedFat = nutrients.saturatedFat, saturatedFat.value > nutrients.totalFat.value {
            errors.append("Doymuş yağ miktarı toplam yağdan fazla olamaz")
        }
        
        return (errors, warnings)
    }
    
    /// Creates a summary text for sharing
    func createSummaryText() -> String {
        var summary = "📊 \(productName ?? "Besin Etiketi")"
        if let brand = brandName {
            summary += " - \(brand)"
        }
        summary += "\n"
        summary += "Porsiyon: \(Int(servingSize.value))\(servingSize.unit)\n\n"
        summary += "Besin Değerleri:\n"
        summary += "• Kalori: \(Int(nutrients.calories.value)) \(nutrients.calories.unit)\n"
        summary += "• Karbonhidrat: \(nutrients.totalCarbohydrates.value)g\n"
        summary += "• Protein: \(nutrients.protein.value)g\n"
        summary += "• Yağ: \(nutrients.totalFat.value)g\n"
        
        if let fiber = nutrients.dietaryFiber {
            summary += "• Lif: \(fiber.value)g\n"
        }
        
        if let sugar = nutrients.sugars {
            summary += "• Şeker: \(sugar.value)g\n"
        }
        
        return summary
    }
}