//
//  ExportError.swift
//  balli
//
//  Error types for data export operations
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Errors that can occur during data export
enum ExportError: LocalizedError, Sendable, Equatable {
    case noDataAvailable
    case invalidDateRange
    case encodingFailed
    case insufficientData(minimum: Int, found: Int)
    case futureDate
    case dateRangeTooLarge(days: Int, maximum: Int)

    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No data available for export. Please ensure you have logged meals and glucose readings."

        case .invalidDateRange:
            return "Invalid date range. Start date must be before end date."

        case .encodingFailed:
            return "Failed to encode export data. Please try again."

        case .insufficientData(let minimum, let found):
            return "Insufficient data for export. Found \(found) entries, but need at least \(minimum)."

        case .futureDate:
            return "End date cannot be in the future."

        case .dateRangeTooLarge(let days, let maximum):
            return "Date range too large (\(days) days). Maximum allowed is \(maximum) days."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noDataAvailable:
            return "Start logging your meals, glucose readings, and activity data to enable exports."

        case .invalidDateRange:
            return "Please select a start date that is before the end date."

        case .encodingFailed:
            return "Try exporting a smaller date range or contact support if the issue persists."

        case .insufficientData:
            return "Log more meals and glucose readings, then try exporting again."

        case .futureDate:
            return "Please select an end date that is today or earlier."

        case .dateRangeTooLarge:
            return "Try exporting a smaller date range, or export multiple ranges separately."
        }
    }
}
