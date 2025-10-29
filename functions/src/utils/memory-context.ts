/**
 * Memory Context Helper
 *
 * Retrieves and formats cross-conversation memory for injection into prompts
 * Includes user facts, conversation summaries, and relevant preferences
 */

import { getFirestore } from 'firebase-admin/firestore';

const db = getFirestore();

/**
 * User fact from memory
 */
export interface UserFact {
  fact: string;
  category: string;
  confidence: number;
  createdAt: Date;
  lastAccessedAt: Date;
  source: string;
}

/**
 * Conversation summary from memory
 */
export interface ConversationSummary {
  summary: string;
  startTime: Date;
  endTime: Date;
  messageCount: number;
  tier: string;
}

/**
 * Memory context bundle
 */
export interface MemoryContext {
  userFacts: UserFact[];
  recentSummaries: ConversationSummary[];
  factCount: number;
  summaryCount: number;
}

/**
 * Fetch user facts from Firestore
 * Returns most recent facts sorted by last accessed
 */
async function fetchUserFacts(userId: string, limit: number = 10): Promise<UserFact[]> {
  try {
    const factsRef = db.collection(`users/${userId}/user_facts`);

    const snapshot = await factsRef
      .orderBy('lastAccessedAt', 'desc')
      .limit(limit)
      .get();

    if (snapshot.empty) {
      return [];
    }

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        fact: data.fact,
        category: data.category,
        confidence: data.confidence,
        createdAt: data.createdAt.toDate(),
        lastAccessedAt: data.lastAccessedAt.toDate(),
        source: data.source
      };
    });
  } catch (error) {
    console.error('❌ [MEMORY] Failed to fetch user facts:', error);
    return [];
  }
}

/**
 * Fetch recent conversation summaries from Firestore
 */
async function fetchConversationSummaries(userId: string, limit: number = 5): Promise<ConversationSummary[]> {
  try {
    const summariesRef = db.collection(`users/${userId}/conversation_summaries`);

    const snapshot = await summariesRef
      .orderBy('endTime', 'desc')
      .limit(limit)
      .get();

    if (snapshot.empty) {
      return [];
    }

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        summary: data.summary,
        startTime: data.startTime.toDate(),
        endTime: data.endTime.toDate(),
        messageCount: data.messageCount,
        tier: data.tier
      };
    });
  } catch (error) {
    console.error('❌ [MEMORY] Failed to fetch conversation summaries:', error);
    return [];
  }
}

/**
 * Get complete memory context for a user
 */
export async function getMemoryContext(userId: string): Promise<MemoryContext> {
  console.log(`🧠 [MEMORY] Fetching memory context for user: ${userId}`);

  const [userFacts, recentSummaries] = await Promise.all([
    fetchUserFacts(userId, 10),
    fetchConversationSummaries(userId, 5)
  ]);

  console.log(`📊 [MEMORY] Retrieved ${userFacts.length} facts, ${recentSummaries.length} summaries`);

  return {
    userFacts,
    recentSummaries,
    factCount: userFacts.length,
    summaryCount: recentSummaries.length
  };
}

/**
 * Format memory context for prompt injection
 * Returns formatted string ready to be added to system prompt or user prompt
 */
export function formatMemoryContext(memory: MemoryContext): string {
  if (memory.factCount === 0 && memory.summaryCount === 0) {
    return '';
  }

  let context = '\n\n--- KULLANICI BELLEGI (Önceki Konuşmalardan) ---\n';

  // Add user facts
  if (memory.userFacts.length > 0) {
    context += '\nBilinen Kullanıcı Bilgileri:\n';
    memory.userFacts.forEach((fact, index) => {
      // Only include high-confidence facts (>0.7)
      if (fact.confidence > 0.7) {
        context += `${index + 1}. ${fact.fact} [${fact.category}]\n`;
      }
    });
  }

  // Add conversation summaries
  if (memory.recentSummaries.length > 0) {
    context += '\nÖnceki Konuşma Özetleri:\n';
    memory.recentSummaries.forEach((summary, index) => {
      const date = summary.endTime.toLocaleDateString('tr-TR');
      context += `${index + 1}. ${date}: ${summary.summary}\n`;
    });
  }

  context += '\n--- BU BİLGİLERİ DIKKATE ALARAK CEVAP VER ---\n\n';

  return context;
}

/**
 * Check if memory context is available for user
 */
export async function hasMemoryContext(userId: string): Promise<boolean> {
  try {
    const factsRef = db.collection(`users/${userId}/user_facts`);
    const factsSnapshot = await factsRef.limit(1).get();
    return !factsSnapshot.empty;
  } catch (error) {
    console.error('❌ [MEMORY] Failed to check memory context:', error);
    return false;
  }
}
