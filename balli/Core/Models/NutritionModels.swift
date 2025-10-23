//
//  NutritionModels.swift
//  balli
//
//  Nutrition extraction models for AI-based food label analysis
//

import Foundation



// MARK: - Nutrition Extraction Models

/// Individual nutrient value with unit and optional daily value percentage
public struct NutrientValue: Codable, Sendable, Equatable {
    public let value: Double
    public let unit: String
    public let dailyValue: Double?
    
    public init(value: Double, unit: String, dailyValue: Double? = nil) {
        self.value = value
        self.unit = unit
        self.dailyValue = dailyValue
    }
}

/// Serving size information
public struct NutritionServingSize: Codable, Sendable, Equatable {
    public let value: Double
    public let unit: String
    public let perContainer: Double?
    
    public init(value: Double, unit: String, perContainer: Double? = nil) {
        self.value = value
        self.unit = unit
        self.perContainer = perContainer
    }
}

/// All extracted nutrients from a food label
public struct ExtractedNutrients: Codable, Sendable, Equatable {
    public let calories: NutrientValue
    public let totalCarbohydrates: NutrientValue
    public let dietaryFiber: NutrientValue?
    public let sugars: NutrientValue?
    public let protein: NutrientValue
    public let totalFat: NutrientValue
    public let saturatedFat: NutrientValue?
    public let transFat: NutrientValue?
    public let cholesterol: NutrientValue?
    public let sodium: NutrientValue?
    public let addedSugars: NutrientValue?
    
    public init(
        calories: NutrientValue,
        totalCarbohydrates: NutrientValue,
        dietaryFiber: NutrientValue? = nil,
        sugars: NutrientValue? = nil,
        protein: NutrientValue,
        totalFat: NutrientValue,
        saturatedFat: NutrientValue? = nil,
        transFat: NutrientValue? = nil,
        cholesterol: NutrientValue? = nil,
        sodium: NutrientValue? = nil,
        addedSugars: NutrientValue? = nil
    ) {
        self.calories = calories
        self.totalCarbohydrates = totalCarbohydrates
        self.dietaryFiber = dietaryFiber
        self.sugars = sugars
        self.protein = protein
        self.totalFat = totalFat
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.cholesterol = cholesterol
        self.sodium = sodium
        self.addedSugars = addedSugars
    }
}

/// Metadata about the extraction process
public struct ExtractionMetadata: Codable, Sendable, Equatable {
    public let confidence: Double
    public let processingTime: String
    public let modelVersion: String
    public let warnings: [String]?
    public let detectedLanguage: String?

    public init(
        confidence: Double,
        processingTime: String,
        modelVersion: String,
        warnings: [String]? = nil,
        detectedLanguage: String? = nil
    ) {
        self.confidence = confidence
        self.processingTime = processingTime
        self.modelVersion = modelVersion
        self.warnings = warnings
        self.detectedLanguage = detectedLanguage
    }
}

/// Complete nutrition extraction result
public struct NutritionExtractionResult: Codable, Sendable, Equatable {
    public let productName: String?  // Made optional - API no longer returns this
    public let brandName: String?    // Already optional
    public let servingSize: NutritionServingSize
    public let nutrients: ExtractedNutrients
    public let metadata: ExtractionMetadata
    public let rawText: String?

    public init(
        productName: String? = nil,  // Default to nil for API compatibility
        brandName: String? = nil,
        servingSize: NutritionServingSize,
        nutrients: ExtractedNutrients,
        metadata: ExtractionMetadata,
        rawText: String? = nil
    ) {
        self.productName = productName
        self.brandName = brandName
        self.servingSize = servingSize
        self.nutrients = nutrients
        self.metadata = metadata
        self.rawText = rawText
    }
}

// MARK: - Ingredient Categories

/// Categories for shopping list items
public enum IngredientCategory: String, CaseIterable, Sendable {
    case meyve = "meyve"
    case sebze = "sebze"
    case sutUrunleri = "süt_ürünleri"
    case et = "et"
    case balik = "balık"
    case bakliyat = "bakliyat"
    case tahil = "tahıl"
    case konserve = "konserve"
    case baharat = "baharat"
    case icecek = "içecek"
    case atistirmalik = "atıştırmalık"
    case dondurulmus = "dondurulmuş"
    case temizlik = "temizlik"
    case kisiselBakim = "kişisel_bakım"
    case ekmek = "ekmek"
    case other = "diğer"
    
    var displayName: String {
        switch self {
        case .meyve: return "Meyve"
        case .sebze: return "Sebze"
        case .sutUrunleri: return "Süt Ürünleri"
        case .et: return "Et"
        case .balik: return "Balık"
        case .bakliyat: return "Bakliyat"
        case .tahil: return "Tahıl"
        case .konserve: return "Konserve"
        case .baharat: return "Baharat"
        case .icecek: return "İçecek"
        case .atistirmalik: return "Atıştırmalık"
        case .dondurulmus: return "Dondurulmuş"
        case .temizlik: return "Temizlik"
        case .kisiselBakim: return "Kişisel Bakım"
        case .ekmek: return "Ekmek"
        case .other: return "Diğer"
        }
    }
    
    var emoji: String {
        switch self {
        case .meyve: return "🍎"
        case .sebze: return "🥬"
        case .sutUrunleri: return "🥛"
        case .et: return "🥩"
        case .balik: return "🐟"
        case .bakliyat: return "🫘"
        case .tahil: return "🌾"
        case .konserve: return "🥫"
        case .baharat: return "🧂"
        case .icecek: return "🥤"
        case .atistirmalik: return "🍿"
        case .dondurulmus: return "🧊"
        case .temizlik: return "🧹"
        case .kisiselBakim: return "🧴"
        case .ekmek: return "🍞"
        case .other: return "📦"
        }
    }
    
    var color: String {
        switch self {
        case .meyve: return "#FF6B6B"
        case .sebze: return "#51CF66"
        case .sutUrunleri: return "#339AF0"
        case .et: return "#FF8787"
        case .balik: return "#4DABF7"
        case .bakliyat: return "#9775FA"
        case .tahil: return "#FAB005"
        case .konserve: return "#FD7E14"
        case .baharat: return "#AE3EC9"
        case .icecek: return "#099268"
        case .atistirmalik: return "#F76707"
        case .dondurulmus: return "#74C0FC"
        case .temizlik: return "#495057"
        case .kisiselBakim: return "#D0BFFF"
        case .ekmek: return "#FFD43B"
        case .other: return "#868E96"
        }
    }
}