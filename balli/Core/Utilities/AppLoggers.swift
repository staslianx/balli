//
//  AppLoggers.swift
//  balli
//
//  Centralized Logger registry for iOS 26 unified logging
//  Swift 6 strict concurrency compliant
//
//  Usage:
//    AppLoggers.Research.streaming.info("Processing token")
//    AppLoggers.Auth.main.error("Login failed: \(error)")
//

import OSLog

/// Centralized registry of pre-configured Logger instances
///
/// Provides organized Logger instances across functional areas:
/// - App lifecycle and configuration
/// - Authentication and user management
/// - Data persistence and sync
/// - Feature-specific loggers (research, food, recipe, health, shopping)
/// - System loggers (performance, network, security)
///
/// All loggers use subsystem: com.anaxoniclabs.balli
/// Categories are organized by functional area for easy Console.app filtering
///
/// **Console.app Usage:**
/// ```
/// // Show all app logs
/// subsystem:com.anaxoniclabs.balli
///
/// // Show only research streaming
/// subsystem:com.anaxoniclabs.balli AND category:research.streaming
///
/// // Show all errors
/// subsystem:com.anaxoniclabs.balli AND messageType == error
/// ```
/// **Thread Safety**: OSLog.Logger is thread-safe, no actor isolation needed
final class AppLoggers {

    // MARK: - Subsystem

    /// Bundle identifier used as subsystem for all loggers
    private static let subsystem = "com.anaxoniclabs.balli"

    // MARK: - Core Loggers

    /// App lifecycle and configuration logging
    struct App {
        /// App startup, termination, background/foreground transitions
        static let lifecycle = Logger(subsystem: subsystem, category: "app.lifecycle")

        /// Environment setup, feature flags, configuration changes
        static let configuration = Logger(subsystem: subsystem, category: "app.configuration")
    }

    /// Authentication and user management logging
    struct Auth {
        /// Sign in, sign out, account creation, authentication events
        static let main = Logger(subsystem: subsystem, category: "auth")

        /// User switching, profile operations, multi-account management
        static let userManagement = Logger(subsystem: subsystem, category: "user.management")
    }

    /// Data persistence and synchronization logging
    struct Data {
        /// CoreData operations, saves, fetches, validation errors
        static let coredata = Logger(subsystem: subsystem, category: "data.coredata")

        /// Background sync operations, conflict resolution
        static let sync = Logger(subsystem: subsystem, category: "data.sync")

        /// Schema migrations, data transformations, upgrades
        static let migration = Logger(subsystem: subsystem, category: "data.migration")
    }

    // MARK: - Feature Loggers

    /// Research and search functionality logging
    struct Research {
        /// SSE streaming, token processing, chunk handling
        static let streaming = Logger(subsystem: subsystem, category: "research.streaming")

        /// Search requests, tier selection, query processing
        static let search = Logger(subsystem: subsystem, category: "research.search")

        /// Markdown parsing, citation validation, deduplication, text processing
        static let parsing = Logger(subsystem: subsystem, category: "research.parsing")

        /// API calls, network operations, request/response logging
        static let network = Logger(subsystem: subsystem, category: "research.network")

        /// Source deduplication tracking
        static let deduplication = Logger(subsystem: subsystem, category: "research.deduplication")

        /// Research stopping condition evaluation
        static let stopping = Logger(subsystem: subsystem, category: "research.stopping")
    }

    /// Food and meal tracking logging
    struct Food {
        /// Manual entry, voice input, food logging
        static let entry = Logger(subsystem: subsystem, category: "food.entry")

        /// Camera capture, barcode scanning, label recognition
        static let scanning = Logger(subsystem: subsystem, category: "food.scanning")

        /// Meal history, favorites, archive operations
        static let archive = Logger(subsystem: subsystem, category: "food.archive")
    }

    /// Recipe management logging
    struct Recipe {
        /// AI recipe creation, generation requests
        static let generation = Logger(subsystem: subsystem, category: "recipe.generation")

        /// Recipe conversation memory, context tracking
        static let memory = Logger(subsystem: subsystem, category: "recipe.memory")
    }

    /// Health and glucose tracking logging
    struct Health {
        /// HealthKit authorization, permission requests
        static let permissions = Logger(subsystem: subsystem, category: "health.permissions")

        /// Glucose readings, Dexcom sync, health data
        static let glucose = Logger(subsystem: subsystem, category: "health.glucose")

        /// Health alerts, reminders, notifications
        static let notifications = Logger(subsystem: subsystem, category: "health.notifications")
    }

    /// Shopping list and location logging
    struct Shopping {
        /// Shopping list operations, item management
        static let list = Logger(subsystem: subsystem, category: "shopping.list")

        /// Store lookup, location services, geofencing
        static let location = Logger(subsystem: subsystem, category: "shopping.location")
    }

    /// UI and presentation logging
    struct UI {
        /// Navigation events, deep links, screen transitions
        static let navigation = Logger(subsystem: subsystem, category: "ui.navigation")

        /// View rendering, layout performance, animation issues
        static let rendering = Logger(subsystem: subsystem, category: "ui.rendering")

        /// Camera preview, capture state, camera operations
        static let camera = Logger(subsystem: subsystem, category: "ui.camera")
    }

    // MARK: - System Loggers

    /// Performance monitoring and diagnostics
    struct Performance {
        /// Slow operations, memory warnings, performance issues
        static let main = Logger(subsystem: subsystem, category: "performance")

        /// Animation frame rate issues, rendering delays
        static let animation = Logger(subsystem: subsystem, category: "performance.animation")
    }

    /// Network operations logging
    struct Network {
        /// General API calls, HTTP requests
        static let api = Logger(subsystem: subsystem, category: "network.api")

        /// Firebase operations, Firestore, Cloud Functions
        static let firebase = Logger(subsystem: subsystem, category: "network.firebase")

        /// Network failures, timeouts, connectivity issues
        static let error = Logger(subsystem: subsystem, category: "network.error")
    }

    /// Security operations logging
    struct Security {
        /// Keychain access, credential storage
        static let keychain = Logger(subsystem: subsystem, category: "security.keychain")

        /// Data encryption, secure operations
        static let encryption = Logger(subsystem: subsystem, category: "security.encryption")
    }
}

// MARK: - Usage Examples

/*
 **Basic Logging:**

 AppLoggers.Research.streaming.info("Processing token")
 AppLoggers.Auth.main.error("Login failed")

 **Log Levels:**

 .debug   - Detailed information for debugging (DEBUG builds only)
 .info    - General informational messages
 .notice  - Significant events worth noting
 .error   - Recoverable errors
 .fault   - Critical failures

 **Privacy:**

 // Public - safe for logs that leave device
 logger.info("User ID: \(userId, privacy: .public)")

 // Private - redacted in logs (default)
 logger.error("Email: \(email, privacy: .private)")

 // Sensitive - never logged
 logger.debug("API key: \(key, privacy: .sensitive)")

 **Console.app Filtering:**

 // All balli logs
 subsystem:com.anaxoniclabs.balli

 // Research streaming only
 subsystem:com.anaxoniclabs.balli AND category:research.streaming

 // All errors
 subsystem:com.anaxoniclabs.balli AND (messageType == error OR messageType == fault)

 // Recent research logs
 subsystem:com.anaxoniclabs.balli AND category BEGINSWITH "research" AND timestamp >= "now-5m"
 */
