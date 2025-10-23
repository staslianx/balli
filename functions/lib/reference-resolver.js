"use strict";
/**
 * Reference Resolver
 *
 * Resolves detected references to specific entities/concepts
 * using conversation state and builds explicit guidance for AI.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveReferences = resolveReferences;
exports.buildContextGuidance = buildContextGuidance;
/**
 * Resolve all detected references using conversation state
 */
function resolveReferences(message, references, state) {
    const resolved = [];
    for (const ref of references) {
        switch (ref.type) {
            case 'ellipsis':
                resolved.push(resolveEllipsis(message, ref, state));
                break;
            case 'definite':
                resolved.push(resolveDefiniteReference(message, ref, state));
                break;
            case 'comparative':
                resolved.push(resolveComparative(message, ref, state));
                break;
            case 'temporal':
                resolved.push(resolveTemporal(message, ref, state));
                break;
            case 'ai_output':
                resolved.push(resolveAIOutput(message, ref, state));
                break;
            case 'causality':
                resolved.push(resolveCausality(message, ref, state));
                break;
            case 'evaluation':
                resolved.push(resolveEvaluation(message, ref, state));
                break;
            case 'modal':
                resolved.push(resolveModal(message, ref, state));
                break;
            case 'memory_recall':
                resolved.push(resolveMemoryRecall(message, ref, state));
                break;
            // Add other categories as needed
            default:
                // No specific resolution needed
                break;
        }
    }
    return resolved;
}
/**
 * Resolve elliptical constructions
 * Category 1: Restore omitted elements from discourse state
 */
function resolveEllipsis(message, ref, state) {
    const lastQ = state.discourse.lastQuestion;
    if (!lastQ) {
        return {
            originalPattern: ref.pattern,
            resolvedTo: message,
            contextGuidance: `User's message "${message}" is elliptical but no previous question context available. Treat as standalone question.`,
            sourceLayer: 'discourse'
        };
    }
    // Restore full question form
    let fullForm = message;
    let guidance = '';
    // Pattern: "Ya akşam?" → "Ya akşam yemeğinde ne yemeli?"
    if (message.toLowerCase().startsWith('ya ')) {
        fullForm = `${message} ${lastQ.subject} ${lastQ.verb}`;
        guidance = `User asks "${message}" which is elliptical for "${fullForm}" (continuing previous question about ${lastQ.subject})`;
    }
    // Pattern: Just question word "Neden?"
    else if (message.match(/^(neden|nasıl|ne\s+zaman)\??$/i)) {
        fullForm = `${message} ${lastQ.subject} ${lastQ.verb}`;
        guidance = `User asks "${message}" which means "${fullForm}" (asking about previous topic: ${lastQ.subject})`;
    }
    // Pattern: Modal without action "Yapmalı mıyım?"
    else if (message.match(/(yapmalı|etmeli|vurmalı|yemeli)\s+m[ıiuü]y[ıi]m/i)) {
        fullForm = `${lastQ.subject} ${message}`;
        guidance = `User asks "${message}" which means "${fullForm}" (the action is about ${lastQ.subject})`;
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: fullForm,
        contextGuidance: guidance || `Elliptical question restored to: ${fullForm}`,
        sourceLayer: 'discourse'
    };
}
/**
 * Resolve definite references (pronouns, demonstratives)
 * Category 2: Map pronouns to specific entities
 */
function resolveDefiniteReference(message, ref, state) {
    const lowerMessage = message.toLowerCase();
    // Get most salient entity (highest salience score)
    const mostSalient = getMostSalientEntity(state);
    if (!mostSalient) {
        return {
            originalPattern: ref.pattern,
            resolvedTo: 'unknown',
            contextGuidance: `User uses pronoun "${ref.pattern}" but no clear antecedent in conversation. May need clarification.`,
            sourceLayer: 'entities'
        };
    }
    // Detect specific pronoun patterns
    let guidance = '';
    if (lowerMessage.includes('bunların')) {
        // Plural possessive - usually refers to most salient entity (plural or collective)
        guidance = `User says "bunların" (of these) which refers to "${mostSalient.name}" mentioned ${mostSalient.turnDelta} turns ago.`;
    }
    else if (lowerMessage.includes('onun')) {
        // Singular possessive
        guidance = `User says "onun" (its/that one's) which refers to "${mostSalient.name}" mentioned ${mostSalient.turnDelta} turns ago.`;
    }
    else if (lowerMessage.includes('onu') || lowerMessage.includes('bunu')) {
        // Accusative - direct object
        guidance = `User says "${ref.pattern}" (it/this) which refers to "${mostSalient.name}".`;
    }
    else if (lowerMessage.match(/\b(bu|o|şu)\s+(\w+)/)) {
        // Demonstrative + noun
        const match = lowerMessage.match(/\b(bu|o|şu)\s+(\w+)/);
        guidance = `User says "${match[0]}" which likely refers to the ${match[2]} related to "${mostSalient.name}".`;
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: mostSalient.name,
        contextGuidance: guidance,
        sourceLayer: 'entities'
    };
}
/**
 * Resolve comparative references
 * Category 3: Find comparison base
 */
function resolveComparative(message, ref, state) {
    const lowerMessage = message.toLowerCase();
    // Check for quantity comparisons
    if (lowerMessage.includes('daha fazla') || lowerMessage.includes('daha az')) {
        const mostSalient = getMostSalientEntity(state);
        const lastMeasurement = state.entities.measurements[state.entities.measurements.length - 1];
        let base = 'unknown';
        let guidance = '';
        if (lastMeasurement) {
            base = `${lastMeasurement.value} ${lastMeasurement.unit}`;
            guidance = `User asks about "more/less" which compares to the previous ${lastMeasurement.type} value of ${base}.`;
        }
        else if (mostSalient) {
            base = mostSalient.name;
            guidance = `User asks about "more/less" referring to ${base}.`;
        }
        return {
            originalPattern: ref.pattern,
            resolvedTo: base,
            contextGuidance: guidance,
            sourceLayer: 'entities'
        };
    }
    // Check for "farkı ne?" (what's the difference?)
    if (lowerMessage.includes('fark')) {
        const recentEntities = state.entities.medications
            .concat(state.entities.foods)
            .filter(e => e.salience > 0.5)
            .slice(0, 2);
        if (recentEntities.length >= 2) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: recentEntities.map(e => e.name).join(' vs '),
                contextGuidance: `User asks about difference between "${recentEntities[0].name}" and "${recentEntities[1].name}".`,
                sourceLayer: 'entities'
            };
        }
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: 'comparison needed',
        contextGuidance: `User is making a comparison but comparison base is unclear.`,
        sourceLayer: 'entities'
    };
}
/**
 * Resolve temporal references
 * Category 4: Find what was said/happened before/after
 */
function resolveTemporal(message, ref, state) {
    const lowerMessage = message.toLowerCase();
    if (lowerMessage.includes('daha önce')) {
        // "What did you say before?"
        const lastStatement = state.discourse.lastStatement;
        if (lastStatement) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: lastStatement.claim,
                contextGuidance: `User refers to "before/earlier" - they mean: "${lastStatement.claim}" (said by ${lastStatement.by} at turn ${lastStatement.turn})`,
                sourceLayer: 'discourse'
            };
        }
    }
    if (lowerMessage.includes('hala') || lowerMessage.includes('hâlâ')) {
        // "Is it still...?" - requires previous state
        const lastMeasurement = state.entities.measurements[state.entities.measurements.length - 1];
        if (lastMeasurement) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: `${lastMeasurement.value} ${lastMeasurement.unit}`,
                contextGuidance: `User asks if "still" - referring to previous ${lastMeasurement.type} of ${lastMeasurement.value} ${lastMeasurement.unit}`,
                sourceLayer: 'entities'
            };
        }
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: 'temporal reference',
        contextGuidance: `User makes temporal reference but previous context unclear.`,
        sourceLayer: 'discourse'
    };
}
/**
 * Resolve AI output references
 * Category 6: Find what AI said/recommended/listed
 */
function resolveAIOutput(message, ref, state) {
    const lowerMessage = message.toLowerCase();
    // Check for ordinal references to lists
    if (lowerMessage.match(/\b(ilk|birinci|first)\b/i)) {
        const lastList = state.aiOutputs.listsPresented[state.aiOutputs.listsPresented.length - 1];
        if (lastList && lastList.items.length > 0) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: lastList.items[0],
                contextGuidance: `User refers to "first option/item" which is "${lastList.items[0]}" from the list of ${lastList.context} I provided.`,
                sourceLayer: 'aiOutputs'
            };
        }
    }
    if (lowerMessage.match(/\b(ikinci|second)\b/i)) {
        const lastList = state.aiOutputs.listsPresented[state.aiOutputs.listsPresented.length - 1];
        if (lastList && lastList.items.length > 1) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: lastList.items[1],
                contextGuidance: `User refers to "second option/item" which is "${lastList.items[1]}" from my list.`,
                sourceLayer: 'aiOutputs'
            };
        }
    }
    // Check for references to AI's recommendations
    if (lowerMessage.includes('önerdiğin') || lowerMessage.includes('söylediğin')) {
        const lastRec = state.aiOutputs.recommendations[state.aiOutputs.recommendations.length - 1];
        if (lastRec) {
            return {
                originalPattern: ref.pattern,
                resolvedTo: lastRec.what,
                contextGuidance: `User refers to "what you recommended/said" which is: "${lastRec.what}" (reason: ${lastRec.reason})`,
                sourceLayer: 'aiOutputs'
            };
        }
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: 'AI output reference',
        contextGuidance: `User references something I said but I cannot find specific content.`,
        sourceLayer: 'aiOutputs'
    };
}
/**
 * Resolve causality questions
 * Category 12: Find what they're asking "why" about
 */
function resolveCausality(message, ref, state) {
    const lastStatement = state.discourse.lastStatement;
    if (!lastStatement) {
        return {
            originalPattern: ref.pattern,
            resolvedTo: 'unknown',
            contextGuidance: `User asks "why" but no previous statement to explain.`,
            sourceLayer: 'discourse'
        };
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: lastStatement.claim,
        contextGuidance: `User asks "why/because" about: "${lastStatement.claim}" - explain the reasoning for this.`,
        sourceLayer: 'discourse'
    };
}
/**
 * Resolve evaluation questions
 * Category 11: Find what they're evaluating
 */
function resolveEvaluation(message, ref, state) {
    const mostSalient = getMostSalientEntity(state);
    if (!mostSalient) {
        return {
            originalPattern: ref.pattern,
            resolvedTo: 'unknown',
            contextGuidance: `User asks if something is good/bad/safe but subject is unclear.`,
            sourceLayer: 'entities'
        };
    }
    const evalType = message.match(/\b(iyi|kötü|zararlı|güvenli|etkili)\b/i)?.[0] || 'quality';
    return {
        originalPattern: ref.pattern,
        resolvedTo: mostSalient.name,
        contextGuidance: `User asks if "${mostSalient.name}" is ${evalType}. Evaluate ${mostSalient.name} based on this criterion.`,
        sourceLayer: 'entities'
    };
}
/**
 * Resolve modal/necessity questions
 * Category 13: Find what action is obligatory/permitted
 */
function resolveModal(message, ref, state) {
    const lastQ = state.discourse.lastQuestion;
    if (lastQ) {
        return {
            originalPattern: ref.pattern,
            resolvedTo: lastQ.subject,
            contextGuidance: `User asks if necessary/allowed regarding: ${lastQ.subject}`,
            sourceLayer: 'discourse'
        };
    }
    return {
        originalPattern: ref.pattern,
        resolvedTo: 'action unclear',
        contextGuidance: `User asks about necessity/permission but action is unclear.`,
        sourceLayer: 'discourse'
    };
}
/**
 * Resolve memory recall requests
 * Category 20: Search for specific past conversation
 */
function resolveMemoryRecall(message, ref, state) {
    // Extract what they're trying to remember
    const searchTerm = message.replace(/hatırlıyor\s+musun|hatırla|hani/gi, '').trim();
    return {
        originalPattern: ref.pattern,
        resolvedTo: searchTerm,
        contextGuidance: `User explicitly asks if I remember: "${searchTerm}". Search conversation history for this topic and confirm/recall the information.`,
        sourceLayer: 'commitments'
    };
}
/**
 * Get most salient entity across all entity types
 */
function getMostSalientEntity(state) {
    const allEntities = [
        ...state.entities.medications.map(e => ({ ...e, type: 'medication' })),
        ...state.entities.foods.map(e => ({ ...e, type: 'food' })),
        ...state.entities.symptoms.map(e => ({ ...e, type: 'symptom' })),
        ...state.entities.exercises.map(e => ({ ...e, type: 'exercise' })),
        ...state.entities.medicalTerms.map(e => ({ ...e, type: 'medical_term' }))
    ];
    if (allEntities.length === 0) {
        return null;
    }
    const sorted = allEntities.sort((a, b) => b.salience - a.salience);
    const most = sorted[0];
    return {
        name: most.name,
        salience: most.salience,
        type: most.type,
        turnDelta: state.turnCount - most.mentionedTurn
    };
}
/**
 * Build comprehensive context guidance from all resolved references
 */
function buildContextGuidance(resolved) {
    if (resolved.length === 0) {
        return '';
    }
    const guidance = resolved
        .map(r => r.contextGuidance)
        .filter(g => g.length > 0)
        .join('\n');
    return `
REFERENCE RESOLUTION GUIDANCE:
${guidance}

Use this guidance to correctly interpret the user's message.
`;
}
//# sourceMappingURL=reference-resolver.js.map