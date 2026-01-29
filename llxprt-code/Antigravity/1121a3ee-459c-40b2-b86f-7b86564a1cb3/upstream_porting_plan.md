# Upstream Porting Plan: Tabs Integration

**Goal**: Establish a clean feature branch based on the latest upstream `main` (located in `llxprt-code-4`) and port the Tabs & Layout architecture onto it. This ensures we inherit upstream stability improvements (PR #845) while reapplying our Tabs feature.

## Target Environment
- **Source**: `llxprt-code` (Current Feature Branch)
- **Target**: `llxprt-code-4` (Clean Main Worktree)

## Migration Payload

The following files constitute the "Tabs Feature" and will be copied/ported to `llxprt-code-4`:

### 1. New Components (Direct Copy)
- `packages/cli/src/ui/components/MainContent.tsx` (Core Tabs Logic)
- `packages/cli/src/ui/components/TabBar.tsx`
- `packages/cli/src/ui/components/AppHeader.tsx`
- `packages/cli/src/ui/components/McpStatus.tsx`
- `packages/cli/src/ui/components/tabs/` (All files: `TodoTab.tsx`, `SystemTab.tsx`)
- `packages/cli/src/ui/layouts/ScreenReaderAppLayout.tsx`

### 2. State & Context (Update/Merge)
- **`packages/cli/src/ui/reducers/appReducer.ts`**:
    - Port `State` interface updates (`activeTab`, `tabs`, `tabsWithUpdates`).
    - Port `Action` types (`SET_ACTIVE_TAB`, `SET_TAB_HAS_UPDATES`).
    - Port Reducer logic for these actions.
- **`packages/cli/src/ui/contexts/UIStateContext.tsx`**:
    - Port `activeTab` and `tabs` state exposure.

### 3. Layout Integration (Manual Merge)
- **`packages/cli/src/ui/layouts/DefaultAppLayout.tsx`**:
    - **Upstream has**: New `initError` logic and `ScrollableList` usage.
    - **We need**: To replace the main rendering block with `<MainContent />`, passing down strict props.
    - **Conflict Resolution**: Preserve `initError` logic inside `DefaultAppLayout` (or verify if `MainContent` needs to handle it). *Decision*: Keep `DefaultAppLayout` as the container that handles initialization errors, and only render `MainContent` when healthy.
- **`packages/cli/src/ui/AppContainer.tsx`**:
    - Port `ScreenReaderAppLayout` integration conditionals.

## Execution Steps

1.  **Backup**: Ensure `llxprt-code-4` is clean.
2.  **Port Files**: Write the content of source files to target files.
3.  **Merge Layouts**: Apply smart edits to target `DefaultAppLayout.tsx` and `AppContainer.tsx` to integrate the components.
4.  **Verification**:
    - Run `npm install` in target (if needed).
    - Run `npm run lint` & `npm run typecheck` in target.
    - Run the new test harness `node scripts/oldui-tmux-harness.js`.

## Post-Migration
- This `llxprt-code-4` directory will effectively become the new implementation ground.
- The user can then push this as `feat/tabs-v2`.
