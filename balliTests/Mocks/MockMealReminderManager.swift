//
//  MockMealReminderManager.swift
//  balliTests
//
//  Mock implementation of MealReminderManagerProtocol for testing
//

import Foundation
@testable import balli

@MainActor
final class MockMealReminderManager: MealReminderManagerProtocol {

    // MARK: - Mock Configuration

    var shouldGrantPermission = true
    var isPermissionGranted = false
    var scheduledRemindersCount = 0

    // MARK: - Call Tracking

    var requestPermissionCallCount = 0
    var checkPermissionCallCount = 0
    var scheduleDailyRemindersCallCount = 0
    var cancelAllRemindersCallCount = 0
    var listScheduledNotificationsCallCount = 0

    // MARK: - Permission Management

    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        isPermissionGranted = shouldGrantPermission

        if shouldGrantPermission {
            await scheduleDailyReminders()
        }

        return shouldGrantPermission
    }

    func checkPermission() async -> Bool {
        checkPermissionCallCount += 1
        return isPermissionGranted
    }

    // MARK: - Schedule Reminders

    func scheduleDailyReminders() async {
        scheduleDailyRemindersCallCount += 1
        scheduledRemindersCount = 3 // Morning, afternoon, evening
    }

    // MARK: - Cancel Reminders

    func cancelAllReminders() {
        cancelAllRemindersCallCount += 1
        scheduledRemindersCount = 0
    }

    // MARK: - Debug Helpers

    func listScheduledNotifications() async {
        listScheduledNotificationsCallCount += 1
    }

    // MARK: - Reset

    func reset() {
        shouldGrantPermission = true
        isPermissionGranted = false
        scheduledRemindersCount = 0
        requestPermissionCallCount = 0
        checkPermissionCallCount = 0
        scheduleDailyRemindersCallCount = 0
        cancelAllRemindersCallCount = 0
        listScheduledNotificationsCallCount = 0
    }
}
