## TLDR

Fixes a critical issue where the terminal would be left in a corrupted state (showing raw escape codes, bell sounds) after exiting the application via `CTRL+C` or a crash. This was caused by the Kitty keyboard protocol not being disabled correctly due to asynchronous cleanup and conflicting signal handlers.

## Dive Deeper

The root cause was identified as:
1.  **Asynchronous Cleanup**: The `disableProtocol` function used `process.stdout.write`, which is asynchronous. In crash or forced exit scenarios, the process would terminate before the write completed.
2.  **Conflicting Signal Handlers**: Global `SIGINT` handlers in `gemini.tsx` were exiting the process immediately, bypassing the UI's internal `CTRL+C` handling (which implements a "press twice to exit" safety mechanism) and potentially racing with cleanup.

The fix involves:
-   **Synchronous Write**: Using `fs.writeSync(process.stdout.fd, ...)` to guarantee the reset sequence `\x1b[<u` is sent to the terminal immediately.
-   **Aligned Signal Handling**: Removed explicit exit calls in global `SIGINT` handlers to match `gemini-cli` behavior and allow `AppContainer` to manage the exit flow gracefully.
-   **Crash Safety**: Added handlers for `SIGTERM`, `uncaughtException`, and `unhandledRejection` to ensure cleanup happens even during crashes.

## Reviewer Test Plan

1.  **CTRL+C Test**:
    -   Run `llxprt` (or `npm start`).
    -   Press `CTRL+C`.
    -   **Verify**: The application shows "Press Ctrl+C again to quit" (or similar prompt) instead of exiting immediately.
    -   Press `CTRL+C` again.
    -   **Verify**: The application exits and the terminal returns to normal immediately. No `^[[A` or bell sounds when typing.

2.  **Crash Test**:
    -   (Optional) Temporarily add `throw new Error("Crash test")` somewhere in the startup code.
    -   Run the app.
    -   **Verify**: The terminal returns to normal despite the crash.

## Testing Matrix

|          | 🍏  | 🪟  | 🐧  |
| -------- | --- | --- | --- |
| npm run  | ✅  | ❓  | ❓  |
| npx      | ✅  | ❓  | ❓  |
| Docker   | ❓  | ❓  | ❓  |
| Podman   | ❓  | -   | -   |
| Seatbelt | ❓  | -   | -   |

## Linked issues / bugs

Fixes #26
