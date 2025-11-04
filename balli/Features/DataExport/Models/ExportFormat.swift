//
//  ExportFormat.swift
//  balli
//
//  Defines available data export formats
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Available export formats for diabetes data
enum ExportFormat: String, CaseIterable, Sendable {
    case correlationCSV = "correlation_csv"
    case eventJSON = "event_json"
    case timeSeriesCSV = "timeseries_csv"

    /// File extension for this format
    var fileExtension: String {
        switch self {
        case .correlationCSV, .timeSeriesCSV:
            return "csv"
        case .eventJSON:
            return "json"
        }
    }

    /// MIME type for this format
    var mimeType: String {
        switch self {
        case .correlationCSV, .timeSeriesCSV:
            return "text/csv"
        case .eventJSON:
            return "application/json"
        }
    }

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .correlationCSV:
            return "Correlation CSV (Excel)"
        case .eventJSON:
            return "Event JSON (Detailed)"
        case .timeSeriesCSV:
            return "Time Series CSV (ML)"
        }
    }

    /// Description of this format
    var description: String {
        switch self {
        case .correlationCSV:
            return "Excel-ready format for quick correlation analysis between meals, glucose, and activity"
        case .eventJSON:
            return "Rich JSON format with detailed meal events, glucose responses, and activity context"
        case .timeSeriesCSV:
            return "ML-ready chronological format with 5-minute intervals for advanced analysis"
        }
    }

    /// Suggested filename for this format
    func filename(dateRange: DateInterval) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let start = formatter.string(from: dateRange.start)
        let end = formatter.string(from: dateRange.end)

        return "balli_\(rawValue)_\(start)_to_\(end).\(fileExtension)"
    }
}
