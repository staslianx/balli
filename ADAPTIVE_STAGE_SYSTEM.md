# Adaptive Stage System for T3 Deep Research

## Problem Statement

The initial timer-based stage progression was too naive:
- Ran for only 18 seconds with fixed timing
- Answer didn't arrive until 47-48 seconds
- Card disappeared while research was still ongoing
- No connection to actual backend progress
- One query found only 1 source (possible backend issue)

## Solution: Adaptive Timing with Backend Hints

The new system intelligently adapts stage duration based on:
1. **Backend event hints** (planning, searching, sources ready)
2. **Answer content arrival** (first token detection)
3. **Source count** (whether sources have been collected)

## How It Works

### Stage Definitions
Each stage has a **minimum** and **maximum** duration:

```swift
("Araştırma planını yapıyorum", 0.10, 3.0, 8.0)      // 3-8 seconds
("Araştırmaya başlıyorum", 0.20, 2.0, 5.0)           // 2-5 seconds
("Kaynakları topluyorum", 0.35, 3.0, 10.0)           // 3-10 seconds
("Kaynakları değerlendiriyorum", 0.50, 2.5, 8.0)     // 2.5-8 seconds
("Ek kaynaklar arıyorum", 0.60, 2.0, 6.0)            // 2-6 seconds
("Ek kaynakları inceliyorum", 0.70, 2.5, 8.0)        // 2.5-8 seconds
("En ilgili kaynakları seçiyorum", 0.80, 2.5, 7.0)   // 2.5-7 seconds
("Bilgileri bir araya getiriyorum", 0.90, 2.0, 6.0)  // 2-6 seconds
("Kapsamlı bir rapor yazıyorum", 0.95, 3.0, 999.0)   // Holds until answer
```

### Adaptive Logic

#### Stage 0: Planning (3-8s)
- If `receivedPlanningEvent` = true → use minimum (3s)
- Otherwise → use 1.5× minimum (4.5s), capped at max (8s)

#### Stages 1-2: Starting + Collecting (2-10s)
- If `receivedSearchEvent` OR `receivedSourcesEvent` = true → minimum
- Otherwise → use 1.3× minimum, capped at max

#### Stages 3-7: Evaluating through Gathering (2.5-8s)
- If `receivedSourcesEvent` AND sources exist → minimum
- Otherwise → use 1.5× minimum, capped at max

#### Stage 8: Writing Report (CRITICAL)
**This is the holding stage:**
- Stays visible until `answer.content` arrives
- Polls every 0.5 seconds
- Progress slowly increments from 95% to 99%
- Maximum wait: 999 seconds (effectively unlimited)
- **This keeps the card visible throughout the entire process**

### Backend Hint Capture

The system observes these signals:

```swift
// 1. Sources arrived
.onChange(of: answer.sources.count) { oldCount, newCount in
    if newCount > 0, oldCount == 0 {
        receivedSourcesEvent = true
        logger.debug("💡 Backend hint: sources received")
    }
}

// 2. Backend stage events
.onChange(of: currentStage) { _, newStage in
    if stage.contains("planın") || stage.contains("plan") {
        receivedPlanningEvent = true
    } else if stage.contains("kaynak") || stage.contains("source") {
        receivedSearchEvent = true
    }
}

// 3. First token arrival (IMMEDIATE EXIT)
.onChange(of: answer.content) { oldContent, newContent in
    if oldContent.isEmpty && !newContent.isEmpty {
        logger.info("🎬 First token arrived - clearing stages")
        adaptiveStageMessage = nil
        stageTask?.cancel()
    }
}
```

## Key Features

### ✅ Grounded in Reality
- Takes hints from backend without being directly wired to it
- Adapts timing based on actual progress signals

### ✅ Stays Until Answer Arrives
- Stage 8 ("Writing report") holds indefinitely
- Slowly increments progress (95% → 99%)
- Exits only when content actually appears

### ✅ Immediate Response to Content
- Detects first token arrival
- Cancels stage task immediately
- Fades out card smoothly

### ✅ Flexible Timing
- Minimum durations ensure readability
- Maximum durations prevent getting stuck
- Adapts based on backend signals

### ✅ Clean Lifecycle Management
- Cancels existing task when new answer starts
- Resets all hint flags
- Proper cleanup on answer ID change

## Example Timeline

**Fast Query (sources arrive quickly):**
1. Badge appears (T=0s)
2. Stage 1: Planning (3s) ← minimum, no planning event yet
3. Stage 2: Starting (2s) ← minimum, search event received
4. Stage 3: Collecting (3s) ← minimum, sources arrived
5. Stage 4-7: (2.5-3s each) ← minimum, sources ready
6. Stage 8: Writing (3s) ← answer arrives quickly
7. **Total: ~20 seconds**

**Slow Query (sources take time):**
1. Badge appears (T=0s)
2. Stage 1: Planning (4.5s) ← no planning event, use 1.5× min
3. Stage 2: Starting (2.6s) ← no search event yet, use 1.3× min
4. Stage 3: Collecting (4.5s) ← no sources yet, use 1.5× min
5. Stage 4-7: (3.75-4s each) ← still waiting for sources
6. Stage 8: Writing (30s+) ← **HOLDS HERE** until answer arrives
7. **Total: ~50+ seconds** (adapts to reality)

## Benefits Over Simple Timer

| Aspect | Simple Timer | Adaptive System |
|--------|-------------|-----------------|
| Duration | Fixed 18s | 20-60+ seconds (adaptive) |
| Backend awareness | None | Takes hints from events |
| Answer detection | Checks in loop | Immediate onChange |
| Final stage | Fixed 2s | Holds until answer |
| Query variance | All queries same | Adapts per query |

## Monitoring

Look for these logs:
- `🎯 Adaptive stage: X (Y%)` - Stage displayed
- `💡 Backend hint: sources received` - Backend signal captured
- `⏱️ Stage duration: Xs (min: Ys, max: Zs)` - Adaptive timing calculation
- `🎬 First token arrived - clearing stages` - Answer detected
- `⏹️ Stopping adaptive stages - content arrived` - Graceful exit

## Future Enhancements

Potential improvements:
1. **Machine learning**: Learn optimal timings from actual query durations
2. **More granular hints**: Capture additional backend events
3. **Query complexity analysis**: Adjust base timings based on query type
4. **Network quality detection**: Slow down on poor connections
5. **Historical data**: Use past query times to predict current query
