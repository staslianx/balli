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

struct GlassTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func glassTextField() -> some View {
        modifier(GlassTextFieldStyle())
    }
}

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

    // Editable insulin data
    @State private var editableInsulinDosage: Double = 0
    @State private var editableInsulinType: String? = nil
    @State private var editableInsulinName: String? = nil
    @State private var hasInsulin: Bool = false

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
            // Processing state - "Notumu alıyorum" centered with icon
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "long.text.page.and.pencil.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeat(.continuous))

                    Text("Notumu alıyorum")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !audioRecorder.isRecording {
            // Placeholder when not recording
            VStack {
                Spacer()

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

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Recording in progress - "Dinliyorum" with waveform icon
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryPurple)
                        .symbolEffect(.variableColor)

                    Text("Dinliyorum")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryPurple)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Meal Preview (Editable)

    @ViewBuilder
    private func mealPreviewView(_ data: ParsedMealData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // TOP ROW: Meal Type (left) and Carb Stepper (right)
                HStack(alignment: .top, spacing: 16) {
                    // EDITABLE Meal Type Picker - LEFT SIDE
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Öğün Türü")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Picker("Öğün", selection: $editableMealType) {
                            Text("Kahvaltı").tag("kahvaltı")
                            Text("Ara Öğün").tag("ara öğün")
                            Text("Akşam Yemeği").tag("akşam yemeği")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // EDITABLE Total Carbs with Stepper - RIGHT SIDE
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Karbonhidrat")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            // Decrease button
                            Button {
                                adjustCarbs(by: -5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .buttonStyle(.plain)

                            // Carb value
                            TextField("0", text: $editableTotalCarbs)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                .glassTextField()
                                .frame(width: 70)
                                .multilineTextAlignment(.center)

                            Text("g")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            // Increase button
                            Button {
                                adjustCarbs(by: 5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(AppTheme.primaryPurple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // EDITABLE Foods Array
                VStack(alignment: .leading, spacing: 16) {
                    Text("Yiyecekler")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    ForEach($editableFoods) { $food in
                        VStack(spacing: 12) {
                            // Food name
                            HStack {
                                Text("İsim:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                TextField("Yiyecek adı", text: $food.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .glassTextField()
                            }

                            // Amount
                            HStack {
                                Text("Miktar:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                TextField("Örn: 2 adet, 1 dilim", text: $food.amount)
                                    .font(.system(size: 14, design: .rounded))
                                    .glassTextField()
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
                                        .glassTextField()
                                        .frame(width: 80)

                                    Text("gram")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
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

                // INSULIN SECTION (if insulin was detected or user wants to add)
                if hasInsulin {
                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("İnsülin")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                hasInsulin = false
                                editableInsulinDosage = 0
                            } label: {
                                Label("Kaldır", systemImage: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 16) {
                            // Insulin dosage stepper
                            HStack {
                                Text("Doz:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                Spacer()

                                // Decrease button
                                Button {
                                    editableInsulinDosage = max(0, editableInsulinDosage - 0.5)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)

                                // Dosage value
                                Text("\(editableInsulinDosage, specifier: "%.1f")")
                                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                    .frame(width: 70)

                                Text("ünite")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)

                                // Increase button
                                Button {
                                    editableInsulinDosage += 0.5
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(AppTheme.primaryPurple)
                                }
                                .buttonStyle(.plain)
                            }

                            // Insulin type display (if detected)
                            if let insulinName = editableInsulinName {
                                HStack {
                                    Text("İsim:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    Text(insulinName)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if let insulinType = editableInsulinType {
                                        Text(insulinType == "bolus" ? "Hızlı Etkili" : "Uzun Etkili")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(insulinType == "bolus" ? AppTheme.primaryPurple : .blue)
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.primaryPurple.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else {
                    // Button to add insulin manually
                    Button {
                        hasInsulin = true
                        editableInsulinDosage = 5.0 // Default starting value
                    } label: {
                        Label("İnsülin Ekle", systemImage: "plus.circle")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }

                // EDITABLE Timestamp
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tarih ve Saat")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    DatePicker(
                        "Öğün zamanı",
                        selection: $editableTimestamp,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // Confidence warning
                if let confidence = data.confidence, confidence != "high" {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Bazı bilgileri tahmin ettim, lütfen kontrol et")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)
                }

                // Show transcription at the BOTTOM
                if let transcription = data.transcription {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Söylediğiniz:")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(transcription)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .italic()
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
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

                    // Populate editable fields for user corrections
                    // Auto-capitalize first letter of food names
                    editableFoods = mealData.foods.map { food in
                        let capitalizedName = food.name.isEmpty ? "" : food.name.prefix(1).uppercased() + food.name.dropFirst()
                        return EditableFoodItem(
                            name: capitalizedName,
                            amount: food.amount,
                            carbs: food.carbs
                        )
                    }
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
                        editableInsulinDosage = insulinDosage
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

        // Use the editable timestamp (user may have changed it)
        let timestamp = editableTimestamp

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

                // CREATE INSULIN MEDICATION ENTRY (if insulin was specified)
                if hasInsulin && editableInsulinDosage > 0 {
                    // Capture insulin values
                    let insulinDosage = editableInsulinDosage
                    let insulinType = editableInsulinType
                    let insulinName = editableInsulinName

                    // Get the first meal entry for relationship (bolus insulin is linked to meals)
                    let mealEntries = try context.fetch(MealEntry.fetchRequest()) as [MealEntry]
                    let firstMealEntry = mealEntries.filter { $0.timestamp == timestamp }.first

                    // Create MedicationEntry
                    let medication = MedicationEntry(context: context)
                    medication.id = UUID()
                    medication.timestamp = timestamp
                    medication.dosage = insulinDosage
                    medication.dosageUnit = "ünite"

                    // Set medication name and type
                    if let name = insulinName {
                        medication.medicationName = name
                    } else {
                        // Default names based on type
                        medication.medicationName = insulinType == "basal" ? "Bazal İnsülin" : "Bolus İnsülin"
                    }

                    // Determine medication type
                    if let type = insulinType {
                        medication.medicationType = type == "basal" ? "basal_insulin" : "bolus_insulin"
                    } else {
                        // If type not specified, assume bolus if connected to meal, basal otherwise
                        medication.medicationType = firstMealEntry != nil ? "bolus_insulin" : "basal_insulin"
                    }

                    medication.administrationRoute = "subcutaneous"
                    medication.timingRelation = firstMealEntry != nil ? "with_meal" : "standalone"
                    medication.isScheduled = false
                    medication.dateAdded = Date()
                    medication.lastModified = Date()
                    medication.source = "voice-gemini"
                    medication.glucoseAtTime = 0 // Could be set if we have current glucose

                    // Link to meal entry if this is bolus insulin
                    if medication.medicationType == "bolus_insulin", let mealEntry = firstMealEntry {
                        medication.mealEntry = mealEntry
                    }

                    logger.info("💉 Created insulin medication: \(medication.medicationName) \(insulinDosage) units")
                }

                // Save on background thread
                try context.save()
            }

            // CRITICAL: Merge changes from private context into viewContext
            // This ensures the glucose chart immediately receives the meal markers
            await MainActor.run {
                viewContext.performAndWait {
                    viewContext.mergeChanges(fromContextDidSave: Notification(
                        name: .NSManagedObjectContextDidSave,
                        object: context,
                        userInfo: [
                            NSInsertedObjectsKey: context.insertedObjects,
                            NSUpdatedObjectsKey: context.updatedObjects,
                            NSDeletedObjectsKey: context.deletedObjects
                        ]
                    ))
                }
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
        self.carbs = carbs.map { "\($0)" } ?? ""
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
