//
//  VoiceInputView.swift
//  balli
//
//  Voice input interface for meal logging with Gemini 2.5 Flash
//  Records audio and uses AI to extract structured meal data
//

import SwiftUI
import AVFoundation
import CoreData
import os.log

// MARK: - Glass Text Field Modifier

// MARK: - Voice Input View

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    // Gemini audio recording
    @StateObject private var audioRecorder = AudioRecordingService()

    // State
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showingResult = false
    @State private var isProcessingButtonTap = false // Debounce rapid taps

    // Meal parsing state
    @State private var parsedMealData: ParsedMealData?
    @State private var showingPreview = false
    @State private var isParsing = false

    // Editable meal data (for user corrections)
    @State private var editableFoods: [EditableFoodItem] = []
    @State private var editableTotalCarbs: String = ""
    @State private var editableMealType: String = "ara öğün"
    @State private var editableMealTime: String = ""
    @State private var editableTimestamp: Date = Date()
    @State private var isDetailedFormat: Bool = false // Tracks if ANY ingredient has per-item carbs

    // Editable insulin data
    @State private var editableInsulinDosage: Double = 0
    @State private var editableInsulinType: String? = nil
    @State private var editableInsulinName: String? = nil
    @State private var hasInsulin: Bool = false

    // Success confirmation
    @State private var showingSaveConfirmation = false

    // Haptic feedback
    private let hapticManager = HapticManager()

    // Animation values
    @State private var dotAnimation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content area
                transcriptionDisplayView

                // Floating recording button overlay
                recordingControlsView
                    .padding(.bottom, ResponsiveDesign.Spacing.large)

                // Success confirmation toast
                if showingSaveConfirmation {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.primaryPurple)
                            Text("Öğün kaydedildi ✓")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .recipeGlass(tint: .warm, cornerRadius: 100)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingSaveConfirmation)
                }
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
                        .buttonStyle(.balliBordered)
                    }
                }
            }
        }
        .task {
            // Check microphone permission
            audioRecorder.checkMicrophonePermission()

            logger.info("🎙️ VoiceInputView ready with Gemini transcription")

            // Request permission if needed
            if !audioRecorder.microphonePermissionGranted {
                logger.info("🎙️ Requesting microphone permission...")
                await audioRecorder.requestMicrophonePermission()
                let micResult = audioRecorder.microphonePermissionGranted
                logger.info("🎙️ Microphone permission result: \(micResult)")
            }
        }
        .onChange(of: audioRecorder.isRecording) { _, isRecording in
            // Trigger dot animation when recording starts
            if isRecording {
                dotAnimation = true
            }
        }
        .onDisappear {
            // CRITICAL: Invalidate timer BEFORE cleanup to prevent memory leak
            recordingTimer?.invalidate()
            recordingTimer = nil
            audioRecorder.cleanup()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-check authorization when app becomes active (e.g., returning from Settings)
            audioRecorder.checkMicrophonePermission()
        }
        .alert("Hata", isPresented: .constant(audioRecorder.error != nil), presenting: audioRecorder.error) { _ in
            Button("Tamam") {
                audioRecorder.error = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Transcription Display

    @ViewBuilder
    private var transcriptionDisplayView: some View {
        if showingPreview, let parsedData = parsedMealData {
            // Preview of parsed meal data - scrollable
            ScrollView {
                mealPreviewView(parsedData)
            }
        } else if isParsing {
            ProcessingStateView()
        } else if !audioRecorder.isRecording {
            PlaceholderStateView(microphonePermissionGranted: audioRecorder.microphonePermissionGranted)
        } else {
            RecordingActiveView()
        }
    }

    // MARK: - Meal Preview (Editable)

    @ViewBuilder
    private func mealPreviewView(_ data: ParsedMealData) -> some View {
        MealPreviewEditor(
            parsedData: data,
            isDetailedFormat: isDetailedFormat, // Use corrected format flag, not parsedData.isDetailedFormat
            editableFoods: $editableFoods,
            editableTotalCarbs: $editableTotalCarbs,
            editableMealType: $editableMealType,
            editableMealTime: $editableMealTime,
            editableTimestamp: $editableTimestamp,
            hasInsulin: $hasInsulin,
            editableInsulinDosage: $editableInsulinDosage,
            editableInsulinType: $editableInsulinType,
            editableInsulinName: $editableInsulinName,
            onAdjustCarbs: adjustCarbs(by:)
        )
    }

    // MARK: - Recording Controls

    @ViewBuilder
    private var recordingControlsView: some View {
        // Microphone/Stop button - floating liquid glass
        Button(action: {
            toggleRecording()
        }) {
            // Icon
            Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.primaryPurple)
                .symbolEffect(.bounce, value: audioRecorder.isRecording)
                .frame(width: 75, height: 75)
                .background(Color.clear)
                .clipShape(Circle())
                .glassEffect(.regular, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!audioRecorder.microphonePermissionGranted && !audioRecorder.isRecording || isProcessingButtonTap)
        .opacity(!audioRecorder.microphonePermissionGranted && !audioRecorder.isRecording || isProcessingButtonTap ? 0.5 : 1.0)
    }


    // MARK: - Helper Methods

    private func toggleRecording() {
        // Debounce rapid taps to prevent concurrent operations
        guard !isProcessingButtonTap else {
            logger.warning("⚠️ Ignoring rapid tap - still processing previous tap")
            return
        }

        logger.info("🎙️ Mic button tapped - Mic: \(audioRecorder.microphonePermissionGranted), isRecording: \(audioRecorder.isRecording)")

        // Set debounce flag
        isProcessingButtonTap = true

        // Reset debounce flag after a very short delay (just enough to prevent double-taps)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                isProcessingButtonTap = false
            }
        }

        if showingPreview {
            // Reset to start re-recording
            showingPreview = false
            parsedMealData = nil
            startRecording()
        } else if audioRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                hapticManager.notification(.success)
                try await audioRecorder.startRecording()

                // Update recording duration from audio recorder
                await MainActor.run {
                    recordingDuration = 0
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioRecorder] _ in
                        Task { @MainActor in
                            recordingDuration = audioRecorder?.recordingDuration ?? 0
                        }
                    }
                }

                logger.info("✅ Started Gemini audio recording")
            } catch {
                logger.error("❌ Failed to start recording: \(error.localizedDescription)")
                audioRecorder.error = error as? AudioRecordingError
            }
        }
    }

    private func stopRecording() {
        hapticManager.impact(.light)
        recordingTimer?.invalidate()
        recordingTimer = nil

        _ = audioRecorder.stopRecording()

        // Transcribe with Gemini
        Task {
            await transcribeWithGemini()
        }
    }

    private func transcribeWithGemini() async {
        guard !audioRecorder.isRecording else { return }

        isParsing = true

        do {
            // Get recorded audio data
            guard let audioData = try audioRecorder.getRecordingData() else {
                throw AudioRecordingError.notRecording
            }

            logger.info("🎤 Transcribing \(audioData.count) bytes with Gemini...")

            // Call Gemini transcription service
            let response = try await GeminiTranscriptionService.shared.transcribeMeal(
                audioData: audioData,
                userId: "ios-user", // TODO: Get from Firebase Auth when available
                progressCallback: { message in
                    Task { @MainActor in
                        logger.info("📱 Progress: \(message)")
                    }
                }
            )

            await MainActor.run {
                isParsing = false

                if response.success, let mealData = response.data {
                    // Convert to ParsedMealData
                    parsedMealData = ParsedMealData(from: mealData)

                    // Determine if this is simple format (no per-item carbs intended)
                    // Simple format = either all items have nil carbs, OR only one item has carbs that matches the total
                    let foodsWithCarbs = mealData.foods.filter { $0.carbs != nil && $0.carbs! > 0 }
                    let isSimpleFormat: Bool

                    if foodsWithCarbs.isEmpty {
                        // No items have carbs - definitely simple format (Case 1)
                        isSimpleFormat = true
                    } else if foodsWithCarbs.count == 1 && foodsWithCarbs[0].carbs == mealData.totalCarbs {
                        // Only one item has carbs and it equals total - likely Gemini incorrectly assigned
                        // total to one item in Case 1 scenario (ERROR to fix)
                        isSimpleFormat = true
                    } else {
                        // Multiple items have different carbs, or sum of individual carbs - detailed format (Case 2 & 3)
                        isSimpleFormat = false
                    }

                    // Populate editable fields for user corrections
                    // Auto-capitalize first letter of food names
                    editableFoods = mealData.foods.map { food in
                        let capitalizedName = food.name.isEmpty ? "" : food.name.prefix(1).uppercased() + food.name.dropFirst()
                        return EditableFoodItem(
                            name: capitalizedName,
                            amount: food.amount,
                            // CRITICAL: In simple format (Case 1), show NO per-item carbs
                            // Only show total at top, never next to individual ingredients
                            carbs: isSimpleFormat ? nil : food.carbs
                        )
                    }

                    // Set detailed format flag based on CORRECTED editableFoods, not raw Gemini response
                    // This ensures UI only shows per-item carbs when they were explicitly provided by user
                    self.isDetailedFormat = !isSimpleFormat
                    editableTotalCarbs = "\(mealData.totalCarbs)"
                    editableMealType = mealData.mealType
                    editableMealTime = mealData.mealTime ?? ""

                    // Initialize timestamp - parse from mealTime if provided, otherwise use current time
                    if let timeString = mealData.mealTime, let parsedTime = parseTimeString(timeString) {
                        editableTimestamp = parsedTime
                    } else {
                        editableTimestamp = Date()
                    }

                    // Initialize insulin data if present
                    if let insulinDosage = mealData.insulinDosage, insulinDosage > 0 {
                        editableInsulinDosage = insulinDosage.rounded() // Round to nearest integer
                        editableInsulinType = mealData.insulinType
                        editableInsulinName = mealData.insulinName
                        hasInsulin = true
                    } else {
                        editableInsulinDosage = 0
                        editableInsulinType = nil
                        editableInsulinName = nil
                        hasInsulin = false
                    }

                    showingPreview = true
                    hapticManager.notification(.success)

                    logger.info("✅ Gemini transcription successful:")
                    logger.info("   - Foods: \(mealData.foods.count)")
                    logger.info("   - Total carbs: \(mealData.totalCarbs)g")
                    logger.info("   - Confidence: \(mealData.confidence)")
                    logger.info("   - Transcription: \(mealData.transcription)")
                } else {
                    let errorMsg = response.error ?? "Transcription failed"
                    audioRecorder.error = .recordingFailed(errorMsg)
                    logger.error("❌ Gemini transcription failed: \(errorMsg)")
                }
            }

        } catch {
            await MainActor.run {
                isParsing = false

                let errorMsg = error.localizedDescription
                audioRecorder.error = .recordingFailed(errorMsg)
                logger.error("❌ Gemini transcription error: \(errorMsg)")
            }
        }
    }

    private func saveMealEntry() async {
        // VALIDATION 1: Total carbs must be positive
        guard let totalCarbs = Int(editableTotalCarbs), totalCarbs > 0 else {
            await MainActor.run {
                audioRecorder.error = .recordingFailed("Lütfen geçerli bir karbonhidrat değeri girin (0'dan büyük)")
            }
            logger.warning("⚠️ Invalid total carbs value: \(editableTotalCarbs)")
            return
        }

        // VALIDATION 2: At least one food item with non-empty name
        let validFoods = editableFoods.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !validFoods.isEmpty else {
            await MainActor.run {
                audioRecorder.error = .recordingFailed("Lütfen en az bir yiyecek adı girin")
            }
            logger.warning("⚠️ No valid food items found")
            return
        }

        // VALIDATION 3: Check for invalid carbs values in detailed format
        if parsedMealData?.isDetailedFormat == true {
            let hasInvalidCarbs = validFoods.contains { food in
                !food.carbs.isEmpty && food.carbsInt == nil
            }

            if hasInvalidCarbs {
                await MainActor.run {
                    audioRecorder.error = .recordingFailed("Lütfen tüm karbonhidrat değerlerinin sayı olduğundan emin olun")
                }
                logger.warning("⚠️ Invalid carbs values in food items")
                return
            }
        }

        // Use the MealEntryService to save
        let service = MealEntryService()

        do {
            try await service.saveMealEntry(
                totalCarbs: totalCarbs,
                mealType: editableMealType,
                timestamp: editableTimestamp,
                foods: validFoods,  // Use filtered valid foods
                hasInsulin: hasInsulin,
                insulinDosage: editableInsulinDosage,
                insulinType: editableInsulinType,
                insulinName: editableInsulinName,
                viewContext: viewContext
            )

            // Success
            await MainActor.run {
                logger.info("✅ Saved meal entry: \(totalCarbs)g carbs, \(editableMealType)")
                hapticManager.notification(.success)

                // Show success toast
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingSaveConfirmation = true
                }

                // Auto-dismiss toast and view
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingSaveConfirmation = false
                    }
                    // Dismiss view after toast disappears
                    try? await Task.sleep(for: .seconds(0.3))
                    dismiss()
                }
            }
        } catch {
            // Error
            await MainActor.run {
                logger.error("Failed to save meal entry: \(error.localizedDescription)")
                audioRecorder.error = .recordingFailed("Öğün kaydedilemedi: \(error.localizedDescription)")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Parse time string in HH:MM format to Date (today with that time)
    private func parseTimeString(_ timeString: String) -> Date? {
        let components = timeString.split(separator: ":").map { String($0) }
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              hour >= 0, hour < 24,
              minute >= 0, minute < 60 else {
            return nil
        }

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute

        return calendar.date(from: dateComponents)
    }

    /// Adjust carbs by a specific amount (±5g increments)
    private func adjustCarbs(by amount: Int) {
        let currentCarbs = Int(editableTotalCarbs) ?? 0
        let newCarbs = max(0, currentCarbs + amount)
        editableTotalCarbs = "\(newCarbs)"
    }

    // Logger
    private let logger = Logger(subsystem: "com.balli.diabetes", category: "VoiceInputView")
}

// MARK: - Editable Food Item

// MARK: - Preview

#Preview {
    VoiceInputView()
        .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
