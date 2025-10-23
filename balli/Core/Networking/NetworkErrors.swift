//
//  NetworkErrors.swift
//  balli
//
//  Comprehensive error handling for network layer
//

import Foundation

// MARK: - Main Network Error

/// Comprehensive error type for network operations
enum NetworkError: LocalizedError, Sendable {
    // Connection Errors
    case connectionFailed(underlying: Error)
    case requestTimeout
    case internetConnectionOffline
    case serverUnreachable
    
    // Authentication Errors
    case authenticationRequired
    case authenticationFailed
    case authTokenExpired
    case authTokenInvalid
    
    // Request Errors
    case invalidRequest(reason: String)
    case invalidURL(url: String)
    case invalidResponseData
    case requestCancelled
    
    // Server Errors
    case serverError(statusCode: Int, message: String?)
    case serverMaintenance
    case serverOverloaded
    case functionNotFound(endpoint: String)
    
    // Rate Limiting
    case rateLimitExceeded(details: RateLimitError)
    case quotaExceeded
    
    // Data Errors
    case decodingError(underlying: Error)
    case encodingError(underlying: Error)
    case dataCorruption
    case encryptionFailed
    case decryptionFailed
    
    // Health Data Specific Errors
    case healthDataValidationFailed(field: String, reason: String)
    case hipaaComplianceViolation(reason: String)
    case sensitiveDataExposure
    
    // AI Specific Errors
    case aiServiceUnavailable
    case streamingInterrupted
    case contextTooLarge
    case unsupportedOperation
    
    // Retry Errors
    case maxRetriesExceeded(lastError: Error)
    case retryNotAllowed
    
    // Generic
    case unknown(underlying: Error)
    
    // MARK: - Error Properties
    
    var errorDescription: String? {
        switch self {
        // Connection Errors
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .requestTimeout:
            return "Request timed out. Please check your internet connection and try again."
        case .internetConnectionOffline:
            return "No internet connection available. Please check your network settings."
        case .serverUnreachable:
            return "Unable to reach the server. Please try again later."
            
        // Authentication Errors
        case .authenticationRequired:
            return "Authentication is required for this operation. Please log in and try again."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials and try again."
        case .authTokenExpired:
            return "Your session has expired. Please log in again."
        case .authTokenInvalid:
            return "Invalid authentication token. Please log in again."
            
        // Request Errors
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponseData:
            return "The server returned invalid data. Please try again."
        case .requestCancelled:
            return "Request was cancelled."
            
        // Server Errors
        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            } else {
                return "Server error (\(statusCode)). Please try again later."
            }
        case .serverMaintenance:
            return "The service is currently under maintenance. Please try again later."
        case .serverOverloaded:
            return "The service is currently experiencing high traffic. Please try again in a few moments."
        case .functionNotFound(let endpoint):
            return "The requested service (\(endpoint)) is not available."
            
        // Rate Limiting
        case .rateLimitExceeded(let details):
            return "Too many requests. Please wait \(details.retryAfter) seconds before trying again."
        case .quotaExceeded:
            return "Service quota exceeded. Please try again later or contact support."
            
        // Data Errors
        case .decodingError(let error):
            return "Failed to process server response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to prepare request: \(error.localizedDescription)"
        case .dataCorruption:
            return "Data integrity check failed. Please try again."
        case .encryptionFailed:
            return "Failed to secure sensitive data. Please try again."
        case .decryptionFailed:
            return "Failed to decrypt data. Please try again or contact support."
            
        // Health Data Specific Errors
        case .healthDataValidationFailed(let field, let reason):
            return "Invalid health data for \(field): \(reason)"
        case .hipaaComplianceViolation(let reason):
            return "Security violation detected: \(reason). Operation cancelled for your privacy."
        case .sensitiveDataExposure:
            return "Potential data exposure detected. Operation cancelled for your security."
            
        // AI Specific Errors
        case .aiServiceUnavailable:
            return "AI service is temporarily unavailable. Please try again later."
        case .streamingInterrupted:
            return "Real-time response was interrupted. Please try again."
        case .contextTooLarge:
            return "Request too large. Please reduce the amount of data and try again."
        case .unsupportedOperation:
            return "This operation is not supported. Please try a different approach."
            
        // Retry Errors
        case .maxRetriesExceeded(let lastError):
            return "Operation failed after multiple attempts: \(lastError.localizedDescription)"
        case .retryNotAllowed:
            return "This operation cannot be retried automatically."
            
        // Generic
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .connectionFailed, .requestTimeout, .internetConnectionOffline, .serverUnreachable:
            return "Network connectivity issue"
        case .authenticationRequired, .authenticationFailed, .authTokenExpired, .authTokenInvalid:
            return "Authentication problem"
        case .serverError, .serverMaintenance, .serverOverloaded, .functionNotFound:
            return "Server-side issue"
        case .rateLimitExceeded, .quotaExceeded:
            return "Rate limiting or quota issue"
        case .healthDataValidationFailed, .hipaaComplianceViolation, .sensitiveDataExposure:
            return "Health data security or validation issue"
        case .aiServiceUnavailable, .streamingInterrupted, .contextTooLarge:
            return "AI service issue"
        default:
            return "Technical issue"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .requestTimeout, .internetConnectionOffline, .serverUnreachable:
            return "Check your internet connection and try again."
        case .authenticationRequired, .authenticationFailed, .authTokenExpired, .authTokenInvalid:
            return "Please log in again to continue."
        case .serverMaintenance, .serverOverloaded:
            return "Wait a few moments and try again."
        case .rateLimitExceeded(let details):
            return "Wait \(details.retryAfter) seconds before trying again."
        case .healthDataValidationFailed:
            return "Please check your health data entry and try again."
        case .contextTooLarge:
            return "Reduce the amount of data in your request and try again."
        case .aiServiceUnavailable, .streamingInterrupted:
            return "Try again in a few moments. If the problem persists, contact support."
        default:
            return "Try again later. If the problem persists, contact support."
        }
    }
    
    // MARK: - Error Classification
    
    /// Check if error is retryable
    var isRetryable: Bool {
        switch self {
        case .connectionFailed, .requestTimeout, .serverUnreachable, .serverOverloaded:
            return true
        case .serverError(let statusCode, _):
            return statusCode >= 500 // Retry server errors (5xx)
        case .rateLimitExceeded:
            return true // Retry after delay
        case .streamingInterrupted:
            return true
        default:
            return false
        }
    }
    
    /// Check if error requires authentication
    var requiresAuthentication: Bool {
        switch self {
        case .authenticationRequired, .authenticationFailed, .authTokenExpired, .authTokenInvalid:
            return true
        case .serverError(let statusCode, _):
            return statusCode == 401 // Unauthorized
        default:
            return false
        }
    }
    
    /// Check if error is security-related
    var isSecurityRelated: Bool {
        switch self {
        case .authenticationRequired, .authenticationFailed, .authTokenExpired, .authTokenInvalid:
            return true
        case .hipaaComplianceViolation, .sensitiveDataExposure:
            return true
        case .encryptionFailed, .decryptionFailed:
            return true
        default:
            return false
        }
    }
    
    /// Get recommended retry delay in seconds
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded(let details):
            return TimeInterval(details.retryAfter)
        case .serverOverloaded:
            return 30.0
        case .connectionFailed, .requestTimeout, .serverUnreachable:
            return 5.0
        default:
            return 1.0
        }
    }
}

// MARK: - Error Creation Helpers

extension NetworkError {
    /// Create error from URLError
    static func from(_ urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .timedOut:
            return .requestTimeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .internetConnectionOffline
        case .cannotFindHost, .cannotConnectToHost:
            return .serverUnreachable
        case .cancelled:
            return .requestCancelled
        default:
            return .connectionFailed(underlying: urlError)
        }
    }
    
    /// Create error from HTTP status code
    static func from(statusCode: Int, data: Data?) -> NetworkError {
        switch statusCode {
        case 400:
            return .invalidRequest(reason: "Bad request")
        case 401:
            return .authenticationRequired
        case 403:
            return .authenticationFailed
        case 404:
            return .functionNotFound(endpoint: "unknown")
        case 429:
            // Try to parse rate limit details
            if let data = data,
               let rateLimitError = try? JSONDecoder().decode(RateLimitError.self, from: data) {
                return .rateLimitExceeded(details: rateLimitError)
            } else {
                return .rateLimitExceeded(details: RateLimitError(limit: 100, remaining: 0, resetTime: "", retryAfter: 60))
            }
        case 500...599:
            let message = extractErrorMessage(from: data)
            return .serverError(statusCode: statusCode, message: message)
        default:
            let message = extractErrorMessage(from: data)
            return .serverError(statusCode: statusCode, message: message)
        }
    }
    
    /// Extract error message from response data
    private static func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        // Try to parse as NetworkErrorResponse
        if let errorResponse = try? JSONDecoder().decode(NetworkErrorResponse.self, from: data) {
            return errorResponse.error.message
        }
        
        // Try to parse as plain JSON with message field
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        
        return nil
    }
}