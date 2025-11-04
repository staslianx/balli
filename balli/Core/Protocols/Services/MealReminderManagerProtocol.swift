//
//  MealReminderManagerProtocol.swift
//  balli
//
//  Protocol definition for MealReminderManager
//  Enables dependency injection and testing
//

import Foundation

/// Protocol for managing meal reminder notifications
@MainActor
protocol MealReminderManagerProtocol: AnyObject {

    // MARK: - Permission Management

    /// Request notification permission from user
    /// - Returns: Boolean indicating if permission was granted
    func requestPermission() async -> Bool

    /// Check if notifications are currently authorized
    /// - Returns: Boolean indicating if notifications are authorized
    func checkPermission() async -> Bool

    // MARK: - Schedule Reminders

    /// Schedule daily reminders: 09:00 (morning), 15:00 (check-in), 18:00 (evening)
    /// with rotating messages for variety
    func scheduleDailyReminders() async

    // MARK: - Cancel Reminders

    /// Cancel all meal reminders and check-ins
    func cancelAllReminders()

    // MARK: - Debug Helpers

    /// Get list of currently scheduled notifications (for debugging)
    func listScheduledNotifications() async
}
