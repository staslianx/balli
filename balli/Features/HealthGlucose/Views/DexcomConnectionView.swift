//
//  DexcomConnectionView.swift
//  balli
//
//  Dexcom CGM connection UI with iOS 26 Liquid Glass design
//  Swift 6 strict concurrency compliant
//
//  JUSTIFICATION FOR UIKIT USAGE:
//  ASWebAuthenticationSession (required for Dexcom OAuth) needs a UIWindow as presentation anchor.
//  We import UIKit to access UIApplication.shared.connectedScenes as a fallback when the
//  SwiftUI environment window is not available (timing issue with environment propagation).
//  This is the recommended approach per Apple's ASWebAuthenticationSession documentation.
//

import SwiftUI
import UIKit
import AuthenticationServices
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
    category: "DexcomConnection"
)

@MainActor
struct DexcomConnectionView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.window) private var window // Captured by .captureWindow() modifier
    @ObservedObject private var dexcomService: DexcomService

    // MARK: - State

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var showingShareSettings = false

    // MARK: - Initialization

    /// Primary initializer accepting concrete type for dependency injection
    init(dexcomService: DexcomService) {
        self.dexcomService = dexcomService
    }

    /// Default initializer for standard app usage
    /// - Note: Force cast is unavoidable due to Swift's @ObservedObject limitation with protocols
    init() {
        // Swift limitation: @ObservedObject requires concrete type, not protocol
        // Force cast is centralized here to enable testing via primary init
        self.init(dexcomService: DependencyContainer.shared.dexcomService as! DexcomService)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if dexcomService.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        }
        .navigationTitle("Dexcom CGM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Tamam") {
                    dismiss()
                }
            }
        }
        .alert("Bağlantı Hatası", isPresented: $showingError) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        // REMOVED: .task { await checkConnectionStatus() }
        // REASON: DexcomService already checks on init AND this caused 7-8 redundant checks per second
        // Connection status is updated automatically when service state changes via @Published
        .captureWindow() // Capture window for OAuth flow - ensures window is available even when pushed via NavigationLink
        .onAppear {
            logger.debug("🔍 DexcomConnectionView appeared")
            logger.debug("🔍 Window state: \(window == nil ? "NIL" : "CAPTURED")")
            if let window = window {
                logger.debug("🔍 Window details: \(window.debugDescription)")
            }
        }
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("dexcom-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 32)

            VStack(spacing: 24) {
                Text("Kan şekeri ölçümlerini senkronize et.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Connect Button
                if isConnecting {
                    ProgressView("Bağlanıyor...")
                        .tint(AppTheme.dexcomGreen)
                } else {
                    Button(action: connect) {
                        Text("Bağlan")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.dexcomGreen)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        Form {
            // Connection Status
            Section {
                HStack {
                    Image("dexcom-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Bağlı")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let reading = dexcomService.latestReading {
                    HStack {
                        Text("Son Okuma")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(reading.value)")
                                .fontWeight(.semibold)
                            Text("mg/dL")
                                .foregroundStyle(.secondary)
                            Image(systemName: reading.trendSymbol)
                                .foregroundStyle(AppTheme.dexcomGreen)
                        }
                    }

                    HStack {
                        Text("Trend")
                        Spacer()
                        Text(reading.trendDescription)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Zaman")
                        Spacer()
                        Text(reading.displayTime.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Son Senkronizasyon")
                    Spacer()
                    if let lastSync = dexcomService.lastSync {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Hiçbir Zaman")
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Bağlantı")
            }

            // Device Info
            if let device = dexcomService.currentDevice {
                Section {
                    HStack {
                        Text("Verici")
                        Spacer()
                        Text(device.transmitterGeneration.uppercased())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Ekran Cihazı")
                        Spacer()
                        Text(device.displayDevice)
                            .foregroundStyle(.secondary)
                    }

                    if let unit = device.unitDisplayMode {
                        HStack {
                            Text("Birim")
                            Spacer()
                            Text(unit)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Cihaz Bilgisi")
                }
            }

            // Actions
            Section {
                Button(action: syncNow) {
                    Label("Şimdi Senkronize Et", systemImage: "arrow.triangle.2.circlepath")
                }
                .foregroundStyle(.primary)
                .disabled(isConnecting)

                NavigationLink(destination: DexcomShareSettingsView()) {
                    Label("Gerçek Zamanlı Mod", systemImage: "bolt.fill")
                }
                .foregroundStyle(.primary)

                Button(role: .destructive, action: disconnectAlert) {
                    Label("Bağlantıyı Kes", systemImage: "xmark.circle")
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Component Views

    private func glucoseReadingCard(_ reading: DexcomGlucoseReading) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                // Glucose Value
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reading.value)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("mg/dL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Trend Arrow
                VStack(spacing: 8) {
                    Image(systemName: reading.trendSymbol)
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.dexcomGreen)

                    Text(reading.trendDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Timestamp
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(reading.displayTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("3s gecikme")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
    }

    private func deviceInfoCard(_ device: DexcomDevice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cihaz Bilgileri", systemImage: device.deviceIcon)
                .font(.headline)

            VStack(spacing: 8) {
                infoRow(label: "Model", value: device.deviceName)
                infoRow(label: "Ekran", value: device.displayDevice)
                infoRow(label: "Birim", value: device.unitDisplayMode ?? "mg/dL")
                infoRow(label: "Son Yükleme", value: device.lastUploadDate.formatted(date: .omitted, time: .shortened))
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Senkronizasyon Durumu", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)

            VStack(spacing: 8) {
                infoRow(
                    label: "Durum",
                    value: dexcomService.statusDescription,
                    valueColor: dexcomService.isConnected ? .green : .secondary
                )

                if let lastSync = dexcomService.lastSync {
                    infoRow(
                        label: "Son Senkronizasyon",
                        value: lastSync.formatted(date: .omitted, time: .shortened)
                    )
                }

                infoRow(
                    label: "Arka Plan Senkronizasyonu",
                    value: "Etkin"
                )
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.dexcomGreen)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func noticeCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func infoRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Actions

    private func connect() {
        isConnecting = true

        Task {
            do {
                logger.debug("🔵 handleConnectButtonTap called")
                logger.debug("🔵 Checking window availability...")

                // Try environment window first, fallback to direct window scene access
                let presentationWindow: UIWindow

                if let envWindow = window {
                    logger.debug("✅ Using window from environment: \(envWindow.debugDescription)")
                    presentationWindow = envWindow
                } else {
                    // Fallback: Get window directly from active window scene
                    logger.warning("⚠️ Window not in environment, attempting direct window scene access...")

                    guard let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                          let sceneWindow = scene.windows.first(where: { $0.isKeyWindow }) else {
                        logger.error("❌ Failed to get window from window scene")
                        throw DexcomError.invalidConfiguration
                    }

                    logger.debug("✅ Using window from window scene: \(sceneWindow.debugDescription)")
                    presentationWindow = sceneWindow
                }

                logger.debug("🔵 Starting Dexcom authorization flow...")
                try await dexcomService.connect(presentationAnchor: presentationWindow)
                logger.debug("✅ Dexcom Official API connection successful")

                // AUTO-CONNECT: Automatically connect SHARE API for real-time data
                logger.debug("🔵 Auto-connecting SHARE API with hardcoded credentials...")
                await autoConnectShareAPI()

            } catch let error as DexcomError {
                logger.error("DexcomError - \(error.errorDescription ?? "Unknown error")")
                errorMessage = error.errorDescription ?? "Dexcom'a bağlanılamadı. Lütfen tekrar deneyin."
                showingError = true
            } catch {
                // Map generic errors to user-friendly messages
                logger.error("Generic error - \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        errorMessage = "İnternet bağlantısı yok. Lütfen ağ bağlantınızı kontrol edin."
                    case .timedOut:
                        errorMessage = "Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin."
                    default:
                        errorMessage = "Ağ hatası. Lütfen internet bağlantınızı kontrol edin."
                    }
                } else {
                    errorMessage = "Dexcom'a bağlanırken hata oluştu. Lütfen tekrar deneyin."
                }
                showingError = true
            }

            isConnecting = false
        }
    }

    /// Automatically connect SHARE API using hardcoded credentials
    /// This runs after Official API connection succeeds
    private func autoConnectShareAPI() async {
        logger.info("🔄 AUTO-CONNECT: Starting automatic SHARE API connection")

        // Get credentials from configuration (loaded from Secrets.xcconfig)
        guard let credentials = DexcomConfiguration.shareCredentials else {
            logger.warning("⚠️ AUTO-CONNECT: No SHARE credentials configured in Secrets.xcconfig")
            logger.info("ℹ️ SHARE API auto-connect skipped - only Official API will be used")
            return
        }

        // Use protocol type - connect() is part of DexcomShareServiceProtocol
        let shareService = DependencyContainer.shared.dexcomShareService

        logger.info("🔄 AUTO-CONNECT: Using \(credentials.server) server")

        do {
            // Attempt to connect with credentials from Secrets.xcconfig
            try await shareService.connect(
                username: credentials.username,
                password: credentials.password
            )

            logger.info("✅ AUTO-CONNECT: SHARE API connected successfully")
            logger.info("📊 Complete timeline now available: SHARE (0-3h) + Official (3h+)")

        } catch {
            // Don't fail the overall connection if SHARE fails
            // Official API still works for historical data
            logger.warning("⚠️ AUTO-CONNECT: SHARE API connection failed: \(error.localizedDescription)")
            logger.info("📊 Official API connected - historical data available (3h+)")
            logger.info("💡 SHARE connection can be retried manually in settings")
        }
    }

    private func syncNow() {
        isConnecting = true

        Task {
            do {
                try await dexcomService.syncData()
            } catch let error as DexcomError {
                errorMessage = error.errorDescription ?? "Veri senkronize edilemedi. Lütfen tekrar deneyin."
                showingError = true
            } catch {
                // Map generic errors to user-friendly messages
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        errorMessage = "İnternet bağlantısı yok. Senkronizasyon için ağ gerekli."
                    case .timedOut:
                        errorMessage = "Senkronizasyon zaman aşımına uğradı. Lütfen tekrar deneyin."
                    default:
                        errorMessage = "Ağ hatası. Veri senkronize edilemedi."
                    }
                } else {
                    errorMessage = "Veri senkronize edilemedi. Lütfen tekrar deneyin."
                }
                showingError = true
            }

            isConnecting = false
        }
    }

    private func disconnectAlert() {
        // In a real app, show a confirmation alert
        Task {
            do {
                try await dexcomService.disconnect()
            } catch let error as DexcomError {
                errorMessage = error.errorDescription ?? "Bağlantı kesilemedi. Lütfen tekrar deneyin."
                showingError = true
            } catch {
                errorMessage = "Bağlantı kesilirken hata oluştu. Lütfen tekrar deneyin."
                showingError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DexcomConnectionView()
        .injectDependencies()
}
