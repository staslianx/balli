//
//  CameraPermissionViews.swift
//  balli
//
//  Camera permission UI components
//

import SwiftUI
import AVFoundation

// MARK: - Main Permission View
public struct CameraPermissionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    let onPermissionGranted: () -> Void
    let onManualEntry: () -> Void
    
    public init(
        permissionManager: SystemPermissionCoordinator? = nil, // Keep for compatibility but unused
        onPermissionGranted: @escaping () -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        self.onPermissionGranted = onPermissionGranted
        self.onManualEntry = onManualEntry
    }
    
    public var body: some View {
        Group {
            switch permissionManager.status(for: .camera) {
            case .notDetermined, .checking:
                PermissionRequestView(
                    onPermissionGranted: onPermissionGranted,
                    onManualEntry: onManualEntry
                )
                
            case .authorized:
                // Permission granted - show camera
                Color.clear.onAppear {
                    // Add delay for first-time permission grant
                    Task {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                        await MainActor.run {
                            onPermissionGranted()
                        }
                    }
                }
                
            case .denied:
                PermissionDeniedView(
                    onManualEntry: onManualEntry
                )
                
            case .restricted:
                PermissionRestrictedView(
                    onManualEntry: onManualEntry
                )
            }
        }
    }
}

// MARK: - Permission Request View
struct PermissionRequestView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    let onPermissionGranted: () -> Void
    let onManualEntry: () -> Void
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            Spacer()
            
            // Icon
            Image(systemName: "camera.fill")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(80), weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.primaryPurple)
            
            // Title
            Text("Kamera İzni")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .fontWeight(.bold)
            
            // Description
            Text("Balli'nin besin etiketlerini tarayabilmesi için kamera erişimine ihtiyacı var.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Benefits
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "Zaman Kazanın",
                    description: "Manuel giriş yerine hızlı tarama"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Doğru Takip",
                    description: "AI ile hassas karbonhidrat sayımı"
                )
                
                FeatureRow(
                    icon: "lock.fill",
                    title: "Gizliliğiniz Önemli",
                    description: "Fotoğraflar yerel işlenir, saklanmaz"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                Button(action: {
                    Task {
                        let granted = await permissionManager.requestPermission(.camera)
                        if granted {
                            // Add small delay for system to update permission state
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                            await MainActor.run {
                                onPermissionGranted()
                            }
                        }
                    }
                }) {
                    Text("Kamera İznini Ver")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryPurple)
                        .cornerRadius(ResponsiveDesign.CornerRadius.button)
                }
                .disabled(permissionManager.isCheckingAnyPermission)
                
                Button(action: onManualEntry) {
                    Text("Manuel Olarak Gir")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, ResponsiveDesign.Spacing.large)
        }
    }
}

// MARK: - Educational Prompt View
struct EducationalPromptView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onContinue: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(28), weight: .regular, design: .rounded))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding()
            }
            
            // Icon
            Image(systemName: "camera.fill")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(80), weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.primaryPurple)
                .padding(.top, ResponsiveDesign.Spacing.large)
            
            // Title
            Text("Besin Etiketlerini Anında Tarayın")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Benefits
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "Zaman Kazanın",
                    description: "Manuel giriş yok - sadece göster ve tara"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Doğru Takip Edin",
                    description: "AI hassas karbonhidrat sayımını garanti eder"
                )
                
                FeatureRow(
                    icon: "lock.fill",
                    title: "Gizliliğiniz Önemli",
                    description: "Fotoğraflar yerel olarak işlenir ve asla saklanmaz"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                Button(action: {
                    onContinue()
                    dismiss()
                }) {
                    Text("Devam Et")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryPurple)
                        .cornerRadius(ResponsiveDesign.CornerRadius.button)
                }
                
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    Text("Manuel Giriş Yapacağım")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, ResponsiveDesign.Spacing.large)
        }
    }
}

// MARK: - Permission Denied View
struct PermissionDeniedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    let onManualEntry: () -> Void
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            Spacer()
            
            // Icon
            Image(systemName: "camera.fill")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(80), weight: .regular, design: .rounded))
                .foregroundColor(.gray)
            
            // Message
            Text("Kamera Erişimi Gerekli")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .fontWeight(.bold)
            
            Text("Besin etiketlerini taramak için Balli'nin kameraya erişmesi gerekiyor. Ayarlar'dan kamera iznini açabilirsiniz.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Actions
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                Button(action: { permissionManager.openSettings() }) {
                    Label("Ayarları Aç", systemImage: "gear")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryPurple)
                        .cornerRadius(ResponsiveDesign.CornerRadius.button)
                }
                
                Button(action: onManualEntry) {
                    Text("Manuel Olarak Gir")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryPurple.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.CornerRadius.button)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Permission Restricted View
struct PermissionRestrictedView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onManualEntry: () -> Void
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            Spacer()
            
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(80), weight: .regular, design: .rounded))
                .foregroundColor(.orange)
            
            // Message
            Text("Kamera Kısıtlanmış")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .fontWeight(.bold)
            
            Text("Bu cihazda kamera erişimi kısıtlanmış. Bu, ebeveyn kontrolleri veya cihaz yönetimi politikaları nedeniyle olabilir.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action
            Button(action: onManualEntry) {
                Text("Besin Değerlerini Manuel Gir")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primaryPurple)
                    .cornerRadius(ResponsiveDesign.CornerRadius.button)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: ResponsiveDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(24), weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.primaryPurple)
                .frame(width: ResponsiveDesign.width(30))
            
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Permission-Aware Camera Button
public struct CameraButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var permissionManager: CameraPermissionHandler
    let action: () -> Void
    
    public init(permissionManager: CameraPermissionHandler, action: @escaping () -> Void) {
        self.permissionManager = permissionManager
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            Task {
                if permissionManager.isAuthorized {
                    action()
                } else {
                    let granted = await permissionManager.requestPermission()
                    if granted {
                        action()
                    }
                }
            }
        }) {
            Label("Etiketi Tara", systemImage: "camera.fill")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                .padding()
                .background(backgroundColor)
                .cornerRadius(ResponsiveDesign.CornerRadius.button)
        }
        .disabled(isDisabled)
    }
    
    private var backgroundColor: Color {
        switch permissionManager.permissionState {
        case .authorized:
            return AppTheme.primaryPurple
        case .restricted:
            return .gray
        default:
            return AppTheme.primaryPurple.opacity(0.8)
        }
    }
    
    private var isDisabled: Bool {
        permissionManager.permissionState == .restricted ||
        permissionManager.isCheckingPermission
    }
}

// MARK: - View Extension for Permission Checking
extension View {
    public func checkCameraPermission(
        permissionManager: CameraPermissionHandler,
        onAuthorized: @escaping () -> Void,
        onDenied: @escaping () -> Void
    ) -> some View {
        self.task {
            let state = await permissionManager.checkPermission()
            
            switch state {
            case .authorized:
                onAuthorized()
            case .denied, .restricted:
                onDenied()
            case .notDetermined:
                let granted = await permissionManager.requestPermission()
                if granted {
                    onAuthorized()
                } else {
                    onDenied()
                }
            case .checking:
                // Wait for check to complete
                break
            }
        }
    }
}