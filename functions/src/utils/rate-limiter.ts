/**
 * Rate Limiting for Tier 3 Medical Research Queries
 *
 * Implements Firestore-based daily query limits per user
 * Limit: 10 Tier 3 queries per user per day
 */

import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const db = getFirestore();

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  reason?: string;
}

export interface UsageRecord {
  userId: string;
  tier3Count: number;
  date: string; // YYYY-MM-DD format
  lastQueryAt: Date;
  queries: Array<{
    timestamp: Date;
    question: string;
  }>;
}

const TIER3_DAILY_LIMIT = 50;

/**
 * Get current date in YYYY-MM-DD format
 */
function getCurrentDate(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Get reset time (midnight UTC)
 */
function getResetTime(): Date {
  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(0, 0, 0, 0);
  return tomorrow;
}

/**
 * Check if user can make a Tier 3 query
 */
export async function checkTier3RateLimit(userId: string): Promise<RateLimitResult> {
  try {
    const currentDate = getCurrentDate();
    const docRef = db.collection('researchUsage').doc(`${userId}_${currentDate}`);

    const doc = await docRef.get();

    if (!doc.exists) {
      // First query of the day - allowed
      return {
        allowed: true,
        remaining: TIER3_DAILY_LIMIT - 1,
        resetAt: getResetTime()
      };
    }

    const data = doc.data() as UsageRecord;

    if (data.tier3Count >= TIER3_DAILY_LIMIT) {
      // Limit exceeded
      return {
        allowed: false,
        remaining: 0,
        resetAt: getResetTime(),
        reason: `Daily limit of ${TIER3_DAILY_LIMIT} medical research queries reached. Resets at midnight UTC.`
      };
    }

    // Within limit
    return {
      allowed: true,
      remaining: TIER3_DAILY_LIMIT - data.tier3Count - 1,
      resetAt: getResetTime()
    };

  } catch (error) {
    console.error('❌ [RATE-LIMIT] Check error:', error);
    // On error, allow the query but log it
    return {
      allowed: true,
      remaining: TIER3_DAILY_LIMIT - 1,
      resetAt: getResetTime()
    };
  }
}

/**
 * Record a Tier 3 query usage
 */
export async function recordTier3Usage(userId: string, question: string): Promise<void> {
  try {
    const currentDate = getCurrentDate();
    const docRef = db.collection('researchUsage').doc(`${userId}_${currentDate}`);

    const doc = await docRef.get();

    if (!doc.exists) {
      // Create new usage record
      const newRecord: UsageRecord = {
        userId,
        tier3Count: 1,
        date: currentDate,
        lastQueryAt: new Date(),
        queries: [
          {
            timestamp: new Date(),
            question: question.substring(0, 200) // Store truncated question for analytics
          }
        ]
      };

      await docRef.set(newRecord);
      console.log(`📊 [RATE-LIMIT] Created usage record for ${userId} (1/${TIER3_DAILY_LIMIT})`);

    } else {
      // Update existing record
      await docRef.update({
        tier3Count: FieldValue.increment(1),
        lastQueryAt: new Date(),
        queries: FieldValue.arrayUnion({
          timestamp: new Date(),
          question: question.substring(0, 200)
        })
      });

      const data = doc.data() as UsageRecord;
      const newCount = data.tier3Count + 1;
      console.log(`📊 [RATE-LIMIT] Updated usage for ${userId} (${newCount}/${TIER3_DAILY_LIMIT})`);
    }

  } catch (error) {
    console.error('❌ [RATE-LIMIT] Record error:', error);
    // Don't throw - we don't want rate limiting failures to block queries
  }
}

/**
 * Get user's current usage stats
 */
export async function getTier3Usage(userId: string): Promise<{
  count: number;
  limit: number;
  remaining: number;
  resetAt: Date;
}> {
  try {
    const currentDate = getCurrentDate();
    const docRef = db.collection('researchUsage').doc(`${userId}_${currentDate}`);

    const doc = await docRef.get();

    if (!doc.exists) {
      return {
        count: 0,
        limit: TIER3_DAILY_LIMIT,
        remaining: TIER3_DAILY_LIMIT,
        resetAt: getResetTime()
      };
    }

    const data = doc.data() as UsageRecord;

    return {
      count: data.tier3Count,
      limit: TIER3_DAILY_LIMIT,
      remaining: Math.max(0, TIER3_DAILY_LIMIT - data.tier3Count),
      resetAt: getResetTime()
    };

  } catch (error) {
    console.error('❌ [RATE-LIMIT] Get usage error:', error);
    return {
      count: 0,
      limit: TIER3_DAILY_LIMIT,
      remaining: TIER3_DAILY_LIMIT,
      resetAt: getResetTime()
    };
  }
}

/**
 * Admin function: Reset user's daily limit (for testing or support)
 */
export async function resetUserLimit(userId: string): Promise<void> {
  try {
    const currentDate = getCurrentDate();
    const docRef = db.collection('researchUsage').doc(`${userId}_${currentDate}`);

    await docRef.delete();
    console.log(`✅ [RATE-LIMIT] Reset limit for user ${userId}`);

  } catch (error) {
    console.error('❌ [RATE-LIMIT] Reset error:', error);
    throw new Error('Failed to reset user limit');
  }
}
