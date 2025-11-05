//
//  DexcomBackgroundRefreshManagerProtocol.swift
//  balli
//
//  Protocol for Dexcom background refresh manager to enable dependency injection and testing
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Protocol defining the interface for Dexcom background refresh management
@MainActor
protocol DexcomBackgroundRefreshManagerProtocol {
    /// Register background task handler
    /// Call this from AppDelegate.didFinishLaunchingWithOptions
    func registerBackgroundTask()

    /// Schedule next background refresh
    /// Call this when app enters background
    func scheduleBackgroundRefresh()
}
