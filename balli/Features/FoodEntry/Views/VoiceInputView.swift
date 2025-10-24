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
    @State private var editableMealType: String = "atıştırmalık"
    @State private var editableMealTime: String = ""

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
        .onDisappear {
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

                        Text("Gemini ile analiz ediliyor...")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResponsiveDesign.height(80))
                } else if !audioRecorder.isRecording {
                    // Placeholder when not recording
                    VStack(spacing: ResponsiveDesign.Spacing.small) {
                        if !audioRecorder.microphonePermissionGranted {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.red)

                            Text("Mikrofon İzni Gerekli")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)

                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text("Mikrofon izni")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.system(size: 13, weight: .regular, design: .rounded))
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
                        } else {
                            Image(systemName: "waveform.low")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.3))

                            Text("Kayıt için dokunun")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResponsiveDesign.height(80))
                } else {
                    // Recording in progress
                    VStack(spacing: ResponsiveDesign.Spacing.large) {
                        // Audio waveform visualization
                        VoiceGlowView(audioLevel: audioRecorder.audioLevel)
                            .frame(height: 200)

                        // Recording indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                                .opacity(pulseAnimation ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)

                            Text("Kaydediliyor...")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        // Duration
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, ResponsiveDesign.height(60))
                }
            })
        }
    }

    // MARK: - Meal Preview (Editable)

    @ViewBuilder
    private func mealPreviewView(_ data: ParsedMealData) -> some View {
        ScrollView {
            VStack(spacing: ResponsiveDesign.Spacing.medium) {
                // Show transcription if Gemini format
                if let transcription = data.transcription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Söylediğiniz:")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(transcription)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                // EDITABLE Foods Array
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yiyecekler")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    ForEach($editableFoods) { $food in
                        VStack(spacing: 8) {
                            // Food name
                            HStack {
                                Text("İsim:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                TextField("Yiyecek adı", text: $food.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Amount
                            HStack {
                                Text("Miktar:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                TextField("Örn: 2 adet, 1 dilim", text: $food.amount)
                                    .font(.system(size: 14, design: .rounded))
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Per-item carbs (if detailed format)
                            if data.isDetailedFormat {
                                HStack {
                                    Text("Karb:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    TextField("0", text: $food.carbs)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)

                                    Text("gram")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }

                    // Add food button
                    Button {
                        editableFoods.append(EditableFoodItem(name: "", amount: nil, carbs: nil))
                    } label: {
                        Label("Yiyecek Ekle", systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // EDITABLE Total Carbs
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toplam Karbonhidrat")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack {
                        TextField("0", text: $editableTotalCarbs)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        Text("gram")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // EDITABLE Meal Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Öğün Türü")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Picker("Öğün", selection: $editableMealType) {
                        Text("Kahvaltı").tag("kahvaltı")
                        Text("Öğle Yemeği").tag("öğle yemeği")
                        Text("Akşam Yemeği").tag("akşam yemeği")
                        Text("Atıştırmalık").tag("atıştırmalık")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // EDITABLE Meal Time (optional)
                if !editableMealTime.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saat (opsiyonel)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        TextField("HH:MM", text: $editableMealTime)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Confidence warning
                if let confidence = data.confidence, confidence != "high" {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Bazı bilgiler tahmin edildi, lütfen kontrol edin")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.top, ResponsiveDesign.Spacing.large)
        }
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
                if audioRecorder.isRecording {
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
                Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.primaryPurple)
                    .symbolEffect(.bounce, value: audioRecorder.isRecording)
            }
            .frame(width: 75, height: 75)
            .background(Color.clear)
            .clipShape(Circle())
            .glassEffect(.regular.interactive(), in: Circle())
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

                    // Populate editable fields for user corrections
                    editableFoods = mealData.foods.map { food in
                        EditableFoodItem(
                            name: food.name,
                            amount: food.amount,
                            carbs: food.carbs
                        )
                    }
                    editableTotalCarbs = "\(mealData.totalCarbs)"
                    editableMealType = mealData.mealType
                    editableMealTime = mealData.mealTime ?? ""

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
        // Use edited values from user
        guard let totalCarbs = Int(editableTotalCarbs), totalCarbs > 0 else {
            logger.warning("⚠️ Invalid total carbs value: \(editableTotalCarbs)")
            return
        }

        // Create a background context for async CoreData operations
        guard let coordinator = viewContext.persistentStoreCoordinator else {
            logger.error("Failed to get persistent store coordinator")
            return
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // Capture edited values - these are Sendable value types
        let carbsValue = totalCarbs
        let mealTypeText = editableMealType
        let timeText = editableMealTime

        // Parse time if provided
        let timestamp: Date
        if !timeText.isEmpty, let parsedTime = parseTimeString(timeText) {
            timestamp = parsedTime
        } else {
            timestamp = parsedMealData?.timestamp ?? Date()
        }

        // Convert editable foods to array
        let foodsArray = editableFoods.filter { !$0.name.isEmpty }
        let isGeminiFormat = !foodsArray.isEmpty

        // Perform CoreData operations on background context
        do {
            try await context.perform {
                if isGeminiFormat {
                    // GEMINI FORMAT: Create separate MealEntry for each food item (using edited values)
                    for (index, editableFood) in foodsArray.enumerated() {
                        // Create FoodItem
                        let foodItem = FoodItem(context: context)
                        foodItem.id = UUID()
                        foodItem.name = editableFood.name
                        foodItem.nameTr = editableFood.name

                        // Set nutrition (from edited carbs)
                        if let itemCarbs = editableFood.carbsInt {
                            foodItem.totalCarbs = Double(itemCarbs)
                        } else {
                            // For simple format, don't set carbs on individual items
                            foodItem.totalCarbs = 0
                        }

                        // Parse amount if possible (from edited amount)
                        let amountText = editableFood.amount
                        if !amountText.isEmpty {
                            let components = amountText.split(separator: " ")
                            if let firstNum = components.first, let value = Double(firstNum) {
                                foodItem.servingSize = value
                                foodItem.servingUnit = components.dropFirst().joined(separator: " ")
                            } else {
                                foodItem.servingSize = 1.0
                                foodItem.servingUnit = amountText
                            }
                        } else {
                            foodItem.servingSize = 1.0
                            foodItem.servingUnit = "porsiyon"
                        }

                        foodItem.gramWeight = foodItem.totalCarbs
                        foodItem.source = "voice-gemini"
                        foodItem.dateAdded = Date()
                        foodItem.lastUsed = Date()
                        foodItem.useCount = 1

                        // Create MealEntry
                        let mealEntry = MealEntry(context: context)
                        mealEntry.id = UUID()
                        mealEntry.timestamp = timestamp
                        mealEntry.mealType = mealTypeText
                        mealEntry.foodItem = foodItem
                        mealEntry.quantity = 1.0
                        mealEntry.unit = "porsiyon"

                        // Calculate and set nutrition
                        mealEntry.calculateNutrition()

                        // For first entry in simple format (no per-item carbs), store total carbs
                        let isSimpleFormat = foodsArray.allSatisfy { $0.carbsInt == nil }
                        if index == 0 && isSimpleFormat {
                            mealEntry.consumedCarbs = Double(carbsValue)
                        }
                    }
                } else {
                    // LEGACY FORMAT: Single entry (backward compatible)
                    let foodItem = FoodItem(context: context)
                    foodItem.id = UUID()
                    foodItem.name = "Sesli Giriş: \(mealTypeText.capitalized)"
                    foodItem.nameTr = "Sesli Giriş: \(mealTypeText.capitalized)"
                    foodItem.totalCarbs = Double(carbsValue)
                    foodItem.servingSize = 1.0
                    foodItem.servingUnit = "porsiyon"
                    foodItem.gramWeight = Double(carbsValue)
                    foodItem.source = "voice-gemini"
                    foodItem.dateAdded = Date()
                    foodItem.lastUsed = Date()
                    foodItem.useCount = 1

                    let mealEntry = MealEntry(context: context)
                    mealEntry.id = UUID()
                    mealEntry.timestamp = timestamp
                    mealEntry.mealType = mealTypeText
                    mealEntry.foodItem = foodItem
                    mealEntry.quantity = 1.0
                    mealEntry.unit = "porsiyon"
                    mealEntry.calculateNutrition()
                    mealEntry.consumedCarbs = Double(carbsValue)
                }

                // Save on background thread
                try context.save()
            }

            // Success
            await MainActor.run {
                logger.info("✅ Saved meal entry: \(carbsValue)g carbs, \(mealTypeText)")
                hapticManager.notification(.success)
                dismiss()
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

    // Logger
    private let logger = Logger(subsystem: "com.balli.diabetes", category: "VoiceInputView")
}

// MARK: - Editable Food Item

/// Editable version of food item for user corrections
struct EditableFoodItem: Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var carbs: String  // String for TextField

    init(id: UUID = UUID(), name: String, amount: String?, carbs: Int?) {
        self.id = id
        self.name = name
        self.amount = amount ?? ""
        self.carbs = carbs != nil ? "\(carbs!)" : ""
    }

    /// Convert to Int for saving
    var carbsInt: Int? {
        Int(carbs)
    }
}

// MARK: - Preview

#Preview {
    VoiceInputView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
