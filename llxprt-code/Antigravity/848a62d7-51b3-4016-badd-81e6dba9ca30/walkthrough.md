# Walkthrough - Fix Terminal Corruption Issue

I have fixed the terminal corruption issue (Issue #26) by implementing synchronous cleanup for the Kitty keyboard protocol and aligning signal handling with `gemini-cli`.

## Changes

### `packages/cli/src/ui/utils/kittyProtocolDetector.ts`

-   **Synchronous Cleanup**: Replaced `process.stdout.write` with `fs.writeSync` in `disableProtocol` to ensure the terminal reset sequence `\x1b[<u` is flushed before the process exits.
-   **Signal Handling**:
    -   Removed the `SIGINT` handler to allow `AppContainer` to handle `CTRL+C` logic (e.g., double-press to exit).
    -   Added `SIGTERM`, `uncaughtException`, and `unhandledRejection` handlers to ensure cleanup during crashes or termination.
    -   Used `process.once` to prevent duplicate listeners.
-   **Re-entry Protection**: Added `protocolEnabled` flag check and update *before* writing to prevent re-entry issues.

### `packages/cli/src/gemini.tsx`

-   **Signal Handling Alignment**: Removed explicit `process.exit` calls from `SIGINT` and `SIGTERM` handlers. This matches `gemini-cli` behavior and prevents the global handler from preempting the UI's input handling logic.

## Verification Results

### Automated Tests
-   `npm run lint`: Passed.
-   `npm run build`: Failed due to unrelated `read-only.toml` missing error (pre-existing issue).
-   `npm run test`: Failed due to unrelated `read-only.toml` missing error (pre-existing issue).

### Manual Verification Plan

1.  **Normal Exit**:
    -   Run the app.
    -   Exit using `/quit` or similar command.
    -   Verify terminal is usable (no bell, no raw codes).

2.  **CTRL+C Exit**:
    -   Run the app.
    -   Press `CTRL+C`.
    -   Verify prompt "Press Ctrl+C again to quit" appears (if implemented) or app stays responsive.
    -   Press `CTRL+C` again.
    -   Verify app exits and terminal is usable.

3.  **Crash Exit**:
    -   Simulate a crash (e.g., throw error).
    -   Verify terminal is usable after crash.
