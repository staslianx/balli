//
//  DexcomDiagnosticsView.swift
//  balli
//
//  Diagnostic view for Dexcom connection issues
//  Displays logs, statistics, and export functionality
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

struct DexcomDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [DexcomDiagnosticsLogger.LogEntry] = []
    @State private var statistics: DexcomDiagnosticsLogger.LogStatistics?
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedCategory: CategoryFilter = .all
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingClearConfirmation = false
    @State private var isRefreshing = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "Settings"
    )

    enum TimeRange: String, CaseIterable {
        case last1Hour = "Last Hour"
        case last6Hours = "Last 6 Hours"
        case last24Hours = "Last 24 Hours"
        case all = "All Time"

        var hours: Int? {
            switch self {
            case .last1Hour: return 1
            case .last6Hours: return 6
            case .last24Hours: return 24
            case .all: return nil
            }
        }
    }

    enum CategoryFilter: String, CaseIterable {
        case all = "All"
        case authentication = "Auth"
        case connection = "Connection"
        case tokenRefresh = "Token Refresh"
        case errors = "Errors Only"

        func filter(_ logs: [DexcomDiagnosticsLogger.LogEntry]) -> [DexcomDiagnosticsLogger.LogEntry] {
            switch self {
            case .all:
                return logs
            case .authentication:
                return logs.filter { $0.category == .authentication }
            case .connection:
                return logs.filter { $0.category == .connection }
            case .tokenRefresh:
                return logs.filter { $0.category == .tokenRefresh }
            case .errors:
                return logs.filter { $0.level == .error }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics Header
                if let stats = statistics {
                    statisticsHeader(stats)
                }

                // Filters
                filterSection

                Divider()

                // Logs List
                logsList

            }
            .navigationTitle("Dexcom Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await exportLogs(format: .text)
                            }
                        } label: {
                            Label("Export as Text", systemImage: "doc.text")
                        }

                        Button {
                            Task {
                                await exportLogs(format: .json)
                            }
                        } label: {
                            Label("Export as JSON", systemImage: "doc.badge.gearshape")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear All Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                await loadLogs()
            }
            .refreshable {
                await loadLogs()
            }
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                exportURL = nil
            }) {
                if let url = exportURL {
                    DiagnosticsShareSheet(items: [url])
                }
            }
            .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    Task {
                        await clearLogs()
                    }
                }
            } message: {
                Text("This will permanently delete all Dexcom diagnostic logs. This action cannot be undone.")
            }
        }
    }

    // MARK: - Statistics Header

    @ViewBuilder
    private func statisticsHeader(_ stats: DexcomDiagnosticsLogger.LogStatistics) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatBox(title: "Total", value: "\(stats.totalLogs)", color: .blue)
                StatBox(title: "Errors", value: "\(stats.errorCount)", color: .red)
                StatBox(title: "Warnings", value: "\(stats.warningCount)", color: .orange)
                StatBox(title: "Duration", value: stats.durationDescription, color: .green)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if stats.totalLogs == 0 {
                Text("No logs captured yet. Logs will appear as you use Dexcom features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Filters

    @ViewBuilder
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Category Filter
            Picker("Category", selection: $selectedCategory) {
                ForEach(CategoryFilter.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onChange(of: selectedTimeRange) { _, _ in
            Task { await loadLogs() }
        }
        .onChange(of: selectedCategory) { _, _ in
            Task { await loadLogs() }
        }
    }

    // MARK: - Logs List

    @ViewBuilder
    private var logsList: some View {
        if logs.isEmpty {
            ContentUnavailableView {
                Label("No Logs", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("No logs match the selected filters")
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(AppTheme.primaryPurple)
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(logs) { log in
                    LogEntryRow(log: log)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Actions

    private func loadLogs() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let diagnosticsLogger = DexcomDiagnosticsLogger.shared

        // Get logs based on time range
        let allLogs: [DexcomDiagnosticsLogger.LogEntry]
        if let hours = selectedTimeRange.hours {
            allLogs = await diagnosticsLogger.getLogsFromLastHours(hours)
        } else {
            allLogs = await diagnosticsLogger.getAllLogs()
        }

        // Apply category filter
        logs = selectedCategory.filter(allLogs)

        // Get statistics
        statistics = await diagnosticsLogger.getStatistics()
    }

    private func exportLogs(format: DexcomDiagnosticsLogger.ExportFormat) async {
        do {
            let url = try await DexcomDiagnosticsLogger.shared.saveLogsToFile(format: format)
            exportURL = url
            showingShareSheet = true
        } catch {
            logger.error("Failed to export logs: \(error.localizedDescription)")
        }
    }

    private func clearLogs() async {
        await DexcomDiagnosticsLogger.shared.clearLogs()
        await loadLogs()
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LogEntryRow: View {
    let log: DexcomDiagnosticsLogger.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.level.rawValue)
                    .font(.body)
                Text(log.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .foregroundStyle(categoryColor)
                    .clipShape(Capsule())

                Spacer()

                Text(log.formattedTimestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(log.message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch log.category {
        case .authentication: return .blue
        case .connection: return .green
        case .tokenRefresh: return .purple
        case .dataSync: return .orange
        case .keychain: return .red
        case .lifecycle: return .cyan
        case .repository: return .pink
        }
    }
}

struct DiagnosticsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    DexcomDiagnosticsView()
}
