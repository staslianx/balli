//
//  ParserProtocols.swift
//  balli
//
//  Protocol definitions for ingredient parsing components
//

import Foundation

// MARK: - Quantity Parser Protocol

public protocol QuantityParsing: Sendable {
    /// Parse complex Turkish number patterns from text
    func parseComplexNumber(startingAt index: Int, in words: [String]) async -> (value: Double, nextIndex: Int)?
    
    /// Extract quantity and unit from text segment
    func extractQuantity(from text: String) async -> (quantity: Double, unit: String, remainingWords: [String])
    
    /// Check if a word starts a quantity pattern
    func isQuantityStart(_ word: String, at index: Int, in words: [String]) async -> Bool
}

// MARK: - Unit Parser Protocol

public protocol UnitParsing: Sendable {
    /// Classify a word as a unit type
    func classifyUnit(_ word: String) async -> String?
    
    /// Map weight units to standard forms
    func mapWeightUnit(_ unit: String) async -> String
    
    /// Map volume units to standard forms
    func mapVolumeUnit(_ unit: String) async -> String
    
    /// Format display quantity based on unit
    func formatDisplayQuantity(_ quantity: Double, _ unit: String) async -> String
}

// MARK: - Ingredient Extractor Protocol

public protocol IngredientExtracting: Sendable {
    /// Split text intelligently into ingredient segments
    func splitIntelligently(_ text: String) async -> [String]
    
    /// Categorize an ingredient by name
    func categorizeIngredient(_ name: String) async -> String
    
    /// Calculate confidence score for parsed result
    func calculateConfidence(original: String, name: String, quantity: Double, unit: String) async -> Double
    
    /// Check if a word likely ends a food item name
    func isLikelyFoodItemEnd(_ word: String) async -> Bool
}