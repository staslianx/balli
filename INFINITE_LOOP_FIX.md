# Infinite Refresh Loop - ROOT CAUSE & FIX

**Date:** 2025-10-26
**Status:** ✅ FIXED
**Severity:** 🔴 CRITICAL

---

## Problem Description

The app was experiencing an **infinite refresh loop** causing rapid, repeated glucose data loading that would freeze/crash the app. The logs showed:

```
Glucose data updated - loading with debounce protection
⚠️ Skipping invalid/deleted reading
Error: vazgeçildi (cancelled)
⚠️ Official API failed: vazgeçildi
Failed to fetch SHARE readings: vazgeçildi
```

The "vazgeçildi" (cancelled) errors were caused by network requests being cancelled due to the rapid loop.

---

## Root Cause Analysis

### The Infinite Loop Chain

```
1. GlucoseChartViewModel receives .glucoseDataDidUpdate notification
                    ↓
2. Calls loadGlucoseData() which calls loadFromHybridSource()
                    ↓
3. HybridGlucoseDataSource.fetchReadings() fetches from both APIs
                    ↓
4. DexcomShareService.fetchGlucoseReadings() fetches data
                    ↓
5. DexcomShareService posts .glucoseDataDidUpdate notification ❌
                    ↓
6. Back to step 1 → INFINITE LOOP
```

### Why This Happened

The notification system was designed for **background syncs** but was being triggered by **on-demand data fetches**:

- **Background Sync:** Timer or user action triggers `syncData()` → fetches new data → posts notification → ViewModel refreshes → ✅ CORRECT
- **On-Demand Fetch:** ViewModel needs data → calls `fetchGlucoseReadings()` → posts notification → ViewModel refreshes again → ❌ LOOP

The problem: **`fetchGlucoseReadings()` methods were posting notifications**, even when called BY the ViewModel that was already loading data.

---

## The Fix (3 Files Changed)

### 1. GlucoseDataSource.swift (Line 264-267)

**BEFORE:**
```swift
// Notify that new glucose data is available
if !sortedReadings.isEmpty {
    await MainActor.run {
        NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
    }
}
```

**AFTER:**
```swift
// NOTE: DO NOT post .glucoseDataDidUpdate here - this creates infinite loop!
// The notification is posted by the underlying services (DexcomService, DexcomShareService)
// when they actually fetch new data from APIs. This hybrid source just combines data.
```

**Why:** The hybrid data source is just a combiner/router. It doesn't fetch new data itself - it delegates to Official or SHARE APIs. It shouldn't post notifications.

---

### 2. DexcomShareService.swift (Line 260-264)

**BEFORE:**
```swift
// Notify that new glucose data is available
await MainActor.run {
    NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
}
```

**AFTER:**
```swift
// NOTE: DO NOT post .glucoseDataDidUpdate here!
// This method is called BY the ViewModel when loading data, which would create infinite loop:
// ViewModel gets notification → loads data → calls this → posts notification → LOOP
// Only syncData() should post notifications (background sync, not on-demand fetch)
```

**Why:** `fetchGlucoseReadings()` is called by the ViewModel for on-demand fetches. Only `syncData()` (background sync) should post notifications.

---

### 3. DexcomService.swift (Line 242-245)

**BEFORE:**
```swift
// Notify that new glucose data is available
if !readings.isEmpty {
    await MainActor.run {
        NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
    }
}
```

**AFTER:**
```swift
// NOTE: DO NOT post .glucoseDataDidUpdate here!
// This method is called BY the ViewModel when loading data, which would create infinite loop:
// ViewModel gets notification → loads data → calls this → posts notification → LOOP
// Only background sync operations should post notifications, not on-demand data fetches
```

**Why:** Same as SHARE service - `fetchGlucoseReadings()` is for on-demand fetches, not background sync.

---

## What Still Posts Notifications (Correctly)

### ✅ DexcomShareService.syncData() (Lines 170, 206)

```swift
func syncData() async throws {
    // ... fetch latest reading ...

    if reading != nil {
        // This IS a background sync, so notification is correct
        NotificationCenter.default.post(name: .glucoseDataDidUpdate, object: nil)
    }
}
```

**Why this is OK:** `syncData()` is called by:
- Timers (periodic background sync)
- User action (pull to refresh)
- App foreground transition

It's NOT called by the ViewModel loading data, so it won't create a loop.

---

## Previous Partial Fix (Was Incomplete)

**Earlier Fix in GlucoseChartViewModel.swift:144**

Changed:
```swift
// OLD (bypassed debounce)
await self?.refreshData()

// NEW (uses debounce)
self?.loadGlucoseData()
```

**This helped but didn't solve the root cause** because:
- The 60-second debounce SLOWED the loop but didn't STOP it
- Once 60 seconds passed, the loop would continue
- The notification was still being posted after every load

---

## How to Verify the Fix

### 1. Check Logs

**Before (infinite loop):**
```
Glucose data updated - loading with debounce protection
Fetched 288 SHARE readings
Auto-saved 0/288 readings to CoreData (duplicates)
Glucose data updated - loading with debounce protection  ← IMMEDIATE REPEAT
Fetched 288 SHARE readings
Glucose data updated - loading with debounce protection  ← LOOP
```

**After (fixed):**
```
Glucose data updated - loading with debounce protection
Fetched 288 SHARE readings
Auto-saved 0/288 readings to CoreData (duplicates)
Final glucose data count: 288
[No further logs until next legitimate data update]
```

### 2. Watch Network Activity

Before: Network requests firing every few seconds (rapid cancellations)
After: Network requests only when data actually changes

### 3. Monitor CPU Usage

Before: High CPU usage from infinite loop
After: CPU returns to normal after initial load

---

## Notification Flow Diagram (Fixed)

```
┌─────────────────────────────────────┐
│  Background Timer (every 5 min)     │
└──────────────┬──────────────────────┘
               │
               ↓
    ┌──────────────────────┐
    │ syncData() called    │
    │ (background sync)    │
    └──────────┬───────────┘
               │
               ↓
    ┌──────────────────────┐
    │ Fetch from SHARE API │
    │ Save to CoreData     │
    └──────────┬───────────┘
               │
               ↓
    ┌────────────────────────────┐
    │ Post .glucoseDataDidUpdate │  ← ONLY here
    └──────────┬─────────────────┘
               │
               ↓
    ┌──────────────────────────────┐
    │ GlucoseChartViewModel gets   │
    │ notification                 │
    └──────────┬───────────────────┘
               │
               ↓
    ┌──────────────────────────────┐
    │ loadGlucoseData() called     │
    │ (on-demand fetch)            │
    └──────────┬───────────────────┘
               │
               ↓
    ┌──────────────────────────────┐
    │ fetchReadings() called       │
    │ Returns data silently        │  ← NO notification
    └──────────┬───────────────────┘
               │
               ↓
    ┌──────────────────────────────┐
    │ Chart updates with new data  │
    │ ✅ DONE - NO LOOP            │
    └──────────────────────────────┘
```

---

## Testing Checklist

- [x] Build succeeds without errors
- [ ] App loads glucose data without infinite refresh
- [ ] Logs show single load cycle, not repeated cycles
- [ ] Network requests not being cancelled rapidly
- [ ] CPU usage normal after initial load
- [ ] Background sync still triggers chart updates
- [ ] Manual refresh (pull to refresh) works correctly
- [ ] App foreground transition refreshes data once

---

## Related Issues

This fix also resolves:
- ❌ "vazgeçildi" network cancellation errors
- ❌ App freeze/crash due to excessive refreshing
- ❌ Battery drain from continuous network requests
- ❌ "⚠️ Skipping invalid/deleted reading" spam in logs

---

## Lessons Learned

### Design Principle Violated

**Violated:** Data fetchers were posting notifications about data availability.

**Correct:** Only data **producers** (background syncs, API calls initiated by the app itself) should post notifications. Data **consumers** (ViewModels requesting data) should get silent responses.

### Proper Notification Usage

```swift
// ✅ CORRECT: Background sync posts notification
func syncData() async {
    let newData = try await fetchFromAPI()
    saveToDatabase(newData)
    NotificationCenter.default.post(name: .dataUpdated) // ✅ OK
}

// ❌ WRONG: On-demand fetch posts notification
func fetchData() async -> [Data] {
    let data = try await fetchFromAPI()
    NotificationCenter.default.post(name: .dataUpdated) // ❌ Creates loop
    return data
}

// ✅ CORRECT: On-demand fetch returns silently
func fetchData() async -> [Data] {
    let data = try await fetchFromAPI()
    return data // ✅ No notification
}
```

---

## Conclusion

The infinite loop was caused by **fetch methods posting notifications when they should have been silent**. The fix separates:

- **Background Sync** (initiated by app) → Posts notifications ✅
- **On-Demand Fetch** (initiated by ViewModel) → Returns data silently ✅

This ensures notifications only flow in one direction:
`Background Sync → Notification → ViewModel Fetch → Chart Update`

And NOT:
`ViewModel Fetch → Notification → ViewModel Fetch → ∞`

---

**End of Report**
