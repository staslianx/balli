//
//  SyncErrorView.swift
//  balli
//
//  Error screen for app initialization failures
//  Provides appropriate recovery actions based on error type
//

import SwiftUI

struct SyncErrorView: View {

    // MARK: - Properties

    let error: SyncError
    let retry: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Content
            VStack(spacing: 32) {
                Spacer()

                // Error icon
                errorIcon

                // Error message
                errorMessage

                // Action buttons
                actionButtons

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Error Icon

    private var errorIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 60))
            .foregroundColor(iconColor)
            .accessibilityLabel("Hata simgesi")
    }

    private var iconName: String {
        if error.isCritical {
            return "xmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        if error.isCritical {
            return .red
        } else {
            return .orange
        }
    }

    // MARK: - Error Message

    private var errorMessage: some View {
        VStack(spacing: 12) {
            // Title
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Description
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var errorTitle: String {
        if error.isCritical {
            return "Başlatma Başarısız"
        } else {
            return "Başlatma Hatası"
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary action button
            primaryActionButton

            // Secondary action (if applicable)
            if !error.isCritical {
                secondaryActionButton
            }
        }
    }

    private var primaryActionButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: 12) {
                Image(systemName: primaryActionIcon)
                    .font(.headline)

                Text(primaryActionTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(primaryActionColor)
            .cornerRadius(16)
        }
        .accessibilityLabel(primaryActionTitle)
        .accessibilityHint(primaryActionHint)
    }

    private var primaryActionTitle: String {
        if error.isCritical {
            return "Uygulamayı Yeniden Başlat"
        } else {
            return "Tekrar Dene"
        }
    }

    private var primaryActionIcon: String {
        if error.isCritical {
            return "arrow.clockwise.circle.fill"
        } else {
            return "arrow.clockwise"
        }
    }

    private var primaryActionColor: Color {
        if error.isCritical {
            return .red
        } else {
            return AppTheme.primaryPurple
        }
    }

    private var primaryActionHint: String {
        if error.isCritical {
            return "Uygulamayı kapatır ve yeniden başlatmanızı ister"
        } else {
            return "Başlatma işlemini tekrar dener"
        }
    }

    private func primaryAction() {
        if error.isCritical {
            // For critical errors, suggest app restart
            // In a real app, you might show a dialog or use fatalError() in debug
            #if DEBUG
            fatalError("Critical sync error - restart required: \(error.localizedDescription)")
            #else
            // In production, the user will need to manually restart the app
            // We can't programmatically restart on iOS
            exit(0)
            #endif
        } else {
            // For recoverable errors, retry sync
            retry()
        }
    }

    private var secondaryActionButton: some View {
        Button(action: {
            // Continue with degraded functionality
            // This bypasses sync and shows main UI
            AppSyncCoordinator.shared.enableBypass()
            retry()
        }) {
            Text("Devam Et")
                .font(.headline)
                .foregroundColor(AppTheme.primaryPurple)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.primaryPurple, lineWidth: 2)
                )
        }
        .accessibilityLabel("Devam et")
        .accessibilityHint("Sınırlı özelliklerle uygulamaya devam eder")
    }
}

// MARK: - Previews

#Preview("Critical Error - Core Data") {
    SyncErrorView(
        error: .coreDataFailed("Store load failed"),
        retry: {}
    )
}

#Preview("Recoverable Error - Config") {
    SyncErrorView(
        error: .appConfigurationFailed("Network timeout"),
        retry: {}
    )
}

#Preview("Timeout Error") {
    SyncErrorView(
        error: .timeout,
        retry: {}
    )
}

#Preview("Unknown Error") {
    SyncErrorView(
        error: .unknown("Something unexpected happened"),
        retry: {}
    )
}

#Preview("Dark Mode") {
    SyncErrorView(
        error: .appConfigurationFailed("Configuration service unavailable"),
        retry: {}
    )
    .preferredColorScheme(.dark)
}
