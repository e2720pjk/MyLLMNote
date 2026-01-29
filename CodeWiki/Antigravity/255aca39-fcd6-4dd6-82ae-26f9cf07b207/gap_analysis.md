# Gap Analysis: Tool Integration in `llxprt-code-2`

## Objective
Analyze the steps required to add a new tool to `llxprt-code` based on commit `fbf628ec6894ec03e4b329ba163d9fed46d1a306` and identify gaps in the current `llxprt-code-2` integration.

## Standard Tool Addition Steps
Based on the analysis of `llxprt-code` codebase and the reference commit:

1.  **Implementation**:
    *   Create a new file in `packages/core/src/tools/` (e.g., `my-tool.ts`).
    *   Define a class extending `BaseDeclarativeTool`.
    *   Define a static `Name` property.
    *   Implement `createInvocation` method.
    *   Define an invocation class extending `BaseToolInvocation`.

2.  **Registration**:
    *   Import the tool class in `packages/core/src/config/config.ts`.
    *   Register the tool in the `createToolRegistry` method using `registerCoreTool(ToolClass, this)`.

3.  **Testing** (Best Practice):
    *   Create a corresponding test file (e.g., `my-tool.test.ts`) in the same directory.
    *   Use `vitest` (or similar) to verify tool behavior, mocking dependencies like `Config` or `FileSystemService`.
    *   *Note: The reference commit `fbf628ec` appeared to skip unit tests for the new file tools, but standard tools like `read-file.ts` have comprehensive tests.*

## Current Status of `llxprt-code-2` Integration

### Completed
- [x] **Implementation**: `CodeSearchTool` (`codesearch.ts`) and `WebFetchTool` (`webfetch.ts`) are implemented following the standard pattern.
- [x] **Registration**: Both tools are correctly registered in `packages/core/src/config/config.ts`.

### Gaps Identified
- [ ] **Unit Tests**:
    -   `CodeSearchTool` lacks a unit test file (`codesearch.test.ts`).
    -   `WebFetchTool` lacks a unit test file (`webfetch.test.ts`).

## Recommendations
1.  Create `packages/core/src/tools/codesearch.test.ts` to verify API interaction (mocking `fetch`).
2.  Create `packages/core/src/tools/webfetch.test.ts` to verify URL fetching and content conversion (mocking `fetch`, `turndown`, `cheerio`).
