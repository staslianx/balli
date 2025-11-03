//
//  MealReminderManager.swift
//  balli
//
//  Simple daily meal logging reminders at 09:00 and 18:00
//  No Apple Developer Program needed - local notifications are free!
//

import Foundation
import UserNotifications
import OSLog

@MainActor
final class MealReminderManager {

    static let shared = MealReminderManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "Notifications"
    )

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {
        logger.info("MealReminderManager initialized")
    }

    // MARK: - Permission Management

    /// Request notification permission from user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                logger.info("✅ Notification permission granted")
                await scheduleDailyReminders()
            } else {
                logger.warning("⚠️ Notification permission denied")
            }

            return granted
        } catch {
            logger.error("❌ Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if notifications are currently authorized
    func checkPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Reminders

    /// Schedule daily meal reminders at 09:00 and 18:00
    func scheduleDailyReminders() async {
        // Remove any existing reminders first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "meal-reminder-morning",
            "meal-reminder-evening"
        ])

        logger.info("📅 Scheduling daily meal reminders...")

        // Morning reminder at 09:00
        await scheduleReminder(
            identifier: "meal-reminder-morning",
            title: "Günaydın! ☀️",
            body: "Yediklerini girmeyi unutma canım, afiyet olsun!",
            hour: 9,
            minute: 0
        )

        // Evening reminder at 18:00
        await scheduleReminder(
            identifier: "meal-reminder-evening",
            title: "İyi akşamlar! 🌙",
            body: "Yediklerini girmeyi unutma canım, afiyet olsun!",
            hour: 18,
            minute: 0
        )

        logger.info("✅ Daily reminders scheduled successfully")
    }

    /// Schedule a single reminder
    private func scheduleReminder(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) async {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create date components for trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        // Create trigger (repeats daily)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule notification
        do {
            try await notificationCenter.add(request)
            logger.info("✅ Scheduled '\(identifier)' at \(hour):\(String(format: "%02d", minute))")
        } catch {
            logger.error("❌ Failed to schedule '\(identifier)': \(error.localizedDescription)")
        }
    }

    // MARK: - Cancel Reminders

    /// Cancel all meal reminders
    func cancelAllReminders() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "meal-reminder-morning",
            "meal-reminder-evening"
        ])
        logger.info("🛑 All meal reminders cancelled")
    }

    // MARK: - Debug Helpers

    /// Get list of currently scheduled notifications (for debugging)
    func listScheduledNotifications() async {
        let requests = await notificationCenter.pendingNotificationRequests()

        logger.info("📋 Scheduled notifications (\(requests.count)):")
        for request in requests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate() {
                logger.info("  - \(request.identifier): \(nextTriggerDate)")
            } else {
                logger.info("  - \(request.identifier): (no trigger date)")
            }
        }
    }
}
