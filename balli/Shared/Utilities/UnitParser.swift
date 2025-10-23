//
//  UnitParser.swift
//  balli
//
//  Handles unit classification and formatting for ingredient parsing
//

import Foundation

public actor UnitParser: UnitParsing {
    
    // MARK: - Unit Classification System
    
    private let weightUnits: [String] = ["kilo", "kg", "kilogram", "gram", "gr", "g"]
    private let volumeUnits: [String] = ["litre", "lt", "l", "ml", "mililitre", "cc"]
    private let countUnits: [String] = ["adet", "tane", "parça", "dilim", "paket", "kutu", "şişe", "torba", "düzine", "kalıp", "blok"]
    private let approxUnits: [String] = ["avuç", "tutam", "çimdik", "dal", "sap", "yaprak", "demet"]

    // Kitchen measurement units
    private let kitchenUnits: [String] = [
        "yemek kaşığı", "yk", "çorba kaşığı", "çk",
        "tatlı kaşığı", "tk", "çay kaşığı", "çk",
        "su bardağı", "sb", "çay bardağı", "bardak",
        "fincan", "kase", "tabak"
    ]
    
    public init() {}
    
    // MARK: - Unit Classification
    
    public func classifyUnit(_ word: String) async -> String? {
        if weightUnits.contains(word) {
            return await mapWeightUnit(word)
        }
        if volumeUnits.contains(word) {
            return await mapVolumeUnit(word)
        }
        if countUnits.contains(word) {
            return "adet"
        }
        if approxUnits.contains(word) {
            return word // Keep approximate units as-is
        }
        if kitchenUnits.contains(word) {
            return word // Keep kitchen units as-is for recipe display
        }
        return nil
    }
    
    // MARK: - Unit Mapping
    
    public func mapWeightUnit(_ unit: String) async -> String {
        switch unit {
        case "kilo", "kg", "kilogram": return "kg"
        case "gram", "gr", "g": return "g"
        default: return "kg"
        }
    }
    
    public func mapVolumeUnit(_ unit: String) async -> String {
        switch unit {
        case "litre", "lt", "l": return "L"
        case "ml", "mililitre", "cc": return "mL"
        default: return "L"
        }
    }
    
    // MARK: - Display Formatting
    
    public func formatDisplayQuantity(_ quantity: Double, _ unit: String) async -> String {
        // More contextual quantity display
        if unit == "adet" {
            // Show "2 adet" instead of "x2"
            return "\(Int(quantity)) adet"
        }
        
        // For weight units, use shorter forms
        if unit == "kg" {
            if quantity == Double(Int(quantity)) {
                return "\(Int(quantity)) kg"
            } else {
                return String(format: "%.1f kg", quantity)
            }
        }
        
        // For volume units
        if unit == "L" {
            if quantity == Double(Int(quantity)) {
                return "\(Int(quantity)) L"
            } else {
                return String(format: "%.1f L", quantity)
            }
        }
        
        if unit == "mL" {
            return "\(Int(quantity)) mL"
        }
        
        // For grams
        if unit == "g" {
            return "\(Int(quantity)) g"
        }
        
        // For approximate units, keep as-is with quantity
        if approxUnits.contains(unit) {
            if quantity == 1 {
                return "1 \(unit)"
            } else {
                return "\(Int(quantity)) \(unit)"
            }
        }
        
        // Default case - show quantity with unit
        if quantity == Double(Int(quantity)) {
            return "\(Int(quantity)) \(unit)"
        } else {
            return String(format: "%.1f \(unit)", quantity)
        }
    }
    
    // MARK: - Helper Methods
    
    public func isWeightUnit(_ word: String) -> Bool {
        return weightUnits.contains(word.lowercased())
    }
    
    public func isVolumeUnit(_ word: String) -> Bool {
        return volumeUnits.contains(word.lowercased())
    }
    
    public func isCountUnit(_ word: String) -> Bool {
        return countUnits.contains(word.lowercased())
    }
    
    public func isApproximateUnit(_ word: String) -> Bool {
        return approxUnits.contains(word.lowercased())
    }
    
    public func isAnyUnit(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        return isWeightUnit(lowercased) || isVolumeUnit(lowercased) || 
               isCountUnit(lowercased) || isApproximateUnit(lowercased)
    }
}