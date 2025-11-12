//
//  NetworkMonitor.swift
//  balli
//
//  Simple network reachability monitor using NWPathMonitor
//  Swift 6 strict concurrency compliant
//

import Foundation
import Network
import OSLog

/// Monitors network connectivity using NWPathMonitor
/// Provides simple online/offline status for the app
@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Properties

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.balli.networkmonitor")
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "NetworkMonitor")

    // LIFECYCLE FIX: Track monitoring state and active subscribers
    private var isMonitoring = false
    private var activeSubscribers: Set<String> = []

    // MARK: - Singleton

    static let shared = NetworkMonitor()

    // MARK: - Types

    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown

        var description: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Wired"
            case .unknown: return "Unknown"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Note: Monitoring is started explicitly by AppDelegate to control initialization timing
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public Methods

    /// Start monitoring network changes with subscriber tracking
    func startMonitoring(subscriber: String = "app") {
        activeSubscribers.insert(subscriber)

        guard !isMonitoring else {
            logger.debug("Already monitoring - added subscriber: \(subscriber, privacy: .public)")
            return
        }

        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unknown
                }

                // Log connectivity changes
                if wasConnected != self.isConnected {
                    if self.isConnected {
                        self.logger.notice("Network connected via \(self.connectionType.description)")
                        NotificationCenter.default.post(name: .networkDidBecomeReachable, object: nil)

                        // Process offline queue when network is restored
                        Task {
                            await OfflineQueue.shared.processQueue()
                        }
                    } else {
                        self.logger.warning("Network disconnected")
                        NotificationCenter.default.post(name: .networkDidBecomeUnreachable, object: nil)
                    }
                }
            }
        }

        monitor.start(queue: queue)
        logger.info("Network monitoring started with subscriber: \(subscriber, privacy: .public)")
    }

    /// Stop monitoring network changes with subscriber tracking
    func stopMonitoring(subscriber: String = "app") {
        activeSubscribers.remove(subscriber)

        guard activeSubscribers.isEmpty else {
            let subscribers = self.activeSubscribers
            logger.debug("Still have active subscribers - not stopping: \(subscribers, privacy: .public)")
            return
        }

        guard isMonitoring else {
            logger.debug("Already stopped")
            return
        }

        isMonitoring = false
        monitor.cancel()
        logger.info("Network monitoring stopped - no active subscribers")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkDidBecomeReachable = Notification.Name("networkDidBecomeReachable")
    static let networkDidBecomeUnreachable = Notification.Name("networkDidBecomeUnreachable")
    static let offlineTranscriptionCompleted = Notification.Name("offlineTranscriptionCompleted")
}
