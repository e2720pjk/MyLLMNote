# Implementation Plan - Optimize ASTReadFileTool (Phase 2: Lazy & Config-Driven)

## Goal Description
Refactor `ASTReadFileTool` to adopt a "Lazy > Eager" and "Working Set > Full Workspace" architecture. This solves the performance/memory CLI crash issues by:
1.  Disabling full workspace indexing by default (but preserving code behind a flag).
2.  Implementing on-demand, strictly limited `findInFiles` queries for context.
3.  Adding robust configuration and performance monitoring.

## User Review Required
> [!NOTE]
> **Philosophy**: We are shifting from "Index Everything" to "Query On Demand".
> **Backward Compatibility**: The old `buildSymbolIndex` logic is preserved but marked `@deprecated` and disabled by default via `ASTConfig.ENABLE_SYMBOL_INDEXING = false`.

## Proposed Changes

### packages/core

#### [MODIFY] [ast-edit.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/ast-edit.ts)

1.  **Enhance `ASTConfig`**:
    *   Add `ENABLE_SYMBOL_INDEXING = false` (Default OFF).
    *   Add `SYMBOL_SEARCH_LIMIT = 20` (Max results per symbol).
    *   Add `MAX_SYMBOLS_TO_QUERY = 5` (Max symbols to look up per file).
    *   Add `FIND_RELATED_TIMEOUT_MS = 3000`.
    *   Add `ENABLE_CROSS_FILE_ANALYSIS = true`.

2.  **Refactor `CrossFileRelationshipAnalyzer`**:
    *   [MODIFY] `buildSymbolIndex`: Guard with `if (!ASTConfig.ENABLE_SYMBOL_INDEXING) return;`. Mark `@deprecated`.
    *   [MODIFY] `findRelatedSymbols`:
        *   **Primary Path**: Use `findInFiles` (via `queryViaFindInFiles` helper) with timeout and limits.
        *   **Fallback Path**: Only check `this.symbolIndex` if `ENABLE_SYMBOL_INDEXING` is true.
        *   **Error Handling**: Catch errors, log warning, return empty array (do NOT fail).

3.  **Refactor `ASTContextCollector`**:
    *   [ADD] `DebugLogger` for metrics (`llxprt:ast:context`).
    *   [MODIFY] `collectEnhancedContext`:
        *   **Metrics**: Track duration and memory delta.
        *   **Logic**:
            *   Conditionalize `buildSymbolIndex` call.
            *   Extract important symbols using new `prioritizeSymbols` logic (Exported > Class > Function).
            *   Limit concurrent queries to `MAX_SYMBOLS_TO_QUERY`.
            *   Use `Promise.allSettled` to survive partial failures.

#### [NEW] [ast-edit.test.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/ast-edit.test.ts)
*(Note: May modify existing test file instead of creating new)*

1.  **Test Configuration Toggles**:
    *   Verify `buildSymbolIndex` is skipped when disabled.
2.  **Test Limits**:
    *   Verify only top N symbols are queried.
    *   Verify results are capped.
3.  **Test Fallback**:
    *   Verify correct behavior when `findInFiles` fails or returns empty.

## Verification Plan

### Automated Tests
- `npm test packages/core/src/tools/ast-edit.test.ts`
- specifically run the new `Performance Optimization` describe block.

### Manual Verification
- **Speed Test**: Run `ast_read_file` on `ast-edit.ts`. Expect < 1s response.
- **Memory Test**: Check memory usage logs (via `DebugLogger`) to ensure no massive spikes.
