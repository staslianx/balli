export interface TranscribeMealInput {
    audioData: string;
    mimeType: string;
    userId: string;
    currentTime: string;
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
        insulinDosage: number | null;
        insulinType: string | null;
        insulinName: string | null;
        confidence: string;
    };
    error?: string;
}
/**
 * Transcribes Turkish audio and extracts structured meal data using Gemini 2.5 Flash
 * Handles both simple format (total carbs only) and detailed format (per-item carbs)
 */
export declare function transcribeMealAudio(input: TranscribeMealInput): Promise<TranscribeMealOutput>;
/**
 * Health check for the transcription service
 */
export declare function healthCheckTranscription(): Promise<{
    status: string;
    model: string;
    apiKey: boolean;
}>;
//# sourceMappingURL=transcribeMeal.d.ts.map