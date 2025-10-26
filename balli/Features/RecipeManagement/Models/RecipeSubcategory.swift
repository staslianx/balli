//
//  RecipeSubcategory.swift
//  balli
//
//  Created by Claude Code
//  Recipe memory system - Defines 9 independent meal subcategories with memory limits
//

import Foundation

/// Represents the 7 independent meal subcategories for recipe memory tracking
/// Each subcategory maintains its own memory pool to prevent false positives between contextually different meals
/// Categories with subcategories: Salatalar (2), Akşam Yemeği (2), Tatlılar (3)
/// Categories without subcategories: Kahvaltı, Atıştırmalık (use parent category as subcategory)
enum RecipeSubcategory: String, Codable, CaseIterable, Sendable {
    // Top-level categories (no subcategories)
    case kahvalti = "Kahvaltı"
    case atistirmalik = "Atıştırmalık"

    // Salatalar subcategories
    case doyurucuSalata = "Doyurucu Salata"
    case hafifSalata = "Hafif Salata"

    // Akşam Yemeği subcategories
    case karbonhidratProtein = "Karbonhidrat ve Protein Uyumu"
    case tamBugdayMakarna = "Tam Buğday Makarna"

    // Tatlılar subcategories
    case sanaOzelTatlilar = "Sana Özel Tatlılar"
    case dondurma = "Dondurma"
    case meyveSalatasi = "Meyve Salatası"

    /// Maximum number of recipes to store in memory for this subcategory
    /// Limits are based on realistic variety potential for diabetes-friendly recipes
    var memoryLimit: Int {
        switch self {
        case .kahvalti:
            return 25  // Limited breakfast options
        case .atistirmalik:
            return 20  // Moderate variety for healthy snacks
        case .doyurucuSalata:
            return 30  // High variety with protein + vegetable combos
        case .hafifSalata:
            return 20  // Simpler compositions
        case .karbonhidratProtein:
            return 30  // Main dinners require maximum variety
        case .tamBugdayMakarna:
            return 25  // Decent variety with different sauces/proteins
        case .sanaOzelTatlilar:
            return 15  // Diabetes-friendly desserts inherently limited
        case .dondurma:
            return 10  // Very limited for diabetes-friendly ice cream
        case .meyveSalatasi:
            return 10  // Limited fruit combinations for diabetes
        }
    }

    /// Parent category for UI grouping (informational only, not used for memory)
    var parentCategory: String {
        switch self {
        case .kahvalti:
            return "Kahvaltı"
        case .atistirmalik:
            return "Atıştırmalık"
        case .doyurucuSalata, .hafifSalata:
            return "Salatalar"
        case .karbonhidratProtein, .tamBugdayMakarna:
            return "Akşam yemeği"
        case .sanaOzelTatlilar, .dondurma, .meyveSalatasi:
            return "Tatlılar"
        }
    }

    /// User-friendly display name (matches raw value)
    var displayName: String {
        return self.rawValue
    }

    /// Context description for recipe generation prompts
    var contextDescription: String {
        switch self {
        case .kahvalti:
            return "Diyabet dostu kahvaltı"
        case .atistirmalik:
            return "Sağlıklı atıştırmalıklar"
        case .doyurucuSalata:
            return "Protein içeren ana yemek olarak servis edilen doyurucu bir salata"
        case .hafifSalata:
            return "Yan yemek olarak servis edilen hafif bir salata"
        case .karbonhidratProtein:
            return "Dengeli karbonhidrat ve protein kombinasyonu içeren akşam yemeği"
        case .tamBugdayMakarna:
            return "Tam buğday makarna çeşitleri"
        case .sanaOzelTatlilar:
            return "Diyabet dostu tatlı versiyonları"
        case .dondurma:
            return "Ninja Creami makinesi için diyabet dostu dondurma"
        case .meyveSalatasi:
            return "Diyabet yönetimine uygun meyve salatası"
        }
    }
}

// MARK: - Convenience Extensions

extension RecipeSubcategory {
    /// Initialize from Turkish string (case-insensitive)
    init?(turkishName: String) {
        guard let match = Self.allCases.first(where: { $0.rawValue.lowercased() == turkishName.lowercased() }) else {
            return nil
        }
        self = match
    }

    /// Get all subcategories grouped by parent category
    static var groupedByParent: [String: [RecipeSubcategory]] {
        Dictionary(grouping: Self.allCases, by: { $0.parentCategory })
    }
}
