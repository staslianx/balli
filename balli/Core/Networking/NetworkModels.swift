//
//  NetworkModels.swift
//  balli
//
//  Network layer models for network integration
//

import Foundation

// MARK: - Base Network Models

/// Base request protocol for network functions
protocol NetworkRequest: Codable, Sendable {
    associatedtype ResponseType: Codable & Sendable
    
    var endpoint: String { get }
    var method: HTTPMethod { get }
    var requiresAuthentication: Bool { get }
    var timeoutInterval: TimeInterval { get }
}

/// HTTP Methods supported by the network layer
enum HTTPMethod: String, CaseIterable, Sendable, Codable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

/// Base response wrapper for network functions
struct NetworkResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T?
    let success: Bool
    let message: String?
    let timestamp: String
    let requestId: String?
    
    init(data: T?, success: Bool = true, message: String? = nil, timestamp: String = ISO8601DateFormatter().string(from: Date()), requestId: String? = nil) {
        self.data = data
        self.success = success
        self.message = message
        self.timestamp = timestamp
        self.requestId = requestId
    }
}

// MARK: - Network Functions Models

/// Health check request
struct HealthCheckRequest: NetworkRequest {
    typealias ResponseType = HealthCheckResponse
    
    let endpoint = "healthCheck"
    let method = HTTPMethod.GET
    let requiresAuthentication = false
    let timeoutInterval: TimeInterval = 10.0
    
    // Explicit Decodable conformance for request with no stored properties
    init() {}
    
    init(from decoder: Decoder) throws {
        // No properties to decode
    }
    
    func encode(to encoder: Encoder) throws {
        // No properties to encode
    }
}

/// Health check response
struct HealthCheckResponse: Codable, Sendable {
    let status: String
    let timestamp: String
    let message: String
    let environment: String
    let nodeVersion: String
    let cloudRun: CloudRunStatus
    let deployment: DeploymentStatus
    let logging: LoggingStatus
    
    struct CloudRunStatus: Codable, Sendable {
        let ready: Bool
        let container: String
        let port: String
    }
    
    struct DeploymentStatus: Codable, Sendable {
        let version: String
        let test: Bool
        let optimized: Bool
    }
    
    struct LoggingStatus: Codable, Sendable {
        let cloud_logger: Bool
        let environment_validated: Bool
        let structured_logging: Bool

        enum CodingKeys: String, CodingKey {
            case cloud_logger
            case environment_validated
            case structured_logging
        }
    }
}

/// Application info request
struct InfoRequest: NetworkRequest {
    typealias ResponseType = InfoResponse
    
    let endpoint = "info"
    let method = HTTPMethod.GET
    let requiresAuthentication = false
    let timeoutInterval: TimeInterval = 15.0
    
    // Explicit Decodable conformance for request with no stored properties
    init() {}
    
    init(from decoder: Decoder) throws {
        // No properties to decode
    }
    
    func encode(to encoder: Encoder) throws {
        // No properties to encode
    }
}

/// Application info response
struct InfoResponse: Codable, Sendable {
    let name: String
    let version: String
    let description: String
    let environment: String
    let architecture: ArchitectureInfo
    let features: [String]
    let deployment: DeploymentInfo
    let status: StatusInfo
    let timestamp: String
    
    struct ArchitectureInfo: Codable, Sendable {
        let platform: String
        let runtime: String
        let nodeVersion: String
        let memoryAllocated: String
        let region: String
    }
    
    struct DeploymentInfo: Codable, Sendable {
        let deployed: Bool
        let cloudRun: Bool
        let scalable: Bool
        let monitoring: Bool
        let quotaCompliant: Bool
    }
    
    struct StatusInfo: Codable, Sendable {
        let container: String
        let ready: Bool
        let optimized: Bool
    }
}

// MARK: - Flow Models removed

/// Health advice flow request
struct HealthAdviceRequest: Codable, Sendable {
    typealias ResponseType = HealthAdviceResponse

    let query: String
    let context: HealthContext?

    // Non-decoded constants
    var flowName: String { "healthAdvice" }
    var requiresAuthentication: Bool { true }
    var supportsStreaming: Bool { true }

    struct HealthContext: Codable, Sendable {
        let bloodSugar: Double?
        let medications: [String]?
        let symptoms: [String]?
    }
}

/// Health advice flow response
struct HealthAdviceResponse: Codable, Sendable {
    let advice: String
    let confidence: Double
    let timestamp: String
    let disclaimer: String
}

// MARK: - Streaming Models

/// Server-Sent Event data
struct SSEEvent: Sendable {
    let id: String?
    let event: String?
    let data: String
    let retry: Int?
    
    init(data: String, id: String? = nil, event: String? = nil, retry: Int? = nil) {
        self.data = data
        self.id = id
        self.event = event
        self.retry = retry
    }
}

/// Streaming response chunk for AI responses
public struct StreamingChunk: Codable, Sendable {
    public let content: String
    public let isComplete: Bool
    public let tokenCount: Int?
    public let timestamp: String

    public init(content: String, isComplete: Bool = false, tokenCount: Int? = nil) {
        self.content = content
        self.isComplete = isComplete
        self.tokenCount = tokenCount
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Health Data Models

/// Health data request wrapper with encryption support
struct HealthDataRequest<T: Codable & Sendable>: NetworkRequest {
    typealias ResponseType = NetworkResponse<T>
    
    let endpoint: String
    let method: HTTPMethod
    let requiresAuthentication = true
    let timeoutInterval: TimeInterval = 30.0
    
    let data: T
    let encryptSensitiveFields: Bool
    
    init(endpoint: String, method: HTTPMethod = .POST, data: T, encryptSensitiveFields: Bool = true) {
        self.endpoint = endpoint
        self.method = method
        self.data = data
        self.encryptSensitiveFields = encryptSensitiveFields
    }
    
    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case endpoint, method, data, encryptSensitiveFields
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        method = try container.decode(HTTPMethod.self, forKey: .method)
        data = try container.decode(T.self, forKey: .data)
        encryptSensitiveFields = try container.decode(Bool.self, forKey: .encryptSensitiveFields)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(endpoint, forKey: .endpoint)
        try container.encode(method, forKey: .method)
        try container.encode(data, forKey: .data)
        try container.encode(encryptSensitiveFields, forKey: .encryptSensitiveFields)
    }
}

// MARK: - Error Response Models

/// Standard error response from network functions
struct NetworkErrorResponse: Codable, Sendable {
    let error: ErrorDetails
    let timestamp: String
    let requestId: String?
    
    struct ErrorDetails: Codable, Sendable {
        let code: String
        let message: String
        let details: [String: String]?
    }
}

/// Rate limit error details
struct RateLimitError: Codable, Sendable {
    let limit: Int
    let remaining: Int
    let resetTime: String
    let retryAfter: Int
}