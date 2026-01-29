# Fix Terminal State and Input Issues

## Goal Description
The goal is to resolve the issue where the terminal displays a bell icon and arrow keys produce literal text input (e.g., `^[[1;2A`) during or after command execution. This behavior indicates that the terminal is left in a state where the **Kitty Keyboard Protocol** is enabled (sending complex escape sequences) but **Raw Mode** is disabled (causing the shell to echo these sequences instead of interpreting them).

The fix involves ensuring that the Kitty Keyboard Protocol is reliably disabled whenever the application exits or crashes, and using synchronous writes to ensure the disable sequence is sent before the process terminates.

## User Review Required
> [!IMPORTANT]
> This change modifies how the application handles terminal cleanup on exit. It uses `fs.writeSync` to `stdout` to ensure the cleanup sequence is flushed.

## Proposed Changes

### CLI Package

#### [MODIFY] [kittyProtocolDetector.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/cli/src/ui/utils/kittyProtocolDetector.ts)
- Update `disableProtocol` to use `fs.writeSync(process.stdout.fd, ...)` instead of `process.stdout.write(...)`. This ensures the escape sequence is written immediately and synchronously, preventing it from being lost if the process exits quickly.
- Ensure `disableProtocol` is robust against repeated calls.

#### [MODIFY] [gemini.tsx](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-2/packages/cli/src/gemini.tsx)
- Verify that `runExitCleanup` and signal handlers correctly trigger the protocol disablement.
- Consider explicitly calling `disableProtocol` (if exported) during cleanup to be safe.

## Verification Plan

### Automated Tests
- Run existing tests: `npm test packages/cli/src/ui/utils/kittyProtocolDetector.ts` (if exists) or create a new test.
- Since this involves TTY behavior, unit tests are limited. We can verify the function calls `fs.writeSync`.

### Manual Verification
1.  **Reproduction Attempt**:
    - Run the tool.
    - Enable Kitty Protocol (if terminal supports it, e.g., iTerm2, Kitty, VS Code).
    - Force a crash or exit via `Ctrl+C`.
    - Verify arrow keys work correctly in the shell afterwards.
2.  **Verify Fix**:
    - Apply changes.
    - Repeat the steps.
    - Ensure no "literal text" is printed when using arrow keys after exit.
