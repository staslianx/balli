//
//  UserSelectionView.swift
//  balli
//
//  User selection modal for diabetes assistant
//  Allows selection between Dilara and Serhat (test user)
//

import SwiftUI

struct UserSelectionView: View {
    @Environment(\.userManager) private var userManager
    @State private var selectedUser: AppUser?
    @State private var showingSelection = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // Logo
                    Image("BalliLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(AppTheme.primaryPurple)

                    // Welcome text
                    VStack(spacing: 8) {
                        Text("balli'ye Hoşgeldin! 👋")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.primaryPurple)

                        Text("Kim kullanacak?")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 32)

                Spacer()

                // User selection cards
                VStack(spacing: 20) {
                    ForEach(AppUser.allCases, id: \.self) { user in
                        UserCard(
                            user: user,
                            isSelected: selectedUser == user
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedUser = user
                                showingSelection = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Continue button
                Button(action: {
                    if let user = selectedUser {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            userManager.selectUser(user)
                        }
                    }
                }) {
                    HStack {
                        Text("Devam Et")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        (selectedUser != nil ? AppTheme.primaryPurple : Color.gray)
                            .cornerRadius(16)
                    )
                    .scaleEffect(showingSelection ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: showingSelection)
                }
                .disabled(selectedUser == nil)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled()
    }
}

// MARK: - User Card Component
struct UserCard: View {
    let user: AppUser
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // User emoji/avatar
                Text(user.emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(user.themeColor.opacity(0.1))
                    )

                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(user.subtitle)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(user.themeColor)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: isSelected ? user.themeColor.opacity(0.3) : Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? user.themeColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
#Preview("User Selection") {
    UserSelectionView()
        .userManager(UserProfileSelector.shared)
}

#Preview("User Card - Dilara") {
    UserCard(user: .dilara, isSelected: false) { }
    .padding()
}

#Preview("User Card - Serhat Selected") {
    UserCard(user: .serhat, isSelected: true) { }
    .padding()
}