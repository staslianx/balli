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
final class MealReminderManager: MealReminderManagerProtocol {

    static let shared = MealReminderManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "Notifications"
    )

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Notification Messages

    /// Morning notification variations (rotates daily for variety)
    private let morningMessages: [(title: String, body: String)] = [
        ("☀️ Günaydın Dilara!", "Kahvaltıda yediklerini kaydetmeyi unutma canım, afiyet olsun!"),
        ("🌈 Günaydın canım!", "Yine kendine nasıl lezzetli menüler hazırladın bakalım?"),
        ("☀️ Günaydın!", "Yediklerini kaydetmeyi unutma canım!📝")
    ]

    /// Afternoon check-in variations (rotates daily for variety)
    private let afternoonMessages: [(title: String, body: String)] = [
        ("İyi günler canım", "Herşey yolundadır umarım, bir sorun olursa her zaman bana yazabilirsin!"),
        ("Naber canım?", "Günün nasıl geçiyor? Bana ihtiyacın olursa buradayım!"),
        ("İyi günler Dilara'cım!", "Umarım harika bir gün geçiriyorsundur!")
    ]

    /// Evening notification variations (rotates daily for variety)
    private let eveningMessages: [(title: String, body: String)] = [
        ("🌙 İyi akşamlar Dilara", "Akşam yemeğinde yediklerini kaydetmeyi unutma canım, afiyet olsun!"),
        ("🌆 İşte günün en keyifli zamanlarından biri", "Yine harika bir menü hazırladın dimi? Ama kaydetmeyi de unutma!"),
        ("✨ İyi akşamlar canım!", "Akşam yemeğini kaydettin mi? Etmediysen söyle not alayım 🎤")
    ]

    /// Night Lantus reminder variations (rotates daily for variety)
    private let lantusMessages: [(title: String, body: String)] = [
        ("🌙 Lantus zamanı canım!", "Günlük bazal insülin dozunu almayı unutma, iyi geceler! 💜"),
        ("✨ İyi geceler Dilara!", "Lantus'unu aldın mı canım? Unutmadan kaydetmek ister misin? 🎤")
    ]

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

    /// Schedule daily reminders: 09:00 (morning), 15:00 (check-in), 18:00 (evening), 21:00 (Lantus) with rotating messages
    func scheduleDailyReminders() async {
        // Remove any existing reminders first (all variations)
        let morningIds = (0..<morningMessages.count).map { "meal-reminder-morning-\($0)" }
        let afternoonIds = (0..<afternoonMessages.count).map { "daily-checkin-afternoon-\($0)" }
        let eveningIds = (0..<eveningMessages.count).map { "meal-reminder-evening-\($0)" }
        let lantusIds = (0..<lantusMessages.count).map { "insulin-reminder-lantus-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: morningIds + afternoonIds + eveningIds + lantusIds)

        logger.info("📅 Scheduling daily reminders with \(self.morningMessages.count) variations...")

        // Pick a random starting message based on current day
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0

        // Schedule morning reminder (09:00) with today's variation
        let morningIndex = dayOfYear % morningMessages.count
        let morningMessage = morningMessages[morningIndex]
        await scheduleReminder(
            identifier: "meal-reminder-morning-\(morningIndex)",
            title: morningMessage.title,
            body: morningMessage.body,
            hour: 9,
            minute: 0
        )

        // Schedule afternoon check-in (15:00) with today's variation
        let afternoonIndex = dayOfYear % afternoonMessages.count
        let afternoonMessage = afternoonMessages[afternoonIndex]
        await scheduleReminder(
            identifier: "daily-checkin-afternoon-\(afternoonIndex)",
            title: afternoonMessage.title,
            body: afternoonMessage.body,
            hour: 15,
            minute: 0
        )

        // Schedule evening reminder (18:00) with today's variation
        let eveningIndex = dayOfYear % eveningMessages.count
        let eveningMessage = eveningMessages[eveningIndex]
        await scheduleReminder(
            identifier: "meal-reminder-evening-\(eveningIndex)",
            title: eveningMessage.title,
            body: eveningMessage.body,
            hour: 18,
            minute: 0
        )

        // Schedule Lantus reminder (21:00 / 9 PM) with today's variation
        let lantusIndex = dayOfYear % lantusMessages.count
        let lantusMessage = lantusMessages[lantusIndex]
        await scheduleReminder(
            identifier: "insulin-reminder-lantus-\(lantusIndex)",
            title: lantusMessage.title,
            body: lantusMessage.body,
            hour: 21,
            minute: 0
        )

        logger.info("✅ Daily reminders scheduled: morning (\(morningIndex + 1)/\(self.morningMessages.count)), afternoon (\(afternoonIndex + 1)/\(self.afternoonMessages.count)), evening (\(eveningIndex + 1)/\(self.eveningMessages.count)), lantus (\(lantusIndex + 1)/\(self.lantusMessages.count))")
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

    /// Cancel all meal reminders, check-ins, and Lantus reminders
    func cancelAllReminders() {
        let morningIds = (0..<morningMessages.count).map { "meal-reminder-morning-\($0)" }
        let afternoonIds = (0..<afternoonMessages.count).map { "daily-checkin-afternoon-\($0)" }
        let eveningIds = (0..<eveningMessages.count).map { "meal-reminder-evening-\($0)" }
        let lantusIds = (0..<lantusMessages.count).map { "insulin-reminder-lantus-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: morningIds + afternoonIds + eveningIds + lantusIds)
        logger.info("🛑 All reminders and check-ins cancelled")
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
