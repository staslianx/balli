//
//  HealthKitManagerView.swift
//  balli
//
//  HealthKit permission management UI
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import HealthKit

@MainActor
struct HealthKitManagerView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    @State private var isAuthorized = false
    @State private var isChecking = true
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var glucoseStats: GlucoseStatistics?
    
    var body: some View {
        Group {
            if isChecking {
                loadingView
            } else if isAuthorized {
                authorizedView
            } else {
                unauthorizedView
            }
        }
        .navigationTitle("Sağlık Verileri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Tamam") {
                    dismiss()
                }
            }
        }
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("HealthKit durumu kontrol ediliyor...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var unauthorizedView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 12) {
                    Text("Sağlık Uygulamasına Bağlan")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("balli, Sağlık uygulamasından kan şekeri verilerini okuyarak kan şekeri modellerine göre kişiselleştirilmiş öğün önerileri sunabilir.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 16) {
                    featureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Kan Şekeri Analizleri",
                        description: "Öğünlerin kan şekerinizi nasıl etkilediğini görün"
                    )

                    featureRow(
                        icon: "fork.knife",
                        title: "Akıllı Öneriler",
                        description: "Modellerinize göre öğün önerileri alın"
                    )

                    featureRow(
                        icon: "moon.fill",
                        title: "Haftalık Özetler",
                        description: "Kan şekeri trendlerinizin otomatik raporları"
                    )
                }
                .padding(.vertical, 24)

                Spacer()
                    .frame(height: 40)

                VStack(spacing: 12) {
                    Button(action: requestAuthorization) {
                        Label("HealthKit'i Bağla", systemImage: "heart.fill")
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)

                    Text("Sağlık verilerin güvende kalır ve yalnızca balli içinde kullanılır")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }
    
    private var authorizedView: some View {
        Form {
            // Connection Status
            Section("Bağlantı") {
                HStack {
                    Text("Durum")
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

                HStack {
                    Text("Veri Erişimi")
                    Spacer()
                    Text("Sadece Okuma")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Arka Plan Güncellemeleri")
                    Spacer()
                    Text("Etkin")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Son Senkronizasyon")
                    Spacer()
                    Text(Date().formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            // Glucose Statistics
            if let stats = glucoseStats {
                Section("Son 7 Gün") {
                    HStack {
                        Text("Ortalama")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f", stats.average))
                                .fontWeight(.semibold)
                            Text("mg/dL")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Hedef Aralık")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f", stats.timeInRange))
                                .fontWeight(.semibold)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Toplam Ölçüm")
                        Spacer()
                        Text("\(stats.readingCount)")
                            .fontWeight(.semibold)
                    }
                }
            }

            // Actions
            Section {
                Button(action: openHealthSettings) {
                    Label("Ayarlarda Yönet", systemImage: "gear")
                }
            }
        }
    }
    
    // MARK: - Helper Views

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func checkAuthorizationStatus() async {
        isChecking = true
        
        // Use unified permission manager for consistent status checking
        let status = await permissionManager.checkPermission(.health)
        isAuthorized = status.isUsable
        
        if isAuthorized {
            // Fetch recent glucose statistics
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            let dateInterval = DateInterval(start: startDate, end: endDate)

            let healthKitService = dependencies.healthKitService
            if let realService = healthKitService as? HealthKitService {
                glucoseStats = try? await realService.getGlucoseStatistics(for: dateInterval)
            }
        }
        
        isChecking = false
    }
    
    private func requestAuthorization() {
        Task {
            // Use unified permission manager for consistent permission handling
            let granted = await permissionManager.requestPermission(.health)
            
            if granted {
                isAuthorized = true
                await checkAuthorizationStatus()
            } else {
                // Check if we need to show settings alert
                let status = permissionManager.status(for: .health)
                if status.needsSettings {
                    errorMessage = "HealthKit yetkilendirmesi daha önce reddedildi. Lütfen Ayarlar'dan etkinleştirin."
                    showingError = true
                } else {
                    errorMessage = "HealthKit yetkilendirmesi verilmedi."
                    showingError = true
                }
            }
        }
    }
    
    private func openHealthSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    HealthKitManagerView()
        .injectDependencies()
}