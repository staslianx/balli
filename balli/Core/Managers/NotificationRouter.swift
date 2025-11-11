//
//  NotificationRouter.swift
//  balli
//
//  Handles notification tap routing to specific app screens
//  Opens VoiceInputView for meal logging notifications
//

import Foundation
import UserNotifications
import OSLog
import SwiftUI

/// Routes notification taps to appropriate app screens
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "NotificationRouter"
    )

    // Published state to trigger navigation from ContentView
    @Published var shouldShowVoiceInput = false

    private init() {
        logger.info("NotificationRouter initialized")
    }

    /// Handle notification response when user taps a notification
    /// Called by AppDelegate's UNUserNotificationCenterDelegate
    /// - Parameter identifier: The notification identifier (extracted before crossing actor boundary)
    func handleNotificationIdentifier(_ identifier: String) {
        logger.info("🔔 Notification tapped: \(identifier)")

        // Check if this is a Lantus reminder notification
        if identifier.hasPrefix("insulin-reminder-lantus-") {
            logger.info("💉 Lantus reminder notification - opening VoiceInputView for insulin logging")

            // Trigger voice input view presentation (user can say "20 units Lantus")
            shouldShowVoiceInput = true

            // Auto-reset after a brief delay to allow for re-triggering
            Task {
                try? await Task.sleep(for: .seconds(2))
                shouldShowVoiceInput = false
            }
        }
        // Check if this is a meal reminder notification
        else if identifier.hasPrefix("meal-reminder-morning-") || identifier.hasPrefix("meal-reminder-evening-") {
            logger.info("📝 Meal reminder notification - opening VoiceInputView")

            // Trigger voice input view presentation
            shouldShowVoiceInput = true

            // Auto-reset after a brief delay to allow for re-triggering
            Task {
                try? await Task.sleep(for: .seconds(2))
                shouldShowVoiceInput = false
            }
        } else if identifier.hasPrefix("daily-checkin-afternoon-") {
            logger.info("👋 Check-in notification - opening main dashboard")
            // Just open the app (default behavior)
        } else {
            logger.info("ℹ️ Unknown notification type - using default behavior")
        }
    }

    /// Manually trigger voice input view (for testing or other entry points)
    func openVoiceInput() {
        logger.info("📝 Manually opening VoiceInputView")
        shouldShowVoiceInput = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            shouldShowVoiceInput = false
        }
    }
}
