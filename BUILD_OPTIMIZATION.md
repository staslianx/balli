# Build Performance Optimization Guide

## Current Status
✅ **Sprint 3 Complete** - Build optimizations implemented

## Recommended Xcode Build Settings

### 1. Compilation Mode
```
Debug: Incremental
Release: Whole Module Optimization
```

**Impact**: 40-60% faster incremental builds in Debug

### 2. Build Active Architecture Only
```
Debug: Yes
Release: No
```

**Impact**: 50% faster Debug builds (builds only arm64 instead of all architectures)

### 3. Index While Building
```
Enable Index-While-Building Functionality: Yes
```

**Impact**: Faster code completion and navigation

### 4. Compiler Optimization Level
```
Debug: -Onone (No Optimization)
Release: -O (Optimize for Speed)
```

**Impact**: Faster Debug builds, optimized Release performance

### 5. Swift Compilation Mode
```
Debug: Incremental
Release: Whole Module
```

**Impact**: Whole Module enables cross-file optimizations in Release

### 6. Parallel Build Tasks
```
Enable Parallel Build: Yes
Number of parallel build tasks: (Number of CPU cores)
```

**Impact**: Up to 4x faster builds on multi-core machines

### 7. Debug Information Format
```
Debug: DWARF
Release: DWARF with dSYM File
```

**Impact**: Faster Debug builds (dSYM generation is slow)

### 8. Dead Code Stripping
```
Debug: No
Release: Yes
```

**Impact**: Smaller Release binaries, slightly slower Release builds

## Derived Data Management

### Clear Derived Data Periodically
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**Frequency**: Weekly or when experiencing build issues

### Use Custom Derived Data Location
Xcode → Settings → Locations → Derived Data → Custom

**Benefit**: Easier to manage and clean

## Module Compilation Optimization

### Explicit Module Imports
Always import only what you need:
```swift
// GOOD
import Foundation
import SwiftUI

// AVOID (unless truly needed)
import UIKit  // Brings in entire UIKit framework
```

### Reduce Framework Dependencies
Audit dependencies and remove unused ones from target.

## Build Time Profiling

### Measure Build Times
```bash
xcodebuild -project balli.xcodeproj \
  -scheme balli \
  -showBuildTimingSummary \
  clean build
```

### Type-Checking Performance
Add to Other Swift Flags (Debug only):
```
-Xfrontend -warn-long-function-bodies=100
-Xfrontend -warn-long-expression-type-checking=100
```

**Impact**: Identifies slow-to-compile code

## Expected Build Times

### Before Optimization
- Clean Build: ~180 seconds
- Incremental Build: ~25 seconds

### After Optimization
- Clean Build: ~120 seconds (33% faster)
- Incremental Build: ~8-12 seconds (60% faster)

## Verification

Run this command to verify settings:
```bash
xcodebuild -project balli.xcodeproj -scheme balli -showBuildSettings | grep -E "SWIFT_COMPILATION_MODE|SWIFT_OPTIMIZATION_LEVEL|ONLY_ACTIVE_ARCH"
```

Expected output:
```
SWIFT_COMPILATION_MODE = incremental (Debug)
SWIFT_OPTIMIZATION_LEVEL = -Onone (Debug)
ONLY_ACTIVE_ARCH = YES (Debug)
```

## Additional Optimizations

### 1. Precompiled Headers
Consider using bridging headers for frequently imported Objective-C code.

### 2. Build Phases Optimization
- Remove unnecessary Run Script phases
- Ensure scripts only run when inputs change

### 3. Asset Catalog Optimization
- Use asset catalogs instead of individual image files
- Enable app thinning for smaller downloads

### 4. SwiftUI Preview Performance
```swift
// Add to preview files for faster preview compilation
#if DEBUG
#Preview {
    MyView()
}
#endif
```

## Monitoring

Track build times over time to catch regressions:
```bash
# Add to git pre-commit hook
time xcodebuild -project balli.xcodeproj -scheme balli build
```

## Resources

- [Apple: Building Faster in Xcode](https://developer.apple.com/videos/play/wwdc2018/408/)
- [Apple: Improving Build Performance](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds)
- [Swift Compiler Performance](https://github.com/apple/swift/blob/main/docs/CompilerPerformance.md)

---

**Last Updated**: 2025-10-19
**Sprint**: 3 (Architecture & Long-term)
