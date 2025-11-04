//
//  AccountActionsSection.swift
//  balli
//
//  Account action buttons for settings (switch user, logout)
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct AccountActionsSection: View {
    let userManager: UserProfileSelector
    let onDismiss: () -> Void

    var body: some View {
        Section {
            // Switch User Button
            Button(action: {
                Task { @MainActor in
                    // Clear user selection to show user selection modal
                    userManager.clearUserSelection()
                    onDismiss()
                }
            }) {
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: 24)

                    Text("Kullanıcı Değiştir")
                        .foregroundColor(.primary)
                }
            }

            // Logout Button
            Button(role: .destructive, action: {
                Task { @MainActor in
                    // Reset app configuration
                    await AppConfigurationManager.shared.resetConfiguration()

                    // Clear user selection
                    userManager.clearUserSelection()

                    // Notify the app about logout
                    NotificationCenter.default.post(
                        name: Notification.Name("UserDidLogout"),
                        object: nil
                    )

                    onDismiss()
                }
            }) {
                Label("Çıkış Yap", systemImage: "door.left.hand.open")
            }
            .foregroundStyle(.red)
        }
    }
}
