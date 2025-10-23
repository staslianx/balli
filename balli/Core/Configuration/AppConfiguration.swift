//
//  AppConfiguration.swift
//  balli
//
//  App configuration
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

// MARK: - App Configuration
@MainActor
final class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()
    
    @Published var isConfigured = false
    @Published var configurationError: Error?
    
    private let logger = AppLoggers.App.configuration
    
    private init() {}
    
    // MARK: - Initialize Services
    func initialize() async {
        logger.info("Starting app configuration")

        // Configuration removed - operating in local mode

        // Configure local services for development
        // Local service configuration goes here if needed

        // Initialize authentication
        await initializeAuthentication()

        // Warm up AI service
        // await warmupAIService()

        isConfigured = true
        logger.info("App configuration completed successfully")
    }
    
    // MARK: - Initialize Authentication
    private func initializeAuthentication() async {
        // Authentication removed
        logger.info("Authentication disabled - service removed")
    }
    
    // MARK: - Warm Up AI Service
    private func warmupAIService() async {
        logger.info("Warming up AI service")

        // Note: AI service warmup disabled pending proper initialization architecture
        /*
        let aiService = AIService()

        // Send a simple test prompt to warm up the service
        do {
            _ = try await aiService.generateContent("Hello")
            logger.info("AI service warmed up successfully")
        } catch {
            logger.warning("AI service warmup failed: \(error.localizedDescription)")
            // Non-critical error - service will initialize on first real use
        }
        */

        logger.info("AI service warmup temporarily disabled")
    }
    
    // MARK: - Reset Configuration
    func reset() async {
        logger.info("Resetting app configuration")

        // Local mode - no external authentication to sign out
        // Local caches cleared by system as needed
        
        // Reset configuration state
        isConfigured = false
        configurationError = nil
        
        logger.info("App configuration reset completed")
    }
}

// MARK: - App Configuration Modifier
struct ConfigureApp: ViewModifier {
    @StateObject private var configuration = AppConfiguration.shared
    @State private var isInitializing = true
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isInitializing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            
                            Text("Initializing Balli...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                    }
                }
            }
            .task {
                await configuration.initialize()
                
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitializing = false
                }
            }
            .alert("Configuration Error", isPresented: .constant(configuration.configurationError != nil)) {
                Button("Retry") {
                    Task {
                        await configuration.initialize()
                    }
                }
                Button("Continue Offline", role: .cancel) {
                    configuration.configurationError = nil
                }
            } message: {
                Text(configuration.configurationError?.localizedDescription ?? "Unknown error")
            }
    }
}

extension View {
    func configureApp() -> some View {
        modifier(ConfigureApp())
    }
}
