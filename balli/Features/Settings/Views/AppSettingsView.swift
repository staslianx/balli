//
//  AppSettingsView.swift
//  balli
//
//  App settings and configuration view
//

import SwiftUI
import HealthKit
import OSLog

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.userManager) private var userManager
    @Environment(\.managedObjectContext) private var viewContext

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "settings")

    @State private var notificationsEnabled = true
    @State private var selectedLanguage = "Türkçe"
    @AppStorage("selectedTheme") private var selectedTheme = "Sistem"
    @State private var glucoseUnit = "mg/dL"
    @State private var autoScanEnabled = true

    // Developer Settings
    @State private var appSettings = AppSettings.load()
    @State private var showingCleanupDialog = false
    @State private var showingDataSummary = false
    @State private var dataSummary: DeveloperDataSummary?
    @ObservedObject private var developerDataManager = DeveloperDataManager.shared

    // Activity Sync
    @State private var isBackfilling = false
    @StateObject private var activityService = ActivitySyncService(
        healthStore: HKHealthStore(),
        authManager: HealthKitAuthorizationManager(healthStore: HKHealthStore())
    )
    
    // Developer mode visibility - always show the toggle so users can enable it
    private var showDeveloperSettings: Bool {
        true // Always show so users can access the toggle
    }
    
    let languages = ["Türkçe", "English"]
    let themes = ["Sistem", "Açık", "Koyu"]
    let glucoseUnits = ["mg/dL", "mmol/L"]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Hesap (Account)
                Section("Hesap") {
                    AccountProfileSection(
                        userManager: userManager,
                        colorScheme: colorScheme
                    )
                }

                // MARK: - Genel (General)
                Section("Genel") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Bildirimler", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    Picker(selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    } label: {
                        Label("Görünüş", systemImage: "circle.lefthalf.striped.horizontal.inverse")
                    }
                    .tint(AppTheme.primaryPurple)
                    .onChange(of: selectedTheme) { _, newValue in
                        updateAppearance(newValue)
                    }
                }

                // MARK: - Veri (Data)
                Section("Veri") {
                    NavigationLink(destination: DexcomConnectionView()) {
                        Label("Dexcom", systemImage: "sensor.tag.radiowaves.forward.fill")
                            .imageScale(.medium)
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: HealthKitManagerView()) {
                        Label("Apple Sağlık", systemImage: "heart.text.square.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: ActivityDetailView(
                        isBackfilling: $isBackfilling,
                        backfillProgress: activityService.backfillProgress,
                        backfillStatus: activityService.backfillStatus,
                        onRefresh: refreshActivityHistory
                    )) {
                        HStack {
                            Label("Aktivite", systemImage: "figure.walk")
                            if isBackfilling {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8, anchor: .center)
                            }
                        }
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: DataExportView()) {
                        Label("Verileri Dışa Aktar", systemImage: "square.and.arrow.up.fill")
                    }
                    .tint(AppTheme.primaryPurple)
                }

                // MARK: - Uygulama Bilgisi (App Info)
                Section("Uygulama Bilgisi") {
                    HStack {
                        Label("Sürüm", systemImage: "app.badge.fill")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        openMessagesApp(email: "stasli.anx@icloud.com")
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(AppTheme.primaryPurple)
                            Text("İletişim")
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: AboutView()) {
                        Label("Hakkında", systemImage: "info.circle.fill")
                    }
                    .tint(AppTheme.primaryPurple)
                }

                // MARK: - User Actions
                Section {
                    AccountActionsSection(
                        userManager: userManager,
                        onDismiss: { dismiss() }
                    )
                }

                // MARK: - Tanı (Diagnostics)
                Section("Tanı") {
                    NavigationLink(destination: DexcomDiagnosticsView()) {
                        Label("Dexcom Log", systemImage: "stethoscope.circle.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: AIDiagnosticsView()) {
                        Label("AI Log", systemImage: "brain.fill")
                    }
                    .tint(AppTheme.primaryPurple)
                }

                // MARK: - Developer Settings (if enabled)
                if showDeveloperSettings {
                    DeveloperModeSection(
                        appSettings: $appSettings,
                        showingCleanupDialog: $showingCleanupDialog,
                        showingDataSummary: $showingDataSummary,
                        dataSummary: $dataSummary,
                        developerDataManager: developerDataManager,
                        userManager: userManager,
                        colorScheme: colorScheme,
                        logger: logger
                    )
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateAppearance(selectedTheme)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
        .captureWindow() // Capture window for child views (DexcomConnectionView OAuth)
    }

    // MARK: - Messages Helper

    private func openMessagesApp(email: String) {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let messagesURL = URL(string: "imessage:\(encodedEmail)") {
            UIApplication.shared.open(messagesURL)
        }
    }

    // MARK: - Theme Management

    private func updateAppearance(_ theme: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        for window in windowScene.windows {
            switch theme {
            case "Açık":
                window.overrideUserInterfaceStyle = .light
            case "Koyu":
                window.overrideUserInterfaceStyle = .dark
            default: // "Sistem"
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    // MARK: - Recipe Preview Helpers

    private var tamarindLassiRecipe: RecipeDetailData { RecipePreviewFactory.tamarindLassi }
    private var avocadoToastRecipe: RecipeDetailData { RecipePreviewFactory.avocadoToast }
    private var chocolateCakeRecipe: RecipeDetailData { RecipePreviewFactory.chocolateCake }
    private var greekSaladRecipe: RecipeDetailData { RecipePreviewFactory.greekSalad }
    private var smoothieBowlRecipe: RecipeDetailData { RecipePreviewFactory.smoothieBowl }

    // MARK: - Activity Sync Helper

    private func refreshActivityHistory() async {
        isBackfilling = true

        do {
            // Clear the 7-day check to force refresh
            UserDefaults.standard.removeObject(forKey: "ActivityBackfillDate")
            try await activityService.backfillHistoricalData(days: 90)

            logger.info("✅ Manual activity backfill completed")
        } catch {
            logger.error("❌ Manual activity backfill failed: \(error.localizedDescription)")
        }

        isBackfilling = false
    }
}

// MARK: - Activity Detail View

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isBackfilling: Bool
    let backfillProgress: Double
    let backfillStatus: String
    let onRefresh: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktivite Geçmişi") {
                    if let backfillDate = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as? Date,
                       let backfillDays = UserDefaults.standard.object(forKey: "ActivityBackfillDays") as? Int {

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(backfillDays) günlük verisi")
                                    .font(.subheadline)
                                Text("Son senkronizasyon: \(backfillDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        Text("Henüz hiçbir verisi senkronize edilmedi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        Task {
                            await onRefresh()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Son 90 Günü Senkronize Et")
                            if isBackfilling {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8, anchor: .center)
                            }
                        }
                    }
                    .disabled(isBackfilling)

                    if isBackfilling {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: backfillProgress)
                            Text(backfillStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Aktivite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
    }
}

// MARK: - Recipe Preview Row Component

struct RecipePreviewRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.2))
                )

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AppSettingsView()
}
