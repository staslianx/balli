//
//  IngredientParser.swift
//  balli
//
//  Coordinator for advanced Turkish NLP ingredient parsing with quantity extraction
//

import Foundation
import CoreData

// MARK: - Parsed Ingredient Result

public struct ParsedIngredient: Sendable, Identifiable {
    public let id = UUID()
    public let name: String
    public let quantity: Double
    public let unit: String
    public let displayQuantity: String
    public let category: String
    public let confidence: Double
    
    public init(name: String, quantity: Double = 1.0, unit: String = "adet", 
                displayQuantity: String? = nil, category: String = "genel", 
                confidence: Double = 1.0) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.displayQuantity = displayQuantity ?? (unit == "adet" ? "x\(Int(quantity))" : "\(quantity) \(unit)")
        self.category = category
        self.confidence = confidence
    }
}

// MARK: - Ingredient Parser Coordinator

public actor IngredientParser {
    
    // MARK: - Component Parsers
    
    private let quantityParser: QuantityParser
    private let unitParser: UnitParser
    private let extractor: IngredientExtractor
    
    // MARK: - Initialization
    
    public init() {
        self.quantityParser = QuantityParser()
        self.unitParser = UnitParser()
        self.extractor = IngredientExtractor()
    }
    
    // MARK: - Main Parsing Function
    
    public func parseIngredients(from text: String) async -> [ParsedIngredient] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanText.isEmpty else { return [] }
        
        // Use extractor for intelligent text splitting
        let items = await extractor.splitIntelligently(cleanText)
        
        // Parse each segment
        var results: [ParsedIngredient] = []
        for item in items {
            if let parsed = await parseSegment(item) {
                results.append(parsed)
            }
        }
        
        return results
    }
    
    // MARK: - Segment Parsing
    
    private func parseSegment(_ segment: String) async -> ParsedIngredient? {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Extract quantity and remaining words
        let extractResult = await quantityParser.extractQuantity(from: trimmed)
        
        // Build name from remaining words
        let name = extractResult.remainingWords.isEmpty ? 
                   trimmed : extractResult.remainingWords.joined(separator: " ")
        
        // Get category from extractor
        let category = await extractor.categorizeIngredient(name)
        
        // Calculate confidence
        let confidence = await extractor.calculateConfidence(
            original: trimmed,
            name: name,
            quantity: extractResult.quantity,
            unit: extractResult.unit
        )
        
        // Format display quantity
        let displayQuantity = await unitParser.formatDisplayQuantity(
            extractResult.quantity, 
            extractResult.unit
        )
        
        return ParsedIngredient(
            name: name.capitalized,
            quantity: extractResult.quantity,
            unit: extractResult.unit,
            displayQuantity: displayQuantity,
            category: category,
            confidence: confidence
        )
    }
}

// MARK: - Core Data Integration

extension IngredientParser {
    
    /// Create ShoppingListItem entities from parsed ingredients
    public func createShoppingItems(
        from ingredients: [ParsedIngredient],
        in context: NSManagedObjectContext
    ) -> [ShoppingListItem] {
        return ingredients.map { ingredient in
            // Only set notes if confidence is low enough to warrant a warning
            let notes = ingredient.confidence < 0.7 ?
                       "Güven: \(Int(ingredient.confidence * 100))%" : nil

            let item = ShoppingListItem.create(
                name: ingredient.name,
                category: mapCategoryToShoppingCategory(ingredient.category),
                quantity: ingredient.displayQuantity,
                notes: notes,
                in: context
            )

            return item
        }
    }
    
    private func mapCategoryToShoppingCategory(_ category: String) -> String {
        // Map parsed categories to Core Data shopping categories
        switch category {
        case "meyve_sebze": 
            return "Meyve & Sebze"
        case "et_tavuk_balık": 
            return "Et & Balık"
        case "süt_ürünleri": 
            return "Süt Ürünleri"
        case "ekmek": 
            return "Tahıl & Ekmek"
        case "içecek": 
            return "İçecek"
        case "temizlik": 
            return "Temizlik"
        case "atıştırmalık": 
            return "Atıştırmalık"
        default: 
            return "Genel"
        }
    }
}