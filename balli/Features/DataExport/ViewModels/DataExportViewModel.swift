//
//  DataExportViewModel.swift
//  balli
//
//  ViewModel for data export UI
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// ViewModel for DataExportView
/// Manages export state, validation, and file generation
@MainActor
final class DataExportViewModel: ObservableObject {
    // MARK: - Published State

    @Published var startDate: Date
    @Published var endDate: Date
    @Published var selectedFormat: ExportFormat = .correlationCSV

    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatus: String = ""

    @Published var validationMessage: String?
    @Published var showingValidationError = false

    @Published var exportedFileURL: URL?
    @Published var showingShareSheet = false

    @Published var dataSummary: [String: Int]?

    // MARK: - Dependencies

    private let exportService: DataExportService
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "DataExportViewModel")

    // MARK: - Initialization

    init(exportService: DataExportService = DataExportService()) {
        self.exportService = exportService

        // Default to last 30 days
        let now = Date()
        self.endDate = now
        self.startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
    }

    // MARK: - Computed Properties

    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)

        return "\(start) - \(end)"
    }

    var dayCount: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var canExport: Bool {
        !isExporting && startDate < endDate && endDate <= Date()
    }

    // MARK: - Actions

    /// Validate export parameters and load data summary
    func validateExport() async {
        logger.info("🔍 [VALIDATE] Validating export for \(self.dateRangeDescription)")

        let dateRange = DateInterval(start: startDate, end: endDate)

        // Validate
        let validation = await exportService.validateExport(for: dateRange)

        if validation.isValid {
            validationMessage = "✅ Ready to export: \(validation.mealCount) meals, \(validation.glucoseCount) glucose readings"
            showingValidationError = false

            // Load summary
            await loadDataSummary()
        } else {
            validationMessage = validation.errorMessage
            showingValidationError = true
        }
    }

    /// Load data summary for display
    func loadDataSummary() async {
        do {
            let dateRange = DateInterval(start: startDate, end: endDate)
            dataSummary = try await exportService.getDataSummary(for: dateRange)
            logger.info("📊 [SUMMARY] Loaded data summary: \(self.dataSummary?.description ?? "empty")")
        } catch {
            logger.error("❌ [SUMMARY] Failed to load: \(error.localizedDescription)")
            dataSummary = nil
        }
    }

    /// Execute export and prepare file for sharing
    func exportData() async {
        guard canExport else {
            logger.warning("⚠️ [EXPORT] Cannot export - invalid state")
            return
        }

        isExporting = true
        exportProgress = 0.0
        exportStatus = "Preparing export..."

        do {
            let dateRange = DateInterval(start: startDate, end: endDate)

            logger.info("🚀 [EXPORT] Starting export - Format: \(self.selectedFormat.rawValue)")

            exportProgress = 0.3
            exportStatus = "Collecting data..."

            // Small delay to show progress
            try await Task.sleep(for: .milliseconds(200))

            exportProgress = 0.6
            exportStatus = "Generating \(selectedFormat.displayName)..."

            // Generate export
            let (data, filename) = try await exportService.exportData(
                format: selectedFormat,
                dateRange: dateRange
            )

            logger.info("✅ [EXPORT] Generated \(data.count) bytes - \(filename)")

            exportProgress = 0.9
            exportStatus = "Saving file..."

            // Write to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)

            exportProgress = 1.0
            exportStatus = "Export complete!"

            // Set file URL to trigger share sheet
            exportedFileURL = tempURL
            showingShareSheet = true

            logger.info("🎉 [EXPORT] Export complete - Ready to share")

        } catch let error as ExportError {
            logger.error("❌ [EXPORT] Export error: \(error.errorDescription ?? "unknown")")
            validationMessage = error.errorDescription
            showingValidationError = true
        } catch {
            logger.error("❌ [EXPORT] Unexpected error: \(error.localizedDescription)")
            validationMessage = "Export failed: \(error.localizedDescription)"
            showingValidationError = true
        }

        isExporting = false
    }

    /// Set date range to predefined period
    func setDateRange(_ period: DateRangePeriod) {
        endDate = Date()

        switch period {
        case .last7Days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .last30Days:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        case .last90Days:
            startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        case .lastYear:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }

        logger.info("📅 [DATE-RANGE] Set to \(period.rawValue): \(self.dateRangeDescription)")

        // Auto-validate after changing range
        Task {
            await validateExport()
        }
    }
}

// MARK: - Supporting Types

enum DateRangePeriod: String, CaseIterable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"
    case lastYear = "Last Year"
}
