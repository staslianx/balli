/**
 * Reference Pattern Detector
 *
 * Detects which of the 20 linguistic reference categories
 * are present in a user's message using pattern matching.
 */
import { DetectedReference } from './types/conversation-state';
/**
 * Detect reference patterns in user message
 */
export declare function detectReferences(message: string): DetectedReference[];
/**
 * Get the most salient (highest confidence) reference type
 */
export declare function getPrimaryReference(references: DetectedReference[]): DetectedReference;
/**
 * Determine which state layers are needed based on detected references
 */
export declare function getRequiredLayers(references: DetectedReference[]): Set<string>;
//# sourceMappingURL=reference-detector.d.ts.map