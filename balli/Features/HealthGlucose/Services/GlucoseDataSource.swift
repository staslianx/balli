//
//  GlucoseDataSource.swift
//  balli
//
//  Protocol-based abstraction for glucose data sources
//  Enables hybrid approach combining Official API + SHARE API
//  Swift 6 strict concurrency compliant
//

import Foundation

// MARK: - Glucose Data Source Protocol

/// Protocol for glucose data sources (Official API, SHARE API, or Hybrid)
protocol GlucoseDataSource: Sendable {
    /// Fetch glucose readings for a specific time range
    /// - Parameters:
    ///   - startDate: Start of time range
    ///   - endDate: End of time range (defaults to now)
    /// - Returns: Array of glucose readings in app's standard format
    func fetchReadings(
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthGlucoseReading]

    /// Fetch the most recent glucose reading
    /// - Returns: Latest reading if available
    func fetchLatestReading() async throws -> HealthGlucoseReading?

    /// Check if data source is available and connected
    /// - Returns: True if data source can provide data
    func isAvailable() async -> Bool

    /// Get data source information for display/debugging
    var sourceInfo: DataSourceInfo { get }
}

// MARK: - Data Source Info

/// Information about a data source
struct DataSourceInfo: Sendable {
    let name: String
    let type: DataSourceType
    let delay: TimeInterval // Typical data delay in seconds
    let description: String

    enum DataSourceType: String, Sendable {
        case official = "Official API"
        case share = "SHARE API"
        case hybrid = "Hybrid"
        case healthKit = "HealthKit"
    }
}

// MARK: - Official API Data Source

/// Data source wrapping the official Dexcom API
final class DexcomOfficialDataSource: GlucoseDataSource, @unchecked Sendable {
    private let service: DexcomService
    private let logger = AppLoggers.Health.glucose

    init(service: DexcomService) {
        self.service = service
    }

    var sourceInfo: DataSourceInfo {
        DataSourceInfo(
            name: "Dexcom Official API",
            type: .official,
            delay: 3 * 60 * 60, // 3 hours in EU
            description: "FDA-cleared Official API with 3-hour regulatory delay in EU region"
        )
    }

    func fetchReadings(startDate: Date, endDate: Date) async throws -> [HealthGlucoseReading] {
        logger.info("📊 Fetching from Official API: \(startDate) to \(endDate)")

        // DexcomService is @MainActor, so call it from main actor
        let readings = try await service.fetchGlucoseReadings(
            startDate: startDate,
            endDate: endDate
        )

        logger.info("✅ Official API returned \(readings.count) readings")
        return readings
    }

    func fetchLatestReading() async throws -> HealthGlucoseReading? {
        logger.info("📊 Fetching latest from Official API")

        // Fetch the most recent reading (last 5 minutes)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .minute, value: -5, to: endDate) ?? endDate

        let readings = try await fetchReadings(startDate: startDate, endDate: endDate)
        let latest = readings.max(by: { $0.timestamp < $1.timestamp })

        if latest != nil {
            logger.info("✅ Official API returned latest reading")
        } else {
            logger.warning("⚠️ Official API returned no recent data")
        }

        return latest
    }

    func isAvailable() async -> Bool {
        await MainActor.run {
            service.isConnected
        }
    }
}

// MARK: - SHARE API Data Source

/// Data source wrapping the unofficial Dexcom SHARE API
final class DexcomShareDataSource: GlucoseDataSource, @unchecked Sendable {
    private let service: DexcomShareService
    private let logger = AppLoggers.Health.glucose

    init(service: DexcomShareService) {
        self.service = service
    }

    var sourceInfo: DataSourceInfo {
        DataSourceInfo(
            name: "Dexcom SHARE API",
            type: .share,
            delay: 5 * 60, // ~5 minutes
            description: "Unofficial SHARE API providing near real-time data (~5 min delay)"
        )
    }

    func fetchReadings(startDate: Date, endDate: Date) async throws -> [HealthGlucoseReading] {
        logger.info("📱 Fetching from SHARE API: \(startDate) to \(endDate)")

        // DexcomShareService is @MainActor
        let shareReadings = try await service.fetchGlucoseReadings(
            startDate: startDate,
            endDate: endDate
        )

        let readings = await service.convertToHealthReadings(shareReadings)

        logger.info("✅ SHARE API returned \(readings.count) readings")
        return readings
    }

    func fetchLatestReading() async throws -> HealthGlucoseReading? {
        logger.info("📱 Fetching latest from SHARE API")

        // DexcomShareService is @MainActor
        let shareReading = try await service.fetchLatestReading()

        guard let shareReading = shareReading else {
            logger.info("⚠️ SHARE API returned no data")
            return nil
        }

        let reading = shareReading.toHealthGlucoseReading()
        logger.info("✅ SHARE API returned latest reading")
        return reading
    }

    func isAvailable() async -> Bool {
        await MainActor.run {
            service.isConnected
        }
    }
}

// MARK: - Hybrid Data Source

/// Hybrid data source combining Official API (>3hrs) and SHARE API (<3hrs)
/// Provides best of both worlds: regulatory compliance + real-time data
final class HybridGlucoseDataSource: GlucoseDataSource {
    private let officialSource: DexcomOfficialDataSource
    private let shareSource: DexcomShareDataSource
    private let logger = AppLoggers.Health.glucose

    // Time boundary: Use SHARE for data newer than this, Official for older
    // 3 hours + 15 minute buffer to ensure Official API data is available
    private let timeBoundary: TimeInterval = (3 * 60 * 60) + (15 * 60)

    init(officialService: DexcomService, shareService: DexcomShareService) {
        self.officialSource = DexcomOfficialDataSource(service: officialService)
        self.shareSource = DexcomShareDataSource(service: shareService)
    }

    var sourceInfo: DataSourceInfo {
        DataSourceInfo(
            name: "Hybrid (Official + SHARE)",
            type: .hybrid,
            delay: 5 * 60, // Reports the best-case delay
            description: "Combines Official API (>3hrs) with SHARE API (<3hrs) for complete coverage"
        )
    }

    func fetchReadings(startDate: Date, endDate: Date) async throws -> [HealthGlucoseReading] {
        logger.info("🔄 HYBRID: Fetching \(startDate) to \(endDate)")

        let now = Date()
        let splitPoint = now.addingTimeInterval(-timeBoundary)

        logger.info("🔄 HYBRID: Split point = \(splitPoint)")
        logger.info("🔄 HYBRID: Recent data (<\(self.timeBoundary/3600)hrs): SHARE API")
        logger.info("🔄 HYBRID: Historical data (>\(self.timeBoundary/3600)hrs): Official API")

        // Determine which sources to use based on time range
        let needsShareData = endDate > splitPoint
        let needsOfficialData = startDate < splitPoint

        var allReadings: [HealthGlucoseReading] = []

        // Fetch from Official API for historical data (if needed)
        if needsOfficialData {
            let officialEndDate = min(endDate, splitPoint)

            logger.info("📊 Fetching historical from Official API: \(startDate) to \(officialEndDate)")

            do {
                let officialReadings = try await officialSource.fetchReadings(
                    startDate: startDate,
                    endDate: officialEndDate
                )
                allReadings.append(contentsOf: officialReadings)
                logger.info("✅ Official API: \(officialReadings.count) readings")
            } catch {
                logger.error("⚠️ Official API failed: \(error.localizedDescription)")
                // Don't throw - try to proceed with SHARE data only
            }
        }

        // Fetch from SHARE API for recent data (if needed)
        if needsShareData {
            let shareStartDate = max(startDate, splitPoint)

            logger.info("📱 Fetching recent from SHARE API: \(shareStartDate) to \(endDate)")

            do {
                let shareReadings = try await shareSource.fetchReadings(
                    startDate: shareStartDate,
                    endDate: endDate
                )
                allReadings.append(contentsOf: shareReadings)
                logger.info("✅ SHARE API: \(shareReadings.count) readings")
            } catch {
                logger.error("⚠️ SHARE API failed: \(error.localizedDescription)")
                // If Official API also failed, throw error
                if allReadings.isEmpty {
                    throw error
                }
            }
        }

        // Remove duplicates (might occur at boundary)
        let uniqueReadings = removeDuplicates(allReadings)

        // Sort by timestamp descending (newest first)
        let sortedReadings = uniqueReadings.sorted { $0.timestamp > $1.timestamp }

        logger.info("🔄 HYBRID: Total \(sortedReadings.count) unique readings")

        // NOTE: DO NOT post .glucoseDataDidUpdate here - this creates infinite loop!
        // The notification is posted by the underlying services (DexcomService, DexcomShareService)
        // when they actually fetch new data from APIs. This hybrid source just combines data.

        return sortedReadings
    }

    func fetchLatestReading() async throws -> HealthGlucoseReading? {
        logger.info("🔄 HYBRID: Fetching latest reading")

        // Always use SHARE for latest reading (real-time data)
        if await shareSource.isAvailable() {
            logger.info("📱 Using SHARE API for latest reading (real-time)")
            do {
                return try await shareSource.fetchLatestReading()
            } catch {
                logger.warning("⚠️ SHARE failed, falling back to Official API: \(error.localizedDescription)")
            }
        }

        // Fallback to Official API if SHARE unavailable
        if await officialSource.isAvailable() {
            logger.info("📊 Falling back to Official API for latest reading")
            return try await officialSource.fetchLatestReading()
        }

        logger.error("❌ No data sources available")
        throw GlucoseDataSourceError.noSourcesAvailable
    }

    func isAvailable() async -> Bool {
        // Hybrid is available if at least one source is available
        let officialAvailable = await officialSource.isAvailable()
        let shareAvailable = await shareSource.isAvailable()

        let available = officialAvailable || shareAvailable
        logger.info("🔄 HYBRID: Available = \(available) (Official: \(officialAvailable), SHARE: \(shareAvailable))")
        return available
    }

    // MARK: - Helper Methods

    /// Remove duplicate readings based on timestamp and value
    private func removeDuplicates(_ readings: [HealthGlucoseReading]) -> [HealthGlucoseReading] {
        var seen = Set<String>()
        return readings.filter { reading in
            // Create unique key from timestamp and value
            let key = "\(Int(reading.timestamp.timeIntervalSince1970))_\(Int(reading.value))"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}

// MARK: - Errors

enum GlucoseDataSourceError: LocalizedError {
    case noSourcesAvailable
    case allSourcesFailed

    var errorDescription: String? {
        switch self {
        case .noSourcesAvailable:
            return "Hiçbir veri kaynağı mevcut değil"
        case .allSourcesFailed:
            return "Tüm veri kaynakları başarısız oldu"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noSourcesAvailable:
            return "Lütfen Dexcom bağlantılarınızı kontrol edin"
        case .allSourcesFailed:
            return "İnternet bağlantınızı kontrol edip tekrar deneyin"
        }
    }
}
