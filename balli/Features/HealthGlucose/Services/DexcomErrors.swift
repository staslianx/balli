//
//  DexcomErrors.swift
//  balli
//
//  Comprehensive error handling for Dexcom API integration
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Comprehensive error types for Dexcom API interactions
enum DexcomError: LocalizedError, Sendable {

    // MARK: - Authentication Errors

    case authorizationCancelled
    case authorizationFailed(reason: String)
    case tokenRefreshFailed
    case invalidAuthorizationCode
    case missingCredentials
    case tokenExpired

    // MARK: - API Errors

    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(code: String, message: String)
    case rateLimitExceeded
    case serverError(statusCode: Int)

    // MARK: - Data Errors

    case noDataAvailable
    case dataDelayNotMet(hoursRemaining: Int)
    case invalidDateRange
    case timeWindowTooLarge

    // MARK: - Connection Errors

    case notConnected
    case connectionLost
    case invalidConfiguration

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        // Authentication Errors
        case .authorizationCancelled:
            return "Dexcom authorization was cancelled."

        case .authorizationFailed(let reason):
            return "Dexcom authorization failed: \(reason)"

        case .tokenRefreshFailed:
            return "Failed to refresh Dexcom access token. Please reconnect your Dexcom account."

        case .invalidAuthorizationCode:
            return "Invalid authorization code received from Dexcom."

        case .missingCredentials:
            return "Dexcom API credentials are missing. Please contact support."

        case .tokenExpired:
            return "Your Dexcom session has expired. Please reconnect."

        // API Errors
        case .networkError(let error):
            // Map to user-friendly network messages
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network and try again."
                case .timedOut:
                    return "Connection timed out. Please check your network and try again."
                case .cannotFindHost, .cannotConnectToHost:
                    return "Cannot reach Dexcom servers. Please check your internet connection."
                case .networkConnectionLost:
                    return "Network connection lost. Please try again."
                default:
                    return "Network error. Please check your internet connection and try again."
                }
            }
            return "Network error. Please check your internet connection and try again."

        case .invalidResponse:
            return "Received invalid response from Dexcom. Please try again or contact support."

        case .decodingError:
            return "Unable to process glucose data from Dexcom. Please try again or contact support."

        case .apiError(let code, let message):
            return "Dexcom API error (\(code)): \(message)"

        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."

        case .serverError(let statusCode):
            return "Dexcom server error (HTTP \(statusCode)). Please try again later."

        // Data Errors
        case .noDataAvailable:
            return "No glucose data available from Dexcom."

        case .dataDelayNotMet(let hoursRemaining):
            return "Dexcom data is delayed by \(hoursRemaining) hours in the EU region."

        case .invalidDateRange:
            return "Invalid date range specified."

        case .timeWindowTooLarge:
            return "Time window too large. Maximum is 30 days."

        // Connection Errors
        case .notConnected:
            return "Not connected to Dexcom. Please connect your account first."

        case .connectionLost:
            return "Connection to Dexcom was lost. Please reconnect."

        case .invalidConfiguration:
            return "Invalid Dexcom configuration. Please check your settings."
        }
    }

    var failureReason: String? {
        switch self {
        case .authorizationCancelled:
            return "User cancelled the authorization process."

        case .tokenRefreshFailed:
            return "The refresh token may have been revoked or expired."

        case .rateLimitExceeded:
            return "Too many API requests in a short period."

        case .dataDelayNotMet:
            return "EU region has a 3-hour data delay."

        case .networkError:
            return "Network connectivity issue."

        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authorizationCancelled, .authorizationFailed:
            return "Try connecting to Dexcom again."

        case .tokenRefreshFailed, .tokenExpired:
            return "Disconnect and reconnect your Dexcom account."

        case .missingCredentials:
            return "Contact app support to configure Dexcom credentials."

        case .networkError:
            return "Check your internet connection and try again."

        case .rateLimitExceeded:
            return "Wait a few minutes before making more requests."

        case .serverError:
            return "Dexcom servers may be experiencing issues. Try again later."

        case .noDataAvailable:
            return "Ensure your Dexcom device is connected and transmitting data."

        case .dataDelayNotMet:
            return "Data will be available after the 3-hour EU delay period."

        case .timeWindowTooLarge:
            return "Request data in smaller time windows (maximum 30 days)."

        case .notConnected, .connectionLost:
            return "Go to Settings to connect your Dexcom account."

        default:
            return "Try again or contact support if the problem persists."
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension DexcomError {
    /// Create appropriate error from HTTP response
    static func from(httpStatusCode: Int, data: Data?) -> DexcomError {
        // Try to decode error response from Dexcom
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(DexcomErrorResponse.self, from: data) {
            return .apiError(code: errorResponse.code ?? "\(httpStatusCode)", message: errorResponse.message)
        }

        // Map common HTTP status codes
        switch httpStatusCode {
        case 401:
            return .tokenExpired
        case 403:
            return .authorizationFailed(reason: "Access forbidden")
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode: httpStatusCode)
        default:
            return .serverError(statusCode: httpStatusCode)
        }
    }
}

// MARK: - User-Friendly Error Messages

extension DexcomError {
    /// Get a concise, user-friendly error title
    var title: String {
        switch self {
        case .authorizationCancelled, .authorizationFailed, .tokenExpired:
            return "Connection Failed"
        case .tokenRefreshFailed:
            return "Session Expired"
        case .networkError:
            return "Network Error"
        case .rateLimitExceeded:
            return "Too Many Requests"
        case .noDataAvailable:
            return "No Data"
        case .dataDelayNotMet:
            return "Data Delayed"
        case .notConnected, .connectionLost:
            return "Not Connected"
        default:
            return "Error"
        }
    }

    /// Check if error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .invalidResponse:
            return true
        case .rateLimitExceeded:
            return true // After waiting
        default:
            return false
        }
    }

    /// Check if error requires re-authentication
    var requiresReauth: Bool {
        switch self {
        case .tokenExpired, .tokenRefreshFailed, .authorizationFailed:
            return true
        case .apiError(let code, _):
            return code == "401" || code == "403"
        default:
            return false
        }
    }

    /// Suggested delay before retry (for retryable errors)
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded:
            return 60 // 1 minute
        case .serverError:
            return 30 // 30 seconds
        case .networkError:
            return 5 // 5 seconds
        default:
            return 0
        }
    }
}

// MARK: - Logging Helpers

extension DexcomError {
    /// Get detailed error information for logging
    var logMessage: String {
        var message = "DexcomError: \(title)"

        if let description = errorDescription {
            message += " - \(description)"
        }

        if let reason = failureReason {
            message += " (Reason: \(reason))"
        }

        // Include underlying error details for debugging
        switch self {
        case .networkError(let error):
            message += " | Underlying: \(error)"
        case .decodingError(let error):
            message += " | Decoding: \(error)"
        case .apiError(let code, let apiMessage):
            message += " | API Code: \(code), Message: \(apiMessage)"
        default:
            break
        }

        return message
    }
}

// MARK: - Analytics Event Names

extension DexcomError {
    /// Get analytics event name for this error type
    var analyticsEventName: String {
        switch self {
        case .authorizationCancelled:
            return "dexcom_auth_cancelled"
        case .authorizationFailed:
            return "dexcom_auth_failed"
        case .tokenRefreshFailed:
            return "dexcom_token_refresh_failed"
        case .tokenExpired:
            return "dexcom_token_expired"
        case .networkError:
            return "dexcom_network_error"
        case .apiError:
            return "dexcom_api_error"
        case .rateLimitExceeded:
            return "dexcom_rate_limit"
        case .noDataAvailable:
            return "dexcom_no_data"
        default:
            return "dexcom_error"
        }
    }
}

// MARK: - Error Result Type

/// Result type for Dexcom operations
typealias DexcomResult<T> = Result<T, DexcomError>