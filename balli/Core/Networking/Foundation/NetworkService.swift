//
//  NetworkService.swift
//  balli
//
//  Unified network service interface
//

import Foundation

/// Unified network service that coordinates network clients
@MainActor
final class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // MARK: - Dependencies

    // External services removed - operating in local mode
    private let logger = NetworkLogger.shared
    
    // MARK: - Published State
    
    @Published var isConnected = false
    @Published var authenticationStatus: AuthenticationStatus = .unauthenticated
    @Published var lastError: NetworkError?
    
    // MARK: - Authentication Status
    
    enum AuthenticationStatus: Sendable {
        case unauthenticated
        case authenticating
        case authenticated
        case tokenExpired
    }
    
    private init() {}
    
    // MARK: - Authentication Management
    
    /// Set authentication token (local mode - no external services)
    func setAuthenticationToken(_ token: String?) async {
        // Operating in local mode - no external authentication required

        Task { @MainActor in
            if token != nil {
                authenticationStatus = .authenticated
            } else {
                authenticationStatus = .unauthenticated
            }
        }
    }
    
    /// Check if service is authenticated
    func isAuthenticated() async -> Bool {
        return false // Local mode - no external authentication
    }
    
    // MARK: - Health API (Local Mode)
    
    /// Check health
    func checkHealth() async throws -> HealthCheckResponse {
        // Service removed
        let error = NetworkError.aiServiceUnavailable
        await handleError(error)
        throw error
    }
    
    /// Get application information
    func getInfo() async throws -> InfoResponse {
        do {
            _ = InfoRequest()
            // External services removed - operating in local mode
            throw NetworkError.aiServiceUnavailable

        } catch let error as NetworkError {
            await handleError(error)
            throw error
        }
    }
    
    /// Send health data (Local Mode - not implemented)
    func sendHealthData<T: Codable & Sendable>(_ data: T, to endpoint: String) async throws -> NetworkResponse<T> {
        do {
            _ = HealthDataRequest(endpoint: endpoint, data: data)
            // External services removed - operating in local mode
            throw NetworkError.aiServiceUnavailable

        } catch let error as NetworkError {
            await logger.logHealthDataAccess(NetworkLogger.HealthDataAccess(
                operation: "write",
                dataType: endpoint,
                endpoint: endpoint,
                success: false,
                userId: await getCurrentUserHash()
            ))
            
            await handleError(error)
            throw error
        }
    }
    
    // MARK: - Flow API removed
    
    /// Get health advice (non-streaming)
    func getHealthAdvice(query: String, context: HealthAdviceRequest.HealthContext? = nil) async throws -> HealthAdviceResponse {
        do {
            _ = HealthAdviceRequest(query: query, context: context)
            throw NetworkError.aiServiceUnavailable
            
        } catch let error as NetworkError {
            await handleError(error)
            throw error
        }
    }
    
    /// Stream health advice with real-time responses
    func streamHealthAdvice(
        query: String,
        context: HealthAdviceRequest.HealthContext? = nil,
        onChunk: @escaping @Sendable (StreamingChunk) -> Void,
        onComplete: @escaping @Sendable (Result<HealthAdviceResponse, NetworkError>) -> Void
    ) async throws {

        _ = HealthAdviceRequest(query: query, context: context)
        _ = onChunk  // Suppress unused parameter warning
        _ = onComplete  // Suppress unused parameter warning

        // Streaming removed
        throw NetworkError.aiServiceUnavailable
    }
    
    /// Cancel all active streams
    func cancelAllStreams() async {
        // Stream cancellation removed
    }
    
    // MARK: - Connection Management
    
    /// Test network connectivity
    func testConnectivity() async -> Bool {
        do {
            _ = try await checkHealth()
            return true
        } catch {
            return false
        }
    }
    
    /// Retry failed operations
    func retryLastOperation() async throws {
        // Implementation would depend on storing the last failed operation
        // For now, we'll just test connectivity
        let isConnected = await testConnectivity()
        
        Task { @MainActor in
            self.isConnected = isConnected
            if isConnected {
                lastError = nil
            }
        }
        
        if !isConnected {
            throw NetworkError.serverUnreachable
        }
    }
    
    // MARK: - Private Helpers
    
    /// Handle network errors and update UI state
    private func handleError(_ error: NetworkError) async {
        Task { @MainActor in
            lastError = error
            
            // Update connection status
            switch error {
            case .connectionFailed, .serverUnreachable, .internetConnectionOffline:
                isConnected = false
            case .authenticationRequired, .authTokenExpired, .authTokenInvalid:
                authenticationStatus = .tokenExpired
            default:
                break
            }
        }
        
        await logger.logError(error, context: "NetworkService")
    }
    
    /// Get current user hash for audit logging
    private func getCurrentUserHash() async -> String? {
        // This would hash the current user ID for HIPAA-compliant logging
        // For development, return a placeholder
        return "user_hash_placeholder"
    }
}

// MARK: - Convenience Extensions

extension NetworkService {
    /// Quick health check with connection status update
    func quickHealthCheck() async {
        do {
            _ = try await checkHealth()
        } catch {
            // Error is already handled in checkHealth()
        }
    }
    
    /// Get connection status description
    var connectionStatusDescription: String {
        if isConnected {
            switch authenticationStatus {
            case .authenticated:
                return "Connected and authenticated"
            case .unauthenticated:
                return "Connected but not authenticated"
            case .authenticating:
                return "Connecting..."
            case .tokenExpired:
                return "Authentication expired"
            }
        } else {
            return "Not connected"
        }
    }
    
    /// Check if ready for health data operations
    var isReadyForHealthData: Bool {
        return isConnected && authenticationStatus == .authenticated
    }
    
    /// Get user-friendly error message
    var lastErrorDescription: String? {
        return lastError?.errorDescription
    }
    
    /// Get recovery suggestion for last error
    var lastErrorRecoverySuggestion: String? {
        return lastError?.recoverySuggestion
    }
}

// MARK: - SwiftUI Helpers

extension NetworkService {
    /// Observable connection status for SwiftUI
    var isHealthy: Bool {
        return isConnected && lastError == nil
    }
    
    /// Color indicator for connection status
    var statusColor: String {
        if isHealthy {
            return "green"
        } else if isConnected {
            return "orange"
        } else {
            return "red"
        }
    }
}