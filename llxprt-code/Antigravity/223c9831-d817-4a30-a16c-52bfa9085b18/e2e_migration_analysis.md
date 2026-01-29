# E2E Testing Migration to Fiber-Recorder: Feasibility Analysis

## Executive Summary

**Recommendation**: **Hybrid Approach** - Enhance existing E2E tests with fiber-recorder validation while maintaining current telemetry-based verification.

**Key Findings**:
- Current E2E tests primarily verify **functional behavior** (tool calls, transcript content) rather than UI state
- `fiber-recorder` excels at capturing **visual/layout state** but doesn't replace functional testing
- Migration is **feasible and valuable** for UI-focused tests, but not all tests benefit from it
- Best approach: **Augment** existing tests with fiber-recorder for UI regression detection

---

## Current E2E Test Infrastructure Analysis

### Test Categories

#### 1. **Placeholder Tests** (`App.e2e.test.tsx`)
- **Status**: Empty placeholder tests
- **Purpose**: Structural placeholders for future OAuth/clipboard tests
- **Current Validation**: None (just `expect(true).toBe(true)`)
- **Fiber-Recorder Benefit**: ⭐⭐⭐⭐⭐ (High - these need real implementation)

#### 2. **Functional Tests** (`todo-continuation.e2e.test.js`, `todo-reminder.e2e.test.ts`)
- **Status**: Active, comprehensive
- **Purpose**: Verify AI behavior, tool calls, transcript content
- **Current Validation**: 
  - Telemetry log parsing (`readToolLogs()`)
  - String matching in output (`result.includes(...)`)
  - Tool call verification (`waitForToolCall()`)
- **Fiber-Recorder Benefit**: ⭐⭐ (Low - these test logic, not UI)

#### 3. **UI Component Tests** (Using `ink-testing-library`)
- **Files**: `HistoryItemDisplay.test.tsx`, `LoadingIndicator.test.tsx`, `SessionController.test.tsx`
- **Current Validation**: `lastFrame()` assertions and snapshots
- **Fiber-Recorder Benefit**: ⭐⭐⭐⭐ (High - direct UI state verification)

### Current Testing Approach

```typescript
// Current: TestRig spawns CLI and parses output
const rig = new TestRig();
await rig.setup('test name');
const result = await rig.run('prompt');

// Verification via string matching
assert.ok(result.includes('expected text'));

// Verification via telemetry logs
const toolCall = await rig.waitForToolCall('tool_name');
assert.ok(toolCall);
```

```typescript
// Current: ink-testing-library for component tests
const { lastFrame } = render(<Component />);
expect(lastFrame()).toContain('expected text');
expect(lastFrame()).toMatchSnapshot();
```

---

## Fiber-Recorder Capabilities vs. Current Needs

### What Fiber-Recorder Provides

✅ **Complete Fiber tree structure** with component hierarchy  
✅ **Ink-specific state** (`stateNode`, styles, text, layout)  
✅ **Temporal UI state** across all commits  
✅ **Visual regression detection** (layout, styling, text changes)  
✅ **Component lifecycle tracking** (mount, update, unmount)

### What Current Tests Need

| Test Type | Current Need | Fiber-Recorder Match |
|-----------|-------------|---------------------|
| Tool call verification | ✅ Telemetry logs | ❌ Not applicable |
| Transcript content | ✅ String matching | ⚠️ Partial (can verify rendered text) |
| UI layout/styling | ❌ **Missing** | ✅ **Perfect match** |
| Component rendering | ⚠️ `lastFrame()` only | ✅ Full tree + state |
| Interaction flows | ❌ **Missing** | ✅ Commit-by-commit state |

---

## Migration Strategy: Hybrid Approach

### Phase 1: Augment Existing Tests (Recommended First Step)

**Goal**: Add fiber-recorder validation **alongside** existing assertions

```typescript
// Enhanced TestRig with fiber-recorder
class TestRig {
  async run(prompt, options = {}) {
    const env = {
      ...process.env,
      ENABLE_FIBER_LOGGER: options.recordFiber ? 'true' : 'false',
      FIBER_LOG_PATH: join(this.testDir!, 'fiber-log.jsonl'),
    };
    
    // ... spawn CLI with env
  }
  
  readFiberLog() {
    const logPath = join(this.testDir!, 'fiber-log.jsonl');
    return fs.readFileSync(logPath, 'utf-8')
      .split('\n')
      .filter(line => line.trim())
      .map(line => JSON.parse(line));
  }
  
  async waitForUIState(predicate, timeout = 5000) {
    return this.poll(() => {
      const commits = this.readFiberLog();
      return commits.some(predicate);
    }, timeout, 100);
  }
}
```

**Example Enhanced Test**:

```typescript
test('todo list displays correctly', async () => {
  const rig = new TestRig();
  await rig.setup('todo ui test');
  
  // Existing functional verification
  await rig.run('Create a todo: Build auth (in_progress)', { recordFiber: true });
  const toolCall = await rig.waitForToolCall('todo_write');
  assert.ok(toolCall);
  
  // NEW: Fiber-recorder UI verification
  const hasCorrectUI = await rig.waitForUIState(commit => {
    // Verify todo item is rendered
    const fiber = commit.fiber;
    return findInTree(fiber, node => 
      node.type === 'TodoItem' && 
      node.props?.status === 'in_progress' &&
      node.stateNode?.text?.includes('Build auth')
    );
  });
  
  assert.ok(hasCorrectUI, 'Todo item should render with correct state');
});
```

### Phase 2: Replace Snapshot Tests

**Target**: Component tests using `toMatchSnapshot()`

**Before**:
```typescript
const { lastFrame } = render(<HistoryItemDisplay item={item} />);
expect(lastFrame()).toMatchSnapshot();
```

**After**:
```typescript
const recorder = attachFiberRecorder({ output: 'memory' });
render(<HistoryItemDisplay item={item} />);

const commits = recorder.getRecords();
const lastCommit = commits[commits.length - 1];

// Verify structure instead of string snapshot
expect(findInTree(lastCommit.fiber, n => n.type === 'HistoryItemDisplay')).toBeTruthy();
expect(findInTree(lastCommit.fiber, n => n.stateNode?.text === 'Expected text')).toBeTruthy();
```

### Phase 3: New UI-Focused E2E Tests

**Create tests specifically for UI regression**:

```typescript
test('tab switching preserves scroll position', async () => {
  const rig = new TestRig();
  await rig.setup('tab scroll test');
  
  await rig.run('Generate long output', { recordFiber: true });
  
  // Capture initial state
  const commits = rig.readFiberLog();
  const chatTabCommit = commits.find(c => 
    findInTree(c.fiber, n => n.type === 'ChatTab' && n.props?.active === true)
  );
  
  const initialScrollOffset = findInTree(chatTabCommit.fiber, n => 
    n.type === 'VirtualizedList'
  )?.props?.scrollOffset;
  
  // Switch tabs
  await rig.sendInput('\u0003\u000f'); // Ctrl+O to switch tabs
  await rig.sendInput('\u0003\u000f'); // Switch back
  
  // Verify scroll position preserved
  const finalCommits = rig.readFiberLog();
  const finalScrollOffset = findInTree(finalCommits[finalCommits.length - 1].fiber, n => 
    n.type === 'VirtualizedList'
  )?.props?.scrollOffset;
  
  assert.equal(finalScrollOffset, initialScrollOffset, 'Scroll position should be preserved');
});
```

---

## Implementation Plan

### Step 1: Enhance TestRig (1-2 hours)

**File**: `integration-tests/test-helper.ts`

**Changes**:
- [ ] Add `recordFiber` option to `run()` method
- [ ] Add `readFiberLog()` method
- [ ] Add `waitForUIState(predicate)` helper
- [ ] Add `findInTree(fiber, predicate)` utility

### Step 2: Create Fiber Assertion Helpers (2-3 hours)

**New File**: `integration-tests/fiber-test-utils.ts`

```typescript
export function findInTree(fiber, predicate) {
  if (!fiber) return null;
  if (predicate(fiber)) return fiber;
  
  if (fiber.children) {
    for (const child of fiber.children) {
      const found = findInTree(child, predicate);
      if (found) return found;
    }
  }
  return null;
}

export function assertComponentRendered(commits, componentType, props = {}) {
  const found = commits.some(commit => 
    findInTree(commit.fiber, node => {
      if (node.type !== componentType) return false;
      return Object.entries(props).every(([key, value]) => 
        node.props?.[key] === value
      );
    })
  );
  
  if (!found) {
    throw new Error(`Component ${componentType} with props ${JSON.stringify(props)} not found in fiber log`);
  }
}

export function assertTextRendered(commits, text) {
  const found = commits.some(commit => 
    findInTree(commit.fiber, node => node.stateNode?.text?.includes(text))
  );
  
  if (!found) {
    throw new Error(`Text "${text}" not found in any rendered component`);
  }
}
```

### Step 3: Migrate Placeholder Tests (2-3 hours)

**File**: `packages/cli/src/ui/App.e2e.test.tsx`

Convert placeholder tests to real fiber-recorder-based UI tests:

```typescript
it('should display clear user instructions for clipboard copy behavior', async () => {
  const rig = new TestRig();
  await rig.setup('clipboard instructions test');
  
  // Trigger OAuth flow
  await rig.run('Authenticate with Gemini', { recordFiber: true });
  
  // Verify instruction text is rendered
  const commits = rig.readFiberLog();
  assertTextRendered(commits, 'Copy the verification code');
  assertTextRendered(commits, 'Paste it here');
  
  await rig.cleanup();
});
```

### Step 4: Add UI Regression Tests (3-4 hours)

**New File**: `integration-tests/ui-regression.e2e.test.ts`

Tests for known UI issues:
- Tab switching scroll preservation
- Long output rendering
- Tool call window display
- Footer overlap prevention

### Step 5: Update Component Tests (2-3 hours)

Replace `toMatchSnapshot()` in:
- `HistoryItemDisplay.test.tsx` (4 snapshot tests)
- Other component tests with snapshots

---

## Benefits of Migration

### ✅ Advantages

1. **Visual Regression Detection**: Catch UI layout/styling bugs automatically
2. **Structural Validation**: Verify component tree structure, not just text output
3. **State Inspection**: Access component props/state for detailed assertions
4. **Temporal Analysis**: Track UI changes across interactions
5. **Reduced Brittleness**: Less reliance on exact string matching

### ⚠️ Limitations

1. **Not a Replacement for Functional Tests**: Still need telemetry for tool call verification
2. **Learning Curve**: Team needs to understand Fiber tree structure
3. **Test Complexity**: Fiber assertions more verbose than string matching
4. **Performance**: Fiber logging adds overhead (mitigated by selective enablement)

---

## Validation Approach

### Before Migration
- ✅ Run full test suite: `npm run test:e2e`
- ✅ Verify all tests pass

### After Each Phase
- ✅ Run migrated tests with fiber-recorder enabled
- ✅ Run original tests to ensure no regression
- ✅ Compare coverage: `npm run test -- --coverage`

### Success Criteria
- [ ] All existing tests still pass
- [ ] New fiber-recorder tests detect known UI bugs
- [ ] Test execution time increase < 20%
- [ ] No false positives in CI

---

## Recommended Next Steps

1. **Implement Phase 1** (TestRig enhancement) - **Start here**
2. **Create 2-3 pilot tests** using fiber-recorder for known UI issues
3. **Evaluate effectiveness** - Does it catch real bugs?
4. **Decide on full migration** based on pilot results
5. **Document patterns** for team adoption

---

## Questions for User Review

> [!IMPORTANT]
> **Decision Points**
> 
> 1. Should we proceed with **Phase 1 (Hybrid Approach)** or explore a different strategy?
> 2. Which test category should we prioritize for migration?
>    - Placeholder tests (high value, low risk)
>    - Component snapshot tests (medium value, medium risk)
>    - New UI regression tests (high value, requires new test cases)
> 3. What is the acceptable test execution time increase?
> 4. Should fiber-recorder be **always enabled** or **opt-in per test**?
