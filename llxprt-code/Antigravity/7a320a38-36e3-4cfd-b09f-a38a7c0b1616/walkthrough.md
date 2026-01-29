# WebFetch Signal Propagation Fix

I have fixed the issue where `GoogleWebFetchTool` would not cancel the network request when the tool execution was cancelled.

## Changes

### Core Utils
#### [fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/utils/fetch.ts)
- Updated `fetchWithTimeout` to accept an optional `signal: AbortSignal`.
- Added logic to listen to the external signal and abort the internal controller if the external signal is aborted.
- Added logic to correctly identify `AbortError` from `fetch` (handling both Node errors and DOMExceptions) and rethrow it as a `FetchError` with the correct message if it was user-initiated.

### Tools
#### [google-web-fetch.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/core/src/tools/google-web-fetch.ts)
- Updated `executeFallback` to pass the `signal` from `execute` to `fetchWithTimeout`.

### Lint Fixes
- Fixed `no-explicit-any` error in `fetch.ts` by using `unknown` type and safe property access for error handling.

### Code Review Fixes
- Fixed potential memory leak in `fetchWithTimeout` by properly removing the `abort` event listener from the external signal in the `finally` block.



## Verification Results

### Manual Verification
I created a manual test script `packages/core/src/utils/fetch.manual.test.ts` that verified:
1.  **Successful fetch**: `fetchWithTimeout` works as expected for normal requests.
2.  **Timeout**: `fetchWithTimeout` correctly times out if the request takes too long.
3.  **Abort**: `fetchWithTimeout` correctly aborts if the external `AbortSignal` is triggered.

All tests passed.

```
Starting test...
Test 1: Successful fetch (google.com)
Test 1 Passed
Test 2: Timeout (1ms)
Test 2 Passed: Timed out as expected
Test 3: Abort
Test 3 Passed: Aborted as expected
```
