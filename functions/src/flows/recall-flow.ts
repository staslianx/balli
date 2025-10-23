/**
 * Recall Flow - Answers user queries from past research sessions
 *
 * When router detects recall intent (tier: 0), this flow:
 * 1. Receives matched sessions from iOS FTS search
 * 2. Ranks sessions by relevance
 * 3. Uses LLM to answer from past conversation context
 * 4. Returns direct answer with session reference
 */

import { ai } from '../genkit-instance';
import { getFlashModel } from '../providers';

export interface RecallInput {
  question: string;
  userId: string;
  matchedSessions: MatchedSession[];
}

export interface MatchedSession {
  sessionId: string;
  title?: string;
  summary?: string;
  keyTopics: string[];
  createdAt: string; // ISO 8601 timestamp
  conversationHistory: Array<{ role: string; content: string }>;
  relevanceScore: number;
}

export interface RecallOutput {
  success: boolean;
  answer?: string;
  sessionReference?: {
    sessionId: string;
    title: string;
    date: string;
  };
  multipleMatches?: {
    sessions: Array<{
      sessionId: string;
      title: string;
      date: string;
      summary: string;
    }>;
    message: string;
  };
  noMatch?: {
    message: string;
    suggestNewResearch: boolean;
  };
}

/**
 * Handles recall requests - answers from past research sessions
 */
export async function handleRecall(input: RecallInput): Promise<RecallOutput> {
  console.log(`📚 [RECALL] Processing recall request for user ${input.userId}`);
  console.log(`📚 [RECALL] Question: "${input.question}"`);
  console.log(`📚 [RECALL] Matched sessions: ${input.matchedSessions.length}`);

  const startTime = Date.now();

  try {
    // CASE 1: No matches found
    if (input.matchedSessions.length === 0) {
      console.log('📚 [RECALL] No matched sessions found');
      return {
        success: true,
        noMatch: {
          message: 'Bu konuda daha önce bir araştırma kaydı bulamadım. Şimdi araştırayım mı?',
          suggestNewResearch: true
        }
      };
    }

    // Sort by relevance score (descending)
    const sortedSessions = [...input.matchedSessions].sort(
      (a, b) => b.relevanceScore - a.relevanceScore
    );

    const topSession = sortedSessions[0];
    const secondSession = sortedSessions[1];

    // CASE 2: Multiple good matches (scores are very close)
    if (
      sortedSessions.length > 1 &&
      secondSession &&
      Math.abs(topSession.relevanceScore - secondSession.relevanceScore) < 0.15
    ) {
      console.log(
        `📚 [RECALL] Multiple close matches detected (score diff: ${Math.abs(topSession.relevanceScore - secondSession.relevanceScore).toFixed(2)})`
      );

      const sessionList = sortedSessions.slice(0, 5).map((session) => ({
        sessionId: session.sessionId,
        title: session.title || 'Araştırma Oturumu',
        date: formatDate(session.createdAt),
        summary: session.summary || ''
      }));

      return {
        success: true,
        multipleMatches: {
          sessions: sessionList,
          message: 'Bu konuda birkaç araştırman var. Hangisinden bahsediyorsun?'
        }
      };
    }

    // CASE 3: Single strong match - generate answer from past conversation
    console.log(
      `📚 [RECALL] Single strong match found (score: ${topSession.relevanceScore.toFixed(2)})`
    );

    const answer = await generateAnswerFromSession(input.question, topSession);

    const duration = Date.now() - startTime;
    console.log(`✅ [RECALL] Answer generated in ${duration}ms`);

    return {
      success: true,
      answer: answer,
      sessionReference: {
        sessionId: topSession.sessionId,
        title: topSession.title || 'Araştırma Oturumu',
        date: formatDate(topSession.createdAt)
      }
    };
  } catch (error) {
    console.error('❌ [RECALL] Error processing recall request:', error);
    throw error;
  }
}

/**
 * Generates an answer from a past research session using LLM
 */
async function generateAnswerFromSession(
  currentQuestion: string,
  session: MatchedSession
): Promise<string> {
  // Format conversation history
  const conversationText = session.conversationHistory
    .map((msg) => {
      const role = msg.role === 'user' ? 'Kullanıcı' : 'Asistan';
      return `${role}: ${msg.content}`;
    })
    .join('\n\n');

  const formattedDate = formatDate(session.createdAt);

  // Build prompt for LLM
  const prompt = `Kullanıcı daha önce yaptığı bir araştırmayı hatırlamaya çalışıyor. İşte o araştırmanın tam konuşması:

Araştırma Başlığı: ${session.title || 'Araştırma Oturumu'}
Tarih: ${formattedDate}
${session.summary ? `Özet: ${session.summary}` : ''}

Önceki Konuşma:
${conversationText}

Kullanıcının Şu Anki Sorusu: "${currentQuestion}"

Yukarıdaki araştırma konuşmasından kullanıcının sorusunu cevaplayacak bilgiyi bul ve özetle. Hangi tarihte bu araştırmayı yaptığını da belirt. Doğrudan cevap ver, kullanıcının eski konuşmaya gitmesine gerek yok.

ÖNEMLI: Sadece yukarıdaki konuşmada geçen bilgileri kullan. Eğer soru bu konuşmayla ilgili değilse, bunu belirt ve yeni araştırma öner.`;

  console.log('📚 [RECALL] Generating answer with Gemini Flash');

  const result = await ai.generate({
    model: getFlashModel(),
    config: {
      temperature: 0.3, // Lower temperature for factual recall
      maxOutputTokens: 1024
    },
    prompt: prompt
  });

  return result.text;
}

/**
 * Formats ISO 8601 timestamp to Turkish date format
 * Example: "2024-10-05T14:30:00Z" -> "5 Ekim 2024"
 */
function formatDate(isoDate: string): string {
  const date = new Date(isoDate);

  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];

  const day = date.getDate();
  const month = months[date.getMonth()];
  const year = date.getFullYear();

  return `${day} ${month} ${year}`;
}
