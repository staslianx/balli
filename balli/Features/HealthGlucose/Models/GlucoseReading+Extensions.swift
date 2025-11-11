//
//  GlucoseReading+Extensions.swift
//  balli
//
//  Created for Business Logic and Convenience Methods
//

import Foundation
import CoreData

// MARK: - Glucose Source Enum
public enum GlucoseSource: String, CaseIterable {
    case manual = "manual"
    case healthKit = "healthkit"
    case cgm = "cgm" // Legacy - kept for backwards compatibility
    case dexcomOfficial = "dexcom_official" // Official API (>3hr delay)
    case dexcomShare = "dexcom_share" // SHARE API (real-time)

    var displayName: String {
        switch self {
        case .manual: return NSLocalizedString("glucose.source.manual", comment: "Manual Entry")
        case .healthKit: return NSLocalizedString("glucose.source.healthkit", comment: "Apple Health")
        case .cgm: return NSLocalizedString("glucose.source.cgm", comment: "CGM Device")
        case .dexcomOfficial: return NSLocalizedString("glucose.source.dexcom_official", comment: "Dexcom (Official)")
        case .dexcomShare: return NSLocalizedString("glucose.source.dexcom_share", comment: "Dexcom (Live)")
        }
    }

    var icon: String {
        switch self {
        case .manual: return "pencil"
        case .healthKit: return "heart.text.square"
        case .cgm, .dexcomOfficial, .dexcomShare: return "sensor.radiowaves.left.and.right.fill"
        }
    }
}

// MARK: - Sync Status Enum
public enum SyncStatus: String, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .synced: return NSLocalizedString("sync.status.synced", comment: "Synced")
        case .pending: return NSLocalizedString("sync.status.pending", comment: "Pending")
        case .failed: return NSLocalizedString("sync.status.failed", comment: "Failed")
        }
    }
    
    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .pending: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Glucose Level Range
public enum GlucoseRange {
    case veryLow       // < 54 mg/dL (< 3.0 mmol/L)
    case low           // 54-69 mg/dL (3.0-3.8 mmol/L)
    case normal        // 70-140 mg/dL (3.9-7.8 mmol/L)
    case elevated      // 141-180 mg/dL (7.9-10.0 mmol/L)
    case high          // 181-250 mg/dL (10.1-13.9 mmol/L)
    case veryHigh      // > 250 mg/dL (> 13.9 mmol/L)
    
    init(mgDL: Double) {
        switch mgDL {
        case ..<54: self = .veryLow
        case 54..<70: self = .low
        case 70..<141: self = .normal
        case 141..<181: self = .elevated
        case 181..<251: self = .high
        default: self = .veryHigh
        }
    }
    
    var color: String {
        switch self {
        case .veryLow: return "red"
        case .low: return "orange"
        case .normal: return "green"
        case .elevated: return "yellow"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
    
    var displayName: String {
        switch self {
        case .veryLow: return NSLocalizedString("glucose.range.veryLow", comment: "Very Low")
        case .low: return NSLocalizedString("glucose.range.low", comment: "Low")
        case .normal: return NSLocalizedString("glucose.range.normal", comment: "Normal")
        case .elevated: return NSLocalizedString("glucose.range.elevated", comment: "Elevated")
        case .high: return NSLocalizedString("glucose.range.high", comment: "High")
        case .veryHigh: return NSLocalizedString("glucose.range.veryHigh", comment: "Very High")
        }
    }
    
    var requiresAction: Bool {
        switch self {
        case .veryLow, .veryHigh: return true
        default: return false
        }
    }
}

// MARK: - GlucoseReading Business Logic
extension GlucoseReading {
    
    /// Source as enum
    var sourceEnum: GlucoseSource? {
        return GlucoseSource(rawValue: source)
    }
    
    /// Sync status as enum
    var syncStatusEnum: SyncStatus? {
        get { return SyncStatus(rawValue: syncStatus) }
        set { syncStatus = newValue?.rawValue ?? "pending" }
    }
    
    /// Glucose range classification
    var glucoseRange: GlucoseRange {
        return GlucoseRange(mgDL: value)
    }
    
    /// Convert mg/dL to mmol/L
    var valueInMmol: Double {
        return value / 18.0182
    }
    
    /// Formatted value with unit
    func formattedValue(unit: String = "mg/dL") -> String {
        if unit == "mmol/L" {
            return String(format: "%.1f mmol/L", valueInMmol)
        } else {
            return String(format: "%.0f mg/dL", value)
        }
    }
    
    /// Formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Time since reading
    var timeAgoDescription: String {
        let interval = Date().timeIntervalSince(timestamp)
        let hours = interval / 3600
        
        if hours < 1 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else if hours < 24 {
            let hoursInt = Int(hours)
            return hoursInt == 1 ? "1 hour ago" : "\(hoursInt) hours ago"
        } else {
            let days = Int(hours / 24)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    
    /// Whether this reading needs sync to HealthKit
    var needsHealthKitSync: Bool {
        return source == GlucoseSource.manual.rawValue && 
               syncStatusEnum != .synced &&
               healthKitUUID == nil
    }
    
    /// Mark as synced with HealthKit
    func markAsSynced(healthKitID: String) {
        healthKitUUID = healthKitID
        syncStatusEnum = .synced
        lastSyncAttempt = Date()
    }
    
    /// Mark sync as failed
    func markSyncFailed() {
        syncStatusEnum = .failed
        lastSyncAttempt = Date()
    }
    
    /// Associated meal if within time window
    var associatedMeal: MealEntry? {
        guard let meal = mealEntry else { return nil }
        
        // Check if reading is within 3 hours after meal
        let timeSinceMeal = timestamp.timeIntervalSince(meal.timestamp)
        if timeSinceMeal >= 0 && timeSinceMeal <= 3 * 3600 {
            return meal
        }
        
        return nil
    }
    
    /// Time relationship to meal
    var mealTimeRelationship: String? {
        guard let meal = mealEntry else { return nil }
        
        let timeDiff = timestamp.timeIntervalSince(meal.timestamp)
        let minutes = Int(abs(timeDiff) / 60)
        
        if timeDiff < 0 {
            // Before meal
            return minutes == 1 ? "1 minute before meal" : "\(minutes) minutes before meal"
        } else {
            // After meal
            return minutes == 1 ? "1 minute after meal" : "\(minutes) minutes after meal"
        }
    }
}

// MARK: - Fetch Requests
extension GlucoseReading {
    
    /// Fetch readings for a specific date
    @nonobjc public class func readingsForDate(_ date: Date) -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            // Fallback: use 24 hours from start of day
            let endOfDay = startOfDay.addingTimeInterval(86400)
            request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
                                            startOfDay as NSDate, endOfDay as NSDate)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: true)
            ]
            return request
        }

        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@",
                                        startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: true)
        ]

        return request
    }
    
    /// Fetch readings in a date range
    @nonobjc public class func readingsInRange(from startDate: Date, to endDate: Date) -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                                        startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: false)
        ]
        
        return request
    }
    
    /// Fetch recent readings
    @nonobjc public class func recentReadings(limit: Int = 50) -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: false)
        ]
        request.fetchLimit = limit
        
        return request
    }
    
    /// Fetch readings by source
    @nonobjc class func readingsByResearchSource(_ source: GlucoseSource) -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "source == %@", source.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: false)
        ]
        
        return request
    }
    
    /// Fetch readings needing HealthKit sync
    @nonobjc public class func needingSyncRequest() -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "source == %@ AND syncStatus != %@ AND healthKitUUID == nil",
                                        GlucoseSource.manual.rawValue, SyncStatus.synced.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: true)
        ]
        
        return request
    }
    
    /// Fetch readings in specific range
    @nonobjc public class func readingsInGlucoseRange(_ range: GlucoseRange) -> NSFetchRequest<GlucoseReading> {
        let request = fetchRequest()
        
        let predicate: NSPredicate
        switch range {
        case .veryLow:
            predicate = NSPredicate(format: "value < 54")
        case .low:
            predicate = NSPredicate(format: "value >= 54 AND value < 70")
        case .normal:
            predicate = NSPredicate(format: "value >= 70 AND value < 141")
        case .elevated:
            predicate = NSPredicate(format: "value >= 141 AND value < 181")
        case .high:
            predicate = NSPredicate(format: "value >= 181 AND value < 251")
        case .veryHigh:
            predicate = NSPredicate(format: "value >= 251")
        }
        
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: false)
        ]
        
        return request
    }
}

// MARK: - HealthGlucoseReading Conversion

import HealthKit

extension GlucoseReading {
    /// Convert CoreData GlucoseReading to HealthGlucoseReading struct
    func toHealthGlucoseReading() -> HealthGlucoseReading {
        HealthGlucoseReading(
            id: self.id,
            value: self.value,
            unit: HKUnit(from: "mg/dL"),
            timestamp: self.timestamp,
            device: self.deviceName,
            source: self.source,
            metadata: self.notes.map { ["notes": $0] }
        )
    }
}

extension HealthGlucoseReading {
    /// Create a new CoreData GlucoseReading from HealthGlucoseReading
    /// - Parameter context: The NSManagedObjectContext to create the object in
    /// - Returns: New GlucoseReading entity
    func toCoreDataReading(in context: NSManagedObjectContext) -> GlucoseReading {
        let reading = GlucoseReading(context: context)
        reading.id = self.id
        reading.timestamp = self.timestamp
        reading.value = self.value
        reading.source = self.source ?? "unknown"
        reading.deviceName = self.device
        reading.syncStatus = "synced"
        reading.notes = self.metadata?["notes"]
        return reading
    }
}

// MARK: - DexcomShareGlucoseReading Conversion
// Note: toHealthGlucoseReading() is already defined in DexcomShareModels.swift
