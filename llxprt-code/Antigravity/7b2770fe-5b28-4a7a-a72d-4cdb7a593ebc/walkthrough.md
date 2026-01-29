# Walkthrough - Fix Input Prompt Misalignment & Height Calculation Stability

## Goal
Fix the vertical misalignment of the input prompt in `llxprt-code-4` and stabilize the dynamic height calculation to prevent UI jitter, overlap, and infinite loops.

## Changes

### 1. Input Prompt Misalignment
- **File:** `packages/cli/src/ui/components/InputPrompt.tsx`
- **Issue:** The prompt text was rendering one line below the `>` symbol due to an extra newline in the `Text` component.
- **Fix:** Removed the newline and ensured `flexDirection="row"` alignment.

### 2. Height Calculation Stability
- **File:** `packages/cli/src/ui/AppContainer.tsx`
- **Issue:**
    - `llxprt-code-2` was stable but static (only updated on resize), causing overflow with dynamic panels.
    - `llxprt-code-4` (initial fix) was dynamic but prone to jitter loops.
    - **Regression:** Debug Console and TodoPanel overlapped with Footer because their height changes were ignored.
    - **Infinite Loop:** Adding `consoleMessages.length` to dependencies caused an infinite loop when error logs triggered re-renders which triggered more error logs.
- **Fix:** Aligned with `gemini-cli` strategy + `llxprt` support + Debug awareness (Safe Mode).
    - Updated `useLayoutEffect` dependency array to:
      `[buffer, terminalHeight, terminalWidth, settings.merged.showTodoPanel, showErrorDetails]`.
    - **Why:**
        - `buffer`: Updates height when user types (Composer grows).
        - `showTodoPanel`: Updates height when TodoPanel toggles.
        - `showErrorDetails`: Updates height when Debug Console opens/closes.
        - `terminalHeight/Width`: Updates on resize.
        - **Removed `consoleMessages.length`:** To prevent infinite loops. This means if the Debug Console grows *while open*, the layout might not immediately adjust until the user types or interacts, but this is a necessary trade-off for stability.
        - **Stability:** During LLM streaming (without debug logs), `buffer` is constant, so height is NOT recalculated, preventing jitter.

## Verification Results

### Automated Tests
- `npm run lint`: Passed.
- `npm run typecheck`: Passed.
- `npm run test`: Passed.

### Manual Verification
- **Typing:** Input box grows, footer adjusts correctly.
- **TodoPanel:** Toggling panel adjusts footer height correctly.
- **Debug Console:** Opening/Closing adjusts footer height correctly.
- **Infinite Loop:** **FIXED**. No more runaway renders when errors occur.
- **Streaming:** UI remains stable (no jitter) while LLM outputs text.
