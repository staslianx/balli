//
//  MealEntryService.swift
//  balli
//
//  Service for creating and saving meal entries with insulin tracking
//  Swift 6 strict concurrency compliant
//

import CoreData
import Foundation
import OSLog

/// Service responsible for creating and persisting meal entries and associated medication
@MainActor
final class MealEntryService {
    private let logger = Logger(subsystem: "com.balli.diabetes", category: "MealEntryService")

    /// Save a meal entry with optional insulin to CoreData
    /// - Parameters:
    ///   - totalCarbs: Total carbohydrates in grams
    ///   - mealType: Type of meal (kahvaltı, ara öğün, akşam yemeği)
    ///   - timestamp: When the meal was consumed
    ///   - foods: Array of food items with names, amounts, and optional per-item carbs
    ///   - hasInsulin: Whether insulin was administered
    ///   - insulinDosage: Insulin dosage in units
    ///   - insulinType: Type of insulin (bolus/basal)
    ///   - insulinName: Name of insulin medication
    ///   - viewContext: Main CoreData context (for merging changes)
    func saveMealEntry(
        totalCarbs: Int,
        mealType: String,
        timestamp: Date,
        foods: [EditableFoodItem],
        hasInsulin: Bool,
        insulinDosage: Double,
        insulinType: String?,
        insulinName: String?,
        viewContext: NSManagedObjectContext
    ) async throws {
        // Create a background context for async CoreData operations
        guard let coordinator = viewContext.persistentStoreCoordinator else {
            logger.error("Failed to get persistent store coordinator")
            throw MealEntryServiceError.missingPersistentStore
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // Filter out empty food items
        let foodsArray = foods.filter { !$0.name.isEmpty }
        let isGeminiFormat = !foodsArray.isEmpty

        // Perform CoreData operations on background context
        try await context.perform {
            if isGeminiFormat {
                // GEMINI FORMAT: Create separate MealEntry for each food item
                try self.createGeminiFormatEntries(
                    foodsArray: foodsArray,
                    totalCarbs: totalCarbs,
                    mealType: mealType,
                    timestamp: timestamp,
                    context: context
                )
            } else {
                // LEGACY FORMAT: Single entry (backward compatible)
                try self.createLegacyFormatEntry(
                    totalCarbs: totalCarbs,
                    mealType: mealType,
                    timestamp: timestamp,
                    context: context
                )
            }

            // CREATE INSULIN MEDICATION ENTRY (if insulin was specified)
            if hasInsulin && insulinDosage > 0 {
                try self.createInsulinEntry(
                    dosage: insulinDosage,
                    insulinType: insulinType,
                    insulinName: insulinName,
                    timestamp: timestamp,
                    context: context
                )
            }

            // Save on background thread
            try context.save()
            self.logger.info("✅ Saved meal entry: \(totalCarbs)g carbs, \(mealType)")
        }

        // CRITICAL: Merge changes from private context into viewContext
        // This ensures the glucose chart immediately receives the meal markers
        await MainActor.run {
            viewContext.performAndWait {
                viewContext.mergeChanges(fromContextDidSave: Notification(
                    name: .NSManagedObjectContextDidSave,
                    object: context,
                    userInfo: [
                        NSInsertedObjectsKey: context.insertedObjects,
                        NSUpdatedObjectsKey: context.updatedObjects,
                        NSDeletedObjectsKey: context.deletedObjects
                    ]
                ))
            }
        }
    }

    // MARK: - Private Helpers

    /// Create meal entries for Gemini format (separate entry for each food)
    private func createGeminiFormatEntries(
        foodsArray: [EditableFoodItem],
        totalCarbs: Int,
        mealType: String,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        let isSimpleFormat = foodsArray.allSatisfy { $0.carbsInt == nil }

        for (index, editableFood) in foodsArray.enumerated() {
            // Create FoodItem
            let foodItem = FoodItem(context: context)
            foodItem.id = UUID()
            foodItem.name = editableFood.name
            foodItem.nameTr = editableFood.name

            // Set nutrition (from edited carbs)
            if let itemCarbs = editableFood.carbsInt {
                foodItem.totalCarbs = Double(itemCarbs)
            } else {
                // For simple format, don't set carbs on individual items
                foodItem.totalCarbs = 0
            }

            // Parse amount if possible (from edited amount)
            let amountText = editableFood.amount
            if !amountText.isEmpty {
                let components = amountText.split(separator: " ")
                if let firstNum = components.first, let value = Double(firstNum) {
                    foodItem.servingSize = value
                    foodItem.servingUnit = components.dropFirst().joined(separator: " ")
                } else {
                    foodItem.servingSize = 1.0
                    foodItem.servingUnit = amountText
                }
            } else {
                foodItem.servingSize = 1.0
                foodItem.servingUnit = "porsiyon"
            }

            foodItem.gramWeight = foodItem.totalCarbs
            foodItem.source = "voice-gemini"
            foodItem.dateAdded = Date()
            foodItem.lastUsed = Date()
            foodItem.useCount = 1

            // Create MealEntry
            let mealEntry = MealEntry(context: context)
            mealEntry.id = UUID()
            mealEntry.timestamp = timestamp
            mealEntry.mealType = mealType
            mealEntry.foodItem = foodItem
            mealEntry.quantity = 1.0
            mealEntry.unit = "porsiyon"

            // Calculate and set nutrition
            mealEntry.calculateNutrition()

            // For first entry in simple format (no per-item carbs), store total carbs
            if index == 0 && isSimpleFormat {
                mealEntry.consumedCarbs = Double(totalCarbs)
            }
        }
    }

    /// Create single meal entry for legacy format
    private func createLegacyFormatEntry(
        totalCarbs: Int,
        mealType: String,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        let foodItem = FoodItem(context: context)
        foodItem.id = UUID()
        foodItem.name = "Sesli Giriş: \(mealType.capitalized)"
        foodItem.nameTr = "Sesli Giriş: \(mealType.capitalized)"
        foodItem.totalCarbs = Double(totalCarbs)
        foodItem.servingSize = 1.0
        foodItem.servingUnit = "porsiyon"
        foodItem.gramWeight = Double(totalCarbs)
        foodItem.source = "voice-gemini"
        foodItem.dateAdded = Date()
        foodItem.lastUsed = Date()
        foodItem.useCount = 1

        let mealEntry = MealEntry(context: context)
        mealEntry.id = UUID()
        mealEntry.timestamp = timestamp
        mealEntry.mealType = mealType
        mealEntry.foodItem = foodItem
        mealEntry.quantity = 1.0
        mealEntry.unit = "porsiyon"
        mealEntry.calculateNutrition()
        mealEntry.consumedCarbs = Double(totalCarbs)
    }

    /// Create insulin medication entry
    private func createInsulinEntry(
        dosage: Double,
        insulinType: String?,
        insulinName: String?,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        // Get the first meal entry for relationship (bolus insulin is linked to meals)
        let mealEntries = try context.fetch(MealEntry.fetchRequest()) as [MealEntry]
        let firstMealEntry = mealEntries.filter { $0.timestamp == timestamp }.first

        // Create MedicationEntry
        let medication = MedicationEntry(context: context)
        medication.id = UUID()
        medication.timestamp = timestamp
        medication.dosage = dosage
        medication.dosageUnit = "ünite"

        // Set medication name and type
        if let name = insulinName {
            medication.medicationName = name
        } else {
            // Default names based on type
            medication.medicationName = insulinType == "basal" ? "Bazal İnsülin" : "Bolus İnsülin"
        }

        // Determine medication type
        if let type = insulinType {
            medication.medicationType = type == "basal" ? "basal_insulin" : "bolus_insulin"
        } else {
            // If type not specified, assume bolus if connected to meal, basal otherwise
            medication.medicationType = firstMealEntry != nil ? "bolus_insulin" : "basal_insulin"
        }

        medication.administrationRoute = "subcutaneous"
        medication.timingRelation = firstMealEntry != nil ? "with_meal" : "standalone"
        medication.isScheduled = false
        medication.dateAdded = Date()
        medication.lastModified = Date()
        medication.source = "voice-gemini"
        medication.glucoseAtTime = 0 // Could be set if we have current glucose

        // Link to meal entry if this is bolus insulin
        if medication.medicationType == "bolus_insulin", let mealEntry = firstMealEntry {
            medication.mealEntry = mealEntry
        }

        logger.info("💉 Created insulin medication: \(medication.medicationName) \(dosage) units")
    }
}

// MARK: - Errors

enum MealEntryServiceError: LocalizedError {
    case missingPersistentStore
    case invalidCarbValue
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingPersistentStore:
            return "CoreData persistent store coordinator not available"
        case .invalidCarbValue:
            return "Invalid carbohydrate value provided"
        case .saveFailed(let error):
            return "Failed to save meal entry: \(error.localizedDescription)"
        }
    }
}
