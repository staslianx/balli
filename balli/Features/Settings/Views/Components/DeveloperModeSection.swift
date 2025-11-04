//
//  DeveloperModeSection.swift
//  balli
//
//  Developer mode settings and testing tools
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

struct DeveloperModeSection: View {
    @Binding var appSettings: AppSettings
    @Binding var showingCleanupDialog: Bool
    @Binding var showingDataSummary: Bool
    @Binding var dataSummary: DeveloperDataSummary?

    @ObservedObject var developerDataManager: DeveloperDataManager
    let userManager: UserProfileSelector
    let colorScheme: ColorScheme
    let logger: Logger

    var body: some View {
        Section {
            developerModeToggle

            if appSettings.isSerhatModeEnabled {
                developerModeInfo

                Divider()
                    .padding(.vertical, 8)

                developerDataActions

                Divider()
                    .padding(.vertical, 8)

                userSwitchingSection

                Divider()
                    .padding(.vertical, 8)

                memoryAndEmbeddingTools
            }
        } header: {
            Text("Developer Settings")
        }
    }

    // MARK: - Computed Bindings

    private var serhatModeBinding: Binding<Bool> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    appSettings.isSerhatModeEnabled
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    if newValue {
                        appSettings.enableSerhatMode()
                    } else {
                        // Show cleanup options before disabling
                        if appSettings.autoCleanupOnToggleOff {
                            showingCleanupDialog = true
                        } else {
                            appSettings.disableSerhatMode()
                        }
                    }
                }
            }
        )
    }

    // MARK: - UI Components

    private var developerModeToggle: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundColor(appSettings.isSerhatModeEnabled ? .orange : AppTheme.primaryPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Serhat Mode")
                    .font(.system(size: 15, weight: .regular, design: .rounded))

                Text("Developer testing mode")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: serhatModeBinding)
                .tint(.orange)
        }
        .alert("Disable Developer Mode", isPresented: $showingCleanupDialog) {
            Button("Keep Data") {
                Task {
                    try? await developerDataManager.performCleanup(option: .keepAll)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }

            Button("Delete Session") {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteCurrentSession)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }

            Button("Delete All", role: .destructive) {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteAllDeveloperData)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What should happen to your developer testing data?")
        }
    }

    private var developerModeInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                Text("Session Info")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("User ID:")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("serhat-developer-mode")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("Session Duration:")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(appSettings.formattedSessionDuration)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(.leading, 30)
        }
    }

    private var developerDataActions: some View {
        VStack(spacing: 8) {
            // Data Summary Button
            Button(action: {
                Task {
                    do {
                        let summary = try await developerDataManager.getDeveloperDataSummary()
                        await MainActor.run {
                            dataSummary = summary
                            showingDataSummary = true
                        }
                    } catch {
                        logger.error("Failed to get developer data summary: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Text("View Data Summary")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Quick Cleanup Actions
            Button(action: {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteCurrentSession)
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Text("Clear Current Session")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
        }
        .alert("Developer Data Summary", isPresented: $showingDataSummary) {
            Button("OK") { }
        } message: {
            if let summary = dataSummary {
                Text(summary.displayText)
            } else {
                Text("No data available")
            }
        }
    }

    private var userSwitchingSection: some View {
        VStack(spacing: 8) {
            // Current User Display
            HStack {
                Image(systemName: "person.2.circle")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick User Switch")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.orange)

                    Text("Current: \(userManager.currentUserDisplayName)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // User Switch Buttons
            HStack(spacing: 12) {
                ForEach(AppUser.allCases, id: \.self) { user in
                    Button(action: {
                        userManager.switchToUser(user)
                    }) {
                        HStack(spacing: 6) {
                            Text(user.emoji)
                                .font(.system(size: 14))

                            Text(user.displayName)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(userManager.currentUser == user ? AppTheme.foregroundOnColor(for: colorScheme) : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(userManager.currentUser == user ? user.themeColor : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 30)
        }
    }

    private var memoryAndEmbeddingTools: some View {
        VStack(spacing: 8) {
            // Memory Statistics
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory & Vector Tools")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.orange)

                    Text("AI memory and embedding utilities")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Tool Buttons
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await testEmbeddingGeneration()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Test Embedding Generation")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }

                Button(action: {
                    Task {
                        await testMemorySearch()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass.circle")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Test Memory Search")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }

                Button(action: {
                    Task {
                        await clearMemoryData()
                    }
                }) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Clear Memory Data")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }
            .padding(.leading, 30)
        }
    }

    // MARK: - Developer Tool Actions

    private func testEmbeddingGeneration() async {
        logger.debug("🧪 Testing embedding generation...")
        // This could trigger a test embedding call
    }

    private func testMemorySearch() async {
        logger.debug("🧪 Testing memory search...")
        // This could trigger a test memory search
    }

    private func clearMemoryData() async {
        logger.info("🧪 Clearing memory data for current user")
        // This could clear memory entries for the current user
    }
}
