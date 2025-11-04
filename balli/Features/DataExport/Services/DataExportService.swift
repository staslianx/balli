//
//  DataExportService.swift
//  balli
//
//  Main export service coordinating data extraction and format generation
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import OSLog

/// Main export service actor
/// Coordinates data extraction, format generation, and file creation
actor DataExportService {
    // MARK: - Properties

    private let repository: ExportDataRepository
    private let mealEventBuilder: MealEventBuilder
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "DataExport")

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext = Persistence.PersistenceController.shared.viewContext) {
        self.repository = ExportDataRepository(viewContext: viewContext)
        self.mealEventBuilder = MealEventBuilder(repository: repository)
    }

    // MARK: - Export Orchestration

    /// Export data in specified format
    /// - Parameters:
    ///   - format: Export format to generate
    ///   - dateRange: Date interval to export
    /// - Returns: Tuple (Data, filename) ready for sharing
    /// - Throws: ExportError if validation fails or generation errors occur
    func exportData(format: ExportFormat, dateRange: DateInterval) async throws -> (data: Data, filename: String) {
        logger.info("🚀 [EXPORT] Starting export - Format: \(format.rawValue), Range: \(dateRange.start) to \(dateRange.end)")

        // 1. Validate date range
        try await repository.validateDateRange(dateRange)

        // 2. Validate data availability
        let validation = try await repository.validateDataAvailability(in: dateRange)

        guard validation.hasData else {
            throw ExportError.noDataAvailable
        }

        // Check minimum data requirements
        let totalEntries = validation.mealCount + validation.glucoseCount
        guard totalEntries >= 10 else {
            throw ExportError.insufficientData(minimum: 10, found: totalEntries)
        }

        logger.info("✅ [EXPORT] Validation passed - \(validation.mealCount) meals, \(validation.glucoseCount) glucose readings")

        // 3. Build meal events (includes glucose response and activity context)
        let mealEvents = try await mealEventBuilder.buildMealEvents(in: dateRange)

        logger.info("📊 [EXPORT] Built \(mealEvents.count) meal events")

        // 4. Generate export data based on format
        let data: Data

        switch format {
        case .correlationCSV:
            data = try await generateCorrelationCSV(mealEvents: mealEvents, dateRange: dateRange)

        case .eventJSON:
            data = try await generateEventJSON(mealEvents: mealEvents, dateRange: dateRange)

        case .timeSeriesCSV:
            data = try await generateTimeSeriesCSV(dateRange: dateRange)
        }

        logger.info("✅ [EXPORT] Generated \(data.count) bytes")

        // 5. Generate filename
        let filename = format.filename(dateRange: dateRange)

        logger.info("🎉 [EXPORT] Export complete - \(filename)")

        return (data, filename)
    }

    // MARK: - Format Generators

    /// Generate Correlation CSV format
    /// Excel-ready format for quick correlation analysis
    private func generateCorrelationCSV(mealEvents: [MealEvent], dateRange: DateInterval) async throws -> Data {
        logger.info("📊 [CSV] Generating Correlation CSV with \(mealEvents.count) events")

        let generator = CorrelationCSVGenerator()
        return try generator.generate(mealEvents: mealEvents, dateRange: dateRange)
    }

    /// Generate Event JSON format
    /// Rich JSON format with detailed meal events
    private func generateEventJSON(mealEvents: [MealEvent], dateRange: DateInterval) async throws -> Data {
        logger.info("📊 [JSON] Generating Event JSON with \(mealEvents.count) events")

        let generator = EventJSONGenerator()
        return try generator.generate(mealEvents: mealEvents, dateRange: dateRange)
    }

    /// Generate Time Series CSV format
    /// ML-ready chronological format with 5-minute intervals
    private func generateTimeSeriesCSV(dateRange: DateInterval) async throws -> Data {
        logger.info("📊 [TIME-SERIES] Generating Time Series CSV for \(dateRange.start) to \(dateRange.end)")

        // Fetch all raw data for time series construction
        let glucoseReadings = try await repository.fetchGlucoseReadings(in: dateRange)
        let meals = try await repository.fetchMeals(in: dateRange)
        let insulinEntries = try await repository.fetchInsulinEntries(in: dateRange)
        let dailyActivity = try await repository.fetchDailyActivity(in: dateRange)

        let generator = TimeSeriesCSVGenerator()
        return try generator.generate(
            glucoseReadings: glucoseReadings,
            meals: meals,
            insulinEntries: insulinEntries,
            dailyActivity: dailyActivity,
            dateRange: dateRange
        )
    }

    // MARK: - Utilities

    /// Validate if export is possible for date range (quick check without full data fetch)
    /// - Parameter dateRange: Date interval to validate
    /// - Returns: Tuple (isValid, mealCount, glucoseCount, errorMessage)
    func validateExport(for dateRange: DateInterval) async -> (isValid: Bool, mealCount: Int, glucoseCount: Int, errorMessage: String?) {
        do {
            // Validate date range
            try await repository.validateDateRange(dateRange)

            // Check data availability
            let validation = try await repository.validateDataAvailability(in: dateRange)

            // Check minimum data
            let totalEntries = validation.mealCount + validation.glucoseCount

            if !validation.hasData {
                return (false, 0, 0, "No data available for the selected date range.")
            }

            if totalEntries < 10 {
                return (false, validation.mealCount, validation.glucoseCount, "Insufficient data. Found \(totalEntries) entries, but need at least 10.")
            }

            return (true, validation.mealCount, validation.glucoseCount, nil)

        } catch let error as ExportError {
            return (false, 0, 0, error.errorDescription)
        } catch {
            return (false, 0, 0, "Validation failed: \(error.localizedDescription)")
        }
    }

    /// Get data summary for date range (for UI display)
    /// - Parameter dateRange: Date interval to query
    /// - Returns: Dictionary with data counts
    func getDataSummary(for dateRange: DateInterval) async throws -> [String: Int] {
        let validation = try await repository.validateDataAvailability(in: dateRange)

        let insulinCount = try await repository.fetchInsulinEntries(in: dateRange).count
        let activityDays = try await repository.fetchDailyActivity(in: dateRange).count

        return [
            "meals": validation.mealCount,
            "glucose_readings": validation.glucoseCount,
            "insulin_entries": insulinCount,
            "activity_days": activityDays
        ]
    }
}
