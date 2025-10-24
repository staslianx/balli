//
//  DexcomShareModels.swift
//  balli
//
//  Dexcom SHARE API data models (unofficial API)
//  Swift 6 strict concurrency compliant
//
//  IMPORTANT: This is an unofficial API used by Nightscout, Loop, xDrip
//  For personal use only - provides ~5 min delay vs 3-hour official API delay
//

import Foundation
import HealthKit

// MARK: - Authentication

/// Request body for SHARE API authentication
struct DexcomShareAuthRequest: Codable, Sendable {
    let accountName: String
    let password: String
    let applicationId: String

    enum CodingKeys: String, CodingKey {
        case accountName
        case password
        case applicationId
    }
}

/// Request body for SHARE API login by account ID
struct DexcomShareLoginByIdRequest: Codable, Sendable {
    let accountId: String
    let password: String
    let applicationId: String

    enum CodingKeys: String, CodingKey {
        case accountId
        case password
        case applicationId
    }
}

/// Response from SHARE API authentication - just returns session ID as plain string
/// Not JSON - just the UUID string like "00000000-0000-0000-0000-000000000000"
typealias DexcomShareSessionID = String

// MARK: - Glucose Reading

/// Glucose reading from SHARE API
/// Much simpler format than official API - just essential data
struct DexcomShareGlucoseReading: Codable, Sendable, Identifiable {
    let WT: String      // Wall Time - ISO8601 timestamp with timezone offset
    let ST: String      // System Time - ISO8601 timestamp with timezone offset
    let DT: String      // Display Time - ISO8601 timestamp (device local time)
    let Value: Int      // Glucose value in mg/dL
    let Trend: String   // Trend direction (e.g., "Flat", "FortyFiveUp", "SingleUp", etc.)

    var id: String { DT + String(Value) }

    enum CodingKeys: String, CodingKey {
        case WT, ST, DT, Value, Trend
    }

    /// Parse date from SHARE API timestamp format
    /// SHARE returns dates like "Date(1640995200000)" (Unix timestamp in milliseconds)
    /// OR "/Date(1640995200000)/" format
    /// OR ISO8601 format like "2025-01-31T14:30:00"
    private static func parseShareDate(_ dateString: String) -> Date? {
        // Try Unix timestamp format: "Date(1640995200000)" or "Date(1640995200000+0300)"
        if dateString.hasPrefix("Date(") && dateString.hasSuffix(")") {
            let timestampString = dateString
                .replacingOccurrences(of: "Date(", with: "")
                .replacingOccurrences(of: ")", with: "")

            // Handle optional timezone offset like "Date(1640995200000+0300)"
            let components = timestampString.components(separatedBy: CharacterSet(charactersIn: "+-"))
            if let milliseconds = Double(components[0]) {
                return Date(timeIntervalSince1970: milliseconds / 1000.0)
            }
        }

        // Try legacy format with slashes: "/Date(1640995200000)/"
        if dateString.hasPrefix("/Date(") && dateString.hasSuffix(")/") {
            let timestampString = dateString
                .replacingOccurrences(of: "/Date(", with: "")
                .replacingOccurrences(of: ")/", with: "")

            // Handle optional timezone offset like "/Date(1640995200000+0300)/"
            let components = timestampString.components(separatedBy: CharacterSet(charactersIn: "+-"))
            if let milliseconds = Double(components[0]) {
                return Date(timeIntervalSince1970: milliseconds / 1000.0)
            }
        }

        // Try ISO8601 format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try basic format without timezone
        let basicFormatter = DateFormatter()
        basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        basicFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Assume UTC
        basicFormatter.locale = Locale(identifier: "en_US_POSIX")
        return basicFormatter.date(from: dateString)
    }

    /// Display time as Date object
    var displayTime: Date {
        Self.parseShareDate(DT) ?? Date()
    }

    /// System time as Date object
    var systemTime: Date {
        Self.parseShareDate(ST) ?? Date()
    }

    /// Wall time as Date object
    var wallTime: Date {
        Self.parseShareDate(WT) ?? Date()
    }

    /// Convert to app's HealthGlucoseReading
    func toHealthGlucoseReading() -> HealthGlucoseReading {
        HealthGlucoseReading(
            id: UUID(),
            value: Double(Value),
            unit: HKUnit(from: "mg/dL"), // SHARE always returns mg/dL
            timestamp: displayTime,
            device: "Dexcom SHARE",
            source: "com.dexcom.share",
            metadata: [
                "trend": Trend,
                "systemTime": ST,
                "wallTime": WT,
                "displayTime": DT,
                "source": "share-api"
            ]
        )
    }
}

// MARK: - Trend Helpers

extension DexcomShareGlucoseReading {
    /// Get user-friendly trend description in Turkish
    var trendDescription: String {
        switch Trend {
        case "None", "Flat":
            return "Sabit"
        case "DoubleUp":
            return "Çok hızlı yükseliyor"
        case "SingleUp":
            return "Hızlı yükseliyor"
        case "FortyFiveUp":
            return "Yükseliyor"
        case "FortyFiveDown":
            return "Düşüyor"
        case "SingleDown":
            return "Hızlı düşüyor"
        case "DoubleDown":
            return "Çok hızlı düşüyor"
        default:
            return Trend
        }
    }

    /// Get SF Symbol name for trend arrow
    var trendSymbol: String {
        switch Trend {
        case "None", "Flat":
            return "arrow.forward"
        case "DoubleUp":
            return "arrow.up.to.line"
        case "SingleUp":
            return "arrow.up"
        case "FortyFiveUp":
            return "arrow.up.right"
        case "FortyFiveDown":
            return "arrow.down.right"
        case "SingleDown":
            return "arrow.down"
        case "DoubleDown":
            return "arrow.down.to.line"
        default:
            return "arrow.forward"
        }
    }

    /// Rate of change estimation based on trend
    /// Returns approximate mg/dL per minute
    var estimatedTrendRate: Double {
        switch Trend {
        case "DoubleUp":
            return 3.0  // >3 mg/dL/min
        case "SingleUp":
            return 2.0  // 2-3 mg/dL/min
        case "FortyFiveUp":
            return 1.0  // 1-2 mg/dL/min
        case "Flat", "None":
            return 0.0  // No change
        case "FortyFiveDown":
            return -1.0 // -1 to -2 mg/dL/min
        case "SingleDown":
            return -2.0 // -2 to -3 mg/dL/min
        case "DoubleDown":
            return -3.0 // <-3 mg/dL/min
        default:
            return 0.0
        }
    }
}

// MARK: - Error Response

/// SHARE API error response
/// Sometimes returns HTML error pages, sometimes JSON
struct DexcomShareErrorResponse: Codable, Sendable {
    let message: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case message = "Message"
        case code = "Code"
    }
}

// MARK: - Server Configuration

/// SHARE API server endpoints
enum DexcomShareServer: String, Sendable {
    case us = "https://share2.dexcom.com"
    case international = "https://shareous1.dexcom.com"

    var baseURL: URL {
        URL(string: rawValue)!
    }

    /// Authentication endpoint
    var authURL: URL {
        baseURL.appendingPathComponent("/ShareWebServices/Services/General/AuthenticatePublisherAccount")
    }

    /// Login (alternative auth) endpoint
    var loginURL: URL {
        baseURL.appendingPathComponent("/ShareWebServices/Services/General/LoginPublisherAccountByName")
    }

    /// Login by account ID endpoint (step 2 of two-step auth)
    var loginByIdURL: URL {
        baseURL.appendingPathComponent("/ShareWebServices/Services/General/LoginPublisherAccountById")
    }

    /// Get latest glucose readings endpoint
    var glucoseURL: URL {
        baseURL.appendingPathComponent("/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues")
    }

    /// Region display name
    var regionName: String {
        switch self {
        case .us:
            return "United States"
        case .international:
            return "International (Non-US)"
        }
    }
}

// MARK: - Application IDs

/// Known SHARE API application IDs from community
/// These are public IDs used by Nightscout, Loop, xDrip
enum DexcomShareApplicationID: String, Sendable {
    /// Nightscout default application ID
    case nightscout = "d89443d2-327c-4a6f-89e5-496bbb0317db"

    /// xDrip/Loop shared application ID
    /// Note: xDrip and Loop both use the same application ID in the community
    case xdripLoop = "d8665ade-9673-4e27-9ff6-92db4ce13d13"

    /// Default - use xDrip/Loop's ID (confirmed working with current SHARE API)
    static var `default`: DexcomShareApplicationID {
        .xdripLoop
    }
}

// MARK: - Constants

extension DexcomShareServer {
    /// Recommended maximum number of readings to request
    /// SHARE API can return up to 288 readings (24 hours of 5-min readings)
    static let maxReadings = 288

    /// Recommended minimum number of readings to request
    static let minReadings = 1

    /// Default number of readings to request (12 hours)
    static let defaultReadings = 144
}
