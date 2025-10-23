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
        NavigationStack {
            VStack(spacing: 24) {
                if isChecking {
                    loadingView
                } else if isAuthorized {
                    authorizedView
                } else {
                    unauthorizedView
                }
            }
            .padding()
            .navigationTitle("Sağlık Verileri")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
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
            
            Text("Checking HealthKit status...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var unauthorizedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 16) {
                Text("Connect to Health")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("balli can read your glucose data from the Health app to provide personalized meal recommendations based on your blood sugar patterns.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                featureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Glucose Insights",
                    description: "See how meals affect your blood sugar"
                )
                
                featureRow(
                    icon: "fork.knife",
                    title: "Smart Recommendations",
                    description: "Get meal suggestions based on your patterns"
                )
                
                featureRow(
                    icon: "moon.fill",
                    title: "Weekly Summaries",
                    description: "Automatic reports of your glucose trends"
                )
            }
            .padding(.vertical)
            
            Spacer()
            
            Button(action: requestAuthorization) {
                Label("Connect HealthKit", systemImage: "heart.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Text("Your health data stays private and is only used within balli")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var authorizedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success Header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("HealthKit Connected")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("balli is reading your glucose data")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Glucose Statistics
                if let stats = glucoseStats {
                    glucoseStatsView(stats)
                }

                // Settings
                VStack(spacing: 16) {
                    settingRow(
                        title: "Data Access",
                        value: "Read Only",
                        icon: "lock.fill"
                    )
                    
                    settingRow(
                        title: "Background Updates",
                        value: "Enabled",
                        icon: "arrow.clockwise"
                    )
                    
                    settingRow(
                        title: "Last Sync",
                        value: Date().formatted(date: .omitted, time: .shortened),
                        icon: "clock.fill"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Manage in Settings
                Button(action: openHealthSettings) {
                    Label("Manage in Settings", systemImage: "gear")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .padding(.top)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func settingRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private func glucoseStatsView(_ stats: GlucoseStatistics) -> some View {
        VStack(spacing: 16) {
            Text("Last 7 Days")
                .font(.headline)
            
            HStack(spacing: 20) {
                statCard(
                    title: "Average",
                    value: String(format: "%.0f", stats.average),
                    unit: "mg/dL",
                    color: .blue
                )
                
                statCard(
                    title: "Time in Range",
                    value: String(format: "%.0f", stats.timeInRange),
                    unit: "%",
                    color: .green
                )
                
                statCard(
                    title: "Readings",
                    value: "\(stats.readingCount)",
                    unit: "total",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    errorMessage = "HealthKit authorization was previously denied. Please enable it in Settings."
                    showingError = true
                } else {
                    errorMessage = "HealthKit authorization was not granted."
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