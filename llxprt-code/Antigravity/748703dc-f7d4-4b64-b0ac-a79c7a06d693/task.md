# Task: IME Ctrl+C, Deadlock & Terminal Leakage Fix Investigation

- [x] Explore and Compare Codebases <!-- id: 0 -->
    - [x] Read `packages/cli/src/gemini.tsx` in `llxprt-code-3` and `gemini-cli` <!-- id: 1 -->
    - [x] Read `packages/cli/src/utils/cleanup.ts` in `llxprt-code-3` and `gemini-cli` <!-- id: 2 -->
    - [x] Read `packages/cli/src/utils/kittyProtocolDetector.ts` in `llxprt-code-3` and `gemini-cli` <!-- id: 3 -->
    - [x] Identify IME Ctrl+C mapping logic in `llxprt-code-3` <!-- id: 4 -->
- [x] Analyze Impact on Lifecycle <!-- id: 5 -->
    - [x] Determine how IME mapping affects signal handling <!-- id: 6 -->
    - [x] Check for potential deadlocks or leakage sources <!-- id: 7 -->
- [x] Report Findings <!-- id: 8 -->
- [x] Review and Modify <!-- id: 9 -->
    - [x] Run `git diff` to review pending changes <!-- id: 10 -->
    - [x] Comment out IME mapping logic in `KeypressContext.tsx` <!-- id: 11 -->
- [ ] Investigate OpenAI Provider Issues <!-- id: 12 -->
    - [x] Locate OpenAI provider implementation <!-- id: 13 -->
    - [x] Analyze `useGeminiStream` for cancellation logic <!-- id: 14 -->
    - [x] Check for unclosed resources/handles in OpenAI provider <!-- id: 15 -->
    - [ ] Compare with `gemini-cli` implementation <!-- id: 16 -->
    - [x] Fix `retryWithBackoff` to support `AbortSignal` <!-- id: 17 -->
    - [x] Update `OpenAIProvider` to pass `AbortSignal` to retry logic <!-- id: 18 -->

