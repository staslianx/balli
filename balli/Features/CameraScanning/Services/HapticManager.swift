//
//  HapticManager.swift
//  balli
//
//  Haptic feedback management for capture flow
//

import UIKit
import os.log

// MARK: - Haptic Manager

@MainActor
public final class HapticManager: HapticFeedback {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "HapticManager")
    
    // MARK: - Feedback Generators
    private let impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [
        .light: UIImpactFeedbackGenerator(style: .light),
        .medium: UIImpactFeedbackGenerator(style: .medium),
        .heavy: UIImpactFeedbackGenerator(style: .heavy),
        .soft: UIImpactFeedbackGenerator(style: .soft),
        .rigid: UIImpactFeedbackGenerator(style: .rigid)
    ]
    
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Settings
    private var isEnabled: Bool = true
    
    // MARK: - Initialization
    
    public init() {
        prepareGenerators()
        logger.info("HapticManager initialized")
    }
    
    // MARK: - Public Methods
    
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        
        impactGenerators[style]?.impactOccurred()
        logger.debug("Impact feedback triggered: \(String(describing: style))")
    }
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        
        notificationGenerator.notificationOccurred(type)
        logger.debug("Notification feedback triggered: \(String(describing: type))")
    }
    
    public func selection() {
        guard isEnabled else { return }
        
        selectionGenerator.selectionChanged()
        logger.debug("Selection feedback triggered")
    }
    
    // MARK: - Configuration
    
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        logger.info("Haptic feedback \(enabled ? "enabled" : "disabled")")
    }
    
    public func prepareGenerators() {
        // Prepare all generators for immediate use
        for generator in impactGenerators.values {
            generator.prepare()
        }
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Capture Flow Specific Feedback
    
    public func captureStarted() {
        impact(.light)
    }
    
    public func captureCompleted() {
        notification(.success)
    }
    
    public func captureFailed() {
        notification(.error)
    }
    
    public func processingStarted() {
        impact(.medium)
    }
    
    public func processingCompleted() {
        notification(.success)
    }
    
    public func processingFailed() {
        notification(.error)
    }
    
    public func buttonTapped() {
        selection()
    }
}