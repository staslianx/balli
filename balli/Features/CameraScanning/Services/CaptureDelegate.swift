//
//  CaptureDelegate.swift
//  balli
//
//  Modern Swift concurrency-based event broadcasting for capture flow
//  Replaces legacy NSHashTable multicast delegation with AsyncStream
//  Swift 6 strict concurrency compliant
//

import Foundation
import UIKit
import os.log

// MARK: - Capture Delegate Handler

/// Modern event broadcaster for capture flow events using Swift concurrency
///
/// Replaces the legacy multicast delegate pattern with AsyncStream-based
/// event broadcasting. Maintains backward compatibility with the delegate protocol
/// while providing a more modern, type-safe event streaming API.
@MainActor
public final class CaptureDelegateHandler: ObservableObject {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureDelegateHandler")

    // MARK: - Delegates (Backward Compatibility)

    /// Legacy delegate for backward compatibility
    /// Consider migrating to event stream API for new code
    public weak var delegate: CaptureDelegate?

    // MARK: - Modern Event Streaming

    /// Continuation for broadcasting events to multiple subscribers
    private var eventContinuation: AsyncStream<CaptureEventType>.Continuation?

    /// Stream of capture events for modern Swift concurrency consumers
    public private(set) lazy var eventStream: AsyncStream<CaptureEventType> = {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }()

    // MARK: - Event Tracking

    private var eventHistory: [CaptureEvent] = []
    private let maxEventHistory = 100

    // MARK: - Initialization

    public init() {
        logger.info("Initializing CaptureDelegateHandler with Swift concurrency")
    }

    deinit {
        eventContinuation?.finish()
    }
    
    // MARK: - Event Notification Methods

    public func notifyCaptureDidStart() {
        let event: CaptureEventType = .captureStarted
        recordEvent(.captureStarted)

        // Notify legacy delegate (backward compatibility)
        delegate?.captureDidStart()

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.info("Notified: captureDidStart")
    }

    public func notifyCaptureDidComplete(with image: UIImage) {
        let event: CaptureEventType = .captureCompleted(image: image)
        recordEvent(.captureCompleted(imageSize: image.size))

        // Notify legacy delegate (backward compatibility)
        delegate?.captureDidComplete(with: image)

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.info("Notified: captureDidComplete - image size: \(image.size.width)x\(image.size.height)")
    }

    public func notifyCaptureDidFail(with error: CaptureError) {
        let event: CaptureEventType = .captureFailed(error: error)
        recordEvent(.captureFailed(error: error))

        // Notify legacy delegate (backward compatibility)
        delegate?.captureDidFail(with: error)

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.error("Notified: captureDidFail - error: \(error.localizedDescription)")
    }

    public func notifyProcessingProgressDidUpdate(_ progress: Double) {
        let event: CaptureEventType = .progressUpdated(progress: progress)
        recordEvent(.progressUpdated(progress: progress))

        // Notify legacy delegate (backward compatibility)
        delegate?.processingProgressDidUpdate(progress)

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.debug("Notified: processingProgressDidUpdate - progress: \(progress)")
    }

    public func notifyAnalysisDidComplete(with result: NutritionExtractionResult) {
        let event: CaptureEventType = .analysisCompleted(result: result)
        recordEvent(.analysisCompleted(success: result.metadata.confidence > 0.5))

        // Notify legacy delegate (backward compatibility)
        delegate?.analysisDidComplete(with: result)

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.info("Notified: analysisDidComplete - confidence: \(result.metadata.confidence)")
    }

    public func notifyAnalysisDidFail(with error: Error) {
        let event: CaptureEventType = .analysisFailed(error: error)
        recordEvent(.analysisFailed(error: error))

        // Notify legacy delegate (backward compatibility)
        delegate?.analysisDidFail(with: error)

        // Broadcast to modern stream subscribers
        eventContinuation?.yield(event)

        logger.error("Notified: analysisDidFail - error: \(error.localizedDescription)")
    }
    
    // MARK: - Event History
    
    private func recordEvent(_ event: CaptureEvent) {
        eventHistory.append(event)
        
        // Maintain max history
        if eventHistory.count > maxEventHistory {
            eventHistory.removeFirst()
        }
    }
    
    public func getEventHistory() -> [CaptureEvent] {
        return eventHistory
    }
    
    public func clearEventHistory() {
        eventHistory.removeAll()
    }
}

// MARK: - Capture Event (Legacy - for event history)

public enum CaptureEvent {
    case captureStarted
    case captureCompleted(imageSize: CGSize)
    case captureFailed(error: CaptureError)
    case progressUpdated(progress: Double)
    case analysisCompleted(success: Bool)
    case analysisFailed(error: Error)

    public var timestamp: Date {
        return Date()
    }

    public var description: String {
        switch self {
        case .captureStarted:
            return "Capture started"
        case .captureCompleted(let size):
            return "Capture completed (size: \(size.width)x\(size.height))"
        case .captureFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .progressUpdated(let progress):
            return "Progress updated: \(Int(progress * 100))%"
        case .analysisCompleted(let success):
            return "Analysis completed (success: \(success))"
        case .analysisFailed(let error):
            return "Analysis failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Modern Event Type (for AsyncStream)

/// Type-safe event type for modern Swift concurrency consumers
///
/// Use this with `eventStream` for async/await based event handling:
/// ```swift
/// for await event in captureHandler.eventStream {
///     switch event {
///     case .captureCompleted(let image):
///         // Handle captured image
///     case .progressUpdated(let progress):
///         // Update UI progress
///     // ...
///     }
/// }
/// ```
public enum CaptureEventType: Sendable {
    case captureStarted
    case captureCompleted(image: UIImage)
    case captureFailed(error: CaptureError)
    case progressUpdated(progress: Double)
    case analysisCompleted(result: NutritionExtractionResult)
    case analysisFailed(error: Error)
}