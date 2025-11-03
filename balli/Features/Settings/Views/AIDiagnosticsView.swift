//
//  AIDiagnosticsView.swift
//  balli
//
//  View for displaying AI operations diagnostic logs
//  Swift 6 strict concurrency compliant
//

import SwiftUI

@MainActor
struct AIDiagnosticsView: View {

    // MARK: - State

    @State private var logs: [AIDiagnosticsLogger.LogEntry] = []
    @State private var statistics: AIDiagnosticsLogger.LogStatistics?
    @State private var selectedTimeRange: TimeRange = .all
    @State private var selectedCategory: AIDiagnosticsLogger.LogEntry.LogCategory?
    @State private var selectedLevel: AIDiagnosticsLogger.LogEntry.LogLevel?
    @State private var isExporting = false
    @State private var exportFormat: AIDiagnosticsLogger.ExportFormat = .json
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var showClearConfirmation = false

    // MARK: - Time Range

    enum TimeRange: String, CaseIterable {
        case lastHour = "Son 1 Saat"
        case last6Hours = "Son 6 Saat"
        case last24Hours = "Son 24 Saat"
        case all = "Tümü"

        var hours: Int? {
            switch self {
            case .lastHour: return 1
            case .last6Hours: return 6
            case .last24Hours: return 24
            case .all: return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Statistics Section
            if let stats = statistics {
                statisticsSection(stats)
            }

            // Filters Section
            filtersSection

            // Logs Section
            logsSection

            // Export Section
            exportSection
        }
        .navigationTitle("AI Tanılama")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive, action: { showClearConfirmation = true }) {
                        Label("Kayıtları Temizle", systemImage: "trash")
                    }
                    Button(action: refreshLogs) {
                        Label("Yenile", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Kayıtları Temizle", isPresented: $showClearConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Temizle", role: .destructive) {
                Task { await clearLogs() }
            }
        } message: {
            Text("Tüm AI tanılama kayıtları silinecek. Bu işlem geri alınamaz.")
        }
        .alert("Hata", isPresented: .constant(errorMessage != nil)) {
            Button("Tamam") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                AIShareSheet(items: [url])
            }
        }
        .task {
            await loadLogs()
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private func statisticsSection(_ stats: AIDiagnosticsLogger.LogStatistics) -> some View {
        Section("İstatistikler") {
            VStack(alignment: .leading, spacing: 12) {
                StatRow(label: "Toplam Kayıt", value: "\(stats.totalLogs)")
                StatRow(label: "Hatalar", value: "\(stats.errorCount)", color: stats.errorCount > 0 ? .red : nil)
                StatRow(label: "Uyarılar", value: "\(stats.warningCount)", color: stats.warningCount > 0 ? .orange : nil)
                StatRow(label: "Kayıt Süresi", value: stats.durationDescription)

                Divider()
                    .padding(.vertical, 4)

                Text("Kategorilere Göre")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                StatRow(label: "🍞 Maya Analizi", value: "\(stats.leavenAnalysisCount)")
                StatRow(label: "🥗 Besin Hesaplama", value: "\(stats.nutritionCalculationCount)")
                StatRow(label: "📝 Tarif Oluşturma", value: "\(stats.recipeGenerationCount)")
                StatRow(label: "🔬 Araştırma", value: "\(stats.researchCount)")
                StatRow(label: "🤖 Gemini API", value: "\(stats.geminiAPICallCount)")
                StatRow(label: "📡 Streaming", value: "\(stats.streamingEventCount)")
                StatRow(label: "📸 Görüntü İşleme", value: "\(stats.imageProcessingCount)")
                StatRow(label: "⚠️ Hata Yönetimi", value: "\(stats.errorHandlingCount)")
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        Section("Filtreler") {
            // Time Range Filter
            Picker("Zaman Aralığı", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task { await loadLogs() }
            }

            // Category Filter
            Picker("Kategori", selection: $selectedCategory) {
                Text("Tümü").tag(nil as AIDiagnosticsLogger.LogEntry.LogCategory?)
                ForEach([
                    AIDiagnosticsLogger.LogEntry.LogCategory.leavenAnalysis,
                    .nutritionCalculation,
                    .recipeGeneration,
                    .research,
                    .geminiAPI,
                    .streaming,
                    .imageProcessing,
                    .errorHandling,
                    .performance
                ], id: \.self) { category in
                    Text(category.rawValue).tag(category as AIDiagnosticsLogger.LogEntry.LogCategory?)
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                Task { await loadLogs() }
            }

            // Level Filter
            Picker("Seviye", selection: $selectedLevel) {
                Text("Tümü").tag(nil as AIDiagnosticsLogger.LogEntry.LogLevel?)
                ForEach([
                    AIDiagnosticsLogger.LogEntry.LogLevel.error,
                    .warning,
                    .info,
                    .success,
                    .debug
                ], id: \.self) { level in
                    Text("\(level.rawValue) \(levelName(level))").tag(level as AIDiagnosticsLogger.LogEntry.LogLevel?)
                }
            }
            .onChange(of: selectedLevel) { _, _ in
                Task { await loadLogs() }
            }
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        Section {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Kayıt Yok",
                    systemImage: "tray",
                    description: Text("Seçilen filtrelere uygun AI tanılama kaydı bulunamadı.")
                )
            } else {
                ForEach(logs) { log in
                    AILogEntryRow(entry: log)
                }
            }
        } header: {
            HStack {
                Text("Kayıtlar")
                Spacer()
                Text("\(logs.count) kayıt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Dışa Aktar") {
            Picker("Format", selection: $exportFormat) {
                Text("JSON").tag(AIDiagnosticsLogger.ExportFormat.json)
                Text("Metin").tag(AIDiagnosticsLogger.ExportFormat.text)
            }
            .pickerStyle(.segmented)

            Button(action: { Task { await exportLogs() } }) {
                if isExporting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Dışa Aktarılıyor...")
                    }
                } else {
                    Label("Kayıtları Dışa Aktar", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isExporting || logs.isEmpty)
        }
    }

    // MARK: - Helper Methods

    private func levelName(_ level: AIDiagnosticsLogger.LogEntry.LogLevel) -> String {
        switch level {
        case .error: return "Hata"
        case .warning: return "Uyarı"
        case .info: return "Bilgi"
        case .success: return "Başarılı"
        case .debug: return "Hata Ayıklama"
        }
    }

    private func loadLogs() async {
        var fetchedLogs = await AIDiagnosticsLogger.shared.getAllLogs()

        // Apply time range filter
        if let hours = selectedTimeRange.hours {
            fetchedLogs = await AIDiagnosticsLogger.shared.getLogsFromLastHours(hours)
        }

        // Apply category filter
        if let category = selectedCategory {
            fetchedLogs = fetchedLogs.filter { $0.category == category }
        }

        // Apply level filter
        if let level = selectedLevel {
            fetchedLogs = fetchedLogs.filter { $0.level == level }
        }

        self.logs = fetchedLogs
        self.statistics = await AIDiagnosticsLogger.shared.getStatistics()
    }

    private func refreshLogs() {
        Task {
            await loadLogs()
        }
    }

    private func exportLogs() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await AIDiagnosticsLogger.shared.saveLogsToFile(format: exportFormat)
            self.exportURL = url
            self.showShareSheet = true
        } catch {
            self.errorMessage = "Dışa aktarma başarısız: \(error.localizedDescription)"
        }
    }

    private func clearLogs() async {
        await AIDiagnosticsLogger.shared.clearLogs()
        await loadLogs()
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color ?? .primary)
        }
        .font(.subheadline)
    }
}

private struct AILogEntryRow: View {
    let entry: AIDiagnosticsLogger.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: timestamp, level, category
            HStack(spacing: 8) {
                Text(entry.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()

                Text(entry.level.rawValue)
                    .font(.caption2)

                Text(entry.category.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Message
            Text(entry.message)
                .font(.footnote)
                .foregroundStyle(levelColor(entry.level))

            // Operation ID (if present)
            if let operationId = entry.operationId {
                Text("İşlem: \(operationId.prefix(12))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            // Metadata (if present)
            if let metadata = entry.metadata, !metadata.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                        if let value = metadata[key] {
                            HStack(spacing: 4) {
                                Text(key)
                                    .fontWeight(.medium)
                                Text(":")
                                Text(value)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private func levelColor(_ level: AIDiagnosticsLogger.LogEntry.LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .primary
        case .success: return .green
        case .debug: return .secondary
        }
    }
}

// MARK: - Share Sheet

private struct AIShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("AI Diagnostics View") {
    NavigationStack {
        AIDiagnosticsView()
    }
}

#Preview("AI Diagnostics View - Dark") {
    NavigationStack {
        AIDiagnosticsView()
    }
    .preferredColorScheme(.dark)
}
