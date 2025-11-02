# API Cost Tracking System

## Overview

Complete cost tracking system for monitoring Vertex AI API usage across all features in the Balli Diabetes Assistant app.

## Architecture

### Backend (Firebase Cloud Functions)

```
functions/src/cost-tracking/
├── model-pricing.ts          # Pricing data for all models
├── cost-tracker.ts            # Core tracking logic with Firestore
└── cost-reporter.ts           # Reporting and analytics functions
```

### Frontend (iOS)

```
balli/Features/CostTracking/
├── Models/CostReport.swift
├── Services/CostTrackingService.swift
└── Views/CostDashboardView.swift
```

## Features Tracked

### 1. Recipe Generation
- **Model:** Gemini 2.5 Flash
- **Cost:** ~$0.0015 per recipe
- **Tracks:** Input/output tokens, meal type, style

### 2. Image Generation
- **Model:** Imagen 4.0 Ultra
- **Cost:** $0.04 per image
- **Tracks:** Image count, aspect ratio, quality level

### 3. Research (3-Tier System)

**Tier 1 - Fast Response:**
- **Model:** Gemini 2.5 Flash-Lite
- **Cost:** ~$0.0002 per query
- **Use:** Simple Q&A

**Tier 2 - Web Search:**
- **Model:** Gemini 2.5 Flash + Exa API
- **Cost:** ~$0.003 per query
- **Use:** Current information queries

**Tier 3 - Deep Research:**
- **Model:** Gemini 2.5 Pro
- **Cost:** ~$0.015 per query
- **Use:** Medical research synthesis

### 4. Nutrition Calculation
- **Model:** Gemini 2.5 Flash (Vision)
- **Cost:** ~$0.001 per scan
- **Tracks:** Image + text tokens

### 5. Chat Assistant
- **Model:** Gemini 2.5 Flash
- **Cost:** Variable based on conversation length
- **Tracks:** Multi-turn conversations

### 6. Voice Meal Logging
- **Model:** Gemini 2.5 Flash
- **Cost:** ~$0.0005 per transcription

## Firestore Schema

### Collection: `cost_tracking/usage_logs/logs`

```typescript
{
  featureName: string,          // "recipe_generation", "research_deep_t3", etc.
  modelName: string,            // "gemini-2.5-flash", "imagen-4.0-ultra", etc.
  inputTokens: number,          // Input token count
  outputTokens: number,         // Output token count
  costUSD: number,              // Calculated cost in USD
  timestamp: Timestamp,         // When the API call was made
  userId?: string,              // Optional user identifier
  metadata?: {
    // Feature-specific metadata
    mealType?: string,
    rounds?: number,
    sourceCount?: number,
    etc...
  }
}
```

### Collection: `cost_tracking/daily_summaries/summaries`

```typescript
{
  date: string,                 // "YYYY-MM-DD"
  totalCost: number,            // Total cost for the day
  byFeature: {
    [featureName]: number       // Cost breakdown by feature
  },
  byModel: {
    [modelName]: number         // Cost breakdown by model
  },
  requestCount: number,         // Total API calls
  lastUpdated: Timestamp
}
```

## Cloud Functions Endpoints

### 1. `getTodayCosts`
Returns cost summary for today.

**Request:**
```bash
GET https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getTodayCosts
```

**Response:**
```json
{
  "success": true,
  "data": {
    "period": "daily",
    "startDate": "2025-11-02",
    "endDate": "2025-11-02",
    "totalCost": 0.0247,
    "byFeature": {
      "recipe_generation": 0.0120,
      "research_deep_t3": 0.0090,
      "nutrition_calculation": 0.0037
    },
    "byModel": {
      "gemini-2.5-flash": 0.0157,
      "gemini-2.5-pro": 0.0090
    },
    "requestCount": 15,
    "averageCostPerRequest": 0.001647
  }
}
```

### 2. `getWeeklyCosts`
Returns cost summary for current week (Mon-Sun).

**Request:**
```bash
GET https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getWeeklyCosts
```

### 3. `getMonthlyCosts`
Returns cost summary for current month.

**Request:**
```bash
GET https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getMonthlyCosts
```

### 4. `getFeatureCosts`
Returns detailed feature comparison.

**Request:**
```bash
GET https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getFeatureCosts?days=7
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "feature": "recipe_generation",
      "totalCost": 0.0480,
      "requestCount": 32,
      "averageCostPerRequest": 0.0015,
      "percentOfTotal": 48.6
    },
    {
      "feature": "research_deep_t3",
      "totalCost": 0.0360,
      "requestCount": 24,
      "averageCostPerRequest": 0.0150,
      "percentOfTotal": 36.4
    }
  ]
}
```

## Model Pricing (as of November 2024)

### Token-Based Models

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Gemini 2.5 Flash-Lite | $0.0375 | $0.15 |
| Gemini 2.5 Flash | $0.075 | $0.30 |
| Gemini 2.5 Pro | $1.25 | $5.00 |
| Text Embedding 004 | $0.02 | - |

### Image Models

| Model | Cost per Image |
|-------|----------------|
| Imagen 3.0 | $0.02 |
| Imagen 4.0 Ultra | $0.04 |

## iOS Integration

### 1. Add to Your App

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationLink("API Cost Tracking") {
            CostDashboardView()
        }
    }
}
```

### 2. Custom Base URL (for testing)

```swift
@StateObject private var service = CostTrackingService(
    baseURL: "http://localhost:5001/balli-diabetes-assistant/us-central1"
)
```

## Example Cost Estimates

Based on typical usage patterns:

### Daily Usage (10 active users)

| Feature | Calls | Cost/Call | Daily Cost |
|---------|-------|-----------|------------|
| Recipe Generation | 20 | $0.0015 | $0.03 |
| Image Generation | 10 | $0.04 | $0.40 |
| Tier 1 Chat | 100 | $0.0002 | $0.02 |
| Tier 2 Research | 15 | $0.003 | $0.045 |
| Tier 3 Research | 5 | $0.015 | $0.075 |
| Nutrition Scan | 30 | $0.001 | $0.03 |
| **TOTAL** | **180** | - | **$0.60/day** |

### Monthly Projection

- **Daily:** $0.60
- **Weekly:** $4.20
- **Monthly:** $18.00
- **Yearly:** $219.00

## Cost Optimization Tips

### 1. Use Tier Routing Wisely
- Tier 1 is 75x cheaper than Tier 3
- Only use Tier 3 for medical research requiring high accuracy

### 2. Cache Recipe Images
- Imagen 4.0 Ultra is the most expensive ($0.04/image)
- Cache generated images to avoid regeneration

### 3. Monitor Feature Usage
- Check `getFeatureCosts` weekly
- Identify unexpected usage spikes
- Optimize high-cost features first

### 4. Set Budget Alerts
Add Firestore triggers for daily cost thresholds:

```typescript
// functions/src/budget-monitor.ts
export const checkDailyBudget = functions.firestore
  .document('cost_tracking/daily_summaries/summaries/{date}')
  .onWrite(async (change, context) => {
    const data = change.after.data();
    if (data.totalCost > 5.00) {
      // Send alert to admin
      console.warn(`🚨 Daily budget exceeded: $${data.totalCost}`);
    }
  });
```

## Deployment

### 1. Deploy Functions

```bash
cd functions
npm run build
firebase deploy --only functions:getTodayCosts,functions:getWeeklyCosts,functions:getMonthlyCosts,functions:getFeatureCosts
```

### 2. Verify Deployment

```bash
# Test today's costs
curl https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getTodayCosts

# Test feature comparison
curl https://us-central1-balli-diabetes-assistant.cloudfunctions.net/getFeatureCosts?days=7
```

## Troubleshooting

### No Data Showing

1. **Check Firestore Rules:**
```javascript
match /cost_tracking/{document=**} {
  allow read: if request.auth != null; // Adjust as needed
  allow write: if false; // Only Cloud Functions write
}
```

2. **Verify Functions are Tracking:**
```bash
firebase functions:log --only getTodayCosts
```

3. **Check Console:**
Look for `Cost tracked:` logs in Cloud Functions console

### Costs Not Matching Expectations

1. **Verify Model Names:**
Check `model-pricing.ts` has correct model names

2. **Check Token Extraction:**
Look for `Token usage:` logs

3. **Validate Calculations:**
```typescript
const cost = (inputTokens / 1_000_000) * $0.075 + (outputTokens / 1_000_000) * $0.30
```

## Monitoring Dashboard

The iOS dashboard provides:

✅ Real-time cost tracking
✅ Period summaries (Today, Week, Month)
✅ Feature-by-feature breakdown
✅ Cost per request analytics
✅ Percentage distribution
✅ Refresh on demand

## Security Considerations

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cost tracking data - read only for authenticated users
    match /cost_tracking/{document=**} {
      allow read: if request.auth != null && request.auth.token.admin == true;
      allow write: if false; // Only Cloud Functions
    }
  }
}
```

### API Endpoints

Consider adding admin authentication:

```typescript
export const getTodayCosts = onRequest({
  timeoutSeconds: 30,
  memory: '256MiB'
}, async (req, res) => {
  // Add admin check
  const adminToken = req.headers.authorization;
  if (!isValidAdminToken(adminToken)) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }

  // ... rest of implementation
});
```

## Future Enhancements

### 1. Budget Alerts
- Email notifications when daily budget exceeded
- SMS alerts for critical thresholds

### 2. Cost Predictions
- ML-based cost forecasting
- Trend analysis and anomaly detection

### 3. User-Level Tracking
- Per-user cost attribution
- Usage quotas and limits

### 4. Real-time Dashboard
- Live cost monitoring
- WebSocket updates

### 5. Export Functionality
- CSV export for accounting
- Monthly cost reports

## Support

For issues or questions:
1. Check Cloud Functions logs: `firebase functions:log`
2. Verify Firestore data: Check `cost_tracking` collection
3. Test endpoints with `curl` or Postman
4. Review this README for configuration details

---

**Last Updated:** 2025-11-02
**Version:** 1.0.0
