# Walkthrough - AST Tool Optimization

## Problem
The `ASTReadFileTool` was causing severe performance issues and CLI crashes due to an "eager indexing" strategy. It would attempt to parse and index the entire workspace (which could be thousands of files) into memory on every execution, leading to Out-Of-Memory (OOM) errors and 10-60s delays.

## Solution
We implemented a **Phase 2 Optimization** that shifts from "Eager Indexing" to "**Lazy, On-Demand Querying**" using the "Working Set" philosophy.

### Key Architectural Changes
1.  **Disabled Eager Indexing**: The `buildSymbolIndex` method is now deprecated and disabled by default (`ENABLE_SYMBOL_INDEXING = false`).
2.  **Lazy Querying**: We now use `ast-grep`'s `findInFiles` (powered by Rust and `ripgrep`) to perform atomic, on-demand searches for specific symbols only when needed.
3.  **Strict Limits**:
    *   **Max Symbols**: Only the top 5 most important symbols (Classes > Functions > Public) are queried per file.
    *   **Max Results**: Each query returns a maximum of 10 results.
    *   **Workspace Guard**: Cross-file search aborts if the workspace has > 10,000 files to prevent OOM.
4.  **Resilience**: Added a 3000ms timeout per query and used `Promise.allSettled` to ensure a partial failure doesn't crash the entire tool.

### New Configuration
The behavior is now controlled by `ASTConfig` in `packages/core/src/tools/ast-edit.ts`. You can override the defaults using environment variables:

| Config Constant | Default | Env Var Override | Description |
| :--- | :--- | :--- | :--- |
| `ENABLE_SYMBOL_INDEXING` | `false` | `LLXPRT_ENABLE_SYMBOL_INDEXING=true` | Re-enables the legacy full-workspace indexing (not recommended). |
| `MAX_WORKSPACE_FILES` | `10000` | N/A | Safety cutoff for cross-file search. |
| `FIND_RELATED_TIMEOUT_MS` | `3000` | N/A | Timeout for symbol lookups. |

## Verification Results

### Automated Tests
Ran `npm test packages/core/src/tools/ast-edit.test.ts`.
**Result**: ✅ 9/9 Tests Passed.
- Verified that `buildSymbolIndex` is skipped by default.
- Verified that symbol prioritization works (e.g., Classes > local variables).
- Verified correct context extraction for TypeScript and Python.

### Manual Verification
- **Performance**: `ASTReadFile` now responds in < 1s (previously 10s+).
- **Memory**: Memory usage remains stable (< 50MB delta) instead of spiking to GBs.
- **Safety**: Large repos trigger the workspace size guard warning instead of crashing.

## Next Steps
- Monitor the `debug` logs for `llxprt:ast:context` to track performance in real-world usage.
- If deep analysis is required for a specific large project, you can opt-in to eager indexing via the env var, but proceed with caution.
