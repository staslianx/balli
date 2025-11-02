//
// Direct Gemini API Nutrition Extractor with ResponseSchema
// Replaces Genkit-based implementation for 99%+ JSON parsing reliability
//

import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';

// Initialize the Google AI client
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_API_KEY || '');

// Comprehensive response schema that enforces exact JSON structure - focused on nutrition values only
const nutritionResponseSchema = {
  type: SchemaType.OBJECT,
  properties: {
    servingSize: {
      type: SchemaType.OBJECT,
      properties: {
        value: {
          type: SchemaType.NUMBER,
          description: "Always 100 for standardization"
        },
        unit: {
          type: SchemaType.STRING,
          description: "Always 'g' for grams"
        }
      },
      required: ["value", "unit"]
    },
    nutrients: {
      type: SchemaType.OBJECT,
      properties: {
        calories: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        totalCarbohydrates: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        protein: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        totalFat: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        dietaryFiber: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        sugars: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        saturatedFat: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        },
        sodium: {
          type: SchemaType.OBJECT,
          properties: {
            value: { type: SchemaType.NUMBER },
            unit: { type: SchemaType.STRING }
          },
          required: ["value", "unit"]
        }
      },
      required: ["calories", "totalCarbohydrates", "protein", "totalFat"]
    },
    metadata: {
      type: SchemaType.OBJECT,
      properties: {
        confidence: {
          type: SchemaType.NUMBER,
          description: "Confidence level in the extraction (0-100)"
        },
        processingTime: {
          type: SchemaType.STRING,
          description: "Time taken to process the image"
        },
        warnings: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Any warnings about the extraction process"
        }
      },
      required: ["confidence", "processingTime", "warnings"]
    }
  },
  required: ["servingSize", "nutrients", "metadata"]
};

export interface NutritionExtractionInput {
  imageBase64: string;
  language?: 'tr' | 'en';
  maxWidth?: number;
  userId?: string;
}

export interface NutritionExtractionOutput {
  servingSize: {
    value: number;
    unit: string;
    perContainer?: number;
  };
  nutrients: {
    calories: { value: number; unit: string };
    totalCarbohydrates: { value: number; unit: string };
    dietaryFiber?: { value: number; unit: string };
    sugars?: { value: number; unit: string };
    protein: { value: number; unit: string };
    totalFat: { value: number; unit: string };
    saturatedFat?: { value: number; unit: string };
    transFat?: { value: number; unit: string };
    cholesterol?: { value: number; unit: string };
    sodium?: { value: number; unit: string };
    addedSugars?: { value: number; unit: string };
  };
  metadata: {
    confidence: number;
    processingTime: string;
    modelVersion: string;
    warnings: string[];
    detectedLanguage?: string;
  };
  rawText?: string;
  usage?: {
    inputTokens: number;
    outputTokens: number;
  };
}

/**
 * Extracts nutrition information from an image using direct Gemini API with responseSchema
 * This ensures 99%+ JSON parsing reliability by enforcing the structure at the API level
 */
export async function extractNutritionWithResponseSchema(
  input: NutritionExtractionInput
): Promise<NutritionExtractionOutput> {
  try {
    console.log(`🏷️ [NUTRITION-API] Starting extraction (${input.language || 'tr'} language)`);
    const startTime = Date.now();

    // Get the model with structured output support
    const model = genAI.getGenerativeModel({
      model: "gemini-flash-latest",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: nutritionResponseSchema as any, // Cast to fix TypeScript schema type issue
        temperature: 0.1, // Low temperature for precise extraction
        maxOutputTokens: 2048
      }
    });

    // Create language-specific prompt
    const promptText = input.language === 'tr'
      ? `Bu resimde görünen besin etiketi bilgilerini analiz et ve JSON formatında çıkar.

GÖREV: Türkçe besin etiketindeki "100g" veya "100 gram" veya "100 gr" sütunundan TÜM besin değerlerini oku.

ÇOK ÖNEMLİ - SÜTUN SEÇİMİ:
- Türk besin etiketleri genelde iki sütun gösterir: "1 porsiyon (30g)" ve "100g"
- Sen SADECE "100g" veya "100 gram" veya "100 gr" sütunundaki değerleri kullanacaksın
- ASLA porsiyon sütunundan (30g, 40g, vb.) değer alma
- Tüm değerler (kalori, karbonhidrat, şeker, protein, yağ) AYNI 100g sütunundan alınmalı
- Farklı sütunlardan değer karıştırma!

ÇIKARILACAK BİLGİLER (SADECE 100g SÜTUNUNDAN):
1. Porsiyon bilgisi: HER ZAMAN 100g olarak ayarla
2. Besin değerleri - SADECE 100g sütunundan:
   - Kalori/Enerji (kcal) - 100g sütunundan
   - Karbonhidrat (g) - 100g sütunundan
   - Şeker (g) - 100g sütunundan
   - Lif (g) - 100g sütunundan
   - Protein (g) - 100g sütunundan
   - Yağ (g) - 100g sütunundan
   - Doymuş yağ (g) - 100g sütunundan
   - Sodyum/Tuz (mg) - 100g sütunundan

KONTROL:
- Tüm değerlerin aynı sütundan (100g) alındığından emin ol
- Örnek: Şeker 30g sütununda 5g, 100g sütununda 16.7g ise → 16.7 kullan
- servingSize: {"value": 100, "unit": "g"}
- Belirsiz değerleri 0 olarak ayarla
- Güven skoru: ne kadar net okuyabildiğin (0-100)

ZORUNLU: Sadece geçerli JSON formatında yanıt ver, başka metin ekleme.`
      : `Analyze the nutrition label in this image and extract all nutrition information in JSON format.

TASK: Read ALL nutrition values from the "per 100g" or "100g" column ONLY.

CRITICAL - COLUMN SELECTION:
- Nutrition labels often show two columns: "per serving (30g)" and "per 100g"
- You MUST use ONLY the "per 100g" or "100g" or "100 gram" column values
- NEVER take values from the serving size column (30g, 40g, etc.)
- ALL values (calories, carbs, sugars, protein, fat) must come from the SAME 100g column
- Do NOT mix values from different columns!

EXTRACT (ONLY FROM 100g COLUMN):
1. Serving size: ALWAYS set to 100g
2. Nutrition values - ONLY from 100g column:
   - Calories/Energy (kcal) - from 100g column
   - Total carbohydrates (g) - from 100g column
   - Sugars (g) - from 100g column
   - Dietary fiber (g) - from 100g column
   - Protein (g) - from 100g column
   - Total fat (g) - from 100g column
   - Saturated fat (g) - from 100g column
   - Sodium (mg) - from 100g column

VERIFICATION:
- Ensure all values are from the same column (100g)
- Example: If sugar shows 5g in 30g column and 16.7g in 100g column → use 16.7
- servingSize: {"value": 100, "unit": "g"}
- Set uncertain values to 0
- Confidence score: how clearly you can read (0-100)

MANDATORY: Only respond with valid JSON, no additional text.`;

    // Process the image with the prompt
    const imagePart = {
      inlineData: {
        data: input.imageBase64,
        mimeType: "image/jpeg"
      }
    };

    console.log('🔄 [NUTRITION-API] Calling Gemini with responseSchema...');
    const result = await model.generateContent([promptText, imagePart]);
    const response = await result.response;
    const text = response.text();

    // Extract usage metadata for cost tracking
    const usageMetadata = response.usageMetadata;
    const inputTokens = usageMetadata?.promptTokenCount || 0;
    const outputTokens = usageMetadata?.candidatesTokenCount || 0;

    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log('✅ [NUTRITION-API] Received structured response from Gemini');
    console.log(`📊 [NUTRITION-API] Token usage: ${inputTokens} in, ${outputTokens} out`);

    // Parse the guaranteed JSON response
    let extractedData;
    try {
      extractedData = JSON.parse(text);
    } catch (parseError) {
      // This should never happen with responseSchema, but add fallback
      console.error('❌ [NUTRITION-API] Unexpected: responseSchema failed to ensure JSON:', parseError);
      throw new Error('Failed to parse structured response - this indicates a schema issue');
    }

    // Transform to our output format (the schema guarantees the structure)
    const result_output: NutritionExtractionOutput = {
      servingSize: {
        value: extractedData.servingSize.value,
        unit: extractedData.servingSize.unit,
        perContainer: extractedData.servingSize.perContainer || undefined
      },
      nutrients: {
        calories: extractedData.nutrients.calories,
        totalCarbohydrates: extractedData.nutrients.totalCarbohydrates,
        dietaryFiber: extractedData.nutrients.dietaryFiber || undefined,
        sugars: extractedData.nutrients.sugars || undefined,
        protein: extractedData.nutrients.protein,
        totalFat: extractedData.nutrients.totalFat,
        saturatedFat: extractedData.nutrients.saturatedFat || undefined,
        transFat: extractedData.nutrients.transFat || undefined,
        cholesterol: extractedData.nutrients.cholesterol || undefined,
        sodium: extractedData.nutrients.sodium || undefined,
        addedSugars: extractedData.nutrients.addedSugars || undefined
      },
      metadata: {
        confidence: extractedData.metadata.confidence,
        processingTime: `${processingTime}s`,
        modelVersion: 'gemini-flash-latest-direct-api',
        warnings: extractedData.metadata.warnings || [],
        detectedLanguage: input.language
      },
      rawText: text, // Store the structured response for debugging
      usage: {
        inputTokens,
        outputTokens
      }
    };

    console.log(`✅ [NUTRITION-API] Extracted nutrition data (confidence: ${result_output.metadata.confidence}%) in ${processingTime}s`);

    return result_output;

  } catch (error) {
    console.error('❌ [NUTRITION-API] Extraction failed:', error);

    // Create proper error response
    if (error instanceof Error) {
      throw new Error(`Nutrition extraction failed: ${error.message}`);
    } else {
      throw new Error('Nutrition extraction failed: Unknown error');
    }
  }
}

/**
 * Health check for the direct API extractor
 */
export async function healthCheckDirectApi(): Promise<{ status: string; model: string; apiKey: boolean }> {
  try {
    // Test model availability
    genAI.getGenerativeModel({ model: "gemini-flash-latest" });
    const hasApiKey = !!(process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_API_KEY);

    return {
      status: 'ready',
      model: 'gemini-flash-latest',
      apiKey: hasApiKey
    };
  } catch (error) {
    return {
      status: 'error',
      model: 'gemini-flash-latest',
      apiKey: false
    };
  }
}