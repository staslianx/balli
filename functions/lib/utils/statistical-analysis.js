"use strict";
//
// statistical-analysis.ts
// Statistical validation methods for EDAMAM accuracy assessment
// Implements 6 validation methods from EDAMAM-VALIDATION-SPEC.md
//
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_THRESHOLDS = void 0;
exports.calculateMAE = calculateMAE;
exports.calculateMAPE = calculateMAPE;
exports.calculateRMSE = calculateRMSE;
exports.calculatePearsonR = calculatePearsonR;
exports.calculateLinsCCC = calculateLinsCCC;
exports.calculateBlandAltman = calculateBlandAltman;
exports.calculateErrorDistribution = calculateErrorDistribution;
exports.performStatisticalValidation = performStatisticalValidation;
/**
 * Default thresholds from EDAMAM-VALIDATION-SPEC.md
 * Based on diabetes insulin dosing requirements
 */
exports.DEFAULT_THRESHOLDS = {
    carbs: {
        maeMax: 7.5, // ±7.5g prevents half-unit insulin errors
        mapeMax: 10, // <10% error for carbs
        pearsonMin: 0.85 // Strong correlation required
    },
    fat: {
        mapeMax: 15, // <15% error for fat (less critical than carbs)
        pearsonMin: 0.80 // Good correlation required
    },
    protein: {
        mapeMax: 15, // <15% error for protein
        pearsonMin: 0.80 // Good correlation required
    }
};
/**
 * Method 1: Mean Absolute Error (MAE)
 * Average absolute difference between ground truth and EDAMAM
 *
 * Formula: MAE = (1/n) * Σ|ground_truth - edamam|
 */
function calculateMAE(data) {
    if (data.length === 0)
        return 0;
    const sumAbsoluteErrors = data.reduce((sum, point) => {
        return sum + Math.abs(point.groundTruth - point.edamam);
    }, 0);
    return sumAbsoluteErrors / data.length;
}
/**
 * Method 2: Mean Absolute Percentage Error (MAPE)
 * Average percentage error relative to ground truth
 *
 * Formula: MAPE = (1/n) * Σ(|ground_truth - edamam| / ground_truth) * 100
 */
function calculateMAPE(data) {
    if (data.length === 0)
        return 0;
    const sumPercentageErrors = data.reduce((sum, point) => {
        // Skip if ground truth is 0 (avoid division by zero)
        if (point.groundTruth === 0)
            return sum;
        const percentageError = Math.abs(point.groundTruth - point.edamam) / point.groundTruth;
        return sum + percentageError;
    }, 0);
    const validPoints = data.filter(p => p.groundTruth !== 0).length;
    return validPoints > 0 ? (sumPercentageErrors / validPoints) * 100 : 0;
}
/**
 * Method 3: Root Mean Square Error (RMSE)
 * Penalizes larger errors more heavily than MAE
 *
 * Formula: RMSE = √((1/n) * Σ(ground_truth - edamam)²)
 */
function calculateRMSE(data) {
    if (data.length === 0)
        return 0;
    const sumSquaredErrors = data.reduce((sum, point) => {
        const error = point.groundTruth - point.edamam;
        return sum + (error * error);
    }, 0);
    return Math.sqrt(sumSquaredErrors / data.length);
}
/**
 * Method 4: Pearson Correlation Coefficient (r)
 * Measures linear relationship between ground truth and EDAMAM
 *
 * Formula: r = Σ((x - x̄)(y - ȳ)) / √(Σ(x - x̄)² * Σ(y - ȳ)²)
 * Range: -1 to +1 (1 = perfect positive correlation)
 */
function calculatePearsonR(data) {
    if (data.length < 2)
        return 0;
    // Calculate means
    const meanGroundTruth = data.reduce((sum, p) => sum + p.groundTruth, 0) / data.length;
    const meanEdamam = data.reduce((sum, p) => sum + p.edamam, 0) / data.length;
    // Calculate deviations and products
    let sumProduct = 0;
    let sumSquaredDeviationsGroundTruth = 0;
    let sumSquaredDeviationsEdamam = 0;
    for (const point of data) {
        const deviationGroundTruth = point.groundTruth - meanGroundTruth;
        const deviationEdamam = point.edamam - meanEdamam;
        sumProduct += deviationGroundTruth * deviationEdamam;
        sumSquaredDeviationsGroundTruth += deviationGroundTruth * deviationGroundTruth;
        sumSquaredDeviationsEdamam += deviationEdamam * deviationEdamam;
    }
    // Calculate correlation coefficient
    const denominator = Math.sqrt(sumSquaredDeviationsGroundTruth * sumSquaredDeviationsEdamam);
    return denominator === 0 ? 0 : sumProduct / denominator;
}
/**
 * Method 5: Lin's Concordance Correlation Coefficient (CCC)
 * Combines precision and accuracy into single metric
 *
 * Formula: CCC = (2 * r * σ_gt * σ_edamam) / (σ_gt² + σ_edamam² + (μ_gt - μ_edamam)²)
 * Range: -1 to +1 (1 = perfect agreement)
 */
function calculateLinsCCC(data) {
    if (data.length < 2)
        return 0;
    // Calculate means
    const meanGroundTruth = data.reduce((sum, p) => sum + p.groundTruth, 0) / data.length;
    const meanEdamam = data.reduce((sum, p) => sum + p.edamam, 0) / data.length;
    // Calculate standard deviations
    const varianceGroundTruth = data.reduce((sum, p) => {
        const deviation = p.groundTruth - meanGroundTruth;
        return sum + (deviation * deviation);
    }, 0) / data.length;
    const varianceEdamam = data.reduce((sum, p) => {
        const deviation = p.edamam - meanEdamam;
        return sum + (deviation * deviation);
    }, 0) / data.length;
    const sdGroundTruth = Math.sqrt(varianceGroundTruth);
    const sdEdamam = Math.sqrt(varianceEdamam);
    // Calculate Pearson r
    const r = calculatePearsonR(data);
    // Calculate Lin's CCC
    const numerator = 2 * r * sdGroundTruth * sdEdamam;
    const denominator = varianceGroundTruth + varianceEdamam + Math.pow(meanGroundTruth - meanEdamam, 2);
    return denominator === 0 ? 0 : numerator / denominator;
}
/**
 * Method 6: Bland-Altman Analysis
 * Assesses agreement between two measurement methods
 *
 * Calculates:
 * - Mean difference (bias)
 * - Limits of agreement (mean ± 1.96 * SD)
 * - Systematic bias detection
 */
function calculateBlandAltman(data) {
    if (data.length === 0) {
        return {
            meanDifference: 0,
            standardDeviation: 0,
            lowerLOA: 0,
            upperLOA: 0,
            systematicBias: false
        };
    }
    // Calculate differences (EDAMAM - ground truth)
    const differences = data.map(p => p.edamam - p.groundTruth);
    // Mean difference (average bias)
    const meanDifference = differences.reduce((sum, d) => sum + d, 0) / differences.length;
    // Standard deviation of differences
    const variance = differences.reduce((sum, d) => {
        const deviation = d - meanDifference;
        return sum + (deviation * deviation);
    }, 0) / differences.length;
    const standardDeviation = Math.sqrt(variance);
    // Limits of agreement (mean ± 1.96 * SD)
    const lowerLOA = meanDifference - (1.96 * standardDeviation);
    const upperLOA = meanDifference + (1.96 * standardDeviation);
    // Systematic bias: mean difference significantly different from 0
    // Using simple heuristic: |mean| > 0.5 * SD
    const systematicBias = Math.abs(meanDifference) > (0.5 * standardDeviation);
    return {
        meanDifference,
        standardDeviation,
        lowerLOA,
        upperLOA,
        systematicBias
    };
}
/**
 * Error Distribution Analysis
 * Provides statistical summary of error distribution
 */
function calculateErrorDistribution(data) {
    if (data.length === 0) {
        return { mean: 0, median: 0, min: 0, max: 0, q25: 0, q75: 0 };
    }
    // Calculate errors
    const errors = data.map(p => p.edamam - p.groundTruth);
    // Sort for percentiles
    const sortedErrors = [...errors].sort((a, b) => a - b);
    // Mean
    const mean = errors.reduce((sum, e) => sum + e, 0) / errors.length;
    // Median (50th percentile)
    const median = sortedErrors[Math.floor(sortedErrors.length / 2)];
    // Min and Max
    const min = sortedErrors[0];
    const max = sortedErrors[sortedErrors.length - 1];
    // Quartiles
    const q25Index = Math.floor(sortedErrors.length * 0.25);
    const q75Index = Math.floor(sortedErrors.length * 0.75);
    const q25 = sortedErrors[q25Index];
    const q75 = sortedErrors[q75Index];
    return { mean, median, min, max, q25, q75 };
}
/**
 * Complete statistical validation
 * Runs all 6 methods and returns comprehensive results
 *
 * @param data - Array of ground truth vs EDAMAM data points
 * @param nutrientType - Type of nutrient being validated (for threshold selection)
 * @param thresholds - Validation thresholds (defaults to diabetes-specific)
 * @returns Complete statistical validation results with pass/fail
 */
function performStatisticalValidation(data, nutrientType, thresholds = exports.DEFAULT_THRESHOLDS) {
    // Run all 6 statistical methods
    const mae = calculateMAE(data);
    const mape = calculateMAPE(data);
    const rmse = calculateRMSE(data);
    const pearsonR = calculatePearsonR(data);
    const linsCCC = calculateLinsCCC(data);
    const blandAltman = calculateBlandAltman(data);
    const errorDistribution = calculateErrorDistribution(data);
    // Determine pass/fail based on nutrient-specific thresholds
    const failureReasons = [];
    const nutrientThresholds = thresholds[nutrientType];
    // Check MAPE
    if (mape > nutrientThresholds.mapeMax) {
        failureReasons.push(`MAPE ${mape.toFixed(1)}% exceeds threshold ${nutrientThresholds.mapeMax}%`);
    }
    // Check Pearson correlation
    if (pearsonR < nutrientThresholds.pearsonMin) {
        failureReasons.push(`Pearson r ${pearsonR.toFixed(2)} below threshold ${nutrientThresholds.pearsonMin}`);
    }
    // Check MAE for carbs specifically (insulin dosing critical)
    if (nutrientType === 'carbs' && 'maeMax' in nutrientThresholds && mae > nutrientThresholds.maeMax) {
        failureReasons.push(`MAE ${mae.toFixed(1)}g exceeds critical threshold ${nutrientThresholds.maeMax}g for carbs`);
    }
    // Check systematic bias
    if (blandAltman.systematicBias) {
        const biasDirection = blandAltman.meanDifference > 0 ? 'over-estimates' : 'under-estimates';
        failureReasons.push(`Systematic bias detected: EDAMAM ${biasDirection} by ${Math.abs(blandAltman.meanDifference).toFixed(1)}g on average`);
    }
    const passesValidation = failureReasons.length === 0;
    return {
        mae,
        mape,
        rmse,
        pearsonR,
        linsCCC,
        blandAltman,
        errorDistribution,
        passesValidation,
        failureReasons
    };
}
//# sourceMappingURL=statistical-analysis.js.map