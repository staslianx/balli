//
//  SettingsState.swift
//  balli
//
//  App settings and notification preferences state management
//

import SwiftUI
import Combine
import OSLog

// MARK: - Settings State Manager
@MainActor
final class SettingsState: ObservableObject {
    static let shared = SettingsState()

    // MARK: - Published Properties
    @Published var appSettings: AppSettings
    @Published var notificationSettings: NotificationSettings

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.appSettings = AppSettings.load()
        self.notificationSettings = NotificationSettings.load()

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Settings observer
        $appSettings
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)

        $notificationSettings
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings Methods

    func updateTheme(_ theme: AppThemeMode) {
        appSettings.theme = theme
    }

    func updateLanguage(_ language: AppLanguage) {
        appSettings.language = language
    }

    func toggleNotifications(_ enabled: Bool) {
        notificationSettings.enabled = enabled
    }
}

// MARK: - App Theme Mode
enum AppThemeMode: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
}

// MARK: - App Settings
struct AppSettings: Codable {
    var theme: AppThemeMode = .auto
    var language: AppLanguage = .turkish
    var glucoseUnit: GlucoseUnit = .mgdl
    var carbUnit: CarbUnit = .grams
    var quickScanEnabled = true
    var hapticFeedback = true
    var soundEffects = false

    // Developer Mode Settings
    var isSerhatModeEnabled = false
    var developerSessionStartTime: Date?
    var autoCleanupOnToggleOff = true

    enum GlucoseUnit: String, Codable, CaseIterable {
        case mgdl = "mg/dL"
        case mmol = "mmol/L"
    }

    enum CarbUnit: String, Codable, CaseIterable {
        case grams = "g"
        case exchanges = "KH"
    }

    static func load() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }
        return AppSettings()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }

    // MARK: - Developer Mode Management

    mutating func enableSerhatMode() {
        isSerhatModeEnabled = true
        developerSessionStartTime = Date()
        save()
        AppLoggers.Auth.userManagement.info("Serhat Mode enabled - Developer session started")
    }

    mutating func disableSerhatMode() {
        isSerhatModeEnabled = false
        developerSessionStartTime = nil
        save()
        AppLoggers.Auth.userManagement.info("Serhat Mode disabled - Returning to main user")
    }

    var developerSessionDuration: TimeInterval? {
        guard let startTime = developerSessionStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    var formattedSessionDuration: String {
        guard let duration = developerSessionDuration else { return "No active session" }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var enabled = true
    var glucoseReminders = true
    var mealReminders = true
    var medicationReminders = false
    var reminderTimes: [Date] = []

    static func load() -> NotificationSettings {
        if let data = UserDefaults.standard.data(forKey: "NotificationSettings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            return settings
        }
        return NotificationSettings()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "NotificationSettings")
        }
    }
}

// MARK: - App Language
enum AppLanguage: String, Codable, CaseIterable {
    case turkish = "tr"
    case english = "en"

    var displayName: String {
        switch self {
        case .turkish:
            return "Türkçe"
        case .english:
            return "English"
        }
    }
}

// MARK: - Environment Key
private struct SettingsStateKey: EnvironmentKey {
    static let defaultValue: SettingsState? = nil
}

extension EnvironmentValues {
    var settingsState: SettingsState {
        get {
            if let state = self[SettingsStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                SettingsState.shared
            }
        }
        set { self[SettingsStateKey.self] = newValue }
    }
}
