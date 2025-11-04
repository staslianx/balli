//
//  EventJSONGenerator.swift
//  balli
//
//  Generates rich JSON format with detailed meal events
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Generates Event JSON format
/// Rich JSON format with complete meal events, glucose responses, and activity context
struct EventJSONGenerator: Sendable {
    // MARK: - JSON Generation

    /// Generate Event JSON from meal events
    /// - Parameters:
    ///   - mealEvents: Array of MealEvent objects
    ///   - dateRange: Date interval being exported
    /// - Returns: JSON data ready for export
    /// - Throws: ExportError.encodingFailed if JSON encoding fails
    func generate(mealEvents: [MealEvent], dateRange: DateInterval) throws -> Data {
        // Create export wrapper with metadata
        let export = EventJSONExport(
            metadata: ExportMetadata(
                exportDate: Date(),
                dateRange: dateRange,
                eventCount: mealEvents.count,
                format: "event_json",
                version: "1.0"
            ),
            events: mealEvents
        )

        // Encode to JSON with pretty printing
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(export)
        } catch {
            throw ExportError.encodingFailed
        }
    }
}

// MARK: - Export Structure

/// Root export object with metadata
private struct EventJSONExport: Codable {
    let metadata: ExportMetadata
    let events: [MealEvent]
}

/// Export metadata
private struct ExportMetadata: Codable {
    let exportDate: Date
    let startDate: Date
    let endDate: Date
    let eventCount: Int
    let format: String
    let version: String

    init(exportDate: Date, dateRange: DateInterval, eventCount: Int, format: String, version: String) {
        self.exportDate = exportDate
        self.startDate = dateRange.start
        self.endDate = dateRange.end
        self.eventCount = eventCount
        self.format = format
        self.version = version
    }
}
