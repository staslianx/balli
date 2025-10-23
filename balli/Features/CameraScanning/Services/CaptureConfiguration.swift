//
//  CaptureConfiguration.swift
//  balli
//
//  Configuration settings for capture flow
//

import Foundation
import UIKit

// MARK: - Capture Configuration

public struct CaptureConfiguration: CaptureConfiguring, Sendable {
    // Retry settings
    public let maxRetryCount: Int
    
    // Session settings
    public let sessionExpirationInterval: TimeInterval
    
    // Image compression settings
    public let compressionQuality: CGFloat
    public let thumbnailCompressionQuality: CGFloat
    public let optimizedImageCompressionQuality: CGFloat
    
    // History settings
    public let maxHistoryCount: Int
    
    // Processing timeouts
    public let captureTimeout: TimeInterval
    public let processingTimeout: TimeInterval
    public let aiProcessingTimeout: TimeInterval
    
    // Image size limits
    public let maxImageDimension: CGFloat
    public let thumbnailSize: CGSize
    
    // Default configuration
    public static let `default` = CaptureConfiguration(
        maxRetryCount: 3,
        sessionExpirationInterval: 86400, // 24 hours
        compressionQuality: 0.9,
        thumbnailCompressionQuality: 0.7,
        optimizedImageCompressionQuality: 0.8,
        maxHistoryCount: 10,
        captureTimeout: 10.0,
        processingTimeout: 30.0,
        aiProcessingTimeout: 60.0,
        maxImageDimension: 2048,
        thumbnailSize: CGSize(width: 200, height: 200)
    )
    
    public init(
        maxRetryCount: Int = 3,
        sessionExpirationInterval: TimeInterval = 86400,
        compressionQuality: CGFloat = 0.9,
        thumbnailCompressionQuality: CGFloat = 0.7,
        optimizedImageCompressionQuality: CGFloat = 0.8,
        maxHistoryCount: Int = 10,
        captureTimeout: TimeInterval = 10.0,
        processingTimeout: TimeInterval = 30.0,
        aiProcessingTimeout: TimeInterval = 60.0,
        maxImageDimension: CGFloat = 2048,
        thumbnailSize: CGSize = CGSize(width: 200, height: 200)
    ) {
        self.maxRetryCount = maxRetryCount
        self.sessionExpirationInterval = sessionExpirationInterval
        self.compressionQuality = compressionQuality
        self.thumbnailCompressionQuality = thumbnailCompressionQuality
        self.optimizedImageCompressionQuality = optimizedImageCompressionQuality
        self.maxHistoryCount = maxHistoryCount
        self.captureTimeout = captureTimeout
        self.processingTimeout = processingTimeout
        self.aiProcessingTimeout = aiProcessingTimeout
        self.maxImageDimension = maxImageDimension
        self.thumbnailSize = thumbnailSize
    }
    
    public func validate() -> Bool {
        return maxRetryCount > 0 &&
               sessionExpirationInterval > 0 &&
               compressionQuality > 0 && compressionQuality <= 1 &&
               thumbnailCompressionQuality > 0 && thumbnailCompressionQuality <= 1 &&
               optimizedImageCompressionQuality > 0 && optimizedImageCompressionQuality <= 1 &&
               maxHistoryCount > 0 &&
               captureTimeout > 0 &&
               processingTimeout > 0 &&
               aiProcessingTimeout > 0 &&
               maxImageDimension > 0 &&
               thumbnailSize.width > 0 && thumbnailSize.height > 0
    }
}

// MARK: - Capture Queue Configuration

public struct CaptureQueueConfiguration: Sendable {
    public let sessionQueueLabel: String
    public let sessionQueueQoS: DispatchQoS
    public let persistenceQueueLabel: String
    public let persistenceQueueQoS: DispatchQoS
    
    public static let `default` = CaptureQueueConfiguration(
        sessionQueueLabel: "com.balli.capture.session",
        sessionQueueQoS: .userInitiated,
        persistenceQueueLabel: "com.balli.capture.persistence",
        persistenceQueueQoS: .utility
    )
}

// MARK: - Notification Configuration

public struct CaptureNotificationConfiguration: Sendable {
    public let backgroundNotificationName: Notification.Name
    public let foregroundNotificationName: Notification.Name
    
    public static let `default` = CaptureNotificationConfiguration(
        backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
        foregroundNotificationName: UIApplication.willEnterForegroundNotification
    )
}