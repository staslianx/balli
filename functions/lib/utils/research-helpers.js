"use strict";
/**
 * Research Helper Functions
 * Shared utilities for research search functionality
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateRelatedQuestions = generateRelatedQuestions;
exports.calculateConfidence = calculateConfidence;
exports.mapCredibilityLevel = mapCredibilityLevel;
exports.formatSourcesWithTypes = formatSourcesWithTypes;
/**
 * Generate contextual follow-up questions using AI based on the query and answer
 * @param ai - Genkit AI instance
 * @param model - Model reference to use for generation
 * @param query - Original user query
 * @param answer - The generated answer
 * @param strategy - Search strategy used (direct_knowledge, medical_sources, deep_research)
 * @returns Promise resolving to array of 3 contextual questions in Turkish
 */
async function generateRelatedQuestions(ai, model, query, answer, strategy) {
    try {
        const prompt = `Kullanıcının şu sorusunu ve aldığı cevabı analiz et:

SORU: ${query}

CEVAP: ${answer.substring(0, 1200)}...

ÖNEMLİ: Bu SPESİFİK soruda bahsedilen konuyla doğrudan ilgili 3 takip sorusu üretmelisin.

YANLIŞ ÖRNEKLER (Generic, genel sorular - BUNLARI YAPMA):
❌ "Diabetes hakkında daha fazla bilgi alabilir miyim?"
❌ "Glükoz kontrolü için ne yapmalıyım?"
❌ "İnsülin dozumu nasıl ayarlarım?"

DOĞRU ÖRNEKLER (Kullanıcının sorusuna özel):
Eğer soru "Sigara ile şeker hastalığı arasında bir bağlantı var mı?" ise:
✅ "Sigara bırakmanın glükoz kontrolü üzerindeki etkileri ne kadar sürede görülür?"
✅ "Pasif içicilik de diyabet riskini artırır mı?"
✅ "E-sigara kullanımı normal sigaraya göre daha mı az riskli?"

Şimdi kullanıcının yukarıdaki SPESİFİK sorusuna özel 3 takip sorusu üret. Sorular:
- Kullanıcının tam olarak sorduğu konuyla (yukarıdaki SORU'da geçen kavramlarla) DOĞRUDAN ilgili olmalı
- Konuyu derinleştirmeli veya farklı açılardan ele almalı
- Türkçe, net ve özgün olmalı
- Her biri tek satır ve soru işaretiyle bitmeli
- GENERİK diabetes soruları değil, bu SPESİFİK konuyla ilgili sorular olmalı

Sadece 3 soruyu listele, başka açıklama ekleme.`;
        const response = await ai.generate({
            model: model,
            prompt: [{ text: prompt }],
            config: {
                temperature: 0.5, // More focused, less generic responses
                maxOutputTokens: 200
            }
        });
        // Parse the response to extract questions
        const text = response.text || '';
        // Remove markdown formatting and split into lines
        const lines = text.split('\n')
            .map(line => {
            // Remove numbered list markers (1., 2., 3., etc.)
            line = line.replace(/^\d+\.\s*/, '');
            // Remove bullet points (-, *, •)
            line = line.replace(/^[-*•]\s*/, '');
            // Remove markdown bold/italic
            line = line.replace(/[*_]/g, '');
            // Trim whitespace
            return line.trim();
        })
            .filter(line => line.length > 10 && line.includes('?')); // At least 10 chars and has ?
        // Take first 3 valid questions, or fall back to generic ones
        const questions = lines.slice(0, 3);
        if (questions.length >= 3) {
            console.log(`✅ [RELATED-QUESTIONS] Generated ${questions.length} contextual questions for: "${query.substring(0, 50)}..."`);
            console.log(`✅ [RELATED-QUESTIONS] Questions: ${JSON.stringify(questions)}`);
            return questions;
        }
        else {
            console.log(`⚠️ [RELATED-QUESTIONS] AI generated only ${questions.length} questions, using fallback`);
            console.log(`⚠️ [RELATED-QUESTIONS] Raw response: "${text.substring(0, 300)}"`);
            return getFallbackQuestions(strategy);
        }
    }
    catch (error) {
        console.error('❌ [RELATED-QUESTIONS] Error generating questions:', error.message);
        return getFallbackQuestions(strategy);
    }
}
/**
 * Fallback generic questions if AI generation fails
 */
function getFallbackQuestions(strategy) {
    if (strategy === 'medical_sources' || strategy === 'deep_research' || strategy === 'DEEP_RESEARCH') {
        return [
            'Bu bilgiler güncel mi? En son araştırmalar ne diyor?',
            'Bu konuda başka neler bilmeliyim?',
            'Kişisel durumuma nasıl uyarlayabilirim?'
        ];
    }
    else {
        return [
            'Bu konuda daha detaylı bilgi alabilir miyim?',
            'İlgili başka hangi faktörleri göz önünde bulundurmalıyım?',
            'Günlük hayatta nasıl uygulayabilirim?'
        ];
    }
}
/**
 * Calculate confidence level based on strategy and source count
 * @param strategy - Search strategy used
 * @param sourceCount - Number of sources found
 * @returns Confidence level 0-100
 */
function calculateConfidence(strategy, sourceCount) {
    // Higher confidence when backed by sources
    if ((strategy === 'deep_research' || strategy === 'DEEP_RESEARCH') && sourceCount >= 3)
        return 95;
    if ((strategy === 'medical_sources' || strategy === 'WEB_SEARCH') && sourceCount >= 2)
        return 90;
    if (strategy === 'direct_knowledge' || strategy === 'MODEL')
        return 85; // Still high, just no external validation
    return 75; // Default
}
/**
 * Map credibility level from API response to UI badge
 * @param level - Credibility level from API
 * @returns UI credibility badge type
 */
function mapCredibilityLevel(level) {
    switch (level) {
        case 'medical_institution':
            return 'medical_source';
        case 'peer_reviewed':
            return 'peer_reviewed';
        case 'expert_authored':
            return 'expert';
        default:
            return 'expert';
    }
}
/**
 * Format research sources with type information
 * Combines results from all APIs into a unified format for client
 *
 * @param exa - Exa search results (trusted medical websites)
 * @param pubmed - PubMed article results
 * @param arxiv - arXiv paper results
 * @param clinicalTrials - ClinicalTrials.gov results
 * @returns Array of formatted sources with type metadata
 */
function formatSourcesWithTypes(exa, pubmed, medrxiv, clinicalTrials) {
    const sources = [];
    // Add Exa sources
    for (const result of exa) {
        sources.push({
            title: result.title,
            url: result.url,
            type: 'exaWeb',
            snippet: result.snippet,
            credibilityLevel: result.credibilityLevel,
            journal: result.domain,
            year: result.publishedDate || undefined,
            authors: result.author || undefined
        });
    }
    // Add PubMed sources
    for (const article of pubmed) {
        sources.push({
            title: article.title,
            url: article.url,
            type: 'pubmed',
            authors: article.authors.slice(0, 3).join(', ') + (article.authors.length > 3 ? ' et al.' : ''),
            journal: article.journal,
            year: article.publishDate.split('-')[0], // Extract year from date
            snippet: article.abstract.substring(0, 300)
        });
    }
    // Add medRxiv sources
    for (const paper of medrxiv) {
        sources.push({
            title: paper.title,
            url: paper.url,
            type: 'medrxiv',
            authors: paper.authors,
            journal: 'medRxiv (preprint)',
            year: paper.date.split('-')[0], // Extract year from date
            snippet: paper.abstract.substring(0, 300)
        });
    }
    // Add ClinicalTrials sources
    for (const trial of clinicalTrials) {
        sources.push({
            title: trial.title,
            url: trial.url,
            type: 'clinicalTrial',
            journal: 'ClinicalTrials.gov',
            year: trial.startDate?.split('-')[0], // Extract year from start date
            snippet: trial.summary.substring(0, 300)
        });
    }
    console.log(`📋 [RESEARCH-HELPERS] Formatted ${sources.length} sources: ` +
        `Exa: ${exa.length}, PubMed: ${pubmed.length}, medRxiv: ${medrxiv.length}, Trials: ${clinicalTrials.length}`);
    return sources;
}
//# sourceMappingURL=research-helpers.js.map