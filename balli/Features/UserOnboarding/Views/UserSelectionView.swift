//
//  UserSelectionView.swift
//  balli
//
//  User selection modal for diabetes assistant
//  Allows selection between Dilara (default) and Serhat (test user via developer menu)
//

import SwiftUI

struct UserSelectionView: View {
    @Environment(\.userManager) private var userManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isSerhatModeEnabled") private var isSerhatModeEnabled: Bool = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Centered Content
                VStack(spacing: 32) {
                    // Logo - adapts to dark/light mode
                    Image(colorScheme == .dark ? "balli-text-logo-dark" : "balli-text-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 70)

                    // Welcome Text
                    Text("Merhaba Dilara!Sonunda tanışabildik")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Continue Button
                Button(action: continueAction) {
                    Text("Devam")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            AppTheme.primaryPurple
                                .cornerRadius(38)
                        )
                }
                .padding(.horizontal, 150)
                .padding(.bottom, 40)
            }

            // Developer Wrench Menu (Top-Right)
            VStack {
                HStack {
                    Spacer()

                    Menu {
                        Toggle("Serhat Mode", isOn: $isSerhatModeEnabled)
                    } label: {
                        Image(systemName: "wrench.adjustable")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
        .interactiveDismissDisabled()
    }

    private func continueAction() {
        let selectedUser: AppUser = isSerhatModeEnabled ? .serhat : .dilara
        withAnimation(.easeInOut(duration: 0.3)) {
            userManager.selectUser(selectedUser)
        }
    }
}

// MARK: - Previews

#Preview("User Selection - Default (Dilara)") {
    UserSelectionView()
        .userManager(UserProfileSelector.shared)
}

#Preview("User Selection - Serhat Mode Enabled") {
    let view = UserSelectionView()
    return view
        .userManager(UserProfileSelector.shared)
        .onAppear {
            UserDefaults.standard.set(true, forKey: "isSerhatModeEnabled")
        }
}
