# Fix Terminal Corruption in Kitty Protocol Detector

## Goal Description
The goal is to prevent terminal corruption when the application exits, specifically addressing the user-reported scenario of using `CTRL+C`. Currently, the cleanup logic is missing a handler for `SIGINT` (CTRL+C) and uses asynchronous writes, which causes the terminal to remain in a "protocol enabled" state (showing raw escape codes) after the application exits.

## User Review Required
> [!IMPORTANT]
> **Root Cause Confirmed**: The current code listens for `exit` and `SIGTERM` but **ignores `SIGINT`** (CTRL+C). This explains why `CTRL+C` leaves the terminal corrupted.
>
> **The Fix**:
> 1.  **Add `SIGINT` handler**: Ensures cleanup runs on CTRL+C.
> 2.  **Use `fs.writeSync`**: Ensures the disable sequence `\x1b[<u` is actually flushed to the terminal before the process dies. Asynchronous `process.stdout.write` is unreliable during exit.
> 3.  **Robust Signal Handling**: Use `process.once` and explicit exit codes to ensure clean termination without duplicate cleanups.

## Proposed Changes

### packages/cli/src/ui/utils

#### [MODIFY] [terminalSequences.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/ui/utils/terminalSequences.ts)
- Add `writeToStdoutSync` helper function using `fs.writeSync`.

#### [MODIFY] [bracketedPaste.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/ui/utils/bracketedPaste.ts)
- Use `writeToStdoutSync` for enabling/disabling bracketed paste.

#### [MODIFY] [kittyProtocolDetector.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/ui/utils/kittyProtocolDetector.ts)
    -   **Add `SIGTERM` handler**: Call `disableProtocol()` then `process.exit(0)`.
    -   **Add `uncaughtException` handler**: Call `disableProtocol()`, log error, then `process.exit(1)`.
    -   **Add `unhandledRejection` handler**: Call `disableProtocol()`, log error, then `process.exit(1)`.
    -   **Update `exit` handler**: Keep `process.once('exit', disableProtocol)`.

## Verification Plan

### Manual Verification
1.  **CTRL+C Test**:
    -   Start the application.
    -   Press `CTRL+C`.
    -   **Pass Criteria**: Terminal should return to normal immediately. Exit code should be 130 (if checkable).
2.  **Crash Test**:
    -   Simulate a crash (e.g., throw Error).
    -   **Pass Criteria**: Terminal should be restored cleanly.
3.  **Rapid CTRL+C**:
    -   Press CTRL+C multiple times quickly.
    -   **Pass Criteria**: No errors printed, terminal restored cleanly (re-entry protection works).
