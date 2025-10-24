//
//  DexcomShareSettingsView.swift
//  balli
//
//  Settings screen for Dexcom SHARE API configuration
//  Enables Real-Time Mode with ~5 minute glucose data delay
//

import SwiftUI

struct DexcomShareSettingsView: View {
    @ObservedObject private var shareService = DexcomShareService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedServer: DexcomShareServer = .international
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    @AppStorage("isRealTimeModeEnabled") private var isRealTimeModeEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                // Real-Time Mode Section
                Section {
                    Toggle("Gerçek Zamanlı Mod", isOn: $isRealTimeModeEnabled)

                    if isRealTimeModeEnabled {
                        Label {
                            Text("~5 dakika gecikme ile anlık veriler")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Label {
                            Text("3 saat AB düzenleyici gecikmesi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Veri Modu")
                } footer: {
                    Text("Gerçek Zamanlı Mod, öğün korelasyonu için ~5 dakika gecikme ile kan şekeri verisi sağlar. Resmi API yerine Dexcom SHARE API'sini kullanır.")
                }

                // Connection Status
                Section {
                    HStack {
                        Text("Durum")
                        Spacer()
                        ConnectionStatusBadge(status: shareService.connectionStatus)
                    }

                    if shareService.isConnected, let lastSync = shareService.lastSync {
                        HStack {
                            Text("Son Senkronizasyon")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let reading = shareService.latestReading {
                        HStack {
                            Text("Son Okuma")
                            Spacer()
                            HStack(spacing: 4) {
                                Text("\(reading.Value)")
                                    .fontWeight(.semibold)
                                Text("mg/dL")
                                    .foregroundStyle(.secondary)
                                Image(systemName: reading.trendSymbol)
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                        }
                    }
                } header: {
                    Text("Bağlantı")
                }

                // Credentials Section (only if Real-Time Mode enabled)
                if isRealTimeModeEnabled {
                    Section {
                        if shareService.isConnected {
                            // Show connected state with masked credentials
                            HStack {
                                Text("Kullanıcı Adı")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("••••••")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Şifre")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("••••••••")
                                    .foregroundStyle(.secondary)
                            }

                            Picker("Sunucu", selection: $selectedServer) {
                                Text("International (Non-US)").tag(DexcomShareServer.international)
                                Text("United States").tag(DexcomShareServer.us)
                            }
                            .disabled(true)

                            Button(role: .destructive, action: disconnect) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Bağlantıyı Kes")
                                }
                            }
                            .disabled(isConnecting)
                        } else {
                            // Show credential input fields when not connected
                            TextField("Kullanıcı Adı", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .disabled(isConnecting)

                            SecureField("Şifre", text: $password)
                                .textContentType(.password)
                                .disabled(isConnecting)

                            Picker("Sunucu", selection: $selectedServer) {
                                Text("International (Non-US)").tag(DexcomShareServer.international)
                                Text("United States").tag(DexcomShareServer.us)
                            }
                            .disabled(isConnecting)

                            Button(action: testConnection) {
                                HStack {
                                    if isConnecting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "link.circle")
                                    }
                                    Text("Bağlan")
                                }
                            }
                            .disabled(username.isEmpty || password.isEmpty || isConnecting)
                        }
                    } header: {
                        Text("Dexcom SHARE Hesabı")
                    } footer: {
                        if shareService.isConnected {
                            Text("Kimlik bilgileriniz güvenli bir şekilde saklanıyor.")
                        } else {
                            Text("Dexcom mobil uygulamanızda kullandığınız kullanıcı adı ve şifre. SHARE takipçi hesabı değil, ana hesap bilgileri.")
                        }
                    }
                }
            }
            .navigationTitle("Dexcom SHARE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tamam") {
                        dismiss()
                    }
                }
            }
            .alert("Hata", isPresented: $showingError) {
                Button("Tamam", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Başarılı", isPresented: $showingSuccess) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Dexcom SHARE bağlantısı başarılı! Artık gerçek zamanlı kan şekeri verileri alabilirsiniz.")
            }
            .task {
                // Load existing credentials if available
                await loadExistingCredentials()
            }
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isConnecting = true
        errorMessage = nil

        Task {
            do {
                try await shareService.connect(username: username, password: password)

                // Auto-enable Real-Time Mode on successful connection
                isRealTimeModeEnabled = true

                showingSuccess = true
                isConnecting = false
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                isConnecting = false
            }
        }
    }

    private func disconnect() {
        isConnecting = true

        Task {
            do {
                try await shareService.disconnect()
                username = ""
                password = ""
                isConnecting = false
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                isConnecting = false
            }
        }
    }

    private func loadExistingCredentials() async {
        // Check if SHARE service is already connected
        await shareService.checkConnectionStatus()

        // Note: We don't load actual credentials from keychain for security
        // User must re-enter them to make changes
    }
}

// MARK: - Connection Status Badge

struct ConnectionStatusBadge: View {
    let status: DexcomShareService.ConnectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    DexcomShareSettingsView()
}

#Preview("Connected") {
    DexcomShareSettingsView()
}
