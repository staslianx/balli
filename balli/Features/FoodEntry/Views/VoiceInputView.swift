//
//  VoiceInputView.swift
//  balli
//
//  Voice input interface for meal logging with Apple Speech Recognition
//  Shows real-time word-by-word transcription
//

import SwiftUI
import AVFoundation
import Speech
import CoreData
import os.log

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    // Speech recognition
    @StateObject private var speechRecognizer = SpeechRecognitionService()

    // State
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showingResult = false
    @State private var isProcessingButtonTap = false // Debounce rapid taps

    // Meal parsing state
    @State private var parsedMealData: ParsedMealData?
    @State private var showingPreview = false
    @State private var isParsing = false

    // Haptic feedback
    private let hapticManager = HapticManager()

    // Animation values
    @State private var pulseAnimation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content area
                VStack(spacing: 0) {
                    // Transcription display area
                    transcriptionDisplayView
                        .frame(maxHeight: .infinity)
                }
                .navigationTitle("Öğününü Kaydet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if showingPreview {
                            // Checkmark button to save meal
                            Button {
                                Task {
                                    await saveMealEntry()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.primaryPurple)
                        }
                    }
                }

                // Floating recording button overlay
                recordingControlsView
                    .padding(.bottom, ResponsiveDesign.Spacing.large)
            }
        }
        .task {
            // Start animation immediately
            pulseAnimation = true

            // Complete async initialization that was deferred from init()
            await speechRecognizer.completeInitialization()

            // Check permissions first
            speechRecognizer.checkAuthorizationStatus()
            speechRecognizer.checkMicrophonePermission()

            let speechStatus = speechRecognizer.authorizationStatus
            let micGranted = speechRecognizer.microphonePermissionGranted
            logger.info("🎙️ VoiceInputView appeared - Speech: \(String(describing: speechStatus)), Mic: \(micGranted)")

            // Request permissions if needed
            if speechRecognizer.authorizationStatus != .authorized {
                logger.info("🎙️ Requesting speech recognition authorization...")
                await speechRecognizer.requestAuthorization()
                let newStatus = speechRecognizer.authorizationStatus
                logger.info("🎙️ Speech authorization result: \(String(describing: newStatus))")
            }

            if !speechRecognizer.microphonePermissionGranted {
                logger.info("🎙️ Requesting microphone permission...")
                await speechRecognizer.requestMicrophonePermission()
                let micResult = speechRecognizer.microphonePermissionGranted
                logger.info("🎙️ Microphone permission result: \(micResult)")
            }
        }
        .onDisappear {
            speechRecognizer.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-check authorization when app becomes active (e.g., returning from Settings)
            speechRecognizer.checkAuthorizationStatus()
            speechRecognizer.checkMicrophonePermission()
        }
        .alert("Hata", isPresented: .constant(speechRecognizer.error != nil), presenting: speechRecognizer.error) { _ in
            Button("Tamam") {
                speechRecognizer.error = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Transcription Display

    @ViewBuilder
    private var transcriptionDisplayView: some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.Spacing.medium, content: {
                if showingPreview, let parsedData = parsedMealData {
                    // Preview of parsed meal data
                    mealPreviewView(parsedData)
                } else if isParsing {
                    // Loading indicator while parsing
                    VStack(spacing: ResponsiveDesign.Spacing.medium) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppTheme.primaryPurple)

                        Text("Öğün bilgisi çıkarılıyor...")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResponsiveDesign.height(80))
                } else if speechRecognizer.transcribedText.isEmpty {
                    // Placeholder when not recording
                    VStack(spacing: ResponsiveDesign.Spacing.small) {
                        if speechRecognizer.authorizationStatus != .authorized || !speechRecognizer.microphonePermissionGranted {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.red)

                            Text("İzinler Gerekli")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)

                            VStack(spacing: 8) {
                                if speechRecognizer.authorizationStatus != .authorized {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text("Konuşma Tanıma izni")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                }

                                if !speechRecognizer.microphonePermissionGranted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text("Mikrofon izni")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                }
                            }
                            .padding(.horizontal)

                            Button {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            } label: {
                                Text("Ayarları Aç")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.primaryPurple)
                                    .clipShape(Capsule())
                            }
                            .padding(.top, ResponsiveDesign.Spacing.small)
                        } else if !speechRecognizer.isRecognizing {
                            Image(systemName: "waveform.low")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResponsiveDesign.height(80))
                } else {
                    // Real-time transcription - scrollable with wrapping text
                    Text(speechRecognizer.transcribedText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .padding(.horizontal)
                        .padding(.top, ResponsiveDesign.Spacing.medium)
                        .padding(.bottom, ResponsiveDesign.height(150))
                }
            })
        }
    }

    // MARK: - Meal Preview

    @ViewBuilder
    private func mealPreviewView(_ data: ParsedMealData) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Carbs
            if let carbs = data.carbsGrams {
                HStack {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Karbonhidrat")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("\(carbs)g")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Spacer()
                }
            }

            // Time
            if let timestamp = data.timestamp {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saat")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(timestamp, style: .time)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Spacer()
                }
            }

            // Meal Type
            if let mealType = data.localizedMealType {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Öğün")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(mealType.capitalized)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, ResponsiveDesign.Spacing.large)
    }

    // MARK: - Recording Controls

    @ViewBuilder
    private var recordingControlsView: some View {
        // Microphone button - floating liquid glass overlay
        Button(action: {
            toggleRecording()
        }) {
            ZStack {
                // Animated background when recording
                if speechRecognizer.isRecognizing {
                    ForEach(0..<2) { index in
                        Circle()
                            .fill(AppTheme.primaryPurple.opacity(0.15))
                            .frame(width: 75 + CGFloat(index) * 35, height: 75 + CGFloat(index) * 35)
                            .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: pulseAnimation
                            )
                    }
                }

                // Main Liquid Glass button
                Image(systemName: speechRecognizer.isRecognizing ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .symbolEffect(.bounce, value: speechRecognizer.isRecognizing)
            }
            .frame(width: 75, height: 75)
            .background(Color.clear)
            .clipShape(Circle())
            .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled((speechRecognizer.authorizationStatus != .authorized || !speechRecognizer.microphonePermissionGranted) && !speechRecognizer.isRecognizing || isProcessingButtonTap)
        .opacity((speechRecognizer.authorizationStatus != .authorized || !speechRecognizer.microphonePermissionGranted) && !speechRecognizer.isRecognizing || isProcessingButtonTap ? 0.5 : 1.0)
    }


    // MARK: - Helper Methods

    private func toggleRecording() {
        // Debounce rapid taps to prevent concurrent operations
        guard !isProcessingButtonTap else {
            logger.warning("⚠️ Ignoring rapid tap - still processing previous tap")
            return
        }

        logger.info("🎙️ Mic button tapped - Speech: \(String(describing: speechRecognizer.authorizationStatus)), Mic: \(speechRecognizer.microphonePermissionGranted), isRecognizing: \(speechRecognizer.isRecognizing)")

        // Set debounce flag
        isProcessingButtonTap = true

        // Reset debounce flag after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                isProcessingButtonTap = false
            }
        }

        if showingPreview {
            // Reset to start re-recording
            showingPreview = false
            parsedMealData = nil
            speechRecognizer.transcribedText = ""
            startRecording()
        } else if speechRecognizer.isRecognizing {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                hapticManager.notification(.success)
                try await speechRecognizer.startRecording()

                // Start duration timer on main actor
                await MainActor.run {
                    recordingDuration = 0
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        Task { @MainActor [self] in
                            recordingDuration += 0.1
                        }
                    }
                }
            } catch {
                logger.error("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func stopRecording() {
        hapticManager.impact(.light)
        speechRecognizer.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Parse the transcription
        Task {
            await parseMealTranscription()
        }
    }

    private func parseMealTranscription() async {
        guard !speechRecognizer.transcribedText.isEmpty else { return }

        isParsing = true

        // Parse locally - no network call needed!
        let parsed = MealTranscriptionParser.parse(speechRecognizer.transcribedText)

        await MainActor.run {
            isParsing = false

            if parsed.isValid {
                parsedMealData = parsed
                showingPreview = true
                hapticManager.notification(.success)
                logger.info("✅ Parsed meal: \(parsed.carbsGrams ?? 0)g carbs, \(parsed.mealType ?? "unknown")")
            } else {
                // Show error - no valid data extracted
                speechRecognizer.error = .mealParsingFailed("Karbonhidrat miktarı bulunamadı. Lütfen tekrar deneyin.")
                logger.warning("⚠️ Could not extract carbs from: \(speechRecognizer.transcribedText)")
            }
        }
    }

    private func saveMealEntry() async {
        guard let parsedData = parsedMealData,
              let carbsGrams = parsedData.carbsGrams else {
            return
        }

        // Create a background context for async CoreData operations
        // This prevents blocking the main thread during save
        guard let coordinator = viewContext.persistentStoreCoordinator else {
            logger.error("Failed to get persistent store coordinator")
            return
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // Capture values needed in background context - these are Sendable value types
        let carbsValue = carbsGrams
        let timestamp = parsedData.timestamp ?? Date()
        let mealTypeText = parsedData.localizedMealType ?? "ara öğün"

        // Perform CoreData operations on background context
        do {
            try await context.perform {
                // Create a FoodItem to represent the voice-entered food
                // This is required because MealEntry.foodItem is a non-optional relationship
                let foodItem = FoodItem(context: context)
                foodItem.id = UUID()

                // Use the meal type as the food name, or a descriptive default
                foodItem.name = "Sesli Giriş: \(mealTypeText.capitalized)"
                foodItem.nameTr = "Sesli Giriş: \(mealTypeText.capitalized)"

                // Set nutrition based on voice input (carbs only)
                foodItem.totalCarbs = Double(carbsValue)
                foodItem.servingSize = 1.0
                foodItem.servingUnit = "porsiyon"
                foodItem.gramWeight = Double(carbsValue)

                // Mark as voice entry
                foodItem.source = "voice"
                foodItem.dateAdded = Date()
                // lastModified will be set by willSave() - don't set it here to avoid recursion
                foodItem.lastUsed = Date()
                foodItem.useCount = 1

                // Create the meal entry and link it to the food item
                let mealEntry = MealEntry(context: context)
                mealEntry.id = UUID()
                mealEntry.timestamp = timestamp
                mealEntry.mealType = mealTypeText
                mealEntry.foodItem = foodItem  // ✅ Required relationship
                mealEntry.quantity = 1.0
                mealEntry.unit = "porsiyon"

                // IMPORTANT: Calculate nutrition BEFORE save to avoid infinite recursion
                // This sets consumedCarbs, consumedProtein, etc. based on the food item
                mealEntry.calculateNutrition()

                // Override consumedCarbs with our voice input value since we only have carbs
                mealEntry.consumedCarbs = Double(carbsValue)

                // Save on background thread - won't block main thread
                try context.save()

                // Note: No logger calls here - this closure runs on background thread
                // and cannot access main actor-isolated properties
            }

            // Success - log and update UI on main actor
            await MainActor.run {
                logger.info("✅ Saved meal entry: \(carbsValue)g carbs, \(mealTypeText)")
                hapticManager.notification(.success)
                dismiss()
            }
        } catch {
            // Error - log and update UI on main actor
            await MainActor.run {
                logger.error("Failed to save meal entry: \(error.localizedDescription)")
                speechRecognizer.error = .mealParsingFailed("Öğün kaydedilemedi: \(error.localizedDescription)")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Logger
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "VoiceInputView")
}

// MARK: - Preview

#Preview {
    VoiceInputView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
