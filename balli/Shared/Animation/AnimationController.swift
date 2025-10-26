//
//  AnimationController.swift
//  balli
//
//  Centralized animation management system for consistent 60fps performance
//

import SwiftUI
import Combine
import QuartzCore
import OSLog

/// Central animation coordinator ensuring smooth 60fps performance
@MainActor
public final class AnimationController: ObservableObject {
    // MARK: - Singleton
    public static let shared = AnimationController()
    
    // MARK: - Published Properties
    @Published public private(set) var currentFPS: Double = 60.0
    @Published public private(set) var performanceMode: PerformanceMode = .normal
    @Published public private(set) var activeAnimations: Set<AnimationID> = []
    
    // MARK: - Performance Modes
    public enum PerformanceMode {
        case reduced    // < 30 FPS - use simple animations
        case normal     // 30-50 FPS - use standard animations
        case optimal    // 50+ FPS - use full animations
    }
    
    // MARK: - Animation ID
    public struct AnimationID: Hashable {
        let id: String
        let priority: AnimationPriority
        
        public init(_ id: String, priority: AnimationPriority = .normal) {
            self.id = id
            self.priority = priority
        }
    }
    
    // MARK: - Animation Priority
    public enum AnimationPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        public static func < (lhs: AnimationPriority, rhs: AnimationPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Private Properties
    private let logger = AppLoggers.Performance.animation
    private var displayLink: CADisplayLink?
    private var frameTimestamps: [TimeInterval] = []
    private let maxFrameCount = 60 // Track last 60 frames for 1 second at 60fps
    private var animationQueue: [AnimationID] = []
    private let maxConcurrentAnimations = 3
    
    // Performance tracking
    private var lastFrameTime: TimeInterval = 0
    private var frameDropCount = 0
    private let frameDropThreshold = 5 // Frames below target FPS to trigger performance adjustment
    
    // MARK: - Initialization
    private init() {
        setupDisplayLink()
    }
    
    deinit {
        // Display link will be invalidated when the app terminates
    }
    
    // MARK: - Display Link Setup
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Stop monitoring - call this when app goes to background
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func frameUpdate(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        // Calculate frame time
        if lastFrameTime > 0 {
            let _ = currentTime - lastFrameTime
            frameTimestamps.append(currentTime)
            
            // Keep only recent frames
            while frameTimestamps.count > maxFrameCount {
                frameTimestamps.removeFirst()
            }
            
            // Calculate FPS
            if frameTimestamps.count > 1,
               let lastTimestamp = frameTimestamps.last,
               let firstTimestamp = frameTimestamps.first {
                let duration = lastTimestamp - firstTimestamp
                let fps = Double(frameTimestamps.count - 1) / duration
                currentFPS = fps

                // Update performance mode
                updatePerformanceMode(fps: fps)
            }
        }
        
        lastFrameTime = currentTime
    }
    
    // MARK: - Performance Mode Management
    private func updatePerformanceMode(fps: Double) {
        let newMode: PerformanceMode
        
        switch fps {
        case 0..<30:
            newMode = .reduced
            if performanceMode != .reduced {
                logger.warning("Entering reduced performance mode: \(String(format: "%.1f", fps)) FPS")
            }
        case 30..<50:
            newMode = .normal
        default:
            newMode = .optimal
        }
        
        if newMode != performanceMode {
            performanceMode = newMode
        }
    }
    
    // MARK: - Animation Management
    
    /// Register an animation as active
    public func beginAnimation(_ id: AnimationID) {
        // Check if we should queue this animation
        if shouldQueueAnimation(id) {
            queueAnimation(id)
            return
        }
        
        activeAnimations.insert(id)
        logger.debug("Started animation: \(id.id)")
    }
    
    /// Mark an animation as completed
    public func endAnimation(_ id: AnimationID) {
        activeAnimations.remove(id)
        logger.debug("Ended animation: \(id.id)")
        
        // Process queued animations
        processAnimationQueue()
    }
    
    /// Check if animation should be queued
    private func shouldQueueAnimation(_ id: AnimationID) -> Bool {
        // Critical animations always run
        if id.priority == .critical {
            return false
        }
        
        // Queue if too many animations or in reduced performance mode
        return activeAnimations.count >= maxConcurrentAnimations || 
               performanceMode == .reduced
    }
    
    /// Add animation to queue
    private func queueAnimation(_ id: AnimationID) {
        animationQueue.append(id)
        animationQueue.sort { $0.priority > $1.priority }
        logger.debug("Queued animation: \(id.id)")
    }
    
    /// Process queued animations
    private func processAnimationQueue() {
        while !animationQueue.isEmpty && activeAnimations.count < maxConcurrentAnimations {
            let nextAnimation = animationQueue.removeFirst()
            activeAnimations.insert(nextAnimation)
            logger.debug("Started queued animation: \(nextAnimation.id)")
        }
    }
    
    // MARK: - Animation Helpers
    
    /// Get appropriate animation for current performance mode
    public func animation(for preset: AnimationPreset) -> Animation {
        switch performanceMode {
        case .reduced:
            // Use faster, simpler animations in reduced mode
            return preset.reducedAnimation
        case .normal:
            return preset.standardAnimation
        case .optimal:
            return preset.optimalAnimation
        }
    }
    
    /// Check if animations should be disabled
    public var shouldDisableAnimations: Bool {
        performanceMode == .reduced && activeAnimations.count > 2
    }
    
    /// Check if complex animations are allowed
    public var allowComplexAnimations: Bool {
        performanceMode == .optimal && activeAnimations.count < 2
    }
}

// MARK: - Animation Preset Protocol
public protocol AnimationPreset {
    var standardAnimation: Animation { get }
    var reducedAnimation: Animation { get }
    var optimalAnimation: Animation { get }
}