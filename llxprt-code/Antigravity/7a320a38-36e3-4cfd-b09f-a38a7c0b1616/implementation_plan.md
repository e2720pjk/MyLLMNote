# Fix WebFetch Signal Propagation

## Goal Description
Fix the issue where `GoogleWebFetchTool` fails to cancel the underlying network request when the tool execution is cancelled. This is caused by `fetchWithTimeout` not accepting or using the external `AbortSignal`.

## User Review Required
> [!NOTE]
> This fix involves modifying a shared utility `fetchWithTimeout`. Any other consumers of this utility will need to be updated if they rely on the function signature, although the new argument will be optional.

## Proposed Changes

### Core Utils
#### [MODIFY] [fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/utils/fetch.ts)
- Update `fetchWithTimeout` to accept an optional `signal: AbortSignal`.
- Logic to merge the timeout signal with the external signal (using `AbortSignal.any` if available, or a helper).
  - *Note*: Node 18+ supports `AbortSignal.any()`. If we need to support older versions, we might need a polyfill or a manual event listener approach. Assuming modern Node for this CLI tool.

### Tools
#### [MODIFY] [google-web-fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/google-web-fetch.ts)
- Update `executeFallback` to pass the `signal` to `fetchWithTimeout`.

## Verification Plan

### Automated Tests
- Create a new test file `packages/core/src/utils/fetch.test.ts` (if not exists) or update it to test `fetchWithTimeout` with an external signal.
- Verify that aborting the external signal aborts the fetch.

### Manual Verification
- Run the CLI.
- Trigger a web fetch (e.g., "fetch google.com").
- Cancel the operation (Ctrl+C or UI cancel) immediately.
- Verify in logs (if possible) or by network observation that the request was aborted.
