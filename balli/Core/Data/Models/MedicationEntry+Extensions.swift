//
//  MedicationEntry+Extensions.swift
//  balli
//
//  Extensions for MedicationEntry to support Firestore sync
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData
import UIKit

extension MedicationEntry {

    // MARK: - Firestore Sync Helpers

    /// Mark this medication entry as pending sync
    func markAsPendingSync() {
        self.lastModified = Date()
        self.source = "manual"
    }

    /// Check if this entry needs to be synced
    var needsSync: Bool {
        // For now, we'll sync all entries
        // In the future, we could add sync status tracking
        return true
    }

    /// Device identifier for multi-device sync conflict resolution
    var deviceIdentifier: String {
        // Access UIDevice from MainActor context
        // This is safe because the device identifier is a constant for app lifetime
        MainActor.assumeIsolated {
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        }
    }
}

// MARK: - Computed Properties

extension MedicationEntry {

    /// Display-friendly medication type name
    var displayMedicationType: String {
        switch medicationType {
        case "basal_insulin":
            return "Bazal İnsülin"
        case "bolus_insulin":
            return "Bolus İnsülin"
        case "rapid_insulin":
            return "Hızlı İnsülin"
        case "long_acting":
            return "Uzun Etkili"
        default:
            return medicationType.capitalized
        }
    }

    /// Display-friendly dosage with unit
    var displayDosage: String {
        "\(Int(dosage)) \(dosageUnit)"
    }

    /// Whether this is a basal insulin dose (Lantus, etc.)
    var isBasalInsulin: Bool {
        medicationType == "basal_insulin" || medicationName.lowercased().contains("lantus")
    }

    /// Whether this is connected to a meal
    var isMealConnected: Bool {
        mealEntry != nil
    }
}
