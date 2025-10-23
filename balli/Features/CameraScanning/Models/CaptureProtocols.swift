//
//  CaptureProtocols.swift
//  balli
//
//  Protocol definitions for capture flow components
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Capture Session Management Protocol

@MainActor
public protocol CaptureSessionManaging: AnyObject {
    var currentSession: CaptureSession? { get }
    var recentSessions: [CaptureSession] { get }
    
    func createSession(with zoomLevel: String?) async -> CaptureSession
    func updateSession(_ sessionId: UUID, update: (inout CaptureSession) -> Void) async
    func saveSession(_ session: CaptureSession) async throws
    func loadSession(id: UUID) async -> CaptureSession?
    func deleteSession(id: UUID) async
    func clearHistory() async
}

// MARK: - Capture State Machine Protocol

@MainActor
public protocol CaptureStateMachine: AnyObject {
    var currentState: CaptureFlowState { get }
    var processingProgress: Double { get }
    
    func transition(to state: CaptureFlowState) async
    func canTransition(from: CaptureFlowState, to: CaptureFlowState) -> Bool
    func handleStateChange(_ state: CaptureFlowState) async
}

// MARK: - Capture Delegate Protocol

@MainActor
public protocol CaptureDelegate: AnyObject {
    func captureDidStart()
    func captureDidComplete(with image: UIImage)
    func captureDidFail(with error: CaptureError)
    func processingProgressDidUpdate(_ progress: Double)
    func analysisDidComplete(with result: NutritionExtractionResult)
    func analysisDidFail(with error: Error)
}

// MARK: - Capture Configuration Protocol

public protocol CaptureConfiguring {
    var maxRetryCount: Int { get }
    var sessionExpirationInterval: TimeInterval { get }
    var compressionQuality: CGFloat { get }
    var thumbnailCompressionQuality: CGFloat { get }
    var optimizedImageCompressionQuality: CGFloat { get }
    var maxHistoryCount: Int { get }
    
    func validate() -> Bool
}

// MARK: - Image Processing Protocol

public protocol ImageProcessing: Actor {
    func optimizeForAI(image: UIImage) async throws -> UIImage
    func generateThumbnail(from image: UIImage) async -> UIImage
    func compressForStorage(image: UIImage) async -> Data?
}

// MARK: - AI Processing Protocol

public protocol AIProcessing: Actor {
    func extractNutrition(from imageData: Data, progressHandler: @escaping (Double) -> Void) async throws -> String
    func validateResponse(_ response: String) throws -> Bool
}

// MARK: - Capture Flow Coordinating Protocol

@MainActor
public protocol CaptureFlowCoordinating: AnyObject {
    var isCapturing: Bool { get }
    var isAnalyzing: Bool { get }
    var capturedImage: UIImage? { get }
    var showingCapturedImage: Bool { get }
    var extractedNutrition: NutritionExtractionResult? { get }
    var currentError: CaptureError? { get }
    
    func startCapture() async
    func confirmAndProcess() async
    func cancelCapture() async
    func retryCapture(_ session: CaptureSession) async
    func clearCapturedImage()
}

// MARK: - Haptic Feedback Protocol

@MainActor
public protocol HapticFeedback {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - Security Protocol

public protocol SecurityManaging: Actor {
    func canPerformAIScan() async -> Bool
    func recordAIScan() async
    func getRemainingScans() async -> Int
}