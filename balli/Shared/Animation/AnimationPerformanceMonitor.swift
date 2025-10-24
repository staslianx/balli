//
//  AnimationPerformanceMonitor.swift
//  balli
//
//  Advanced performance monitoring for animation system
//

import SwiftUI
import Combine
import OSLog
import QuartzCore

/// Detailed performance monitoring for animations
@MainActor
public final class AnimationPerformanceMonitor: ObservableObject {
    // MARK: - Performance Metrics
    public struct PerformanceMetrics {
        let averageFPS: Double
        let minFPS: Double
        let maxFPS: Double
        let frameDropCount: Int
        let stutterEvents: Int
        let timestamp: Date
    }
    
    // MARK: - Performance Event
    public struct PerformanceEvent {
        let type: EventType
        let fps: Double
        let activeAnimations: Int
        let timestamp: Date
        let context: String?
        
        enum EventType {
            case frameDropped
            case stutterDetected
            case performanceDegraded
            case performanceRecovered
        }
    }
    
    // MARK: - Published Properties
    @Published public private(set) var currentMetrics: PerformanceMetrics?
    @Published public private(set) var recentEvents: [PerformanceEvent] = []
    @Published public private(set) var isMonitoring = false
    
    // MARK: - Private Properties
    private let logger = AppLoggers.Performance.animation
    private let controller = AnimationController.shared
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var frameTimestamps: [TimeInterval] = []
    private var frameDrops: [TimeInterval] = []
    private var lastFrameTime: TimeInterval = 0
    private var monitoringStartTime: Date?
    
    // Thresholds
    private let targetFPS: Double = 60.0
    private let acceptableVariance: Double = 5.0 // Allow 55-65 FPS
    private let stutterThreshold: Int = 3 // Consecutive frame drops
    private let maxEventHistory = 50
    
    // MARK: - Singleton
    public static let shared = AnimationPerformanceMonitor()
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Monitoring Control
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringStartTime = Date()
        frameTimestamps.removeAll()
        frameDrops.removeAll()
        
        displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink?.add(to: .main, forMode: .common)
        
        logger.info("Started performance monitoring")
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        displayLink?.invalidate()
        displayLink = nil
        
        _ = generateReport()
        logger.info("Stopped performance monitoring")
    }
    
    // MARK: - Frame Updates
    @objc private func frameUpdate(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastFrameTime > 0 {
            let frameDuration = currentTime - lastFrameTime
            let currentFPS = 1.0 / frameDuration
            
            frameTimestamps.append(currentTime)
            
            // Keep last 2 seconds of data
            while frameTimestamps.count > 120 {
                frameTimestamps.removeFirst()
            }
            
            // Check for frame drop
            if currentFPS < (targetFPS - acceptableVariance) {
                handleFrameDrop(fps: currentFPS, timestamp: currentTime)
            }
            
            // Update metrics periodically
            if frameTimestamps.count >= 60 {
                updateMetrics()
            }
        }
        
        lastFrameTime = currentTime
    }
    
    // MARK: - Performance Analysis
    private func handleFrameDrop(fps: Double, timestamp: TimeInterval) {
        frameDrops.append(timestamp)
        
        // Check for stuttering (multiple consecutive drops)
        let recentDrops = frameDrops.filter { timestamp - $0 < 0.1 }
        if recentDrops.count >= stutterThreshold {
            recordEvent(.stutterDetected, fps: fps, context: "Consecutive frame drops detected")
            frameDrops.removeAll() // Reset to avoid duplicate stutter events
        } else {
            recordEvent(.frameDropped, fps: fps)
        }
    }
    
    private func updateMetrics() {
        guard frameTimestamps.count > 1,
              let lastTimestamp = frameTimestamps.last,
              let firstTimestamp = frameTimestamps.first else { return }

        let timeRange = lastTimestamp - firstTimestamp
        let frameCount = frameTimestamps.count - 1
        let averageFPS = Double(frameCount) / timeRange
        
        // Calculate min/max FPS from frame intervals
        var minFPS = Double.infinity
        var maxFPS = 0.0
        
        for i in 1..<frameTimestamps.count {
            let interval = frameTimestamps[i] - frameTimestamps[i-1]
            let fps = 1.0 / interval
            minFPS = min(minFPS, fps)
            maxFPS = max(maxFPS, fps)
        }
        
        let metrics = PerformanceMetrics(
            averageFPS: averageFPS,
            minFPS: minFPS,
            maxFPS: maxFPS,
            frameDropCount: frameDrops.count,
            stutterEvents: recentEvents.filter { $0.type == .stutterDetected }.count,
            timestamp: Date()
        )
        
        currentMetrics = metrics
        
        // Check for performance degradation
        if averageFPS < 50 {
            recordEvent(.performanceDegraded, fps: averageFPS, context: "Average FPS below 50")
        }
    }
    
    // MARK: - Event Recording
    private func recordEvent(
        _ type: PerformanceEvent.EventType,
        fps: Double,
        context: String? = nil
    ) {
        let event = PerformanceEvent(
            type: type,
            fps: fps,
            activeAnimations: controller.activeAnimations.count,
            timestamp: Date(),
            context: context
        )
        
        recentEvents.append(event)
        
        // Limit event history
        if recentEvents.count > maxEventHistory {
            recentEvents.removeFirst()
        }
        
        // Log significant events
        switch type {
        case .stutterDetected:
            logger.warning("Stutter detected: \(String(format: "%.1f", fps)) FPS, \(event.activeAnimations) active animations")
        case .performanceDegraded:
            logger.error("Performance degraded: \(String(format: "%.1f", fps)) FPS")
        default:
            break
        }
    }
    
    // MARK: - Observers
    private func setupObservers() {
        // Monitor active animations
        controller.$activeAnimations
            .removeDuplicates()
            .sink { [weak self] animations in
                if animations.count > 3 {
                    self?.logger.warning("High animation count: \(animations.count)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Reporting
    public func generateReport() -> String {
        guard let metrics = currentMetrics else {
            return "No performance data available"
        }
        
        let duration = monitoringStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        var report = """
        Animation Performance Report
        ============================
        Duration: \(String(format: "%.1f", duration))s
        
        FPS Metrics:
        - Average: \(String(format: "%.1f", metrics.averageFPS))
        - Min: \(String(format: "%.1f", metrics.minFPS))
        - Max: \(String(format: "%.1f", metrics.maxFPS))
        
        Issues:
        - Frame Drops: \(metrics.frameDropCount)
        - Stutter Events: \(metrics.stutterEvents)
        
        """
        
        if !recentEvents.isEmpty {
            report += "Recent Events:\n"
            for event in recentEvents.suffix(10) {
                report += "- \(event.type): \(String(format: "%.1f", event.fps)) FPS"
                if let context = event.context {
                    report += " (\(context))"
                }
                report += "\n"
            }
        }
        
        logger.info("Generated performance report")
        return report
    }
    
    // MARK: - Debug Helpers
    #if DEBUG
    /// Force a performance degradation for testing
    public func simulatePerformanceIssue() {
        recordEvent(.performanceDegraded, fps: 25, context: "Simulated for testing")
    }
    
    /// Get current performance status
    public var performanceStatus: String {
        guard let metrics = currentMetrics else { return "No data" }
        
        switch metrics.averageFPS {
        case 55...:
            return "Optimal (\(String(format: "%.0f", metrics.averageFPS)) FPS)"
        case 45..<55:
            return "Good (\(String(format: "%.0f", metrics.averageFPS)) FPS)"
        case 30..<45:
            return "Fair (\(String(format: "%.0f", metrics.averageFPS)) FPS)"
        default:
            return "Poor (\(String(format: "%.0f", metrics.averageFPS)) FPS)"
        }
    }
    #endif
}

// MARK: - SwiftUI Integration
public struct PerformanceMonitorView: View {
    @StateObject private var monitor = AnimationPerformanceMonitor.shared
    
    public var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 4) {
            Text("Performance: \(monitor.performanceStatus)")
                .font(.caption2)
                .foregroundColor(performanceColor)
            
            if monitor.currentMetrics != nil {
                Text("Active: \(AnimationController.shared.activeAnimations.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
        #else
        EmptyView()
        #endif
    }
    
    private var performanceColor: Color {
        guard let metrics = monitor.currentMetrics else { return .gray }
        
        switch metrics.averageFPS {
        case 55...:
            return .green
        case 45..<55:
            return .yellow
        case 30..<45:
            return .orange
        default:
            return .red
        }
    }
}