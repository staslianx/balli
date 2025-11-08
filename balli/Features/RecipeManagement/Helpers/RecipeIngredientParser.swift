//
//  RecipeIngredientParser.swift
//  balli
//
//  Specialized parser for recipe ingredients with Turkish kitchen measurements
//

import Foundation
import CoreData

// MARK: - Recipe Parsed Ingredient
public struct RecipeParsedIngredient: Sendable, Identifiable {
    public let id = UUID()
    public let name: String
    public let quantity: String
    public let unit: String
    public let originalText: String
    
    public init(name: String, quantity: String, unit: String, originalText: String) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.originalText = originalText
    }
}

// MARK: - Recipe Ingredient Parser
@MainActor
public class RecipeIngredientParser {
    
    // MARK: - Turkish Kitchen Units
    private let kitchenUnits = [
        // Spoon measurements
        "yemek kaşığı", "yk", "çorba kaşığı", "çk",
        "tatlı kaşığı", "tk", "çay kaşığı",
        
        // Glass/Cup measurements  
        "su bardağı", "sb", "çay bardağı", "bardak",
        "fincan", "kase",
        
        // Handful measurements
        "avuç", "tutam", "çimdik", "dal", "sap", "yaprak",
        
        // Slice/Piece measurements
        "dilim", "parça", "kalıp", "blok", "küp",
        
        // Standard measurements
        "adet", "tane", "paket", "kutu", "şişe", "kavanoz",
        "kilo", "kilogram", "kg", "gram", "gr", "g",
        "litre", "lt", "l", "mililitre", "ml", "cc",
        
        // Fractions
        "yarım", "çeyrek", "buçuk"
    ]
    
    // MARK: - Parse Recipe Ingredients
    public func parseRecipeIngredients(_ ingredients: [String]) -> [RecipeParsedIngredient] {
        return ingredients.compactMap { parseIngredient($0) }
    }
    
    // MARK: - Parse Single Ingredient
    private func parseIngredient(_ text: String) -> RecipeParsedIngredient? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Pattern 1: "2 yemek kaşığı zeytinyağı" or "1 su bardağı süt"
        // Pattern 2: "150 gram çilek" or "2 adet yumurta"
        // Pattern 3: "Yarım su bardağı un" or "1-2 çorba kaşığı stevia"
        // Pattern 4: "Bir tutam tuz" or "Az miktar karabiber"
        
        let components = extractComponents(from: trimmed)
        
        return RecipeParsedIngredient(
            name: components.name,
            quantity: components.quantity,
            unit: components.unit,
            originalText: trimmed
        )
    }
    
    // MARK: - Component Extraction
    private func extractComponents(from text: String) -> (name: String, quantity: String, unit: String) {
        let lowercased = text.lowercased()
        let words = lowercased.split(separator: " ").map(String.init)
        
        var quantity = ""
        var unit = ""
        var nameWords: [String] = []
        var skipNext = false
        
        for (index, word) in words.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            
            // Check if this is a quantity
            if index == 0 {
                if isQuantity(word) {
                    quantity = word
                    
                    // Check for range (e.g., "1-2")
                    if index + 1 < words.count && words[index + 1] == "-" && index + 2 < words.count {
                        quantity = "\(word)-\(words[index + 2])"
                        skipNext = true
                    }
                    continue
                } else if isFraction(word) {
                    quantity = word
                    continue
                } else if word == "bir" || word == "az" {
                    quantity = word
                    continue
                }
            }
            
            // Check for compound units (e.g., "yemek kaşığı", "su bardağı")
            if index < words.count - 1 {
                let compound = "\(word) \(words[index + 1])"
                if kitchenUnits.contains(compound) {
                    unit = compound
                    skipNext = true
                    continue
                }
            }
            
            // Check for single word units
            if kitchenUnits.contains(word) {
                unit = word
                continue
            }
            
            // Everything else is part of the name
            nameWords.append(word)
        }
        
        // Format the extracted components
        let finalName = nameWords.joined(separator: " ").capitalized
        let finalQuantity = quantity.isEmpty ? "1" : quantity
        let finalUnit = unit.isEmpty ? "adet" : unit
        
        return (name: finalName, quantity: finalQuantity, unit: finalUnit)
    }
    
    // MARK: - Helper Methods
    private func isQuantity(_ word: String) -> Bool {
        // Check if it's a number
        if Double(word) != nil { return true }
        
        // Check for number ranges
        if word.contains("-") {
            let parts = word.split(separator: "-")
            if parts.count == 2 {
                return Double(parts[0]) != nil && Double(parts[1]) != nil
            }
        }
        
        return false
    }
    
    private func isFraction(_ word: String) -> Bool {
        let fractions = ["yarım", "çeyrek", "buçuk", "üçte", "dörtte"]
        return fractions.contains(word)
    }
    
    // MARK: - Create Shopping Items from Recipe
    public func createRecipeShoppingItems(
        from ingredients: [RecipeParsedIngredient],
        recipeName: String,
        recipeId: UUID,
        in context: NSManagedObjectContext
    ) -> [ShoppingListItem] {
        return ingredients.map { ingredient in
            let item = ShoppingListItem(context: context)
            item.id = UUID()
            item.name = ingredient.name
            item.quantity = "\(ingredient.quantity) \(ingredient.unit)"
            item.measurementUnit = ingredient.unit
            item.recipeName = recipeName
            item.recipeId = recipeId
            item.isFromRecipe = true
            item.dateCreated = Date()
            item.lastModified = Date()
            item.isCompleted = false
            item.sortOrder = 0
            item.category = categorizeIngredient(ingredient.name)
            
            return item
        }
    }
    
    // MARK: - Categorization
    private func categorizeIngredient(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Meat & Protein
        if lowercased.contains("tavuk") || lowercased.contains("et") || 
           lowercased.contains("kıyma") || lowercased.contains("balık") ||
           lowercased.contains("yumurta") {
            return "Et ve Protein"
        }
        
        // Dairy
        if lowercased.contains("süt") || lowercased.contains("yoğurt") ||
           lowercased.contains("peynir") || lowercased.contains("ayran") ||
           lowercased.contains("tereyağı") {
            return "Süt Ürünleri"
        }
        
        // Vegetables
        if lowercased.contains("domates") || lowercased.contains("salatalık") ||
           lowercased.contains("biber") || lowercased.contains("soğan") ||
           lowercased.contains("sarımsak") || lowercased.contains("patlıcan") {
            return "Sebzeler"
        }
        
        // Fruits
        if lowercased.contains("elma") || lowercased.contains("portakal") ||
           lowercased.contains("muz") || lowercased.contains("çilek") ||
           lowercased.contains("üzüm") {
            return "Meyveler"
        }
        
        // Grains
        if lowercased.contains("un") || lowercased.contains("makarna") ||
           lowercased.contains("pirinç") || lowercased.contains("bulgur") ||
           lowercased.contains("ekmek") {
            return "Tahıllar"
        }
        
        // Spices
        if lowercased.contains("tuz") || lowercased.contains("karabiber") ||
           lowercased.contains("kimyon") || lowercased.contains("kekik") ||
           lowercased.contains("nane") || lowercased.contains("baharat") {
            return "Baharatlar"
        }
        
        // Oils
        if lowercased.contains("yağ") || lowercased.contains("zeytinyağı") {
            return "Yağlar"
        }
        
        return "Genel"
    }
}