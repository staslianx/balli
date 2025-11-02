# SwiftLint Setup Guide

## Overview

SwiftLint is now configured for this project to enforce Swift 6 coding standards and best practices.

---

## Installation

### Option 1: Homebrew (Recommended)
```bash
brew install swiftlint
```

### Option 2: CocoaPods
Add to `Podfile`:
```ruby
pod 'SwiftLint'
```

### Option 3: Mint
```bash
mint install realm/SwiftLint
```

---

## Xcode Integration

### Add Build Phase

1. Open Xcode
2. Select your target (`balli`)
3. Go to **Build Phases**
4. Click **+** → **New Run Script Phase**
5. Name it "SwiftLint"
6. Add this script:

```bash
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

7. **Important:** Drag this phase to run **BEFORE** "Compile Sources"

---

## Manual Usage

### Lint entire project
```bash
swiftlint
```

### Lint specific files
```bash
swiftlint lint --path balli/Features/
```

### Auto-fix violations
```bash
swiftlint --fix
```

**Warning:** Review changes after auto-fix before committing!

### Generate HTML report
```bash
swiftlint lint --reporter html > swiftlint-report.html
```

---

## Configuration

The project uses `.swiftlint.yml` at the root directory.

### Key Rules Enforced

**File/Function Limits:**
- File length: 300 lines (warning), 500 (error)
- Function body: 50 lines (warning), 80 (error)
- Line length: 200 chars (warning), 250 (error)

**Forbidden Patterns:**
- ❌ Force unwraps (`!`) - ERROR
- ❌ Force casts (`as!`) - ERROR
- ❌ Force try (`try!`) - ERROR
- ❌ `print()` statements - Use `Logger` instead
- ❌ `NSLog()` - Use `Logger` instead
- ❌ `DispatchQueue.main.async` - Use `@MainActor` instead

**Encouraged Patterns:**
- ✅ Async/await over completion handlers
- ✅ `@MainActor` for UI code
- ✅ `Logger` for all logging
- ✅ Explicit access control (`public`, `private`, etc.)
- ✅ Documentation for public APIs
- ✅ `isEmpty` over `count == 0`

---

## Swift 6 Compliance

SwiftLint configuration enforces:
- Proper use of `@MainActor`
- Avoidance of legacy concurrency patterns
- Actor isolation compliance
- Sendable conformance where appropriate

---

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: SwiftLint
  run: |
    brew install swiftlint
    swiftlint lint --reporter github-actions-logging
```

### Fastlane Integration

```ruby
lane :lint do
  swiftlint(
    mode: :lint,
    config_file: '.swiftlint.yml',
    reporter: 'html',
    output_file: 'swiftlint-report.html',
    ignore_exit_status: false
  )
end
```

---

## Ignoring Violations

### File-level ignore
```swift
// swiftlint:disable file_length
// ... long file content ...
// swiftlint:enable file_length
```

### Line-level ignore
```swift
let value = dict["key"]! // swiftlint:disable:this force_unwrapping
```

### Function-level ignore
```swift
// swiftlint:disable:next function_body_length
func veryLongFunction() {
    // ... many lines ...
}
```

**Warning:** Only ignore rules when absolutely necessary. Document WHY you're ignoring the rule.

---

## Custom Rules

This project includes custom rules:

1. **no_print** - Enforces Logger usage
2. **no_nslog** - Enforces Logger usage
3. **avoid_completion_handler** - Encourages async/await
4. **todo_requires_ticket** - TODOs must reference issues
5. **avoid_dispatch_main** - Encourages @MainActor
6. **public_requires_docs** - Public APIs need documentation

---

## Troubleshooting

### "swiftlint: command not found"
- Ensure SwiftLint is installed: `brew install swiftlint`
- Check PATH: `echo $PATH | grep homebrew`
- Restart Xcode after installation

### Too many warnings
- Start by fixing errors first
- Gradually fix warnings over time
- Use `swiftlint --fix` for auto-fixable issues

### Rules conflict with project style
- Edit `.swiftlint.yml` to adjust limits
- Add rules to `disabled_rules` if needed
- Document exceptions in CLAUDE.md

---

## Best Practices

1. **Run before committing:**
   ```bash
   swiftlint && git add .
   ```

2. **Fix auto-fixable issues:**
   ```bash
   swiftlint --fix && swiftlint
   ```

3. **Review before pushing:**
   - Zero errors
   - Minimal warnings
   - Documented exceptions

4. **Team workflow:**
   - Run SwiftLint in CI/CD
   - Block merges with SwiftLint failures
   - Regular lint debt cleanup sprints

---

## Integration with CLAUDE.md

This SwiftLint configuration enforces standards from `CLAUDE.md`:

- Max file length: 300 lines (CLAUDE.md specifies 300)
- No force unwraps (CLAUDE.md forbids them)
- Logger usage (CLAUDE.md requires Logger framework)
- Swift 6 concurrency (CLAUDE.md requires strict concurrency)
- Documentation standards (CLAUDE.md emphasizes documentation)

---

## Next Steps

1. Install SwiftLint: `brew install swiftlint`
2. Add Xcode build phase (see above)
3. Run first lint: `swiftlint`
4. Fix critical errors
5. Gradually address warnings
6. Add to CI/CD pipeline

---

**Last Updated:** 2025-11-02
**SwiftLint Version:** Latest (via Homebrew)
**Swift Version:** 6.0
