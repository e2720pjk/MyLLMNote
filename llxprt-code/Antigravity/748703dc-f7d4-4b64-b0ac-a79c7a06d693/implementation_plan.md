# Fix Deadlock in OpenAI Provider Retry Logic

## Goal Description
The `llxprt` CLI experiences a deadlock when exiting (Ctrl+C) while an OpenAI provider conversation is active, specifically during retries (e.g., rate limits or network errors). The `retryWithBackoff` utility uses a `setTimeout` based delay that does not respect `AbortSignal`, causing the process to hang until the timeout completes even if the user has requested cancellation.

This plan addresses this by adding `AbortSignal` support to the retry logic and ensuring the OpenAI provider passes the signal correctly.

## User Review Required
> [!IMPORTANT]
> This change modifies a core utility `retryWithBackoff`. While intended to be backward compatible, it changes the behavior of `delay` to be abortable.

## Proposed Changes

### Core Package

#### [MODIFY] [retry.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-3/packages/core/src/utils/retry.ts)
- Update `RetryOptions` interface to include `signal?: AbortSignal`.
- Update `delay` function to accept `signal?: AbortSignal`.
  - If `signal` is provided, use it to reject the promise immediately upon abort.
- Update `retryWithBackoff` to:
  - Accept `signal` in options.
  - Pass `signal` to `delay`.
  - Check `signal.aborted` before making a new attempt.

#### [MODIFY] [OpenAIProvider.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-3/packages/core/src/providers/openai/OpenAIProvider.ts)
- In `generateLegacyChatCompletionImpl`, pass the `abortSignal` (already extracted from metadata) to `retryWithBackoff`.

## Verification Plan

### Automated Tests
- Add a new test case to `packages/core/src/utils/retry.test.ts` that verifies `retryWithBackoff` aborts immediately when the signal is triggered during a delay.
- Run tests: `npm test packages/core/src/utils/retry.test.ts`

### Manual Verification
1.  **Reproduction (Pre-fix)**:
    - Simulate a 429 error loop in OpenAI provider (can be done by mocking or using a dummy key/endpoint).
    - Trigger a request.
    - Hit Ctrl+C immediately.
    - Observe the CLI hanging for the duration of the retry delay.
2.  **Verification (Post-fix)**:
    - Repeat the above steps.
    - The CLI should exit immediately upon Ctrl+C.
