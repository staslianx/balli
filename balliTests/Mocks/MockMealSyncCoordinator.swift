//
//  MockMealSyncCoordinator.swift
//  balliTests
//
//  Mock implementation of MealSyncCoordinatorProtocol for testing
//

import Foundation
@testable import balli

@MainActor
final class MockMealSyncCoordinator: MealSyncCoordinatorProtocol {

    // MARK: - Mock Configuration

    var shouldSucceedSync = true
    var mockSyncError: Error?
    var mockSyncDelay: TimeInterval = 0.1

    // MARK: - Published State

    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    @Published private(set) var pendingChangesCount: Int = 0

    // MARK: - Call Tracking

    private(set) var manualSyncCallCount = 0
    private(set) var syncOnAppActivationCallCount = 0
    private(set) var enableAutoSyncCallCount = 0
    private(set) var disableAutoSyncCallCount = 0

    // MARK: - Protocol Implementation

    func manualSync() async {
        manualSyncCallCount += 1
        await performMockSync()
    }

    func syncOnAppActivation() async {
        syncOnAppActivationCallCount += 1
        await performMockSync()
    }

    func enableAutoSync() {
        enableAutoSyncCallCount += 1
    }

    func disableAutoSync() {
        disableAutoSyncCallCount += 1
    }

    // MARK: - Test Helpers

    func reset() {
        shouldSucceedSync = true
        mockSyncError = nil
        mockSyncDelay = 0.1
        isSyncing = false
        lastSyncTime = nil
        syncError = nil
        pendingChangesCount = 0
        manualSyncCallCount = 0
        syncOnAppActivationCallCount = 0
        enableAutoSyncCallCount = 0
        disableAutoSyncCallCount = 0
    }

    func setPendingChangesCount(_ count: Int) {
        pendingChangesCount = count
    }

    // MARK: - Mock Sync

    private func performMockSync() async {
        isSyncing = true
        syncError = nil

        // Simulate sync delay
        try? await Task.sleep(for: .seconds(mockSyncDelay))

        if let error = mockSyncError {
            syncError = error
            isSyncing = false
            return
        }

        if shouldSucceedSync {
            lastSyncTime = Date()
            syncError = nil
            pendingChangesCount = 0
        } else {
            let error = NSError(
                domain: "MockMealSyncCoordinator",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock sync failed"]
            )
            syncError = error
        }

        isSyncing = false
    }
}
