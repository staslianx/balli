/**
 * TLS Certificate Pinning for iOS
 * 
 * This module provides:
 * - TLS 1.3 enforcement for URLSession
 * - Certificate pinning validation
 * - Secure network configuration
 * - Swift 6 concurrency compliance
 */

import Foundation
import Network
import os
import CryptoKit

// MARK: - Certificate Pinning Configuration

public struct TLSPinningConfig {
    // Domains that require certificate pinning
    static let pinnedDomains = [
        "api.example.com",
        "storage.example.com",
        "auth.example.com"
    ]
    
    // Certificate pins (SHA256 hashes of public keys)
    // These would be actual certificate pins in production
    static let certificatePins = [
        "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]
    
    // TLS configuration
    static let minimumTLSVersion: tls_protocol_version_t = .TLSv13
    static let maximumTLSVersion: tls_protocol_version_t = .TLSv13
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 300
}

// MARK: - TLS Security Manager

@MainActor
public final class TLSSecurityManager: NSObject, ObservableObject, Sendable {
    
    private let logger = os.Logger(subsystem: "com.balli.health", category: "tls-security")
    
    // Singleton instance
    public static let shared = TLSSecurityManager()
    
    private override init() {
        super.init()
        logger.info("TLS Security Manager initialized")
    }
    
    // MARK: - URLSession Configuration
    
    /**
     * Create a secure URLSession with TLS 1.3 and certificate pinning
     */
    public func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // Set timeouts
        configuration.timeoutIntervalForRequest = TLSPinningConfig.requestTimeout
        configuration.timeoutIntervalForResource = TLSPinningConfig.resourceTimeout
        
        // Security headers
        configuration.httpAdditionalHeaders = [
            "User-Agent": "BalliHealthApp/1.0",
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        
        // Disable caching for sensitive requests
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        
        // TLS configuration
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // Create session with custom delegate for certificate pinning
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        
        logger.info("Secure URLSession created with TLS 1.3 and certificate pinning")
        return session
    }
    
    // MARK: - Certificate Validation
    
    /**
     * Validate certificate pin against expected pins
     */
    nonisolated private func validateCertificatePin(certificate: SecCertificate) -> Bool {
        // Get the public key from the certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Failed to extract public key from certificate")
            return false
        }
        
        // Get the public key data
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Failed to get public key data")
            return false
        }
        
        // Calculate SHA256 hash of the public key
        let keyData = publicKeyData as Data
        let hash = SHA256.hash(data: keyData)
        let hashData = Data(hash)
        
        let pin = "sha256-" + hashData.base64EncodedString()
        
        // Check against expected pins
        let isValid = TLSPinningConfig.certificatePins.contains(pin)
        
        if isValid {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").debug("Certificate pin validated successfully")
        } else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Certificate pin validation failed - receivedPin: \(String(pin.prefix(20)))...")
        }
        
        return isValid
    }
    
    /**
     * Check if domain requires certificate pinning
     */
    nonisolated private func shouldPinCertificateForHost(_ host: String) -> Bool {
        return TLSPinningConfig.pinnedDomains.contains { pinnedDomain in
            host == pinnedDomain || host.hasSuffix("." + pinnedDomain)
        }
    }
    
    // MARK: - Network Monitoring
    
    /**
     * Create network path monitor for connection quality
     */
    public func createNetworkMonitor() -> NWPathMonitor {
        let monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        return monitor
    }
    
    @MainActor
    private func handleNetworkPathUpdate(_ path: NWPath) {
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wifi) {
                logger.info("Network: WiFi connection available")
            } else if path.usesInterfaceType(.cellular) {
                logger.info("Network: Cellular connection available")
            }
        case .unsatisfied:
            logger.warning("Network: Connection unavailable")
        case .requiresConnection:
            logger.info("Network: Connection requires user action")
        @unknown default:
            logger.warning("Network: Unknown connection status")
        }
    }
    
    // MARK: - Security Configuration
    
    /**
     * Get current TLS security configuration
     */
    public func getSecurityConfiguration() -> [String: Any] {
        return [
            "tlsMinVersion": "TLS 1.3",
            "tlsMaxVersion": "TLS 1.3",
            "pinnedDomains": TLSPinningConfig.pinnedDomains,
            "certificatePinsCount": TLSPinningConfig.certificatePins.count,
            "requestTimeout": TLSPinningConfig.requestTimeout,
            "resourceTimeout": TLSPinningConfig.resourceTimeout,
            "cachePolicy": "no-cache"
        ]
    }
}

// MARK: - URLSessionDelegate

extension TLSSecurityManager: URLSessionDelegate {
    
    nonisolated public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("No server trust found in authentication challenge")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Check if this host requires certificate pinning
        guard shouldPinCertificateForHost(host) else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").debug("Host \(host) does not require certificate pinning, using default handling")
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Validate the certificate chain using modern API
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            if let error = error {
                os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Certificate trust evaluation failed: \(error)")
            } else {
                os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Certificate trust evaluation failed with unknown error")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate certificate pinning using modern API
        var certificateValid = false

        if let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
            for certificate in certificateChain {
                if validateCertificatePin(certificate: certificate) {
                    certificateValid = true
                    break
                }
            }
        } else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Failed to get certificate chain")
        }
        
        if certificateValid {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").info("Certificate pinning validation successful for host: \(host)")
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("Certificate pinning validation failed for host: \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").error("URLSession became invalid with error: \(error.localizedDescription)")
        } else {
            os.Logger(subsystem: "com.balli.health", category: "tls-security").info("URLSession became invalid")
        }
    }
}

// MARK: - Secure Network Client

/**
 * Secure HTTP client with encryption and certificate pinning
 */
@MainActor
public final class SecureNetworkClient: ObservableObject, Sendable {
    
    private let session: URLSession
    private let encryption: HealthDataEncryption
    private let logger = os.Logger(subsystem: "com.balli.health", category: "network-client")
    
    public init() {
        self.session = TLSSecurityManager.shared.createSecureURLSession()
        self.encryption = HealthDataEncryption.shared
        logger.info("Secure network client initialized")
    }
    
    /**
     * Send encrypted health data to server
     */
    public func sendEncryptedHealthData(
        _ record: EncryptedHealthRecord,
        to endpoint: URL
    ) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        
        // Encode the encrypted record
        let jsonData = try JSONEncoder().encode(record)
        request.httpBody = jsonData
        
        logger.info("Sending encrypted health data to \(endpoint.host ?? "unknown")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                logger.error("Server returned error status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            logger.info("Successfully sent encrypted health data")
            return data
            
        } catch {
            logger.error("Failed to send encrypted health data: \(error.localizedDescription)")
            throw error
        }
    }
    
    /**
     * Fetch and decrypt health data from server
     */
    public func fetchEncryptedHealthData(from endpoint: URL) async throws -> [EncryptedHealthRecord] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        
        logger.info("Fetching encrypted health data from \(endpoint.host ?? "unknown")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                logger.error("Server returned error status: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let records = try JSONDecoder().decode([EncryptedHealthRecord].self, from: data)
            logger.info("Successfully fetched \(records.count) encrypted health records")
            
            return records
            
        } catch {
            logger.error("Failed to fetch encrypted health data: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

// Helper for SHA256 calculation
private extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}