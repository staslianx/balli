//
//  ParsedIngredientExtensions.swift
//  balli
//
//  Extensions for ParsedIngredient to work with Local Functions
//

import Foundation

// MARK: - ParsedIngredient Extensions for Local

extension ParsedIngredient {
    
    /// Alternative initializer for Local Functions compatibility
    public init(
        originalText: String,
        name: String,
        quantity: String?,
        unit: String,
        note: String?,
        category: IngredientCategory
    ) {
        // Parse quantity from string to double
        let quantityValue: Double
        if let quantityStr = quantity {
            // Try to parse various formats: "2", "2.5", "1/2", etc.
            if let parsed = Double(quantityStr) {
                quantityValue = parsed
            } else if quantityStr.contains("/") {
                // Handle fractions like "1/2"
                let parts = quantityStr.split(separator: "/")
                if parts.count == 2,
                   let numerator = Double(parts[0]),
                   let denominator = Double(parts[1]),
                   denominator != 0 {
                    quantityValue = numerator / denominator
                } else {
                    quantityValue = 1.0
                }
            } else {
                // Try to extract number from string like "2 adet"
                let scanner = Scanner(string: quantityStr)
                if let number = scanner.scanDouble() {
                    quantityValue = number
                } else {
                    quantityValue = 1.0
                }
            }
        } else {
            quantityValue = 1.0
        }
        
        // Format display quantity
        let displayQty: String
        if unit == "adet" {
            displayQty = "x\(Int(quantityValue))"
        } else {
            displayQty = quantity ?? "1 \(unit)"
        }
        
        // Initialize with proper values
        self.init(
            name: note != nil ? "\(name) (\(note!))" : name,
            quantity: quantityValue,
            unit: unit,
            displayQuantity: displayQty,
            category: category.rawValue,
            confidence: 0.9  // Default confidence for Local results
        )
    }
}

// MARK: - Array Extensions

extension Array where Element == ParsedIngredient {
    
    /// Convert parsed ingredients to shopping list format for display
    public func toShoppingListFormat() -> [(category: String, items: [ParsedIngredient])] {
        // Group by category
        let grouped = Dictionary(grouping: self) { $0.category }
        
        // Sort categories and items
        return grouped
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
    }
    
    /// Merge duplicate items by combining quantities
    public func mergeDuplicates() -> [ParsedIngredient] {
        var merged: [String: ParsedIngredient] = [:]
        
        for item in self {
            let key = "\(item.name)_\(item.unit)"
            if let existing = merged[key] {
                // Combine quantities
                let newQuantity = existing.quantity + item.quantity
                let newDisplayQuantity = item.unit == "adet" 
                    ? "x\(Int(newQuantity))" 
                    : "\(newQuantity) \(item.unit)"
                
                merged[key] = ParsedIngredient(
                    name: item.name,
                    quantity: newQuantity,
                    unit: item.unit,
                    displayQuantity: newDisplayQuantity,
                    category: item.category,
                    confidence: Swift.max(existing.confidence, item.confidence)
                )
            } else {
                merged[key] = item
            }
        }
        
        return Array(merged.values).sorted { $0.name < $1.name }
    }
}