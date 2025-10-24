# Voice Meal Logging with Gemini 2.5 Flash Audio Transcription

## Overview
THIS IS AN UPDATED VERSION OF THE CURRENT MEAL LOG FEATURE WHERE USER TAPS THE PLUS BUTTON ON hosgeldinView and logs her meal.USE THIS SPEC TO UPDATE THAT.
Implement voice-based meal logging that uses Gemini 2.5 Flash to transcribe Turkish audio and extract structured meal data in a single API call. This replaces the current Apple Speech Recognition approach with a more accurate and intelligent solution.

## Problem Statement
Current meal logging uses Apple's Speech Recognition for Turkish, which has poor accuracy. Users must speak in a rigid format, and the system cannot extract food descriptions - only carb amounts and meal types. We need natural language processing that can handle casual Turkish speech and extract complete meal information including what was eaten.

## Solution: Gemini 2.5 Flash Audio Processing

### Why Gemini 2.5 Flash?
- Native audio input support (no separate transcription step needed)
- Improved Turkish language understanding
- Better at extracting structured data from natural speech
- Can handle variations in how users describe meals
- Single API call for transcription + parsing = faster, simpler

## Technical Architecture

### Current Flow (Apple Speech)
1. User taps mic button in iOS app
2. iOS records audio using Apple Speech Recognition
3. Transcribed text sent to backend
4. Backend parses for carbs and meal type only
5. Missing: actual food description

### New Flow (Gemini 2.5 Flash)
1. User taps mic button in iOS app
2. iOS records audio file (AVAudioRecorder)
3. Audio file sent to Cloud Function
4. Cloud Function sends audio to Gemini 2.5 Flash with structured prompt
5. Gemini returns: transcription + extracted fields (food name, carbs, meal type, time)
6. Cloud Function returns JSON to iOS app
7. iOS shows confirmation screen with all fields pre-filled
8. User confirms or edits
9. Save to Core Data

## Data Structure

### Input (from iOS to Cloud Function)
```typescript
{
  audioData: string,        // Base64-encoded audio file
  mimeType: string,         // "audio/m4a" or "audio/mp4" (iOS default)
  userId: string,           // For authentication
  currentTime: string       // ISO8601 timestamp as fallback
}
```

### Output (from Cloud Function to iOS)
```typescript
{
  success: boolean,
  data: {
    transcription: string,      // Full transcribed text
    foods: Array<{              // Array of food items
      name: string,             // Food name (e.g., "yumurta", "tam buğday ekmek")
      amount: string | null,    // Amount/portion (e.g., "2 adet", "1 dilim", null)
      carbs: number | null      // Carbs for this item if specified, otherwise null
    }>,
    totalCarbs: number,         // Total carbs (either sum of items or overall amount)
    mealType: string,           // "kahvaltı" | "öğle yemeği" | "akşam yemeği" | "atıştırmalık"
    mealTime: string | null,    // "HH:MM" format if mentioned, otherwise null
    confidence: string          // "high" | "medium" | "low"
  },
  error?: string
}
```

**Note on foods array:**
- Can contain single or multiple items
- If user specifies carbs per item: each item has `carbs` value
- If user gives total only: items have `carbs: null`, total in `totalCarbs`
- Gemini determines structure based on natural speech pattern

## Implementation Details

### Cloud Function: `transcribeMeal`

**Location:** `/functions/src/transcribeMeal.ts`

**Method:** POST

**Authentication:** Firebase Auth token required

**Input validation:**
- audioData must be present and valid base64
- mimeType must be audio format
- Audio file size limit: 20MB (Gemini inline data limit)
- If larger, use Files API (but unlikely for meal logging)

**Gemini 2.5 Flash Integration:**

```typescript
import { GoogleGenerativeAI } from "@google/generative-ai";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

// Prompt structure
const prompt = `Bu Türkçe ses kaydını dinle ve öğün bilgilerini çıkar.

Kullanıcı doğal bir şekilde konuşuyor. İki farklı şekilde konuşabilir:

TİP 1 - Basit format (toplam karbonhidrat):
"yumurta yedim, peynir yedim, domates yedim, toplam 30 gram karbonhidrat"
→ Yiyecekleri listele, toplam karbonhidratı kaydet

TİP 2 - Detaylı format (her yiyecek için ayrı):
"2 yumurta bu 10 gram karbonhidrat, ekmek 20 gram karbonhidrat"
→ Her yiyecek için ayrı karbonhidrat değeri kaydet

Kullanıcı hangi formatta konuşursa konuşsun, doğal konuşmayı anla ve yapılandır.

Diğer örnekler:
- "menemen yaptım sabah, otuz gram karbonhidrat falan"
- "öğlen tavuklu salata yedim 25 gram karb"
- "2 dilim ekmek yedim bu 15 gram, yumurta 2 tane o da 10 gram"
- "makarna yaptım, yoğurt yedim, meyve salatası yedim, 60 gram toplam"

Şu bilgileri çıkar:
{
  "transcription": "Kullanıcının söylediği tam metin",
  "foods": [
    {
      "name": "yiyecek adı",
      "amount": "miktar belirtildiyse (2 adet, 1 dilim, 100 gram, vb.), yoksa null",
      "carbs": "bu yiyecek için özel karbonhidrat belirtildiyse sayı, yoksa null"
    }
  ],
  "totalCarbs": "toplam karbonhidrat (sayı)",
  "mealType": "kahvaltı" | "öğle yemeği" | "akşam yemeği" | "atıştırmalık",
  "mealTime": "belirtilen saat varsa HH:MM formatında, yoksa null",
  "confidence": "çıkarım güvenilirliği - high, medium, veya low"
}

ÖNEMLI:
- Eğer kullanıcı her yiyecek için ayrı karbonhidrat söylediyse, foods array'indeki her item'ın carbs değeri olmalı
- Eğer sadece toplam karbonhidrat söylediyse, foods array'indeki carbs değerleri null olmalı
- totalCarbs her zaman dolu olmalı (ya toplam, ya da items'ların toplamı)
- Eğer karbonhidrat hiç belirtilmediyse totalCarbs = 0 ve confidence = "low"

JSON formatında dön.`;

// Generate content with audio
const result = await model.generateContent([
  {
    inlineData: {
      data: audioBase64String,
      mimeType: mimeType
    }
  },
  prompt
]);

const responseText = result.response.text();
const parsedData = JSON.parse(responseText);
```

### Error Handling

**Gemini API Errors:**
- Rate limit exceeded → Return error with retry suggestion
- Audio format not supported → Return error asking for different format
- Audio too long/large → Return error with size limit info
- Invalid API key → Log error, return generic error to user

**Parsing Errors:**
- Cannot extract any foods → Set foods to empty array and confidence to "low"
- Cannot extract totalCarbs → Set to 0 and confidence to "low"
- Cannot extract mealType → Try to infer from time or food type, otherwise set to "atıştırmalık"
- Malformed JSON response → Retry once, if fails return transcription only with empty foods array

**Validation:**
- totalCarbs must be 0-500 (sanity check)
- If foods array has carbs per item, sum must equal totalCarbs (±5g tolerance)
- mealTime must be valid HH:MM format
- mealType must be one of the four options
- Each food item must have a name (required)

### iOS Implementation Notes

**Recording Audio:**
```swift
// Use AVAudioRecorder to save audio file
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.record, mode: .default)
try audioSession.setActive(true)

let settings = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
]

let recorder = try AVAudioRecorder(url: audioURL, settings: settings)
recorder.record()
```

**Sending to Cloud Function:**
```swift
// Convert audio file to base64
let audioData = try Data(contentsOf: audioURL)
let base64Audio = audioData.base64EncodedString()

// Call Cloud Function
let requestBody = [
    "audioData": base64Audio,
    "mimeType": "audio/m4a",
    "userId": currentUserId,
    "currentTime": ISO8601DateFormatter().string(from: Date())
]

// Make HTTP request to Cloud Function endpoint
```

**Confirmation Screen:**
```swift
struct MealConfirmationView: View {
    @State var foods: [FoodItem]  // Array of food items
    @State var totalCarbs: String
    @State var mealType: String
    @State var mealTime: String?

    let transcription: String
    let confidence: String

    var body: some View {
        VStack(spacing: 16) {
            // Show transcription at top for context
            Text("Söylediğiniz: \(transcription)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()

            // Foods list (editable)
            VStack(alignment: .leading, spacing: 12) {
                Text("Yiyecekler")
                    .font(.headline)

                ForEach(foods.indices, id: \.self) { index in
                    HStack {
                        // Food name and amount
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Yiyecek", text: $foods[index].name)
                                .font(.body)

                            if let amount = foods[index].amount {
                                Text(amount)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Carbs for this item (if detailed format)
                        if foods[index].carbs != nil {
                            HStack(spacing: 4) {
                                TextField("", value: $foods[index].carbs, format: .number)
                                    .keyboardType(.numberPad)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.trailing)
                                Text("g")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Add food button
                Button(action: {
                    foods.append(FoodItem(name: "", amount: nil, carbs: nil))
                }) {
                    Label("Yiyecek Ekle", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Divider()

            // Total carbs (always editable)
            HStack {
                Text("Toplam Karbonhidrat")
                    .font(.headline)
                Spacer()
                TextField("", text: $totalCarbs)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text("gram")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Meal type picker
            Picker("Öğün", selection: $mealType) {
                Text("Kahvaltı").tag("kahvaltı")
                Text("Öğle").tag("öğle yemeği")
                Text("Akşam").tag("akşam yemeği")
                Text("Atıştırmalık").tag("atıştırmalık")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Meal time (if specified)
            if let time = mealTime {
                HStack {
                    Text("Saat")
                    Spacer()
                    TextField("", text: Binding(
                        get: { time },
                        set: { mealTime = $0 }
                    ))
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal)
            }

            // Confidence warning
            if confidence != "high" {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Bazı bilgiler tahmin edildi, kontrol edin")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 16) {
                Button("İptal") {
                    // Dismiss without saving
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button("Kaydet") {
                    // Validate and save to Core Data
                    saveMeal()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding(.top)
    }

    private func saveMeal() {
        // Combine foods into storage format
        // If detailed format (items have carbs), store as separate linked entries
        // If simple format (no item carbs), store as single combined entry
        // Save to Core Data with totalCarbs and mealType
    }
}

struct FoodItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: String?
    var carbs: Int?
}
```

**Display Logic:**
- If all foods have `carbs: null` → Simple format, show combined list with total
- If foods have individual `carbs` values → Detailed format, show per-item carbs
- User can always edit everything before saving
- Can add more food items manually via "+ Yiyecek Ekle" button

## Natural Language Examples

Users can speak naturally in two main patterns. Gemini adapts to either format automatically.

### Pattern 1: Simple Combined Format (Total Carbs Only)

**Example 1a: Single food with total**
```
User: "menemen yaptım, 30 gram karbonhidrat, kahvaltı"

Expected output:
{
  "transcription": "menemen yaptım 30 gram karbonhidrat kahvaltı",
  "foods": [
    {
      "name": "menemen",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 30,
  "mealType": "kahvaltı",
  "mealTime": null,
  "confidence": "high"
}
```

**Example 1b: Multiple foods with total**
```
User: "tam buğday makarna, yoğurt, meyve salatası yedim, toplam 60 gram karbonhidrat"

Expected output:
{
  "transcription": "tam buğday makarna yoğurt meyve salatası yedim toplam 60 gram karbonhidrat",
  "foods": [
    {
      "name": "tam buğday makarna",
      "amount": null,
      "carbs": null
    },
    {
      "name": "yoğurt",
      "amount": null,
      "carbs": null
    },
    {
      "name": "meyve salatası",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 60,
  "mealType": "öğle yemeği",  // Inferred
  "mealTime": null,
  "confidence": "high"
}
```

**Example 1c: With portions but no individual carbs**
```
User: "2 yumurta yedim, sonra iki dilim tam buğday ekmek yedim, hellim peyniri yedim, toplam 25 gram"

Expected output:
{
  "transcription": "2 yumurta yedim sonra iki dilim tam buğday ekmek yedim hellim peyniri yedim toplam 25 gram",
  "foods": [
    {
      "name": "yumurta",
      "amount": "2 adet",
      "carbs": null
    },
    {
      "name": "tam buğday ekmek",
      "amount": "2 dilim",
      "carbs": null
    },
    {
      "name": "hellim peyniri",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 25,
  "mealType": "kahvaltı",  // Inferred from foods
  "mealTime": null,
  "confidence": "high"
}
```

### Pattern 2: Detailed Per-Item Format (Individual Carbs)

**Example 2a: Explicit carbs per item**
```
User: "2 dilim tam buğday ekmeği bu 15 gram karbonhidrat, 2 yumurta o da 10 gram, hellim peyniri onu saymıyoruz zaten"

Expected output:
{
  "transcription": "2 dilim tam buğday ekmeği bu 15 gram karbonhidrat 2 yumurta o da 10 gram hellim peyniri onu saymıyoruz",
  "foods": [
    {
      "name": "tam buğday ekmek",
      "amount": "2 dilim",
      "carbs": 15
    },
    {
      "name": "yumurta",
      "amount": "2 adet",
      "carbs": 10
    },
    {
      "name": "hellim peyniri",
      "amount": null,
      "carbs": 0
    }
  ],
  "totalCarbs": 25,  // Sum of individual items
  "mealType": "kahvaltı",
  "mealTime": null,
  "confidence": "high"
}
```

**Example 2b: Mixed - some with carbs, some without**
```
User: "makarna yedim 45 gram karbonhidrat, cacık yedim onda yok, salata da yok"

Expected output:
{
  "transcription": "makarna yedim 45 gram karbonhidrat cacık yedim onda yok salata da yok",
  "foods": [
    {
      "name": "makarna",
      "amount": null,
      "carbs": 45
    },
    {
      "name": "cacık",
      "amount": null,
      "carbs": 0
    },
    {
      "name": "salata",
      "amount": null,
      "carbs": 0
    }
  ],
  "totalCarbs": 45,
  "mealType": "akşam yemeği",
  "mealTime": null,
  "confidence": "high"
}
```

### Pattern 3: Edge Cases

**Example 3a: Very casual and incomplete**
```
User: "bugün öğlen tavuklu salata yedim, 25 gram karb falan"

Expected output:
{
  "transcription": "bugün öğlen tavuklu salata yedim 25 gram karb falan",
  "foods": [
    {
      "name": "tavuklu salata",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 25,
  "mealType": "öğle yemeği",
  "mealTime": null,
  "confidence": "high"
}
```

**Example 3b: No carbs mentioned at all**
```
User: "makarna yaptım akşam, karbonhidrat bilmiyorum ama çok değil"

Expected output:
{
  "transcription": "makarna yaptım akşam karbonhidrat bilmiyorum ama çok değil",
  "foods": [
    {
      "name": "makarna",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 0,  // User doesn't know
  "mealType": "akşam yemeği",
  "mealTime": null,
  "confidence": "low"
}
```

**Example 3c: With specific time**
```
User: "sabah saat dokuz buçukta menemen yaptım, 30 gram karbonhidrat"

Expected output:
{
  "transcription": "sabah saat dokuz buçukta menemen yaptım 30 gram karbonhidrat",
  "foods": [
    {
      "name": "menemen",
      "amount": null,
      "carbs": null
    }
  ],
  "totalCarbs": 30,
  "mealType": "kahvaltı",
  "mealTime": "09:30",
  "confidence": "high"
}
```

**Example 3d: Very detailed with everything**
```
User: "öğle yemeği saat 13:00'de, tavuk göğsü 150 gram bu 0 karbonhidrat, pilav 1 kase bu 45 gram, salata yedim onda yok"

Expected output:
{
  "transcription": "öğle yemeği saat 13:00'de tavuk göğsü 150 gram bu 0 karbonhidrat pilav 1 kase bu 45 gram salata yedim onda yok",
  "foods": [
    {
      "name": "tavuk göğsü",
      "amount": "150 gram",
      "carbs": 0
    },
    {
      "name": "pilav",
      "amount": "1 kase",
      "carbs": 45
    },
    {
      "name": "salata",
      "amount": null,
      "carbs": 0
    }
  ],
  "totalCarbs": 45,
  "mealType": "öğle yemeği",
  "mealTime": "13:00",
  "confidence": "high"
}
```

### Key Takeaways for Gemini

1. **Flexible structure**: Don't force a format - adapt to user's speech
2. **Natural portions**: Capture "2 adet", "1 dilim", "1 kase" naturally
3. **Smart defaults**: Infer meal type from foods/time when not specified
4. **Handle negatives**: "onu saymıyoruz", "onda yok" = carbs: 0
5. **Casual language**: "falan", "karb", "bi" are all acceptable
6. **Time parsing**: "dokuz buçuk" = "09:30", "saat 13:00" = "13:00"

## Performance Considerations

**Latency:**
- Expected: 2-4 seconds for typical 5-10 second audio clips
- Acceptable: Up to 6 seconds
- If longer: Show progress indicator in iOS

**Cost:**
- Gemini 2.5 Flash pricing:
  - Audio input: $0.50 per million tokens
  - Text output: $0.40 per million tokens
- Typical audio (10 seconds): ~5,000-10,000 audio tokens
- Estimated cost per transcription: $0.005-0.01 (less than 1 cent)

**Optimization:**
- Don't store audio files long-term (delete after processing)
- Use Firebase Cloud Functions with adequate timeout (60s)
- Add retry logic for transient failures
- Cache nothing (each meal is unique)

## Testing Scenarios

### Test Case 1: Simple format - single food
- Input: Clear audio "menemen yedim kahvaltıda 30 gram karbonhidrat"
- Expected: Single food item, totalCarbs = 30, all fields extracted correctly, high confidence

### Test Case 2: Simple format - multiple foods
- Input: "yumurta peynir domates zeytin yedim toplam 25 gram"
- Expected: Four food items in array, all with carbs: null, totalCarbs = 25

### Test Case 3: Detailed format - carbs per item
- Input: "2 yumurta bu 10 gram, ekmek 15 gram karbonhidrat"
- Expected: Two foods with individual carbs (10 and 15), totalCarbs = 25 (sum)

### Test Case 4: Mixed format - some items with carbs
- Input: "makarna 45 gram karbonhidrat, salata, cacık"
- Expected: Makarna has carbs: 45, others have carbs: 0 or null, totalCarbs = 45

### Test Case 5: Portions specified
- Input: "2 dilim ekmek, 1 kase yoğurt yedim, 30 gram"
- Expected: Foods have amount field filled ("2 dilim", "1 kase"), totalCarbs = 30

### Test Case 6: No carbs mentioned
- Input: "tavuk göğsü yedim"
- Expected: Single food, totalCarbs = 0, confidence = low

### Test Case 7: Time in different formats
- Input: "saat dokuz buçukta kahvaltı yaptım"
- Expected: mealTime = "09:30" or null if cannot parse reliably

### Test Case 8: Noisy environment
- Input: Audio with background noise
- Expected: Transcription may be imperfect but still extracts main structure

### Test Case 9: "Not counting" items
- Input: "ekmek 20 gram, salata onu saymıyoruz"
- Expected: Ekmek has carbs: 20, salata has carbs: 0

### Test Case 10: Very detailed complete entry
- Input: "öğle yemeği saat 13:00, tavuk 150 gram 0 karbonhidrat, pilav 1 kase 45 gram"
- Expected: All fields including time and individual carbs correctly extracted

## Migration Plan

### Phase 1: Parallel Implementation
- Keep existing Apple Speech implementation
- Add new Gemini transcription as optional feature
- Add toggle in Settings: "Gelişmiş ses tanıma (Beta)"
- Collect feedback

### Phase 2: Default Switch
- Make Gemini the default
- Keep Apple Speech as fallback
- If Gemini fails, automatically retry with Apple Speech

### Phase 3: Full Migration
- Remove Apple Speech code
- Gemini only

### Rollback Plan
If Gemini proves unreliable:
- Re-enable Apple Speech as primary
- Keep Gemini for non-critical features
- Investigate issues

## Security Considerations

**Audio Privacy:**
- Audio files never stored permanently
- Deleted immediately after processing
- Not logged or backed up
- Firebase Cloud Functions ephemeral storage only

**Authentication:**
- All Cloud Function calls require valid Firebase Auth token
- Verify userId matches authenticated user
- Rate limit per user: 60 requests/hour (prevents abuse)

**API Key Protection:**
- Gemini API key stored in Firebase Functions environment variables
- Never exposed to client
- Rotated quarterly

## Monitoring & Logging

**Metrics to track:**
- Average transcription latency
- Success rate (successfully extracted all fields)
- Confidence distribution (high/medium/low)
- Error rate by error type
- Cost per transcription
- Daily/weekly usage patterns

**Logging:**
- Log all failed transcriptions (without audio data)
- Log parsing errors
- Log unusual carbAmount values (>200g)
- Do NOT log audio files or full transcriptions (privacy)

## Future Enhancements (Out of Scope)

- Multi-language support (English, Arabic)
- Voice confirmation ("Is this correct?")
- Learning from corrections (feedback loop)
- Automatic portion size estimation
- Integration with recipe database for auto-fill carbs
- Voice commands for other app features

---

## Summary

This spec describes implementing voice-based meal logging using Gemini 2.5 Flash for transcription and structured data extraction in a single API call. The system handles natural Turkish speech with two flexible formats:

1. **Simple format**: User lists foods and gives total carbs
2. **Detailed format**: User specifies carbs per food item

Gemini automatically detects which format the user is using and structures the data accordingly. The system extracts:
- Individual food items with optional portions
- Per-item or total carbohydrates
- Meal type and time
- Confidence level

Users see a confirmation screen where they can review and edit all extracted information before saving. This replaces the less accurate Apple Speech Recognition approach with an AI-powered solution that understands natural language, handles variations, and provides complete meal tracking data including specific foods eaten.

## Key Benefits
1. Single API call (transcription + parsing combined)
2. Flexible input format (adapts to natural speech)
3. Better Turkish language understanding
4. Captures complete meal details (what, how much, when)
5. Handles both simple and detailed logging styles
6. More accurate than Apple Speech Recognition
7. Cost-effective (~1 cent per meal log)
8. Reduces friction - users speak naturally without rigid rules
