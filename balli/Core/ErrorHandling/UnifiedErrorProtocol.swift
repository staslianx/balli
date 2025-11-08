//
//  UnifiedErrorProtocol.swift
//  balli
//
//  Unified error handling protocol for consistent error management
//

import Foundation
import OSLog

// MARK: - Unified Error Protocol

/// A unified protocol for all application errors
protocol UnifiedError: LocalizedError, Sendable {
    /// The error category for analytics and logging
    var category: ErrorCategory { get }
    
    /// The severity level of the error
    var severity: ErrorSeverity { get }
    
    /// Whether this error is recoverable
    var isRecoverable: Bool { get }
    
    /// Suggested action for the user
    var userAction: String? { get }
    
    /// Technical details for debugging
    var technicalDetails: String? { get }
    
    /// Unique error code for tracking
    var errorCode: String { get }
}

// MARK: - Error Categories

enum ErrorCategory: String, Sendable {
    case network = "network"
    case data = "data"
    case camera = "camera"
    case ai = "ai"
    case validation = "validation"
    case authentication = "auth"
    case system = "system"
    case unknown = "unknown"
}

// MARK: - Error Severity

enum ErrorSeverity: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Default Implementation

extension UnifiedError {
    var isRecoverable: Bool { true }
    var userAction: String? { nil }
    var technicalDetails: String? { nil }
    
    var errorCode: String {
        "\(category.rawValue)_\(String(describing: self))"
    }
}

// MARK: - Error Handler

/// Centralized error handler for the application
@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: (any UnifiedError)?
    @Published var errorHistory: [(any UnifiedError, Date)] = []
    
    private let maxHistorySize = 50
    
    private init() {}
    
    /// Handle an error with appropriate logging and user notification
    func handle(_ error: any Error) {
        // Convert to UnifiedError if needed
        let unifiedError: any UnifiedError
        
        if let unified = error as? any UnifiedError {
            unifiedError = unified
        } else {
            unifiedError = GenericError(underlying: error)
        }
        
        // Store error
        currentError = unifiedError
        errorHistory.append((unifiedError, Date()))
        
        // Trim history
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
        
        // Log based on severity
        logError(unifiedError)
        
        // Handle critical errors
        if unifiedError.severity == .critical {
            handleCriticalError(unifiedError)
        }
    }
    
    private func logError(_ error: any UnifiedError) {
        let logger = AppLoggers.Performance.main
        
        let message = """
        Error: \(error.localizedDescription)
        Category: \(error.category.rawValue)
        Severity: \(error.severity)
        Code: \(error.errorCode)
        Recoverable: \(error.isRecoverable)
        """
        
        switch error.severity {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.notice("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.fault("\(message)")
        }
        
        if let details = error.technicalDetails {
            logger.debug("Technical details: \(details)")
        }
    }
    
    private func handleCriticalError(_ error: any UnifiedError) {
        // In production, send to crash reporting service
        // Log critical error prominently
        let criticalLogger = AppLoggers.Performance.main
        criticalLogger.fault("CRITICAL ERROR: \(error.localizedDescription)")
    }
    
    /// Clear the current error
    func clearError() {
        currentError = nil
    }
    
    /// Get errors by category
    func errors(for category: ErrorCategory) -> [(any UnifiedError, Date)] {
        errorHistory.filter { $0.0.category == category }
    }
    
    /// Get errors by severity
    func errors(with severity: ErrorSeverity) -> [(any UnifiedError, Date)] {
        errorHistory.filter { $0.0.severity == severity }
    }
}

// MARK: - Generic Error Wrapper

/// Wraps non-unified errors into the unified system
struct GenericError: UnifiedError {
    let underlying: Error
    
    var category: ErrorCategory { .unknown }
    var severity: ErrorSeverity { .error }
    var isRecoverable: Bool { true }
    
    var errorDescription: String? {
        underlying.localizedDescription
    }
    
    var errorCode: String {
        "generic_\(type(of: underlying))"
    }
}

// MARK: - Existing Error Conformance

// Mock service error conformance removed - service deleted

extension CameraError: UnifiedError {
    var category: ErrorCategory { .camera }
    
    var severity: ErrorSeverity {
        switch self {
        case .permissionDenied:
            return .critical
        case .deviceNotAvailable:
            return .error
        case .sessionConfigurationFailed:
            return .critical
        default:
            return .error
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .permissionDenied:
            return false
        default:
            return true
        }
    }
    
    var userAction: String? {
        switch self {
        case .permissionDenied:
            return "Ayarlar'a gidip kamera iznini verin"
        case .deviceNotAvailable:
            return "Kamera şu anda kullanılamıyor"
        default:
            return nil
        }
    }
}

extension CoreDataError: UnifiedError {
    var category: ErrorCategory { .data }
    
    var severity: ErrorSeverity {
        switch self {
        case .saveFailed:
            return .critical
        case .migrationRequired:
            return .critical
        case .storeCorrupted:
            return .critical
        case .insufficientStorage:
            return .critical
        case .validationFailed:
            return .error
        case .contextUnavailable:
            return .error
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .saveFailed, .storeCorrupted, .insufficientStorage:
            return false
        case .migrationRequired, .validationFailed, .contextUnavailable:
            return true
        }
    }
}

// MARK: - Error Recovery

protocol ErrorRecoverable {
    /// Attempt to recover from an error
    func attemptRecovery(from error: any UnifiedError) async throws
}

// MARK: - SwiftUI Integration

import SwiftUI

// SwiftUI error handling extension
extension View {
    /// Adds unified error handling to any view
    func withUnifiedErrorHandling() -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UnifiedError"))) { notification in
                if let error = notification.object as? any UnifiedError {
                    Task { @MainActor in
                        ErrorHandler.shared.handle(error)
                    }
                }
            }
    }
}