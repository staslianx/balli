/**
 * Comprehensive response cleaning utility
 * Handles all variations of LLM JSON output formatting
 */

export function cleanLLMResponse(responseText: string): string {
  let cleaned = responseText;

  // Step 1: Remove code fence markers
  cleaned = cleaned
    .replace(/```json\n?/g, '')
    .replace(/```\n?/g, '')
    .trim();

  // Step 2: Remove leading "json" word (case-insensitive)
  cleaned = cleaned.replace(/^json\s*/i, '').trim();

  // Step 3: Try to extract answer from {"answer": "..."} structure
  // This handles cases where JSON parsing fails but structure is present
  const answerMatch = cleaned.match(/"answer"\s*:\s*"([\s\S]+?)"\s*,?\s*"?confidence/);
  if (answerMatch) {
    cleaned = answerMatch[1];
  } else {
    // Try broader match for just {"answer": "..."}
    const simpleMatch = cleaned.match(/^\s*\{\s*"answer"\s*:\s*"([\s\S]+?)"\s*[,}]/);
    if (simpleMatch) {
      cleaned = simpleMatch[1];
    }
  }

  // Step 4: Remove any remaining wrapper braces if they wrap the entire content
  cleaned = cleaned.replace(/^\s*\{\s*"answer"\s*:\s*"?/, '').replace(/"?\s*\}\s*$/, '');

  // Step 5: Unescape any JSON-escaped characters
  cleaned = cleaned
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\')
    .trim();

  return cleaned;
}

/**
 * Parse LLM JSON response with aggressive fallback cleaning
 */
export function parseLLMResponse<T extends { answer: string }>(
  responseText: string,
  fallbackConfidence: number = 0.7
): T {
  // First try: Clean and parse as JSON
  const cleaned = cleanLLMResponse(responseText);

  try {
    return JSON.parse(cleaned) as T;
  } catch (parseError) {
    // Second try: The cleaned text IS the answer
    console.log('⚠️ JSON parse failed, using cleaned text as answer');
    return {
      answer: cleaned,
      confidence: fallbackConfidence
    } as unknown as T;
  }
}
