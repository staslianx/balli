//
//  MealSyncStatus.swift
//  balli
//
//  UI presentation helpers for meal sync status
//  Extracted from MealSyncCoordinator for single responsibility
//  Swift 6 strict concurrency compliant
//

import Foundation

/// UI presentation helpers for sync status display
struct MealSyncStatus {
    let isSyncing: Bool
    let syncError: Error?
    let pendingChangesCount: Int
    let lastSyncTime: Date?

    /// Get a user-friendly sync status message
    var syncStatusMessage: String {
        if isSyncing {
            return "Senkronize ediliyor..."
        } else if let error = syncError {
            return "Hata: \(error.localizedDescription)"
        } else if pendingChangesCount > 0 {
            return "\(pendingChangesCount) değişiklik bekliyor"
        } else if let lastSync = lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            return "Son senkronizasyon: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Henüz senkronize edilmedi"
        }
    }

    /// Get sync status icon name
    var syncStatusIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncError != nil {
            return "exclamationmark.triangle.fill"
        } else if pendingChangesCount > 0 {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    /// Get sync status color
    var syncStatusColor: String {
        if isSyncing {
            return "blue"
        } else if syncError != nil {
            return "red"
        } else if pendingChangesCount > 0 {
            return "orange"
        } else {
            return "green"
        }
    }
}
