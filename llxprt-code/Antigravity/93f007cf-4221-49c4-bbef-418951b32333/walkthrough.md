# Walkthrough - Fix Terminal Corruption in Kitty Protocol Detector

I have implemented a robust fix for the terminal corruption issue by introducing a centralized `SignalManager`. This ensures that cleanup handlers (like disabling the Kitty protocol and bracketed paste mode) are reliably executed when the application exits, specifically addressing the `CTRL+C` (SIGINT) scenario.

## Changes

### Centralized Signal Handling

I created a new `SignalManager` class to handle process signals (`SIGINT`, `SIGTERM`, `uncaughtException`, `unhandledRejection`) in a unified way.

#### [NEW] [signalManager.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/utils/signalManager.ts)
```typescript
export class SignalManager {
  // ... singleton implementation ...
  initialize(): void {
    process.once('SIGINT', () => this.handleShutdown('SIGINT', 0));
    // ... other signals ...
  }
  // ... executes cleanup handlers sequentially ...
}
```

### Updated Cleanup Logic

I refactored existing cleanup mechanisms to use the `SignalManager`.

#### [MODIFY] [cleanup.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/utils/cleanup.ts)
- `registerCleanup` now delegates to `SignalManager`.
- `runExitCleanup` is deprecated/no-op as `SignalManager` handles it.

#### [MODIFY] [gemini.tsx](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/gemini.tsx)
- Initialized `SignalManager` in `main()`.
- Replaced manual `SIGINT` listeners with `signalManager.registerCleanup`.

### Reliable Terminal Writes

I updated terminal control functions to use synchronous writes (`fs.writeSync`) to ensure escape sequences are flushed to the terminal before the process exits.

#### [MODIFY] [bracketedPaste.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/ui/utils/bracketedPaste.ts)
- Switched from `process.stdout.write` to `fs.writeSync`.

#### [MODIFY] [kittyProtocolDetector.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code/packages/cli/src/ui/utils/kittyProtocolDetector.ts)
- Switched to `fs.writeSync` for disabling the protocol.
- Registered `disableProtocol` with `SignalManager` instead of attaching its own listeners.

## Verification Results

### Automated Verification
I ran a verification script `verify_signal_manager.ts` to simulate a `SIGINT` signal and verify that cleanup handlers are executed.

**Output:**
```
Starting SignalManager verification...
Simulating SIGINT...
Cleanup handler executed
process.exit called with code: 0
SUCCESS: Cleanup handler was called.
```

### Manual Verification Steps
To manually verify the fix:
1.  Start the `llxprt` CLI.
2.  Press `CTRL+C`.
3.  **Expected Result**: The application should exit immediately, and the terminal should return to a normal state (cursor visible, no raw escape codes printed when typing).
