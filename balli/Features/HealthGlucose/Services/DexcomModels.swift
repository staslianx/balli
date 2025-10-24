//
//  DexcomModels.swift
//  balli
//
//  Dexcom API data models for EU region
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit

// MARK: - Date Decoding Helpers

/// Custom date formatter for Dexcom API responses
/// Dexcom returns dates in multiple formats without 'Z' timezone indicator
extension JSONDecoder {
    /// Create a decoder configured for Dexcom API date formats
    static func dexcomDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // Custom date decoding strategy for Dexcom's inconsistent formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try formats in order of likelihood
            let formatters = [
                // Format with milliseconds and timezone: "2025-09-30T11:54:34.663+03:00"
                DateFormatter.dexcomWithMillisecondsTimezone,
                // Format with milliseconds and Z: "2025-09-30T08:49:34.738Z"
                DateFormatter.dexcomWithMillisecondsZ,
                // Format without milliseconds but with timezone: "2025-10-20T07:39:52+03:00"
                DateFormatter.dexcomWithoutMillisecondsTimezone,
                // Format without milliseconds but with Z: "2025-10-20T04:39:52Z"
                DateFormatter.dexcomWithoutMillisecondsZ,
                // Format with milliseconds: "2025-02-18T18:30:05.561"
                DateFormatter.dexcomWithMilliseconds,
                // Format without milliseconds: "2025-02-18T20:18:59"
                DateFormatter.dexcomWithoutMilliseconds,
                // Short format with timezone (hour:minute only): "1970-01-01T02:00+02:00"
                DateFormatter.dexcomShortFormatTimezone,
                // Short format with Z (hour:minute only): "1970-01-01T00:00Z"
                DateFormatter.dexcomShortFormatZ,
                // Short format (hour:minute only): "2025-09-30T05:55"
                DateFormatter.dexcomShortFormat
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date string '\(dateString)' does not match expected Dexcom formats"
            )
        }

        return decoder
    }
}

extension DateFormatter {
    /// Formatter for Dexcom dates with milliseconds and timezone offset (e.g., "2025-09-30T11:54:34.663+03:00")
    static let dexcomWithMillisecondsTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for Dexcom dates with milliseconds and Z (e.g., "2025-09-30T08:49:34.738Z")
    static let dexcomWithMillisecondsZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for Dexcom dates with milliseconds (e.g., "2025-02-18T18:30:05.561")
    static let dexcomWithMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for Dexcom dates without milliseconds but with timezone (e.g., "2025-10-20T07:39:52+03:00")
    static let dexcomWithoutMillisecondsTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for Dexcom dates without milliseconds but with Z (e.g., "2025-10-20T04:39:52Z")
    static let dexcomWithoutMillisecondsZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for Dexcom dates without milliseconds (e.g., "2025-02-18T20:18:59")
    static let dexcomWithoutMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for short Dexcom date format with timezone (e.g., "1970-01-01T02:00+02:00")
    static let dexcomShortFormatTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mmZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for short Dexcom date format with Z (e.g., "1970-01-01T00:00Z")
    static let dexcomShortFormatZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Formatter for short Dexcom date format (e.g., "2025-09-30T05:55")
    static let dexcomShortFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - OAuth Token Response

/// OAuth 2.0 token response from Dexcom
struct DexcomTokenResponse: Codable, Sendable {
    let accessToken: String
    let expiresIn: Int // Seconds until expiration (typically 7200 = 2 hours)
    let tokenType: String // "Bearer"
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
    }
}

// MARK: - Glucose Reading (EGV)

/// Estimated Glucose Value from Dexcom CGM
struct DexcomGlucoseReading: Codable, Sendable, Identifiable {
    let recordId: String
    let systemTime: Date
    let displayTime: Date
    let value: Int // mg/dL
    let status: String? // "high", "low", "ok", etc.
    let trend: String? // Trend arrow
    let trendRate: Double? // Rate of change

    var id: String { recordId }

    enum CodingKeys: String, CodingKey {
        case recordId
        case systemTime
        case displayTime
        case value
        case status
        case trend
        case trendRate
    }
}

/// Response wrapper for glucose readings
struct DexcomEGVResponse: Codable, Sendable {
    let recordType: String
    let recordVersion: String
    let userId: String
    let records: [DexcomGlucoseReading]
}

// MARK: - Device Information

/// Dexcom CGM device information
struct DexcomDevice: Codable, Sendable, Identifiable {
    let lastUploadDate: Date
    let alertSchedules: [AlertSchedule]
    let unitDisplayMode: String? // "mg/dL" or "mmol/L" - optional in API response
    let transmitterGeneration: String // "g6", "g7", "dexcomone", etc.
    let displayDevice: String // "receiver", "iOS", "Android"
    let deviceId: String? // transmitterId in API response

    var id: String { deviceId ?? transmitterGeneration }

    struct AlertSchedule: Codable, Sendable {
        let alertScheduleSettings: AlertScheduleSettings
        let alertSettings: [AlertSetting]?

        struct AlertScheduleSettings: Codable, Sendable {
            let alertScheduleName: String
            let isEnabled: Bool
            let isDefaultSchedule: Bool
            let startTime: String
            let endTime: String
            let daysOfWeek: [String]
            let isActive: Bool?
        }

        struct AlertSetting: Codable, Sendable {
            let alertName: String
            let value: Double
            let unit: String
            let enabled: Bool
            let systemTime: Date
            let displayTime: Date
            let snooze: Int?
            let delay: Int?
            let secondaryTriggerCondition: Int?
            let soundTheme: String?
            let soundOutputMode: String?
        }
    }

    enum CodingKeys: String, CodingKey {
        case lastUploadDate
        case alertSchedules
        case unitDisplayMode
        case transmitterGeneration
        case displayDevice
        case deviceId = "transmitterId"
    }
}

/// Response wrapper for devices
struct DexcomDevicesResponse: Codable, Sendable {
    let records: [DexcomDevice]
}

// MARK: - User Events

/// User-logged events (carbs, insulin, exercise)
struct DexcomUserEvent: Codable, Sendable, Identifiable {
    let recordId: String
    let systemTime: Date
    let displayTime: Date
    let eventType: String // "carbs", "insulin", "exercise", "health"
    let eventSubType: String?
    let value: Double?
    let unit: String?

    var id: String { recordId }

    enum CodingKeys: String, CodingKey {
        case recordId
        case systemTime
        case displayTime
        case eventType
        case eventSubType
        case value
        case unit
    }
}

/// Response wrapper for user events
struct DexcomEventsResponse: Codable, Sendable {
    let records: [DexcomUserEvent]
}

// MARK: - Data Range

/// Available data date range for user
struct DexcomDataRange: Codable, Sendable {
    let calibrations: DateRange?
    let egvs: DateRange
    let events: DateRange?

    struct DateRange: Codable, Sendable {
        let start: DateInfo
        let end: DateInfo

        struct DateInfo: Codable, Sendable {
            let systemTime: Date
            let displayTime: Date

            enum CodingKeys: String, CodingKey {
                case systemTime
                case displayTime
            }
        }
    }
}

// MARK: - Statistics

/// Glucose statistics for a time period
struct DexcomStatistics: Codable, Sendable {
    let hypoglycemiaRisk: String // "minimal", "low", "moderate", "high"
    let min: Int
    let max: Int
    let mean: Double
    let median: Int
    let variance: Double
    let stdDev: Double
    let sum: Int
    let q1: Int // First quartile
    let q2: Int // Second quartile (median)
    let q3: Int // Third quartile
    let utilizationPercent: Double // Percentage of CGM usage
    let meanDailyCalibrations: Double?
    let nDays: Int
    let nValues: Int
    let nHypoglycemia: Int // Number of low readings
    let nHyperglycemia: Int // Number of high readings

    enum CodingKeys: String, CodingKey {
        case hypoglycemiaRisk
        case min, max, mean, median, variance, stdDev, sum
        case q1, q2, q3
        case utilizationPercent
        case meanDailyCalibrations
        case nDays, nValues, nHypoglycemia, nHyperglycemia
    }
}

// MARK: - Error Response

/// Dexcom API error response
struct DexcomErrorResponse: Codable, Sendable {
    let code: String?
    let message: String
    let status: Int?
    let traceId: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case status
        case traceId
    }
}

// MARK: - Trend Arrow Helpers

extension DexcomGlucoseReading {
    /// Get user-friendly trend description
    var trendDescription: String {
        guard let trend = trend else { return "Unknown" }

        switch trend.lowercased() {
        case "none", "flat":
            return "Steady"
        case "doubleup":
            return "Rising very fast"
        case "singleup":
            return "Rising fast"
        case "fortyup":
            return "Rising"
        case "fortydown":
            return "Falling"
        case "singledown":
            return "Falling fast"
        case "doubledown":
            return "Falling very fast"
        default:
            return trend
        }
    }

    /// Get SF Symbol name for trend arrow
    var trendSymbol: String {
        guard let trend = trend else { return "arrow.forward" }

        switch trend.lowercased() {
        case "none", "flat":
            return "arrow.forward"
        case "doubleup":
            return "arrow.up.to.line"
        case "singleup":
            return "arrow.up"
        case "fortyup":
            return "arrow.up.right"
        case "fortydown":
            return "arrow.down.right"
        case "singledown":
            return "arrow.down"
        case "doubledown":
            return "arrow.down.to.line"
        default:
            return "arrow.forward"
        }
    }

    /// Convert to app's HealthGlucoseReading
    /// - Parameter deviceName: Optional device name from DexcomDevice (e.g., "Dexcom G7")
    func toHealthGlucoseReading(deviceName: String? = nil) -> HealthGlucoseReading {
        HealthGlucoseReading(
            id: UUID(),
            value: Double(value),
            unit: HKUnit(from: "mg/dL"), // Dexcom always returns mg/dL
            timestamp: displayTime,
            device: deviceName ?? "Dexcom CGM", // Use actual device name when available
            source: "com.dexcom.cgm",
            metadata: [
                "recordId": recordId,
                "trend": trend ?? "unknown",
                "trendRate": String(describing: trendRate ?? 0),
                "status": status ?? "unknown",
                "systemTime": DexcomConfiguration.dateFormatter.string(from: systemTime)
            ]
        )
    }
}

// MARK: - Device Type Helpers

extension DexcomDevice {
    /// User-friendly device name
    var deviceName: String {
        switch transmitterGeneration.lowercased() {
        case "g6":
            return "Dexcom G6"
        case "g7":
            return "Dexcom G7"
        case "dexcomone":
            return "Dexcom ONE"
        case "dexcomone+":
            return "Dexcom ONE+"
        default:
            return "Dexcom \(transmitterGeneration)"
        }
    }

    /// Device icon name
    var deviceIcon: String {
        switch transmitterGeneration.lowercased() {
        case "g6", "g7", "dexcomone", "dexcomone+":
            return "sensor.radiowaves.left.and.right.fill.fill"
        default:
            return "sensor.fill"
        }
    }
}
