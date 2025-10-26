-----

description: Comprehensive audit of Dexcom CGM integration including Official API, SHARE API, data persistence, authentication, chart rendering, and error handling
allowed-tools:

- bash_tool
- view
- str_replace

-----

# Dexcom Integration Comprehensive Audit

Perform a systematic audit of the entire Dexcom CGM integration covering both Official API and SHARE API implementations, data flow, storage, authentication, UI rendering, and error handling.

## Audit Scope

This command will analyze:

1. **API Implementation** - Both Official Dexcom API and SHARE API code paths
1. **Authentication & Session Management** - Token/sessionId lifecycle and persistence
1. **Data Fetching & Stitching** - How 3-hour delayed + real-time data are combined
1. **Core Data Persistence** - Storage schema, queries, and data integrity
1. **Data Validation** - Gap detection, duplicate handling, timestamp ordering
1. **Chart Rendering** - How data flows from storage to UI visualization
1. **Background Sync** - Automatic refresh and app lifecycle handling
1. **Error Handling** - Failure scenarios, retries, and user feedback

-----

## Step 1: Locate All Dexcom-Related Files

First, find all files related to Dexcom integration:

!find . -type f ( -name “*Dexcom*” -o -name “*dexcom*” -o -name “*CGM*” -o -name “*Share*” -o -name “*share*” -o -name “*Glucose*” -o -name “*glucose*” ) -not -path “*/.*” | grep -v “.git”

Then examine the project structure for integration points:

!find . -name “*.swift” -type f -exec grep -l “dexcom|Dexcom|SHARE|glucose” {} ; | head -20

-----

## Step 2: API Implementation Analysis

### Official Dexcom API Audit

Examine the official API implementation:

**Questions to answer:**

- What is the base URL? (should be `api.dexcom.com`)
- How is OAuth implemented? (access token, refresh token)
- What is the token expiration logic? (tokens expire every 2 hours)
- What date range is being requested?
- How does it handle the 3-hour delay?
- Is pagination handled? (API max 288 readings per request)
- What error codes are handled? (401, 403, 429, 500)

**Search for official API code:**

```
Look for:
- URLSession calls to api.dexcom.com
- OAuth token refresh logic
- Access token storage (Keychain?)
- Date range calculation for API requests
- Response parsing and error handling
```

### SHARE API Audit

Examine the SHARE API implementation:

**Questions to answer:**

- How is sessionId obtained?
- Where is sessionId stored? (Keychain, UserDefaults, memory?)
- What is sessionId expiration handling? (24 hours)
- What server is being used? (US vs International)
- How frequently is it polled? (should be every 5 minutes)
- What credentials are required? (username, password)

**Search for SHARE API code:**

```
Look for:
- SessionId generation calls
- Credential storage in Keychain
- Polling timer or scheduled fetch
- Server URL selection logic
- Authentication failure handling
```

-----

## Step 3: Data Stitching Logic

### How are Official API + SHARE API combined?

**Critical questions:**

1. Which API is used as the “primary” source?
1. How do you decide when to use Official vs SHARE data?
1. Is there overlap handling? (both APIs might return same reading)
1. How are gaps filled?
1. What happens if one API fails but the other succeeds?

**Find the stitching code:**

```
Search for:
- Functions that combine glucose readings from multiple sources
- Logic that determines which source to use for what time range
- Deduplication logic (same timestamp from both APIs)
- Gap detection and filling
```

**Expected pattern:**

```
- Official API: Fetch historical data (now - 3 hours) to (earliest date)
- SHARE API: Fetch recent data (now) to (now - 15 minutes)
- Merge: Combine with deduplication on timestamp
- Validation: Check for gaps and outliers
```

-----

## Step 4: Core Data Schema Audit

### GlucoseReading Entity

**Find and examine the Core Data model:**

!find . -name “*.xcdatamodeld” -o -name “*.xcdatamodel”

**Critical fields to verify:**

- `timestamp: Date` - When the reading was taken
- `value: Double` - Glucose value in mg/dL
- `source: String` - “dexcom_official” or “dexcom_share”
- `userId: String` - User scoping
- Indexes on `userId` and `timestamp` for fast queries

**Questions:**

1. Is there a unique constraint on (userId, timestamp, source)?
1. Are readings properly indexed for query performance?
1. Is there a TTL or cleanup policy? (delete old readings)
1. How are duplicate timestamps handled?

**Search for Core Data queries:**

```
Look for:
- NSFetchRequest for GlucoseReading
- Sorting and filtering logic
- Save operations after API fetch
- Delete operations for cleanup
```

-----

## Step 5: Data Persistence Flow

### Trace data from API → Core Data → UI

**API Fetch → Save:**

```
1. API response returns JSON
2. Parse JSON into Swift structs
3. Create NSManagedObject for each reading
4. Save to Core Data context
5. Handle save errors
```

**Questions:**

- Is saving done on background thread? (should be)
- Are batch inserts used for performance?
- Is there error handling for save failures?
- What happens if device storage is full?

**Core Data → ViewModel:**

```
1. Fetch readings from Core Data
2. Sort by timestamp ascending
3. Filter by date range (last 24 hours)
4. Convert to chart-ready format
```

**Search for ViewModel code:**

```
Look for:
- @Published properties holding glucose data
- Core Data fetch requests in ViewModel
- Data transformation for chart
- ObservableObject conformance
```

-----

## Step 6: Data Validation

### Gap Detection

**Questions:**

1. Are there checks for missing timestamps? (should be every 5 min)
1. What happens when a gap is detected?
1. Is gap filling attempted? (interpolation vs backfill)

**Expected gaps:**

- CGM sensor warmup (2 hours after insertion)
- Bluetooth connection loss
- Sensor failure or expiration

**Search for gap handling:**

```
Look for:
- Logic comparing expected vs actual reading count
- Timestamp difference calculations
- "No recent data" warnings
- Retry logic for failed fetches
```

### Duplicate Handling

**Critical issue:** Both Official and SHARE APIs might return same reading

**Deduplication strategy should be:**

1. Primary key: `(userId, timestamp, source)`
1. On conflict: Keep SHARE (newer, real-time) over Official
1. Or: Keep first inserted, ignore duplicates

**Search for deduplication:**

```
Look for:
- Merge conflict resolution
- "ON CONFLICT" SQL logic
- Timestamp comparison before insert
- Filtering duplicate readings
```

### Data Validation

**Sanity checks needed:**

- Glucose value range: 40-400 mg/dL (physiological limits)
- Timestamp not in future
- Timestamp not older than 3 months
- Rate of change validation (<5 mg/dL per minute)

**Search for validation:**

```
Look for:
- Range checks on glucose values
- Timestamp validation
- Outlier detection
- Data quality flags
```

-----

## Step 7: Chart Rendering

### Data Flow to UI

**SwiftUI Chart component should:**

1. Receive array of readings from ViewModel
1. Sort by timestamp (ascending)
1. Plot as line chart with X=time, Y=glucose
1. Handle missing data (gaps show as discontinuities)
1. Display current reading prominently
1. Show trend arrow

**Find chart code:**

```
Look for:
- Chart { ... } SwiftUI view
- LineMark or AreaMark
- X-axis: .value("Time", timestamp)
- Y-axis: .value("Glucose", value)
- Current reading display
- Trend arrow logic
```

**Continuity issues to check:**

1. Are readings sorted before charting?
1. Is there a “connect gaps” option? (should not connect >15min gaps)
1. How are different sources styled? (Official vs SHARE)
1. Is the chart real-time updated? (every 5 min)

-----

## Step 8: Authentication Lifecycle

### Official API Token Management

**OAuth flow:**

1. Initial authorization → receive access_token + refresh_token
1. Access token expires in 2 hours
1. Refresh token expires in 90 days
1. Use refresh_token to get new access_token

**Critical checks:**

- Is refresh_token stored securely? (Keychain only)
- Is token refresh automatic? (before expiration)
- What happens if refresh fails? (re-authenticate user)
- Are tokens deleted on logout?

**Search for token logic:**

```
Look for:
- Keychain storage calls
- Token expiration checking
- Refresh token endpoint calls
- Re-authentication triggers
```

### SHARE API Session Management

**SessionId lifecycle:**

1. Login with username/password → receive sessionId
1. SessionId valid for 24 hours
1. After expiration: re-login required
1. Sessions survive app restarts

**Critical checks:**

- Is sessionId stored in Keychain? (should be)
- Is password stored? (should be Keychain, not UserDefaults)
- Is expiration tracked? (timestamp + 24 hours)
- Is re-login automatic or manual?

**Search for session logic:**

```
Look for:
- SessionId generation
- Keychain password storage
- Expiration timestamp tracking
- Automatic re-login logic
```

-----

## Step 9: Background Sync & App Lifecycle

### Background Fetch

**iOS limitations:**

- Background fetch scheduled by OS (not guaranteed)
- Limited to ~30 seconds execution time
- Not reliable for critical glucose updates

**Better approach:**

- Foreground: Fetch on app activate
- Background: Use push notifications from Dexcom (if available)
- Fallback: Background fetch when allowed

**Questions:**

1. Is background fetch enabled in Capabilities?
1. Is there a scheduled timer when app is active?
1. What happens when app returns from background?
1. Is there a “last sync” timestamp displayed?

**Search for background code:**

```
Look for:
- application(_:performFetchWithCompletionHandler:)
- BackgroundTasks framework usage
- Timer scheduling for active app
- sceneDidBecomeActive refresh logic
```

### App Lifecycle Handling

**Scenarios to test:**

- App launches cold → fetch data → display
- App returns from background → check staleness → refresh if needed
- App terminated and reopened → restore last state
- Device reboots → re-authenticate if needed

**Search for lifecycle:**

```
Look for:
- @Environment(\.scenePhase) observation
- onAppear refresh calls
- Task cancellation on disappear
- State restoration logic
```

-----

## Step 10: Error Handling Audit

### Network Errors

**Expected errors:**

- No internet connection (URLError.notConnectedToInternet)
- Timeout (URLError.timedOut)
- Server errors (500, 502, 503)
- Rate limiting (429)

**Proper handling:**

1. Show user-friendly error message
1. Implement exponential backoff for retries
1. Don’t spam API with rapid retries
1. Cache last successful data to show stale data

**Search for error handling:**

```
Look for:
- catch blocks around API calls
- URLError handling
- Retry logic with delays
- Error state in ViewModel
```

### Authentication Errors

**Expected errors:**

- Invalid credentials (401)
- Expired token (403)
- Account locked
- Dexcom service down

**Proper handling:**

1. Detect auth failure
1. Clear invalid tokens
1. Show re-authentication UI
1. Don’t auto-retry with same invalid credentials

### Data Errors

**Expected errors:**

- Corrupt JSON response
- Missing required fields
- Out-of-range values
- Timestamp parsing failures

**Proper handling:**

1. Validate before saving to Core Data
1. Log malformed responses for debugging
1. Skip invalid readings (don’t crash)
1. Show data quality warning if many failures

-----

## Step 11: Testing Scenarios

### Test what happens when:

1. **Official API returns empty** → Should fall back to SHARE
1. **SHARE API fails** → Should show Official API data (3hr delay)
1. **Both APIs fail** → Show cached data with “stale” warning
1. **Duplicate timestamps** → Should deduplicate, prefer SHARE
1. **10-minute gap in data** → Chart should show discontinuity
1. **Token expires mid-session** → Should refresh automatically
1. **SessionId expires** → Should re-login automatically
1. **User logs out** → Should clear all credentials and cached data
1. **Network switches (WiFi→Cellular)** → Should retry failed requests
1. **App killed mid-fetch** → Should resume cleanly on next launch

-----

## Step 12: Performance Audit

### Query Performance

**Checks:**

- Are Core Data queries using indexes?
- Are fetch limits set? (avoid loading all readings)
- Is pagination used for large datasets?
- Are background context used for saves?

**Benchmark queries:**

```
Measure:
- Time to fetch 288 readings (24 hours at 5min intervals)
- Time to save 288 new readings
- Time to render chart with 288 points
```

### Memory Usage

**Checks:**

- Are old readings purged? (delete older than 90 days)
- Is image caching aggressive? (chart snapshots)
- Are API responses released after parsing?

-----

## Step 13: Security Audit

**Critical security checks:**

1. **Credentials Storage**
- ✅ Keychain for tokens/passwords (NOT UserDefaults)
- ✅ Tokens marked as `kSecAttrAccessibleAfterFirstUnlock`
- ❌ Never log credentials or tokens
1. **Network Security**
- ✅ All API calls use HTTPS
- ✅ Certificate pinning (optional but recommended)
- ❌ No HTTP fallback
1. **Data Protection**
- ✅ Core Data encrypted (FileProtection.complete)
- ✅ Glucose data scoped to user
- ❌ No glucose data sent to third parties

-----

## Deliverable: Audit Report

After running this command, provide a comprehensive report with:

### Findings Summary

- ✅ What’s working correctly
- ⚠️ What has issues or concerns
- ❌ What’s broken or missing

### Critical Issues

1. Authentication persistence across sessions
1. Data stitching logic between APIs
1. Duplicate/gap handling
1. Chart rendering with intermittent data
1. Error recovery mechanisms

### Recommendations

- Prioritized list of fixes
- Code improvements
- Architecture suggestions
- Testing additions

-----

## Execution Instructions

**For each section above:**

1. Use `view` tool to read relevant source files
1. Use `bash_tool` to search for patterns
1. Analyze the code for correctness
1. Document findings in structured format
1. Provide specific file/line references

**Focus on:**

- The “stitching” logic for Official + SHARE data
- Authentication survival across app restarts
- Chart rendering with incomplete data
- What happens when one API is down

**Be brutally honest about what you find.**
