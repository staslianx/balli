//
//  CaptureLifecycleHandler.swift
//  balli
//
//  Handles lifecycle events for capture flow (background/foreground, observers)
//  Extracted from CaptureFlowManager for single responsibility
//

import UIKit
import os.log

/// Handles lifecycle events and notification observers for capture flow
@MainActor
final class CaptureLifecycleHandler {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureLifecycleHandler")

    // Lifecycle Observers
    nonisolated(unsafe) private var backgroundObserver: (any NSObjectProtocol)?
    nonisolated(unsafe) private var foregroundObserver: (any NSObjectProtocol)?

    // MARK: - Observer Setup

    func setupObservers(
        onEnterBackground: @escaping @Sendable () async -> Void,
        onEnterForeground: @escaping @Sendable () async -> Void
    ) {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await onEnterBackground()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await onEnterForeground()
            }
        }
    }

    // MARK: - Background Handling

    func handleEnterBackground(
        currentSession: CaptureSession?,
        sessionManager: CaptureSessionManager,
        cameraManager: CameraManager,
        processingTask: Task<Void, Never>?
    ) async {
        logger.info("Handling background transition")

        if let session = currentSession {
            try? await sessionManager.saveSession(session)
        }

        await cameraManager.stop()
        processingTask?.cancel()
    }

    // MARK: - Foreground Handling

    func handleEnterForeground(
        showingCapturedImage: Bool,
        cameraManager: CameraManager,
        sessionManager: CaptureSessionManager,
        onResumeProcessing: @escaping (CaptureSession) async -> Void
    ) async {
        logger.info("Handling foreground transition")

        if !showingCapturedImage {
            await cameraManager.prepare()
        }

        // Check for active session to resume
        if let activeSession = await sessionManager.getActiveSession() {
            if activeSession.isActive && !sessionManager.isSessionExpired(activeSession) {
                await onResumeProcessing(activeSession)
            }
        }
    }

    // MARK: - Session Recovery

    func resumeProcessing(
        session: CaptureSession,
        onProcessCapture: @escaping (UUID) async -> Void
    ) async {
        logger.info("Resuming processing for session: \(session.id)")

        switch session.state {
        case .captured, .optimizing, .processingAI:
            await onProcessCapture(session.id)

        case .waitingForNetwork:
            // Note: Network availability check could be implemented here if needed
            await onProcessCapture(session.id)

        default:
            break
        }
    }

    // MARK: - Cleanup

    nonisolated func cleanup() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    deinit {
        cleanup()
    }
}
