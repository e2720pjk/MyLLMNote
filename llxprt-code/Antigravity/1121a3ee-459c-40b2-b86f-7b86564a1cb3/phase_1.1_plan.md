# Phase 1.1: Screen Reader Support Implementation Plan

## Overview

Complete the gemini-cli UI optimization alignment by implementing missing Screen Reader (SR) support components identified in the gap analysis.

## Background

Based on direct comparison with gemini-cli codebase:
- gemini-cli has `ScreenReaderAppLayout.tsx` with SR-optimized layout
- gemini-cli uses conditional rendering in App.tsx based on `useIsScreenReaderEnabled()`
- llxprt-code is missing both components

**Gap Analysis Findings**:
- ✅ useRenderMode: Correctly implemented
- ✅ historyRemountKey: Correctly implemented  
- ❌ ScreenReaderAppLayout: Completely missing
- ❌ SR conditional rendering: Missing from AppContainer
- ⚠️ pendingHistory field: Does not exist in gemini-cli, should be removed (optional cleanup)

## Proposed Changes

### Component 1: ScreenReaderAppLayout.tsx

#### [NEW] packages/cli/src/ui/layouts/ScreenReaderAppLayout.tsx

**Purpose**: SR-optimized layout with Footer on top and 90% width for better screen reader navigation.

**Implementation**: Based on gemini-cli reference, adapted for llxprt-code architecture.

```typescript
/**
 * @license
 * Copyright 2025 Vybestack LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { Box } from 'ink';
import { MainContent } from '../components/MainContent.js';
import { Composer } from '../components/Composer.js';
import { Footer } from '../components/Footer.js';
import { Notifications } from '../components/Notifications.js';
import { useUIState } from '../contexts/UIStateContext.js';
import { useFlickerDetector } from '../hooks/useFlickerDetector.js';
import type { Config } from '@vybestack/llxprt-code-core';

interface ScreenReaderAppLayoutProps {
  config: Config;
}

/**
 * Screen Reader optimized app layout.
 * Key differences from DefaultAppLayout:
 * - Footer positioned at top for better SR navigation
 * - Width constrained to 90% for better SR readability
 * - Component order optimized for sequential SR reading
 */
export const ScreenReaderAppLayout: React.FC<ScreenReaderAppLayoutProps> = ({
  config,
}) => {
  const uiState = useUIState();
  const { rootUiRef, terminalHeight, constrainHeight } = uiState;

  useFlickerDetector(rootUiRef, terminalHeight, constrainHeight);

  return (
    <Box
      flexDirection="column"
      width="90%"  // SR optimized width
      height="100%"
      ref={rootUiRef}
    >
      <Notifications />
      <Footer />  {/* Footer on top for SR optimization */}
      <Box flexGrow={1} overflow="hidden">
        <MainContent config={config} />
      </Box>
      {uiState.isInputActive && <Composer />}
    </Box>
  );
};
```

**Key Design Decisions**:
1. Footer on top: Provides context before content (SR optimization)
2. 90% width: Prevents overly long line lengths for SR users
3. useFlickerDetector: Same as DefaultAppLayout for consistency
4. Component order: Notifications → Footer → MainContent → Composer

---

### Component 2: AppContainer.tsx Updates

#### [MODIFY] packages/cli/src/ui/AppContainer.tsx

**Changes Required**:

1. **Add imports** (after existing ink imports around line 15):
```typescript
import { useIsScreenReaderEnabled } from 'ink';
```

2. **Add import** (after DefaultAppLayout import around line 113):
```typescript
import { ScreenReaderAppLayout } from './layouts/ScreenReaderAppLayout.js';
```

3. **Add SR detection** (in AppContainer function body, after other hooks):
```typescript
const isScreenReaderEnabled = useIsScreenReaderEnabled();
```

4. **Update render logic** (find the DefaultAppLayout usage and replace with conditional):

**Before**:
```typescript
<DefaultAppLayout config={config} />
```

**After**:
```typescript
{isScreenReaderEnabled ? (
  <ScreenReaderAppLayout config={config} />
) : (
  <DefaultAppLayout config={config} />
)}
```

**Full context example** (render section):
```typescript
return (
  <StreamingContext.Provider value={streamingState}>
    <UIStateProvider value={uiState}>
      <UIActionsProvider value={uiActions}>
        {isScreenReaderEnabled ? (
          <ScreenReaderAppLayout config={config} />
        ) : (
          <DefaultAppLayout config={config} />
        )}
      </UIActionsProvider>
    </UIStateProvider>
  </StreamingContext.Provider>
);
```

---

### Optional Cleanup: Remove pendingHistory

#### [MODIFY] packages/cli/src/ui/contexts/UIStateContext.tsx

**Investigation Result**: gemini-cli does NOT have a `pendingHistory` field. It only uses `pendingHistoryItems`.

**Recommendation**: Remove pendingHistory field (non-blocking).

**Change** (Line 51):
```typescript
// Before
pendingHistory: HistoryItem[]; // Dynamic history for alternate buffer

// After
// Remove this line entirely
```

#### [MODIFY] packages/cli/src/ui/AppContainer.tsx

**Change** (Line 1530):
```typescript
// Before
pendingHistory: [], // Dynamic history for alternate buffer

// After
// Remove this line entirely
```

---

## Verification Plan

### Manual Testing

1. **Test SR Mode Detection**:
   - Enable screen reader on system
   - Launch llxprt-code
   - Verify ScreenReaderAppLayout is used
   - Check Footer is at top
   - Verify 90% width constraint

2. **Test Default Mode**:
   - Disable screen reader
   - Launch llxprt-code
   - Verify DefaultAppLayout is used
   - Check standard layout

3. **Test Mode Switching** (if applicable):
   - Toggle screen reader during runtime
   - Verify layout switches appropriately

### Automated Tests

```bash
npm run preflight
```

Expected results:
- All existing tests pass
- No new lint errors
- Build succeeds
- Type checking passes

### Accessibility Validation

1. Test with actual screen reader (NVDA on Windows, VoiceOver on macOS)
2. Verify component reading order
3. Confirm Footer information is announced first
4. Check navigation flow

---

## Success Criteria

- [ ] ScreenReaderAppLayout.tsx created with SR-optimized layout
- [ ] AppContainer.tsx uses conditional rendering based on SR detection
- [ ] All tests pass (npm run preflight)
- [ ] No type errors
- [ ] No lint errors
- [ ] Manual testing confirms layout switches based on SR status
- [ ] (Optional) pendingHistory field removed with no breakage

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-------------|
| useFlickerDetector conflicts | Low | Medium | Copy exact pattern from DefaultAppLayout |
| Import path errors | Low | Low | Follow existing import patterns |
| SR detection false positives | Low | Medium | useIsScreenReaderEnabled is provided by ink |
| Layout rendering issues | Low | Medium | Based on proven gemini-cli implementation |

---

## Rollback Plan

If issues occur:
1. Revert AppContainer.tsx conditional rendering
2. Keep ScreenReaderAppLayout.tsx (no harm)
3. Fix issues and retry

---

## References

- gemini-cli ScreenReaderAppLayout: `/Users/caishanghong/Shopify/cli-tool/gemini-cli/packages/cli/src/ui/layouts/ScreenReaderAppLayout.tsx` (if exists)
- gemini-cli App.tsx: Conditional rendering pattern
- Gap Analysis: `/Users/caishanghong/.gemini/antigravity/brain/.../verified_gap_analysis.md`
- pendingHistory Investigation: `/Users/caishanghong/.gemini/antigravity/brain/.../pendingHistory_investigation.md`
