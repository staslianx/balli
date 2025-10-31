//
//  ResearchStageDiagnosticsView.swift
//  balli
//
//  Diagnostic view for research stage visibility issues
//  Displays comprehensive logs for backend SSE events, stage queue, observer, and UI rendering
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

struct ResearchStageDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [ResearchStageDiagnosticsLogger.LogEntry] = []
    @State private var statistics: ResearchStageDiagnosticsLogger.LogStatistics?
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedCategory: CategoryFilter = .all
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingClearConfirmation = false
    @State private var isRefreshing = false
    @State private var selectedAnswerId: String? = nil

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
        case sseEvent = "SSE Events"
        case stageQueue = "Stage Queue"
        case observer = "Observer"
        case viewRendering = "View Render"
        case timing = "Timing"
        case errorsOnly = "Errors Only"

        func filter(_ logs: [ResearchStageDiagnosticsLogger.LogEntry]) -> [ResearchStageDiagnosticsLogger.LogEntry] {
            switch self {
            case .all:
                return logs
            case .sseEvent:
                return logs.filter { $0.category == .sseEvent }
            case .stageQueue:
                return logs.filter { $0.category == .stageQueue }
            case .observer:
                return logs.filter { $0.category == .observer }
            case .viewRendering:
                return logs.filter { $0.category == .viewRendering }
            case .timing:
                return logs.filter { $0.category == .timing }
            case .errorsOnly:
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
            .navigationTitle("Research Stage Diagnostics")
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
                Text("This will permanently delete all research stage diagnostic logs. This action cannot be undone.")
            }
        }
    }

    // MARK: - Statistics Header

    @ViewBuilder
    private func statisticsHeader(_ stats: ResearchStageDiagnosticsLogger.LogStatistics) -> some View {
        VStack(spacing: 12) {
            // First row: Basic stats
            HStack(spacing: 16) {
                StatBox(title: "Total", value: "\(stats.totalLogs)", color: .blue)
                StatBox(title: "Errors", value: "\(stats.errorCount)", color: .red)
                StatBox(title: "Warnings", value: "\(stats.warningCount)", color: .orange)
                StatBox(title: "Duration", value: stats.durationDescription, color: .green)
            }
            .padding(.horizontal)

            // Second row: Stage-specific stats
            HStack(spacing: 16) {
                SmallStatBox(title: "SSE", value: "\(stats.sseEventCount)", icon: "📡")
                SmallStatBox(title: "Queue", value: "\(stats.stageTransitionCount)", icon: "📋")
                SmallStatBox(title: "Observer", value: "\(stats.observerPollCount)", icon: "👁️")
                SmallStatBox(title: "View", value: "\(stats.viewRenderCount)", icon: "🎨")
                SmallStatBox(title: "Ready", value: "\(stats.viewReadySignalCount)", icon: "🚦")
            }
            .padding(.horizontal)

            if stats.totalLogs == 0 {
                Text("No logs captured yet. Logs will appear as you perform deep research queries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
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
        } else {
            List {
                ForEach(logs) { log in
                    ResearchLogEntryRow(log: log)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Actions

    private func loadLogs() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let diagnosticsLogger = ResearchStageDiagnosticsLogger.shared

        // Get logs based on time range
        let allLogs: [ResearchStageDiagnosticsLogger.LogEntry]
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

    private func exportLogs(format: ResearchStageDiagnosticsLogger.ExportFormat) async {
        do {
            let url = try await ResearchStageDiagnosticsLogger.shared.saveLogsToFile(format: format)
            exportURL = url
            showingShareSheet = true
        } catch {
            logger.error("Failed to export logs: \(error.localizedDescription)")
        }
    }

    private func clearLogs() async {
        await ResearchStageDiagnosticsLogger.shared.clearLogs()
        await loadLogs()
    }
}

// MARK: - Supporting Views

struct SmallStatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ResearchLogEntryRow: View {
    let log: ResearchStageDiagnosticsLogger.LogEntry

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

            if let answerId = log.answerId {
                Text("Answer: \(answerId.prefix(8))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            if let metadata = log.metadata, !metadata.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                        if let value = metadata[key] {
                            Text("\(key): \(value)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch log.category {
        case .sseEvent: return .blue
        case .stageQueue: return .purple
        case .stageTransition: return .green
        case .observer: return .orange
        case .viewRendering: return .pink
        case .viewReadySignal: return .cyan
        case .timing: return .indigo
        case .dataFlow: return .mint
        }
    }
}

// MARK: - Preview

#Preview {
    ResearchStageDiagnosticsView()
}
