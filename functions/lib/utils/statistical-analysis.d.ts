/**
 * Data point for validation (ground truth vs EDAMAM)
 */
export interface DataPoint {
    groundTruth: number;
    edamam: number;
    ingredient: string;
}
/**
 * Complete statistical validation results
 */
export interface StatisticalValidation {
    mae: number;
    mape: number;
    rmse: number;
    pearsonR: number;
    linsCCC: number;
    blandAltman: {
        meanDifference: number;
        standardDeviation: number;
        lowerLOA: number;
        upperLOA: number;
        systematicBias: boolean;
    };
    errorDistribution: {
        mean: number;
        median: number;
        min: number;
        max: number;
        q25: number;
        q75: number;
    };
    passesValidation: boolean;
    failureReasons: string[];
}
/**
 * Thresholds for pass/fail validation (diabetes-specific)
 */
export interface ValidationThresholds {
    carbs: {
        maeMax: number;
        mapeMax: number;
        pearsonMin: number;
    };
    fat: {
        mapeMax: number;
        pearsonMin: number;
    };
    protein: {
        mapeMax: number;
        pearsonMin: number;
    };
}
/**
 * Default thresholds from EDAMAM-VALIDATION-SPEC.md
 * Based on diabetes insulin dosing requirements
 */
export declare const DEFAULT_THRESHOLDS: ValidationThresholds;
/**
 * Method 1: Mean Absolute Error (MAE)
 * Average absolute difference between ground truth and EDAMAM
 *
 * Formula: MAE = (1/n) * Σ|ground_truth - edamam|
 */
export declare function calculateMAE(data: DataPoint[]): number;
/**
 * Method 2: Mean Absolute Percentage Error (MAPE)
 * Average percentage error relative to ground truth
 *
 * Formula: MAPE = (1/n) * Σ(|ground_truth - edamam| / ground_truth) * 100
 */
export declare function calculateMAPE(data: DataPoint[]): number;
/**
 * Method 3: Root Mean Square Error (RMSE)
 * Penalizes larger errors more heavily than MAE
 *
 * Formula: RMSE = √((1/n) * Σ(ground_truth - edamam)²)
 */
export declare function calculateRMSE(data: DataPoint[]): number;
/**
 * Method 4: Pearson Correlation Coefficient (r)
 * Measures linear relationship between ground truth and EDAMAM
 *
 * Formula: r = Σ((x - x̄)(y - ȳ)) / √(Σ(x - x̄)² * Σ(y - ȳ)²)
 * Range: -1 to +1 (1 = perfect positive correlation)
 */
export declare function calculatePearsonR(data: DataPoint[]): number;
/**
 * Method 5: Lin's Concordance Correlation Coefficient (CCC)
 * Combines precision and accuracy into single metric
 *
 * Formula: CCC = (2 * r * σ_gt * σ_edamam) / (σ_gt² + σ_edamam² + (μ_gt - μ_edamam)²)
 * Range: -1 to +1 (1 = perfect agreement)
 */
export declare function calculateLinsCCC(data: DataPoint[]): number;
/**
 * Method 6: Bland-Altman Analysis
 * Assesses agreement between two measurement methods
 *
 * Calculates:
 * - Mean difference (bias)
 * - Limits of agreement (mean ± 1.96 * SD)
 * - Systematic bias detection
 */
export declare function calculateBlandAltman(data: DataPoint[]): {
    meanDifference: number;
    standardDeviation: number;
    lowerLOA: number;
    upperLOA: number;
    systematicBias: boolean;
};
/**
 * Error Distribution Analysis
 * Provides statistical summary of error distribution
 */
export declare function calculateErrorDistribution(data: DataPoint[]): {
    mean: number;
    median: number;
    min: number;
    max: number;
    q25: number;
    q75: number;
};
/**
 * Complete statistical validation
 * Runs all 6 methods and returns comprehensive results
 *
 * @param data - Array of ground truth vs EDAMAM data points
 * @param nutrientType - Type of nutrient being validated (for threshold selection)
 * @param thresholds - Validation thresholds (defaults to diabetes-specific)
 * @returns Complete statistical validation results with pass/fail
 */
export declare function performStatisticalValidation(data: DataPoint[], nutrientType: 'carbs' | 'fat' | 'protein', thresholds?: ValidationThresholds): StatisticalValidation;
//# sourceMappingURL=statistical-analysis.d.ts.map