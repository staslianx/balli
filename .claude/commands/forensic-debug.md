---
description: Complete forensic debugging workflow with logs, tests, and systematic problem resolution
disable-model-invocation: false
---

# Forensic Debug Workflow

Execute a comprehensive debugging process for: $ARGUMENTS

## Phase 1: Enhanced Logging
1. **Identify Critical Code Paths**
   - Analyze the reported issue/feature area
   - Locate all relevant files and functions
   - Map the execution flow

2. **Add Strategic Debug Logs**
   - Add `Logger` statements at entry/exit points of key functions
   - Log important state changes and data transformations
   - Use appropriate log levels (debug, info, error)
   - Include contextual information in logs
   - Follow the logging standards in CLAUDE.md

3. **Review Added Logs**
   - Show me all the logging code you've added
   - Explain what each log will reveal

## Phase 2: Test-Driven Verification
1. **Invoke rigorous-tester Agent**
   - Create comprehensive test cases that exercise the problematic code paths
   - Tests should trigger the logging we just added
   - Include both happy path and edge cases
   - Ensure tests cover the specific scenario in $ARGUMENTS

2. **Run Tests & Collect Logs**
   - Execute the test suite
   - For simulator: Use `balli-logs` to capture live logs during test execution
   - For physical device: Use `balli-logs-r` to capture live logs
   - Save log output for analysis

## Phase 3: Log Analysis & Diagnosis
1. **Parse Log Output**
   - Extract relevant log entries related to the issue
   - Identify anomalies, errors, or unexpected behavior
   - Track data flow through the system
   - Note timing and sequence of events

2. **Present Initial Findings**
   - **Summary:** What is the problem based on logs?
   - **Evidence:** Cite specific log entries that support your conclusion
   - **Root Cause:** What is causing the issue?
   - **Impact:** What functionality is affected?

3. **Letting the user know about issue of [issue explaination]"

## Phase 4: Resolution 
1. **Invoke forensic-debugger Agent**
   - Share all gathered context (logs, test results, root cause analysis)
   - Implement the fix based on the diagnosed issue
   - Ensure fix follows all CLAUDE.md standards
   - Maintain existing functionality

2. **Verify Fix Quality**
   - Code review against CLAUDE.md checklist
   - Verify Swift 6 concurrency compliance
   - Check error handling is proper
   - Ensure no force unwraps or unsafe code

## Phase 5: Validation
1. **Re-run Tests with rigorous-tester**
   - Execute the same test suite
   - Verify all tests pass
   - Collect new logs to confirm fix

2. **Compare Before/After**
   - Show log differences before and after fix
   - Confirm the issue no longer appears
   - Verify no new issues introduced

3. **Final Report**
   - ✅ Problem identified: [description]
   - ✅ Root cause: [explanation]
   - ✅ Solution implemented: [what was changed]
   - ✅ Tests passing: [test results]
   - ✅ Logs clean: [verification]
   
   OR if not resolved:
   
   - ❌ Issue persists
   - 📊 New findings from latest logs: [details]
   - 🔄 Recommended next steps
   - **Return to Phase 3 for another iteration**

## Phase 6: Cleanup (If Resolved)
1. **Remove Debug Logs**
   - Clean up excessive debug logging added in Phase 1
   - Keep only production-appropriate logging
   - Maintain error logging and important state changes

2. **Build Verification**
   - Run `⌘B` to build
   - Verify zero warnings
   - Run full test suite with `⌘U`

## Important Notes
- **Always wait for user approval** before invoking forensic-debugger agent
- **Never proceed past Phase 3** without explicit permission
- **If fix doesn't work**, return to Phase 3 and iterate
- **Use concrete log commands**: `balli-logs`, `balli-logs-r`, `balli-logs-last`, `balli-logs-last-r`
- **Follow CLAUDE.md** standards at all times
- **Coordinate agents**: rigorous-tester for testing, forensic-debugger for fixes
