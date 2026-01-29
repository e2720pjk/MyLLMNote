# Restore nextSpeakerChecker

## Goal Description
Restore `nextSpeakerChecker.ts` to `llxprt-code-3` from `gemini-cli` and integrate it, ensuring it respects the new configuration options (enable/disable).

## User Review Required
- [ ] Confirm if `nextSpeakerChecker` should be enabled by default.

## Proposed Changes
### Core
#### [NEW] [nextSpeakerChecker.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-3/packages/core/src/utils/nextSpeakerChecker.ts)
- Create `nextSpeakerChecker.ts` based on `gemini-cli` version.
- Define `JsonGenerator` interface to match `GeminiClient.generateJson` signature.
- Adapt `checkNextSpeaker` to use `JsonGenerator` and `DEFAULT_GEMINI_FLASH_MODEL`.

#### [MODIFY] [client.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-3/packages/core/src/core/client.ts)
- Import `checkNextSpeaker` and `DEFAULT_GEMINI_FLASH_MODEL`.
- In `sendMessageStream`, after the tool execution check and before returning the turn, add `checkNextSpeaker` logic.
- Use `this.config.getSkipNextSpeakerCheck()` to conditionally run it.
- If `next_speaker` is 'model', recursively call `sendMessageStream` with "Please continue.".

#### [MODIFY] [config.ts](file:///Users/caishanghong/Shopify/cli-tool/llxprt-code-3/packages/core/src/config/config.ts)
- Ensure `skipNextSpeakerCheck` is exposed (already verified).

## Verification Plan
### Automated Tests
- Run `npm test` in `packages/core`.

### Manual Verification
- Verify that the checker runs (or doesn't run) based on config.
