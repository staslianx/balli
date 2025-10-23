//
//  PermissionHandlerModifier.swift
//  balli
//
//  SwiftUI view modifier for seamless permission handling
//  Automatically handles permission requests and Settings navigation
//

import SwiftUI

// MARK: - Permission Handler View Modifier

struct PermissionHandlerModifier: ViewModifier {
    let permissionType: PermissionType
    @Binding var isAuthorized: Bool
    let onStatusChange: ((UnifiedPermissionStatus) -> Void)?
    
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    @State private var showingDeniedAlert = false
    @State private var observerID: UUID?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setupObserver()
                checkInitialStatus()
            }
            .onDisappear {
                if let id = observerID {
                    permissionManager.removeObserver(id)
                }
            }
            .alert("Permission Required", isPresented: $showingDeniedAlert) {
                Button("Open Settings") {
                    permissionManager.openSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(permissionType.rawValue) access is required for this feature. Please enable it in Settings.")
            }
            .onChange(of: permissionManager.status(for: permissionType)) { oldValue, newValue in
                handleStatusChange(newValue)
            }
    }
    
    private func setupObserver() {
        observerID = permissionManager.observePermissionChanges { type, status in
            if type == permissionType {
                Task { @MainActor in
                    handleStatusChange(status)
                }
            }
        }
    }
    
    private func checkInitialStatus() {
        Task {
            let status = await permissionManager.checkPermission(permissionType)
            await MainActor.run {
                handleStatusChange(status)
            }
        }
    }
    
    private func handleStatusChange(_ status: UnifiedPermissionStatus) {
        isAuthorized = status.isUsable
        onStatusChange?(status)
        
        if status.needsSettings {
            showingDeniedAlert = true
        }
    }
}

// MARK: - View Extension

extension View {
    /// Handles permission state for a specific permission type
    /// - Parameters:
    ///   - type: The permission type to monitor
    ///   - isAuthorized: Binding to track authorization state
    ///   - onStatusChange: Optional callback for status changes
    public func handlePermission(
        _ type: PermissionType,
        isAuthorized: Binding<Bool>,
        onStatusChange: ((UnifiedPermissionStatus) -> Void)? = nil
    ) -> some View {
        modifier(PermissionHandlerModifier(
            permissionType: type,
            isAuthorized: isAuthorized,
            onStatusChange: onStatusChange
        ))
    }
}

// MARK: - Permission Request Button

public struct PermissionRequestButton: View {
    let permissionType: PermissionType
    let onGranted: (() -> Void)?
    let onDenied: (() -> Void)?
    
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    @State private var isRequesting = false
    @State private var showingDeniedAlert = false
    
    public init(
        _ type: PermissionType,
        onGranted: (() -> Void)? = nil,
        onDenied: (() -> Void)? = nil
    ) {
        self.permissionType = type
        self.onGranted = onGranted
        self.onDenied = onDenied
    }
    
    public var body: some View {
        Button(action: requestPermission) {
            HStack {
                if isRequesting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: permissionType.systemName)
                }
                
                Text(buttonTitle)
            }
        }
        .disabled(isRequesting || !canRequest)
        .alert("Permission Required", isPresented: $showingDeniedAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(permissionType.rawValue) access was previously denied. Please enable it in Settings.")
        }
    }
    
    private var buttonTitle: String {
        let status = permissionManager.status(for: permissionType)
        switch status {
        case .authorized:
            return "\(permissionType.rawValue) Enabled"
        case .denied:
            return "Enable in Settings"
        case .checking:
            return "Checking..."
        case .notDetermined:
            return "Enable \(permissionType.rawValue)"
        case .restricted:
            return "\(permissionType.rawValue) Restricted"
        }
    }
    
    private var canRequest: Bool {
        let status = permissionManager.status(for: permissionType)
        return status.canRequest || status.needsSettings
    }
    
    private func requestPermission() {
        let status = permissionManager.status(for: permissionType)
        
        if status.needsSettings {
            showingDeniedAlert = true
            return
        }
        
        guard status.canRequest else { return }
        
        isRequesting = true
        
        Task {
            let granted = await permissionManager.requestPermission(permissionType)
            
            await MainActor.run {
                isRequesting = false
                
                if granted {
                    onGranted?()
                } else {
                    onDenied?()
                    
                    // Check if we should show settings alert
                    let newStatus = permissionManager.status(for: permissionType)
                    if newStatus.needsSettings {
                        showingDeniedAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Permission Status View

public struct PermissionStatusView: View {
    let permissionType: PermissionType
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    
    public init(_ type: PermissionType) {
        self.permissionType = type
    }
    
    public var body: some View {
        HStack {
            Image(systemName: permissionType.systemName)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(permissionType.rawValue)
                    .font(.headline)
                
                Text(permissionType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            statusIndicator
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch permissionManager.status(for: permissionType) {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .restricted: return .gray
        case .checking: return .blue
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        let status = permissionManager.status(for: permissionType)
        
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            Button("Settings") {
                permissionManager.openSettings()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        case .notDetermined:
            PermissionRequestButton(permissionType)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .restricted:
            Text("Restricted")
                .font(.caption)
                .foregroundColor(.secondary)
        case .checking:
            ProgressView()
                .scaleEffect(0.8)
        }
    }
}