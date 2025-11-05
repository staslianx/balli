//
//  AccountProfileSection.swift
//  balli
//
//  Account profile display component for settings
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct AccountProfileSection: View {
    let userManager: UserProfileSelector
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 16) {
            // User emoji avatar with theme color background
            Text(userManager.currentUser?.emoji ?? "👤")
                .font(.system(size: 48))
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill((userManager.currentUser?.themeColor ?? AppTheme.primaryPurple).opacity(0.1))
                )

            // User name and email
            VStack(alignment: .leading, spacing: 6) {
                Text(userManager.currentUserDisplayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(userManager.currentUserEmail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }
}
