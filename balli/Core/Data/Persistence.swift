//
//  Persistence.swift
//  balli
//
//  Created by Serhat on 4.08.2025.
//
//  Refactored facade for Core Data persistence layer
//  Delegates to specialized components while maintaining backward compatibility
//

import CoreData
import OSLog

// Import the refactored components from Persistence folder
typealias RefactoredController = Persistence.PersistenceController

// Helper for passing non-Sendable data across actor boundaries
private struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
}

/// Main persistence facade that maintains backward compatibility
/// while delegating to specialized components
public final class PersistenceController: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = PersistenceController()
    
    // MARK: - Properties
    
    private let logger = AppLoggers.Data.coredata
    private let controller: RefactoredController
    
    public var viewContext: NSManagedObjectContext {
        controller.viewContext
    }
    
    public var container: NSPersistentContainer {
        controller.container
    }
    
    // MARK: - Initialization
    
    public init(inMemory: Bool = false) {
        self.controller = RefactoredController(inMemory: inMemory)
    }
    
    private init() {
        self.controller = RefactoredController.shared
    }
    
    // MARK: - Core Operations
    
    public func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        try await controller.fetch(request)
    }
    
    public func fetchBatched<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        batchSize: Int = 20
    ) async throws -> [T] {
        request.fetchBatchSize = batchSize
        request.returnsObjectsAsFaults = true
        request.includesPropertyValues = false
        return try await controller.fetch(request)
    }
    
    public func save() async throws {
        try await controller.save()
    }
    
    // MARK: - Background Operations
    
    public func performBackgroundTask<T>(
        _ block: @escaping @Sendable (NSManagedObjectContext) async throws -> T,
        progress: Progress? = nil
    ) async throws -> T where T: Sendable {
        try await controller.performBackgroundTask(block)
    }
    
    // MARK: - Batch Operations
    
    public func batchDelete<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil
    ) async throws -> Int {
        try await controller.batchDelete(type, predicate: predicate)
    }
    
    public func batchImport<T: NSManagedObject>(
        _ type: T.Type,
        data: [[String: Any]],
        updateHandler: @escaping @Sendable (T, [String: Any]) -> Void,
        progressHandler: (@Sendable (ImportProgress) -> Void)? = nil
    ) async throws {
        let totalItems = data.count
        
        logger.info("Starting batch import of \(totalItems) items")
        
        // Wrap data to make it Sendable
        let wrappedData = UnsafeSendableWrapper(value: data)
        
        try await controller.performBackgroundTask { @Sendable context in
            let batchSize = 100
            var processedItems = 0
            
            for batchStart in stride(from: 0, to: wrappedData.value.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, wrappedData.value.count)
                let batch = Array(wrappedData.value[batchStart..<batchEnd])
                
                try autoreleasepool {
                    for item in batch {
                        let object = T(context: context)
                        updateHandler(object, item)
                        processedItems += 1
                    }
                    
                    if context.hasChanges {
                        try context.save()
                    }
                    
                    let progress = ImportProgress(
                        totalItems: totalItems,
                        processedItems: processedItems,
                        failedItems: 0
                    )
                    progressHandler?(progress)
                    
                    try Task.checkCancellation()
                }
            }
        }
    }
    
    // MARK: - State Management
    
    public func prepareForBackground() async {
        await controller.prepareForBackground()
    }
    
    public func handleMemoryPressure() async {
        await controller.handleMemoryPressure()
    }
    
    public func recoverFromError(_ error: Error) async throws {
        let nsError = error as NSError
        
        // Try migration recovery
        try await controller.migrateStoreIfNeeded()
        
        // Context recovery
        switch nsError.code {
        case NSPersistentStoreIncompleteSaveError:
            viewContext.rollback()
        default:
            viewContext.reset()
        }
    }
    
    // MARK: - Migration
    
    public func checkMigrationNeeded() async throws -> Bool {
        try await controller.checkMigrationNeeded()
    }
    
    public func migrateStoreIfNeeded() async throws {
        try await controller.migrateStoreIfNeeded()
    }
    
    // MARK: - Health Monitoring
    
    public func checkHealth() async -> DataHealth {
        await controller.checkHealth()
    }
    
    public func getMetrics() async -> HealthMetrics {
        await controller.getMetrics()
    }
}

// MARK: - Import Progress (for backward compatibility)

extension PersistenceController {
    public struct ImportProgress {
        public let totalItems: Int
        public let processedItems: Int
        public let failedItems: Int
        public var percentComplete: Double {
            guard totalItems > 0 else { return 0 }
            return Double(processedItems) / Double(totalItems)
        }
    }
}

// MARK: - Preview Support

extension PersistenceController {
    public static var preview: PersistenceController {
        let controller = PersistenceController(inMemory: true)
        
        #if DEBUG
        do {
            try controller.generatePreviewData()
        } catch {
            AppLoggers.Data.coredata.error("Failed to generate preview data: \(error.localizedDescription)")
        }
        #endif
        
        return controller
    }
    
    #if DEBUG
    private func generatePreviewData() throws {
        let context = viewContext

        // Create food items first
        let favoriteItems = [
            ("Elma", "Apple", 95.0, 25.0, 4.0, 0.5, true),
            ("Beyaz Peynir", "White Cheese", 280.0, 2.0, 0.0, 18.0, true),
            ("Simit", "Turkish Bagel", 250.0, 45.0, 2.0, 8.0, true),
            ("Yoğurt", "Yogurt", 60.0, 5.0, 0.0, 4.0, true),
            ("Bal", "Honey", 304.0, 82.0, 0.0, 0.3, true)
        ]

        var createdFoodItems: [FoodItem] = []

        for (nameTr, nameEn, calories, carbs, fiber, protein, isFavorite) in favoriteItems {
            let item = FoodItem(context: context)
            item.name = nameTr
            item.nameTr = nameTr
            item.nameEn = nameEn
            item.calories = calories
            item.totalCarbs = carbs
            item.fiber = fiber
            item.protein = protein
            item.isFavorite = isFavorite
            item.useCount = Int32.random(in: 60...100)
            item.servingSize = 100
            item.servingUnit = "g"
            item.dateAdded = Date()
            item.lastModified = Date()
            item.lastUsed = Date().addingTimeInterval(-Double.random(in: 0...86400 * 7))
            item.carbsConfidence = Double.random(in: 85...95)
            item.overallConfidence = Double.random(in: 80...95)
            item.source = "manual"
            item.isVerified = true

            createdFoodItems.append(item)
        }

        // Create mock meal entries at specific times today
        // Chart shows 6am-6am (24 hours), so place meals within that window
        // Only meal type, carbs, and timestamp are logged
        let calendar = Calendar.current
        let now = Date()

        // Get today at 6am (chart start time)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 0
        components.second = 0

        guard let today6am = calendar.date(from: components) else {
            try context.save()
            return
        }

        // Create meals at specific times relative to 6am start
        let mealData: [(hoursAfter6am: Double, mealType: String, carbs: Double)] = [
            (3.0, "breakfast", 45.0),   // 9:00 AM (6am + 3 hours) - Breakfast - 45g carbs
            (3.5, "breakfast", 12.0),   // 9:30 AM - Coffee/snack - 12g carbs
            (6.5, "snack", 25.0),       // 12:30 PM - Snack - 25g carbs
            (8.0, "lunch", 38.0)        // 2:00 PM (6am + 8 hours) - Lunch - 38g carbs
        ]

        for (hoursAfter6am, mealType, carbs) in mealData {
            let meal = MealEntry(context: context)
            meal.id = UUID()
            meal.timestamp = today6am.addingTimeInterval(hoursAfter6am * 3600)
            meal.mealType = mealType

            // Only carbs are tracked
            meal.consumedCarbs = carbs

            // Set defaults for other fields
            meal.quantity = 1.0
            meal.unit = "serving"
            meal.portionGrams = 0.0
            meal.consumedProtein = 0.0
            meal.consumedFat = 0.0
            meal.consumedCalories = 0.0
            meal.consumedFiber = 0.0
            meal.glucoseBefore = 0.0
            meal.glucoseAfter = 0.0
            meal.insulinUnits = 0.0
        }

        try context.save()
    }
    #endif
}

// MARK: - Context Extensions

extension NSManagedObjectContext {
    /// Performs an async operation with proper error handling
    func performAsync<T>(_ block: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.perform {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Saves with retry logic
    func saveWithRetry(attempts: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                try self.save()
                return
            } catch {
                lastError = error
                let nsError = error as NSError
                
                if nsError.code == NSManagedObjectMergeError {
                    self.refreshAllObjects()
                } else if nsError.code == NSValidationMultipleErrorsError {
                    throw error
                } else if attempt < attempts {
                    let delay = UInt64(attempt * attempt * 100_000_000)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        
        throw lastError ?? CoreDataError.saveFailed(NSError(domain: "PersistenceController", code: -1))
    }
}

// Note: Persistence namespace is defined in Persistence/PersistenceController.swift