//
//  StorageModels.swift
//  balli
//
//  Storage data models with Sendable conformance for Swift 6
//

import Foundation
// Note: External storage integration pending new implementation

// MARK: - User Profile

struct StorageUserProfile: Codable, Sendable {
    let userId: String
    let systemPrompt: String
    let pinnedFacts: [String]
    let createdAt: Date
    let updatedAt: Date
    let monthlyTokenUsage: Int
    let monthlyRequestCount: Int
    // Additional fields for diabetes management
    var diabetesType: String?
    var targetGlucoseRange: StorageGlucoseRange?
    var carbToInsulinRatio: Double?
    var insulinType: String?
    var medications: [String]?
    var allergies: [String]?
    var dietaryRestrictions: [String]?
    
    enum CodingKeys: String, CodingKey {
        case userId, systemPrompt, pinnedFacts, createdAt, updatedAt
        case monthlyTokenUsage, monthlyRequestCount
        case diabetesType, targetGlucoseRange, carbToInsulinRatio
        case insulinType, medications, allergies, dietaryRestrictions
    }
    
    init(userId: String,
         systemPrompt: String = "",
         pinnedFacts: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         monthlyTokenUsage: Int = 0,
         monthlyRequestCount: Int = 0,
         diabetesType: String? = nil,
         targetGlucoseRange: StorageGlucoseRange? = nil,
         carbToInsulinRatio: Double? = nil,
         insulinType: String? = nil,
         medications: [String]? = nil,
         allergies: [String]? = nil,
         dietaryRestrictions: [String]? = nil) {
        self.userId = userId
        self.systemPrompt = systemPrompt
        self.pinnedFacts = pinnedFacts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.monthlyTokenUsage = monthlyTokenUsage
        self.monthlyRequestCount = monthlyRequestCount
        self.diabetesType = diabetesType
        self.targetGlucoseRange = targetGlucoseRange
        self.carbToInsulinRatio = carbToInsulinRatio
        self.insulinType = insulinType
        self.medications = medications
        self.allergies = allergies
        self.dietaryRestrictions = dietaryRestrictions
    }
}

// MARK: - Glucose Range
struct StorageGlucoseRange: Codable, Sendable {
    let min: Double
    let max: Double
    let unit: String // mg/dL or mmol/L
    
    init(min: Double, max: Double, unit: String = "mg/dL") {
        self.min = min
        self.max = max
        self.unit = unit
    }
}

// MARK: - Message

struct StorageMessage: Codable, Sendable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    let tokenCount: Int?
    let streamingDuration: TimeInterval?
    var imageData: Data?
    var imageURL: String?
    var conversationId: String?
    var userId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        case tokenCount, streamingDuration
        case imageData, imageURL, conversationId, userId
    }
    
    init(id: String = UUID().uuidString,
         role: MessageRole,
         content: String,
         timestamp: Date = Date(),
         tokenCount: Int? = nil,
         streamingDuration: TimeInterval? = nil,
         imageData: Data? = nil,
         imageURL: String? = nil,
         conversationId: String? = nil,
         userId: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
        self.streamingDuration = streamingDuration
        self.imageData = imageData
        self.imageURL = imageURL
        self.conversationId = conversationId
        self.userId = userId
    }
}

enum MessageRole: String, Codable, Sendable {
    case user
    case model
    case system
}

// MARK: - Conversation

struct StorageConversation: Codable, Sendable {
    let id: String
    let userId: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
    let lastMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, title, createdAt, updatedAt
        case messageCount, lastMessage
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         title: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         messageCount: Int = 0,
         lastMessage: String? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.lastMessage = lastMessage
    }
}

// MARK: - Meal Log

struct StorageMealLog: Codable, Sendable {
    let id: String
    let userId: String
    let mealDescription: String
    let timestamp: Date
    let nutritionData: StorageNutritionInfo?
    let glucoseReadings: [StorageGlucoseReading]?
    let aiAnalysis: String?
    let imageUrls: [String]?
    var mealType: String // breakfast, lunch, dinner, snack
    var mealName: String?
    var estimatedCarbs: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, mealDescription, timestamp
        case nutritionData, glucoseReadings, aiAnalysis, imageUrls
        case mealType, mealName, estimatedCarbs
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         mealDescription: String,
         timestamp: Date = Date(),
         nutritionData: StorageNutritionInfo? = nil,
         glucoseReadings: [StorageGlucoseReading]? = nil,
         aiAnalysis: String? = nil,
         imageUrls: [String]? = nil,
         mealType: String = "meal",
         mealName: String? = nil,
         estimatedCarbs: Double? = nil) {
        self.id = id
        self.userId = userId
        self.mealDescription = mealDescription
        self.timestamp = timestamp
        self.nutritionData = nutritionData
        self.glucoseReadings = glucoseReadings
        self.aiAnalysis = aiAnalysis
        self.imageUrls = imageUrls
        self.mealType = mealType
        self.mealName = mealName
        self.estimatedCarbs = estimatedCarbs
    }
}

// MARK: - Nutrition Info

struct StorageNutritionInfo: Codable, Sendable {
    let calories: Double?
    let carbohydrates: Double?
    let protein: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let cholesterol: Double?
    let servingSize: String?
    
    enum CodingKeys: String, CodingKey {
        case calories, carbohydrates, protein, fat
        case fiber, sugar, sodium, cholesterol, servingSize
    }
}

// MARK: - Glucose Reading

struct StorageGlucoseReading: Codable, Sendable {
    let value: Double
    let unit: GlucoseUnit
    let timestamp: Date
    let type: ReadingType
    let notes: String?
    
    enum GlucoseUnit: String, Codable, Sendable {
        case mgDL = "mg/dL"
        case mmolL = "mmol/L"
    }
    
    enum ReadingType: String, Codable, Sendable {
        case beforeMeal = "before_meal"
        case afterMeal = "after_meal"
        case fasting = "fasting"
        case random = "random"
    }
    
    enum CodingKeys: String, CodingKey {
        case value, unit, timestamp, type, notes
    }
}

// MARK: - Recipe

struct StorageRecipe: Codable, Sendable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let nutritionInfo: StorageNutritionInfo?
    let prepTime: Int? // in minutes
    let cookTime: Int? // in minutes
    let servings: Int?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let imageUrl: String?
    let aiGenerated: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, userId, title, description, ingredients, instructions
        case nutritionInfo, prepTime, cookTime, servings, tags
        case createdAt, updatedAt, imageUrl, aiGenerated
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         title: String,
         description: String,
         ingredients: [String],
         instructions: [String],
         nutritionInfo: StorageNutritionInfo? = nil,
         prepTime: Int? = nil,
         cookTime: Int? = nil,
         servings: Int? = nil,
         tags: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         imageUrl: String? = nil,
         aiGenerated: Bool = false) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.nutritionInfo = nutritionInfo
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageUrl = imageUrl
        self.aiGenerated = aiGenerated
    }
}

// MARK: - Shopping List Item

struct ShoppingItem: Codable, Sendable {
    let id: String
    let userId: String
    let name: String
    let quantity: Double?
    let unit: String?
    let category: String?
    let isChecked: Bool
    let addedAt: Date
    let checkedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, name, quantity, unit, category
        case isChecked, addedAt, checkedAt
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         name: String,
         quantity: Double? = nil,
         unit: String? = nil,
         category: String? = nil,
         isChecked: Bool = false,
         addedAt: Date = Date(),
         checkedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isChecked = isChecked
        self.addedAt = addedAt
        self.checkedAt = checkedAt
    }
}

// MARK: - AI Request Tracking

struct AIRequest: Codable, Sendable {
    let id: String
    let userId: String
    let timestamp: Date
    let requestType: String
    let tokenCount: Int
    let responseTime: TimeInterval
    let success: Bool
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, timestamp, requestType
        case tokenCount, responseTime, success, errorMessage
    }
}