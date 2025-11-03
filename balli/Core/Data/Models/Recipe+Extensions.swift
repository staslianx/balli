//
//  Recipe+Extensions.swift
//  balli
//
//  Extensions for Recipe to support Firestore sync
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import UIKit

extension Recipe {

    // MARK: - Firestore Sync Helpers

    /// Mark this recipe as pending sync
    func markAsPendingSync() {
        self.lastModified = Date()
        if self.source.isEmpty {
            self.source = "manual"
        }
    }

    /// Check if this entry needs to be synced
    var needsSync: Bool {
        // For now, we'll sync all entries
        // In the future, we could add sync status tracking
        return true
    }

    /// Device identifier for multi-device sync conflict resolution
    var deviceIdentifier: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    // MARK: - Computed Properties

    /// Display-friendly meal type name
    var displayMealType: String {
        guard let mealType = mealType else { return "Genel" }

        switch mealType.lowercased() {
        case "kahvaltı", "breakfast":
            return "Kahvaltı"
        case "öğle yemeği", "lunch":
            return "Öğle Yemeği"
        case "akşam yemeği", "dinner":
            return "Akşam Yemeği"
        case "ara öğün", "snack":
            return "Ara Öğün"
        default:
            return mealType.capitalized
        }
    }

    /// Display-friendly style type
    var displayStyleType: String {
        guard let styleType = styleType else { return "Genel" }
        return styleType.capitalized
    }

    /// Total time (prep + cook)
    var totalTime: Int {
        return Int(prepTime) + Int(cookTime)
    }

    /// Whether recipe has photo
    var hasPhoto: Bool {
        return imageData != nil || (imageURL != nil && !imageURL!.isEmpty)
    }

    /// Net carbs per serving (total carbs - fiber)
    var netCarbsPerServing: Double {
        return max(0, carbsPerServing - fiberPerServing)
    }
}
