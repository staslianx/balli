# Remaining Fixes Required - Quick Reference

**Date**: 2025-11-01
**Status**: Post-fix verification audit
**Priority Issues**: 3 critical fixes remaining

---

## 🔴 CRITICAL - Fix Immediately (Today)

### 1. CaptureFlowManager: Missing deinit cleanup call
**File**: `balli/Features/CameraScanning/Services/CaptureFlowManager.swift`
**Line**: 512-514
**Effort**: 5 minutes
**Impact**: Prevents 2 observer leaks per camera session

**Current Code**:
```swift
deinit {
    // Cleanup should be called before deinit
}
```

**Fix**:
```swift
deinit {
    cleanup()  // ✅ Call existing cleanup method
}
```

---

### 2. DataHealthMonitor: Observer leak in actor
**File**: `balli/Features/HealthGlucose/Services/DataHealthMonitor.swift`
**Lines**: 232-243
**Effort**: 1 hour
**Impact**: Prevents observer leak on every Core Data save

**Current Code**:
```swift
actor DataHealthMonitor {
    private func setupNotificationMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { _ in
            Task {
                await self.recordSave(duration: 0, success: true)
            }
        }
    }
}
```

**Fix Option 1 - Convert to @MainActor class**:
```swift
@MainActor
class DataHealthMonitor {
    // Add observer storage
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    private func setupNotificationMonitoring() {
        let observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main  // ✅ Use main queue
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordSave(duration: 0, success: true)
            }
        }
        observers.append(observer)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
```

**Fix Option 2 - Use Combine publisher**:
```swift
actor DataHealthMonitor {
    private var cancellables = Set<AnyCancellable>()

    private func setupNotificationMonitoring() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                Task {
                    await self?.recordSave(duration: 0, success: true)
                }
            }
            .store(in: &cancellables)
    }
}
```

**Recommended**: Option 1 (consistent with other fixes)

---

## 🟡 HIGH PRIORITY - Fix This Week

### 3. MemorySyncCoordinator: Observer leak in singleton
**File**: `balli/Core/Services/Memory/Sync/MemorySyncCoordinator.swift`
**Lines**: 141-153
**Effort**: 10 minutes
**Impact**: Observer leaks for app lifetime

**Current Code**:
```swift
func setupNetworkObserver() {
    NotificationCenter.default.addObserver(
        forName: .networkDidBecomeReachable,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.syncOnNetworkRestore()
        }
    }
    logger.info("📡 Network observer setup complete")
}
```

**Fix**:
```swift
// Add property
private var networkObserver: NSObjectProtocol?

func setupNetworkObserver() {
    networkObserver = NotificationCenter.default.addObserver(
        forName: .networkDidBecomeReachable,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            await self?.syncOnNetworkRestore()
        }
    }
    logger.info("📡 Network observer setup complete")
}

// Add deinit
deinit {
    if let observer = networkObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

---

### 4. MealSyncCoordinator: Missing task cancellation
**File**: `balli/Core/Sync/MealSyncCoordinator.swift`
**Lines**: 55-59
**Effort**: 5 minutes
**Impact**: Task may continue after coordinator deallocation

**Current Code**:
```swift
deinit {
    if let observer = coreDataObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

**Fix**:
```swift
deinit {
    if let observer = coreDataObserver {
        NotificationCenter.default.removeObserver(observer)
    }
    syncTask?.cancel()  // ✅ Cancel ongoing task
}
```

---

## 📋 Verification Checklist

After implementing fixes:

- [ ] Fix #1: CaptureFlowManager deinit calls cleanup()
- [ ] Fix #2: DataHealthMonitor converted to @MainActor class with proper observer cleanup
- [ ] Fix #3: MemorySyncCoordinator stores and removes network observer
- [ ] Fix #4: MealSyncCoordinator cancels syncTask in deinit
- [ ] Run Instruments "Leaks" tool - verify no NotificationCenter leaks
- [ ] Test camera scanning session - verify no leaks
- [ ] Test memory sync - verify no leaks
- [ ] Build and run tests - all pass
- [ ] No new warnings or errors

---

## 🎯 Expected Impact After Fixes

- **Memory Leaks**: 0 (down from 3 remaining)
- **Code Quality Score**: 82/100 (up from 74/100)
- **Critical Issues**: 0 (down from 2)
- **Production Ready**: ✅ Yes

---

## 📚 Pattern to Follow (Reference)

For any new NotificationCenter observers, always use this pattern:

```swift
@MainActor
class MyViewModel: ObservableObject {
    // Storage
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        setupObservers()
    }

    private func setupObservers() {
        let observer = NotificationCenter.default.addObserver(
            forName: .myNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleNotification(notification)
            }
        }
        observers.append(observer)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
```

**Key Points**:
1. ✅ Use `nonisolated(unsafe)` for observer storage in @MainActor classes
2. ✅ Store ALL observers in an array
3. ✅ Remove ALL observers in deinit
4. ✅ Use `queue: .main` for MainActor code
5. ✅ Use `[weak self]` to prevent retain cycles

---

**Last Updated**: 2025-11-01
**Next Review**: After all 4 fixes implemented
