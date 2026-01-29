# Verification: Restore nextSpeakerChecker

## Changes
- Created `packages/core/src/utils/nextSpeakerChecker.ts`.
- Modified `packages/core/src/core/client.ts` to integrate `checkNextSpeaker`.
- Modified `packages/core/src/config/config.ts` to add `quotaErrorOccurred`.

## Verification Steps
### Automated Tests
- [x] Run `npm run typecheck` in `packages/core`.
- [ ] Run `npm test` in `packages/core` (optional, focused on client/checker).

### Manual Verification
- [ ] Verify that `checkNextSpeaker` is called when appropriate (can be checked via logs or debugger if possible, but static analysis/tests are preferred).
