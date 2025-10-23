//
//  SettingsOpener.swift
//  balli
//
//  SwiftUI-native Settings navigation without UIKit dependencies
//  iOS 26 Liquid Glass compliant
//

import SwiftUI
import OSLog

/// Notification-based Settings opener that works without UIKit
/// Allows managers to request Settings opening without importing UIKit
public enum SettingsOpener {
    private static let logger = Logger(subsystem: "com.balli.diabetes", category: "SettingsOpener")

    /// Settings URL for iOS
    public static var settingsURL: URL? {
        URL(string: "app-settings:root")
    }

    /// Post notification to request Settings opening
    /// The app's root view should listen for this and use @Environment(\.openURL)
    public static func requestSettingsOpen() {
        logger.info("Requesting Settings open via notification")
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
    }
}

/// Notification name for Settings open requests
extension Notification.Name {
    public static let openSettingsRequested = Notification.Name("com.balli.openSettingsRequested")
}

/// View modifier that listens for Settings open requests and handles them with SwiftUI
struct SettingsOpenerModifier: ViewModifier {
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                if let settingsURL = SettingsOpener.settingsURL {
                    openURL(settingsURL)
                }
            }
    }
}

extension View {
    /// Enable Settings opening throughout the app via notification pattern
    /// Apply this to your root view
    public func enableSettingsOpener() -> some View {
        modifier(SettingsOpenerModifier())
    }
}
