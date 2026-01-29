# Upstream Integration Plan (PR #845)

**Goal**: Integrate the UI stability fixes and testing infrastructure from upstream PR #845 (`vybestack/llxprt-code`) into our `llxprt-code` codebase.

## Analysis
The upstream PR "stop scrollback redraw + stabilize legacy Ink UI" introduces:
1.  **Testing Harness**: A robust `tmux`-based integration test runner (`oldui-tmux-harness.js`) with JSON scenario scripts. This is critical for verifying UI behavior without regressions.
2.  **UI Components**: Updates to `ScrollableList`, `VirtualizedList`, and `useAnimatedScrollbar` to support smooth scrolling and better layout stability.
3.  **Alignment**: Our `llxprt-code` already utilizes `ScrollableList` within our custom `MainContent` (Tabs) architecture. Adopting the upstream component logic will provide performance/feature parity (smooth scrolling) while maintaining our Tabs feature.

## Plan

### 1. Component Synchronization
Update the following files from the upstream `llxprt-code-4` worktree:
- `packages/cli/src/ui/components/shared/ScrollableList.tsx`
- `packages/cli/src/ui/components/shared/VirtualizedList.tsx`
- `packages/cli/src/ui/hooks/useAnimatedScrollbar.ts`

### 2. Test Harness Adoption
Port the testing infrastructure:
- Copy `scripts/oldui-tmux-harness.js`
- Copy `scripts/oldui-tmux-script.*.json` (specifically the scrollback/stability tests)
- Add necessary dependencies (if any) or script entries in `package.json` (e.g., `"test:ui": "node scripts/oldui-tmux-harness.js"`).

### 3. Verification
- Run the ported test harness scenarios against our build.
- Validate that the Tab switching mechanism works seamlessly with the updated `ScrollableList`.

## Verification Steps
1.  Run `npm run lint` & `npm run typecheck` after copying.
2.  Execute `node scripts/oldui-tmux-harness.js --script scripts/oldui-tmux-script.llm-tool-scrollback-realistic.llxprt.json`.
3.  Manually inspect smooth scrolling in the CLI.
