//
//  ExportDataRepository.swift
//  balli
//
//  Thread-safe repository for fetching export data from Core Data
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import OSLog

/// Actor-isolated repository for fetching meal, glucose, insulin, and activity data
/// Provides thread-safe Core Data access for export operations
actor ExportDataRepository {
    // MARK: - Properties

    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "ExportDataRepository")

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext = Persistence.PersistenceController.shared.viewContext) {
        self.viewContext = viewContext
    }

    // MARK: - Meal Data

    /// Fetch all meal entries within date range
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Array of MealEntry objects
    func fetchMeals(in dateRange: DateInterval) async throws -> [MealEntry] {
        try await viewContext.perform {
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

            return try self.viewContext.fetch(request)
        }
    }

    /// Count meals in date range (for validation)
    func countMeals(in dateRange: DateInterval) async throws -> Int {
        try await viewContext.perform {
            let request = MealEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )

            return try self.viewContext.count(for: request)
        }
    }

    // MARK: - Glucose Data

    /// Fetch all glucose readings within date range
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Array of GlucoseReading objects
    func fetchGlucoseReadings(in dateRange: DateInterval) async throws -> [GlucoseReading] {
        try await viewContext.perform {
            let request = GlucoseReading.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

            return try self.viewContext.fetch(request)
        }
    }

    /// Fetch glucose readings surrounding a specific meal
    /// - Parameters:
    ///   - mealTimestamp: Time of the meal
    ///   - minutesBefore: Window before meal (default 30)
    ///   - minutesAfter: Window after meal (default 180 = 3 hours)
    /// - Returns: Array of glucose readings in the window
    func fetchGlucoseReadings(
        around mealTimestamp: Date,
        minutesBefore: Int = 30,
        minutesAfter: Int = 180
    ) async throws -> [GlucoseReading] {
        let start = mealTimestamp.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        let end = mealTimestamp.addingTimeInterval(TimeInterval(minutesAfter * 60))

        return try await fetchGlucoseReadings(in: DateInterval(start: start, end: end))
    }

    /// Count glucose readings in date range (for validation)
    func countGlucoseReadings(in dateRange: DateInterval) async throws -> Int {
        try await viewContext.perform {
            let request = GlucoseReading.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )

            return try self.viewContext.count(for: request)
        }
    }

    // MARK: - Insulin Data

    /// Fetch all medication entries (insulin) within date range
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Array of MedicationEntry objects
    func fetchInsulinEntries(in dateRange: DateInterval) async throws -> [MedicationEntry] {
        try await viewContext.perform {
            let request = MedicationEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

            return try self.viewContext.fetch(request)
        }
    }

    /// Find insulin entries associated with a specific meal
    /// Looks for insulin within ±30 minutes of meal time
    func fetchInsulinEntries(
        for mealTimestamp: Date,
        windowMinutes: Int = 30
    ) async throws -> [MedicationEntry] {
        let start = mealTimestamp.addingTimeInterval(TimeInterval(-windowMinutes * 60))
        let end = mealTimestamp.addingTimeInterval(TimeInterval(windowMinutes * 60))

        return try await fetchInsulinEntries(in: DateInterval(start: start, end: end))
    }

    // MARK: - Activity Data

    /// Fetch daily activity records within date range
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Array of DailyActivity objects
    func fetchDailyActivity(in dateRange: DateInterval) async throws -> [DailyActivity] {
        try await viewContext.perform {
            let request = DailyActivity.fetchRequest()
            request.predicate = NSPredicate(
                format: "date >= %@ AND date <= %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

            return try self.viewContext.fetch(request)
        }
    }

    /// Fetch activity record for specific date
    /// - Parameter date: Date to query (ignores time component)
    /// - Returns: DailyActivity object or nil if not found
    func fetchDailyActivity(for date: Date) async throws -> DailyActivity? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let activities = try await fetchDailyActivity(in: DateInterval(start: startOfDay, end: endOfDay))
        return activities.first
    }


    // MARK: - Validation

    /// Check if sufficient data exists for export
    /// - Parameter dateRange: Date interval to validate
    /// - Returns: Tuple (hasData, mealCount, glucoseCount)
    func validateDataAvailability(in dateRange: DateInterval) async throws -> (hasData: Bool, mealCount: Int, glucoseCount: Int) {
        let mealCount = try await countMeals(in: dateRange)
        let glucoseCount = try await countGlucoseReadings(in: dateRange)

        let hasData = mealCount > 0 || glucoseCount > 0

        logger.info("📊 [VALIDATION] Date range: \(dateRange.start) to \(dateRange.end)")
        logger.info("📊 [VALIDATION] Meals: \(mealCount), Glucose readings: \(glucoseCount)")

        return (hasData, mealCount, glucoseCount)
    }

    /// Check if date range is valid and not too large
    /// - Parameter dateRange: Date interval to validate
    /// - Throws: ExportError if invalid
    func validateDateRange(_ dateRange: DateInterval) throws {
        // Check start < end
        guard dateRange.start < dateRange.end else {
            throw ExportError.invalidDateRange
        }

        // Check end is not in future
        guard dateRange.end <= Date() else {
            throw ExportError.futureDate
        }

        // Check range is not too large (max 365 days)
        let maxDays = 365
        let daysDifference = Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0

        guard daysDifference <= maxDays else {
            throw ExportError.dateRangeTooLarge(days: daysDifference, maximum: maxDays)
        }

        logger.info("✅ [VALIDATION] Date range valid: \(daysDifference) days")
    }
}
