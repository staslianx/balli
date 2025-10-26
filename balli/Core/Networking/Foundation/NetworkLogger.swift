//
//  NetworkLogger.swift
//  balli
//
//  HIPAA-compliant logging for network operations
//

import Foundation
import os.log

/// HIPAA-compliant network logger that sanitizes health data
actor NetworkLogger {
    static let shared = NetworkLogger()
    
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "Network")
    private let config = NetworkConfiguration.shared
    
    // MARK: - Logging Categories
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }
    
    private init() {}
    
    // MARK: - Request Logging
    
    /// Log outgoing network request (sanitized for HIPAA compliance)
    func logRequest<T: NetworkRequest>(_ request: T, url: URL, headers: [String: String]?) {
        guard config.enableLogging else { return }
        
        let sanitizedHeaders = sanitizeHeaders(headers)
        let requestInfo = RequestLogInfo(
            endpoint: request.endpoint,
            method: request.method.rawValue,
            url: url.absoluteString,
            headers: sanitizedHeaders,
            requiresAuth: request.requiresAuthentication,
            timestamp: Date()
        )
        
        logger.info("📤 Outgoing Request: \(requestInfo.summary)")
        logger.debug("Request Details: \(requestInfo.details)")
    }
    
    /// Log incoming network response (sanitized)
    func logResponse(for endpoint: String, statusCode: Int, data: Data?, responseTime: TimeInterval) {
        guard config.enableLogging else { return }
        
        let sanitizedData = sanitizeResponseData(data, for: endpoint)
        let responseInfo = ResponseLogInfo(
            endpoint: endpoint,
            statusCode: statusCode,
            dataSize: data?.count ?? 0,
            responseTime: responseTime,
            sanitizedData: sanitizedData,
            timestamp: Date()
        )
        
        let logLevel = getLogLevel(for: statusCode)
        switch logLevel {
        case .debug:
            logger.debug("📥 Response: \(responseInfo.summary)")
        case .info:
            logger.info("📥 Response: \(responseInfo.summary)")
        case .warning:
            logger.warning("📥 Response: \(responseInfo.summary)")
        case .error:
            logger.error("📥 Response: \(responseInfo.summary)")
        case .critical:
            logger.critical("📥 Response: \(responseInfo.summary)")
        }
        
        logger.debug("Response Details: \(responseInfo.details)")
    }
    
    // MARK: - Error Logging
    
    /// Log network error with context
    func logError(_ error: NetworkError, context: String? = nil) {
        let errorInfo = ErrorLogInfo(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        if error.isSecurityRelated {
            logger.critical("🔒 Security Error: \(errorInfo.summary)")
        } else if error.isRetryable {
            logger.warning("🔄 Retryable Error: \(errorInfo.summary)")
        } else {
            logger.error("❌ Network Error: \(errorInfo.summary)")
        }
        
        logger.debug("Error Details: \(errorInfo.details)")
    }
    
    // MARK: - Streaming Logging
    
    /// Log streaming operation start
    func logStreamingStart(flowName: String, endpoint: String) {
        guard config.enableLogging else { return }
        
        logger.info("🌊 Starting stream: \(flowName) -> \(endpoint)")
    }
    
    /// Log streaming chunk (sanitized)
    func logStreamingChunk(flowName: String, chunkSize: Int, isComplete: Bool) {
        guard config.enableLogging else { return }
        
        let status = isComplete ? "✅" : "🔄"
        logger.debug("\(status) Stream chunk: \(flowName) (\(chunkSize) chars)")
    }
    
    /// Log streaming completion or error
    func logStreamingEnd(flowName: String, success: Bool, totalChunks: Int?, error: Error?) {
        guard config.enableLogging else { return }
        
        if success {
            let chunks = totalChunks.map { "\($0) chunks" } ?? "unknown chunks"
            logger.info("✅ Stream completed: \(flowName) (\(chunks))")
        } else if let error = error {
            logger.error("❌ Stream failed: \(flowName) - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Retry Logging
    
    /// Log retry attempt
    func logRetryAttempt(attempt: Int, maxAttempts: Int, delay: TimeInterval, error: Error) {
        guard config.enableLogging else { return }
        
        logger.info("🔄 Retry attempt \(attempt)/\(maxAttempts) after \(delay)s delay: \(error.localizedDescription)")
    }
    
    // MARK: - Authentication Logging
    
    /// Log authentication events (sanitized)
    func logAuthenticationEvent(_ event: AuthEvent) {
        guard config.enableLogging else { return }
        
        switch event {
        case .tokenRefreshed:
            logger.info("🔑 Auth token refreshed")
        case .tokenExpired:
            logger.warning("⏰ Auth token expired")
        case .authenticationFailed:
            logger.error("🔒 Authentication failed")
        case .authenticationRequired:
            logger.info("🔐 Authentication required")
        }
    }
    
    enum AuthEvent: String {
        case tokenRefreshed = "token_refreshed"
        case tokenExpired = "token_expired"
        case authenticationFailed = "authentication_failed"
        case authenticationRequired = "authentication_required"
    }
    
    // MARK: - Health Data Audit Logging
    
    /// Log health data access (for HIPAA compliance)
    func logHealthDataAccess(_ access: HealthDataAccess) {
        // Always log health data access regardless of debug settings (HIPAA requirement)
        let auditInfo = HealthDataAuditInfo(
            access: access,
            timestamp: Date()
        )
        
        logger.info("  Health Data Access: \(auditInfo.summary)")
    }
    
    struct HealthDataAccess: Sendable {
        let operation: String // "read", "write", "update", "delete"
        let dataType: String // "glucose", "medication", "symptoms", etc.
        let endpoint: String
        let success: Bool
        let userId: String? // Hashed user ID for audit trail
    }
    
    // MARK: - Private Sanitization Methods
    
    /// Sanitize HTTP headers by removing sensitive information
    private func sanitizeHeaders(_ headers: [String: String]?) -> [String: String] {
        guard let headers = headers else { return [:] }
        
        var sanitized = headers
        
        // Remove or mask sensitive headers
        let sensitiveHeaders = ["authorization", "x-api-key", "cookie", "x-auth-token"]
        for header in sensitiveHeaders {
            if sanitized[header] != nil {
                sanitized[header] = "***MASKED***"
            }
            if sanitized[header.capitalized] != nil {
                sanitized[header.capitalized] = "***MASKED***"
            }
        }
        
        return sanitized
    }
    
    /// Sanitize response data by removing health information
    private func sanitizeResponseData(_ data: Data?, for endpoint: String) -> String {
        guard let data = data,
              config.enableLogging else { return "***DISABLED***" }
        
        // For health-related endpoints, don't log the actual data
        let healthEndpoints = ["healthAdvice", "healthData", "glucose", "medication"]
        if healthEndpoints.contains(where: { endpoint.contains($0) }) {
            return "***HEALTH_DATA_SANITIZED*** (\(data.count) bytes)"
        }
        
        // Try to parse and sanitize JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let sanitizedJson = sanitizeJsonObject(json)
            if let sanitizedData = try? JSONSerialization.data(withJSONObject: sanitizedJson),
               let sanitizedString = String(data: sanitizedData, encoding: .utf8) {
                return sanitizedString
            }
        }
        
        // Fallback: just show data size
        return "***DATA_SANITIZED*** (\(data.count) bytes)"
    }
    
    /// Recursively sanitize JSON object
    private func sanitizeJsonObject(_ json: [String: Any]) -> [String: Any] {
        var sanitized = json
        
        // Sanitize sensitive fields
        for field in config.sensitiveLogFields {
            if sanitized[field] != nil {
                sanitized[field] = "***SANITIZED***"
            }
        }
        
        // Recursively sanitize nested objects
        for (key, value) in sanitized {
            if let nestedDict = value as? [String: Any] {
                sanitized[key] = sanitizeJsonObject(nestedDict)
            } else if let nestedArray = value as? [[String: Any]] {
                sanitized[key] = nestedArray.map { sanitizeJsonObject($0) }
            }
        }
        
        return sanitized
    }
    
    /// Get appropriate log level for HTTP status code
    private func getLogLevel(for statusCode: Int) -> LogLevel {
        switch statusCode {
        case 200...299:
            return .debug
        case 300...399:
            return .info
        case 400...499:
            return .warning
        case 500...599:
            return .error
        default:
            return .critical
        }
    }
}

// MARK: - Logging Info Structures

private struct RequestLogInfo {
    let endpoint: String
    let method: String
    let url: String
    let headers: [String: String]
    let requiresAuth: Bool
    let timestamp: Date
    
    var summary: String {
        "\(method) \(endpoint) (auth: \(requiresAuth))"
    }
    
    var details: String {
        "URL: \(url), Headers: \(headers.count) headers"
    }
}

private struct ResponseLogInfo {
    let endpoint: String
    let statusCode: Int
    let dataSize: Int
    let responseTime: TimeInterval
    let sanitizedData: String
    let timestamp: Date
    
    var summary: String {
        "\(endpoint) -> \(statusCode) (\(dataSize) bytes, \(String(format: "%.2f", responseTime))s)"
    }
    
    var details: String {
        "Status: \(statusCode), Size: \(dataSize) bytes, Time: \(responseTime)s"
    }
}

private struct ErrorLogInfo {
    let error: NetworkError
    let context: String?
    let timestamp: Date
    
    var summary: String {
        if let context = context {
            return "\(context): \(error.localizedDescription)"
        } else {
            return error.localizedDescription
        }
    }
    
    var details: String {
        "Error: \(error), Retryable: \(error.isRetryable), Security: \(error.isSecurityRelated)"
    }
}

private struct HealthDataAuditInfo {
    let access: NetworkLogger.HealthDataAccess
    let timestamp: Date
    
    var summary: String {
        let userId = access.userId ?? "anonymous"
        let status = access.success ? "SUCCESS" : "FAILED"
        return "[\(status)] \(access.operation.uppercased()) \(access.dataType) via \(access.endpoint) (user: \(userId))"
    }
}