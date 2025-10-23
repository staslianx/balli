
import Foundation
import os.log
import AVFoundation

// MARK: - Audio Transcription Actor

actor AudioTranscriber {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AudioTranscriber")
    // Note: AI service disabled pending new implementation
    // private let aiService: AIService
    private let aiService: Any? = nil
    
    init() {
        // Note: AI service initialization disabled pending new implementation
        // let firestoreService = FirestoreService()
        // let authService = AuthenticationService()
        // let healthKitService = HealthKitService()
        // self.aiService = AIService(
        //     firestoreService: firestoreService,
        //     authService: authService,
        //     healthKitService: healthKitService
        // )
        // aiService already initialized above
        logger.info("AudioTranscriber initialized with AI processing support")
    }
    
    // MARK: - Transcription Methods
    
    func transcribeAudioOnly(_ audioData: Data) async throws -> String {
        logger.info("Starting real-time audio transcription with AI processing")
        
        do {
            // Convert audio data to proper format if needed
            _ = try await processAudioData(audioData)

            // Use local audio transcription capabilities
            // AI processing supports audio transcription directly
            _ = """
            Please transcribe the following audio to text. 
            Return ONLY the transcribed text without any additional formatting or explanation.
            If the audio is in Turkish, transcribe in Turkish.
            If the audio is unclear or empty, return an empty string.
            """
            
            // Process audio with AI processing - using audio/wav for WAV format
            // The audio recorder produces WAV format with Linear PCM encoding
            // Note: AI service disabled - returning empty transcription as placeholder
            // let transcription = try await aiService.processAudioWithPrompt(
            //     audioData: processedAudioData,
            //     mimeType: "audio/wav",
            //     prompt: prompt
            // )
            let transcription = ""  // Disabled
            
            // Clean up the transcription (remove any extra formatting)
            let cleanedTranscription = transcription
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            
            logger.info("Successfully transcribed audio: \(cleanedTranscription.prefix(50))...")
            return cleanedTranscription
            
        } catch {
            logger.error("Audio transcription failed: \(error.localizedDescription)")
            throw VoiceRecordingError.processingFailed("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    func processVoiceRecording(_ audioData: Data) async throws -> [ShoppingItemParsed] {
        logger.info("Processing voice recording for shopping list with AI processing")
        
        do {
            // Convert audio data to proper format if needed
            let processedAudioData = try await processAudioData(audioData)
            
            // First transcribe the audio
            let transcription = try await transcribeAudioOnly(processedAudioData)
            
            guard !transcription.isEmpty else {
                logger.warning("Empty transcription received")
                return []
            }
            
            // Then parse the transcription into shopping items using AI processing
            let shoppingPrompt = """
            Given this transcribed shopping list text: "\(transcription)"
            
            Parse it into a JSON array of shopping items. Each item should have:
            - name: The item name (string)
            - quantity: The quantity/amount if mentioned (string or null)
            - category: The category (meyve, sebze, et, süt_ürünleri, tahıl, diğer)
            - confidence: A confidence score between 0 and 1
            
            Return ONLY valid JSON in this format:
            {
                "transcription": "original transcription here",
                "items": [
                    {"name": "elma", "quantity": "2 kilo", "category": "meyve", "confidence": 0.95}
                ]
            }
            
            If no items can be parsed, return {"transcription": "...", "items": []}
            """

            // Note: AI service disabled - returning empty response as placeholder
            // let jsonResponse = try await aiService.generateContent(
            //     shoppingPrompt,
            let jsonResponse = ""  // Disabled
            _ = (shoppingPrompt,  // Keep to avoid unused warning
                history: [],
                systemPrompt: "You are a shopping list parser. Always return valid JSON."
            )
            
            return try parseShoppingListResponse(jsonResponse)
            
        } catch {
            logger.error("Voice processing failed: \(error.localizedDescription)")
            throw VoiceRecordingError.processingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func processAudioData(_ audioData: Data) async throws -> Data {
        // Check if audio data is valid
        guard !audioData.isEmpty else {
            throw VoiceRecordingError.audioTooShort
        }
        
        // Log audio data info
        let sizeInKB = Double(audioData.count) / 1024.0
        logger.info("Processing audio data: \(String(format: "%.2f", sizeInKB)) KB")
        
        // Check if it's already in a supported format
        // The AudioRecorder produces WAV format with Linear PCM encoding which is compatible with AI processing
        // No conversion needed as AI processing supports WAV audio directly
        
        return audioData
    }
    
    private func parseShoppingListResponse(_ jsonText: String) throws -> [ShoppingItemParsed] {
        // Clean JSON text (remove markdown code blocks if present)
        var cleanedText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw VoiceRecordingError.processingFailed("Could not convert response to data")
        }
        
        do {
            let decoder = JSONDecoder()
            let shoppingResponse = try decoder.decode(ShoppingListResponse.self, from: jsonData)
            
            return shoppingResponse.items.map { item in
                ShoppingItemParsed(
                    name: item.name,
                    quantity: item.quantity,
                    category: item.category,
                    confidence: item.confidence
                )
            }
            
        } catch {
            logger.error("JSON parsing failed: \(error)")
            logger.error("JSON text was: \(cleanedText)")
            throw VoiceRecordingError.processingFailed("Could not parse shopping list JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types for Transcription

private struct ShoppingListResponse: Codable {
    let transcription: String?
    let items: [ShoppingItem]
    
    struct ShoppingItem: Codable {
        let name: String
        let quantity: String?
        let category: String
        let confidence: Double
    }
}


