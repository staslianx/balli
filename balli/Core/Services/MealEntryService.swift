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

        // PRE-COMPUTE VALUES ON MAIN THREAD (before background context)
        // This prevents Swift 6 concurrency violations when accessing computed properties
        let isSimpleFormat = foodsArray.allSatisfy { $0.carbsInt == nil }

        // Pre-compute carbs values to avoid accessing computed property on background thread
        let foodDataArray: [(name: String, amount: String, carbs: Int?)] = foodsArray.map { food in
            (name: food.name, amount: food.amount, carbs: food.carbsInt)
        }

        // Note: automaticallyMergesChangesFromParent is already set to true in CoreDataStack.configureContexts()
        // Do NOT set it again here as it causes ALL active @FetchRequest to re-evaluate synchronously,
        // which can freeze the UI when multiple views have fetch requests active (e.g., ArdiyeView).

        // Perform CoreData operations on background context with auto-retry
        var saveSucceeded = false
        var saveAttempt = 0
        let maxAttempts = 2

        while !saveSucceeded && saveAttempt < maxAttempts {
            saveAttempt += 1

            do {
                try await context.perform {
                    if isGeminiFormat {
                        // GEMINI FORMAT: Create separate MealEntry for each food item
                        try self.createGeminiFormatEntries(
                            foodDataArray: foodDataArray,
                            isSimpleFormat: isSimpleFormat,
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
                    // The save will automatically trigger a merge into viewContext
                    // because automaticallyMergesChangesFromParent = true
                    try context.save()
                }

                // Save succeeded
                saveSucceeded = true
                if saveAttempt == 1 {
                    self.logger.info("✅ Saved meal entry: \(totalCarbs)g carbs, \(mealType)")
                } else {
                    self.logger.info("✅ Saved meal entry on retry: \(totalCarbs)g carbs, \(mealType)")
                }

            } catch {
                if saveAttempt < maxAttempts {
                    // CRITICAL SAFETY: Retry once for transient CoreData failures
                    // (disk busy, temporary permission issues, etc.)
                    self.logger.warning("⚠️ Save attempt \(saveAttempt) failed: \(error.localizedDescription) - retrying once...")
                    try? await Task.sleep(for: .milliseconds(500))
                } else {
                    // Both attempts failed - this is a real problem
                    self.logger.error("❌ CRITICAL: Failed to save meal entry after \(maxAttempts) attempts: \(error.localizedDescription)")
                    throw MealEntryServiceError.saveFailed(error)
                }
            }
        }

        // CRITICAL FIX: automaticallyMergesChangesFromParent merges silently without triggering
        // NSManagedObjectContextObjectsDidChange notifications. We must explicitly notify
        // observers (like GlucoseChartViewModel) that meal data has changed.
        //
        // RACE CONDITION FIX: The background context save triggers an async merge to the main context.
        // We MUST explicitly trigger a refresh on the main context to ensure the merge has completed
        // and the new objects are available before notifying observers!
        await MainActor.run {
            // Force the view context to process pending changes from the merge
            // This ensures that @FetchRequest and manual fetches will see the new data
            viewContext.refreshAllObjects()

            // Process pending changes to trigger any active @FetchRequest queries
            viewContext.processPendingChanges()

            // NOW post the notification - observers will see the refreshed data
            NotificationCenter.default.post(
                name: .mealEntryDidSave,
                object: nil,
                userInfo: ["timestamp": timestamp, "mealType": mealType]
            )
            self.logger.debug("Posted mealEntryDidSave notification after forcing context refresh")
        }
    }

    // MARK: - Private Helpers

    /// Create meal entries for Gemini format (separate entry for each food)
    nonisolated private func createGeminiFormatEntries(
        foodDataArray: [(name: String, amount: String, carbs: Int?)],
        isSimpleFormat: Bool,
        totalCarbs: Int,
        mealType: String,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        // VALIDATION: Ensure foodDataArray is not empty
        guard !foodDataArray.isEmpty else {
            logger.error("❌ Cannot create entries: foodDataArray is empty")
            throw MealEntryServiceError.invalidFoodData
        }

        for (index, foodData) in foodDataArray.enumerated() {
            // VALIDATION: Skip foods with empty names (should already be filtered, but double-check)
            let trimmedName = foodData.name.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else {
                logger.warning("⚠️ Skipping food item with empty name at index \(index)")
                continue
            }

            // Create FoodItem
            let foodItem = FoodItem(context: context)
            foodItem.id = UUID()
            foodItem.name = trimmedName  // Use trimmed name
            foodItem.nameTr = trimmedName

            // Set required properties FIRST before any nutrition values
            // Parse amount if possible (from edited amount)
            let amountText = foodData.amount.trimmingCharacters(in: .whitespaces)
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

            // Set remaining required properties
            foodItem.source = "voice-gemini"
            foodItem.dateAdded = Date()
            foodItem.lastModified = Date()
            foodItem.lastUsed = Date()
            foodItem.useCount = 1

            // Initialize all required Double properties with defaults
            foodItem.servingsPerContainer = 1.0
            foodItem.gramWeight = 0.0
            foodItem.calories = 0.0
            foodItem.fiber = 0.0
            foodItem.sugars = 0.0
            foodItem.addedSugars = 0.0
            foodItem.sugarAlcohols = 0.0
            foodItem.protein = 0.0
            foodItem.totalFat = 0.0
            foodItem.saturatedFat = 0.0
            foodItem.transFat = 0.0
            foodItem.sodium = 0.0
            foodItem.carbsConfidence = 0.0
            foodItem.overallConfidence = 0.0
            foodItem.ocrConfidence = 0.0

            // Now set nutrition (from pre-computed carbs)
            // IMPORTANT: Only set per-item carbs if this is NOT simple format
            if let itemCarbs = foodData.carbs, itemCarbs > 0 {
                foodItem.totalCarbs = Double(itemCarbs)
            } else if isSimpleFormat {
                // For simple format, don't set carbs on individual items
                foodItem.totalCarbs = 0
            } else {
                // Detailed format but this item has no carbs - set to 0
                foodItem.totalCarbs = 0
            }

            // Set gramWeight - ensure it's never zero to prevent division errors
            // Use max of 1.0 or totalCarbs, but prefer a more realistic minimum
            if foodItem.totalCarbs > 0 {
                foodItem.gramWeight = max(10.0, foodItem.totalCarbs)  // Minimum 10g
            } else {
                foodItem.gramWeight = 100.0  // Default for items without carb data
            }

            // Create MealEntry
            let mealEntry = MealEntry(context: context)
            mealEntry.id = UUID()
            mealEntry.timestamp = timestamp
            mealEntry.mealType = mealType
            mealEntry.foodItem = foodItem
            mealEntry.quantity = 1.0
            mealEntry.unit = "porsiyon"

            // Initialize all consumed nutrition values (required before calculateNutrition)
            mealEntry.portionGrams = 0.0
            mealEntry.consumedCarbs = 0.0
            mealEntry.consumedProtein = 0.0
            mealEntry.consumedFat = 0.0
            mealEntry.consumedCalories = 0.0
            mealEntry.consumedFiber = 0.0
            mealEntry.glucoseBefore = 0.0
            mealEntry.glucoseAfter = 0.0
            mealEntry.insulinUnits = 0.0

            // Calculate and set nutrition
            mealEntry.calculateNutrition()

            // For first entry in simple format (no per-item carbs), store total carbs
            if index == 0 && isSimpleFormat {
                mealEntry.consumedCarbs = Double(totalCarbs)
            }
        }
    }

    /// Create single meal entry for legacy format
    nonisolated private func createLegacyFormatEntry(
        totalCarbs: Int,
        mealType: String,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        let foodItem = FoodItem(context: context)
        foodItem.id = UUID()
        foodItem.name = "Sesli Giriş: \(mealType.capitalized)"
        foodItem.nameTr = "Sesli Giriş: \(mealType.capitalized)"
        foodItem.servingSize = 1.0
        foodItem.servingUnit = "porsiyon"
        foodItem.source = "voice-gemini"
        foodItem.dateAdded = Date()
        foodItem.lastModified = Date()
        foodItem.lastUsed = Date()
        foodItem.useCount = 1

        // Initialize all required Double properties with defaults
        foodItem.servingsPerContainer = 1.0
        foodItem.calories = 0.0
        foodItem.fiber = 0.0
        foodItem.sugars = 0.0
        foodItem.addedSugars = 0.0
        foodItem.sugarAlcohols = 0.0
        foodItem.protein = 0.0
        foodItem.totalFat = 0.0
        foodItem.saturatedFat = 0.0
        foodItem.transFat = 0.0
        foodItem.sodium = 0.0
        foodItem.carbsConfidence = 0.0
        foodItem.overallConfidence = 0.0
        foodItem.ocrConfidence = 0.0

        foodItem.totalCarbs = Double(totalCarbs)
        // Ensure gramWeight is never zero to prevent division errors
        foodItem.gramWeight = max(1.0, Double(totalCarbs))

        let mealEntry = MealEntry(context: context)
        mealEntry.id = UUID()
        mealEntry.timestamp = timestamp
        mealEntry.mealType = mealType
        mealEntry.foodItem = foodItem
        mealEntry.quantity = 1.0
        mealEntry.unit = "porsiyon"

        // Initialize all consumed nutrition values (required before calculateNutrition)
        mealEntry.portionGrams = 0.0
        mealEntry.consumedCarbs = 0.0
        mealEntry.consumedProtein = 0.0
        mealEntry.consumedFat = 0.0
        mealEntry.consumedCalories = 0.0
        mealEntry.consumedFiber = 0.0
        mealEntry.glucoseBefore = 0.0
        mealEntry.glucoseAfter = 0.0
        mealEntry.insulinUnits = 0.0

        mealEntry.calculateNutrition()
        mealEntry.consumedCarbs = Double(totalCarbs)
    }

    /// Create insulin medication entry
    nonisolated private func createInsulinEntry(
        dosage: Double,
        insulinType: String?,
        insulinName: String?,
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws {
        // Get the first meal entry for relationship (bolus insulin is linked to meals)
        let fetchRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "timestamp == %@", timestamp as NSDate)
        fetchRequest.fetchLimit = 1

        let mealEntries = try context.fetch(fetchRequest)
        let firstMealEntry = mealEntries.first

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
    case invalidFoodData
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingPersistentStore:
            return "CoreData persistent store coordinator not available"
        case .invalidCarbValue:
            return "Invalid carbohydrate value provided"
        case .invalidFoodData:
            return "Invalid food data - no valid food items found"
        case .saveFailed(let error):
            return "Öğün kaydedilemedi. Lütfen tekrar deneyin.\n\nHata: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when a meal entry is successfully saved to Core Data
    /// Allows glucose chart and other observers to refresh immediately
    static let mealEntryDidSave = Notification.Name("mealEntryDidSave")
}
