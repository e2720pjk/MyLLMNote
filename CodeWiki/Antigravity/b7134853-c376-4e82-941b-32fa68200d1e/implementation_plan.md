# Implement WebSearch Tool

## Goal Description
Implement `ExaWebSearchTool` based on the `opencode` implementation and rename the existing `WebSearchTool` to `GoogleWebSearchTool` to avoid confusion.

## Proposed Changes

### WebSearch Tool
#### [MODIFY] [google-web-search.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/google-web-search.ts)
- Rename `WebSearchTool` to `GoogleWebSearchTool`
#### [NEW] [exa-web-search.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/exa-web-search.ts)
- Implement `ExaWebSearchTool` using Exa.ai API
#### [NEW] [exa-web-search.md](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/prompt-config/defaults/tools/exa-web-search.md)
- Documentation for `ExaWebSearchTool`

### CodeSearch Configuration
- [x] Refine `tokensNum` logic in `codesearch.ts`
- [x] Add tests for `tokensNum` clamping and settings integration

### DirectWebFetch Refactor
- [x] Remove `timeout` from `fetch` options
- [x] Implement `AbortController` for timeout handling
- [x] Ensure resource cleanup in `finally` block

### Signal Handling Fixes
#### [MODIFY] [fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/utils/fetch.ts)
- Update `fetchWithTimeout` to accept optional `AbortSignal`
- Merge external signal with timeout controller

#### [MODIFY] [google-web-fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/google-web-fetch.ts)
- Pass `signal` to `fetchWithTimeout` in `executeFallback`

## Verification Plan
### Automated Tests
- Run `npm run test` to verify all tests pass.
