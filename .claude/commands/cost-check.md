---
description: Analyze Gemini API costs in this personal health app and suggest optimizations
allowed-tools: [view, bash]
---

# Cost Efficiency Analysis for Personal App

Analyze the codebase's usage of Google Gemini models via Firebase Genkit and Vertex AI with focus on cost optimization for a **personal, non-enterprise application**.

## Context
This is a personal health management app, not an enterprise product. Cost optimization should balance:
- Reasonable functionality for personal use
- Avoiding unnecessary API calls
- Smart use of cheaper models where appropriate
- No need for enterprise-level redundancy or over-engineering

## Analysis Steps

1. **Find all Gemini API calls**
   - Search for Genkit flow definitions
   - Identify model usage (Flash vs Pro variants)
   - Check prompt configurations

2. **Evaluate current usage patterns**
   - Which features use which models?
   - Are prompts unnecessarily long?
   - Any duplicate/redundant calls?
   - Streaming vs non-streaming usage

3. **Assess model selection**
   - Is Gemini 2.5 Flash being used where possible?
   - Are any features using more expensive models unnecessarily?
   - Could any features use smaller context windows?

4. **Check for inefficiencies**
   - Repeated API calls for same data
   - Missing caching opportunities
   - Overly verbose system prompts
   - Unnecessary token usage in responses

5. **Provide personal-app appropriate recommendations**
   - Practical optimizations that make sense for a solo developer
   - Don't suggest complex caching infrastructure unless truly needed
   - Focus on simple wins: shorter prompts, cheaper models where viable
   - Flag any obvious cost sinks

## Output Format

**Current Cost Drivers:**
- List top 3-5 features/flows by likely cost impact

**Quick Wins:**
- Simple changes that reduce costs immediately

**Model Selection Review:**
- Are you using the cheapest model that works?
- Specific suggestions for model downgrades

**Prompt Optimization:**
- Unnecessarily long system/user prompts
- Redundant instructions

**Architecture Concerns:**
- Any patterns causing repeated calls?
- Missing obvious caching opportunities?

**Personal App Reality Check:**
- Are you over-engineering anything?
- What's "good enough" for personal use?

Remember: This is your personal app. Perfect isn't necessary - functional and affordable is.