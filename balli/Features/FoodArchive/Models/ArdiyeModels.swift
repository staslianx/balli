//
//  ArdiyeModels.swift
//  balli
//
//  Data models for food archive (Ardiye) feature
//  Swift 6 strict concurrency compliant
//

import Foundation

struct ArdiyeItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let displayTitle: String
    let subtitle: String
    let totalCarbs: Double
    let servingSize: Double
    let servingUnit: String
    let isFavorite: Bool
    let isRecipe: Bool

    // Optional references to actual entities
    let recipe: Recipe?
    let foodItem: FoodItem?

    static func == (lhs: ArdiyeItem, rhs: ArdiyeItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ArdiyeFilter: String, CaseIterable {
    case recipes = "tarif"
    case products = "ürün"
}
