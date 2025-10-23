//
//  PermissionsDemoView.swift
//  balli
//
//  Demo view showcasing the unified permission system
//  Shows how all permissions work immediately after being granted
//

import SwiftUI
import AVFoundation
import HealthKit

// MARK: - Demo View for Testing Permissions

struct PermissionsDemoView: View {
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    @State private var testResult = ""
    @State private var isTestingPermission = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Header
                    statusHeader
                    
                    // Permission Cards
                    VStack(spacing: 16) {
                        permissionCard(for: .camera)
                        permissionCard(for: .microphone)
                        permissionCard(for: .health)
                    }
                    .padding(.horizontal)
                    
                    // Test Section
                    testSection
                    
                    // Result Display
                    if !testResult.isEmpty {
                        resultView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Permission System")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Check all permissions on appear
            permissionManager.checkAllPermissions()
        }
    }
    
    // MARK: - Subviews
    
    private var statusHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Unified Permission System")
                .font(.headline)
            
            Text("All permissions work immediately after granting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func permissionCard(for type: PermissionType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: type.systemName)
                    .font(.title2)
                    .foregroundColor(statusColor(for: type))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge(for: type)
            }
            
            // Action Button
            if permissionManager.status(for: type).canRequest {
                Button(action: { requestPermission(type) }) {
                    Label("Request Permission", systemImage: "hand.raised.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else if permissionManager.status(for: type).needsSettings {
                Button(action: { permissionManager.openSettings() }) {
                    Label("Open Settings", systemImage: "gear")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            // Test Button
            if permissionManager.status(for: type).isUsable {
                Button(action: { testPermission(type) }) {
                    Label("Test \(type.rawValue)", systemImage: "play.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
                .disabled(isTestingPermission)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(
                    icon: "arrow.clockwise",
                    text: "Automatic state updates when returning from Settings"
                )
                
                featureRow(
                    icon: "bolt.fill",
                    text: "Immediate functionality after permission grant"
                )
                
                featureRow(
                    icon: "checkmark.shield",
                    text: "No app restart required"
                )
                
                featureRow(
                    icon: "bell.fill",
                    text: "Lifecycle monitoring for all permission changes"
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Test Result", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
            
            Text(testResult)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(for type: PermissionType) -> some View {
        let status = permissionManager.status(for: type)
        
        return Group {
            switch status {
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
            case .restricted:
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
            case .checking:
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
    
    private func statusColor(for type: PermissionType) -> Color {
        switch permissionManager.status(for: type) {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .gray
        case .checking: return .blue
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func requestPermission(_ type: PermissionType) {
        Task {
            isTestingPermission = true
            let granted = await permissionManager.requestPermission(type)
            
            await MainActor.run {
                testResult = "Permission \(type.rawValue): \(granted ? "✅ Granted" : "❌ Denied")"
                isTestingPermission = false
                
                if granted {
                    // Immediately test the permission to show it works
                    testPermission(type)
                }
            }
        }
    }
    
    private func testPermission(_ type: PermissionType) {
        isTestingPermission = true
        testResult = "Testing \(type.rawValue)..."
        
        Task {
            switch type {
            case .camera:
                await testCameraAccess()
            case .microphone:
                await testMicrophoneAccess()
            case .health:
                await testHealthAccess()
            }
            
            await MainActor.run {
                isTestingPermission = false
            }
        }
    }
    
    private func testCameraAccess() async {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            await MainActor.run {
                testResult = "Camera: ❌ Failed to access camera"
            }
            return
        }
        
        if session.canAddInput(input) {
            await MainActor.run {
                testResult = "Camera: ✅ Successfully accessed camera\nNo restart needed!"
            }
        } else {
            await MainActor.run {
                testResult = "Camera: ❌ Cannot add camera input"
            }
        }
    }
    
    private func testMicrophoneAccess() async {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            await MainActor.run {
                testResult = "Microphone: ✅ Audio session configured\nReady to record immediately!"
            }
        } catch {
            await MainActor.run {
                testResult = "Microphone: ❌ Failed to configure audio: \(error.localizedDescription)"
            }
        }
    }
    
    private func testHealthAccess() async {
        let healthStore = HKHealthStore()
        let glucoseType = HKQuantityType(.bloodGlucose)
        
        let query = HKSampleQuery(
            sampleType: glucoseType,
            predicate: nil,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            Task { @MainActor in
                if error != nil {
                    testResult = "Health: ❌ Query failed: \(error?.localizedDescription ?? "Unknown")"
                } else {
                    testResult = "Health: ✅ Successfully queried HealthKit\nFound \(samples?.count ?? 0) samples"
                }
            }
        }
        
        healthStore.execute(query)
    }
}

// MARK: - Preview

#Preview {
    PermissionsDemoView()
}