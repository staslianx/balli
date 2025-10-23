"use strict";
/**
 * Source Deduplicator - Cross-Round Deduplication
 * Tracks and filters duplicate sources across multiple research rounds
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SourceDeduplicator = void 0;
const v2_1 = require("firebase-functions/v2");
/**
 * Source Deduplication Tracker
 * Maintains set of seen identifiers across rounds
 */
class SourceDeduplicator {
    seenIdentifiers = new Set();
    duplicateCount = 0;
    /**
     * Extract unique identifier from a source
     * Priority: DOI > PubMed ID > medRxiv DOI > URL
     */
    extractIdentifier(source) {
        // PubMed articles
        if ('pmid' in source && source.pmid) {
            return { type: 'pubmed', value: source.pmid };
        }
        // DOI (multiple source types including medRxiv)
        if ('doi' in source && source.doi) {
            return { type: 'doi', value: source.doi.toLowerCase() };
        }
        // Clinical trials (use NCT ID if available)
        if ('nctId' in source && source.nctId) {
            return { type: 'url', value: `clinicaltrials:${source.nctId}` };
        }
        // Fallback to URL (all source types have URL)
        if ('url' in source && source.url) {
            try {
                // Normalize URL (remove query params, trailing slash, www)
                const url = new URL(source.url);
                const normalized = `${url.protocol}//${url.hostname.replace(/^www\./, '')}${url.pathname}`.replace(/\/$/, '');
                return { type: 'url', value: normalized };
            }
            catch {
                return { type: 'url', value: source.url };
            }
        }
        return null;
    }
    /**
     * Convert identifier to string key for Set
     */
    identifierToKey(identifier) {
        return `${identifier.type}:${identifier.value}`;
    }
    /**
     * Check if a source has been seen before
     */
    isSeen(source) {
        const identifier = this.extractIdentifier(source);
        if (!identifier) {
            return false; // Can't identify, assume not seen
        }
        const key = this.identifierToKey(identifier);
        return this.seenIdentifiers.has(key);
    }
    /**
     * Mark a source as seen
     */
    markSeen(source) {
        const identifier = this.extractIdentifier(source);
        if (identifier) {
            const key = this.identifierToKey(identifier);
            this.seenIdentifiers.add(key);
        }
    }
    /**
     * Filter duplicates from PubMed results
     */
    filterPubMed(articles) {
        const unique = [];
        const duplicates = [];
        for (const article of articles) {
            if (this.isSeen(article)) {
                duplicates.push(article.pmid || article.title.substring(0, 50));
                this.duplicateCount++;
            }
            else {
                unique.push(article);
                this.markSeen(article);
            }
        }
        if (duplicates.length > 0) {
            v2_1.logger.debug(`📋 [DEDUP] Filtered ${duplicates.length} duplicate PubMed articles`);
        }
        return unique;
    }
    /**
     * Filter duplicates from medRxiv results
     */
    filterMedRxiv(papers) {
        const unique = [];
        const duplicates = [];
        for (const paper of papers) {
            if (this.isSeen(paper)) {
                duplicates.push(paper.doi || paper.title.substring(0, 50));
                this.duplicateCount++;
            }
            else {
                unique.push(paper);
                this.markSeen(paper);
            }
        }
        if (duplicates.length > 0) {
            v2_1.logger.debug(`📋 [DEDUP] Filtered ${duplicates.length} duplicate arXiv papers`);
        }
        return unique;
    }
    /**
     * Filter duplicates from Clinical Trials results
     */
    filterClinicalTrials(trials) {
        const unique = [];
        const duplicates = [];
        for (const trial of trials) {
            if (this.isSeen(trial)) {
                duplicates.push(trial.nctId || trial.title.substring(0, 50));
                this.duplicateCount++;
            }
            else {
                unique.push(trial);
                this.markSeen(trial);
            }
        }
        if (duplicates.length > 0) {
            v2_1.logger.debug(`📋 [DEDUP] Filtered ${duplicates.length} duplicate clinical trials`);
        }
        return unique;
    }
    /**
     * Filter duplicates from Exa results
     */
    filterExa(results) {
        const unique = [];
        const duplicates = [];
        for (const result of results) {
            if (this.isSeen(result)) {
                duplicates.push(new URL(result.url).hostname);
                this.duplicateCount++;
            }
            else {
                unique.push(result);
                this.markSeen(result);
            }
        }
        if (duplicates.length > 0) {
            v2_1.logger.debug(`📋 [DEDUP] Filtered ${duplicates.length} duplicate Exa sources`);
        }
        return unique;
    }
    /**
     * Get statistics
     */
    getStats() {
        return {
            totalSeen: this.seenIdentifiers.size,
            duplicatesFiltered: this.duplicateCount
        };
    }
    /**
     * Log deduplication summary
     */
    logSummary() {
        const stats = this.getStats();
        v2_1.logger.info(`📋 [DEDUP] Summary: ${stats.totalSeen} unique sources tracked, ` +
            `${stats.duplicatesFiltered} duplicates filtered`);
    }
}
exports.SourceDeduplicator = SourceDeduplicator;
//# sourceMappingURL=source-deduplicator.js.map