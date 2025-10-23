//
//  RecentRecipe.swift
//  balli
//
//  Lightweight model for tracking recent recipe history for diversity
//  Stores only essential info needed to avoid repetitive suggestions
//  Scoped by (mealType, styleType) combination
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Lightweight model for recipe diversity tracking
/// Tracks last 25 recipes per (mealType, styleType) combination
public struct RecentRecipe: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let mainIngredient: String
    public let cookingMethod: String
    public let mealType: String
    public let styleType: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        mainIngredient: String,
        cookingMethod: String,
        mealType: String,
        styleType: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.mainIngredient = mainIngredient
        self.cookingMethod = cookingMethod
        self.mealType = mealType
        self.styleType = styleType
        self.createdAt = createdAt
    }

    /// Create a category key for storage grouping
    public var categoryKey: String {
        return "\(mealType):\(styleType)"
    }

    /// Display format for debugging
    public var displayString: String {
        return "[\(categoryKey)] \(title) - \(mainIngredient), \(cookingMethod)"
    }
}
