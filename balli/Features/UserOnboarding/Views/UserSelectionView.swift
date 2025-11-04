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
    @AppStorage("isSerhatModeEnabled") private var isSerhatModeEnabled: Bool = false
    @State private var showDeveloperMenu: Bool = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Centered Content
                VStack(spacing: 32) {
                    // Logo
                    Image("balli-text-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 44)

                    // Welcome Text
                    Text("Sonunda tanışabildik")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
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
                                .cornerRadius(20)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }

            // Developer Wrench Button (Bottom-Left)
            VStack {
                Spacer()
                HStack {
                    Button(action: { showDeveloperMenu = true }) {
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
                    .popover(isPresented: $showDeveloperMenu) {
                        DeveloperMenuView(isSerhatModeEnabled: $isSerhatModeEnabled)
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 16)

                    Spacer()
                }
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

// MARK: - Developer Menu Component

struct DeveloperMenuView: View {
    @Binding var isSerhatModeEnabled: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Geliştirici Seçenekleri")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 16)

            Divider()

            // Serhat Mode Toggle
            Toggle(isOn: $isSerhatModeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Serhat Mode")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Test kullanıcısı olarak giriş yap")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppTheme.primaryPurple))
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(width: 280, height: 160)
        .background(Color(.systemBackground))
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

#Preview("Developer Menu") {
    DeveloperMenuView(isSerhatModeEnabled: .constant(false))
        .padding()
}
