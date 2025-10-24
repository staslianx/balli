//
// Gemini 2.5 Flash Audio Transcription for Meal Logging
// Direct Gemini API with ResponseSchema for structured meal data extraction
//

import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';

// Initialize the Google AI client
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_API_KEY || '');

// Response schema that enforces exact JSON structure for meal data
const mealTranscriptionResponseSchema = {
  type: SchemaType.OBJECT,
  properties: {
    transcription: {
      type: SchemaType.STRING,
      description: "Full transcribed text of what the user said"
    },
    foods: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          name: {
            type: SchemaType.STRING,
            description: "Name of the food item"
          },
          amount: {
            type: SchemaType.STRING,
            description: "Amount or portion (e.g. '2 adet', '1 dilim'), null if not specified",
            nullable: true
          },
          carbs: {
            type: SchemaType.NUMBER,
            description: "Carbs for this specific item if mentioned, null if not specified",
            nullable: true
          }
        },
        required: ["name"]
      },
      description: "Array of food items mentioned"
    },
    totalCarbs: {
      type: SchemaType.NUMBER,
      description: "Total carbohydrates in grams (0 if not mentioned)"
    },
    mealType: {
      type: SchemaType.STRING,
      description: "Type of meal: kahvaltı, öğle yemeği, akşam yemeği, or atıştırmalık",
      enum: ["kahvaltı", "öğle yemeği", "akşam yemeği", "atıştırmalık"]
    },
    mealTime: {
      type: SchemaType.STRING,
      description: "Time in HH:MM format if mentioned, null otherwise",
      nullable: true
    },
    confidence: {
      type: SchemaType.STRING,
      description: "Confidence level: high, medium, or low",
      enum: ["high", "medium", "low"]
    }
  },
  required: ["transcription", "foods", "totalCarbs", "mealType", "confidence"]
};

export interface TranscribeMealInput {
  audioData: string;        // Base64-encoded audio file
  mimeType: string;         // "audio/m4a" or "audio/mp4" (iOS default)
  userId: string;           // For authentication
  currentTime: string;      // ISO8601 timestamp as fallback
}

export interface FoodItem {
  name: string;
  amount: string | null;
  carbs: number | null;
}

export interface TranscribeMealOutput {
  success: boolean;
  data?: {
    transcription: string;
    foods: FoodItem[];
    totalCarbs: number;
    mealType: string;
    mealTime: string | null;
    confidence: string;
  };
  error?: string;
}

/**
 * Transcribes Turkish audio and extracts structured meal data using Gemini 2.5 Flash
 * Handles both simple format (total carbs only) and detailed format (per-item carbs)
 */
export async function transcribeMealAudio(
  input: TranscribeMealInput
): Promise<TranscribeMealOutput> {
  try {
    console.log(`🎤 [TRANSCRIBE-MEAL] Starting transcription for user ${input.userId}`);
    const startTime = Date.now();

    // Validate audio size (20MB limit for inline data)
    const audioSizeBytes = (input.audioData.length * 3) / 4; // Base64 to bytes approximation
    const audioSizeMB = audioSizeBytes / (1024 * 1024);

    if (audioSizeMB > 20) {
      console.error(`❌ [TRANSCRIBE-MEAL] Audio too large: ${audioSizeMB.toFixed(2)}MB`);
      return {
        success: false,
        error: 'Audio file too large. Please record a shorter message (max 20MB).'
      };
    }

    console.log(`📊 [TRANSCRIBE-MEAL] Audio size: ${audioSizeMB.toFixed(2)}MB`);

    // Get the model with structured output support
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash-exp",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: mealTranscriptionResponseSchema as any,
        temperature: 0.2, // Low temperature for precise extraction
        maxOutputTokens: 2048
      }
    });

    // Turkish prompt for meal logging (from spec)
    const promptText = `Bu Türkçe ses kaydını dinle ve öğün bilgilerini çıkar.

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
- "onu saymıyoruz", "onda yok" gibi ifadeler = carbs: 0
- Zaman formatları: "dokuz buçuk" = "09:30", "saat 13:00" = "13:00"
- Öğün türünü yiyeceklere ve zamana göre tahmin et (belirtilmediyse)

JSON formatında dön.`;

    // Process the audio with the prompt
    const audioPart = {
      inlineData: {
        data: input.audioData,
        mimeType: input.mimeType
      }
    };

    console.log('🔄 [TRANSCRIBE-MEAL] Calling Gemini 2.5 Flash with audio...');
    const result = await model.generateContent([promptText, audioPart]);
    const response = await result.response;
    const text = response.text();

    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`✅ [TRANSCRIBE-MEAL] Received structured response in ${processingTime}s`);

    // Parse the guaranteed JSON response
    let extractedData;
    try {
      extractedData = JSON.parse(text);
    } catch (parseError) {
      console.error('❌ [TRANSCRIBE-MEAL] Unexpected: responseSchema failed to ensure JSON:', parseError);
      return {
        success: false,
        error: 'Failed to parse transcription. Please try again.'
      };
    }

    // Validate the extracted data
    const validationErrors = validateMealData(extractedData);
    if (validationErrors.length > 0) {
      console.warn(`⚠️ [TRANSCRIBE-MEAL] Validation warnings: ${validationErrors.join(', ')}`);
      // Don't fail, just log warnings - data might still be usable
    }

    // Transform to output format
    const output: TranscribeMealOutput = {
      success: true,
      data: {
        transcription: extractedData.transcription || '',
        foods: extractedData.foods || [],
        totalCarbs: extractedData.totalCarbs || 0,
        mealType: extractedData.mealType || 'atıştırmalık',
        mealTime: extractedData.mealTime || null,
        confidence: extractedData.confidence || 'low'
      }
    };

    console.log(`✅ [TRANSCRIBE-MEAL] Extracted ${output.data!.foods.length} foods, ${output.data!.totalCarbs}g carbs (${output.data!.confidence} confidence) in ${processingTime}s`);

    return output;

  } catch (error) {
    console.error('❌ [TRANSCRIBE-MEAL] Transcription failed:', error);

    // Handle specific error types
    if (error instanceof Error) {
      const errorMessage = error.message.toLowerCase();

      if (errorMessage.includes('rate limit') || errorMessage.includes('quota')) {
        return {
          success: false,
          error: 'Service is busy. Please wait a moment and try again.'
        };
      }

      if (errorMessage.includes('audio format') || errorMessage.includes('mime type')) {
        return {
          success: false,
          error: 'Audio format not supported. Please try recording again.'
        };
      }

      if (errorMessage.includes('timeout')) {
        return {
          success: false,
          error: 'Processing took too long. Please try a shorter recording.'
        };
      }

      return {
        success: false,
        error: `Transcription failed: ${error.message}`
      };
    }

    return {
      success: false,
      error: 'An unexpected error occurred. Please try again.'
    };
  }
}

/**
 * Validates extracted meal data and returns warnings
 */
function validateMealData(data: any): string[] {
  const warnings: string[] = [];

  // Validate totalCarbs range
  if (data.totalCarbs < 0 || data.totalCarbs > 500) {
    warnings.push(`Unusual totalCarbs value: ${data.totalCarbs}g`);
  }

  // Validate foods array has items
  if (!data.foods || data.foods.length === 0) {
    warnings.push('No food items extracted');
  }

  // If foods have individual carbs, check if sum matches total (±5g tolerance)
  if (data.foods && data.foods.length > 0) {
    const foodsWithCarbs = data.foods.filter((f: FoodItem) => f.carbs !== null);
    if (foodsWithCarbs.length > 0) {
      const sum = foodsWithCarbs.reduce((acc: number, f: FoodItem) => acc + (f.carbs || 0), 0);
      const diff = Math.abs(sum - data.totalCarbs);
      if (diff > 5) {
        warnings.push(`Sum of item carbs (${sum}g) doesn't match totalCarbs (${data.totalCarbs}g)`);
      }
    }
  }

  // Validate mealTime format if present
  if (data.mealTime && !/^\d{2}:\d{2}$/.test(data.mealTime)) {
    warnings.push(`Invalid mealTime format: ${data.mealTime}`);
  }

  // Validate each food has a name
  if (data.foods) {
    data.foods.forEach((food: FoodItem, index: number) => {
      if (!food.name || food.name.trim().length === 0) {
        warnings.push(`Food item ${index + 1} has no name`);
      }
    });
  }

  return warnings;
}

/**
 * Health check for the transcription service
 */
export async function healthCheckTranscription(): Promise<{ status: string; model: string; apiKey: boolean }> {
  try {
    genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    const hasApiKey = !!(process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_API_KEY);

    return {
      status: 'ready',
      model: 'gemini-2.0-flash-exp',
      apiKey: hasApiKey
    };
  } catch (error) {
    return {
      status: 'error',
      model: 'gemini-2.0-flash-exp',
      apiKey: false
    };
  }
}
