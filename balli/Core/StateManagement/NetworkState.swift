//
//  NetworkState.swift
//  balli
//
//  Network connectivity and offline queue state management
//

import SwiftUI
import Combine
import OSLog

// MARK: - Network State Manager
@MainActor
final class NetworkState: ObservableObject {
    static let shared = NetworkState()

    // MARK: - Published Properties
    @Published var networkStatus: NetworkStatus = .connected
    @Published var isOnline = true
    @Published var isOfflineMode = false
    @Published var pendingOperationsCount = 0

    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNetworkMonitoring()
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Network status observer (legacy)
        NotificationCenter.default.publisher(for: .balliNetworkStatusChanged)
            .compactMap { $0.object as? NetworkStatus }
            .receive(on: DispatchQueue.main)
            .assign(to: &$networkStatus)

        // New network reachability observer
        NotificationCenter.default.publisher(for: .networkDidBecomeReachable)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleNetworkReconnection()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .networkDidBecomeUnreachable)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleNetworkDisconnection()
            }
            .store(in: &cancellables)
    }

    private func setupNetworkMonitoring() {
        // Observe network monitor's isConnected property
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOnline = isConnected
                self?.isOfflineMode = !isConnected
            }
            .store(in: &cancellables)
    }

    // MARK: - Network Handling

    private func handleNetworkReconnection() {
        isOnline = true
        isOfflineMode = false

        // Process queued operations
        Task {
            let queue = OfflineQueue.shared
            let queueSize = await queue.getQueueSize()
            if queueSize > 0 {
                await queue.processQueue()
                let remainingSize = await queue.getQueueSize()
                pendingOperationsCount = remainingSize
            }
        }
    }

    private func handleNetworkDisconnection() {
        isOnline = false
        isOfflineMode = true

        // Update pending operations count
        Task {
            let queue = OfflineQueue.shared
            pendingOperationsCount = await queue.getQueueSize()
        }
    }
}

// MARK: - Network Status
enum NetworkStatus {
    case connected
    case disconnected
    case connecting
}

// MARK: - Environment Key
private struct NetworkStateKey: EnvironmentKey {
    static let defaultValue: NetworkState? = nil
}

extension EnvironmentValues {
    var networkState: NetworkState {
        get {
            if let state = self[NetworkStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                NetworkState.shared
            }
        }
        set { self[NetworkStateKey.self] = newValue }
    }
}
